"""Replace segmented staircase cheeks with two continuous retaining walls.
Updates architecture only; native Godot prop placements are not exported.
"""
import bpy
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE / 'city_hall.blend'))
architecture = bpy.data.collections['CITY HALL | architecture and grounds']
material = bpy.data.objects['Front setback wall 1'].data.materials[0]
for obj in list(architecture.objects):
    if obj.name in {'Stair cheek walls', 'Landing piers', 'Continuous stair side Left', 'Continuous stair side Right'}:
        bpy.data.objects.remove(obj, do_unlink=True)

# Blender Y runs uphill; Z is height. Each wall has an uninterrupted side face
# from ground to its sloping/level top, including the three landing sections.
profile = [(-68, -.1), (-41.4, -.1), (-41.4, 8.8), (-45.8, 6.8),
           (-48.8, 6.8), (-53.2, 4.8), (-56.2, 4.8), (-60.6, 2.8),
           (-63.6, 2.8), (-68, .8)]
for name, x0, x1 in [('Left', -21.5, -20.6), ('Right', 20.6, 21.5)]:
    vertices = [(x, y, z) for x in [x0, x1] for y, z in profile]
    n = len(profile)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new('Continuous stair side ' + name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(mesh.name, mesh)
    architecture.objects.link(obj)
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
        axes = [i for i in range(3) if i != axis]
        for loop in polygon.loop_indices:
            v = mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv = (v[axes[0]] / 8, v[axes[1]] / 8)

bpy.ops.object.select_all(action='DESELECT')
for obj in architecture.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(HERE/'city_hall.glb'), export_format='GLB',
                         use_selection=True, export_yup=True, export_apply=True,
                         export_cameras=False, export_lights=False)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'city_hall.blend'))
print('CITY_HALL_CONTINUOUS_STAIR_SIDES: two solid walls, shared retaining material')
