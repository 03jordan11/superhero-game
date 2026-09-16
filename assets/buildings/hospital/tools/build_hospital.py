"""Run with Blender --background --python this_file.py. No addons or downloads.
Original, reference-inspired exterior; metres; Blender -Y / Godot +Z is front.
"""
import bpy
import math
import json
from pathlib import Path
from collections import defaultdict
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parents[1]
SHARED = HERE.parent / 'materials'
PREVIEWS = HERE.parents[2] / 'artifacts' / 'hospital'
for path in [HERE, SHARED, PREVIEWS]:
    path.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for data in list(bpy.data.materials):
    bpy.data.materials.remove(data)
rng = np.random.default_rng(19032)


def image_file(name, data, folder, noncolor=False):
    h, w = data.shape[:2]
    image = bpy.data.images.new(name, width=w, height=h, alpha=True)
    if noncolor:
        image.colorspace_settings.name = 'Non-Color'
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = data[:, :, :3]
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(folder / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    return image


# Seamless, restrained limestone coursing. One texture repeat covers 8 x 8 metres.
n = 512
yy, xx = np.mgrid[:n, :n]
grain = rng.normal(0, .008, (n, n))
row = yy // 32
joint = ((yy % 32) < 1) | (((xx + (row % 2) * 64) % 128) < 1)
shade = grain - joint * .038 + .009 * np.sin(row * 7.3)
stone_rgb = np.clip(np.array([.68, .635, .535])[None, None, :] + shade[:, :, None], 0, 1)
stone_image = image_file('limestone_warm_albedo', stone_rgb, SHARED)
stone_rough = image_file('limestone_warm_roughness', np.repeat((.79 + joint * .09 + grain)[:, :, None], 3, 2), SHARED, True)

# 8 x 8 room-window atlas. Emission and base colour share exact texel coordinates.
n = 1024
atlas = np.zeros((n, n, 3), dtype=np.float32)
emit = np.zeros_like(atlas)
for row in range(8):
    for col in range(8):
        y, x = np.mgrid[:128, :128]
        lit = rng.random() < .42
        tint = np.array([.19, .29, .32]) * rng.uniform(.77, 1.15)
        glass = (x > 12) & (x < 115) & (y > 13) & (y < 116)
        frame = (~glass) | (abs(x - 64) < 2) | (abs(y - 48) < 2) | (abs(y - 87) < 2)
        cell = np.broadcast_to(tint, (128, 128, 3)).copy()
        cell += (y / 128 * .045)[:, :, None]
        cell[frame] = [.34, .36, .345]
        cell[:9] = [.44, .43, .375]
        # Small variation in blinds adds inhabited rooms without extra geometry.
        blind = glass & (y > (91 if (row + col) % 3 else 71))
        cell[blind & ~frame] *= 1.20
        atlas[row*128:(row+1)*128, col*128:(col+1)*128] = cell
        emission = np.zeros((128, 128, 3), dtype=np.float32)
        if lit:
            warm = [.95, .66, .34] if (row + col) % 4 else [.48, .77, .86]
            emission[glass & ~frame] = np.array(warm) * rng.uniform(.5, 1.0)
            emission[blind & ~frame] *= .60
        emit[row*128:(row+1)*128, col*128:(col+1)*128] = emission
window_image = image_file('windows_bluegray_atlas_albedo', atlas, SHARED)
window_emit = image_file('hospital_windows_emission', emit, HERE)

# Tall curtain glazing: slim vertical mullions and floor spandrels, tiled vertically.
h, w = 1024, 512
y, x = np.mgrid[:h, :w]
glass_rgb = np.empty((h, w, 3), dtype=np.float32)
glass_rgb[:] = [.21, .32, .35]
glass_rgb += (.035 * (y % 85) / 85)[:, :, None]
curtain_emit = np.zeros_like(glass_rgb)
for row in range(12):
    for col in range(4):
        ys, xs = slice(row*85, (row+1)*85), slice(col*128, (col+1)*128)
        glass_rgb[ys, xs] *= rng.uniform(.85, 1.15)
        if rng.random() < .55:
            curtain_emit[ys, xs] = np.array([.82, .69, .47] if col % 3 else [.43, .69, .79]) * rng.uniform(.20, .70)
mullions = (x % 128 < 5) | (x % 128 > 122) | (y % 85 < 3) | (abs(y % 85 - 42) < 2)
spandrels = y % 85 > 69
glass_rgb[mullions] = [.43, .44, .40]
glass_rgb[spandrels & ~mullions] = [.12, .17, .18]
curtain_emit[mullions | spandrels] = 0
curtain_image = image_file('curtain_glazing_albedo', glass_rgb, SHARED)
curtain_emission = image_file('hospital_curtain_emission', curtain_emit, HERE)

# Separate skylight glass; no room lights, blinds, spandrels or window atlas.
yy, xx = np.mgrid[:512, :512]
sheen = .025 * np.cos((xx + yy * .55) / 512 * math.tau)
canopy_rgb = np.clip(np.array([.17,.29,.33])[None,None,:] + sheen[:,:,None],0,1)
canopy_rgb[(xx < 4) | (xx > 507) | (yy < 4) | (yy > 507)] = [.012,.016,.018]
canopy_image = image_file('canopy_glass_albedo', canopy_rgb, SHARED)


def material(name, color, texture=None, emission=None, metallic=0, roughness=.75):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = roughness
    bs.inputs['Metallic'].default_value = metallic
    if texture:
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = texture
        mat.node_tree.links.new(node.outputs['Color'], bs.inputs['Base Color'])
    if emission:
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = emission
        mat.node_tree.links.new(node.outputs['Color'], bs.inputs['Emission Color'])
        bs.inputs['Emission Strength'].default_value = 2.0
    mat.diffuse_color = (*color, 1)
    return mat


mats = {
    'stone': material('Limestone | warm reusable masonry', (.68, .635, .535), stone_image),
    'trim': material('Limestone | pale carved trim', (.74, .70, .60)),
    'roof': material('Roof | weathered copper taupe', (.24, .255, .245)),
    'metal': material('Metal | dark bronze', (.075, .105, .11), metallic=.65, roughness=.38),
    'window': material('Hospital | room windows NIGHT', (.23, .3, .33), window_image, window_emit, .15, .38),
    'curtain': material('Hospital | arched glazing NIGHT', (.23, .32, .35), curtain_image, curtain_emission, .2, .32),
    'teal': material('Hospital | teal enamel', (.025, .28, .30), metallic=.2),
    'sign': material('Hospital | illuminated ivory lettering NIGHT', (.91, .9, .73)),
    'paving': material('Paving | charcoal granite', (.24, .255, .25)),
    'canopy': material('Glass | smoke blue canopy', (.18, .28, .31), canopy_image, metallic=.25, roughness=.22),
    'canopy_frame': material('Metal | black canopy framing', (.012,.016,.018), metallic=.6, roughness=.32),
}
bs = mats['stone'].node_tree.nodes.get('Principled BSDF')
tex = mats['stone'].node_tree.nodes.new('ShaderNodeTexImage')
tex.image = stone_rough
mats['stone'].node_tree.links.new(tex.outputs['Color'], bs.inputs['Roughness'])
bs = mats['sign'].node_tree.nodes.get('Principled BSDF')
bs.inputs['Emission Color'].default_value = (.72, .85, .75, 1)
bs.inputs['Emission Strength'].default_value = 2.0

# Mesh buffers keep the exported model to a few grouped meshes / material surfaces.
buffers = defaultdict(lambda: [[], [], [], []])
collision_boxes = []
opaque_boxes = []
pending_rooms = []
front_bays = []


def face(group, mat, points, uv=None):
    vertices, faces, uvs, slots = buffers[group]
    start = len(vertices)
    points = [tuple(p) for p in points]
    vertices.extend(points)
    faces.append(tuple(range(start, start + len(points))))
    slots.append(mat)
    if uv is None:
        normal = (Vector(points[1])-Vector(points[0])).cross(Vector(points[2])-Vector(points[0]))
        axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = [i for i in range(3) if i != axis]
        uv = [(p[axes[0]] / 8, p[axes[1]] / 8) for p in points]
    uvs.extend(uv)


def box(group, mat, center, size, solid=False):
    x, y, z = center
    a, b, c = [v/2 for v in size]
    v = [(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
         (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
    for f in [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]:
        face(group, mat, [v[i] for i in f])
    if solid:
        collision_boxes.append({'center': [x,z,-y], 'size':[size[0],size[2],size[1]]})
    if mat in ['stone','trim'] and group != 'Window sills':
        opaque_boxes.append((Vector((x-a,y-b,z-c)),Vector((x+a,y+b,z+c))))


def building(name, x, y, width, depth, height, rounded_front=False):
    box(name, 'stone', (x,y,height/2), (width,depth,height), True)
    box('Roof terraces', 'roof', (x,y,height+.06), (width-.7,depth-.7,.12))
    # Light projecting cornice and substantial parapet ring.
    if not rounded_front:
        box('Carved stonework','trim',(x,y,height-.8),(width+.55,depth+.55,.65))
    for px, py, sx, sy in [(x,y-depth/2,width,.45),(x,y+depth/2,width,.45),(x-width/2,y,.45,depth),(x+width/2,y,.45,depth)]:
        if rounded_front and py == y-depth/2:
            continue
        box('Roof terraces','stone',(px,py,height+.6),(sx,sy,1.2))


def panel(group, mat, origin, tangent, width, height, pointed=False, tile=None):
    o, t = Vector(origin), Vector(tangent)
    n = t.cross(Vector((0,0,1)))
    if pointed:
        rise = width*.62
        shape = [(-.5,0),(.5,0),(.5,height-rise),(.46,height-rise*.59),(.34,height-rise*.32),(.18,height-rise*.13),(0,height),(-.18,height-rise*.13),(-.34,height-rise*.32),(-.46,height-rise*.59),(-.5,height-rise)]
    else:
        shape = [(-.5,0),(.5,0),(.5,height),(-.5,height)]
    points = [o+t*(u*width)+Vector((0,0,z)) for u,z in shape]
    if tile is not None:
        col, row = tile % 8, tile // 8
        uv = [((col+.035+(u+.5)*.93)/8,(row+.035+z/height*.93)/8) for u,z in shape]
    else:
        uv = [(u+.5,z/24) for u,z in shape]
    face(group, mat, points, uv)
    # Stone arch surround is genuine silhouette geometry, not a painted arch.
    if pointed:
        for i in range(1,len(shape)-1):
            a,b = points[i],points[i+1]
            aa = a+t*(.24 if shape[i][0]>0 else -.24)+Vector((0,0,.22))
            bb = b+t*(.24 if shape[i+1][0]>0 else -.24)+Vector((0,0,.22))
            face('Arched surrounds','trim',[a+n*.025,aa+n*.025,bb+n*.025,b+n*.025])


def rooms(origin, tangent, columns, floors, dx=3.6, dz=3.6, width=1.35, height=2.15):
    o,t = Vector(origin),Vector(tangent)
    for j in range(floors):
        for i in range(columns):
            p=o+t*((i-(columns-1)/2)*dx)+Vector((0,0,j*dz))
            # Wait until all walls/pillars exist before deciding which panes are visible.
            pending_rooms.append((p,t,width,height,int(rng.integers(0,64))))


def blocked_room(p,t,width,height):
    n=t.cross(Vector((0,0,1)))
    axis=0 if abs(n.x)>.5 else 1
    across=1-axis
    sign=n[axis]
    plane=p[axis]*sign
    for low,high in opaque_boxes:
        near,far=sorted((low[axis]*sign,high[axis]*sign))
        # Test nearby projecting masonry, not the opposite side of the courtyard.
        if near > plane+.3 or far <= plane+.005:
            continue
        if high[across] <= p[across]-width/2-.13 or low[across] >= p[across]+width/2+.13:
            continue
        if high.z <= p.z-.17 or low.z >= p.z+height:
            continue
        return True
    return False


def bay(cx, cy, bottom, top, radius, name):
    # Five front facets retain the distinctive glazed projecting lanterns.
    points = [(cx+radius*math.cos(a),cy-radius*math.sin(a)) for a in np.linspace(math.pi,0,6)]
    for i in range(5):
        a,b=Vector((*points[i],bottom)),Vector((*points[i+1],bottom))
        t=(b-a).normalized()
        width=(b-a).length
        n=t.cross(Vector((0,0,1)))
        # This rounded end is the wing envelope, not an overlay on a wider box.
        face(name,'stone',[a,b,b+Vector((0,0,top-bottom)),a+Vector((0,0,top-bottom))])
        panel(name,'curtain',(a+b)/2+n*.045+Vector((0,0,1.0)),t,width-.6,top-bottom-2.0,True)
        # Faceted stone piers and a base retain the low-poly silhouette.
        box('Bay piers','trim',(a.x,a.y,(bottom+top)/2),(.42,.42,top-bottom))
    box('Bay piers','trim',(*points[-1],(bottom+top)/2),(.42,.42,top-bottom))
    cap=[(x,y,top+.06) for x,y in points]
    face('Roof terraces','roof',cap)
    face('Roof terraces','trim',[(x,y,bottom) for x,y in reversed(points)])
    # Continuous rounded parapet matches the roof of the shortened rectangular wing.
    inner=[(cx+(x-cx)*(radius-.45)/radius,cy+(y-cy)*(radius-.45)/radius) for x,y in points]
    for i in range(5):
        a,b=points[i],points[i+1]
        ia,ib=inner[i],inner[i+1]
        face('Roof terraces','stone',[(*a,top),(*b,top),(*b,top+1.2),(*a,top+1.2)])
        face('Roof terraces','stone',[(*ib,top),(*ia,top),(*ia,top+1.2),(*ib,top+1.2)])
        face('Roof terraces','trim',[(*a,top+1.2),(*b,top+1.2),(*ib,top+1.2),(*ia,top+1.2)])
    front_bays.append({'center':[cx,0,-cy],'bottom':bottom,'top':top,'radius':radius,'segments':5})


# Primary volumes, separated into meaningful editable groups.
building('Central tower',0,17,55,27,128)
building('Lower central hall',0,-1,55,16,61)
for side in [-1,1]:
    building('Stepped wings',side*35,8,18,35,69)
    building('Stepped wings',side*35,-15.5,18,19,48,rounded_front=True)
    building('Outer pavilions',side*48,-5,8,26,29)
    bay(side*35,-25,0,48,9,'Front lantern bays')
    # Windows on courtyard walls and outer wings, never buried inside another mass.
    rooms((side*25.96,-17.5,5),(0,-side,0),4,11,dx=3.6,dz=3.6)
    rooms((side*44.04,-17.5,5),(0,side,0),4,11,dx=3.6,dz=3.6)
    rooms((side*44.04,8,31),(0,side,0),8,10,dx=3.7,dz=3.6)
    rooms((side*52.04,-5,4),(0,side,0),6,6,dx=3.6,dz=3.9)

# A central rank of arched curtain bays at the rear of the courtyard.
for x in [-20.5,-7,7,20.5]:
    panel('Central arched bays','curtain',(x,-9.05,10),(1,0,0),5.1,48,True)
for x in [-25,-13.8,0,13.8,25]:
    rooms((x,-9.09,12),(1,0,0),1,12,dz=3.7,width=1.05,height=2.0)

# Slender vertical tower piers / crest arches capture the photographed skyline.
for x in [-24,-16,-8,0,8,16,24]:
    box('Tower ribs','trim',(x,3.25,96),(.72,.7,60))
    box('Tower ribs','stone',(x,3.2,125.2),(1.2,1.0,5.6))
for x in [-20,-12,-4,4,12,20]:
    rooms((x,3.43,65),(1,0,0),1,11,dz=3.7,width=1.25,height=2.1)
    panel('Tower crown arches','curtain',(x,3.40,107),(1,0,0),2.8,14,True)

# All rear and side elevations are finished; traversal can view the asset from above.
rooms((0,30.56,5),(-1,0,0),14,32,dx=3.65,dz=3.7,width=1.25,height=2.05)
for side in [-1,1]:
    rooms((side*27.56,17,71),(0,side,0),6,14,dx=3.6,dz=3.7,width=1.25)
    rooms((side*35,25.56,5),(-1,0,0),4,17,dx=3.6,dz=3.65)
for x in [-25,-17,-9,0,9,17,25]:
    box('Tower ribs','trim',(x,30.63,65),(.55,.4,125))

# Mechanical roof furniture remains deliberately simple, low and readable.
for x,y,z,sx,sy in [(-13,18,129,9,6),(8,20,129,12,6),(0,7,129,7,4),(-35,10,70,6,8),(35,10,70,6,8)]:
    box('Roof equipment','metal',(x,y,z+1.2),(sx,sy,2.4))
    box('Roof equipment','trim',(x,y,z+2.5),(sx+.4,sy+.4,.22))
    for dx in [-1.5,1.5]:
        box('Roof equipment','roof',(x+dx,y,z+2.7),(1.8,sy*.7,.2))

# Open central approach: low entrance pavilion, bronze-framed canopy and signage.
building('Entrance pavilion',0,-14,29,10,9)
box('Entrance apron','paving',(0,-27,.12),(48,29,.24),True)
box('Entrance doors','metal',(0,-19.10,3.2),(11,.15,6))
panel('Entrance doors','curtain',(0,-19.20,.4),(1,0,0),10.6,5.8)
for x in [-5.4,-2.7,0,2.7,5.4]:
    box('Entrance doors','metal',(x,-19.29,3.2),(.13,.12,5.7))
box('Entrance sign','teal',(0,-19.18,7.55),(26,.22,1.7))
box('Canopy','canopy_frame',(0,-25.2,5.4),(21,12.3,.23))
face('Canopy','canopy',[(-10.25,-31.1,5.57),(10.25,-31.1,5.57),(10.25,-19.3,5.57),(-10.25,-19.3,5.57)],[(0,0),(4,0),(4,3),(0,3)])
for x in [-8.5,8.5]:
    box('Canopy','sign',(x,-25.2,5.25),(.12,10.8,.08))
for x in [-9.7,9.7]:
    for y in [-29.8,-22]:
        box('Canopy','canopy_frame',(x,y,2.75),(.22,.22,5.5))
for x in np.linspace(-10.25,10.25,5):
    box('Canopy','canopy_frame',(float(x),-25.2,5.64),(.11,11.9,.14))
for y in np.linspace(-31.1,-19.3,4):
    box('Canopy','canopy_frame',(0,float(y),5.64),(20.6,.11,.14))
for side in [-1,1]:
    if side == -1:
        box('Wayfinding','teal',(side*19,-34,2.4),(1.8,.65,4.8),True)
        box('Wayfinding','trim',(side*19,-34,.18),(2.1,.9,.36))
    for y in [-35,-29,-23]:
        box('Bollards','metal',(side*11.3,y,.62),(.22,.22,1.24))
        box('Bollards','sign',(side*11.3,y,1.13),(.235,.235,.14))


def lettering(name, text, position, size, mat='sign'):
    curve=bpy.data.curves.new(name,'FONT')
    curve.body=text
    curve.size=size
    curve.align_x='CENTER'
    curve.align_y='CENTER'
    curve.extrude=.013
    curve.resolution_u=2
    ob=bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(ob)
    ob.location=position
    ob.rotation_euler=(math.pi/2,0,0)
    ob.data.materials.append(mats[mat])
    bpy.context.view_layer.objects.active=ob
    ob.select_set(True)
    bpy.ops.object.convert(target='MESH')
    ob.select_set(False)
    return ob


lettering('Hospital lettering','MEDICAL CENTER',(0,-19.34,7.53),1.05)
for side in [-1]:
    lettering('H wayfinding','H',(side*19,-34.34,3.5),1.3)
    lettering('Entry wayfinding','ENTRY',(side*19,-34.34,1.95),.29)
    lettering('Arrow wayfinding','>',(side*19,-34.34,1.2),.7)

omitted_rooms=0
visible_rooms=[]
for p,t,width,height,tile in pending_rooms:
    if blocked_room(p,t,width,height):
        omitted_rooms+=1
        continue
    panel('Room windows','window',p,t,width,height,tile=tile)
    # The existing room atlas includes a painted sill; no projecting sill box.
    visible_rooms.append({'origin':[p.x,p.z,-p.y],'width':width,'height':height})

for name,(verts,faces,uvs,slots) in buffers.items():
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    used=list(dict.fromkeys(slots))
    for key in used:
        mesh.materials.append(mats[key])
    layer=mesh.uv_layers.new(name='UVMap')
    cursor=0
    for poly,key in zip(mesh.polygons,slots):
        poly.material_index=used.index(key)
        for loop in poly.loop_indices:
            layer.data[loop].uv=uvs[cursor]
            cursor+=1
    # Non-planar input is avoided; triangulate only on export, keep blend editable.
    assert mesh.validate(verbose=True) is False, name

asset_objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
collection=bpy.data.collections.new('HOSPITAL | export geometry')
bpy.context.scene.collection.children.link(collection)
for ob in asset_objects:
    for source in list(ob.users_collection):
        source.objects.unlink(ob)
    collection.objects.link(ob)
    ob['asset_role']='hospital_exterior'
bpy.context.scene.unit_settings.system='METRIC'
bpy.context.scene.unit_settings.scale_length=1.0

# Export only geometry; no preview ground, lamps or cameras in the GLB.
bpy.ops.object.select_all(action='DESELECT')
for ob in asset_objects:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(HERE/'hospital.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_cameras=False,export_lights=False)
triangles=0
for ob in asset_objects:
    ob.data.calc_loop_triangles()
    triangles+=len(ob.data.loop_triangles)
all_points=[ob.matrix_world @ v.co for ob in asset_objects for v in ob.data.vertices]
minimum=[min(v[i] for v in all_points) for i in range(3)]
maximum=[max(v[i] for v in all_points) for i in range(3)]
assert triangles <= 10000, f'Hospital exceeds the POI triangle limit: {triangles}'
report={'mesh_objects':len(asset_objects),'triangles':triangles,'materials':len(mats),
        'blender_bounds_min':minimum,'blender_bounds_max':maximum,
        'godot_front':'+Z','units':'metres','collision_boxes':collision_boxes,
        'front_bays':front_bays,'room_window_count':len(visible_rooms),
        'omitted_obscured_rooms':omitted_rooms,'room_windows':visible_rooms,
        'revision':'2026-09-13: removed projecting window sill boxes; painted atlas sills retained'}
(HERE/'hospital_manifest.json').write_text(json.dumps(report,indent=2))

# Editable presentation rig, isolated from the model; retained in .blend only.
rig=bpy.data.collections.new('PREVIEW ONLY | not exported')
bpy.context.scene.collection.children.link(rig)
def rig_object(ob):
    for source in list(ob.users_collection): source.objects.unlink(ob)
    rig.objects.link(ob)
    return ob
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.08))
ground=rig_object(bpy.context.object)
ground.name='Preview ground (not exported)'
ground.data.materials.append(material('Preview ground',(.13,.17,.18)))
bpy.ops.object.camera_add(location=(164,-230,152))
camera=rig_object(bpy.context.object)
camera.rotation_euler=(Vector((0,0,61))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=185
bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(0,0,180))
sun=rig_object(bpy.context.object)
sun.rotation_euler=(math.radians(28),math.radians(-24),math.radians(-32))
sun.data.energy=2.5
sun.data.angle=.13
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1400
scene.render.resolution_y=1400
scene.render.resolution_percentage=100
scene.world.color=(.28,.28,.28)
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
# Relative, packed images make the .blend portable while external PNGs stay reusable.
for img in [stone_image,stone_rough,window_image,window_emit,curtain_image,curtain_emission,canopy_image]:
    img.pack()
    img.filepath=bpy.path.relpath(img.filepath,start=str(HERE))
bpy.ops.object.select_all(action='DESELECT')
for ob in asset_objects: ob.select_set(True)
bpy.context.view_layer.objects.active=asset_objects[0]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.clip_end = 5000
            space.region_3d.view_location = Vector((0,0,62))
            space.region_3d.view_distance = 230
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_perspective = 'PERSP'
            space.shading.color_type = 'MATERIAL'
            space.overlay.show_floor = False
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'hospital.blend'))
for key in ['window','curtain','sign']:
    mats[key].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=0
scene.render.filepath=str(PREVIEWS/'hospital_blender_day.png')
bpy.ops.render.render(write_still=True)
print('HOSPITAL_COMPLETE '+json.dumps({k:v for k,v in report.items() if k not in ['collision_boxes','room_windows']}))
