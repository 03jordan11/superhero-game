"""Append the charged-punch trio to the existing shared-rig combat library in Blender."""
import ast
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/animations/authored-combo'
QA = ROOT / 'artifacts/charge_punch'
QA.mkdir(parents=True, exist_ok=True)
FPS = 60
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/hero_combat_grabs.blend'))
bpy.context.preferences.filepaths.save_version = 0
rig = bpy.data.objects['Armature']
scene = bpy.context.scene
scene.render.fps = FPS
victim = bpy.data.objects.get('VictimPreview')
if victim:
    for obj in list(victim.children_recursive): bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(victim, do_unlink=True)
rest = {b.name:b.matrix_local.copy() for b in rig.data.bones}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
tree = ast.parse((OUT/'tools/build_combo.py').read_text())
helpers = [n for n in tree.body if isinstance(n,ast.FunctionDef) or isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='GUARD' for t in n.targets)]
exec(compile(ast.Module(body=helpers,type_ignores=[]),'combo_helpers','exec'))
rear = pose(hip=(-.06,.07,-.14),yaw=-30,twist=-22,lean=-8,
    right=(-.26,.15,1.24),rpole=(-.60,.38,1.15),left=(.27,-.30,1.46),
    lfoot=(.22,-.24,.088),rfoot=(-.24,.30,.088))
strike = pose(hip=(.06,-.08,-.10),yaw=30,twist=22,lean=16,
    right=(-.04,-.74,1.44),rpole=(-.45,-.35,1.4),left=(.31,-.09,1.41),
    palm_r=(0,0,-1),rturn=42,heel=.07,lfoot=(.22,-.24,.088),rfoot=(-.24,.30,.088))
clips = {
 'Hero_ChargePunchWindup': {'duration':.4,'loop':False,'keys':[(0,pose()),(.4,rear)]},
 'Hero_ChargePunchHold': {'duration':1.5,'loop':True,'keys':[(0,rear),(.75,dict(rear,lean=-7,twist=-23)),(1.5,rear)]},
 'Hero_ChargePunchRelease': {'duration':.7,'loop':False,'impact':.2,'keys':[(0,rear),(.10,dict(rear,lean=2,yaw=-12)),(.2,strike),(.28,strike),(.48,pose(yaw=10,twist=8)),(.7,pose())]},
}
for name,spec in clips.items():
    action=bpy.data.actions.new(name); action.use_fake_user=True
    rig.animation_data.action=action
    for i in range(round(spec['duration']*FPS)+1):
        scene.frame_set(i+1)
        apply_pose(sample(spec['keys'],i/FPS))
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_quaternion',frame=i+1,group=pb.name)
            if pb.name=='pelvis': pb.keyframe_insert('location',frame=i+1,group=pb.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    if 'impact' in spec: action.pose_markers.new('impact').frame=round(spec['impact']*FPS)+1
    print('BAKED',name,flush=True)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'hero_combo.glb'),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
    export_frame_range=False,export_nla_strips=False,export_anim_slide_to_zero=True,
    export_anim_single_armature=True,export_skins=True,export_all_influences=True)
(OUT/'charge_punch_manifest.json').write_text(json.dumps({'fps':FPS,'clips':[dict(name=n,**{k:v for k,v in s.items() if k!='keys'}) for n,s in clips.items()]},indent=2)+'\n')
rig.animation_data.action=bpy.data.actions['Hero_ChargePunchWindup']
scene.frame_start=1; scene.frame_end=25; scene.frame_set(25)
scene.render.resolution_x=960; scene.render.resolution_y=720
scene.cycles.samples=12
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/hero_charge_punch.blend'))
for name,time in [('Hero_ChargePunchWindup',.4),('Hero_ChargePunchHold',.75),('Hero_ChargePunchRelease',.2)]:
    rig.animation_data.action=bpy.data.actions[name]
    rig.animation_data.action_slot=bpy.data.actions[name].slots[0]
    scene.frame_set(round(time*FPS)+1)
    scene.render.filepath=str(QA/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('CHARGE_PUNCH_LIBRARY_COMPLETE',flush=True)
