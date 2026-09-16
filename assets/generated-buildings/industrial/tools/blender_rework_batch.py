"""Blender batch authoring; imports the existing meshes and edits the tier shells.
Run Blender --background --python this_file. Godot import consumes evaluated meshes.
"""
import bpy, json, math
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/generated-buildings/industrial'
WORK = ROOT / 'artifacts/industrial_batch'
SOURCE = json.loads((WORK / 'source.json').read_text())
RESULT = {'buildings': {}, 'colliders': []}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
material_cache = {}

def material(path, color=None, texture=''):
    key = (path, tuple(color or []))
    if key in material_cache:
        return material_cache[key]
    mat = bpy.data.materials.new(Path(path).stem)
    mat['godot_source'] = path
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    if color: bsdf.inputs['Base Color'].default_value = color
    if path.endswith('/solid.tres'):
        color_node = mat.node_tree.nodes.new('ShaderNodeVertexColor')
        color_node.layer_name = 'Color'
        mat.node_tree.links.new(color_node.outputs['Color'], bsdf.inputs['Base Color'])
    if texture:
        image = bpy.data.images.load(str(ROOT / texture.replace('res://','')), check_existing=True)
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = image
        tex.interpolation = 'Closest'
        mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    material_cache[key] = mat
    return mat

for rows in list(SOURCE['meshes'].values()) + [SOURCE['hvac']]:
    for row in rows: material(row['material'], row['albedo'], row['texture'])

def source_material(path):
    for key, mat in material_cache.items():
        if key[0] == path: return mat
    return material(path)

def object_from_faces(name, faces, collection):
    # Each entry is (Godot coordinates, Godot UVs, material path, corner colors).
    verts, polys, mats, uvs, colors = [], [], [], [], []
    for points, texcoords, path, cols in faces:
        start = len(verts)
        verts.extend((p[0], -p[2], p[1]) for p in reversed(points))
        polys.append(tuple(range(start, len(verts))))
        mat = source_material(path)
        if mat not in mats: mats.append(mat)
        uvs.extend((u[0], 1-u[1]) for u in reversed(texcoords))
        colors.extend(reversed(cols))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], polys); mesh.update()
    for mat in mats: mesh.materials.append(mat)
    uv = mesh.uv_layers.new(name='UVMap')
    col = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for face, entry in zip(mesh.polygons, faces):
        face.material_index = mats.index(source_material(entry[2]))
    for loop in mesh.loops:
        uv.data[loop.index].uv = uvs[loop.vertex_index]
        col.data[loop.index].color = colors[loop.vertex_index]
    obj = bpy.data.objects.new(name, mesh); collection.objects.link(obj)
    return obj

def source_faces(rows):
    faces = []
    for row in rows:
        ids = row['indices'] or list(range(len(row['vertices'])))
        for i in range(0, len(ids), 3):
            indices = ids[i:i+3]
            faces.append(([row['vertices'][j] for j in indices], [row['uv'][j] for j in indices], row['material'], [row['colors'][j] if row['colors'] else [1,1,1,1] for j in indices]))
    return faces

def exported(obj):
    mesh = obj.data; mesh.calc_loop_triangles()
    rows = {}
    for tri in mesh.loop_triangles:
        path = mesh.materials[tri.material_index]['godot_source']
        row = rows.setdefault(path, {'material':path, 'vertices':[], 'normals':[], 'uv':[], 'colors':[]})
        n = tri.normal
        for loop_id in reversed(tri.loops):
            v = mesh.vertices[mesh.loops[loop_id].vertex_index].co
            uv = mesh.uv_layers.active.data[loop_id].uv
            row['vertices'].append([v.x,v.z,-v.y])
            row['normals'].append([n.x,n.z,-n.y])
            row['uv'].append([uv.x,1-uv.y])
            row['colors'].append(list(mesh.color_attributes['Color'].data[loop_id].color))
    return list(rows.values())


# Main wall volumes are boxes. Sloping roofs and tapered stacks are closed convex
# volumes, never hollow triangle surfaces. Coordinates follow the authored designs.
BOXES=[
 [[34,26,0,8.9,0,0],[10,9,8.9,12.6,-9,5],[28,1.8,5.3,5.55,0,-13.7]],
 [[30,24,0,7,0,0]],
 [[30,26,0,11,0,0]],
 [[32,26,0,12.3,0,0]]+[[5,6,12.3,14.1,x,3] for x in [-9,0,9]],
 [[32,24,0,6,0,0]],
 [[28,22,0,24.28,0,0],[8,8,24.28,29,6,4]],
 [[30,24,0,13.28,0,0]],
 [[32,24,0,6,0,0],[11,16,6,19,-10,2]],
 [[28,24,0,15,0,0],[16,18,15,19,-4,0],[5,5,15,30.4,9,6]],
 [[30,24,0,7,0,0],[9,24,7,12,-10.5,0]]
]
for index in range(1,11):
    slug=f'industrial_building_{index:02d}'
    scene=bpy.data.scenes.new(slug); bpy.context.window.scene=scene
    originals=bpy.data.collections.new('Original before rework'); scene.collection.children.link(originals)
    originals.hide_render=True; originals.hide_viewport=True
    original=source_faces(SOURCE['meshes'][slug])
    object_from_faces(slug+'_original',original,originals)
    faces=[f for f in original if not (f[2].endswith('signs_and_doors.tres') and max(uv[1] for uv in f[1])<.8)]
    building=object_from_faces(slug,faces,scene.collection)
    if index==3:
        # The foundry had no windows at all. Paint a narrow clerestory into a
        # private brick texture, preserving the wall geometry and loading bays.
        base=next(r for r in SOURCE['meshes'][slug] if r['material'].endswith('brick_wall.tres'))
        original_image=bpy.data.images.load(str(ROOT/base['texture'].replace('res://','')),check_existing=True)
        image=bpy.data.images.new('foundry_windows',width=64,height=64,alpha=False)
        pixels=list(original_image.pixels)
        for by in range(64):
            y=63-by
            for x in range(64):
                if y//16==0 and 3<=x%16<=12 and 3<=y%16<=6:
                    color=(.20,.27,.29,1) if x%16 not in [4,8] and y%16!=3 else (.32,.25,.22,1)
                    pixels[(by*64+x)*4:(by*64+x+1)*4]=color
        image.pixels.foreach_set(pixels); image.filepath_raw=str(OUT/'textures/foundry_windows.png'); image.file_format='PNG'; image.save()
        for slot in building.material_slots:
            if not slot.material['godot_source'].endswith('brick_wall.tres'): continue
            mat=slot.material.copy(); slot.material=mat
            mat['godot_source']='res://assets/generated-buildings/industrial/materials/foundry_windows.tres'
            for node in mat.node_tree.nodes:
                if node.type=='TEX_IMAGE': node.image=image
    rows=exported(building)
    walls=[p for f in faces if not f[2].endswith(('solid.tres','signs_and_doors.tres')) for p in f[0]]
    shift=[(min(p[0] for p in walls)+max(p[0] for p in walls))/2,0,(min(p[2] for p in walls)+max(p[2] for p in walls))/2]
    colliders=[]
    for w,d,b,t,x,z in BOXES[index-1]:
        colliders.append({'type':'box','size':[w,t-b,d],'center':[x+shift[0],(b+t)/2,z+shift[2]]})
    def convex(points):
        colliders.append({'type':'convex','points':[[p[0]+shift[0],p[1],p[2]+shift[2]] for p in points]})
    def gable(w,d,y,h,x=0,z=0):
        convex([(x+dx,y,z+dz) for dx in [-w/2,w/2] for dz in [-d/2,d/2]]+[(x,y+h,z-d/2),(x,y+h,z+d/2)])
    def cylinder(radius,b,t,x,z,top_radius=None):
        top_radius=radius if top_radius is None else top_radius
        convex([(x+math.cos(i*math.pi/4)*r,y,z+math.sin(i*math.pi/4)*r) for y,r in [(b,radius),(t,top_radius)] for i in range(8)])
    smoke=[]
    if index==2:
        for i in range(4):
            x=-15+i*7.5
            convex([(x,7,-12),(x+7.5,7,-12),(x+7.5,9.8,-12),(x,7,12),(x+7.5,7,12),(x+7.5,9.8,12)])
    if index==3:
        gable(30.3,26.3,11,4)
        cylinder(3,11,25,-10,8,3*.74); cylinder(2.4,25,25.6,-10,8)
        smoke=[[-10,25.7,8]]
    if index==5:
        for x in [-8,8]: gable(16,24,6,2.8,x)
    if index==7:
        for x in [-8,8]:
            cylinder(1.8,13.28,28,x,5,1.8*.74); cylinder(1.44,28,28.6,x,5)
        smoke=[[-8,28.7,5]]
    if index==8:
        for x in [0,7]:
            for z in [-2,6]:
                cylinder(3.2,6,22,x,z); cylinder(3.25,22,24,x,z,.35)
    if index==9:
        gable(16,18,19,2.5,-4)
        smoke=[[9,30.5,6]]
    if index==10: gable(21,24,7,2.3,4.5)
    # Editable collision objects alongside the authored building, excluded from render/export.
    collision_collection=bpy.data.collections.new('Collision solids'); scene.collection.children.link(collision_collection)
    collision_collection.hide_render=True; collision_collection.hide_viewport=True
    for number,c in enumerate(colliders):
        if c['type']=='box':
            center=c['center']; size=c['size']
            pts=[tuple(center[k]+sign[k]*size[k]/2 for k in range(3)) for sign in [(x,y,z) for x in [-1,1] for y in [-1,1] for z in [-1,1]]]
        else: pts=c['points']
        mesh=bpy.data.meshes.new('CollisionVolume'); mesh.from_pydata([(p[0],-p[2],p[1]) for p in pts],[],[])
        obj=bpy.data.objects.new(f'Collision_{number:02d}',mesh); collision_collection.objects.link(obj)
        import bmesh
        bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.convex_hull(bm,input=list(bm.verts)); bm.to_mesh(mesh); bm.free()
        obj.display_type='WIRE'; obj['godot_collision_type']=c['type']
    for row in rows:
        style=Path(row['material']).stem
        if style in ['solid','signs_and_doors','brick_wall']: continue
        image=bpy.data.images.new(slug+'_'+style+'_emission',width=64,height=64,alpha=False)
        pixels=[]
        for by in range(64):
            y=63-by
            for x in range(64):
                px,py=x%16,y%16
                factory=style in ['red_factory','buff_factory']
                inside=(2<=px<=13 and 3<=py<=12) if factory else (3<=px<=12 and 3<=py<=6)
                inside=inside and px not in [4,8] and py!=3 and not(factory and py==8)
                if style=='foundry_windows': inside=inside and y//16==0
                lit=inside and ((x//16*3+y//16*5+index)%7)<4
                pixels.extend((1,.67,.35,1) if lit else (0,0,0,1))
        image.pixels.foreach_set(pixels); image.filepath_raw=str(OUT/'textures'/f'{slug}_{style}_emission.png'); image.file_format='PNG'; image.save()
        for slot in building.material_slots:
            if slot.material['godot_source']!=row['material']: continue
            mat=slot.material.copy(); slot.material=mat
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image; tex.interpolation='Closest'
            mat.node_tree.links.new(tex.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'])
            mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=0
    count=sum(len(row['vertices'])//3 for row in rows)
    RESULT['buildings'][slug]={'surfaces':rows,'triangles':count,'colliders':colliders,'smoke':[[p[0]+shift[0],p[1],p[2]+shift[2]] for p in smoke]}
    bpy.ops.object.select_all(action='DESELECT'); building.select_set(True); bpy.context.view_layer.objects.active=building
    bpy.ops.export_scene.gltf(filepath=str(WORK/(slug+'.glb')),use_selection=True,use_active_scene=True,export_format='GLB')
    print(f'INDUSTRIAL_BLENDER {slug}: {count} triangles; {len(colliders)} solid colliders',flush=True)
(WORK/'edited_meshes.json').write_text(json.dumps(RESULT))
for image in bpy.data.images:
    if image.has_data: image.pack()
bpy.context.window.scene=bpy.data.scenes['industrial_building_03']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'blender/industrial_01_10.blend'))
print('INDUSTRIAL_BLENDER_COMPLETE',flush=True)


