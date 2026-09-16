"""Author the standalone power machine in Blender; metres, front -Y.
Run: blender --background --python assets/props/power_machine/tools/build_power_machine.py
Original painted PBR atlas, editable mesh parts, selected-only GLB export.
"""
import bpy, json, math, struct
import numpy as np
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[2]
QA = ROOT / 'artifacts/power_machine'
for p in [BASE/'textures', QA]: p.mkdir(parents=True, exist_ok=True)
(QA/'.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
asset = bpy.data.collections.new('POWER MACHINE | export meshes')
scene.collection.children.link(asset)
S = 512
y,x = np.mgrid[0:S,0:S]
u,v = x/(S-1),y/(S-1)
rng = np.random.default_rng(7619)
noise = rng.normal(0,.012,(S,S))
mottle = np.sin(u*29+np.sin(v*14))*np.sin(v*33+u*5)*.012
atlas = np.ones((2048,2048,4),dtype=np.float32)
rough = np.ones_like(atlas)
emission = np.zeros_like(atlas); emission[:,:,3]=1
names = ['Ivory','Graphite','Steel','Front','Left','Vent','Screen','Pad',
         'Core','Warning','Chamber','Rear','DarkTrim','Identification','Slot','IvorySide']
tiles = {}; glow = {}
def rect(a,x0,y0,x1,y1,c):
    a[(u>=x0)&(u<=x1)&(v>=y0)&(v<=y1)] = c
def line(a,p,q,c,w=.002):
    dx,dy=q[0]-p[0],q[1]-p[1]
    t=np.clip(((u-p[0])*dx+(v-p[1])*dy)/max(dx*dx+dy*dy,1e-8),0,1)
    a[(u-p[0]-t*dx)**2+(v-p[1]-t*dy)**2<w*w]=c
FONT = {
'A':['01110','10001','10001','11111','10001','10001','10001'],
'B':['11110','10001','10001','11110','10001','10001','11110'],
'C':['01111','10000','10000','10000','10000','10000','01111'],
'D':['11110','10001','10001','10001','10001','10001','11110'],
'E':['11111','10000','10000','11110','10000','10000','11111'],
'F':['11111','10000','10000','11110','10000','10000','10000'],
'G':['01111','10000','10000','10111','10001','10001','01111'],
'H':['10001','10001','10001','11111','10001','10001','10001'],
'I':['111','010','010','010','010','010','111'],
'L':['10000','10000','10000','10000','10000','10000','11111'],
'M':['10001','11011','10101','10101','10001','10001','10001'],
'N':['10001','11001','11001','10101','10011','10011','10001'],
'O':['01110','10001','10001','10001','10001','10001','01110'],
'P':['11110','10001','10001','11110','10000','10000','10000'],
'R':['11110','10001','10001','11110','10100','10010','10001'],
'S':['01111','10000','10000','01110','00001','00001','11110'],
'T':['11111','00100','00100','00100','00100','00100','00100'],
'U':['10001','10001','10001','10001','10001','10001','01110'],
'V':['10001','10001','10001','10001','10001','01010','00100'],
'X':['10001','10001','01010','00100','01010','10001','10001'],
'Y':['10001','10001','01010','00100','00100','00100','00100'],
'0':['01110','10001','10011','10101','11001','10001','01110'],
'1':['010','110','010','010','010','010','111'],
'2':['01110','10001','00001','00010','00100','01000','11111'],
'3':['11110','00001','00001','01110','00001','00001','11110'],
'4':['10010','10010','10010','11111','00010','00010','00010'],
'7':['11111','00001','00010','00100','01000','01000','01000'],
'8':['01110','10001','10001','01110','10001','10001','01110'],
'9':['01110','10001','10001','01111','00001','00001','01110'],
'-':['00000','00000','00000','11111','00000','00000','00000'],
'.':['0','0','0','0','0','1','1'],
' ':['000']*7,
}
def text(a,word,px,py,scale,color):
    for ch in word:
        glyph=FONT.get(ch,FONT[' '])
        for j,row in enumerate(glyph):
            for i,bit in enumerate(row):
                if bit=='1':
                    xx=px+i*scale; yy=py+(6-j)*scale
                    a[yy:yy+scale,xx:xx+scale]=color
        px+=(len(glyph[0])+1)*scale
def painted(name,col,r=.65,wear=.025):
    i=names.index(name); row,c=divmod(i,4)
    a=atlas[row*S:(row+1)*S,c*S:(c+1)*S,:3]
    a[:]=np.clip(np.array(col)+(noise+mottle)[:,:,None],0,1)
    edge=np.minimum.reduce([u,1-u,v,1-v])
    dirt=np.exp(-edge*38)*(wear*2+np.maximum(0,np.sin(u*150)*np.sin(v*121))*wear)
    a[:]-=dirt[:,:,None]
    # Small exposed paint chips and fine scuffs, not large camouflage patches.
    chips=(edge<.022)&(rng.random((S,S))>.84)
    a[chips]=(.24,.25,.24)
    for k in range(20):
        p=rng.uniform(.03,.97,2)
        line(a,p,p+[rng.uniform(.006,.033),rng.uniform(-.004,.004)],np.clip(np.array(col)-.14,0,1),.0008)
    rr=np.clip(r+noise*3+mottle,0,1)
    rough[row*S:(row+1)*S,c*S:(c+1)*S,:3]=rr[:,:,None]
    tiles[name]=a; glow[name]=emission[row*S:(row+1)*S,c*S:(c+1)*S,:3]
    return a
def bolts(a):
    for xx in [.043,.957]:
        for yy in [.055,.945]:
            d=(u-xx)**2+(v-yy)**2
            a[d<.00012]=(.12,.14,.14); a[d<.000065]=(.40,.42,.40)
            line(a,(xx-.004,yy-.004),(xx+.004,yy+.004),(.08,.09,.09),.0015)
ivory=(.66,.65,.60); dark=(.085,.101,.105); cyan=(.12,.85,.91)
for name,col,r in [('Ivory',ivory,.68),('Graphite',dark,.52),('Steel',(.30,.34,.35),.34),
                   ('Front',ivory,.72),('Left',ivory,.74),('Vent',dark,.71),
                   ('Screen',(.012,.037,.047),.34),('Pad',(.035,.16,.18),.30),
                   ('Core',(.12,.65,.70),.25),('Warning',(.58,.42,.12),.75),
                   ('Chamber',(.064,.083,.086),.63),('Rear',ivory,.78),
                   ('DarkTrim',(.032,.041,.045),.56),('Identification',dark,.67),
                   ('Slot',(.035,.045,.048),.73),('IvorySide',ivory,.72)]:
    painted(name,col,r)
for name in ['Front','Left','Rear','IvorySide','Chamber']: bolts(tiles[name])
a=tiles['Front']
rect(a,.06,.73,.94,.735,(.30,.32,.30))
text(a,'PROMETHEUS',36,402,5,(.15,.20,.20))
text(a,'CELL INDUCTION SYSTEM',38,370,2,(.25,.28,.27))
text(a,'P-01',38,40,3,(.25,.28,.27))
rect(a,.76,.09,.93,.21,dark)
text(a,'CAUTION',397,86,1,(.64,.65,.54))
for k in range(22): rect(a,.78+k*.006,.105,.782+k*.006,.155,(.47,.49,.45))
for xx in [.08,.92]: rect(a,xx,.26,xx+.016,.38,(.15,.18,.18))
a=tiles['Left']; text(a,'AUXILIARY',40,375,3,dark); text(a,'SERVICE',40,335,2,dark)
rect(a,.10,.15,.90,.155,(.33,.35,.33)); text(a,'01',46,58,5,(.28,.31,.28))
a=tiles['Vent']
for yy in np.arange(.10,.95,.105):
    rect(a,.07,yy,.93,yy+.061,(.017,.025,.027))
    rect(a,.07,yy+.062,.93,yy+.076,(.28,.31,.31))
bolts(a)
a=tiles['Screen']; e=glow['Screen']
for dest,c in [(a,(.24,.72,.76)),(e,(.09,.42,.47))]:
    text(dest,'P-01  READY',26,448,4,c)
    line(dest,(.05,.84),(.95,.84),c)
    for k in range(4):
        rect(dest,.06,.69-k*.095,.39-k*.025,.728-k*.095,c)
    circle=np.abs(np.sqrt((u-.70)**2+(v-.51)**2)-.185)<.004
    dest[circle]=c
    line(dest,(.70,.27),(.70,.75),c,.001)
    line(dest,(.46,.51),(.94,.51),c,.001)
    text(dest,'98.7',304,246,3,c)
    text(dest,'CORE STABLE',30,53,3,c)
    for k in range(38): rect(dest,.06+k*.023,.20,.075+k*.023,.215+(k%7)*.002,c)
a=tiles['Pad']; e=glow['Pad']
for dest,c in [(a,cyan),(e,(.1,.65,.72))]:
    for xx in [.08,.92]: line(dest,(xx,.08),(xx,.92),c,.009)
    for yy in [.08,.92]: line(dest,(.08,yy),(.92,yy),c,.009)
    rect(dest,.16,.18,.84,.82,np.array(c)*.45)
    for yy in np.arange(.2,.81,.018): rect(dest,.18,yy,.82,yy+.004,np.array(c)*.70)
    text(dest,'CONTACT',116,46,4,c)
glow['Core'][:]=(.10,.68,.77)
for xx in [.04,.10,.90,.96]: rect(tiles['Core'],xx,0,xx+.012,1,(.60,.96,.98))
for yy in [.18,.5,.82]:
    rect(tiles['Core'],0,yy,1,yy+.009,(.5,.95,1))
    rect(glow['Core'],0,yy,1,yy+.009,(.35,.9,1))
a=tiles['Warning']; a[((u+v)*12%1)<.46]=dark
a=tiles['Chamber']
for xx in [.1,.3,.7,.9]:
    line(a,(xx,.05),(xx,.92),(.16,.19,.19),.006)
    line(a,(xx+.008,.05),(xx+.008,.92),(.02,.035,.04),.003)
a=tiles['Rear']; text(a,'P-01 SERVICE',45,421,4,dark); bolts(a)
for yy in np.arange(.2,.67,.048): rect(a,.09,yy,.91,yy+.023,dark)
text(tiles['Identification'],'CORE - 01',42,226,7,(.57,.66,.65))
a=tiles['Slot']
for xx in [.16,.84]: line(a,(xx,.05),(xx,.95),(.26,.31,.31),.012)
for name,arr in [('albedo',atlas),('roughness',rough),('emission',emission)]:
    # 32-pixel duplicated gutters prevent emissive atlas neighbours bleeding into
    # non-emissive metal at game-sized mip levels, including narrow bevel faces.
    sample=np.linspace(0,S-1,S-64).astype(int)
    for row in range(4):
        for col in range(4):
            source=arr[row*S:(row+1)*S,col*S:(col+1)*S].copy()
            inner=source[sample[:,None],sample[None,:]]
            arr[row*S:(row+1)*S,col*S:(col+1)*S]=np.pad(inner,((32,32),(32,32),(0,0)),mode='edge')
    img=bpy.data.images.new('Power machine '+name,2048,2048,alpha=True)
    if name!='albedo': img.colorspace_settings.name='Non-Color'
    img.pixels.foreach_set(np.clip(arr,0,1).ravel())
    img.filepath_raw=str(BASE/'textures'/('power_machine_'+name+'.png'))
    img.file_format='PNG'; img.save(); img.pack()
material=bpy.data.materials.new('Machine | painted metal + cyan instrumentation'); material.use_nodes=True
bs=material.node_tree.nodes.get('Principled BSDF'); bs.inputs['Metallic'].default_value=.32
bs.inputs['Emission Strength'].default_value=2.5
for key,socket in [('albedo','Base Color'),('roughness','Roughness'),('emission','Emission Color')]:
    n=material.node_tree.nodes.new('ShaderNodeTexImage'); n.image=bpy.data.images['Power machine '+key]
    material.node_tree.links.new(n.outputs['Color'],bs.inputs[socket])
glass=bpy.data.materials.new('Canopy | lightly tinted transparent glass'); glass.use_nodes=True
g=glass.node_tree.nodes.get('Principled BSDF')
g.inputs['Base Color'].default_value=(.16,.27,.29,1); g.inputs['Roughness'].default_value=.16
g.inputs['Alpha'].default_value=.13; g.inputs['Metallic'].default_value=.1
glass.surface_render_method='DITHERED'; glass.use_backface_culling=True
objects=[]
def finish(ob,name,tile='Ivory',bevel=0):
    ob.name=name
    for c in list(ob.users_collection): c.objects.unlink(ob)
    asset.objects.link(ob)
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Machined edge chamfers','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(material)
    uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name='UVMap')
    i=names.index(tile); row,col=divmod(i,4)
    for p in ob.data.polygons:
        coords=[ob.data.vertices[ob.data.loops[k].vertex_index].co for k in p.loop_indices]
        n=p.normal; dominant=max(range(3),key=lambda j:abs(n[j]))
        axes={0:(1,2),1:(0,2),2:(0,1)}[dominant]
        lo=[min(c[j] for c in coords) for j in axes]; hi=[max(c[j] for c in coords) for j in axes]
        for k,c in zip(p.loop_indices,coords):
            s=[(c[j]-lo[q])/max(hi[q]-lo[q],1e-6) for q,j in enumerate(axes)]
            uv.data[k].uv=((col+.068+s[0]*.864)/4,(row+.068+s[1]*.864)/4)
    objects.append(ob); return ob
def box(name,pos,size,tile='Ivory',bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); ob=bpy.context.object; ob.dimensions=size
    return finish(ob,name,tile,bevel)
def rod(name,a,b,r,tile='Steel',vertices=12):
    d=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(Vector(a)+Vector(b))/2)
    ob=bpy.context.object; ob.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    ob=finish(ob,name,tile)
    for p in ob.data.polygons: p.use_smooth=len(p.vertices)==4
    return ob
def face(name,verts,tile,glass_face=False):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],[(0,1,2,3)]); me.update()
    ob=bpy.data.objects.new(name,me); asset.objects.link(ob); objects.append(ob)
    me.materials.append(glass if glass_face else material)
    uv=me.uv_layers.new(name='UVMap'); row,col=divmod(names.index(tile),4)
    for k,st in enumerate([(0,0),(1,0),(1,1),(0,1)]): uv.data[k].uv=((col+.068+st[0]*.864)/4,(row+.068+st[1]*.864)/4)
    return ob
def front(name,x,y,z,w,h,tile):
    return face(name,[(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2)],tile)
def beam(name,a,b,w,d,tile='Graphite',bevel=0):
    delta=Vector(b)-Vector(a)
    ob=box(name,(Vector(a)+Vector(b))/2,(w,d,delta.length),tile,bevel)
    ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler(); return ob

# Floor-centred origin; full-size freestanding console, not a tabletop miniature.
box('Lower steel chassis',(0,0,.27),(3.50,1.17,.28),'Graphite',.065)
for xx in [-1.46,1.46]:
    for yy in [-.41,.41]: box('Rubber isolation foot',(xx,yy,.085),(.34,.32,.17),'DarkTrim',.025)
box('Cabinet carcass',(0,.01,.72),(3.42,1.12,.77),'Graphite',.03)
box('Central ivory access panel',(-.20,-.585,.76),(2.03,.055,.73),'Ivory',.012)
front('Printed centre access panel',-.20,-.614,.76,1.99,.69,'Front')
box('Left service cabinet',(-1.47,0,.84),(.55,1.20,1.15),'Ivory',.045)
front('Left lower service markings',-1.47,-.607,.60,.47,.51,'Left')
box('Auxiliary slot surround',(-1.47,-.619,1.047),(.48,.06,.32),'Graphite',.018)
box('Auxiliary recessed opening',(-1.47,-.657,1.065),(.40,.013,.23),'DarkTrim')
box('Auxiliary tray',(-1.47,-.71,.929),(.43,.22,.042),'Steel',.009)
front('Auxiliary cyan status strip',-1.47,-.67,1.191,.32,.015,'Core')
rod('Tray pull',(-1.61,-.834,.952),(-1.33,-.834,.952),.014,vertices=8)
# Wedge at left matches the rising canopy silhouette.
left_profile=[(-.60,1.36),(-.60,1.40),(.13,1.79),(.57,1.79),(.57,1.36)]
def extrusion(name,x0,x1,profile,tile):
    n=len(profile); verts=[(xx,yy,zz) for xx in [x0,x1] for yy,zz in profile]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); scene.collection.objects.link(ob); finish(ob,name,tile)
    return ob
extrusion('Left angled shoulder',-1.75,-1.19,left_profile,'Ivory')
# Chamber interior and a real cylindrical reactor visible through the hood.
box('Chamber bed',(-.17,.02,1.14),(2.04,1.08,.12),'Chamber',.012)
box('Chamber back',(-.17,.523,1.44),(2.07,.058,.61),'Chamber',.018)
for yy in [-.28,.30]: rod('Longitudinal guide rail',(-1.09,yy,1.25),(.79,yy,1.25),.026,'Steel',10)
rod('Reactor shaft',(-1.10,.035,1.38),(.85,.035,1.38),.062,'Steel',12)
rod('Luminous induction cell',(-.64,.035,1.38),(.34,.035,1.38),.124,'Core',24)
for xx in [-.80,.50]:
    box('Reactor saddle',(xx,.035,1.225),(.25,.42,.10),'Graphite',.012)
    rod('Reactor end housing',(xx-.095,.035,1.38),(xx+.095,.035,1.38),.190,'Graphite',16)
    for dx in [-.090,.067]: rod('Polished end ring',(xx+dx,.035,1.38),(xx+dx+.026,.035,1.38),.196,'Steel',16)
    rod('Live collar',(xx+(-.118 if xx>0 else .097),.035,1.38),(xx+(-.096 if xx>0 else .119),.035,1.38),.150,'Core',16)
for xx in [-.98,.69]: rod('Insulator coupling',(xx-.041,.035,1.38),(xx+.041,.035,1.38),.109,'Steel',12)
front('Rear chamber luminous rail',-.15,.487,1.655,1.47,.014,'Core')
front('Reactor equipment plate',-.15,-.363,1.205,.38,.042,'Identification')
# Transparent canopy: one sloped front pane, a shallow top pane, metal perimeter.
for xx in [-1.13,.89]:
    beam('Hood sloped side frame',(xx,-.565,1.22),(xx,.17,1.765),.080,.080,'Graphite',.008)
    beam('Hood top side frame',(xx,.17,1.765),(xx,.56,1.765),.080,.07,'Graphite')
box('Hood lower crossbar',(-.12,-.565,1.225),(2.10,.095,.09),'Graphite',.009)
box('Hood crown crossbar',(-.12,.17,1.765),(2.10,.074,.055),'Graphite',.009)
box('Hood rear crossbar',(-.12,.548,1.765),(2.10,.062,.056),'Graphite')
face('Sloped glass canopy',[(-1.09,-.558,1.25),(.85,-.558,1.25),(.85,.16,1.74),(-1.09,.16,1.74)],'Graphite',True)
face('Canopy top glass',[(-1.09,.18,1.747),(.85,.18,1.747),(.85,.52,1.747),(-1.09,.52,1.747)],'Graphite',True)
for xx in [-1.089,.849]:
    ob=face('Glass cheek',[(xx,-.53,1.23),(xx,.51,1.23),(xx,.51,1.73),(xx,.17,1.73)],'Graphite',True)
    if xx<0:
        for poly in ob.data.polygons: poly.flip()
for xx in [-.75,.50]: box('Hood hinge',(xx,.55,1.775),(.22,.10,.065),'Steel',.014)
for xx in [-.48,.23]: rod('Canopy handle mount',(xx,-.605,1.18),(xx,-.705,1.18),.021,'Steel',8)
rod('Canopy pull handle',(-.48,-.705,1.18),(.23,-.705,1.18),.025,'Steel',10)
# Right contact station: rectangular illuminated pad, no hand model.
box('Right contact pedestal',(1.36,0,.69),(.77,1.20,.92),'Ivory',.055)
front('Right service panel',1.36,-.607,.71,.62,.68,'IvorySide')
extrusion('Contact sloped support',1.00,1.73,[(-.58,1.10),(.50,1.10),(.50,1.57),(.33,1.57),(-.58,1.15)],'Ivory')
pad_angle=math.atan2(.34,.83)
pad=box('Contact pad graphite recess',(1.37,-.045,1.395),(.52,.94,.052),'Graphite',.018); pad.rotation_euler.x=pad_angle
def padpoint(x,y,z=.030):
    return (1.37+x,-.045+y*math.cos(pad_angle)-z*math.sin(pad_angle),1.395+y*math.sin(pad_angle)+z*math.cos(pad_angle))
face('Rectangular illuminated contact pad',[padpoint(-.211,-.404),padpoint(.211,-.404),padpoint(.211,.404),padpoint(-.211,.404)],'Pad')
for xx in [1.055,1.68]:
    beam('Contact protective side rail',(xx,-.49,1.25),(xx,.32,1.59),.064,.086,'Graphite',.008)
# Raised display mounted between canopy and contact surface.
box('Control display pedestal',(.99,.33,1.62),(.34,.33,.43),'Ivory',.035)
monitor=box('Angled control display housing',(.99,.27,1.96),(.49,.14,.39),'Ivory',.024)
monitor.rotation_euler.x=math.radians(-18)
bezel=box('Control display bezel',(.99,.193,1.985),(.43,.023,.326),'DarkTrim',.01); bezel.rotation_euler.x=math.radians(-18)
display=front('Control display interface',0,-.02,0,.375,.275,'Screen')
display.rotation_euler.x=math.radians(-18); display.location=(.99,.177,1.990)
# All ventilation slats, screws and lettering are texture detail.
face('Right ventilation inset',[(1.752,-.44,.35),(1.752,.45,.35),(1.752,.45,1.01),(1.752,-.44,1.01)],'Vent')
face('Left side service face',[(-1.756,.43,.35),(-1.756,-.44,.35),(-1.756,-.44,1.26),(-1.756,.43,1.26)],'IvorySide')
face('Rear maintenance panel',[(1.60,.613,.36),(-1.60,.613,.36),(-1.60,.613,1.08),(1.60,.613,1.08)],'Rear')
front('Lower caution band',-.20,-.594,.369,1.95,.023,'Warning')
rod('Rear power socket',(1.42,.58,.42),(1.42,.70,.42),.065,'Graphite',10)
rod('Power socket cap',(1.42,.70,.42),(1.42,.735,.42),.048,'Steel',10)

# Retain named editable parts in Blender, but merge export into two material surfaces.
for ob in objects: ob.data.calc_loop_triangles()
by_part={ob.name:len(ob.data.loop_triangles) for ob in objects}
mesh_count=sum(by_part.values())
assert mesh_count<=4500,mesh_count
bpy.ops.object.select_all(action='DESELECT')
duplicates=[]
for original in objects:
    ob=original.copy(); ob.data=original.data.copy(); scene.collection.objects.link(ob)
    ob.select_set(True); duplicates.append(ob)
bpy.context.view_layer.objects.active=duplicates[0]
bpy.ops.object.join(); exported_obj=bpy.context.object; exported_obj.name='PowerMachine'
scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.export_scene.gltf(filepath=str(BASE/'power_machine.glb'),export_format='GLB',use_selection=True,
    export_animations=False,export_yup=True,export_cameras=False,export_lights=False)
bpy.data.objects.remove(exported_obj,do_unlink=True)
blob=(BASE/'power_machine.glb').read_bytes(); length,kind=struct.unpack_from('<II',blob,12)
doc=json.loads(blob[20:20+length])
exported=sum(doc['accessors'][p['indices']]['count']//3 for n in doc['nodes'] if 'mesh' in n for p in doc['meshes'][n['mesh']]['primitives'])
assert exported==mesh_count,(exported,mesh_count)
bpy.context.view_layer.update()
corners=[ob.matrix_world @ Vector(c) for ob in objects for c in ob.bound_box]
dimensions=[round(max(c[j] for c in corners)-min(c[j] for c in corners),4) for j in [0,2,1]]
manifest={'units':'metres','godot_front_axis':'+Z','origin':'floor centre','exported_triangles':exported,
          'surfaces':sum(len(m['primitives']) for m in doc['meshes']),'dimensions_xyz_m':dimensions,
          'by_part':by_part,'atlas_tiles':{n:i for i,n in enumerate(names)},
          'station_existing_combined_triangles':4486,'station_with_one_machine_triangles':4486+exported,
          'placement':'Standalone asset only; not placed in any scene.','collision':'None; visual mesh only.'}
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Preview rig belongs only to the .blend, and never to the GLB export.
rig=bpy.data.collections.new('STUDIO | preview only - not exported'); scene.collection.children.link(rig)
def rig_move(ob):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    rig.objects.link(ob)
bpy.ops.mesh.primitive_plane_add(size=200)
ground=bpy.context.object; ground.name='Studio ground'; rig_move(ground); ground.location.z=-.006
gm=bpy.data.materials.new('Studio graphite'); gm.diffuse_color=(.073,.084,.10,1); ground.data.materials.append(gm)
world=bpy.data.worlds.new('Studio world'); world.use_nodes=True; scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.22,.26,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.40
def light(name,loc,energy,size,color):
    bpy.ops.object.light_add(type='AREA',location=loc); ob=bpy.context.object; ob.name=name; rig_move(ob)
    ob.data.energy=energy; ob.data.shape='DISK'; ob.data.size=size; ob.data.color=color
    ob.rotation_euler=(Vector((0,0,.8))-ob.location).to_track_quat('-Z','Y').to_euler()
light('Large warm key',(-3,-4,6),750,5,(1,.90,.77))
light('Cool right fill',(4,-1,4),550,4,(.70,.86,1))
light('Rear rim',(-1,4,5),900,3,(.79,.9,1))
bpy.ops.object.camera_add(location=(4.2,-6.4,3.65)); camera=bpy.context.object; rig_move(camera)
camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'; camera.data.ortho_scale=4.9; scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1440; scene.render.resolution_y=1024; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='AgX'
# Cycles emission lights the chamber naturally; game bloom is environment-controlled.
bpy.ops.object.select_all(action='DESELECT')
for ob in objects: ob.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=5
            area.spaces.active.region_3d.view_location=(0,0,1)
            area.spaces.active.shading.type='MATERIAL'
scene.render.filepath=str(QA/'power_machine_front.png')
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'power_machine.blend'))
bpy.ops.render.render(write_still=True)
camera.location=(-4.3,5.9,3.4)
camera.rotation_euler=(Vector((0,0,.93))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(QA/'power_machine_rear.png'); bpy.ops.render.render(write_still=True)
print('POWER_MACHINE_COMPLETE',json.dumps(manifest),flush=True)
