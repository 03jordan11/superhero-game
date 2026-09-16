"""Make the three authored flight loops editable without rebaking their source.

Run Blender --background --python this_file.py. Keeps a separate untouched baked
backup, edits only the .blend, and measures subframe skeletal and skin error.
The game GLB is intentionally unchanged during this source-editing trial.
"""
import bpy
import json
import math
import shutil
from pathlib import Path
import numpy as np
from mathutils import Vector, Quaternion

OUT = Path(__file__).resolve().parents[1]
SOURCE = OUT / 'source/hero_flight.blend'
BACKUP = OUT / 'source/backups/hero_flight_baked.blend'
REPORT = OUT / 'source/flight_editability_report.json'
NAMES = ['Flight_Hover', 'Flight_Move', 'Flight_Fast']

def curves(action):
    return [c for layer in action.layers for strip in layer.strips
            for bag in strip.channelbags for c in bag.fcurves]

def activate(rig, action):
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]

def frame(scene, value):
    whole = math.floor(value)
    scene.frame_set(whole, subframe=value-whole)
    bpy.context.view_layer.update()

def skeleton(rig):
    return np.array([(*b.head, *b.tail, *b.matrix.to_quaternion())
                     for b in rig.pose.bones], dtype=np.float64)

def skin(objects):
    points = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        points.extend(tuple(evaluated.matrix_world @ v.co) for v in mesh.vertices)
        evaluated.to_mesh_clear()
    return np.array(points)

def errors(reference, candidate):
    head = np.linalg.norm(reference[:,:,:3]-candidate[:,:,:3],axis=2)
    tail = np.linalg.norm(reference[:,:,3:6]-candidate[:,:,3:6],axis=2)
    qa=reference[:,:,6:10]; qb=candidate[:,:,6:10]
    qa=qa/np.linalg.norm(qa,axis=2,keepdims=True)
    qb=qb/np.linalg.norm(qb,axis=2,keepdims=True)
    # Angular comparison normalizes quaternions and treats q and -q identically.
    angles=np.degrees(2*np.arccos(np.clip(np.abs(np.sum(qa*qb,axis=2)),0,1)))
    return float(max(head.max(),tail.max())),float(angles.max())

def simplify(action, sampled_curves, end, intervals):
    key_frames=[1+(end-1)*i/intervals for i in range(intervals+1)]
    for curve, samples in zip(curves(action), sampled_curves):
        curve.keyframe_points.clear()
        for modifier in list(curve.modifiers): curve.modifiers.remove(modifier)
        cycle=curve.modifiers.new('CYCLES')
        cycle.mode_before='REPEAT'; cycle.mode_after='REPEAT'
        for i, at in enumerate(key_frames):
            value=samples[0] if i==intervals else float(np.interp(at,np.arange(1,end+1),samples))
            key=curve.keyframe_points.insert(at,value,options={'FAST'})
            key.interpolation='BEZIER'
            key.handle_left_type='AUTO'; key.handle_right_type='AUTO'
            key.type='KEYFRAME' if i in [0,intervals] else ('EXTREME' if i in [intervals//4,3*intervals//4] else 'BREAKDOWN')
        curve.update()
    action.use_frame_range=True
    action.frame_start=1; action.frame_end=end
    if hasattr(action,'use_cyclic'): action.use_cyclic=True
    # Action-local labels follow the selected clip instead of showing other loops.
    for marker in list(action.pose_markers): action.pose_markers.remove(marker)
    labels={0:'Neutral - roll left',intervals//4:'Highest - inhale',
            intervals//2:'Neutral - roll right',3*intervals//4:'Lowest - exhale',
            intervals:'Loop seam - match 01'}
    for i,at in enumerate(key_frames):
        label=labels.get(i,{1:'Rising',3:'Settling',5:'Falling',7:'Recovering'}.get(i,'Transition'))
        marker=action.pose_markers.new('%02d %s' % (i+1,label)); marker.frame=round(at)
    return key_frames

def make_editable(scene, rig):
    """Called by the original authoring tool after its runtime export, too."""
    report={'fps':scene.render.fps, 'position_limit_m':0.001, 'angular_limit_degrees':0.15,
            'sample_step_frames':0.25, 'interpolation':'Bezier / automatic handles / Cycles repeat', 'clips':{}}
    bodies=[o for o in scene.objects if o.type=='MESH' and
            any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
    for name in NAMES:
        action=bpy.data.actions[name]
        activate(rig,action)
        end=round(action.frame_range[1])
        old_curves=curves(action)
        original_keys=sum(len(c.keyframe_points) for c in old_curves)
        source_values=[[c.evaluate(t) for t in range(1,end+1)] for c in old_curves]
        times=np.arange(1,end+.001,.25)
        reference=[]
        for t in times:
            frame(scene,float(t)); reference.append(skeleton(rig))
        reference=np.array(reference)
        # Include in-between points rather than validating only retained poses.
        skin_times=np.linspace(1,end,33)
        original_skin=[]
        for t in skin_times:
            frame(scene,float(t)); original_skin.append(skin(bodies))
        original_skin=np.array(original_skin)
        for intervals in [4,8,16]:
            poses=simplify(action,source_values,end,intervals)
            candidate=[]
            for t in times:
                frame(scene,float(t)); candidate.append(skeleton(rig))
            candidate=np.array(candidate)
            displacement,angle=errors(reference,candidate)
            print('FLIGHT_FIT',name,'pose_columns',len(poses),'max_mm',displacement*1000,'max_deg',angle,flush=True)
            if displacement<=report['position_limit_m'] and angle<=report['angular_limit_degrees']:
                break
        assert displacement<=report['position_limit_m'] and angle<=report['angular_limit_degrees'],(name,displacement,angle)
        assert intervals<=8, 'More than nine poses would undermine this editable-flight trial'
        new_skin=[]
        for t in skin_times:
            frame(scene,float(t)); new_skin.append(skin(bodies))
        skin_error=float(np.linalg.norm(original_skin-np.array(new_skin),axis=2).max())
        assert skin_error<=0.0015,(name,skin_error)
        seam_position,seam_angle=errors(candidate[0:1],candidate[-1:])
        assert seam_position<1e-6 and seam_angle<.001,(name,seam_position,seam_angle)
        # Check all scalar curve values and derivatives at both sides of the seam.
        derivative_gap=0.0
        for c in curves(action):
            first,last=c.keyframe_points[0],c.keyframe_points[-1]
            start_slope=(first.handle_right.y-first.co.y)/(first.handle_right.x-first.co.x)
            end_slope=(last.co.y-last.handle_left.y)/(last.co.x-last.handle_left.x)
            derivative_gap=max(derivative_gap,abs(start_slope-end_slope))
            assert abs(c.evaluate(1.125)-c.evaluate(end+.125))<1e-5,'Cycles repeat failed'
        assert derivative_gap<1e-5,(name,derivative_gap)
        report['clips'][name]={'frame_range':[1,end],'seconds':(end-1)/scene.render.fps,
            'pose_frames':poses,'original_key_count':original_keys,
            'editable_key_count':sum(len(c.keyframe_points) for c in curves(action)),
            'max_bone_endpoint_error_mm':displacement*1000,'max_bone_angle_error_deg':angle,
            'max_skinned_vertex_error_mm':skin_error*1000,'loop_position_error_mm':seam_position*1000,
            'loop_angle_error_deg':seam_angle,'loop_curve_slope_gap':derivative_gap,
            'skeleton_samples':len(times),'skin_samples':len(skin_times)}
        action['editing_notes']='Whole-body pose columns. Auto Bezier handles and Cycles keep the loop smooth. First and last poses must match.'
        print('FLIGHT_SPARSE_VALIDATED',name,json.dumps(report['clips'][name]),flush=True)
    setup_editing(scene,rig)
    return report

def setup_editing(scene,rig):
    activate(rig,bpy.data.actions['Flight_Hover'])
    scene.frame_start=1; scene.frame_end=193; frame(scene,1)
    rig.show_in_front=True
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
    bpy.context.view_layer.objects.active=rig
    for bone in rig.pose.bones: bone.select=False
    rig.pose.bones['pelvis'].select=True; rig.data.bones.active=rig.data.bones['pelvis']
    if hasattr(scene.tool_settings,'use_keyframe_cycle_aware'):
        scene.tool_settings.use_keyframe_cycle_aware=True
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='DOPESHEET_EDITOR':
                space=area.spaces.active
                space.mode='ACTION'; space.dopesheet.show_only_selected=True
                space.show_pose_markers=True
            elif area.type=='VIEW_3D':
                space=area.spaces.active
                space.region_3d.view_location=Vector((0,0,1.0))
                space.region_3d.view_distance=3.1
                space.region_3d.view_rotation=Quaternion((1,0,0),math.radians(80))
                space.shading.type='MATERIAL'
    for window in bpy.context.window_manager.windows:
        window.workspace=bpy.data.workspaces.get('Animation') or window.workspace
        for area in window.screen.areas:
            if area.type=='DOPESHEET_EDITOR':
                with bpy.context.temp_override(window=window,area=area,region=next(r for r in area.regions if r.type=='WINDOW')):
                    bpy.ops.action.view_all()
    bpy.ops.object.mode_set(mode='POSE')
    notes=bpy.data.texts.get('START HERE - Editable flight') or bpy.data.texts.new('START HERE - Editable flight')
    notes.clear()
    notes.write('''EDITABLE FLIGHT LOOPS
Select Armature, then choose Flight_Hover, Flight_Move or Flight_Fast in Action Editor.
The textured body and original weighted skeleton are included.
Only selected bones are shown in the Action Editor by default; select another bone
to see its curves, or turn off Only Show Selected to see the full-body keys.
Full-body key columns are intentional: select a pose, adjust bones in Pose Mode,
then insert Location & Rotation keys for the bones you changed.
Automatic Bezier handles update when poses move. Cycles repeats the curve and
makes endpoint handles continuous. Keep first and last poses identical.
Playback ranges at 60 FPS: Hover 1-193; Move 1-169; Fast 1-121.
For an exact repeated preview without the duplicated endpoint frame, play through
192 / 168 / 120 respectively; keep the seam keys at 193 / 169 / 121.
Actions retain their individual export frame ranges including the closing key.
Original baked backup: backups/hero_flight_baked.blend (not mixed into this action list).
The runtime GLB is unchanged for this editing trial. No other animation libraries changed.
''')

def main():
    BACKUP.parent.mkdir(parents=True,exist_ok=True)
    # Never overwrite the first untouched backup with an already-edited source.
    if not BACKUP.exists(): shutil.copy2(SOURCE,BACKUP)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.preferences.filepaths.save_version=0
    rig=bpy.data.objects['Armature']
    assert not rig.get('sparse_flight_source',False),'Already sparse: preserve manual edits; do not reduce again'
    report=make_editable(bpy.context.scene,rig)
    rig['sparse_flight_source']=True
    REPORT.write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    print('EDITABLE_FLIGHT_SAVED',str(SOURCE),flush=True)

if __name__=='__main__': main()
