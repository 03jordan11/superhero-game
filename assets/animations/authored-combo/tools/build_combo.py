"""Author the alternate combo on the actual hero rig in Blender; export one GLB library.

Run from the project root with Blender --background --python <this file>.
No source actions are copied. Hand/foot targets and torso keys below are the
animation controls; the two-bone solves are baked onto the original deform rig.
Blender coordinates: +X left, -Y forward, +Z up. Distances are meters.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/animations/authored-combo'
QA = ROOT / 'artifacts/authored_combo'
FPS = 60
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/Superhero-male/Superhero_Male_FullBody.gltf'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.name = 'Armature'
rig.animation_data_clear()
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'


def rotation(axis, degrees):
    return Quaternion(Vector(axis), math.radians(degrees)).to_matrix().to_4x4()


def set_world(name, matrix):
    pb = rig.pose.bones[name]
    # Explicit local conversion avoids stale dependency-graph parent matrices.
    pb.matrix_basis = pb.bone.convert_local_to_pose(
        matrix, pb.bone.matrix_local,
        parent_matrix=rig.pose.bones[pb.parent.name].matrix if pb.parent else Matrix.Identity(4),
        parent_matrix_local=pb.parent.bone.matrix_local if pb.parent else Matrix.Identity(4),
        invert=True)
    bpy.context.view_layer.update()


def point(name):
    return rig.pose.bones[name].matrix.translation.copy()


def aim(name, origin, destination):
    direction = (Vector(destination) - Vector(origin)).normalized()
    bone = rig.data.bones[name]
    original = (bone.tail_local - bone.head_local).normalized()
    orient = original.rotation_difference(direction).to_matrix().to_4x4() @ rest[name]
    orient.translation = Vector(origin)
    set_world(name, orient)


def limb(upper, lower, end, target, pole):
    origin = point(upper)
    target = Vector(target)
    a = (rest[lower].translation - rest[upper].translation).length
    b = (rest[end].translation - rest[lower].translation).length
    direction = target - origin
    distance = min(direction.length, (a + b) * .997)
    direction.normalize()
    x = (a*a - b*b + distance*distance) / (2*distance)
    height = math.sqrt(max(0, a*a - x*x))
    bend = Vector(pole) - origin
    bend = (bend - direction * bend.dot(direction)).normalized()
    elbow = origin + direction*x + bend*height
    aim(upper, origin, elbow)
    aim(lower, elbow, origin + direction*distance)


def orient_hand(side, palm):
    name = 'hand_' + side
    forward = (point(name) - point('lowerarm_' + side)).normalized()
    down = Vector(palm)
    down = (down - forward * down.dot(forward)).normalized()
    sign = 1 if side == 'l' else -1
    # Map the bind hand's longitudinal X and palm-facing -Z to the target frame.
    x = forward * sign
    z = -down
    y = z.cross(x).normalized()
    z = x.cross(y).normalized()
    matrix = Matrix((x, y, z)).transposed().to_4x4() @ rest[name]
    matrix.translation = point(name)
    set_world(name, matrix)


def fist(side):
    sign = 1 if side == 'l' else -1
    for finger in ['index', 'middle', 'ring', 'pinky']:
        for joint, angle in [(1, 72), (2, 92), (3, 68)]:
            name = f'{finger}_{joint:02}_{side}'
            axis = rest[name].to_quaternion().inverted() @ Vector((0, sign, 0))
            rig.pose.bones[name].rotation_quaternion = Quaternion(axis, math.radians(angle))
    # Thumb wraps across the curled fingers, outside the fist.
    for joint, angle in [(1, 48), (2, 38), (3, 28)]:
        name = f'thumb_{joint:02}_{side}'
        axis = rest[name].to_quaternion().inverted() @ Vector((0, -.25*sign, sign))
        rig.pose.bones[name].rotation_quaternion = Quaternion(axis.normalized(), math.radians(angle))


# A shared compact guard lets either punch end naturally or queue into the next.
GUARD = dict(hip=(0, .015, -.085), yaw=-10, twist=-8, lean=4, side=0,
             left=(.25, -.24, 1.39), right=(-.25, -.18, 1.38),
             lpole=(.62, .0, 1.05), rpole=(-.62, .10, 1.03),
             lfoot=(.21, -.19, .088), rfoot=(-.22, .22, .088),
             lturn=-8, rturn=18, heel=0, palm_l=(0, 1, -.2), palm_r=(0, 1, -.2))


def pose(**kwargs):
    return dict(GUARD, **kwargs)


CLIPS = {
    'Hero_Cross': [
        (0.00, pose()),
        (0.08, pose(hip=(-.055,.055,-.12), yaw=-24, twist=-22, lean=-3,
                    right=(-.36,.04,1.35), left=(.24,-.24,1.42))),
        (0.14, pose(hip=(-.02,.015,-.075), yaw=-3, twist=-15, lean=6,
                    right=(-.31,-.17,1.4))),
        (0.20, pose(hip=(.035,-.045,-.045), yaw=26, twist=20, lean=10,
                    right=(-.065,-.68,1.46), left=(.29,-.19,1.44),
                    rpole=(-.5,-.25,1.4), palm_r=(0,0,-1), rturn=40, heel=.045)),
        (0.27, pose(hip=(.04,-.055,-.06), yaw=31, twist=24, lean=12,
                    right=(.04,-.66,1.40), left=(.30,-.14,1.42),
                    rpole=(-.40,-.29,1.38), palm_r=(0,0,-1), rturn=45, heel=.05)),
        (0.39, pose(hip=(.02,-.01,-.09), yaw=15, twist=8, lean=5,
                    right=(-.18,-.32,1.38), left=(.27,-.20,1.42), rturn=26, heel=.02)),
        (0.55, pose(yaw=-7, twist=-4)),
        (0.70, pose()),
    ],
    'Hero_Hook': [
        (0.00, pose()),
        (0.085, pose(hip=(.055,.015,-.14), yaw=24, twist=20, lean=4,
                    left=(.46,-.02,1.37), right=(-.21,-.21,1.43), lpole=(.75,.18,1.34))),
        (0.145, pose(hip=(.035,-.025,-.10), yaw=7, twist=18, lean=7,
                    left=(.50,-.32,1.45), lpole=(.75,-.05,1.46), palm_l=(0,0,-1))),
        (0.20, pose(hip=(-.045,-.04,-.07), yaw=-30, twist=-24, lean=7, side=-5,
                    left=(.03,-.60,1.46), right=(-.24,-.16,1.43),
                    lpole=(.52,-.36,1.46), palm_l=(0,0,-1), lturn=-37)),
        (0.28, pose(hip=(-.06,-.02,-.10), yaw=-44, twist=-32, lean=8, side=-7,
                    left=(-.37,-.39,1.43), right=(-.23,-.07,1.42),
                    lpole=(.20,-.5,1.43), palm_l=(0,0,-1), lturn=-48)),
        (0.42, pose(hip=(-.03,.01,-.12), yaw=-26, twist=-17, lean=6,
                    left=(-.04,-.28,1.36), right=(-.3,-.05,1.37), lturn=-24)),
        (0.60, pose(yaw=-12, twist=-10)),
        (0.76, pose()),
    ],
    'Hero_FlyingUppercut': [
        (0.00, pose()),
        (0.10, pose(hip=(-.03,.07,-.25), yaw=-25, twist=-20, lean=16, side=-9,
                    right=(-.34,-.04,1.03), left=(.21,-.24,1.29))),
        (0.16, pose(hip=(-.025,.035,-.21), yaw=-17, twist=-20, lean=12, side=-6,
                    right=(-.31,-.19,1.09), left=(.23,-.24,1.34))),
        (0.20, pose(hip=(.01,-.01,-.12), yaw=3, twist=4, lean=4,
                    right=(-.16,-.43,1.36), left=(.25,-.21,1.40), palm_r=(0,1,0))),
        (0.25, pose(hip=(.01,-.015,-.005), yaw=20, twist=14, lean=-7,
                    right=(-.12,-.39,1.69), left=(.30,-.13,1.44),
                    rpole=(-.40,-.35,1.38), rturn=35, heel=.06, palm_r=(0,1,0))),
        (0.34, pose(hip=(0,0,.015), yaw=34, twist=17, lean=-11, side=7,
                    right=(-.10,-.25,1.98), left=(.35,-.04,1.39),
                    rpole=(-.38,-.33,1.72), palm_r=(0,1,0),
                    lfoot=(.20,-.30,.54), rfoot=(-.22,.34,.33), lturn=-5, rturn=34)),
        (0.53, pose(hip=(0,0,0), yaw=30, twist=12, lean=-8, side=6,
                    right=(-.09,-.23,1.95), left=(.32,-.03,1.39),
                    rpole=(-.38,-.30,1.72), palm_r=(0,1,0),
                    lfoot=(.20,-.24,.52), rfoot=(-.23,.31,.34), rturn=30)),
        (0.72, pose(hip=(0,0,-.025), yaw=10, twist=3, lean=0,
                    right=(-.21,-.22,1.65), left=(.28,-.17,1.40),
                    lfoot=(.21,-.14,.22), rfoot=(-.22,.22,.18))),
        (0.92, pose(hip=(0,.015,-.06), yaw=-10, twist=-8,
                    lfoot=(.21,-.19,.14), rfoot=(-.22,.22,.13))),
    ],
}


def apply_pose(p):
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    hip = rest['pelvis'].copy()
    hip = rotation((0,0,1), p['yaw']) @ hip
    hip.translation = rest['pelvis'].translation + Vector(p['hip'])
    set_world('pelvis', hip)
    for name, weight in [('spine_01',.25),('spine_02',.35),('spine_03',.40)]:
        pb = rig.pose.bones[name]
        pivot = pb.matrix.translation.copy()
        mat = (rotation((0,0,1),p['twist']*weight) @ rotation((1,0,0),p['lean']*weight)
               @ rotation((0,1,0),p['side']*weight) @ pb.matrix)
        mat.translation = pivot
        set_world(name, mat)
    for name, weight in [('neck_01', .35), ('Head', .65)]:
        pb = rig.pose.bones[name]
        mat = rotation((0,0,1), -(p['yaw']+p['twist'])*.8*weight) @ pb.matrix
        mat.translation = pb.matrix.translation
        set_world(name, mat)
    for side in ['l','r']:
        # Foot targets remain planted while the pelvis and torso coil above them.
        target = Vector(p[side+'foot'])
        if side == 'r':
            target.z += p['heel']
        limb('thigh_'+side, 'calf_'+side, 'foot_'+side, target,
             (target.x,-1,.55))
        foot = rotation((0,0,1),p[side+'turn']) @ rotation((1,0,0),-p['heel']*220) @ rest['foot_'+side]
        foot.translation = point('foot_'+side)
        set_world('foot_'+side, foot)
        limb('upperarm_'+side, 'lowerarm_'+side, 'hand_'+side,
             p['left' if side == 'l' else 'right'], p[side+'pole'])
        orient_hand(side, p['palm_'+side])
        fist(side)
    bpy.context.view_layer.update()


def sample(keys, time):
    for i in range(len(keys)-1):
        ta, a = keys[i]
        tb, b = keys[i+1]
        if time <= tb + 1e-8:
            f = max(0, min(1,(time-ta)/(tb-ta)))
            # Smooth acceleration inside each deliberately unevenly spaced beat.
            f = f*f*(3-2*f)
            return {key: tuple(x+(y-x)*f for x,y in zip(a[key],b[key]))
                    if isinstance(a[key],tuple) else a[key]+(b[key]-a[key])*f for key in a}
    return keys[-1][1]


actions = []
rig.animation_data_create()
scene = bpy.context.scene
scene.render.fps = FPS
for name, keys in CLIPS.items():
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    end = round(keys[-1][0]*FPS)+1
    for frame in range(1,end+1):
        scene.frame_set(frame)
        apply_pose(sample(keys,(frame-1)/FPS))
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
            if pb.name == 'pelvis':
                pb.keyframe_insert('location',frame=frame,group=pb.name)
    # Dense baked keys use linear interpolation to preserve the authored arcs.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
    actions.append(action)
    print('AUTHORED',name,end,'frames')

rig.animation_data.action = actions[0]
scene.frame_start = 1
scene.frame_end = 43
scene.frame_set(13)
# GLB contains the rig and three clips only. The .blend retains the textured hero.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'hero_combo.glb'), export_format='GLB',
    use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_range=False, export_nla_strips=False,
    export_anim_slide_to_zero=True,
    export_anim_single_armature=True, export_skins=True, export_all_influences=True)

# A neutral studio is included in the editable source for animation review.
bpy.ops.mesh.primitive_plane_add(size=200)
floor = bpy.context.object
floor.name = 'Preview Ground (not exported)'
mat = bpy.data.materials.new('Studio slate')
mat.diffuse_color = (.085,.105,.14,1)
floor.data.materials.append(mat)
scene.world = bpy.data.worlds.new('Studio World')
scene.world.color = (.22,.22,.22)
for name, location, power, size in [('Key',(3,-4,6),1100,4),('Fill',(-4,-2,3),850,4),('Rim',(1,3,5),1600,3)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    lamp = bpy.context.object
    lamp.name = name
    lamp.data.energy = power
    lamp.data.shape = 'DISK'
    lamp.data.size = size
    lamp.rotation_euler = (Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3.4,-5.2,2.8))
camera = bpy.context.object
camera.rotation_euler = (Vector((0,-.05,1.02))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.65
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
for image in bpy.data.images:
    if image.source == 'FILE':
        try: image.pack()
        except RuntimeError: pass
# Prevent Godot from also importing the editable Blender source.
source = OUT/'source'
source.mkdir(exist_ok=True)
(source/'.gdignore').touch()
bpy.ops.wm.save_as_mainfile(filepath=str(source/'hero_combo.blend'))
QA.mkdir(exist_ok=True)
for action in actions:
    rig.animation_data.action = action
    for frame in ([7,13,18] if action.name != 'Hero_FlyingUppercut' else [7,16,24]):
        scene.frame_set(frame)
        scene.render.filepath = str(QA/f'{action.name}_{frame:02}.png')
        bpy.ops.render.render(write_still=True)
print('DONE: three original Blender actions and hero_combo.glb')
