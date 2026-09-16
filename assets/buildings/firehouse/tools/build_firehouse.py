"""Original low-poly firehouse. Blender units are metres; front is -Y (+Z in Godot).
Run with Blender --background --python assets/buildings/firehouse/tools/build_firehouse.py.
"""
import bpy
import json
import math
from pathlib import Path
from collections import defaultdict
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parents[1]
OUT = HERE.parents[2] / 'artifacts/firehouse'
for folder in [HERE / 'props', OUT]:
    folder.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1
rng = np.random.default_rng(1907)
buffers = defaultdict(lambda: [[], [], [], []])
materials = {}
collisions = []

def texture(name, pixels):
    height,width = pixels.shape[:2]
    image = bpy.data.images.new(name,width=width,height=height,alpha=True)
    rgba = np.ones((height,width,4),dtype=np.float32)
    rgba[:,:,:pixels.shape[2]] = pixels
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(HERE / (name+'.png'))
    image.file_format = 'PNG'
    image.save()
    return image

def material(name, color, image=None, emission=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color,1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color,1)
    bs.inputs['Roughness'].default_value = .82
    for im,socket in [(image,'Base Color'),(emission,'Emission Color')]:
        if im is not None:
            node = m.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = im
            m.node_tree.links.new(node.outputs['Color'],bs.inputs[socket])
    if emission is not None:
        bs.inputs['Emission Strength'].default_value = 1
    materials[name] = m
    return m

# Seamless running-bond brick. A tile spans 2 x 2 m: bricks are about 25 x 6.25 cm.
y,x = np.mgrid[:1024,:1024]
rows = y//32
offset_x = (x+(rows%2)*64)%1024
brick_id = offset_x//128
variations = rng.uniform(-.04,.04,(32,8))
shade = variations[rows,brick_id] + rng.normal(0,.008,x.shape)
rgb = np.array([.28,.095,.055]) + shade[:,:,None]*np.array([1,.48,.30])
mortar = (y%32<3) | (offset_x%128<3)
rgb[mortar] = [.22,.18,.135]
brick_image = texture('firehouse_brick',np.clip(rgb,0,1))
material('Historic red brick',(.28,.095,.055),brick_image)
material('Terracotta cornice',(.25,.065,.035))
material('Sandstone',(.55,.48,.34))
material('Charcoal metal',(.035,.045,.045))
material('Roof membrane',(.065,.075,.075))
material('Engine red',(.23,.025,.018))
material('Old gold lettering',(.72,.51,.20))
material('Dark glass',(.025,.055,.060))

# One 2x2 atlas: rectangular sash, fanlight door, tower louver, service door.
# Trim, sills, muntins, louvers and door subdivisions are painted, not meshed.
atlas = np.zeros((1024,1024,3),dtype=np.float32)
emit = np.zeros_like(atlas)
yy,xx = np.mgrid[:512,:512]
for cell in range(4):
    col,row = cell%2,cell//2
    tile = np.zeros((512,512,3),dtype=np.float32)
    tile[:] = [.10,.035,.022]
    mask = np.zeros((512,512),dtype=bool)
    if cell == 0:
        inner = (xx>38)&(xx<474)&(yy>36)&(yy<477)
        tile[inner] = [.095,.17,.19]
        frame = (abs(xx-256)<5)|(abs(yy-256)<7)
        tile[inner & frame] = [.075,.025,.018]
        mask = inner & ~frame
        tile[(yy>15)&(yy<31)] = [.55,.48,.34]
        tile[yy<=15] = [.09,.035,.02]
        tile[(yy>481)] = [.35,.12,.07]
        tile[mask & (yy>300)] *= .70
    elif cell == 1:
        tile[:] = [.23,.025,.018]
        inner = (xx>18)&(xx<494)&(yy>32)&(yy<482)
        grid = (xx%160<10)|(yy%84<10)
        mask = inner & ~grid
        tile[mask] = [.04,.09,.105]
        tile[(yy>26)&(yy<38)] = [.065,.07,.065]
        # Roller door rails, central lock and small brass handles.
        tile[(abs(xx-256)<18)&(abs(yy-200)<4)] = [.55,.40,.17]
    elif cell == 2:
        inner=(xx>36)&(xx<476)&(yy>32)&(yy<480)
        tile[inner] = [.028,.037,.034]
        slat=inner & (yy%36<10)
        tile[slat] = [.105,.085,.055]
        tile[(yy<25)|(yy>487)] = [.40,.15,.075]
    else:
        tile[:] = [.23,.025,.018]
        inner=(xx>55)&(xx<457)&(yy>150)&(yy<450)
        tile[inner] = [.045,.09,.10]
        mask=inner & (abs(yy-300)>6)
        tile[(xx>405)&(xx<430)&(yy>100)&(yy<130)] = [.60,.44,.18]
    atlas[row*512:(row+1)*512,col*512:(col+1)*512] = tile
    glow = np.zeros_like(tile)
    if cell != 2:
        glow[mask] = np.array([.55,.36,.15])*(.60 if cell==1 else .85)
    emit[row*512:(row+1)*512,col*512:(col+1)*512] = glow
atlas_image = texture('firehouse_details_albedo',atlas)
emission_image = texture('firehouse_details_emission',emit)
material('Painted windows and doors',(.1,.15,.16),atlas_image,emission_image)
material('Unlit window details',(.1,.15,.16),atlas_image)
lamp = material('Warm fixture glass',(.80,.62,.32))
lamp.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value = (1,.65,.28,1)
lamp.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 1

def face(group,mat,points,uv=None):
    vs,fs,uvs,ms = buffers[group]
    start=len(vs)
    vs.extend([tuple(p) for p in points])
    fs.append(tuple(range(start,start+len(points))))
    if uv is None:
        a,b,c=map(Vector,points[:3])
        normal=(b-a).cross(c-a)
        axis=max(range(3),key=lambda i:abs(normal[i]))
        axes=[i for i in range(3) if i!=axis]
        uv=[(p[axes[0]]/2,p[axes[1]]/2) for p in points]
    uvs.extend(uv)
    ms.append(mat)

CUBE=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
def box(group,mat,center,size,collision=False):
    x,y,z=center
    a,b,c=[s/2 for s in size]
    points=[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
            (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
    for f in CUBE:face(group,mat,[points[i] for i in f])
    if collision:
        collisions.append({'name':group,'center':[x,z,-y],'size':[size[0],size[2],size[1]]})

def panel(group,p,t,width,height,cell=0,lit=True,arched=False):
    p,t=Vector(p),Vector(t)
    outline=[(-width/2,0),(width/2,0)]
    if arched:
        rise=.72
        outline += [(math.cos(i*math.pi/8)*width/2,height-rise+math.sin(i*math.pi/8)*rise) for i in range(9)]
    else: outline += [(width/2,height),(-width/2,height)]
    col,row=cell%2,cell//2
    uv=[((col+.012+(a/width+.5)*.976)/2,(row+.012+b/height*.976)/2) for a,b in outline]
    face(group,'Painted windows and doors' if lit else 'Unlit window details',[p+t*a+Vector((0,0,b)) for a,b in outline],uv)

def cylinder(group,mat,center,radius,height,segments=8):
    x,y,z=center
    points=[(x+math.cos(i*math.tau/segments)*radius,y+math.sin(i*math.tau/segments)*radius,z+h)
            for h in [-height/2,height/2] for i in range(segments)]
    face(group,mat,list(reversed(points[:segments])))
    face(group,mat,points[segments:])
    for i in range(segments):
        j=(i+1)%segments
        face(group,mat,[points[i],points[j],points[j+segments],points[i+segments]])

# Main envelope and asymmetrical hose tower. No interior or operable garage doors.
box('Engine house masonry','Historic red brick',(3,0,6.8),(28,22,13.6),True)
box('Hose tower masonry','Historic red brick',(-14,-7.25,12.7),(5.8,7.5,25.4),True)
# Stop the main plinth behind the rear door plane. Split its projecting rear
# strip around the doorway so the stone band cannot cover the bottom of the door.
box('Stone foundation','Sandstone',(3,-.055,.28),(28.2,22.04,.56))
for left,right in [(-11.1,1.0),(3.0,17.1)]:
    box('Stone foundation','Sandstone',((left+right)/2,11.02,.28),(right-left,.11,.56))
box('Tower foundation','Sandstone',(-14,-7.25,.28),(5.95,7.65,.56))
for z,thickness,over,mat in [(6.45,.26,.12,'Terracotta cornice'),(12.2,.22,.20,'Terracotta cornice'),
                            (12.75,.32,.50,'Terracotta cornice'),(13.7,.20,.30,'Terracotta cornice')]:
    box('Main cornices',mat,(3,-11,z),(28+over,.45+over,thickness))
    for side in [-1,1]:box('Return cornices',mat,(3+side*14,0,z),(.30,22,thickness))
    box('Rear cornices',mat,(3,11,z),(28,.30,thickness))
box('Main roof','Roof membrane',(3,0,13.62),(27.5,21.5,.12),True)
for x in [-10.85,16.85]:box('Roof parapets','Historic red brick',(x,0,14),(.30,22,1),True)
for y in [-10.85,10.85]:box('Roof parapets','Historic red brick',(3,y,14),(28,.30,1),True)
for x in [-10.85,16.85]:box('Parapet caps','Terracotta cornice',(x,0,14.55),(.50,22.3,.16))
for y in [-10.85,10.85]:box('Parapet caps','Terracotta cornice',(3,y,14.55),(28.3,.50,.16))
# Slightly projecting piers between bays retain depth where it matters.
for x in [-10.65,-4,3,10,16.65]:
    box('Front brick piers','Historic red brick',(x,-11.12,5.95),(.52,.28,11.9))
    box('Pier bases','Sandstone',(x,-11.18,.40),(.65,.42,.80))
for number,x in enumerate([-7.5,-.5,6.5,13.5],1):
    panel('Engine bay doors',(x,-11.285,.10),(1,0,0),5.25,5.7,1,True,True)
    # Broad arch band and keystone; garage arches define the entrance silhouette.
    for i in range(8):
        a,b=i*math.pi/8,(i+1)*math.pi/8
        face('Engine bay arches','Historic red brick',[(x+math.cos(t)*r,-11.31,5.08+math.sin(t)*h)
             for t,r,h in [(a,2.625,.72),(a,2.90,.99),(b,2.90,.99),(b,2.625,.72)]])
    box('Bay keystones','Sandstone',(x,-11.36,6.01),(.34,.20,.50))
    for dx,w in [(-1.85,.85),(0,1.50),(1.85,.85)]:
        panel('Upper sash windows',(x+dx,-11.17,8.0),(1,0,0),w,3.2,0,number%3!=0)
    # A thin shadow course above each triplet, without individual sill geometry.
    box('Brick lintel course','Historic red brick',(x,-11.13,11.5),(5.45,.20,.40))
# Side and rear elevations, with deliberately blank wall where tower touches main house.
for side in [-1,1]:
    for y in [-7,-2,3,8]:
        if side==-1 and y < -3:continue
        for z in [2.4,8.0]:
            panel('Side sash windows',(3+side*14.025,y,z),(0,side,0),1.25,2.9,0,(int(y)+int(z))%3!=0)
for x in [-8,-3,2,7,12]:
    for z in [2.4,8.0]:
        if x==2 and z==2.4:continue  # Leave a clear opening for the service door.
        panel('Rear sash windows',(x,11.025,z),(-1,0,0),1.4,2.9,0,x%3!=0)
panel('Rear service door',(2,11.045,0),(-1,0,0),1.6,2.8,3,False)
for x in [1.1,2.9]:
    box('Rear door frame','Sandstone',(x,11.075,1.4),(.20,.20,2.8))
box('Rear door frame','Sandstone',(2,11.075,2.9),(2,.20,.20))
# Tower entrance, slit windows and louvered drying chamber.
panel('Watch office entry',(-14,-11.09,.03),(1,0,0),1.8,3.25,3)
box('Entry hood','Terracotta cornice',(-14,-11.34,3.65),(3.3,.85,.28))
for z in [7.2,12.5,16.2]:
    for x in [-14.7,-13.3]:panel('Tower slit windows',(x,-11.03,z),(1,0,0),.55,2.15,0,False)
for p,t in [((-14,-11.035,21),(1,0,0)),((-16.935,-7.25,21),(0,-1,0)),
            ((-11.065,-7.25,21),(0,1,0)),((-14,-3.465,21),(-1,0,0))]:
    panel('Tower louvers',p,t,3.4,2.7,2,False)
for z,w,d,h in [(4.05,6.3,8,.25),(19.9,6.3,8,.30),(24.7,6.5,8.2,.40),(25.35,6.8,8.5,.28)]:
    box('Tower cornices','Terracotta cornice',(-14,-7.25,z),(w,d,h))
box('Tower roof','Roof membrane',(-14,-7.25,25.45),(5.5,7.2,.15),True)
for x in [-16.75,-11.25]:box('Tower crown','Historic red brick',(x,-7.25,25.8),(.30,7.5,.8),True)
for y in [-10.85,-3.65]:box('Tower crown','Historic red brick',(-14,y,25.8),(5.8,.30,.8),True)
box('Tower crest','Terracotta cornice',(-14,-11,26.4),(4.5,.5,.45))
box('Tower crest','Terracotta cornice',(-14,-11,26.75),(3.5,.45,.25))
# Small useful exterior details, all low-sided or boxes.
for x in [-10.8,-4,3,10,16.8]:
    box('Wall lamp mounts','Charcoal metal',(x,-11.42,5.05),(.16,.35,.42))
    box('Wall lamps','Warm fixture glass',(x,-11.62,5.10),(.25,.24,.34))
    box('Lamp caps','Charcoal metal',(x,-11.62,5.31),(.36,.32,.09))
for x,y in [(-9,9),(15,9)]:
    box('Rain downpipes','Charcoal metal',(x,11.24,6.3),(.13,.13,12.6))
for x in [-5,9]:
    box('Rooftop ventilators','Charcoal metal',(x,4,14.10),(1.5,1.5,.85))
    box('Ventilator caps','Terracotta cornice',(x,4,14.6),(1.8,1.8,.15))
box('Brick chimney','Historic red brick',(14,8,15.1),(1.2,1.3,3))
box('Chimney cap','Sandstone',(14,8,16.65),(1.55,1.65,.20))
box('Alarm cabinet','Engine red',(-16.25,-11.17,1.25),(.50,.26,.72))
box('Alarm glass','Dark glass',(-16.25,-11.32,1.34),(.32,.02,.35))

def meshes(collection):
    result=[]
    for name,(vs,fs,uvs,slots) in buffers.items():
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(vs,[],fs)
        mesh.update()
        assert not mesh.validate(),name
        ob=bpy.data.objects.new(name,mesh)
        collection.objects.link(ob)
        used=list(dict.fromkeys(slots))
        for key in used:mesh.materials.append(materials[key])
        layer=mesh.uv_layers.new(name='UVMap')
        cursor=0
        for poly,key in zip(mesh.polygons,slots):
            poly.material_index=used.index(key)
            for loop in poly.loop_indices:
                layer.data[loop].uv=uvs[cursor];cursor+=1
        result.append(ob)
    buffers.clear()
    return result

architecture=bpy.data.collections.new('FIREHOUSE | exterior architecture')
bpy.context.scene.collection.children.link(architecture)
asset=meshes(architecture)
def lettering(text,position,size,mat='Old gold lettering'):
    curve=bpy.data.curves.new('Historic lettering','FONT')
    curve.body=text;curve.align_x='CENTER';curve.size=size;curve.resolution_u=1;curve.extrude=0
    ob=bpy.data.objects.new(text,curve);architecture.objects.link(ob)
    ob.location=position;ob.rotation_euler=(math.pi/2,0,0)
    curve.materials.append(materials[mat])
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.convert(target='MESH');asset.append(bpy.context.object)
lettering('ENGINE HOUSE  No. 7',(3,-11.36,6.92),.63)
lettering('1907',(-14,-11.28,19.20),.60)
for number,x in enumerate([-7.5,-.5,6.5,13.5],1):lettering(str(number),(x,-11.475,5.93),.24,'Charcoal metal')

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_cameras=False,export_lights=False)

# One separate stone bench design, instanced on the rear wall side.
props=bpy.data.collections.new('PROPS | independently editable')
bpy.context.scene.collection.children.link(props)
box('Stone bench','Sandstone',(0,0,.48),(2,.55,.16))
for x in [-.65,.65]:box('Stone bench','Sandstone',(x,0,.20),(.28,.42,.40))
bench=meshes(props)[0]
export(HERE/'props/bench.glb',[bench])
placements=[]
for index,x in enumerate([-5,11]):
    ob=bpy.data.objects.new('Bench_%02d'%index,bench.data);props.objects.link(ob)
    ob.location=(x,11.65,0)
    placements.append({'kind':'bench','name':ob.name,'position':[x,0,-11.65],'rotation_y':0})
bpy.data.objects.remove(bench,do_unlink=True)
def triangles(objects):
    total=0
    for ob in objects:ob.data.calc_loop_triangles();total+=len(ob.data.loop_triangles)
    return total
base_triangles=triangles(asset)
total=base_triangles+triangles(list(props.objects))
assert total<10000,f'POI budget exceeded: {total}'
export(HERE/'firehouse.glb',asset)
points=[ob.matrix_world @ v.co for ob in asset+list(props.objects) for v in ob.data.vertices]
report={'units':'metres','godot_front':'+Z','base_triangles':base_triangles,'total_triangles':total,
        'base_meshes':len(asset),'props':placements,'bench_triangles':36,'collision_boxes':collisions,
        'bounds_min_blender':[min(p[i] for p in points) for i in range(3)],
        'bounds_max_blender':[max(p[i] for p in points) for i in range(3)],
        'mesh_triangles':{ob.name:triangles([ob]) for ob in asset},'triangle_limit':10000}
(HERE/'firehouse_manifest.json').write_text(json.dumps(report,indent=2))

rig=bpy.data.collections.new('PREVIEW ONLY | not exported');bpy.context.scene.collection.children.link(rig)
def rig_ob(ob):
    for col in list(ob.users_collection):col.objects.unlink(ob)
    rig.objects.link(ob);return ob
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.03))
ground=rig_ob(bpy.context.object);ground.data.materials.append(material('Preview pavement',(.15,.17,.16)))
bpy.ops.object.camera_add(location=(49,-70,38));camera=rig_ob(bpy.context.object)
camera.rotation_euler=(Vector((0,0,11))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=61;bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(0,0,80));sun=rig_ob(bpy.context.object)
sun.rotation_euler=(.40,-.5,-.4);sun.data.energy=2.5;sun.data.angle=.12
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.world.color=(.25,.25,.25);scene.view_settings.view_transform='AgX'
for im in bpy.data.images:
    if im.source=='FILE':im.pack();im.filepath=bpy.path.relpath(im.filepath,start=str(HERE))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.clip_end=4000;space.region_3d.view_location=Vector((0,0,11))
            space.region_3d.view_distance=70;space.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
            space.shading.color_type='MATERIAL'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'firehouse.blend'))
for mat in materials.values():mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=0
scene.render.filepath=str(OUT/'firehouse_blender.png');bpy.ops.render.render(write_still=True)
print('FIREHOUSE_COMPLETE '+json.dumps({k:v for k,v in report.items() if k not in ['collision_boxes','mesh_triangles']}))
