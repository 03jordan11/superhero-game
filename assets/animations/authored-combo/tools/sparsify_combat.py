"""Convert authored combat sources to sparse poses; never export or rebuild them.

Run with Blender --background --python this_file.py. First baked backups are
immutable. Already converted files are skipped to protect subsequent hand edits.
"""
import hashlib
import json
import math
import runpy
import shutil
from pathlib import Path

import bpy
import numpy as np
from mathutils import Quaternion, Vector

OUT = Path(__file__).resolve().parents[1]
HELPERS = runpy.run_path(str(OUT.parent / 'authored-flight/tools/sparsify_flight.py'))
curves, activate, frame, skeleton, skin, errors = [HELPERS[n] for n in
    ('curves', 'activate', 'frame', 'skeleton', 'skin', 'errors')]
SOURCES = ('hero_combo', 'hero_combat_grabs', 'hero_charge_punch')
POSITION_LIMIT = .006
ANGLE_LIMIT = .85
SKIN_LIMIT = .008

# Original authoring beats, in seconds. Keep event frames at their original
# rounded 60-fps positions; extra keys preserve arcs between these poses.
BEATS = {
    'Cross': [(0, 'Guard'), (.08, 'Anticipation'), (.14, 'Drive'), (.20, 'Impact'), (.27, 'Follow through'), (.39, 'Retract'), (.55, 'Recover'), (.70, 'Guard')],
    'Hook': [(0, 'Guard'), (.085, 'Anticipation'), (.145, 'Drive'), (.20, 'Impact'), (.28, 'Follow through'), (.42, 'Retract'), (.60, 'Recover'), (.76, 'Guard')],
    'FlyingUppercut': [(0, 'Guard'), (.10, 'Crouch'), (.16, 'Drive'), (.20, 'Strike'), (.25, 'Launch'), (.34, 'Apex'), (.53, 'Hold'), (.72, 'Recover'), (.92, 'Airborne exit')],
    'Grab': [(0, 'Reach'), (.20, 'Grip'), (.36, 'Lift'), (.60, 'Held')],
    'ThrowCharge': [(0, 'Held'), (.60, 'Fully charged')],
    'ThrowRelease': [(0, 'Loaded'), (.18, 'Drive'), (.30, 'Release'), (.43, 'Follow through'), (.70, 'Recover')],
    'ChargePunchWindup': [(0, 'Guard'), (.4, 'Fully charged')],
    'ChargePunchHold': [(0, 'Loaded'), (.75, 'Breathe'), (1.5, 'Loop seam')],
    'ChargePunchRelease': [(0, 'Loaded'), (.10, 'Drive'), (.20, 'Impact'), (.28, 'Strike hold'), (.48, 'Recover'), (.70, 'Guard')],
}
for i, end, impact in ((1, 1., .36), (2, 1., .36), (3, 1.2, .44)):
    BEATS['Slam%d' % i] = [(0, 'Held'), (.16, 'Windup'), (impact, 'Impact' if i < 3 else 'Impact and release'), (impact+.10, 'Impact hold'), (end, 'Lift complete' if i < 3 else 'Recover')]


def metadata(action, end):
    name = action.name.split('_', 1)[1]
    loop = bool(action.get('loop', False)) or name == 'ChargePunchHold'
    beats = BEATS.get(name)
    if beats is None:
        beats = [(0, 'Loop start'), ((end-1)/240, 'Quarter cycle'),
                 ((end-1)/120, 'Half cycle'), (3*(end-1)/240, 'Three quarter cycle'),
                 ((end-1)/60, 'Loop seam')]
    labels = {min(end, max(1, round(t*60)+1)): label for t, label in beats}
    labels.setdefault(1, 'Start'); labels.setdefault(end, 'Loop seam' if loop else 'Exit')
    for marker in action.pose_markers:
        labels[marker.frame] = marker.name.replace('_', ' ').capitalize()
    return loop, labels


def write_group(group, values, poses, end, loop):
    ordered = np.array(sorted(poses))
    times = np.arange(1, end+.01, .25)
    interval = np.clip(np.searchsorted(ordered, times, side='right')-1, 0, len(ordered)-2)
    widths = np.diff(ordered)[interval]
    u = (times-ordered[interval])/widths
    h00 = 2*u**3-3*u**2+1; h01 = -2*u**3+3*u**2
    h10 = u**3-2*u**2+u; h11 = u**3-u**2
    indices = [i for i,c in group]
    targets = np.array([np.interp(times,np.arange(1,end+1),values[i]) for i in indices]).T
    key_values = values[indices][:,ordered-1].T
    fixed = h00[:,None]*key_values[interval]+h01[:,None]*key_values[interval+1]
    # Fit one shared tangent at each key. This yields C1 continuous Bezier
    # curves, including the loop seam, with ordinary editable aligned handles.
    design = np.zeros((len(times),len(ordered)-(1 if loop else 0)))
    rows = np.arange(len(times))
    design[rows,interval] += h10*widths
    design[rows,(interval+1)%design.shape[1]] += h11*widths
    slopes = np.linalg.lstsq(design,targets-fixed,rcond=None)[0]
    if loop: slopes = np.vstack((slopes,slopes[0]))
    for column,(index, curve) in enumerate(group):
        curve.keyframe_points.clear()
        for modifier in list(curve.modifiers):
            curve.modifiers.remove(modifier)
        if loop:
            modifier = curve.modifiers.new('CYCLES')
            modifier.mode_before = 'REPEAT'; modifier.mode_after = 'REPEAT'
        curve.keyframe_points.add(len(poses))
        for j,(key, at) in enumerate(zip(curve.keyframe_points, ordered)):
            key.co = (at, float(values[index, at-1]))
            key.interpolation = 'BEZIER'
            key.handle_left_type = 'FREE'; key.handle_right_type = 'FREE'
            left = (ordered[j]-ordered[j-1])/3 if j else (ordered[-1]-ordered[-2])/3 if loop else (ordered[1]-ordered[0])/3
            right = (ordered[j+1]-ordered[j])/3 if j<len(ordered)-1 else (ordered[1]-ordered[0])/3 if loop else left
            slope = slopes[j,column]
            key.handle_left = (at-left,key.co.y-left*slope)
            key.handle_right = (at+right,key.co.y+right*slope)
            key.handle_left_type = 'ALIGNED'; key.handle_right_type = 'ALIGNED'
            key.type = 'BREAKDOWN'
        curve.update()
        # Preserve short sharp contacts exactly; no easing across their edges.
        for a,b in zip(curve.keyframe_points,list(curve.keyframe_points)[1:]):
            if b.co.x-a.co.x <= 1.001 and not (loop and (a.co.x==1 or b.co.x==end)):
                a.interpolation='LINEAR'


def fit_curves(action, values, end, loop, labels, tolerance):
    times = np.arange(1, end+.01, .25)
    groups = {}
    for i, c in enumerate(curves(action)):
        bone = c.data_path.split('"')[1]
        groups.setdefault(bone, []).append((i, c))
    counts = {}
    for bone, group in groups.items():
        indices = [i for i, c in group]
        # Constant bones only need endpoints. They remain easy to pose/key.
        constant = np.ptp(values[indices], axis=1).max() < 1e-6
        poses = {1, end} if constant else set(labels)
        targets = np.array([np.interp(times, np.arange(1,end+1), values[i]) for i in indices])
        while True:
            write_group(group, values, poses, end, loop)
            actual = np.array([[c.evaluate(float(t)) for t in times] for i, c in group])
            deviation = np.abs(actual-targets).max(axis=0)
            if deviation.max() <= tolerance or len(poses) == end:
                break
            # Add one worst missing integer pose per interval, avoiding a dense
            # chain of adjacent keys merely to chase the same local maximum.
            additions = set()
            ordered = sorted(poses)
            for left, right in zip(ordered, ordered[1:]):
                if right-left <= 1: continue
                mask = (times > left) & (times < right)
                ids = np.flatnonzero(mask)
                worst = ids[np.argmax(deviation[mask])]
                if deviation[worst] > tolerance:
                    additions.add(max(left+1, min(right-1, round(times[worst]))))
            if not additions: break
            poses.update(additions)
        for i, c in group:
            for k in c.keyframe_points:
                if round(k.co.x) in labels: k.type = 'KEYFRAME'
        counts[bone] = len(poses)
    return counts


def sample_skeleton(scene, rig, times):
    result = []
    for t in times:
        frame(scene, float(t)); result.append(skeleton(rig))
    return np.array(result)


def reduce_action(scene, rig, action):
    activate(rig, action)
    end = round(action.frame_range[1])
    original = curves(action)
    values = np.array([[c.evaluate(t) for t in range(1,end+1)] for c in original])
    loop, labels = metadata(action, end)
    # The existing run seam needs a small additional adjustment for a matched
    # pose AND velocity; other actions use the tighter standard limits.
    position_limit=.008 if action.name=='Hero_CarryRun' else POSITION_LIMIT
    angle_limit=1.3 if action.name=='Hero_CarryRun' else ANGLE_LIMIT
    fingerprint = hashlib.sha256(values.tobytes() + str([(c.data_path,c.array_index) for c in original]).encode()).hexdigest()
    times = np.arange(1, end+.01, .25)
    raw_baseline = sample_skeleton(scene, rig, times)
    # Equivalent quaternion signs sometimes alternate in these baked files.
    # Align their hemispheres before fitting: this keeps every keyed orientation
    # and prevents a hand from taking a 180-degree detour between baked frames.
    quaternion_groups={}
    for i,c in enumerate(original):
        if c.data_path.endswith('rotation_quaternion'):
            quaternion_groups.setdefault(c.data_path,[]).append((c.array_index,i))
    sign_fixes=0
    for entries in quaternion_groups.values():
        indices=[i for component,i in sorted(entries)]
        for at in range(1,end):
            if np.dot(values[indices,at-1],values[indices,at])<0:
                values[indices,at]*=-1; sign_fixes+=1
    for i,c in enumerate(original):
        for k in c.keyframe_points: k.co.y=float(values[i,round(k.co.x)-1])
        c.update()
    baseline = sample_skeleton(scene, rig, times)
    original_seam_position,original_seam_angle=errors(baseline[0:1],baseline[-1:])
    if loop:
        # CarryRun's original imported footwork has a 4.7 mm endpoint mismatch.
        # Blend its scalar mismatch away over the final fifth of the cycle.
        weight=np.clip((np.arange(end)-(end-1)*.8)/((end-1)*.2),0,1)
        weight=weight*weight*(3-2*weight)
        values += (values[:,0]-values[:,-1])[:,None]*weight
        values[:,-1]=values[:,0]
    bodies = [o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
    skin_times = sorted(set(np.linspace(1,end,17).tolist()+list(labels)))
    original_skin = []
    for t in skin_times:
        frame(scene,float(t)); original_skin.append(skin(bodies))
    original_skin = np.array(original_skin)
    original_keys = sum(len(c.keyframe_points) for c in original)
    for tolerance in (.003, .0015, .00075, .0003, .0001):
        counts = fit_curves(action, values, end, loop, labels, tolerance)
        candidate = sample_skeleton(scene, rig, times)
        displacement, angle = errors(baseline, candidate)
        print('FIT', action.name, 'keys/bone',min(counts.values()),max(counts.values()),'mm',round(displacement*1000,3),'degrees',round(angle,3),flush=True)
        if displacement <= position_limit and angle <= angle_limit: break
    assert displacement <= position_limit and angle <= angle_limit, (action.name,displacement,angle)
    keyed_error,keyed_angle=errors(raw_baseline[::4],candidate[::4])
    assert keyed_error <= position_limit and keyed_angle <= angle_limit
    new_skin = []
    for t in skin_times:
        frame(scene,float(t)); new_skin.append(skin(bodies))
    skin_error = float(np.linalg.norm(original_skin-np.array(new_skin),axis=2).max())
    assert skin_error <= SKIN_LIMIT, (action.name,skin_error)
    seam_position, seam_angle = errors(candidate[0:1],candidate[-1:])
    slope_gap = 0.
    if loop:
        assert seam_position < 1e-5 and seam_angle < .01, (action.name,seam_position,seam_angle)
        for c in curves(action):
            first,last=c.keyframe_points[0],c.keyframe_points[-1]
            start_slope=(first.handle_right.y-first.co.y)/(first.handle_right.x-first.co.x)
            end_slope=(last.co.y-last.handle_left.y)/(last.co.x-last.handle_left.x)
            slope_gap=max(slope_gap,abs(start_slope-end_slope))
            assert abs(c.evaluate(1.125)-c.evaluate(end+.125))<1e-5
        assert slope_gap < 1e-5, (action.name,slope_gap)
    action.use_frame_range=True; action.frame_start=1; action.frame_end=end
    action.use_cyclic=loop
    action['sparse_combat_source']=True
    action['editing_notes']='Named key poses plus per-bone breakdowns. Fitted Bezier with aligned handles. Keep both loop endpoints and their tangents matched.'
    for m in list(action.pose_markers): action.pose_markers.remove(m)
    for at,label in sorted(labels.items()): action.pose_markers.new(label).frame=at
    report = dict(frame_range=[1,end], loop=loop, important_poses=labels,
        keys_per_bone=counts, original_key_count=original_keys,
        editable_key_count=sum(len(c.keyframe_points) for c in curves(action)),
        max_bone_endpoint_error_mm=displacement*1000,max_bone_angle_error_deg=angle,
        max_skinned_vertex_error_mm=skin_error*1000,
        loop_position_gap_mm=seam_position*1000 if loop else None,
        loop_angle_gap_deg=seam_angle if loop else None,
        loop_curve_slope_gap=slope_gap if loop else None,
        original_loop_position_gap_mm=original_seam_position*1000 if loop else None,
        original_loop_angle_gap_deg=original_seam_angle if loop else None,
        quaternion_hemisphere_samples_corrected=sign_fixes,
        max_original_integer_frame_error_mm=keyed_error*1000,
        max_original_integer_frame_angle_error_deg=keyed_angle,
        position_limit_mm=position_limit*1000,angle_limit_deg=angle_limit,
        skeleton_samples=len(times),skin_samples=len(skin_times),baseline_sha256=fingerprint)
    print('SPARSE_VALIDATED',action.name,json.dumps({k:v for k,v in report.items() if k not in ('keys_per_bone','important_poses')}),flush=True)
    return report


def setup_editing(scene, rig, source):
    victim=bpy.data.objects.get('VictimPreview')
    name='Hero_Hold' if victim else ('Hero_ChargePunchWindup' if 'charge_punch' in source else 'Hero_Cross')
    activate(rig,bpy.data.actions[name])
    if victim: activate(victim,bpy.data.actions['Victim_Hold'])
    scene.frame_start=1; scene.frame_end=round(rig.animation_data.action.frame_range[1]); frame(scene,1)
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
    bpy.context.view_layer.objects.active=rig
    rig.show_in_front=True
    for b in rig.pose.bones: b.select=False
    rig.pose.bones['pelvis'].select=True; rig.data.bones.active=rig.data.bones['pelvis']
    scene.tool_settings.use_keyframe_cycle_aware=True
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='DOPESHEET_EDITOR':
                space=area.spaces.active; space.mode='ACTION'
                space.dopesheet.show_only_selected=True; space.show_pose_markers=True
            elif area.type=='VIEW_3D':
                space=area.spaces.active
                space.region_3d.view_location=Vector((0,-.3,1))
                space.region_3d.view_distance=4 if victim else 3.1
                space.region_3d.view_rotation=Quaternion((1,0,0),math.radians(80))
                space.shading.type='MATERIAL'
    for window in bpy.context.window_manager.windows:
        window.workspace=bpy.data.workspaces.get('Animation') or window.workspace
        for area in window.screen.areas:
            if area.type=='DOPESHEET_EDITOR':
                with bpy.context.temp_override(window=window,area=area,region=next(r for r in area.regions if r.type=='WINDOW')):
                    bpy.ops.action.view_all()
    bpy.ops.object.mode_set(mode='POSE')
    notes=bpy.data.texts.get('START HERE - Editable combat') or bpy.data.texts.new('START HERE - Editable combat')
    notes.clear()
    notes.write('''EDITABLE COMBAT ANIMATIONS - 60 FPS
Select Armature, choose a Hero_ action in the Action Editor, and select the bones
you want to edit in Pose Mode. The textured reference body remains rigged.
Only Show Selected is enabled: keys for unrelated bones are hidden. The summary
of ALL bones can still look busy because individual bones need different keys.
Named action markers identify anticipation, grip, impact, release and recovery.
Gold keys are important poses; blue breakdowns preserve the movement between them.
Constant bones have only two endpoint keys. Transitions use Bezier interpolation
with aligned handles fitted to preserve the original motion. Move a key to edit
its pose; use Graph Editor handles to reshape timing. Do not change every handle
to Automatic at once: the fitted handle slopes are part of the preserved motion.
Pose a bone and insert Location & Rotation keys to record your changes.
Switching actions does NOT automatically change the scene playback range:
use the action's Frame Range (also listed below). Loops have a duplicate last
pose: keep both endpoints and their handle slopes matched, preview through the
frame before the last. Cycles repeats the curves outside the original range.
For paired actions, open hero_combat_grabs.blend, select VictimPreview and choose
the matching Victim_ action as well. Keep both rigs at their shared origin.
Use hero_charge_punch.blend for charged punches; its other clips are duplicates.
Backups of the untouched baked sources are in source/backups/*_baked.blend.
This conversion changes only source editing. Runtime GLBs were not re-exported.
Do not run build_*.py after editing: those regenerate poses and overwrite sources.

ACTION RANGES:
''')
    for a in sorted(bpy.data.actions,key=lambda a:a.name):
        notes.write('%s: 1-%d%s\n' % (a.name,round(a.frame_range[1]),' (loop)' if a.use_cyclic else ''))


def main():
    report={'fps':60,'bone_position_limit_mm':POSITION_LIMIT*1000,'bone_angle_limit_deg':ANGLE_LIMIT,
        'skin_position_limit_mm':SKIN_LIMIT*1000,'sample_step_frames':.25,'files':{}}
    protected=[OUT/'hero_combo.glb',OUT.parent/'authored-flight/hero_flight.glb',OUT.parent/'authored-flight/source/hero_flight.blend']
    hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    for source in SOURCES:
        path=OUT/'source'/(source+'.blend')
        bpy.ops.wm.open_mainfile(filepath=str(path))
        rig=bpy.data.objects['Armature']; scene=bpy.context.scene
        if rig.get('sparse_combat_source'):
            existing_report=OUT/'source'/('editability_'+source+'.json')
            if existing_report.exists(): report['files'][source]=json.loads(existing_report.read_text())
            print('SKIP_ALREADY_EDITABLE',source,flush=True); continue
        backup=path.parent/'backups'/(source+'_baked.blend')
        backup.parent.mkdir(exist_ok=True)
        if not backup.exists(): shutil.copy2(path,backup)
        assert scene.render.fps==60
        clips={}
        for action in sorted(bpy.data.actions,key=lambda a:a.name):
            clips[action.name]=reduce_action(scene,rig,action)
        setup_editing(scene,rig,source)
        rig['sparse_combat_source']=True
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(path))
        report['files'][source]={'backup':str(backup),'clips':clips}
        (OUT/'source'/('editability_'+source+'.json')).write_text(json.dumps(report['files'][source],indent=2)+'\n')
        print('EDITABLE_COMBAT_SAVED',source,flush=True)
    assert hashes=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    report['protected_files_sha256']=hashes
    (OUT/'source/combat_editability_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('EDITABLE_COMBAT_COMPLETE',flush=True)


if __name__=='__main__': main()
