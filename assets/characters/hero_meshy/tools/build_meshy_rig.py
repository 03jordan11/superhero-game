"""Fit the approved Meshy mesh to the existing player armature without remeshing.
Run with Blender --background --factory-startup --python this_file.py.
"""
import bpy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/characters/hero_meshy'
sys.path.insert(0, str(OUT/'tools'))
from costume_shapes import flatten_lips
SOURCE = OUT / 'source/meshy_reference_fro.glb'
(OUT/'source').mkdir(parents=True, exist_ok=True)
(OUT/'source/.gdignore').write_text('')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/Superhero-male/Superhero_Male_FullBody.gltf'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.name = 'Armature'; rig.animation_data_clear()
for bone in rig.pose.bones: bone.matrix_basis.identity()
donor = bpy.data.objects['SuperHero_Male']
donor.animation_data_clear()
for modifier in list(donor.modifiers): donor.modifiers.remove(modifier)
for obj in list(bpy.data.objects):
    if obj not in (rig, donor): bpy.data.objects.remove(obj, do_unlink=True)
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
hero = next(o for o in set(bpy.data.objects)-before if o.type == 'MESH')
hero.name = 'Meshy_Hero'
bpy.ops.object.select_all(action='DESELECT')
hero.select_set(True); bpy.context.view_layer.objects.active = hero
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh = hero.data
original = np.array([tuple(v.co) for v in mesh.vertices])
original_uvs = np.array([tuple(v.uv) for v in mesh.uv_layers.active.data])
original_faces = [tuple(p.vertices) for p in mesh.polygons]
assert len(mesh.polygons) == 1552 and all(len(p.vertices) == 3 for p in mesh.polygons)


def smooth(a, b, value):
    t = max(0., min(1., (value-a)/(b-a)))
    return t*t*(3-2*t)


def interpolate(value, anchors):
    return float(np.interp(value, [p[0] for p in anchors], [p[1] for p in anchors]))


def fit(point):
    # Source in Blender: X across, -Y forward, Z up, centered at half-height.
    x, y, z = point
    ax = abs(x); side = 1 if x >= 0 else -1
    height = interpolate(z, [(-.5, 0), (-.449, .0865), (-.195, .5424),
        (-.025, .96), (.065, 1.072), (.20, 1.31), (.30, 1.4555),
        (.355, 1.5205), (.381, 1.5998), (.503, 1.82)])
    torso = Vector((x*1.8, y*1.8+.023, height))
    leg_blend = 1-smooth(-.03, .085, z)
    leg_center = interpolate(z, [(-.5,.105),(-.449,.104),(-.195,.079),(-.025,.066),(.085,.065)])
    torso.x += side*(.1143-leg_center*1.8)*leg_blend
    depth_shift = interpolate(z,[(-.5,.038),(-.449,.04),(-.195,.025),(-.025,.043),(.085,.023)])
    torso.y += (depth_shift-.023)*leg_blend
    arm_blend = smooth(.095, .155, ax)*smooth(.20, .245, z)
    if arm_blend:
        source_height = interpolate(ax,[(.125,.300),(.235,.284),(.326,.278),(.422,.274)])
        source_depth = interpolate(ax,[(.125,-.025),(.235,-.025),(.326,.02),(.422,.077)])
        arm = Vector((side*interpolate(ax,[(0,0),(.095,.171),(.125,.212),(.235,.463),(.326,.7065),(.375,.8219),(.422,.92)]),
                      (y+source_depth)*1.8+.0654, 1.4555+(z-source_height)*1.8))
        # The thumb is forward of the palm. Fit its downward splay to the
        # existing thumb chain without adding finger geometry.
        thumb = smooth(.026,.054,-y-source_depth)*(1-smooth(.368,.393,ax))*smooth(.328,.343,ax)
        arm.z -= .045*thumb
        torso = torso.lerp(arm, arm_blend)
    return torso


for vertex in mesh.vertices: vertex.co = fit(vertex.co)
mesh.update()
# Clear imported split normals after the anatomical fit; recompute on the same
# triangles while preserving their original smooth/flat flags and UV seams.
if mesh.has_custom_normals:
    mesh.normals_split_custom_set([(0.,0.,0.)]*len(mesh.loops))
for group in donor.vertex_groups: hero.vertex_groups.new(name=group.name)
transfer = hero.modifiers.new('Existing player skin weights', 'DATA_TRANSFER')
transfer.object = donor; transfer.use_vert_data = True
transfer.data_types_verts = {'VGROUP_WEIGHTS'}; transfer.vert_mapping = 'POLYINTERP_NEAREST'
transfer.layers_vgroup_select_src = 'ALL'; transfer.layers_vgroup_select_dst = 'NAME'
bpy.ops.object.modifier_apply(modifier=transfer.name)


def assign(vertex, pairs):
    for membership in list(vertex.groups): hero.vertex_groups[membership.group].remove([vertex.index])
    pairs = sorted([(name, weight) for name, weight in pairs if weight > .00001], key=lambda p: -p[1])[:4]
    total = sum(w for _, w in pairs)
    assert total > 0, 'Unweighted vertex'
    for name, weight in pairs: hero.vertex_groups[name].add([vertex.index], weight/total, 'REPLACE')


def chain(value, anchors):
    if value <= anchors[0][0]: return [(anchors[0][1],1)]
    for (a, first), (b, second) in zip(anchors, anchors[1:]):
        if value <= b:
            t = smooth(a,b,value)
            return [(first,1-t),(second,t)]
    return [(anchors[-1][1],1)]


for vertex, source_point in zip(mesh.vertices, original):
    x,y,z = vertex.co; side = 'l' if x>=0 else 'r'
    ax=abs(x)
    if z > 1.50 and abs(source_point[0]) < .09:
        # The lowest chin/beard vertices reach 1.545 m. Keep the complete
        # lower face rigid, with all blending confined to the neck below it.
        head = smooth(1.50,1.54,z)
        assign(vertex,[('Head',head),('neck_01',1-head)])
    elif ax > .705 and z > 1.3:
        # Coherent mitten closure: index/ring/little animation tracks remain
        # available but cannot split or independently twist this finger block.
        raw_x, raw_y, _ = source_point
        source_depth = interpolate(abs(raw_x),[(.326,.02),(.422,.077)])
        thumb_factor = smooth(.017,.04,-raw_y-source_depth)*(1-smooth(.368,.393,abs(raw_x)))
        if thumb_factor > .1:
            thumb_bones = [rig.data.bones[f'thumb_{i:02}_{side}'] for i in (1,2,3)]
            origin=thumb_bones[0].head_local
            axis=(thumb_bones[-1].head_local-origin).normalized()
            position=(vertex.co-origin).dot(axis)
            pairs=chain(position,[(float((b.head_local-origin).dot(axis)),b.name) for b in thumb_bones])
            pairs=[(name,w*thumb_factor) for name,w in pairs]+[('hand_'+side,1-thumb_factor)]
        else:
            # A rigid finger block cannot make three tight knuckle folds
            # without crushing its sparse triangles. Bend it at the first
            # middle knuckle, blending into the palm, as a single mitten.
            pairs=chain(ax,[(.785,'hand_'+side),(.855,'middle_01_'+side)])
        assign(vertex,pairs)
    else:
        assign(vertex,[(hero.vertex_groups[g.group].name,g.weight) for g in vertex.groups])

# All duplicated seam vertices must deform identically.
groups = {}
for vertex, point in zip(mesh.vertices, original):
    key=tuple(point)
    if key not in groups:
        groups[key]=[(hero.vertex_groups[g.group].name,g.weight) for g in vertex.groups]
    else: assign(vertex,groups[key])

# Retract the pointed pectoral front only; preserve width, height, UVs and the
# fitted skin weights. Fade into the upper chest, ribs and abdomen.
before_chest = np.array([tuple(v.co) for v in mesh.vertices])
for vertex in mesh.vertices:
    x,y,z = vertex.co
    weight = smooth(1.285,1.34,z)*(1-smooth(1.41,1.475,z))
    weight *= 1-smooth(.12,.185,abs(x))
    front_limit = .068-.009*min(1.,(abs(x)/.16)**2)
    if weight > 0 and y < -front_limit:
        vertex.co.y += (-front_limit-y)*weight
mesh.update()
after_chest = np.array([tuple(v.co) for v in mesh.vertices])
chest_delta = after_chest-before_chest
moved_chest = np.linalg.norm(chest_delta,axis=1)>1e-8
assert np.all(chest_delta[:,1] >= 0) and np.all(chest_delta[:,[0,2]] == 0)
faces = np.array(original_faces)
old_normals = np.cross(before_chest[faces[:,1]]-before_chest[faces[:,0]],before_chest[faces[:,2]]-before_chest[faces[:,0]])
new_normals = np.cross(after_chest[faces[:,1]]-after_chest[faces[:,0]],after_chest[faces[:,2]]-after_chest[faces[:,0]])
assert np.all(np.einsum('ij,ij->i',old_normals,new_normals)>0), 'Chest face flipped'
lip_cleanup = flatten_lips(mesh, 'underwear')
head_group = hero.vertex_groups['Head'].index
for vertex in mesh.vertices:
    if vertex.co.z >= 1.54 and abs(vertex.co.x)<.17:
        assert len(vertex.groups)==1 and vertex.groups[0].group==head_group and vertex.groups[0].weight==1.0
assert original_faces == [tuple(p.vertices) for p in mesh.polygons]
assert np.array_equal(original_uvs,np.array([tuple(v.uv) for v in mesh.uv_layers.active.data]))
for obj in list(bpy.data.objects):
    if obj not in (rig,hero): bpy.data.objects.remove(obj,do_unlink=True)
hero.parent=rig
modifier=hero.modifiers.new('Existing 65-bone player skeleton','ARMATURE'); modifier.object=rig
for action in list(bpy.data.actions): bpy.data.actions.remove(action)
rig.show_in_front=True
for image in bpy.data.images:
    if image.has_data: image.pack()
bpy.ops.object.select_all(action='DESELECT')
hero.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=hero
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/hero_meshy.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'hero_meshy.glb'),export_format='GLB',use_selection=True,
    export_animations=False,export_apply=True,export_def_bones=False,export_all_influences=False,export_yup=True,export_vertex_color='ACTIVE')
raw=(OUT/'hero_meshy.glb').read_bytes();size=struct.unpack_from('<I',raw,12)[0]
gltf=json.loads(raw[20:20+size])
report={'source':str(SOURCE.relative_to(ROOT)), 'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'lip_cleanup':lip_cleanup,
    'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives']),
    'joints':len(gltf['skins'][0]['joints']), 'max_influences':max(len(v.groups) for v in mesh.vertices),
    'authoring_vertices':len(mesh.vertices),'added_triangles':0, 'uvs_unchanged':True,
    'method':'Landmark fit to unchanged player rest skeleton; transferred weights; rigid head and coherent mitten/thumb weights',
    'chin_chest_cleanup':{'rigid_head_min_height':1.54,'neck_blend_height':[1.50,1.54],
        'chest_unique_vertices_retracted':len(np.unique(before_chest[moved_chest],axis=0)),
        'maximum_chest_retraction':float(chest_delta[:,1].max()),'chest_width_height_unchanged':True},
    'bounds':[list(min(v.co[i] for v in mesh.vertices) for i in range(3)),list(max(v.co[i] for v in mesh.vertices) for i in range(3))]}
assert report['triangles']==1552 and report['joints']==65 and report['max_influences']<=4
(OUT/'rig_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('MESHY_RIG',json.dumps(report))
