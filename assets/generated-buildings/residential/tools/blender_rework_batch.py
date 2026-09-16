"""Blender batch authoring; imports the existing meshes and edits the tier shells.
Run Blender --background --python this_file. Godot import consumes evaluated meshes.
"""
import bpy, json, math
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/generated-buildings/residential'
WORK = ROOT / 'artifacts/residential_batch'
SOURCE = json.loads((WORK / 'source.json').read_text())
RESULT = {'buildings': {}, 'water_tower': []}
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


# One reusable eight-sided wooden tank with four supports and a conical lid.
# Shared mesh data is instanced in the building scenes, never joined to the shell.
solid = 'res://assets/generated-buildings/residential/materials/solid.tres'
water_scene = bpy.context.scene
water_scene.name = 'Shared rooftop water tower'
water_faces = []
def box_faces(x,z,y,w,d,h,color):
    pts = [(x-w/2,y,z-d/2),(x+w/2,y,z-d/2),(x+w/2,y,z+d/2),(x-w/2,y,z+d/2)]
    for i in range(4):
        a,b=pts[i],pts[(i+1)%4]
        water_faces.append(([a,b,(b[0],y+h,b[2]),(a[0],y+h,a[2])],[(0,0)]*4,solid,[color]*4))
    water_faces.append(([(p[0],y+h,p[2]) for p in pts],[(0,0)]*4,solid,[color]*4))
for x in [-.85,.85]:
    for z in [-.85,.85]: box_faces(x,z,0,.18,.18,1.2,[.22,.25,.26,1])
for i in range(8):
    a,b=2*math.pi*i/8,2*math.pi*(i+1)/8
    p,q=(math.cos(a)*1.3,math.sin(a)*1.3),(math.cos(b)*1.3,math.sin(b)*1.3)
    wood=[.40+(i%3)*.025,.30+(i%3)*.02,.22+(i%3)*.012,1]
    water_faces.append(([(p[0],1,p[1]),(q[0],1,q[1]),(q[0],3.5,q[1]),(p[0],3.5,p[1])],[(0,0)]*4,solid,[wood]*4))
    water_faces.append(([(p[0]*1.08,3.5,p[1]*1.08),(q[0]*1.08,3.5,q[1]*1.08),(0,4.25,0)],[(0,0)]*3,solid,[[.27,.30,.31,1]]*3))
water=object_from_faces('RooftopWaterTower',water_faces,water_scene.collection)
RESULT['water_tower']=exported(water)
water_count=sum(len(r['vertices'])//3 for r in RESULT['water_tower'])
bpy.context.view_layer.objects.active=water
water.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(WORK/'rooftop_water_tower.glb'),use_selection=True,use_active_scene=True,export_format='GLB')
bpy.data.libraries.write(str(ROOT/'assets/props/rooftop_water_tower/rooftop_water_tower.blend'), {water_scene}, fake_user=True)

for index in range(1,21):
    slug=f'residential_building_{index:02d}'
    scene=bpy.data.scenes.new(slug); bpy.context.window.scene=scene
    originals=bpy.data.collections.new('Original before rework'); scene.collection.children.link(originals)
    originals.hide_render=True; originals.hide_viewport=True
    original=source_faces(SOURCE['meshes'][slug])
    object_from_faces(slug+'_original',original,originals)
    wall_points=[p for f in original if not f[2].endswith(('solid.tres','signs_and_doors.tres')) for p in f[0]]
    wall_top=max(p[1] for p in wall_points)
    roof_levels=[f[0][0][1] for f in original if f[2].endswith('solid.tres') and max(p[1] for p in f[0])-min(p[1] for p in f[0])<.001 and wall_top-.005<=f[0][0][1]<=wall_top+.26]
    roof_y=max(roof_levels)
    front=min(p[2] for p in wall_points)
    faces=[]; removed=0
    for f in original:
        pts,uv,path,cols=f
        if path.endswith('signs_and_doors.tres') and max(t[1] for t in uv)<.80:
            removed+=1; continue
        if path.endswith('solid.tres'):
            # Existing utility blocks, chimneys, baked tanks and duplex gables.
            if min(p[1] for p in pts)>=roof_y-.005 and max(p[1] for p in pts)>roof_y+.02:
                removed+=1; continue
            # Balcony slab/parapet boxes are the only deep front protrusions above entries.
            if index in [10,12,14] and min(p[1] for p in pts)>3.5 and min(p[2] for p in pts)<front-.3:
                removed+=1; continue
            # Back faces of slabs sit just inside the facade and need removing too.
            if index in [10,12,14]:
                ys=[p[1] for p in pts]; zs=[p[2] for p in pts]
                if min(ys)>3.5 and max(zs)<=front+.11 and min(zs)<front+.11 and max(ys)-min(ys)<1.0:
                    # Preserve broad cornice bands; balconies are exactly 3.4m wide.
                    width=max(p[0] for p in pts)-min(p[0] for p in pts)
                    if abs(width-3.4)<.01: removed+=1; continue
        faces.append(f)
    building=object_from_faces(slug,faces,scene.collection)
    # Find the largest actual top roof rectangle; this also handles offset/L-shaped plans.
    roof_faces=[f for f in faces if all(abs(p[1]-roof_y)<.01 for p in f[0])]
    assert roof_faces,(slug,roof_y)
    def area(f):
        return (max(p[0] for p in f[0])-min(p[0] for p in f[0]))*(max(p[2] for p in f[0])-min(p[2] for p in f[0]))
    top=max(roof_faces,key=area)[0]
    low=[min(p[k] for p in top) for k in range(3)]; high=[max(p[k] for p in top) for k in range(3)]
    cx,cz=(low[0]+high[0])/2,(low[2]+high[2])/2
    with_water=index in [4,9,16]
    scale=min(.65,(high[0]-low[0])*.60/9.4,(high[2]-low[2])*.60/6.4)
    ac_pos=[cx+(2 if with_water else 0),roof_y,cz]
    equipment=object_from_faces('RooftopHVAC',source_faces(SOURCE['hvac']),scene.collection)
    equipment.scale=(scale,scale,scale); equipment.location=(ac_pos[0],-ac_pos[2],ac_pos[1])
    tank_pos=[cx-2.8,roof_y,cz+1.0]
    if with_water:
        tank=bpy.data.objects.new('RooftopWaterTower',water.data); scene.collection.objects.link(tank)
        tank.location=(tank_pos[0],-tank_pos[2],tank_pos[1])
    rows=exported(building)
    count=sum(len(r['vertices'])//3 for r in rows)
    total=count+22+(water_count if with_water else 0)
    # Per-style masks exactly respect existing frames, mullions and painted sills.
    for row in rows:
        style=Path(row['material']).stem
        if style in ['solid','signs_and_doors']: continue
        image=bpy.data.images.new(slug+'_'+style+'_emission',width=64,height=64,alpha=False)
        pattern='factory' if style=='loft_brick' else ('modern' if style in ['concrete','sage_panel'] else ('stone' if style in ['brownstone','limestone'] else ('brick' if style=='red_brick' else 'tenement')))
        pixels=[]
        for by in range(64):
            y=63-by
            for x in range(64):
                px,py=x%16,y%16
                inside=(2<=px<=13 and 2<=py<=13) if pattern=='modern' else ((2<=px<=13 and 3<=py<=12) if pattern=='factory' else (4<=px<=11 and 3<=py<=12))
                inside=inside and px not in [4,8] and py!=3 and not (py==8 and pattern in ['factory','tenement','brick'])
                lit=inside and ((x//16*3+y//16*5+index)%7)<4
                pixels.extend((1,.67,.35,1) if lit else (0,0,0,1))
        image.pixels.foreach_set(pixels)
        image.filepath_raw=str(OUT/'textures'/f'{slug}_{style}_emission.png'); image.file_format='PNG'; image.save()
        for slot in building.material_slots:
            if slot.material['godot_source']!=row['material']: continue
            mat=slot.material.copy(); slot.material=mat
            node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image; node.interpolation='Closest'
            mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'])
            mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=0
    RESULT['buildings'][slug]={'surfaces':rows,'building_triangles':count,'triangles':total,'removed_triangles':removed,'roof_y':roof_y,'hvac_position':ac_pos,'hvac_scale':scale,'water_position':tank_pos if with_water else None,'front':front}
    bpy.ops.object.select_all(action='DESELECT'); building.select_set(True); equipment.select_set(True)
    if with_water: tank.select_set(True)
    bpy.context.view_layer.objects.active=building
    bpy.ops.export_scene.gltf(filepath=str(WORK/(slug+'.glb')),use_selection=True,use_active_scene=True,export_format='GLB')
    print(f'RESIDENTIAL_BLENDER {slug}: {count} shell + props = {total}; removed {removed}',flush=True)

(WORK/'edited_meshes.json').write_text(json.dumps(RESULT))
for image in bpy.data.images:
    if image.has_data: image.pack()
bpy.context.window.scene=bpy.data.scenes['residential_building_10']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'blender/residential_01_20.blend'))
print('RESIDENTIAL_BLENDER_COMPLETE',flush=True)

