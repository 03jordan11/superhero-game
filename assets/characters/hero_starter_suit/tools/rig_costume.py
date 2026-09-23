"""Fit the refined starter suit to the unchanged gameplay armature.
Run after refine_costume.py, using Blender --background --factory-startup.
"""
import bpy
import hashlib
import json
import struct
import sys
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'assets/characters/hero_starter_suit'
SOURCE=OUT/'hero_starter_suit.glb'
sys.path.insert(0,str(ROOT/'assets/characters/hero_meshy/tools'))
from costume_shapes import smooth
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/Superhero-male/Superhero_Male_FullBody.gltf'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.name='Armature';rig.animation_data_clear()
for bone in rig.pose.bones: bone.matrix_basis.identity()
donor=bpy.data.objects['SuperHero_Male']
donor.animation_data_clear()
for modifier in list(donor.modifiers): donor.modifiers.remove(modifier)
for obj in list(bpy.data.objects):
    if obj not in (rig,donor): bpy.data.objects.remove(obj,do_unlink=True)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
hero=next(o for o in set(bpy.data.objects)-before if o.type=='MESH')
hero.name='Hero_Starter_Suit'
bpy.ops.object.select_all(action='DESELECT')
hero.select_set(True);bpy.context.view_layer.objects.active=hero
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
mesh=hero.data
uv_before=np.array([tuple(v.uv) for v in mesh.uv_layers.active.data])
faces_before=[tuple(p.vertices) for p in mesh.polygons]
colors_before=np.array([tuple(c.color) for c in mesh.color_attributes.active_color.data])
scale=1.8131932
original=np.array([tuple(v.co*scale+Vector((0,0,scale/2))) for v in mesh.vertices])

def interp(value,anchors):
    return float(np.interp(value,[p[0] for p in anchors],[p[1] for p in anchors]))

for v,point in zip(mesh.vertices,original):
    x,y,z=point;ax=abs(x);side=1 if x>=0 else -1
    result=Vector((x,y,z))
    # Narrow the generated wide stance around the existing knee/ankle joints.
    result.x-=side*.075*(1-smooth(.18,.85,z))*smooth(.015,.07,ax)
    result.y+=interp(z,[(0,.075),(.18,.065),(.55,.025),(1.30,.025),(1.52,0)])
    arm_blend=smooth(.15,.25,ax)*smooth(1.27,1.35,z)
    if arm_blend:
        arm=Vector((side*interp(ax,[(0,0),(.15,.15),(.20,.212),(.40,.463),(.58,.707),(.60,.735),(1,1.135)]),
            y+.025,z+interp(ax,[(.15,0),(.25,.012),(.42,.027),(.60,.040)])))
        result=result.lerp(arm,arm_blend)
    v.co=result
mesh.update()
if mesh.has_custom_normals: mesh.normals_split_custom_set([(0.,0.,0.)]*len(mesh.loops))
for group in donor.vertex_groups: hero.vertex_groups.new(name=group.name)
transfer=hero.modifiers.new('Existing gameplay skin weights','DATA_TRANSFER')
transfer.object=donor;transfer.use_vert_data=True
transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST'
transfer.layers_vgroup_select_src='ALL';transfer.layers_vgroup_select_dst='NAME'
bpy.ops.object.modifier_apply(modifier=transfer.name)

def assign(vertex,pairs):
    merged={}
    for name,weight in pairs:
        if weight>1e-5: merged[name]=merged.get(name,0)+weight
    pairs=sorted(merged.items(),key=lambda p:-p[1])[:4]
    total=sum(w for _,w in pairs)
    assert total>0
    for group in list(vertex.groups): hero.vertex_groups[group.group].remove([vertex.index])
    for name,weight in pairs: hero.vertex_groups[name].add([vertex.index],weight/total,'REPLACE')

def chain(value,anchors):
    if value<=anchors[0][0]: return [(anchors[0][1],1)]
    for (a,first),(b,second) in zip(anchors,anchors[1:]):
        if value<=b:
            t=smooth(a,b,value)
            return [(first,1-t),(second,t)]
    return [(anchors[-1][1],1)]

for v in mesh.vertices:
    x,y,z=v.co;ax=abs(x);side='l' if x>=0 else 'r'
    if z>1.47 and ax<.23:
        # Keep the face and upper hood rigid, but taper the lower hood's
        # influence across the collar. A rectangular head/neck mask reached
        # the shoulder cap and pulled it against the arm during running.
        head=smooth(1.47,1.54,z)
        collar=1-smooth(.105,.185,ax)
        hood=smooth(1.525,1.54,z)
        influence=collar+(1-collar)*hood
        transferred=[(hero.vertex_groups[g.group].name,g.weight*(1-influence)) for g in v.groups]
        assign(v,transferred+[('Head',head*influence),('neck_01',(1-head)*influence)])
    elif .94<z<1.17 and ax<.23:
        # The hoodie hem and belt share the torso, not the nearest moving
        # thigh surface. This prevents small waist triangles peeling apart.
        assign(v,chain(z,[(.94,'pelvis'),(1.17,'spine_01')]))
    elif ax>.705 and z>1.3:
        thumb=smooth(-.035,-.008,-y)*(1-smooth(.827,.85,ax))
        if thumb>.05:
            bones=[rig.data.bones[f'thumb_{i:02}_{side}'] for i in (1,2,3)]
            origin=bones[0].head_local;axis=(bones[-1].head_local-origin).normalized()
            pairs=chain((v.co-origin).dot(axis),[(float((b.head_local-origin).dot(axis)),b.name) for b in bones])
            assign(v,[(name,w*thumb) for name,w in pairs]+[('hand_'+side,1-thumb)])
        else: assign(v,chain(ax,[(.785,'hand_'+side),(.855,'middle_01_'+side)]))
    else: assign(v,[(hero.vertex_groups[g.group].name,g.weight) for g in v.groups])

seams={}
for v,point in zip(mesh.vertices,original):
    key=tuple(point)
    if key not in seams: seams[key]=[(hero.vertex_groups[g.group].name,g.weight) for g in v.groups]
    else: assign(v,seams[key])
assert faces_before==[tuple(p.vertices) for p in mesh.polygons]
assert np.array_equal(uv_before,np.array([tuple(v.uv) for v in mesh.uv_layers.active.data]))
assert np.array_equal(colors_before,np.array([tuple(c.color) for c in mesh.color_attributes.active_color.data]))
for obj in list(bpy.data.objects):
    if obj not in (rig,hero): bpy.data.objects.remove(obj,do_unlink=True)
hero.parent=rig
modifier=hero.modifiers.new('Gameplay armature','ARMATURE');modifier.object=rig
rig.show_in_front=True
for action in list(bpy.data.actions): bpy.data.actions.remove(action)
for image in bpy.data.images:
    if image.has_data: image.pack()
bpy.ops.object.select_all(action='DESELECT')
hero.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=hero
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/hero_starter_suit_rigged.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'hero_starter_suit_rigged.glb'),export_format='GLB',use_selection=True,
    export_animations=False,export_apply=True,export_def_bones=False,export_all_influences=False,
    export_yup=True,export_vertex_color='ACTIVE')
raw=(OUT/'hero_starter_suit_rigged.glb').read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n])
report={'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'triangles':sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives']),
    'joints':len(doc['skins'][0]['joints']),'max_influences':max(len(v.groups) for v in mesh.vertices),
    'uvs_and_lip_colors_unchanged':True,'added_triangles':0,
    'method':'Existing gameplay armature, fitted stance/arms, transferred weights, tapered collar/shoulder blend, rigid face/upper hood, coherent mitten and thumb weights',
    'shoulder_blend':{'collar_half_width_m':[.105,.185],'upper_hood_height_m':[1.525,1.54]}}
assert report['triangles']==2172 and report['joints']==65 and report['max_influences']<=4
(OUT/'rig_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('STARTER_SUIT_RIG_PASS',json.dumps(report))
