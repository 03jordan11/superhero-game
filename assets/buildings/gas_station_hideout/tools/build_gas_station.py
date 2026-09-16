"""Blender authoring for the abandoned hideout exterior. Metres; front -Y.
Run Blender --background --python assets/buildings/gas_station_hideout/tools/build_gas_station.py.
The original atlas is painted procedurally; no reference-photo pixels are used.
"""
import bpy, math, json, struct
import numpy as np
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[2]
QA = ROOT/'artifacts/gas_station_hideout'
for folder in [BASE/'textures', QA]: folder.mkdir(parents=True, exist_ok=True)
(QA/'.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
rng = np.random.default_rng(4709)
S = 512
y,x = np.mgrid[0:S,0:S].astype(float)
u,v = x/(S-1),y/(S-1)

def noise(seed):
    r = np.random.default_rng(seed)
    n = np.zeros((S,S))
    for freq,amp in [(2, .42),(5,.24),(13,.16),(31,.10),(81,.05)]:
        for j in range(3):
            angle = r.uniform(0,math.tau)
            n += np.sin((u*np.cos(angle)+v*np.sin(angle))*math.tau*freq+r.uniform(0,math.tau))*amp/3
    return n

N = noise(43)
fine = rng.normal(0,.014,(S,S))
tiles = {}
rough = {}

def base(name, color, roughness=.88, strength=.1):
    a = np.clip(np.array(color)[None,None,:]+(N*strength+fine)[:,:,None],0,1)
    tiles[name] = a
    rough[name] = np.clip(roughness + N*.08,0,1)
    return a

def rect(a,x0,y0,x1,y1,c):
    a[(u>=x0)&(u<=x1)&(v>=y0)&(v<=y1)] = c

def line(a, points, color, width=.003):
    for p,q in zip(points, points[1:]):
        dx,dy = q[0]-p[0],q[1]-p[1]
        t = np.clip(((u-p[0])*dx+(v-p[1])*dy)/max(dx*dx+dy*dy,1e-8),0,1)
        mask = (u-p[0]-t*dx)**2+(v-p[1]-t*dy)**2 < width*width
        a[mask] = color

def weather(a, rust=False, amount=1):
    edge = np.minimum.reduce([u,1-u,v,1-v])
    chips = (N + .12*np.sin(u*120+v*46) > .27+edge*.6)
    a[chips] = np.array([.28,.12,.055] if rust else [.29,.28,.235]) + fine[chips,None]
    stain = np.exp(-v*10) * (.13+N*.15)
    streak = (np.sin(u*151+np.sin(u*25)*3)*.5+.5)**12 * (v*.08)
    a[:] = np.clip(a-(stain+streak)[:,:,None]*amount,0,1)

a=base('Plaster',(.70,.69,.59),strength=.16)
weather(a)
rows=(y//24).astype(int)
mortar=(y%24<2)|((x+(rows%2)*36)%72<2)
exposed=(v<.18+N*.18)&(N>-.14)
a[exposed]=np.array([.36,.29,.20])+fine[exposed,None]
a[exposed&mortar]=[.48,.45,.37]
for pts in [[(.2,1),(.22,.83),(.19,.73),(.23,.61)],[(.75,1),(.73,.89),(.78,.75),(.76,.69)]]:
    line(a,pts,[.33,.32,.26],.0018)
for name,col in [('Red',(.39,.075,.052)),('Teal',(.115,.24,.235)),('CreamMetal',(.62,.60,.47))]:
    a=base(name,col,.86,.11); weather(a,True)
a=base('Rust',(.27,.115,.049),.94,.21)
for i in range(40):
    x0,y0=rng.uniform(0,1,2); line(a,[(x0,y0),(x0+rng.uniform(-.03,.03),y0-.17)],[.13,.075,.038],.002)
a=base('Roof',(.16,.18,.17),.97,.1)
rect(a,.08,.15,.52,.57,[.09,.105,.102])
for i in [.08,.53,.85]: line(a,[(i,0),(i+.015,1)],[.055,.06,.055],.006)
a=base('Concrete',(.42,.43,.385),.98,.17)
for pts in [[(0,.24),(.2,.28),(.28,.36),(.44,.39),(.48,.56),(.64,.61),(.73,1)],[(.43,.4),(.62,.34),(.69,.20),(1,.11)],[(.2,.27),(.13,.53),(.01,.68)]]:
    line(a,pts,[.17,.18,.15],.0028)
oil=np.exp(-((u-.58)**2/.045+(v-.57)**2/.027))*.22
a[:]-=oil[:,:,None]
a=base('Glass',(.075,.12,.125),.42,.055)
a+=np.clip(1-np.abs(u+v-1.02)*5,0,1)[:,:,None]*np.array([.05,.075,.075])
a-=np.exp(-v*8)[:,:,None]*.045
for k in [.24,.65,.81]: line(a,[(k,1),(k+.012,.58)],[.21,.235,.21],.004)
a=base('Wood',(.32,.245,.13),.96,.13)
grain=np.sin(u*240+np.sin(v*9)*3)*.018+np.sin(u*650+v*3)*.008
a+=grain[:,:,None]
for k in [.20,.43,.65,.82]: line(a,[(k,0),(k+.006,1)],[.13,.105,.056],.002)
a=base('Rubber',(.033,.040,.036),.96,.025)
for k in np.arange(.03,1,.075): line(a,[(k,0),(k+.03,.5),(k,1)],[.075,.080,.064],.007)
a=base('Door',(.24,.13,.080),.9,.1)
rect(a,.045,.035,.955,.965,[.34,.085,.05])
for row in range(4):
    for col in range(4):
        x0=.073+col*.222; y0=.30+row*.162
        rect(a,x0,y0,x0+.185,y0+.126,[.065,.095,.098])
        rect(a,x0+.006,y0+.092,x0+.177,y0+.119,[.15,.19,.177])
        rect(a,x0+.02,y0+.008,x0+.10,y0+.038,[.040,.056,.051])
for yy in [.08,.16,.24]: line(a,[(.08,yy),(.92,yy)],[.15,.085,.045],.002)
weather(a,True,.65)
line(a,[(.30,.73),(.35,.78),(.32,.84)],[.35,.38,.31],.0018)
a=base('Pump',(.61,.59,.46),.81,.08)
rect(a,.095,.63,.905,.89,[.065,.076,.066])
rect(a,.13,.67,.87,.86,[.30,.33,.275])
for i in range(5):
    xx=.19+i*.128
    rect(a,xx,.69,xx+.083,.84,[.042,.047,.036])
    for yy in [.714,.762,.808]: rect(a,xx+.013,yy,xx+.066,yy+.011,[.63,.63,.48])
rect(a,.19,.44,.80,.59,[.38,.10,.055])
rect(a,.36,.1,.66,.25,[.065,.082,.067])
weather(a,True,.9)
# Torn lower face exposes dark oxidized sheet metal.
missing=(v<.31)&(v<.23+np.sin(u*17)*.10)&(u>.19)&(u<.82)
a[missing]=[.042,.049,.04]
a=base('Sign',(.58,.57,.43),.94,.14)
rect(a,.02,.06,.98,.10,[.16,.25,.22]); rect(a,.02,.9,.98,.94,[.16,.25,.22])
FONT={'F':['11111','10000','10000','11110','10000','10000','10000'],
 'U':['10001','10001','10001','10001','10001','10001','01110'],
 'E':['11111','10000','10000','11110','10000','10000','11111'],
 'L':['10000','10000','10000','10000','10000','10000','11111'],
 'S':['01111','10000','10000','01110','00001','00001','11110'],
 'R':['11110','10001','10001','11110','10100','10010','10001'],
 'V':['10001','10001','10001','10001','10001','01010','00100'],
 'I':['111','010','010','010','010','010','111'],
 'C':['01111','10000','10000','10000','10000','10000','01111']}
def text(a,word,left,bottom,width,height,color):
    total=sum(len(FONT[c][0])+1 for c in word)-1; cursor=left
    for c in word:
        glyph=FONT[c]; w=len(glyph[0])
        for yy,row in enumerate(reversed(glyph)):
            for xx,p in enumerate(row):
                if p=='1': rect(a,cursor+xx*width/total,bottom+yy*height/7,cursor+(xx+.84)*width/total,bottom+(yy+.85)*height/7,color)
        cursor+=(w+1)*width/total
text(a,'FUEL',.12,.34,.76,.40,[.34,.095,.055]); weather(a,True,.4)
chips=N>.21; a[chips]=np.array([.51,.5,.39])+fine[chips,None]
a=base('ServiceSign',(.15,.24,.224),.91,.08)
text(a,'SERVICE',.06,.28,.88,.43,[.57,.55,.41]); weather(a,True,.7)
a=base('Metal',(.14,.165,.15),.8,.09)
for k in np.arange(.10,.92,.08):
    rect(a,.06,k,.94,k+.025,[.045,.056,.047]); rect(a,.06,k+.027,.94,k+.037,[.22,.24,.20])
a=base('Weeds',(.22,.24,.095),.98,.10)

names=list(tiles)
assert len(names)==16
atlas=np.ones((2048,2048,4),np.float32)
rough_atlas=np.ones_like(atlas)
for i,name in enumerate(names):
    row,col=divmod(i,4)
    atlas[row*S:(row+1)*S,col*S:(col+1)*S,:3]=np.clip(tiles[name],0,1)
    rough_atlas[row*S:(row+1)*S,col*S:(col+1)*S,:3]=rough[name][:,:,None]
def write_image(name,pixels,noncolor=False):
    image=bpy.data.images.new(name,width=2048,height=2048,alpha=True)
    if noncolor: image.colorspace_settings.name='Non-Color'
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw=str(BASE/'textures'/(name+'.png')); image.file_format='PNG'; image.save()
    return image
albedo=write_image('station_albedo',atlas)
roughness=write_image('station_roughness',rough_atlas,True)
material=bpy.data.materials.new('Weathered station atlas'); material.use_nodes=True
bs=material.node_tree.nodes.get('Principled BSDF')
for im,socket in [(albedo,'Base Color'),(roughness,'Roughness')]:
    node=material.node_tree.nodes.new('ShaderNodeTexImage'); node.image=im
    material.node_tree.links.new(node.outputs['Color'],bs.inputs[socket])

parts={}; collisions=[]
def uv(tile,coords):
    i=names.index(tile); row,col=divmod(i,4); pad=4/512
    return [((col+pad+float(a)*(1-2*pad))/4,(row+pad+float(b)*(1-2*pad))/4) for a,b in coords]
def finish(obj,name,tile,group):
    obj.name=name; obj.data.materials.clear(); obj.data.materials.append(material)
    layer=obj.data.uv_layers.active or obj.data.uv_layers.new()
    # Object-local projection keeps bottom grime at the bottom of vertical faces.
    for p in obj.data.polygons:
        normal=p.normal; axis=max(range(3),key=lambda k:abs(normal[k]))
        axes=[k for k in range(3) if k!=axis]
        vs=[obj.data.vertices[obj.data.loops[l].vertex_index].co for l in p.loop_indices]
        low=[min(pt[k] for pt in vs) for k in axes]; high=[max(pt[k] for pt in vs) for k in axes]
        coords=[tuple((pt[k]-lo)/max(hi-lo,.0001) for k,lo,hi in zip(axes,low,high)) for pt in vs]
        for index,point in zip(p.loop_indices,uv(tile,coords)): layer.data[index].uv=point
    parts.setdefault(group,[]).append(obj)
    return obj
def box(name,center,size,tile,group='Architecture',collision=False,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center); ob=bpy.context.object
    ob.dimensions=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Worn edges','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    finish(ob,name,tile,group)
    if collision: collisions.append({'name':name,'center':[center[0],center[2],-center[1]],'size':[size[0],size[2],size[1]]})
    return ob
def face(name,center,size,tile,group='Facade'):
    # Upright face looking toward the forecourt (-Y).
    xx,yy,zz=center; w,h=size
    mesh=bpy.data.meshes.new(name); mesh.from_pydata([(xx-w/2,yy,zz-h/2),(xx+w/2,yy,zz-h/2),(xx+w/2,yy,zz+h/2),(xx-w/2,yy,zz+h/2)],[],[(0,1,2,3)])
    ob=bpy.data.objects.new(name,mesh); scene.collection.objects.link(ob)
    finish(ob,name,tile,group); return ob
def rod(name,a,b,radius,tile,group='Details',sides=8):
    a,b=Vector(a),Vector(b); delta=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=delta.length,location=(a+b)/2)
    ob=bpy.context.object; ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    finish(ob,name,tile,group); return ob
def hose(name,points,radius=.034):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'; curve.resolution_u=1
    curve.bevel_depth=radius; curve.bevel_resolution=0; curve.resolution_u=1
    spline=curve.splines.new('POLY'); spline.points.add(len(points)-1)
    for p,co in zip(spline.points,points): p.co=(*co,1)
    ob=bpy.data.objects.new(name,curve); scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob; ob.select_set(True)
    bpy.ops.object.convert(target='MESH'); finish(bpy.context.object,name,'Rubber','Pumps')

# Complete included forecourt: no roads/neighbour buildings baked into the asset.
box('Cracked forecourt',(0,-1,.06),(27.5,25,.12),'Concrete','Grounds',True)
box('Office slab',(-6.65,3.2,.20),(6.9,11.4,.28),'Concrete','Architecture',True)
box('Garage shell',(3.25,4,.2+2.05),(13.3,10,4.1),'Plaster',collision=True)
box('Office shell',(-6.65,3.2,2.20),(6.5,10.8,4),'Plaster',collision=True)
box('Garage foundation',(3.25,-1.018,.58),(13.3,.045,.75),'Red')
box('Office foundation',(-6.65,-2.218,.58),(6.5,.045,.75),'Red')
box('Office side paint',(-9.92,3.2,.60),(.055,10.8,.76),'Red')
box('Garage side paint',(9.92,4,.60),(.055,10,.76),'Red')
box('Garage back paint',(3.25,9.02,.6),(13.3,.045,.76),'Red')
box('Office back paint',(-6.65,8.62,.6),(6.5,.045,.76),'Red')
# Roof lips cast the broad simple shadows of the reference.
box('Garage roof',(3.25,4,4.34),(13.9,10.6,.20),'Roof','Roof',True)
box('Office roof',(-6.65,3.05,4.23),(7.1,11.6,.20),'Roof','Roof',True)
box('Garage fascia',(3.25,-1.31,4.37),(13.95,.20,.30),'Teal','Roof')
box('Office fascia',(-6.65,-2.78,4.25),(7.14,.20,.31),'Teal','Roof')
box('Office side fascia',(-10.19,3.05,4.25),(.19,11.6,.25),'Teal','Roof')
box('Garage side fascia',(10.19,4,4.38),(.19,10.6,.25),'Teal','Roof')
box('Garage back fascia',(3.25,9.28,4.38),(13.95,.20,.29),'Teal','Roof')
box('Office back fascia',(-6.65,8.83,4.25),(7.14,.20,.29),'Teal','Roof')
# Garage bay doors: window sashes, chipped trim and metal panels live in the atlas.
for xx in [.55,6.55]:
    face('Glazed garage door',(xx,-1.031,1.96),(4.65,3.24),'Door')
    for dx in [-2.40,2.40]: box('Bay jamb',(xx+dx,-1.10,1.91),(.16,.22,3.40),'Red','Facade')
    box('Bay lintel',(xx,-1.10,3.65),(4.96,.23,.15),'Red','Facade')
    box('Bay threshold',(xx,-1.18,.30),(4.85,.40,.10),'Concrete','Facade')
# Office shopfront: dark window panes, entry door, painted sill detail in textures.
face('Storefront glass',(-7.94,-2.231,2.02),(2.95,2.61),'Glass')
face('Entry glass',(-5.14,-2.234,2.0),(1.83,2.66),'Glass')
for xx in [-9.48,-6.4,-6.06,-4.21]: box('Storefront mullion',(xx,-2.28,1.99),(.095,.13,2.93),'Red','Facade')
box('Shopfront header',(-6.83,-2.27,3.48),(5.42,.13,.14),'Red','Facade')
box('Door kickplate',(-5.14,-2.255,.63),(1.72,.035,.58),'CreamMetal','Facade')
rod('Door handle',(-4.51,-2.36,1.20),(-4.51,-2.36,1.68),.026,'Metal','Facade',6)
box('Faded service panel',(-6.6,-2.30,3.84),(6.12,.07,.40),'Teal','Facade')
face('Service lettering',(-6.6,-2.342,3.84),(5.74,.31),'ServiceSign')
# Two loose boards across a single office pane, not a fully sealed facade.
for z,angle in [(1.41,-.11),(2.40,.09)]:
    plank=box('Boarded office window',(-7.98,-2.34,z),(2.92,.085,.22),'Wood','Facade')
    plank.rotation_euler.y=angle
# Side window panels, flush textured detail instead of modeled window sills.
for yy in [1.4,5.3]:
    panel=face('Side window',(0,0,0),(2.0,1.45),'Glass')
    panel.rotation_euler.z=-math.pi/2; panel.location=(-9.917,yy,2.45)
    for z in [2.04,2.71]:
        ob=box('Side window board',(-9.985,yy,z),(.08,2.15,.20),'Wood','Facade'); ob.rotation_euler.x=.055
# Rear utility entrance, kept separate for a future interior transition.
door=face('Rear reinforced door',(0,0,0),(1.6,2.7),'Metal')
door.rotation_euler.z=math.pi; door.location=(-6.6,8.631,1.60)
box('Rear doorstep',(-6.6,8.99,.25),(2.0,.8,.26),'Concrete','Details',True)
for xx,yy in [(-9.55,8.68),(9.55,9.08)]:
    rod('Rain pipe',(xx,yy,.5),(xx,yy,4.08),.073,'Rust')
    rod('Drain outlet',(xx,yy,.5),(xx,yy+.32,.34),.073,'Rust')
# Patches and a small low-poly turbine/exhaust silhouette; no fake AC boxes.
box('Roof patch',(-5.2,5.2,4.344),(2.9,2.1,.016),'Metal','Roof')
for xx,yy in [(4.9,7.0),(7.2,7.0)]:
    rod('Vent base',(xx,yy,4.43),(xx,yy,4.83),.19,'Metal','Roof',10)
    rod('Vent cap',(xx,yy,4.78),(xx,yy,4.94),.29,'CreamMetal','Roof',10)
box('Roof access panel',(1.5,7.2,4.46),(1.25,1.5,.08),'Rust','Roof')
# Rounded pump island and two salvaged mechanical pumps.
box('Pump island',(0,-7.7,.24),(12.5,2.25,.37),'Concrete','Pumps',True,bevel=.16)
for i,xx in enumerate([-3.95,3.95]):
    box('Pump plinth',(xx,-7.70,.51),(1.05,.94,.20),'Rust','Pumps',True,bevel=.06)
    box('Pump pedestal',(xx,-7.70,1.01),(.79,.72,.95),'CreamMetal','Pumps',True,bevel=.07)
    box('Pump head',(xx,-7.70,1.86),(1.00,.79,.93),'CreamMetal','Pumps',True,bevel=.10)
    face('Mechanical pump face',(xx,-8.104,1.61),(.83,1.26),'Pump','Pumps')
    for z in [1.46,2.33]: box('Pump trim',(xx,-7.70,z),(1.05,.85,.065),'Red','Pumps')
    points=[(xx+.53,-7.72,1.94),(xx+.80,-7.74,1.70),(xx+.96,-7.84,1.27),(xx+1.08,-7.93,.65),(xx+1.02,-8.12,.42),(xx+.79,-8.23,.35),(xx+.61,-8.14,.49),(xx+.65,-7.99,.91),(xx+.58,-7.92,1.44)]
    hose('Hanging fuel hose',points)
    rod('Nozzle grip',(xx+.58,-7.93,1.4),(xx+.58,-7.89,1.67),.075,'Rubber','Pumps',6)
    rod('Nozzle spout',(xx+.58,-7.89,1.67),(xx+.48,-7.84,1.83),.032,'Metal','Pumps',6)
    box('Pump number plate',(xx,-8.113,2.25),(.38,.023,.15),'Red','Pumps')
# The reference's narrow, weather-beaten island light, slightly leaning.
rod('Island lamp pole',(0,-7.7,.41),(.12,-7.65,6.5),.12,'CreamMetal','Pumps',10)
collisions.append({'name':'LampPole','center':[.06,3.4,7.67],'size':[.29,6.0,.29]})
rod('Lamp yoke',(-2.65,-7.65,6.46),(2.7,-7.65,6.56),.085,'Rust','Pumps',8)
for xx,ang in [(-1.80,.055),(1.82,-.035)]:
    ob=box('Island lamp housing',(xx,-7.65,6.56),(3.1,.60,.22),'CreamMetal','Pumps',bevel=.05); ob.rotation_euler.y=ang
    ob=box('Dead lamp diffuser',(xx,-7.65,6.44),(2.87,.45,.015),'Metal','Pumps'); ob.rotation_euler.y=ang
# Faded roadside sign, useful landmark at superhero traversal distances.
for xx in [-11.65,-10.02]: rod('Sign leg',(xx,-8.90,.14),(xx,-8.90,4.3),.055,'Rust','Yard',8)
box('Old fuel sign',(-10.835,-8.90,4.46),(2.6,.20,1.5),'Rust','Yard')
face('Fuel sign face',(-10.835,-9.007,4.46),(2.45,1.36),'Sign','Yard')
panel=face('Fuel sign reverse',(0,0,0),(2.45,1.36),'Sign','Yard'); panel.rotation_euler.z=math.pi; panel.location=(-10.835,-8.79,4.46)
# A few tires, a rusty drum and a low crate, all included in the geometry budget.
for i in range(3):
    bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=5,location=(10.8,6.8,.30+i*.32),major_radius=.42,minor_radius=.14)
    finish(bpy.context.object,'Discarded tire','Rubber','Yard')
rod('Rust drum',(10.9,4.5,.15),(10.9,4.5,1.04),.34,'Rust','Yard',12)
for z in [.31,.81]: rod('Drum hoop',(10.9,4.5,z),(10.9,4.5,z+.045),.354,'Metal','Yard',12)
box('Service crate',(10.85,2.7,.39),(.86,.88,.51),'Wood','Yard',True)
for xx,yy in [(-10.5,8.8),(-10.7,5.7),(10.5,-.8),(11.7,5),(-6.6,-8.4),(5.9,-7.5),(6.0,-8.4),(-11,-9.5),(-12.8,-12),(12.8,-11),(-9.6,-2.6),(9.7,9.6)]:
    for j in range(5):
        a=rng.uniform(0,math.tau); r=rng.uniform(.04,.25); h=rng.uniform(.15,.43)
        p=Vector((xx+math.cos(a)*r,yy+math.sin(a)*r,.13))
        mesh=bpy.data.meshes.new('Grass'); mesh.from_pydata([p+Vector((-.035,0,0)),p+Vector((.035,0,0)),p+Vector((math.cos(a)*.16,math.sin(a)*.16,h))],[],[(0,1,2)])
        ob=bpy.data.objects.new('Dry weed',mesh); scene.collection.objects.link(ob); finish(ob,'Dry weed','Weeds','Yard')

objects=[]
for group,items in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in items: ob.select_set(True)
    bpy.context.view_layer.objects.active=items[0]
    bpy.ops.object.join(); ob=bpy.context.object; ob.name=group
    # Merge material slots so every group exports a single surface.
    ob.data.materials.clear(); ob.data.materials.append(material)
    for p in ob.data.polygons: p.material_index=0
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    ob.data.calc_loop_triangles(); objects.append(ob)
count=sum(len(ob.data.loop_triangles) for ob in objects)
assert count < 5000, count
bpy.ops.object.select_all(action='DESELECT')
for ob in objects: ob.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.export_scene.gltf(filepath=str(BASE/'gas_station_hideout.glb'),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
blob=(BASE/'gas_station_hideout.glb').read_bytes(); size,kind=struct.unpack_from('<II',blob,12); data=json.loads(blob[20:20+size])
exported=sum(data['accessors'][p['indices']]['count']//3 for m in data['meshes'] for p in m['primitives'])
assert exported == count and exported < 5000, (exported,count)
manifest={'triangles':count,'exported_triangles':exported,'limit_exclusive':5000,'units':'meters','godot_front_axis':'+Z','footprint':[27.5,25.0],'height':6.7,'by_part':{o.name:len(o.data.loop_triangles) for o in objects},'collision_boxes':collisions,'atlas_tiles':{name:i for i,name in enumerate(names)},'entry_marker':[-5.14,.22,2.6],'rear_entry_marker':[-6.6,.12,-9.6]}
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Source includes review camera/lights; they are not selected for mesh export.
world=bpy.data.worlds.new('Soft studio'); scene.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.25,.30,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.55
def lamp(name,at,power,size):
    bpy.ops.object.light_add(type='AREA',location=at); ob=bpy.context.object; ob.name=name
    ob.data.energy=power; ob.data.shape='DISK'; ob.data.size=size
    ob.rotation_euler=(Vector((0,0,0))-ob.location).to_track_quat('-Z','Y').to_euler()
lamp('Warm key',(-10,-15,25),3800,14); lamp('Fill',(15,-4,12),2200,12)
bpy.ops.object.camera_add(location=(29,-34,24)); camera=bpy.context.object
camera.rotation_euler=(Vector((0,-.8,1.7))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'; camera.data.ortho_scale=39; scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=1500; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'gas_station_hideout.blend'))
scene.render.filepath=str(QA/'blender_front.png'); bpy.ops.render.render(write_still=True)
print('GAS_STATION_COMPLETE',json.dumps(manifest['by_part']), 'EXPORTED_TRIANGLES',exported,flush=True)
