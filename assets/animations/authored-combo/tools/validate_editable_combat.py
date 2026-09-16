"""Reopen sparse sources, audit paired contact/structure, render source previews."""
import hashlib
import json
import runpy
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

OUT=Path(__file__).resolve().parents[1]
ROOT=OUT.parents[2]
QA=ROOT/'artifacts/combat_editability'
H=runpy.run_path(str(OUT/'tools/sparsify_combat.py'))
curves,activate,frame=H['curves'],H['activate'],H['frame']


def structure():
    meshes={}
    for o in bpy.data.objects:
        if o.type!='MESH': continue
        weights=[[(w.group,round(w.weight,7)) for w in v.groups] for v in o.data.vertices]
        meshes[o.name]={'vertices':len(o.data.vertices),
            'geometry':hashlib.sha256(str([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest(),
            'weights':hashlib.sha256(str(weights).encode()).hexdigest(),
            'armatures':[m.object.name for m in o.modifiers if m.type=='ARMATURE' and m.object]}
    return {'meshes':meshes,'bones':{o.name:[(b.name,[list(r) for r in b.matrix_local]) for b in o.data.bones]
        for o in bpy.data.objects if o.type=='ARMATURE'},
        'textures':{i.name:bool(i.packed_file or i.packed_files) for i in bpy.data.images if i.source=='FILE'},
        'actions':sorted(a.name for a in bpy.data.actions),'fps':bpy.context.scene.render.fps}


def align_quaternions():
    # Compare the physically equivalent shortest quaternion paths, avoiding
    # preexisting sign-flip spins at fractional frames in the baked reference.
    for a in bpy.data.actions:
        groups={}
        for c in curves(a):
            if c.data_path.endswith('rotation_quaternion'):
                groups.setdefault(c.data_path,[]).append(c)
        for group in groups.values():
            group.sort(key=lambda c:c.array_index)
            previous=None
            for i in range(len(group[0].keyframe_points)):
                value=np.array([c.keyframe_points[i].co.y for c in group])
                if previous is not None and np.dot(previous,value)<0:
                    value=-value
                    for c,v in zip(group,value): c.keyframe_points[i].co.y=float(v)
                previous=value
            for c in group:c.update()


def contact_samples():
    rig=bpy.data.objects['Armature']; victim=bpy.data.objects['VictimPreview']
    scene=bpy.context.scene; result={}
    hand=rig.data.bones['hand_r'].matrix_local
    offset=hand.inverted() @ (hand.translation+Vector((-.075,-.018,0)))
    for a in bpy.data.actions:
        if not a.name.startswith('Victim_'):continue
        pair=a.name.split('_',1)[1]
        activate(rig,bpy.data.actions['Hero_'+pair]);activate(victim,a)
        samples=[]
        for t in np.arange(1,round(a.frame_range[1])+.01,.25):
            frame(scene,float(t))
            anchor=rig.pose.bones['hand_r'].matrix @ offset
            samples.append(tuple(victim.pose.bones['neck_01'].head-anchor))
        result[pair]=np.array(samples)
    return result


def main():
    QA.mkdir(parents=True,exist_ok=True)
    report={}
    for source in H['SOURCES']:
        path=OUT/'source'/(source+'.blend')
        bpy.ops.wm.open_mainfile(filepath=str(path.parent/'backups'/(source+'_baked.blend')))
        original=structure()
        old_markers={a.name:sorted(m.frame for m in a.pose_markers) for a in bpy.data.actions}
        reference=None
        if source=='hero_combat_grabs':
            align_quaternions();reference=contact_samples()
        bpy.ops.wm.open_mainfile(filepath=str(path))
        assert structure()==original, 'Rig, reference mesh, weights, textures, action names or FPS changed'
        rig=bpy.data.objects['Armature'];scene=bpy.context.scene
        assert rig.mode=='POSE' and rig.get('sparse_combat_source')
        assert bpy.data.texts.get('START HERE - Editable combat')
        counts={};seams={}
        for a in bpy.data.actions:
            assert a.get('sparse_combat_source') and a.use_frame_range
            assert set(old_markers[a.name]).issubset({m.frame for m in a.pose_markers})
            cs=curves(a)
            counts[a.name]=sum(len(c.keyframe_points) for c in cs)
            if a.use_cyclic:
                gap=0.
                for c in cs:
                    first,last=c.keyframe_points[0],c.keyframe_points[-1]
                    assert first.interpolation=='BEZIER'
                    assert c.keyframe_points[-2].interpolation=='BEZIER'
                    assert abs(first.co.y-last.co.y)<1e-6
                    start=(first.handle_right.y-first.co.y)/(first.handle_right.x-first.co.x)
                    end=(last.co.y-last.handle_left.y)/(last.co.x-last.handle_left.x)
                    gap=max(gap,abs(start-end))
                    assert any(m.type=='CYCLES' for m in c.modifiers)
                assert gap<1e-5,(a.name,gap)
                seams[a.name]=gap
        report[source]={'structure_unchanged':True,'action_count':len(counts),'total_keys':sum(counts.values()),'loop_slope_gaps':seams}
        if reference:
            actual=contact_samples()
            deviation={name:float(np.linalg.norm(reference[name]-actual[name],axis=1).max()*1000) for name in reference}
            assert max(deviation.values())<10, deviation
            report[source]['max_paired_contact_change_mm']=deviation
        if source=='hero_combat_grabs':
            activate(rig,bpy.data.actions['Hero_Hold'])
            activate(bpy.data.objects['VictimPreview'],bpy.data.actions['Victim_Hold'])
            at=25
        elif source=='hero_combo':activate(rig,bpy.data.actions['Hero_Hook']);at=13
        else:activate(rig,bpy.data.actions['Hero_ChargePunchWindup']);at=25
        frame(scene,at)
        scene.render.engine='CYCLES';scene.cycles.samples=12
        scene.render.resolution_x=800;scene.render.resolution_y=720;scene.render.resolution_percentage=100
        scene.render.filepath=str(QA/(source+'.png'))
        bpy.ops.render.render(write_still=True)
        print('REOPEN_AUDIT_PASS',source,json.dumps(report[source]),flush=True)
    (QA/'source_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('EDITABLE_COMBAT_REOPEN_VALIDATION_PASS',flush=True)


if __name__=='__main__':main()
