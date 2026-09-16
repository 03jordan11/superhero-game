"""Blender authoring/baking of matched throat-grab actions on the shared rig.
Run from any directory with Blender --background --python this_file.py.
Preserves the three original combo actions; exports the combined combat library.
Paired characters share an actor origin. Victim pelvis translation is intentional.
"""
import ast
import json
import math
import os
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/animations/authored-combo'
QA = ROOT / 'artifacts/grab_animations'
QA.mkdir(parents=True, exist_ok=True)
FPS = 60
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/hero_combo.blend'))
rig = bpy.data.objects['Armature']
originals = list(bpy.data.actions)
scene = bpy.context.scene
scene.render.fps = FPS
# Original actions were authored at 60 fps: retain their exact duration/curves.
for action in originals:
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        for co in [key.co, key.handle_left, key.handle_right]:
                            co.x = 1 + (co.x-1)*FPS/60
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
# Reuse the established two-bone IK and hand authoring tools, without running
# the original builder or replacing its three actions.
tree = ast.parse((OUT/'tools/build_combo.py').read_text())
nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) or
         isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id=='GUARD' for t in n.targets)]
exec(compile(ast.Module(body=nodes, type_ignores=[]), 'combo_pose_helpers', 'exec'))

existing_objects = set(bpy.data.objects)
existing_actions = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/animations/UAL1_Standard.glb'))
reference = next(o for o in bpy.data.objects if o not in existing_objects and o.type=='ARMATURE')
reference.name='LocomotionReference'
reference_actions = [a for a in bpy.data.actions if a not in existing_actions]
walk = next(a for a in reference_actions if a.name.startswith('Walk_Loop'))
run = next(a for a in reference_actions if a.name.startswith('Jog_Fwd_Loop'))
lower_bones = ['pelvis']+[b.name for b in rig.pose.bones if b.name.startswith(('thigh_', 'calf_', 'foot_', 'ball_'))]
baseline = {}
for name, action in [('Walk',walk),('Run',run)]:
    reference.animation_data.action=action
    start,end=action.frame_range
    samples=[]
    for i in range(121):
        frame=start+(end-start)*i/120
        scene.frame_set(int(frame), subframe=frame%1)
        samples.append({b.name:b.matrix_basis.copy() for b in reference.pose.bones})
    baseline[name]=samples
for obj in list(bpy.data.objects):
    if obj not in existing_objects: bpy.data.objects.remove(obj,do_unlink=True)
for action in reference_actions: bpy.data.actions.remove(action)

HOLD=pose(hip=(0,.015,-.025),yaw=-5,twist=4,lean=-3,
    right=(-.40,-.48,1.77),rpole=(-.67,-.06,1.43),palm_r=(0,-1,0),
    left=(.33,-.025,1.0),lpole=(.62,.08,1.18),palm_l=(-1,0,0),
    lfoot=(.16,-.05,.088),rfoot=(-.16,.075,.088),lturn=0,rturn=0)
def held(**kw): return dict(HOLD,**kw)
def keys(*rows): return list(rows)
CLIPS={
 'Grab': dict(duration=.6,loop=False,events={'grip':.2,'lift_complete':.6},keys=keys(
    (0,held(right=(-.33,-.04,1.05))),(.2,held(right=(-.4,-.48,1.48),lean=7)),
    (.36,held(right=(-.4,-.48,1.60),hip=(0,.03,-.075))),(.6,held()))),
 'Hold':dict(duration=2.4,loop=True),
 'CarryWalk':dict(duration=1.333333,loop=True,baseline='Walk'),
 'CarryRun':dict(duration=.933333,loop=True,baseline='Run'),
 'CarryFlightHover':dict(duration=2.4,loop=True,flight=0),
 'CarryFlightMove':dict(duration=2.0,loop=True,flight=22),
 'CarryFlightFast':dict(duration=1.6,loop=True,flight=78),
 'ThrowCharge':dict(duration=.6,loop=False,keys=keys((0,held()),(.6,held(
    hip=(-.05,.07,-.12),yaw=-28,twist=-18,lean=-8,right=(-.48,-.03,1.82),
    left=(.40,-.26,1.18),rpole=(-.72,.16,1.43))))),
 'ThrowHold':dict(duration=1.6,loop=True,charge=True),
 'ThrowRelease':dict(duration=.7,loop=False,events={'release':.3},keys=keys(
    (0,held(hip=(-.05,.07,-.12),yaw=-28,twist=-18,lean=-8,right=(-.48,-.03,1.82),left=(.40,-.26,1.18),rpole=(-.72,.16,1.43))),
    (.18,held(yaw=8,twist=12,right=(-.32,-.4,1.73),lean=10)),
    (.3,held(yaw=23,twist=20,right=(-.2,-.67,1.65),lean=14,rpole=(-.45,-.4,1.4))),
    (.43,held(yaw=30,twist=23,right=(-.1,-.66,1.40),lean=16)),
    (.7,held(right=(-.31,-.06,1.0),yaw=0,twist=0,lean=0)))),
}
for index,duration,impact in [(1,1.0,.36),(2,1.0,.36),(3,1.2,.44)]:
    side=-1 if index==2 else 1
    CLIPS['Slam%d'%index]=dict(duration=duration,loop=False,events={'impact':impact,**({'release':impact} if index==3 else {'lift_complete':duration})},keys=keys(
      (0,held()),(.16,held(hip=(0,.03,-.08),right=(-.38,-.42,1.86),yaw=-12*side,twist=-10*side)),
      (impact,held(hip=(0,-.12,-.70),right=(-.4,-.60,.21),rpole=(-.65,-.4,.45),lean=95,yaw=10*side,twist=8*side,left=(.47,-.12,.72))),
      (impact+.10,held(hip=(0,-.12,-.70),right=(-.4,-.60,.21),rpole=(-.65,-.4,.45),lean=95,yaw=10*side,twist=8*side,left=(.47,-.12,.72))),
      (duration,held() if index<3 else held(right=(-.32,-.05,1.0),yaw=0,twist=0,lean=0))))

def rotate_pose_bone(name, axis, degrees):
    pb=rig.pose.bones[name]
    mat=rotation(axis,degrees)@pb.matrix
    mat.translation=pb.matrix.translation
    set_world(name,mat)

def curl(side, strength):
    fist(side)
    for pb in rig.pose.bones:
        if pb.name.endswith('_'+side) and pb.name.startswith(('index','middle','ring','pinky','thumb')):
            pb.rotation_quaternion=Quaternion().slerp(pb.rotation_quaternion,strength)

def hero_pose(name,spec,t):
    phase=t/spec['duration']*math.tau
    p=sample(spec['keys'],t) if 'keys' in spec else held()
    if spec.get('charge'):
        p=sample(CLIPS['ThrowCharge']['keys'],.6)
    if spec['loop']:
        bob=.007*math.sin(phase)
        p['hip']=tuple(Vector(p['hip'])+Vector((0,0,bob)))
        p['right']=tuple(Vector(p['right'])+Vector((0,0,bob)))
    apply_pose(p)
    if 'baseline' in spec:
        bases=baseline[spec['baseline']][round(t/spec['duration']*120)%121]
        for bone in lower_bones+['upperarm_l','lowerarm_l','hand_l']:
            rig.pose.bones[bone].matrix_basis=bases[bone]
        bpy.context.view_layer.update()
        limb('upperarm_r','lowerarm_r','hand_r',p['right'],p['rpole'])
        orient_hand('r',(0,-1,0))
    if 'flight' in spec:
        pitch=spec['flight']
        rotate_pose_bone('pelvis',(1,0,0),pitch)
        rotate_pose_bone('neck_01',(1,0,0),-pitch*.35)
        rotate_pose_bone('Head',(1,0,0),-pitch*.45)
        # Keep the forearm up/front while the torso and legs become horizontal.
        wrist=(-.40,-.56,1.70) if pitch>60 else (-.4,-.48,1.77)
        limb('upperarm_r','lowerarm_r','hand_r',wrist,(-.67,-.28,1.45))
        orient_hand('r',(0,-1,0))
        for side in ['l','r']:
            rotate_pose_bone('foot_'+side,(1,0,0),38 if pitch>60 else 15)
    amount=.65
    if name=='Grab': amount=.1+.55*min(t/.2,1)
    if name=='ThrowRelease' and t>=.3: amount=.05
    if name=='Slam3' and t>=.44: amount=.08
    curl('r',amount); curl('l',.35)
    bpy.context.view_layer.update()
    # Center of the curled fingers, expressed in the original hand's space.
    anchor=rig.pose.bones['hand_r'].matrix @ rest['hand_r'].inverted() @ (rest['hand_r'].translation+Vector((-.075,-.018,0)))
    return anchor

def victim_pose(name,spec,t,anchor):
    for pb in rig.pose.bones: pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    phase=t/spec['duration']*math.tau
    pitch=0.0
    if 'flight' in spec: pitch=55 if spec['flight']>60 else spec['flight']*.7
    if name.startswith('Slam'):
        impact=spec['events']['impact']
        if t<.16: factor=0
        elif t<impact: factor=(t-.16)/(impact-.16)
        elif t<impact+.10 or name=='Slam3': factor=1
        else: factor=1-(t-impact-.10)/(spec['duration']-impact-.10)
        factor=max(0,min(1,factor)); factor=factor*factor*(3-2*factor)
        pitch=-90*factor
    orientation=rotation((1,0,0),pitch)@rotation((0,0,1),180)
    if name.startswith('Slam'):
        # Sweep the victim to the player's right and onto their back, keeping
        # their legs clear of the player's planted feet and bent knees.
        start=rotation((0,0,1),180).to_quaternion()
        end=(rotation((0,0,1),90)@rotation((1,0,0),90)@rotation((0,0,1),180)).to_quaternion()
        orientation=start.slerp(end,factor).to_matrix().to_4x4()
    hip=orientation@rest['pelvis']; hip.translation=rest['pelvis'].translation
    set_world('pelvis',hip)
    rotate_pose_bone('Head',(1,0,0),-6)
    for side,sign in [('l',1),('r',-1)]:
        # Asymmetric, periodic struggle; all loops join exactly.
        kick=math.sin(phase*(2 if side=='l' else 3)+sign*.65)
        rig.pose.bones['thigh_'+side].rotation_quaternion=Quaternion((1,0,0),math.radians(12+kick*11))
        rig.pose.bones['calf_'+side].rotation_quaternion=Quaternion((1,0,0),math.radians(-22-abs(kick)*22))
        rig.pose.bones['foot_'+side].rotation_quaternion=Quaternion((1,0,0),math.radians(15+kick*8))
    if name.startswith('Slam') and abs(pitch)>75:
        for side in ['l','r']:
            rig.pose.bones['thigh_'+side].rotation_quaternion=Quaternion()
            rig.pose.bones['calf_'+side].rotation_quaternion=Quaternion((1,0,0),math.radians(-8))
    bpy.context.view_layer.update()
    # Move the pelvis, not root, to put the throat inside the player's grip.
    neck=point('neck_01')
    destination=anchor+Vector((0,-.025,-.005))
    if name=='Grab' and t<.2:
        destination=Vector((-.4,-.58,1.56))
    if name=='Slam3' and t>=spec['events']['release']:
        destination=Vector(RELEASE_ANCHORS['Slam3'])+Vector((0,-.025,-.005))
    if name=='ThrowRelease' and t>=.3:
        # Flight path belongs to future gameplay. This is only the release pose.
        destination=Vector(RELEASE_ANCHORS['ThrowRelease'])+Vector((0,-.025,-.005))
    hip=rig.pose.bones['pelvis'].matrix.copy(); hip.translation+=destination-neck
    set_world('pelvis',hip)
    neck=point('neck_01')
    for side,sign in [('l',1),('r',-1)]:
        target=neck+Vector((sign*.09,.065,-.12 if side=='l' else -.10))
        if name=='Grab' and t<.2:
            target=target.lerp(point('upperarm_'+side)+Vector((0,0,-.48)),1-t/.2)
        if (name=='ThrowRelease' and t>.3) or (name=='Slam3' and t>.44):
            f=min(1,(t-(.3 if name=='ThrowRelease' else .44))/.25)
            target=target.lerp(neck+Vector((sign*.43,-.05,-.32)),f)
        limb('upperarm_'+side,'lowerarm_'+side,'hand_'+side,target,neck+Vector((sign*.5,.05,-.38)))
        orient_hand(side,(-sign,0,0)); curl(side,.32)
    bpy.context.view_layer.update()

RELEASE_ANCHORS={}
for name in ['ThrowRelease','Slam3']:
    rig.animation_data.action=None
    RELEASE_ANCHORS[name]=tuple(hero_pose(name,CLIPS[name],CLIPS[name]['events']['release']))

manifest={'fps':FPS,'pair_origin':'Shared actor origin and orientation; animate victim pelvis, never attach the already-offset victim clip to the hand.',
          'clips':[], 'baseline_sources':{'CarryWalk':'UAL1/Walk','CarryRun':'UAL1/Jog_Fwd','flight':'authored-flight pose workflow'}}
new_actions=[]
for name,spec in CLIPS.items():
    count=round(spec['duration']*FPS)
    spec['duration']=count/FPS
    anchors=[]
    for role in ['Hero','Victim']:
        action=bpy.data.actions.new(role+'_'+name); action.use_fake_user=True
        rig.animation_data.action=action
        for i in range(count+1):
            scene.frame_set(i+1)
            t=i/FPS
            if role=='Hero': anchors.append(tuple(hero_pose(name,spec,t)))
            else: victim_pose(name,spec,t,Vector(anchors[i]))
            for pb in rig.pose.bones:
                pb.keyframe_insert('rotation_quaternion',frame=i+1,group=pb.name)
                if pb.name=='pelvis': pb.keyframe_insert('location',frame=i+1,group=pb.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for k in curve.keyframe_points: k.interpolation='LINEAR'
        action['loop']=spec['loop']
        for event,time in spec.get('events',{}).items():
            action.pose_markers.new(event).frame=round(time*FPS)+1
        new_actions.append(action)
        manifest['clips'].append({'name':action.name,'pair':name,'role':role,'duration':spec['duration'],'loop':spec['loop'],'events':spec.get('events',{})})
        print('BAKED',action.name,count+1,flush=True)

rig.animation_data.action=new_actions[0]
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'hero_combo.glb'),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
    export_frame_range=False,export_nla_strips=False,export_anim_slide_to_zero=True,
    export_anim_single_armature=True,export_skins=True,export_all_influences=True)
(OUT/'grab_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

# A second copy of the same mesh/armature for paired source/pose review.
victim=rig.copy(); victim.data=rig.data.copy(); scene.collection.objects.link(victim)
victim.name='VictimPreview'; victim.animation_data_clear(); victim.animation_data_create()
for mesh in [o for o in list(bpy.data.objects) if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]:
    dup=mesh.copy(); dup.data=mesh.data.copy(); scene.collection.objects.link(dup)
    dup.parent=victim
    for mod in dup.modifiers:
        if mod.type=='ARMATURE': mod.object=victim
    for index,material in enumerate(dup.data.materials):
        if material:
            mat=material.copy(); dup.data.materials[index]=mat
            # A blue tint makes the two bodies readable in the preview.
            if mat.use_nodes:
                bsdf=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                if bsdf:
                    for link in list(bsdf.inputs['Base Color'].links): mat.node_tree.links.remove(link)
                    bsdf.inputs['Base Color'].default_value=(.12,.23,.36,1)
scene.render.engine='CYCLES'; scene.cycles.samples=16
scene.render.resolution_x=960; scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.view_settings.exposure=-1.0
scene.camera.location=(3.4,-5.0,2.8)
scene.camera.rotation_euler=(Vector((0,-.65,1.0))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=3.8
rig.animation_data.action=bpy.data.actions['Hero_Hold']
victim.animation_data.action=bpy.data.actions['Victim_Hold']
victim.animation_data.action_slot=bpy.data.actions['Victim_Hold'].slots[0]
scene.frame_start=1; scene.frame_end=round(CLIPS['Hold']['duration']*FPS)+1; scene.frame_set(1)
for image in bpy.data.images:
    if image.source=='FILE':
        try: image.pack()
        except RuntimeError: pass
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/hero_combat_grabs.blend'))
if not os.environ.get('GRAB_SKIP_RENDER'):
    for name,t in [('Grab',.2),('Hold',.3),('CarryRun',.23),('CarryFlightFast',.4),('ThrowHold',.2),('ThrowRelease',.3),('Slam1',.36),('Slam3',.7)]:
        rig.animation_data.action=bpy.data.actions['Hero_'+name]
        victim.animation_data.action=bpy.data.actions['Victim_'+name]
        victim.animation_data.action_slot=bpy.data.actions['Victim_'+name].slots[0]
        scene.frame_set(round(t*FPS)+1)
        scene.render.filepath=str(QA/(name+'.png'))
        bpy.ops.render.render(write_still=True)
print('GRAB_LIBRARY_COMPLETE',len(new_actions),'new clips',flush=True)
