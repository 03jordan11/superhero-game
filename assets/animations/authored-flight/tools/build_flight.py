"""Blender-authored seamless flight actions on the actual hero deform rig.
Run Blender --background --python this_file.py from any directory.
Coordinates: +X character left, -Y forward, +Z up; meters. No root motion.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/animations/authored-flight'
QA = ROOT / 'artifacts/authored_flight'
OUT.mkdir(parents=True, exist_ok=True)
QA.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/Superhero-male/Superhero_Male_FullBody.gltf'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.name = 'Armature'
rig.animation_data_clear()
for action in list(bpy.data.actions): bpy.data.actions.remove(action)
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
for pb in rig.pose.bones: pb.rotation_mode = 'QUATERNION'

def rotate(axis, degrees):
    return Quaternion(Vector(axis), math.radians(degrees)).to_matrix().to_4x4()

def set_world(name, matrix):
    pb = rig.pose.bones[name]
    pb.matrix_basis = pb.bone.convert_local_to_pose(
        matrix, pb.bone.matrix_local,
        parent_matrix=pb.parent.matrix if pb.parent else Matrix.Identity(4),
        parent_matrix_local=pb.parent.bone.matrix_local if pb.parent else Matrix.Identity(4), invert=True)
    bpy.context.view_layer.update()

def point(name): return rig.pose.bones[name].matrix.translation.copy()

def turn(name, axis, degrees):
    pb = rig.pose.bones[name]
    matrix = rotate(axis, degrees) @ pb.matrix
    matrix.translation = pb.matrix.translation
    set_world(name, matrix)

def aim(name, origin, destination):
    direction = (Vector(destination)-Vector(origin)).normalized()
    bone = rig.data.bones[name]
    original = (bone.tail_local-bone.head_local).normalized()
    matrix = original.rotation_difference(direction).to_matrix().to_4x4() @ rest[name]
    matrix.translation = origin
    set_world(name, matrix)

def limb(upper, lower, end, target, pole):
    origin = point(upper)
    a = (rest[lower].translation-rest[upper].translation).length
    b = (rest[end].translation-rest[lower].translation).length
    direction = Vector(target)-origin
    distance = min(direction.length, (a+b)*.997)
    direction.normalize()
    x = (a*a-b*b+distance*distance)/(2*distance)
    bend = Vector(pole)-origin
    bend = (bend-direction*bend.dot(direction)).normalized()
    elbow = origin+direction*x+bend*math.sqrt(max(0,a*a-x*x))
    aim(upper,origin,elbow)
    aim(lower,elbow,origin+direction*distance)

def hand(side, curl):
    name = 'hand_'+side
    sign = 1 if side == 'l' else -1
    forward = (point(name)-point('lowerarm_'+side)).normalized()
    palm = Vector((-sign,0,0))
    palm = (palm-forward*palm.dot(forward)).normalized()
    x = forward*sign
    z = -palm
    y = z.cross(x).normalized()
    z = x.cross(y).normalized()
    matrix = Matrix((x,y,z)).transposed().to_4x4() @ rest[name]
    matrix.translation = point(name)
    set_world(name,matrix)
    for finger in ['index','middle','ring','pinky']:
        for joint, angle in [(1,65),(2,82),(3,60)]:
            name = f'{finger}_{joint:02}_{side}'
            axis = rest[name].to_quaternion().inverted() @ Vector((0,sign,0))
            rig.pose.bones[name].rotation_quaternion = Quaternion(axis,math.radians(angle*curl))
    for joint, angle in [(1,40),(2,30),(3,20)]:
        name = f'thumb_{joint:02}_{side}'
        axis = rest[name].to_quaternion().inverted() @ Vector((0,-.25*sign,sign))
        rig.pose.bones[name].rotation_quaternion = Quaternion(axis.normalized(),math.radians(angle*curl))

def pose(mode, phase):
    for pb in rig.pose.bones: pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    wave = math.sin(phase)
    secondary = math.sin(phase+math.pi*.5)
    fast = mode == 'Flight_Fast'
    cruise = mode == 'Flight_Move'
    bob = (.008 if fast else .025)*wave
    hip = rest['pelvis'].copy(); hip.translation.z += bob
    set_world('pelvis',hip)
    turn('spine_02',(1,0,0),-2+wave*.6)
    turn('spine_03',(0,1,0),secondary*(.3 if fast else .8))
    for side,sign in [('l',1),('r',-1)]:
        spread = .265 if fast else (.34 if cruise else .39)
        wrist = (sign*(spread+wave*.006), .09 if fast or cruise else -.025, .94+bob)
        limb('upperarm_'+side,'lowerarm_'+side,'hand_'+side,wrist,
             (sign*.58,-.035,1.18+bob))
        hand(side, .95 if fast else .55)
        stagger = 0 if fast else (.06 if side == 'l' else -.015)
        foot = (sign*(.105 if fast else .145), .035+stagger, (.04 if fast else .12)+stagger+bob+wave*.005*sign)
        limb('thigh_'+side,'calf_'+side,'foot_'+side,foot,(sign*.2,-.5,.55))
        matrix = rotate((1,0,0),70 if fast else 18) @ rest['foot_'+side]
        matrix.translation=point('foot_'+side); set_world('foot_'+side,matrix)
    pitch = (80 if fast else 18 if cruise else 0)+wave*(.4 if fast else 1.0)
    turn('pelvis',(1,0,0),pitch)
    # Keep the gaze directed forward while the body stretches into the airstream.
    turn('neck_01',(1,0,0),-pitch*.36)
    turn('Head',(1,0,0),-pitch*.46)
    bpy.context.view_layer.update()

scene=bpy.context.scene
scene.render.fps=60
rig.animation_data_create()
actions=[]
for name,seconds in [('Flight_Hover',3.2),('Flight_Move',2.8),('Flight_Fast',2.0)]:
    action=bpy.data.actions.new(name); action.use_fake_user=True
    rig.animation_data.action=action
    end=round(seconds*60)+1
    for frame in range(1,end+1):
        scene.frame_set(frame)
        pose(name,(frame-1)/(end-1)*math.tau)
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
            if pb.name=='pelvis': pb.keyframe_insert('location',frame=frame,group=pb.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    actions.append(action)
    print('AUTHORED',name,end,flush=True)
rig.animation_data.action=actions[0]
scene.frame_start=1; scene.frame_end=193; scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'hero_flight.glb'),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
    export_frame_range=False,export_nla_strips=False,export_anim_slide_to_zero=True,
    export_anim_single_armature=True,export_skins=True,export_all_influences=True)
for image in bpy.data.images:
    if image.source=='FILE':
        try: image.pack()
        except RuntimeError: pass
source=OUT/'source'; source.mkdir(exist_ok=True); (source/'.gdignore').touch()
# Keep the runtime export sampled, but save an editable source with sparse poses.
# This intentionally regenerates the authored baseline, not later manual revisions.
import runpy, json
sparse = runpy.run_path(str(OUT/'tools/sparsify_flight.py'))
edit_report = sparse['make_editable'](scene, rig)
rig['sparse_flight_source'] = True
(source/'flight_editability_report.json').write_text(json.dumps(edit_report,indent=2)+'\n')
# Editable source retains the original textured mesh and the three named actions.
bpy.ops.wm.save_as_mainfile(filepath=str(source/'hero_flight.blend'))
print('FLIGHT_LIBRARY_EXPORTED',flush=True)
