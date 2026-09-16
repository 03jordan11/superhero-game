"""Export the saved hand-edited Blender actions. NEVER rebuild or save the .blend.
Run Blender --background --python assets/animations/authored-flight/tools/export_edited_flight.py
Then run Godot --headless --path . --editor --import to refresh the existing library.
"""
import bpy, hashlib, json, math, struct
from pathlib import Path

BASE=Path(__file__).resolve().parents[1]
SOURCE=BASE/'source/hero_flight.blend'
TARGET=BASE/'hero_flight.glb'
names=['Flight_Hover','Flight_Move','Flight_Fast']
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene
rig=bpy.data.objects['Armature']
assert all(name in bpy.data.actions for name in names),'Expected three named flight actions'
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
info={}
reference={}
for name in names:
    action=bpy.data.actions[name]
    rig.animation_data.action=action
    rig.animation_data.action_slot=action.slots[0]
    start,end=action.frame_range
    snapshots=[]
    for frame in [start,end]:
        scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame))
        bpy.context.view_layer.update()
        snapshots.append({b.name:b.matrix.copy() for b in rig.pose.bones})
    max_position=max((snapshots[0][n].translation-snapshots[1][n].translation).length for n in snapshots[0])
    max_angle=max(snapshots[0][n].to_quaternion().rotation_difference(snapshots[1][n].to_quaternion()).angle for n in snapshots[0])
    cs=[c for l in action.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
    info[name]={'frames':[start,end], 'seconds':(end-start)/(scene.render.fps/scene.render.fps_base),
        'source_key_count':sum(len(c.keyframe_points) for c in cs),
        'source_loop_position_gap_m':max_position,'source_loop_angle_gap_deg':math.degrees(max_angle)}
    # Record actual local TRS for an independent export roundtrip check.
    samples=[]
    for f in range(round(start),round(end)+1):
        scene.frame_set(f); bpy.context.view_layer.update()
        samples.append({b.name:{'location':list(b.location),'rotation':list(b.matrix_basis.to_quaternion()),'scale':list(b.scale)} for b in rig.pose.bones})
    reference[name]=samples
    print('EDITED_SOURCE',name,json.dumps(info[name]),flush=True)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig
# Include only these armature actions; reference meshes remain in the source file.
for action in bpy.data.actions:
    action.use_fake_user=True if action.name in names else action.use_fake_user
bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
    export_frame_range=False,export_nla_strips=False,export_anim_slide_to_zero=True,
    export_anim_single_armature=True,export_skins=True,export_all_influences=True)
blob=TARGET.read_bytes(); size,kind=struct.unpack_from('<II',blob,12)
doc=json.loads(blob[20:20+size])
assert sorted(a['name'] for a in doc['animations'])==sorted(names), 'Unexpected exported clip set'
assert not doc.get('meshes'), 'Animation export unexpectedly includes a reference mesh'
for action in doc['animations']:
    duration=max(doc['accessors'][s['input']]['max'][0] for s in action['samplers'])
    assert abs(duration-info[action['name']]['seconds'])<1e-5,(action['name'],duration)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash,'Source Blender file changed'
report={'source_sha256':source_hash,'export_sha256':hashlib.sha256(blob).hexdigest(),
    'fps':scene.render.fps,'actions':info,'source_file_unchanged':True}
(BASE/'edited_export_report.json').write_text(json.dumps(report,indent=2)+'\n')
qa=BASE.parents[2]/'artifacts/flight-editability'
qa.mkdir(parents=True,exist_ok=True)
(qa/'edited_source_samples.json').write_text(json.dumps(reference))
print('EDITED_FLIGHT_EXPORTED',json.dumps(report),flush=True)
