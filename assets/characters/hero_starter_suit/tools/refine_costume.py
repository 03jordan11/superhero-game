"""Flatten lips and fit both glove mittens to the approved underwear hero.
Blender --background --factory-startup --python this_file.py
"""
import bpy
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT/'assets/characters/hero_starter_suit'
sys.path.insert(0,str(ROOT/'assets/characters/hero_meshy/tools'))
from costume_shapes import flatten_lips, smooth

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
SOURCE = OUT/'source/hero_starter_suit_original.glb'
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
hero = next(o for o in bpy.context.scene.objects if o.type=='MESH')
hero.name = 'Hero_Starter_Suit'
bpy.context.view_layer.objects.active=hero
hero.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh = hero.data
original_faces = [tuple(p.vertices) for p in mesh.polygons]
original_uv = np.array([tuple(v.uv) for v in mesh.uv_layers.active.data])
scale = 1.8131932
for v in mesh.vertices: v.co = v.co*scale+Vector((0,0,scale/2))
original = np.array([tuple(v.co) for v in mesh.vertices])
lip_cleanup = flatten_lips(mesh, 'starter')

before_objects = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/hero_meshy/hero_meshy.glb'))
reference = next(o for o in set(bpy.data.objects)-before_objects
                 if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
bpy.context.view_layer.update()
ref_points = [reference.matrix_world @ v.co for v in reference.data.vertices]
before_hands = np.array([tuple(v.co) for v in mesh.vertices])

for side in [-1,1]:
    # Keep the cuff/arm intact. The reference hand is translated from the
    # fitted player arm to this outfit's shorter source arm, without scaling
    # its palm or thumb. BVH fitting works with the existing glove topology.
    points = [Vector((p.x-side*.135, p.y-.025, p.z-.040)) for p in ref_points]
    faces = [tuple(p.vertices) for p in reference.data.polygons
             if all(ref_points[i].x*side>.66 for i in p.vertices)]
    surface = BVHTree.FromPolygons(points,faces,all_triangles=True)
    for v in mesh.vertices:
        x,y,z = v.co
        ax=x*side
        if ax<.585 or z<1.30: continue
        weight=smooth(.585,.630,ax)
        if not weight: continue
        guess=Vector((side*(.600+(ax-.600)*(.185/.158)), y, z))
        location, normal, face, distance = surface.find_nearest(guess)
        if location is None: continue
        v.co = v.co.lerp(location, weight*.85)

# Local projections must not invert or crush triangles. Back off only vertices
# on problematic hand faces, retaining the largest safe amount of the fit.
faces=np.array(original_faces)
target=np.array([tuple(v.co) for v in mesh.vertices])
base=before_hands.copy()
normals=np.cross(base[faces[:,1]]-base[faces[:,0]],base[faces[:,2]]-base[faces[:,0]])
for iteration in range(14):
    new=np.cross(target[faces[:,1]]-target[faces[:,0]],target[faces[:,2]]-target[faces[:,0]])
    invalid=(np.einsum('ij,ij->i',normals,new)<=0) | (np.linalg.norm(new,axis=1)<1e-10)
    if not invalid.any(): break
    indices=np.unique(faces[invalid])
    # All duplicated UV seam vertices must receive the identical correction.
    affected={tuple(base[i]) for i in indices}
    for i,p in enumerate(base):
        if tuple(p) in affected: target[i]=base[i]+(target[i]-base[i])*.5
assert not invalid.any(), 'Hand fitting created invalid faces'
for v,point in zip(mesh.vertices,target): v.co=point
hand_delta=target-before_hands
changed=np.linalg.norm(hand_delta,axis=1)>1e-8
hand_report={'unique_vertices_adjusted':len(np.unique(before_hands[changed],axis=0)),
    'maximum_vertex_motion_m':float(np.linalg.norm(hand_delta,axis=1).max()),
    'reference':'hero_meshy.glb', 'thumbs_retained':True,'no_inverted_hand_faces':True}
assert hand_report['maximum_vertex_motion_m'] < .06, 'Reference must be the body, not an imported bone display mesh'

# Return to original asset coordinates, keeping the saved costume scene fit.
for v in mesh.vertices: v.co=(v.co-Vector((0,0,scale/2)))/scale
mesh.update()
if mesh.has_custom_normals: mesh.normals_split_custom_set([(0.,0.,0.)]*len(mesh.loops))
assert original_faces==[tuple(p.vertices) for p in mesh.polygons]
assert np.array_equal(original_uv,np.array([tuple(v.uv) for v in mesh.uv_layers.active.data]))
for obj in list(bpy.data.objects):
    if obj!=hero: bpy.data.objects.remove(obj,do_unlink=True)
for image in bpy.data.images:
    if image.has_data: image.pack()
bpy.ops.object.select_all(action='DESELECT')
hero.select_set(True); bpy.context.view_layer.objects.active=hero
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/hero_starter_suit.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'hero_starter_suit.glb'),export_format='GLB',use_selection=True,
    export_animations=False,export_apply=True,export_yup=True,export_vertex_color='ACTIVE')
report={'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'triangles':len(mesh.polygons),'added_triangles':0,'uvs_unchanged':True,
    'lip_cleanup':lip_cleanup,'hand_cleanup':hand_report}
assert report['triangles']==2172
(OUT/'shape_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('STARTER_SUIT_SHAPE_PASS',json.dumps(report))
