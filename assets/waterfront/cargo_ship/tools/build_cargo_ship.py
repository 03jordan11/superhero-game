"""Original reference-inspired container ship. Run with Blender --background --python.
Authoring coordinates: X starboard, +Y bow, Z up. glTF/Godot: bow -Z, waterline Y=0.
All output is confined to cargo_ship and artifacts/cargo_ship. No lettering is generated.
"""
import bpy, bmesh, math, json, struct
import numpy as np
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[2]
OUT = ROOT / 'artifacts/cargo_ship'
for p in (BASE/'textures', BASE/'materials', OUT): p.mkdir(parents=True, exist_ok=True)
(OUT/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
rng = np.random.default_rng(4261)
materials = {}
objects = []
collision_boxes = []

def srgb(c):
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in c)

def texture(name, rgb):
    h,w = rgb.shape[:2]
    image = bpy.data.images.new(name, width=w, height=h, alpha=True)
    rgba = np.ones((h,w,4), np.float32)
    rgba[:,:,:3] = np.clip(rgb,0,1)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(BASE/'textures'/f'{name}.png')
    image.file_format = 'PNG'
    image.save()
    return image

# Three panels in one shared grayscale atlas: ribbed sides, unlabelled doors, roof.
y,x = np.mgrid[:1024,:1024]
atlas = np.ones((1024,1024,3), np.float32)*.8
sx,sy = x[:,:512]/511, y[:,:512]/1023
rib = .80 + .12*np.cos(sx*math.tau*38) + .025*np.sin(sx*math.tau*76)
edge = (sx<.025)|(sx>.975)|(sy<.045)|(sy>.955)
rib[edge] = .59
rib[(sy>.93)&(sy<.955)] = .94
rib -= .12*np.exp(-sy*15)
rib += rng.normal(0,.013,rib.shape)
atlas[:,:512] = rib[:,:,None]
dx,dy = x[:512,:512]/511, y[:512,:512]/511
door = .78 + .035*np.cos(dx*math.tau*8)
door[(dx<.04)|(dx>.96)|(dy<.04)|(dy>.96)|(abs(dx-.5)<.012)] = .40
for line in [.17,.36,.64,.83]:
    door[abs(dx-line)<.009] = .43
    door[(dx>line)&(dx<line+.009)] = .95
    for height in [.24,.75]:
        door[(abs(dx-line)<.034)&(abs(dy-height)<.013)] = .40
atlas[:512,512:] = door[:,:,None]
roof = .84 + .065*np.cos(dx*math.tau*20)
roof[(dx<.02)|(dx>.98)|(dy<.025)|(dy>.975)] = .49
atlas[512:,512:] = roof[:,:,None]
container_image = texture('container_panels',atlas)
y,x = np.mgrid[:512,:512]
weather = .83 + .025*np.sin(x*.053) * np.sin(y*.009) + rng.normal(0,.009,(512,512))
weather -= .09*np.exp(-(y/512)*12)
weather[(y%128)<2] -= .05
steel_image = texture('painted_steel',np.repeat(weather[:,:,None],3,axis=2))

def material(name,color,image=None,metallic=.15,roughness=.7):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*srgb(color),1)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=m.diffuse_color
    bs.inputs['Metallic'].default_value=metallic
    bs.inputs['Roughness'].default_value=roughness
    if image:
        tx=m.node_tree.nodes.new('ShaderNodeTexImage'); tx.image=image
        multiply=m.node_tree.nodes.new('ShaderNodeMixRGB'); multiply.blend_type='MULTIPLY'
        multiply.inputs[0].default_value=1
        multiply.inputs[2].default_value=m.diffuse_color
        m.node_tree.links.new(tx.outputs['Color'],multiply.inputs[1])
        m.node_tree.links.new(multiply.outputs[0],bs.inputs['Base Color'])
    materials[name]=m

palette = {'Hull':(.075,.37,.59),'Deck':(.50,.30,.17),'BootStripe':(.095,.12,.13),
 'Antifouling':(.35,.13,.085),'Superstructure':(.84,.83,.76),'Steel':(.48,.53,.54),
 'DarkSteel':(.07,.095,.11),'Glass':(.075,.16,.205),'SafetyOrange':(.86,.27,.055),
 'ContainerA':(.13,.57,.63),'ContainerB':(.77,.31,.15),'ContainerC':(.83,.83,.77),
 'ContainerD':(.21,.29,.33)}
for name,col in palette.items():
    material(name,col,container_image if name.startswith('Container') else steel_image if name in ['Hull','Deck','Superstructure','Antifouling'] else None,
             .35 if name in ['Steel','Glass'] else .12, .24 if name=='Glass' else .72)

def mesh(name,verts,faces,mat,uvs=None):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
    me.materials.append(materials[mat]); objects.append(ob)
    uv=me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        for n,li in enumerate(poly.loop_indices):
            uv.data[li].uv=uvs[poly.index][n] if uvs else ((verts[me.loops[li].vertex_index][1]+78)/30, (verts[me.loops[li].vertex_index][2]+6)/12)
    return ob

def box(name,center,size,mat,collide=False,container=False):
    cx,cy,cz=center; a,b,c=[v/2 for v in size]
    vs=[(cx+xx*a,cy+yy*b,cz+zz*c) for xx,yy,zz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    fs=[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
    rectangles=[(.51,.51,.99,.99),(.51,.01,.99,.49),(.01,.01,.49,.99),(.51,.01,.99,.49),(.01,.01,.49,.99),(.51,.51,.99,.99)]
    uv=[]
    for i in range(6):
        u0,v0,u1,v1=rectangles[i] if container else (0,0,1,1)
        uv.append([(u0,v0),(u1,v0),(u1,v1),(u0,v1)])
    ob=mesh(name,vs,fs,mat,uv)
    if collide:
        collision_boxes.append({'name':name,'center':[cx,cz,-cy],'size':[size[0],size[2],size[1]]})
    return ob

def rod(name,a,b,r,mat,segments=6):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized()
    tangent=axis.cross(Vector((0,0,1)) if abs(axis.z)<.95 else Vector((1,0,0))).normalized()
    bitangent=axis.cross(tangent)
    vs=[tuple(p+r*(math.cos(i*math.tau/segments)*tangent+math.sin(i*math.tau/segments)*bitangent)) for p in (a,b) for i in range(segments)]
    fs=[tuple(range(segments-1,-1,-1)),tuple(range(segments,2*segments))]
    fs += [(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
    return mesh(name,vs,fs,mat)

stations=[(-78,7.5,5),(-74,10.8,5),(-64,12,5),(-43,12,5),(24,12,5),(48,11.9,5),(60,10.3,6.2),(70,6.8,7),(78,.08,7.6)]
def hull_band(name,lower,upper,mat):
    vs=[]
    for yy,w,deck in stations:
        for level,factor in (lower,upper):
            z=deck if level=='deck' else level
            vs.extend([(-w*factor,yy,z),(w*factor,yy,z)])
    fs=[]
    for i in range(len(stations)-1):
        a=i*4;b=a+4
        fs.extend([(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)])
    fs += [(0,2,3,1),(32,33,35,34)]
    return mesh(name,vs,fs,mat)
hull_band('UnderwaterHull',(-6,.60),(-2.5,.94),'Antifouling')
hull_band('WaterlineHull',(-2.5,.94),(.3,.99),'Antifouling')
hull_band('WaterlineBoot',(.3,.99),(.75,.991),'BootStripe')
hull_band('PaintedHull',(.75,.991),('deck',1),'Hull')
vs=[]
for yy,w,z in stations: vs.extend([(-w,yy,z),(w,yy,z)])
deck=mesh('WeatherDeck',vs,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(8)],'Deck')
# Raised forecastle and its continuous low bulwark; bow curve follows the hull.
for i in range(len(stations)-1):
    ya,wa,za=stations[i];yb,wb,zb=stations[i+1]
    for s in [-1,1]:
        rod('Gunwale',(s*wa,ya,za+.14),(s*wb,yb,zb+.14),.13,'Superstructure',4)
        if i>=5:
            mesh('BowBulwark',[(s*wa,ya,za),(s*wb,yb,zb),(s*wb,yb,zb+.95),(s*wa,ya,za+.95)],[(0,1,2,3)],'Hull')

# Eight bays, seven ISO-width lanes, varied stacks and a low bow-facing first row.
count=0
for bay in range(8):
    yy=-42+bay*12.45
    for lane in range(7):
        xx=(lane-3)*2.54
        tiers=2+int((bay+lane*2)%5!=0)
        if bay in [0,7]: tiers=2 if lane%3 else 1
        if bay in [3,4] and lane in [2,3,4]: tiers=4
        for tier in range(tiers):
            key=['ContainerA','ContainerB','ContainerC','ContainerD'][int(rng.choice(4,p=[.34,.23,.30,.13]))]
            box('Cargo', (xx,yy,5.25+1.295+tier*2.64),(2.44,12.19,2.59),key,True,True)
            count+=1
for yy in [-48.2,-23.3,1.6,26.5,51.4]:
    box('HatchCoaming',(0,yy,5.18),(19,.22,.36),'DarkSteel')

# Aft accommodation block, bridge wings, brow, funnel and rooftop equipment.
box('Accommodation',(0,-62,12),(16,15,14),'Superstructure',True)
for z in [8.5,11.5,14.5,18.5]:
    box('DeckLip',(0,-62,z),(16.5,15.5,.2),'Superstructure')
box('Bridge',(0,-60,20),(19.6,11.5,3),'Superstructure',True)
box('BridgeRoof',(0,-60,21.7),(21.3,12.4,.38),'Superstructure',True)
for side in [-1,1]:
    box('BridgeWing',(side*10.6,-56,18.85),(2.8,5.7,.38),'Superstructure',True)
    box('SideScreen',(side*11.5,-54.2,19.7),(.15,1.5,1.2),'DarkSteel')
    for z in [8.7,11.7,14.7]:
        for yy in [-67,-63,-59,-56]:
            box('CabinGlass',(side*8.012,yy,z),(.025,1.15,1.05),'Glass')
    for yy in [-63.8,-61.3,-58.8,-56.3]:
        box('BridgeGlass',(side*9.812,yy,20.15),(.025,1.9,1.45),'Glass')
for xx in [-8,-5.7,-3.4,-1.1,1.2,3.5,5.8,8.1]:
    box('ForwardBridgeGlass',(xx,-54.235,20.15),(1.9,.025,1.45),'Glass')
for xx in [-6,-3,0,3,6]:
    box('AftGlass',(xx,-69.515,14.7),(1.2,.025,1),'Glass')
box('Funnel',(4.6,-66,24),(4,4.5,5),'Superstructure',True)
box('FunnelCowl',(4.6,-66,26.25),(4.25,4.7,1),'DarkSteel')
for xx in [3.7,5.5]: rod('Exhaust',(xx,-66,26.5),(xx,-66,27.2),.42,'DarkSteel',8)
for xx in [-5,-2]: box('Ventilation',(xx,-63,22.6),(1.8,3.3,1.5),'Steel',True)
rod('ForwardMast',(0,61,6.7),(0,61,26),.18,'Superstructure',8)
rod('AftMast',(0,-58,21.9),(0,-58,32),.2,'Superstructure',8)
rod('MastYard',(-3,-58,28.5),(3,-58,28.5),.09,'Steel')
box('Radar',(0,-58,29),(4.5,.45,.3),'Superstructure')
for xx in [-2,2]: rod('Antenna',(xx,-60,22),(xx,-60,26),.045,'Steel',4)
rod('ForeStay',(0,64,7.2),(0,61,24),.035,'Steel',4)
rod('SternPole',(0,-76,5),(0,-76,16),.1,'Superstructure')

# Low-cost railings and cargo access walkways; no separate corrugation geometry.
for s in [-1,1]:
    for z in [5.55,6.1]: rod('SideRail',(s*11.65,-71,z),(s*11.65,45,z),.045,'Superstructure',4)
    for yy in [-71,-57,-43,-29,-15,-1,13,27,41]:
        rod('Stanchion',(s*11.65,yy,5.05),(s*11.65,yy,6.1),.045,'Superstructure',4)
    for yy in [-73,56,64]:
        xx=s*(8 if yy<60 else 5.5)
        rod('Bollard',(xx,yy,5.3 if yy<0 else 6.6),(xx,yy,6 if yy<0 else 7.3),.25,'DarkSteel')
        rod('BollardCross',(xx-.6,yy,5.9 if yy<0 else 7.2),(xx+.6,yy,5.9 if yy<0 else 7.2),.15,'DarkSteel')
    # Enclosed survival craft with a tapered, orange shell.
    xx=s*9.9
    boatvs=[(xx+dx,-65+dy,zz) for dx,dy,zz in [(-1,-3.8,8),(1,-3.8,8),(1.2,2.7,8),(0,4,8),(-1.2,2.7,8),(-.7,-2.8,9.5),(.7,-2.8,9.5),(.75,2,9.5),(-.75,2,9.5)]]
    mesh('Lifeboat',boatvs,[(0,4,3,2,1),(0,1,6,5),(1,2,7,6),(2,3,7),(3,4,8,7),(4,0,5,8),(5,6,7,8)],'SafetyOrange')
    for yy in [-67,-63]:
        rod('Davit',(s*8.3,yy,9),(s*10.7,yy,10.5),.11,'Steel')
    box('AnchorPocket',(s*9.2,61,3),(.15,1.8,1.6),'DarkSteel')
    rod('AnchorShank',(s*9.35,61,3.6),(s*9.35,61,2),.14,'Steel')
    rod('AnchorFlukes',(s*9.35,60.3,2.4),(s*9.35,61.7,2.4),.14,'Steel')
for xx in [-2,2]:
    box('WindlassBase',(xx,66,7.3),(1.8,2,.35),'Steel')
    rod('Windlass',(xx-.7,66,7.9),(xx+.7,66,7.9),.5,'DarkSteel',8)
    rod('AnchorChain',(xx,66,7.35),(xx*2,69,7.5),.07,'DarkSteel',4)

# Lamp mounting plates are exported; actual directional lenses are native Godot geometry.
lights=[{'name':'Port','position':[-11.9,19.8,54.2],'color':[1,.025,.012],'center':-56.25,'arc':112.5,'mode':'underway'},
 {'name':'Starboard','position':[11.9,19.8,54.2],'color':[.015,1,.075],'center':56.25,'arc':112.5,'mode':'underway'},
 {'name':'ForwardMasthead','position':[0,26,-61],'color':[1,1,.94],'center':0,'arc':225,'mode':'underway'},
 {'name':'AftMasthead','position':[0,32,58],'color':[1,1,.94],'center':0,'arc':225,'mode':'underway'},
 {'name':'Stern','position':[0,8,78.1],'color':[1,1,.94],'center':180,'arc':135,'mode':'underway'},
 {'name':'ForwardAnchor','position':[0,25.5,-61],'color':[1,1,.94],'center':0,'arc':360,'mode':'anchored'},
 {'name':'AftAnchor','position':[0,16,76],'color':[1,1,.94],'center':0,'arc':360,'mode':'anchored'}]
for light in lights:
    xx,zz,neg_y=light['position']
    box('LanternMount',(xx,-neg_y,zz-.22),(.5,.5,.12),'DarkSteel')
for side in [-1,1]:
    for yy in [-48,0,48]:
        rod('DeckLightPole',(side*10.8,yy,5),(side*10.8,yy,19),.09,'Steel',6)
        box('DeckFloodlight',(side*10.8,yy,19.1),(.7,.9,.25),'Superstructure')

# Join by modular material slot. UVs and all placed instances remain actual geometry.
for mat in materials:
    group=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0].name==mat]
    if not group: continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in group: ob.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    bpy.ops.object.join()
    joined=bpy.context.object; joined.name=mat
    bm=bmesh.new();bm.from_mesh(joined.data)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bmesh.ops.triangulate(bm,faces=bm.faces)
    bm.to_mesh(joined.data);bm.free()

ship_objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
triangles=sum(len(o.data.polygons) for o in ship_objects)
print('SHIP_MESH_TRIANGLES',triangles,'CONTAINERS',count)
# 7 native low-poly lenses and one anchor day ball add 160 triangles.
assert triangles+160 < 5000, f'Complete ship exceeds budget: {triangles+160}'
bpy.ops.object.select_all(action='DESELECT')
for ob in ship_objects: ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(BASE/'cargo_ship.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
data=(BASE/'cargo_ship.glb').read_bytes()
json_size,chunk_type=struct.unpack_from('<II',data,12)
gltf=json.loads(data[20:20+json_size])
exported=sum(gltf['accessors'][p['indices']]['count']//3 for node in gltf['nodes'] if 'mesh' in node for p in gltf['meshes'][node['mesh']]['primitives'])
print('EXPORTED_TRIANGLES',exported,'BLENDER_TRIANGLES',triangles)
assert exported == triangles
assert exported+160 < 5000
manifest={'length_m':156,'beam_m':24,'waterline_y':0,'bow_axis':'-Z','containers':count,'blender_triangles':triangles,'exported_glb_triangles':exported,'native_extra_budget':160,'lights':lights,'collision_boxes':collision_boxes,'material_slots':list(materials),'by_slot':{o.name:len(o.data.polygons) for o in ship_objects}}
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2))

# Keep a clean editable Blender master plus a non-exported presentation rig.
scene=bpy.context.scene
world=bpy.data.worlds.new('MarineStudio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.32,.39,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
bpy.ops.object.light_add(type='AREA',location=(30,45,100));bpy.context.object.name='Preview_Key';bpy.context.object.data.energy=160000;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=80
bpy.ops.object.light_add(type='SUN',location=(-40,0,50));bpy.context.object.rotation_euler=(.35,-.45,-.5);bpy.context.object.data.energy=2
bpy.ops.object.camera_add(location=(130,175,130))
camera=bpy.context.object;camera.name='Preview_Camera';camera.rotation_euler=(Vector((0,0,9))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=194;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1500;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'blender_day.png')
scene.view_settings.view_transform='AgX'
scene.name='Ocean Blue'
# Four editable Blender scenes: mesh data and texture images are shared, materials are
# assigned at object level. This keeps color changes separate from ship geometry.
variant_colors={
 'Oxide Red':['923c32','62645b','e5e0d3','416674','bc9b65','d4d4c5','865146'],
 'Deep Teal':['205750','666d67','d7ddd6','608f87','b66639','ced8ce','37575b'],
 'Graphite':['343d48','786c54','ddd9cb','416985','b9a36c','cfd2ca','915945']}
slots=['Hull','Deck','Superstructure','ContainerA','ContainerB','ContainerC','ContainerD']
for label,colors in variant_colors.items():
    other=bpy.data.scenes.new(label)
    other.world=world
    other.unit_settings.system='METRIC'
    for original in list(scene.objects):
        copy=original.copy()
        other.collection.objects.link(copy)
        if original.type=='CAMERA':other.camera=copy
        if original.type=='MESH' and original.name in slots:
            code=colors[slots.index(original.name)]
            tint=tuple(int(code[i:i+2],16)/255 for i in (0,2,4))
            m=original.data.materials[0].copy();m.name=label+' / '+original.name
            m.diffuse_color=(*srgb(tint),1)
            bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=m.diffuse_color
            for node in m.node_tree.nodes:
                if node.type=='MIX_RGB':node.inputs[2].default_value=m.diffuse_color
            copy.material_slots[0].link='OBJECT';copy.material_slots[0].material=m
    other.render.engine='CYCLES';other.cycles.samples=24
    other.render.resolution_x=1500;other.render.resolution_y=1050
    other.view_settings.view_transform='AgX'
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=190
        area.spaces.active.region_3d.view_location=(0,0,9)
bpy.ops.object.select_all(action='DESELECT')
for ob in ship_objects:ob.select_set(True)
bpy.context.view_layer.objects.active=ship_objects[0]
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'cargo_ship.blend'))
bpy.ops.render.render(write_still=True)
print('CARGO_SHIP_BUILD_COMPLETE',exported)
