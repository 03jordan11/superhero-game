"""Blender-authored hideout, fitted to the exterior's actual shell dimensions."""
import bpy, math, json, struct
import numpy as np
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
source = json.loads((BASE/'manifest.json').read_text())
names = list(source['atlas_tiles'])
# Shared paint/plaster wear matches the exterior; new tiles furnish the hideout.
img = bpy.data.images.load(str(BASE/'textures/station_albedo.png'))
atlas = np.array(img.pixels[:],dtype=np.float32).reshape(2048,2048,4)
y,x = np.mgrid[0:512,0:512]
u,v = x/511,y/511
rng = np.random.default_rng(701)
grain = rng.normal(0,.018,(512,512))
def tile(name,color):
    i=names.index(name); row,col=divmod(i,4)
    a=atlas[row*512:(row+1)*512,col*512:(col+1)*512,:3]
    a[:]=np.clip(np.array(color)+grain[:,:,None],0,1)
    return a
def rect(a,x0,y0,x1,y1,c):
    a[(u>=x0)&(u<x1)&(v>=y0)&(v<y1)]=c
def line(a,p,q,c,w=.004):
    dx,dy=q[0]-p[0],q[1]-p[1]
    t=np.clip(((u-p[0])*dx+(v-p[1])*dy)/max(dx*dx+dy*dy,.00001),0,1)
    a[(u-p[0]-t*dx)**2+(v-p[1]-t*dy)**2<w*w]=c
a=tile('Door',(.47,.48,.38)) # Old wall tiles with broken corners and grout.
grout=(x%64<3)|(y%64<3); a[grout]=(.22,.24,.21)
for i in range(28):
    p=rng.random(2); line(a,p,p+rng.uniform(-.1,.1,2),(.22,.23,.19),.002)
a=tile('Pump',(.21,.23,.20)) # Pegboard: tools are texture detail.
a[((x%24-12)**2+(y%24-12)**2)<5]=(.055,.06,.05)
for i in range(6):
    xx=.11+i*.15
    rect(a,xx,.24,xx+.025,.69,(.44,.42,.33))
    rect(a,xx-.025,.62,xx+.055,.71,(.15,.16,.14))
    rect(a,xx-.011,.22,xx+.04,.42,(.36,.105,.065))
a=tile('Sign',(.26,.23,.16)) # Cork board with street maps, pins, notes.
for px,py,pw,ph in [(.06,.12,.56,.76),(.67,.58,.25,.29),(.69,.18,.22,.28)]:
    rect(a,px,py,px+pw,py+ph,(.62,.59,.45))
for k in range(7):
    line(a,(.1+k*.067,.17),(.13+k*.067,.82),(.32,.37,.32),.003)
    line(a,(.1,.18+k*.096),(.57,.2+k*.096),(.32,.37,.32),.003)
line(a,(.12,.3),(.52,.65),(.20,.32,.35),.012)
for p in [(.19,.29),(.36,.54),(.51,.7),(.75,.83),(.8,.41)]:
    a[(u-p[0])**2+(v-p[1])**2<.00016]=(.50,.065,.035)
a=tile('ServiceSign',(.02,.045,.05)) # Salvaged display, restrained blue-green.
rect(a,.03,.83,.97,.91,(.13,.32,.30))
for k in range(8): rect(a,.07,.13+k*.07,.36+(k%3)*.07,.145+k*.07,(.18,.37,.31))
for k in range(5): rect(a,.61+k*.061,.15,.642+k*.061,.3+(k%3)*.13,(.12,.31,.28))
a=tile('Weeds',(.22,.26,.22)) # Frayed military blanket/upholstery.
a+=((x%4==0)|(y%4==0))[:,:,None]*.015
rect(a,.02,.06,.98,.075,(.32,.34,.27)); rect(a,.02,.92,.98,.935,(.32,.34,.27))
for p,q in [((.1,.4),(.25,.43)),((.66,.6),(.77,.65))]: line(a,p,q,(.1,.13,.11),.003)
img=bpy.data.images.new('Hideout painted atlas',2048,2048,alpha=True)
img.pixels.foreach_set(np.clip(atlas,0,1).ravel()); img.filepath_raw=str(BASE/'textures/interior_albedo.png'); img.file_format='PNG'; img.save()
material=bpy.data.materials.new('Hideout worn surfaces'); material.use_nodes=True
bs=material.node_tree.nodes.get('Principled BSDF')
for socket,path in [('Base Color',BASE/'textures/interior_albedo.png'),('Roughness',BASE/'textures/station_roughness.png')]:
    tex=material.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(path),check_existing=True)
    if socket=='Roughness': tex.image.colorspace_settings.name='Non-Color'
    material.node_tree.links.new(tex.outputs['Color'],bs.inputs[socket])
# Reuse only the mesh/UV helper definitions, not the exterior's build/export.
helpers=(BASE/'tools/build_gas_station.py').read_text()
exec(helpers[helpers.index('parts={}; collisions=[]'):helpers.index('# Complete included forecourt')])

# Keep whole furnishings editable instead of combining all furniture by category.
props = {}
active_prop = None
original_finish = finish
def finish(obj, name, tile, group):
    return original_finish(obj, name, tile, active_prop or group)
class PropCollisions(list):
    def append(self, item):
        if active_prop: item['prop'] = active_prop
        super().append(item)
collisions = PropCollisions()
def prop(name, pivot, parent=None):
    global active_prop
    active_prop = name
    props[name] = {'pivot':[pivot[0],pivot[2],-pivot[1]], 'parent':parent}

# Office and garage have the same asymmetric footprint as the exterior.
box('Office floor',(-6.65,3.2,.26),(6.3,10.6,.20),'Door','Floor',True)
box('Garage floor',(3.2,4,.26),(13.2,9.8,.20),'Concrete','Floor',True)
box('Office garage threshold',(-3.45,3.25,.26),(.50,2.5,.20),'Concrete','Floor',True)
for name,c,s in [
    ('Office west',(-9.72,3.2,2.22),(.18,10.6,3.72)),
    ('Office front',(-6.65,-2.01,2.22),(6.3,.18,3.72)),
    ('Office rear',(-6.65,8.41,2.22),(6.3,.18,3.72)),
    ('Garage east',(9.71,4,2.25),(.18,9.8,3.78)),
    ('Garage rear',(3.2,8.81,2.25),(13.2,.18,3.78)),
    ('Garage front',(3.2,-.81,2.25),(13.2,.18,3.78)),
    ('Partition front',(-3.45,-.1,2.22),(.20,4.2,3.72)),
    ('Partition rear',(-3.45,6.5,2.22),(.20,4,3.72)),
    ('Opening lintel',(-3.45,3.25,3.64),(.20,2.5,.88))]:
    box(name,c,s,'Plaster','Walls',True)
    if 'lintel' not in name:
        cc=list(c); ss=list(s); cc[2]=.88; ss[2]=1.04; ss[0]+=.015; ss[1]+=.015
        box(name+' faded dado',cc,ss,'Teal','Walls')
box('Office ceiling',(-6.65,3.2,4.07),(6.3,10.6,.16),'Plaster','Ceiling',True)
box('Garage ceiling',(3.2,4,4.12),(13.2,9.8,.16),'Roof','Ceiling',True)
for yy in [1,4,7]:
    box('Exposed roof beam',(3.2,yy,3.91),(13,.13,.26),'Rust','Ceiling')
    rod('Surface conduit',(-9.55,yy,3.88),(9.5,yy,3.88),.026,'Metal','Ceiling',6)
# Door/window backs align with their corresponding exterior openings.
for xx in [.55,6.55]:
    panel=face('Closed garage bay',(0,0,0),(4.65,3.2),'Metal','Doors')
    panel.rotation_euler.z=math.pi; panel.location=(xx,-.711,1.98)
    for z in [.8,1.35,1.9,2.45,3]: box('Bay seams',(xx,-.69,z),(4.65,.032,.04),'Rust','Doors')
    for dx in [-1.58,-.53,.53,1.58]:
        box('Dirty bay pane',(xx+dx,-.68,2.9),(.91,.025,.54),'Glass','Doors')
box('Inside entry door',(-5.14,-1.899,1.77),(1.82,.035,2.78),'Red','Doors')
box('Entry frosted pane',(-5.14,-1.868,2.13),(1.59,.025,1.80),'Glass','Doors')
rod('Inside door pull',(-4.51,-1.81,1.2),(-4.51,-1.81,1.68),.026,'Metal','Doors',6)
box('Office storefront inside',(-7.94,-1.905,2.02),(2.95,.024,2.61),'Glass','Doors')
for z in [1.41,2.40]: box('Window boarding',(-7.94,-1.86,z),(2.92,.07,.22),'Wood','Doors')

def table(name,x,y,w,d,h=.95):
    box(name+' top',(x,y,h),(w,d,.14),'Wood','Furniture')
    for dx in [-w/2+.12,w/2-.12]:
        for dy in [-d/2+.12,d/2-.12]: box(name+' leg',(x+dx,y+dy,(h+.36)/2),(.08,.08,h-.36),'Rust','Furniture')
    collisions.append({'name':name,'center':[x,(h+.36)/2,-y],'size':[w,h-.36+.14,d]})
# Command desk near the front of the office, space behind and toward the doorway.
prop('Desk',(-8.5,.55,.36))
table('Salvaged desk',-8.5,.55,1.3,2.3,1.05)
for index,yy in enumerate([.1,1.03]):
    prop('DeskMonitor%d' % (index+1),(-8.83,yy,1.12),'Desk')
    box('Monitor back',(-8.96,yy,1.52),(.10,.78,.55),'Rubber','Equipment')
    box('Monitor screen',(-8.9,yy,1.52),(.012,.69,.44),'ServiceSign','Equipment')
    box('Monitor foot',(-8.83,yy,1.16),(.37,.45,.06),'Metal','Equipment')
prop('Keyboard',(-8.31,.55,1.12),'Desk')
box('Keyboard',(-8.31,.55,1.14),(.29,.69,.035),'Pump','Equipment')
prop('ComputerTower',(-8.72,1.99,.36))
box('Computer tower',(-8.72,1.99,.75),(.54,.57,.78),'Metal','Equipment',True)
prop('Chair',(-7.3,.55,.36))
box('Chair seat',(-7.3,.55,.86),(.64,.67,.12),'Weeds','Furniture')
box('Chair back',(-6.99,.55,1.20),(.10,.67,.61),'Weeds','Furniture')
for yy in [.3,.8]:
    for xx in [-7.55,-7.05]: box('Chair leg',(xx,yy,.59),(.055,.055,.46),'Metal','Furniture')
prop('InvestigationBoard',(-9.59,3.25,2.35))
box('Investigation corkboard',(-9.59,3.25,2.35),(.07,2.55,1.49),'Wood','Equipment')
box('Pinned street map',(-9.543,3.25,2.35),(.012,2.40,1.34),'Sign','Equipment')
# Rear sleeping nook: cot, folded blanket, footlocker and battered lockers.
prop('Cot',(-8.3,6.68,.36))
box('Cot frame',(-8.3,6.68,.71),(2.65,1.12,.13),'Metal','Furniture')
collisions.append({'name':'Cot','center':[-8.3,.67,-6.68],'size':[2.65,.62,1.12]})
box('Cot mattress',(-8.3,6.68,.87),(2.57,1.05,.22),'Weeds','Furniture')
prop('Blanket',(-7.65,6.68,.97),'Cot')
box('Folded blanket',(-7.65,6.68,1.005),(.72,1.01,.07),'Teal','Furniture')
prop('Pillow',(-9.21,6.68,.96),'Cot')
box('Pillow',(-9.21,6.68,1.02),(.53,.82,.12),'CreamMetal','Furniture',bevel=.055)
active_prop='Cot'
for xx in [-9.4,-7.2]:
    for yy in [6.25,7.11]: box('Cot feet',(xx,yy,.55),(.06,.06,.39),'Metal','Furniture')
prop('Footlocker',(-8.2,7.95,.36))
box('Footlocker',(-8.2,7.95,.61),(1.9,.65,.5),'Teal','Storage',True)
for index,xx in enumerate([-5.55,-4.65]):
    prop('Locker%d' % (index+1),(xx,7.94,.36))
    box('Steel locker',(xx,7.94,1.4),(.83,.68,2.08),'Teal','Storage',True)
    box('Locker inset',(xx,7.59,1.43),(.72,.022,1.88),'Metal','Storage')
    for z in [1.92,2.02,2.12]: box('Locker vent',(xx,7.57,z),(.46,.012,.025),'Rubber','Storage')
    box('Locker latch',(xx+.22,7.54,1.37),(.04,.05,.15),'CreamMetal','Storage')
# Workbench and toolboard on the back wall; keep the centre largely empty.
prop('Workbench',(2.4,8.02,.36))
table('Long workbench',2.4,8.02,5.2,1.1,1.1)
prop('Toolboard',(2.4,8.68,2.20))
box('Toolboard frame',(2.4,8.68,2.20),(5.35,.09,1.42),'Wood','Equipment')
board=face('Tools on pegboard',(2.4,8.622,2.20),(5.15,1.25),'Pump','Equipment')
active_prop='Workbench'
for xx in [.8,2.25,3.7]: box('Workbench lower shelf',(xx,8.02,.55),(1.3,.93,.12),'Wood','Furniture')
prop('BenchVise',(4.25,7.70,1.17),'Workbench')
box('Bench vise',(4.25,7.70,1.27),(.43,.36,.20),'Teal','Equipment')
box('Vise jaw',(4.25,7.57,1.4),(.45,.08,.12),'Metal','Equipment')
prop('Toolbox',(.3,8.12,1.17),'Workbench')
box('Toolbox',(.3,8.12,1.31),(.92,.46,.28),'Red','Equipment')
rod('Toolbox handle',(.04,8.12,1.49),(.55,8.12,1.49),.027,'Metal','Equipment',6)
for index,xx in enumerate([1.3,1.7,2.1]):
    prop('OilTin%d' % (index+1),(xx,8.26,1.18),'Workbench')
    rod('Oil tin',(xx,8.26,1.18),(xx,8.26,1.48),.095,'CreamMetal','Equipment',8)
for rack_index,(x0,y0) in enumerate([(8.93,6.6),(8.93,3.5)]):
    rack_name='StorageRack%d' % (rack_index+1)
    prop(rack_name,(x0,y0,.36))
    for xx in [x0-.46,x0+.46]:
        for yy in [y0-1.12,y0+1.12]: box('Rack upright',(xx,yy,1.64),(.07,.07,2.56),'Rust','Storage')
    for z in [.46,1.22,2.01,2.86]: box('Rack shelf',(x0,y0,z),(1.05,2.45,.075),'Wood','Storage')
    collisions.append({'name':'Storage rack','center':[x0,1.64,-y0],'size':[1.05,2.56,2.45]})
    for index,(yy,z) in enumerate([(y0-.6,.75),(y0+.57,.75),(y0-.55,1.50),(y0+.60,2.27)]):
        prop('Rack%dCrate%d' % (rack_index+1,index+1),(x0,yy,z-.235),rack_name)
        box('Stored crate',(x0,yy,z),(.78,.83,.47),'Wood','Storage')
prop('TrainingMat',(3,3.7,.36))
box('Training mat',(3,3.7,.382),(4.2,3.1,.035),'Rubber','Furniture')
for xx in [1.03,4.97]: box('Mat edge',(xx,3.7,.404),(.07,2.9,.009),'Teal','Furniture')
for i in range(2):
    prop('Tire%d' % (i+1),(7.5,.13,.40+i*.32),'Tire1' if i else None)
    bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=6,location=(7.5,.13,.55+i*.32),major_radius=.42,minor_radius=.15)
    finish(bpy.context.object,'Old tire','Rubber','Storage')
prop('Drum',(-2.48,7.96,.36))
rod('Rusty drum',(-2.48,7.96,.36),(-2.48,7.96,1.27),.36,'Rust','Storage',12)
collisions.append({'name':'Drum','center':[-2.48,.815,-7.96],'size':[.72,.91,.72]})
for z in [.50,1.1]: rod('Drum hoop',(-2.48,7.96,z),(-2.48,7.96,z+.045),.374,'Metal','Storage',12)
# Fixtures share one restrained emissive material, with real Godot room lights.
glow=bpy.data.materials.new('Warm fluorescent diffusers'); glow.use_nodes=True
g=glow.node_tree.nodes.get('Principled BSDF'); g.inputs['Base Color'].default_value=(.8,.77,.58,1)
g.inputs['Emission Color'].default_value=(1,.88,.65,1); g.inputs['Emission Strength'].default_value=1.4
lights=[(-6.6,1,3.82),(-6.6,6.3,3.82),(1,3,3.83),(5.5,6.2,3.83)]
for index,(x0,y0,z0) in enumerate(lights):
    prop('CeilingFixture%d' % index,(x0,y0,z0))
    props[active_prop]['light_node']='CeilingLight%d' % index
    box('Salvaged light housing',(x0,y0,z0),(1.65,.39,.12),'CreamMetal','Fixtures')
    ob=box('Light diffuser',(x0,y0,z0-.072),(1.48,.27,.022),'CreamMetal','Glow')
    ob.data.materials.clear(); ob.data.materials.append(glow)

objects=[]
for group,items in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in items: ob.select_set(True)
    bpy.context.view_layer.objects.active=items[0]; bpy.ops.object.join(); ob=bpy.context.object; ob.name=group
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    # Local geometry with a useful pivot, retaining per-face material assignments.
    if group in props:
        p=props[group]['pivot']; scene.cursor.location=(p[0],-p[2],p[1])
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    ob.data.calc_loop_triangles(); objects.append(ob)
count=sum(len(o.data.loop_triangles) for o in objects)
assert count<5000 and count+2200<10000, count
bpy.ops.object.select_all(action='DESELECT')
for ob in objects: ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(BASE/'gas_station_interior.glb'),export_format='GLB',use_selection=True,export_animations=False)
blob=(BASE/'gas_station_interior.glb').read_bytes(); size,kind=struct.unpack_from('<II',blob,12); data=json.loads(blob[20:20+size])
exported=sum(data['accessors'][p['indices']]['count']//3 for m in data['meshes'] for p in m['primitives'])
assert exported==count
manifest={'triangles':count,'by_part':{o.name:len(o.data.loop_triangles) for o in objects},'props':props,'collision_boxes':collisions,'lights':[[x,z,-y] for x,y,z in lights],'spawn':[-5.14,1.40,.5],'exit':[-5.14,1.55,1.83]}
(BASE/'interior_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'gas_station_interior.blend'))
print('INTERIOR_EXPORTED',count)
