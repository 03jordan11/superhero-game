"""Blender batch authoring; imports the existing meshes and edits the tier shells.
Run Blender --background --python this_file. Godot import consumes evaluated meshes.
"""
import bpy, json, math
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/generated-buildings/commercial'
WORK = ROOT / 'artifacts/commercial_batch'
SOURCE = json.loads((WORK / 'source.json').read_text())
STYLES = SOURCE['styles']
RESULT = {'buildings': {}, 'hvac': []}
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

# Derive a budget variant from the ACTUAL stock mesh, retaining its body, lid,
# proportions and materials. Flatten its two raised panels to overlays on the lid.
hvac_faces = []
for entry in source_faces(SOURCE['hvac']):
    pts, uv, path, cols = entry
    ys = [p[1] for p in pts]
    flat = max(ys)-min(ys) < .002
    if path == SOURCE['hvac'][0]['material'] and flat: continue  # hidden body caps
    if path == SOURCE['hvac'][1]['material'] and flat and sum(ys)/3 < 2.5: continue
    if path == SOURCE['hvac'][2]['material']:
        if not flat or sum(ys)/3 < 2.7: continue
        pts = [[p[0],2.615,p[2]] for p in pts]
    hvac_faces.append((pts,uv,path,cols))
hvac_scene = bpy.context.scene; hvac_scene.name = 'Stock HVAC budget variant'
hvac = object_from_faces('RooftopHVAC_LowPoly', hvac_faces, hvac_scene.collection)
RESULT['hvac'] = exported(hvac)
assert sum(len(s['vertices'])//3 for s in RESULT['hvac']) == 22

def ring(t):
    w,d = t[:2]; x,z = t[4:6] if len(t)>4 else (0,0); cut = t[6] if len(t)>6 else 0
    if cut:
        pts = [(-w/2+cut,-d/2),(w/2-cut,-d/2),(w/2,-d/2+cut),(w/2,d/2-cut),(w/2-cut,d/2),(-w/2+cut,d/2),(-w/2,d/2-cut),(-w/2,-d/2+cut)]
    else: pts = [(-w/2,-d/2),(w/2,-d/2),(w/2,d/2),(-w/2,d/2)]
    return [(a+x,b+z) for a,b in pts]

def inside(p, polygon):
    return all((polygon[(i+1)%len(polygon)][0]-a[0])*(p[1]-a[1])-(polygon[(i+1)%len(polygon)][1]-a[1])*(p[0]-a[0]) >= -1e-6 for i,a in enumerate(polygon))

def add_roof(faces, outer, inner, height):
    pts = outer + inner
    edges = [(i,(i+1)%len(outer)) for i in range(len(outer))]
    if inner: edges += [(len(outer)+i,len(outer)+(i+1)%len(inner)) for i in range(len(inner))]
    vs, _, tris, *_ = delaunay_2d_cdt([Vector(p) for p in pts], edges, [], 0, 1e-6)
    for ids in tris:
        poly = [vs[i] for i in ids]
        center = sum(poly,Vector((0,0)))/len(poly)
        if inner and inside(center,inner): continue
        if not inside(center,outer): continue
        # Upward Godot face winding uses counterclockwise in the X/Z plane.
        area = sum(poly[i].x*poly[(i+1)%len(poly)].y-poly[(i+1)%len(poly)].x*poly[i].y for i in range(len(poly)))
        if area<0: poly.reverse()
        faces.append(([(p.x,height,p.y) for p in poly], [(0,0)]*len(poly), 'res://assets/generated-buildings/commercial/materials/solid.tres', [[.32549,.33725,.33725,1]]*len(poly)))

def add_walls(faces, outline, bottom, top, style):
    for i,a in enumerate(outline):
        b = outline[(i+1)%len(outline)]
        u = max(1,math.floor(math.dist(a,b)/2.7+.5))/4
        v = max(1,math.floor((top-bottom)/3.8+.5))/4
        faces.append(([(a[0],bottom,a[1]),(b[0],bottom,b[1]),(b[0],top,b[1]),(a[0],top,a[1])], [(0,v),(u,v),(u,0),(0,0)], 'res://assets/generated-buildings/commercial/materials/'+style+'.tres', [[1,1,1,1]]*4))

for index in range(3,21):
    slug = f'commercial_skyscraper_{index:02d}'
    scene = bpy.data.scenes.new(slug)
    bpy.context.window.scene = scene
    # Keep the imported originals in a hidden collection for editable comparison.
    originals = bpy.data.collections.new('Original before rework'); scene.collection.children.link(originals)
    originals.hide_render = True; originals.hide_viewport = True
    object_from_faces(slug+'_original',source_faces(SOURCE['meshes'][slug]),originals)
    tiers = SOURCE['designs'][index-1]
    faces = []
    bottom = 0
    for j,tier in enumerate(tiers):
        outline = ring(tier)
        if j==0:
            add_walls(faces,outline,0,4.2,'lobby'); bottom=4.2
        add_walls(faces,outline,bottom,tier[2],STYLES[tier[3]])
        add_roof(faces,outline,ring(tiers[j+1]) if j+1<len(tiers) else [],tier[2])
        bottom=tier[2]
    # Retain the actual original door triangles; remove only the plaque UV region.
    for entry in source_faces(SOURCE['meshes'][slug]):
        if entry[2].endswith('signs_and_doors.tres') and max(v[1] for v in entry[0])<3.6:
            faces.append(entry)
    building = object_from_faces(slug,faces,scene.collection)
    rows = exported(building)
    count = sum(len(r['vertices'])//3 for r in rows)
    lowpoly = count+48>=110
    equipment = object_from_faces('RooftopHVAC',hvac_faces if lowpoly else source_faces(SOURCE['hvac']),scene.collection)
    last = tiers[-1]
    center = [last[4],last[2],last[5]] if len(last)>4 else [0,last[2],0]
    equipment.location = (center[0],-center[2],center[1])
    total = count+(22 if lowpoly else 48)
    assert total<110,(slug,count,total)
    # A separate, seeded window mask per asset. Interior pixels fit every style.
    image = bpy.data.images.new(slug+'_emission',width=64,height=64,alpha=False)
    pixels=[]
    for y in range(64):
        gy=63-y
        for x in range(64):
            lit=((x//16*3+gy//16*5+index)%7)<4
            lit=lit and 3<=x%16<12 and x%16!=8 and 2<=gy%16<=11
            pixels.extend((1,.67,.35,1) if lit else (0,0,0,1))
    image.pixels.foreach_set(pixels)
    image.filepath_raw=str(OUT/'textures'/f'{slug}_emission.png'); image.file_format='PNG'; image.save()
    # Keep the native Blender source editable with the same per-asset night mask.
    for slot in building.material_slots:
        style = Path(slot.material['godot_source']).stem
        if style in ['solid','signs_and_doors','lobby']: continue
        mat = slot.material.copy(); mat.name = slug+'_'+style
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = image
        tex.interpolation = 'Closest'; tex.label = 'Night window emission'
        mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = 0
        mat['night_emission_strength'] = 2.0
        slot.material = mat
    RESULT['buildings'][slug]={'surfaces':rows,'building_triangles':count,'triangles':total,'lowpoly_hvac':lowpoly,'hvac_position':center,'tiers':tiers}
    # Standard Blender export is also checked independently after Godot loads it.
    bpy.ops.object.select_all(action='DESELECT')
    building.select_set(True); equipment.select_set(True)
    bpy.context.view_layer.objects.active=building
    bpy.ops.export_scene.gltf(filepath=str(WORK/(slug+'.glb')),use_selection=True,export_format='GLB',export_materials='EXPORT')
    print(f'BLENDER_REWORK {slug}: {count} building + {22 if lowpoly else 48} HVAC = {total}',flush=True)

(WORK/'edited_meshes.json').write_text(json.dumps(RESULT))
(OUT/'blender').mkdir(exist_ok=True)
for image in bpy.data.images:
    if image.has_data: image.pack()
bpy.context.window.scene=bpy.data.scenes['commercial_skyscraper_03']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'blender/commercial_03_20.blend'))
print('BLENDER_BATCH_COMPLETE',flush=True)
