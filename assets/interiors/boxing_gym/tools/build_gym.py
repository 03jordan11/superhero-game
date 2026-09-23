"""Blender authoring source; Godot metres (X, Y up, Z) throughout.
Exports each reusable object separately and an assembled editable .blend.
Run Blender --background --python this_file, then tools/prepare_gym.gd in Godot.
"""
import bpy, math, json, random
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
random.seed(74)
MATS = {}
TEXTURES = {}
# Seamless procedural material maps authored in Blender, not reference-image crops.
(ROOT/'textures').mkdir(exist_ok=True)
rng=np.random.default_rng(74)
n=512
yy,xx=np.mgrid[0:n,0:n]/n
cloud=np.zeros((n,n))
for frequency,weight in [(1,.035),(2,.03),(4,.026),(9,.015),(23,.007)]:
    for j in range(6):
        ax=int(rng.integers(-frequency,frequency+1)); ay=int(rng.integers(-frequency,frequency+1))
        cloud+=weight*np.sin(math.tau*(ax*xx+ay*yy)+rng.random()*math.tau)
grain=rng.normal(0,.014,(n,n))
for kind in ['concrete','plaster','wood','canvas','rubber']:
    value=.78+cloud*.15+grain*.7
    if kind=='plaster': value=.88+cloud*.08+grain*.7
    if kind=='wood': value=.73+cloud*.4+.055*np.sin(math.tau*(yy*34+.14*np.sin(xx*math.tau*3)))+grain
    if kind=='canvas': value=.86+cloud*.2+.035*np.sin(xx*math.tau*180)*np.sin(yy*math.tau*180)+grain*.5
    if kind=='rubber': value=.78+cloud*.18+grain*1.5+.035*np.sin(math.tau*(xx+yy)*70)
    value=np.clip(value,.2,1)
    rgba=np.ones((n,n,4),dtype=np.float32); rgba[:,:,:3]=value[:,:,None]
    img=bpy.data.images.new('Gym_'+kind,width=n,height=n)
    img.pixels.foreach_set(rgba.ravel()); img.filepath_raw=str(ROOT/'textures'/f'{kind}.png'); img.file_format='PNG'; img.save()
    TEXTURES[kind]='assets/interiors/boxing_gym/textures/'+kind+'.png'

def material(name, color, texture=None, metal=0, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .78 if not metal else .48
    bs.inputs['Metallic'].default_value = metal
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    if texture:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(PROJECT / texture), check_existing=True)
        mul = m.node_tree.nodes.new('ShaderNodeMixRGB')
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1
        mul.inputs[2].default_value = (*color, 1)
        m.node_tree.links.new(tex.outputs['Color'], mul.inputs[1])
        m.node_tree.links.new(mul.outputs[0], bs.inputs['Base Color'])
        # Godot preparation assigns matching shared materials explicitly.
    m['source_texture'] = texture or ''
    MATS[name] = m

concrete = TEXTURES['concrete']
for name,c,tex,metal in [
    ('Plaster',(.62,.57,.47),TEXTURES['plaster'],0), ('Concrete',(.40,.41,.39),concrete,0),
    ('Teal',(.10,.22,.23),concrete,0), ('Brick',(.42,.33,.25),concrete,0),
    ('Steel',(.075,.095,.105),None,.55), ('SteelEdge',(.28,.31,.30),None,.65),
    ('Canvas',(.75,.72,.62),TEXTURES['canvas'],0), ('CanvasEdge',(.43,.40,.32),None,0),
    ('Apron',(.085,.17,.22),TEXTURES['canvas'],0),
    ('Red',(.43,.09,.065),None,0), ('Blue',(.08,.18,.24),None,0),
    ('Ivory',(.72,.69,.57),None,0), ('Rubber',(.07,.08,.08),TEXTURES['rubber'],0),
    ('Wood',(.28,.19,.105),TEXTURES['wood'],0), ('WoodLight',(.42,.30,.17),TEXTURES['wood'],0),
    ('Locker',(.11,.20,.25),None,.35), ('Paper',(.55,.48,.34),None,0),
    ('Ink',(.08,.105,.10),None,0), ('Leather',(.23,.065,.042),None,0)]:
    material(name,c,tex,metal)
material('Lamp',(.95,.78,.48),emission=3)
material('ExitGreen',(.025,.20,.065),emission=.6)
material('WindowGlass',(.12,.19,.22),metal=.25)

def bl(v): return (v[0],-v[2],v[1])
assets={}
class Asset:
    def __init__(self,name):
        self.name=name; self.buffers={}; self.collision=[]; self.objects=[]
        assets[name]=self
    def face(self,pts,mat,uv=None):
        vs,fs,us=self.buffers.setdefault(mat,([],[],[]))
        start=len(vs); vs.extend(bl(p) for p in pts); fs.append(tuple(range(start,start+len(pts))))
        if uv is None:
            norm=(Vector(pts[1])-Vector(pts[0])).cross(Vector(pts[2])-Vector(pts[0]))
            axis=max(range(3),key=lambda i:abs(norm[i])); axes=[i for i in range(3) if i!=axis]
            uv=[(p[axes[0]]/2,p[axes[1]]/2) for p in pts]
        us.extend(uv)
    def box(self,c,s,mat='Steel',solid=False):
        x,y,z=c; a,b,d=[v/2 for v in s]
        p=[(x+dx,y+dy,z+dz) for dx,dy,dz in [(-a,-b,-d),(a,-b,-d),(a,-b,d),(-a,-b,d),(-a,b,-d),(a,b,-d),(a,b,d),(-a,b,d)]]
        for f in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2)]: self.face([p[i] for i in f],mat)
        if solid: self.collision.append({'center':c,'size':s})
    def beam(self,a,b,r,mat='Steel',sides=8):
        a,b=Vector(a),Vector(b); axis=(b-a).normalized()
        u=axis.cross(Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))).normalized()
        v=axis.cross(u)
        rings=[[p+r*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)] for p in [a,b]]
        for i in range(sides):
            j=(i+1)%sides
            self.face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],mat)
        self.face(list(reversed(rings[0])),mat); self.face(rings[1],mat)
    def ellipsoid(self,c,s,mat='Leather',segments=16,rings=8):
        # Lathed, faceted padded leather; no poles with degenerate triangles.
        rows=[]
        for j in range(1,rings):
            phi=math.pi*j/rings
            rows.append([(c[0]+s[0]*math.sin(phi)*math.cos(i*math.tau/segments),c[1]+s[1]*math.cos(phi),c[2]+s[2]*math.sin(phi)*math.sin(i*math.tau/segments)) for i in range(segments)])
        for i in range(segments):
            k=(i+1)%segments
            self.face([(c[0],c[1]+s[1],c[2]),rows[0][k],rows[0][i]],mat)
            self.face([(c[0],c[1]-s[1],c[2]),rows[-1][i],rows[-1][k]],mat)
            for j in range(len(rows)-1): self.face([rows[j][i],rows[j][k],rows[j+1][k],rows[j+1][i]],mat)
    def ramp(self,x,z0,z1,width,height):
        pts=[(x-width/2,0,z0),(x+width/2,0,z0),(x-width/2,0,z1),(x+width/2,0,z1),(x-width/2,height,z1),(x+width/2,height,z1)]
        self.collision.append({'points':pts})
    def corner_pad(self,x,z,mat):
        outline=[(-.10,-.15),(.10,-.15),(.15,-.10),(.15,.10),(.10,.15),(-.10,.15),(-.15,.10),(-.15,-.10)]
        rows=[[(x+dx*scale,y,z+dz*scale) for dx,dz in outline] for y,scale in [(1.18,.7),(1.24,1),(2.41,1),(2.47,.7)]]
        for j in range(3):
            for i in range(8):
                k=(i+1)%8
                self.face([rows[j][i],rows[j+1][i],rows[j+1][k],rows[j][k]],mat)
        self.face(rows[0],mat); self.face(list(reversed(rows[-1])),mat)
    def lettering(self,text,c,size,mat):
        curve=bpy.data.curves.new('Sign lettering','FONT'); curve.body=text
        curve.align_x='CENTER'; curve.align_y='CENTER'; curve.size=size; curve.extrude=.001
        obj=bpy.data.objects.new('Sign lettering',curve); bpy.context.collection.objects.link(obj)
        obj.location=bl(c); obj.rotation_euler[0]=math.pi/2
        bpy.context.view_layer.update()
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()); mesh=evaluated.to_mesh()
        for poly in mesh.polygons:
            points=[obj.matrix_world @ mesh.vertices[i].co for i in poly.vertices]
            self.face([(p.x,p.z,-p.y) for p in points],mat)
        evaluated.to_mesh_clear(); bpy.data.objects.remove(obj,do_unlink=True)
    def rail(self,a,b,base=0):
        a,b=Vector(a),Vector(b)
        for h in [.52,1.08]: self.beam(a+Vector((0,h,0)),b+Vector((0,h,0)),.034)
        n=max(1,math.ceil((b-a).length/1.3))
        for i in range(n+1):
            p=a.lerp(b,i/n); self.beam(p,p+Vector((0,1.08,0)),.038)
        # Walkway edges block players/cameras; bars remain visually open.
        c=(a+b)/2+Vector((0,.55,0)); size=[max(.09,abs(b[i]-a[i])) for i in range(3)]; size[1]=1.1
        self.collision.append({'center':list(c),'size':size})
    def export(self):
        collection=bpy.data.collections.new(self.name); bpy.context.scene.collection.children.link(collection)
        for mat,(vs,fs,uvs) in self.buffers.items():
            mesh=bpy.data.meshes.new(self.name+'_'+mat); mesh.from_pydata(vs,[],fs); mesh.materials.append(MATS[mat]); mesh.update()
            uv=mesh.uv_layers.new(name='UVMap')
            for loop in mesh.loops: uv.data[loop.index].uv=uvs[loop.vertex_index]
            obj=bpy.data.objects.new(self.name+'_'+mat,mesh); collection.objects.link(obj); self.objects.append(obj)
        bpy.ops.object.select_all(action='DESELECT')
        for o in self.objects: o.select_set(True)
        bpy.context.view_layer.objects.active=self.objects[0]
        bpy.ops.export_scene.gltf(filepath=str(ROOT/'source'/f'{self.name}.glb'),use_selection=True,export_format='GLB',export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)

# A single clear-span industrial hall: no additional rooms.
a=Asset('floor'); a.box((0,-.16,0),(24.6,.32,22.6),'Concrete',True)
# Inlaid expansion joints are flat detail, not trip hazards.
for x in [-8,-4,0,4,8]: a.box((x,.001,0),(.012,.002,22),'CanvasEdge')
for z in [-8,-4,0,4,8]: a.box((0,.001,z),(24,.002,.012),'CanvasEdge')
a=Asset('walls')
for c,s in [((0,4,-11.2),(24.8,8,.4)),((-12.2,4,0),(.4,8,22)),((12.2,4,0),(.4,8,22))]: a.box(c,s,'Plaster',True)
for c,s in [((0,.7,-10.985),(24,1.4,.025)),((-11.985,.7,0),(.025,1.4,22)),((11.985,.7,0),(.025,1.4,22))]: a.box(c,s,'Teal')
for x in [-11.7,-6,6,11.7]:
    a.box((x,4,-10.77),(.36,8,.4),'Concrete',True)
    a.box((x,7.6,0),(.22,.44,22),'Steel')
a.box((0,7.6,0),(.22,.44,22),'Steel')
for x in [-11.77,11.77]:
    for z in [-5,1,7]: a.box((x,4,z),(.45,8,.4),'Concrete',True)
for z in [-10.6,0,10.6]: a.box((0,7.2,z),(24,.3,.22),'Steel')
for x in [-11.9,11.9]: a.beam((x,6.8,-10.8),(x,6.8,10.8),.055,'SteelEdge')
a=Asset('front_wall')
a.box((-6.9,4,11.2),(10.2,8,.4),'Plaster',True); a.box((6.9,4,11.2),(10.2,8,.4),'Plaster',True)
a.box((0,5.6,11.2),(3.6,4.8,.4),'Plaster',True)
for x in [-6.9,6.9]: a.box((x,.7,10.985),(10.2,1.4,.025),'Teal')
a=Asset('ceiling'); a.box((0,8.1,0),(24.7,.2,22.7),'Concrete',True)
for x in range(-11,12,2): a.box((x,7.92,0),(.065,.14,22),'SteelEdge')
a=Asset('entrance_door')
for x in [-.79,.79]:
    a.box((x,1.55,0),(1.55,3.1,.13),'Steel',True)
    a.box((x,2.25,.076),(1.15,1.1,.025),'Blue')
    a.box((x,1.1,.095),(1.3,.12,.05),'SteelEdge')
    a.box((x,.32,.08),(1.35,.44,.024),'SteelEdge')
for x in [-1.72,1.72]: a.box((x,1.64,0),(.16,3.28,.25),'SteelEdge')
a.box((0,3.2,0),(3.6,.16,.25),'SteelEdge')

# Elevated rear catwalk and open office overlook.
a=Asset('catwalk'); a.box((0,3.45,-9.25),(23.5,.3,3.5),'Steel',True)
a.box((8.75,3.45,-6.35),(6,.3,2.3),'Steel',True)
for x in [-7,-1,5]: a.box((x,1.65,-8),(.18,3.3,.18),'Steel',True)
a.rail((-8.8,3.6,-7.5),(5.75,3.6,-7.5)); a.rail((5.75,3.6,-7.5),(5.75,3.6,-5.2))
a.rail((5.75,3.6,-5.2),(11.75,3.6,-5.2))
a.box((8.75,4.0,-5.23),(6,.8,.1),'Teal')
a=Asset('catwalk_stairs')
for i in range(21):
    h=(i+1)*3.6/21; z=-1.2-(i+.5)*.3
    a.box((-10.1,h-.065,z),(1.8,.13,.3),'Steel')
    a.box((-10.1,h+.003,z+.105),(1.7,.006,.035),'SteelEdge')
a.ramp(-10.1,-1.2,-7.5,1.8,3.6)
for x in [-11.05,-9.15]:
    a.beam((x,.82,-1.2),(x,4.42,-7.5),.04)
    a.beam((x,.38,-1.2),(x,3.98,-7.5),.035)
    a.beam((x,.05,-1.2),(x,3.65,-7.5),.075)
    for i in range(0,22,3):
        z=-1.2-i*.3; y=i*3.6/21
        a.beam((x,y,z),(x,y+.82,z),.033)
    a.collision.append({'points':[(x-.07,y,z) for y,z in [(0,-1.2),(1.1,-1.2),(3.6,-7.5),(4.7,-7.5)]]+[(x+.07,y,z) for y,z in [(0,-1.2),(1.1,-1.2),(3.6,-7.5),(4.7,-7.5)]]})

# Boxing ring, 6.10 m clear inside 4 cm ropes, 7.4 m platform, 1 m high.
a=Asset('boxing_ring'); a.box((0,.46,0),(7.4,.92,7.4),'Apron',True)
a.box((0,.96,0),(7.4,.08,7.4),'Canvas',True)
for x in [-3.66,3.66]: a.box((x,1.002,0),(.07,.004,7.3),'CanvasEdge')
for z in [-3.66,3.66]: a.box((0,1.002,z),(7.3,.004,.07),'CanvasEdge')
for x in [-3.37,3.37]:
    for z in [-3.37,3.37]:
        color='Red' if x*z>0 else 'Blue'
        a.beam((x,0,z),(x,2.5,z),.10,color,12)
        a.box((x,.08,z),(.36,.16,.36),'Steel',True)
        a.corner_pad(x/abs(x)*3.12,z/abs(z)*3.12,color)
        for h in [1.4,1.7,2.0,2.3]: a.beam((x,h,z),(x/abs(x)*3.07,h,z/abs(z)*3.07),.019,'SteelEdge',6)
for h,color in [(1.4,'Blue'),(1.7,'Ivory'),(2.0,'Ivory'),(2.3,'Red')]:
    for x in [-3.07,3.07]: a.beam((x,h,-3.07),(x,h,3.07),.02,color,8)
    a.beam((-3.07,h,-3.07),(3.07,h,-3.07),.02,color,8)
    a.beam((-3.07,h,3.07),(3.07,h,3.07),.02,color,8)
for x in [-3.07,3.07]:
    for z in [-1,1]: a.box((x,1.85,z),(.05,.95,.075),'CanvasEdge')
for x in [-1,1]: a.box((x,1.85,-3.07),(.075,.95,.05),'CanvasEdge')
for x in [-1,1]: a.box((x,1.85,3.07),(.075,.95,.05),'CanvasEdge')
for x in [-3.08,3.08]: a.collision.append({'center':(x,1.7,0),'size':(.07,1.4,6.16)})
a.collision.append({'center':(0,1.7,-3.08),'size':(6.16,1.4,.07)})
a.collision.append({'center':(0,1.7,3.08),'size':(6.16,1.4,.07)})
a=Asset('ring_steps')
for i in range(5):
    h=(i+1)*.2; z=1.5-(i+.5)*.3
    a.box((0,h/2,z),(1.5,h,.3),'Steel')
    a.box((0,h+.003,z+.11),(1.4,.006,.03),'Ivory')
a.ramp(0,1.5,0,1.5,1)

a=Asset('heavy_bag')
a.box((0,2.7,-.75),(.18,1.6,.16),'Steel',True)
a.box((0,3.35,-.18),(.16,.15,1.2),'Steel')
a.beam((0,2.55,-.7),(0,3.35,.38),.04)
for x in [-.19,.19]: a.beam((0,3.3,.32),(x,2.52,.32),.017,'SteelEdge',6)
a.beam((0,.8,.32),(0,2.4,.32),.31,'Leather',20)
a.ellipsoid((0,.81,.32),(.31,.15,.31),'Leather',20,6)
a.ellipsoid((0,2.39,.32),(.31,.15,.31),'Leather',20,6)
for y in [.95,2.28]: a.beam((0,y-.04,.32),(0,y+.04,.32),.316,'Ink',20)
a.box((0,1.62,.637),(.035,1.08,.006),'CanvasEdge')
a.collision.append({'center':(0,1.55,.32),'size':(.62,1.8,.62)})
a=Asset('speed_bag')
a.box((0,2.2,-.42),(.9,.85,.12),'Wood',True)
for x in [-.32,.32]: a.beam((x,1.95,-.36),(x,2.5,.25),.035)
a.beam((0,2.51,.23),(0,2.61,.23),.5,'WoodLight',24)
a.beam((0,2.35,.23),(0,2.51,.23),.023,'SteelEdge')
a.ellipsoid((0,2.13,.23),(.13,.24,.13),'Leather',16,8)
a.ellipsoid((0,2.02,.23),(.18,.17,.18),'Leather',16,8)
a.collision.append({'center':(0,2.4,.05),'size':(1,.45,.95)})
a=Asset('weight_rack')
for x in [-1.35,1.35]:
    a.box((x,.62,0),(.09,1.24,.1),'Steel')
    a.box((x,.08,0),(.16,.16,1.05),'Steel',True)
for h in [.48,1.05]:
    a.box((0,h,.02),(3,.07,.58),'Steel',True)
    for i in range(6):
        x=-1.16+i*.46; r=.1+i*.014
        a.beam((x,h+.12,-.23),(x,h+.12,.25),.024,'SteelEdge')
        for z in [-.18,.2]: a.beam((x,h+.12,z-.07),(x,h+.12,z+.07),r,'Rubber',10)
a=Asset('bench')
for x in [-.85,.85]:
    a.box((x,.23,0),(.09,.46,.48),'Steel',True)
for z in [-.16,0,.16]: a.box((0,.49,z),(2.2,.1,.145),'WoodLight',True)
a=Asset('locker')
a.box((0,1.02,0),(.66,2.04,.55),'Locker',True)
a.box((0,1.05,.282),(.58,1.94,.025),'Blue')
for y in [.24,1.73,1.78,1.83]: a.box((0,y,.30),(.37,.018,.012),'Steel')
a.box((.19,1.12,.31),(.045,.19,.035),'SteelEdge')
a.box((.19,1.19,.333),(.025,.027,.012),'Ink')
a=Asset('mat'); a.box((0,.017,0),(2.4,.034,2.4),'Rubber')
for i in range(-5,6):
    a.box((i*.2,.035,0),(.008,.002,2.3),'Steel')
a=Asset('boarded_window')
a.box((0,0,0),(2.65,2.75,.08),'Ink')
for x in [-1.3,0,1.3]: a.box((x,0,.05),(.06,2.8,.07),'Steel')
for y in [-1.35,0,1.35]: a.box((0,y,.05),(2.65,.065,.07),'Steel')
for i in range(7):
    y=-1.2+i*.39
    a.box((0,y,.11),(2.55,.32,.055),'WoodLight' if i%3==0 else 'Wood')
    for x in [-1.13,1.13]: a.box((x,y,.144),(.028,.028,.009),'SteelEdge')
for x in [-.85,.85]: a.box((x,0,.17),(.10,2.65,.06),'Wood')
a=Asset('poster')
a.box((0,0,0),(1.7,2.25,.035),'Steel'); a.box((0,0,.022),(1.61,2.16,.008),'Paper')
a.box((0,-.7,.03),(1.4,.1,.005),'Red'); a.box((0,.79,.03),(1.4,.025,.005),'Ink')
# Wordless stylised paired boxing gloves, formed as shallow graphic silhouettes.
for side in [-1,1]:
    a.ellipsoid((side*.32,.12,.036),(.29,.4,.008),'Red',14,8)
    a.ellipsoid((side*.12,-.04,.04),(.14,.2,.009),'Red',12,6)
    a.box((side*.33,-.32,.038),(.40,.20,.012),'Ink')
    a.box((side*.33,-.30,.047),(.25,.022,.005),'Paper')
a=Asset('desk')
a.box((0,.78,0),(1.9,.09,.82),'WoodLight',True)
for x in [-.78,.78]: a.box((x,.36,0),(.12,.72,.7),'Steel',True)
a.box((.53,.53,.02),(.5,.35,.65),'Wood')
a.box((.53,.54,.354),(.2,.022,.032),'SteelEdge')
a=Asset('chair')
a.box((0,.47,0),(.58,.1,.55),'Leather',True)
a.box((0,.85,-.25),(.58,.62,.09),'Leather',True)
for x in [-.23,.23]:
    for z in [-.2,.2]: a.box((x,.23,z),(.035,.46,.035),'Steel')
a=Asset('crate')
a.box((0,.28,0),(.7,.56,.55),'Wood',True)
for x in [-.28,.28]:
    for z in [-.29,.29]: a.box((x,.28,z),(.07,.57,.045),'WoodLight')
for y in [.12,.3,.48]: a.box((0,y,.281),(.62,.009,.008),'Ink')
a=Asset('duffel')
a.ellipsoid((0,.19,0),(.40,.20,.23),'Blue',16,8)
for x in [-.18,.18]:
    a.beam((x,.25,-.16),(x,.43,0),.018,'Ink'); a.beam((x,.43,0),(x,.25,.16),.018,'Ink')
a=Asset('towel'); a.box((0,.022,0),(.44,.044,.32),'Ivory')
for x in [-.17,.17]: a.box((x,.045,0),(.022,.002,.31),'Blue')
a=Asset('bottle')
a.beam((0,0,0),(0,.24,0),.055,'Blue',12); a.beam((0,.24,0),(0,.28,0),.033,'SteelEdge',12)
a=Asset('pendant')
a.beam((0,0,0),(0,-.6,0),.016,'SteelEdge',6)
a.beam((0,-.62,0),(0,-.76,0),.3,'Steel',20)
a.beam((0,-.76,0),(0,-.78,0),.25,'Lamp',20)
a=Asset('wall_light')
a.box((0,0,0),(.24,.55,.18),'Steel'); a.box((0,0,.102),(.16,.39,.04),'Lamp')
for y in [-.16,0,.16]: a.box((0,y,.132),(.2,.018,.02),'Steel')

a=Asset('front_window')
a.box((0,0,0),(8.8,2.05,.09),'WindowGlass')
for x in [-4.45,4.45]: a.box((x,0,.035),(.12,2.2,.16),'Steel')
for y in [-1.075,1.075]: a.box((0,y,.035),(9,.1,.16),'Steel')
for x in [-3.15,-1.9,-.63,.63,1.9,3.15]: a.box((x,0,.065),(.055,2.1,.09),'Steel')
for y in [-.36,.36]: a.box((0,y,.065),(8.9,.055,.09),'Steel')
a.box((0,-1.14,0),(9.15,.12,.33),'Concrete')

a=Asset('bathroom_exterior')
a.box((0,1.62,0),(5.4,3.24,4.3),'Plaster',True)
# Wainscot wraps all exposed sides; upper slab sits beneath the office floor.
for x in [-2.705,2.705]: a.box((x,.64,0),(.025,1.28,4.3),'Teal')
a.box((0,.64,2.16),(5.4,1.28,.025),'Teal')
a.box((0,3.13,2.18),(5.4,.13,.09),'Concrete')
a.box((0,1.28,2.195),(1.3,2.56,.08),'Wood')
for x in [-.71,.71]: a.box((x,1.33,2.215),(.1,2.66,.13),'Steel')
a.box((0,2.62,2.215),(1.52,.1,.13),'Steel')
a.box((.43,1.15,2.27),(.20,.055,.075),'SteelEdge')
a.box((0,.2,2.241),(1.18,.32,.012),'SteelEdge')
a.box((0,1.89,2.255),(.42,.48,.035),'Blue')
# Wordless restroom pictogram.
for x in [-.105,.105]:
    a.ellipsoid((x,2.01,2.28),(.043,.043,.009),'Ivory',10,6)
    a.box((x,1.88,2.28),(.083,.17,.016),'Ivory')
    for dx in [-.026,.026]: a.box((x+dx,1.755,2.28),(.027,.1,.016),'Ivory')

a=Asset('back_door')
a.box((0,1.32,0),(1.35,2.64,.12),'Blue',True)
for x in [-.73,.73]: a.box((x,1.36,.01),(.12,2.72,.19),'Steel')
a.box((0,2.68,.01),(1.58,.1,.19),'Steel')
a.box((0,.3,.069),(1.2,.42,.025),'SteelEdge')
a.box((0,1.12,.11),(1.1,.085,.08),'SteelEdge')
a.box((0,2.06,.067),(.55,.48,.025),'Steel')
a.box((0,2.06,.085),(.46,.39,.025),'WindowGlass')
a=Asset('exit_sign')
a.box((0,0,0),(.92,.35,.13),'Steel')
a.box((0,0,.076),(.84,.28,.026),'ExitGreen')
a.lettering('EXIT',(0,0,.096),.25,'Lamp')

placements=[]
def place(kind,name,pos=(0,0,0),yaw=0,category='Props'):
    placements.append(dict(kind=kind,name=name,position=pos,yaw=yaw,category=category))
for name in ['floor','walls','front_wall','ceiling','catwalk','catwalk_stairs']: place(name,''.join(s.title() for s in name.split('_')),category='Architecture')
place('entrance_door','EntranceDoor',(0,0,10.94),math.pi)
place('boxing_ring','BoxingRing',(0,0,1),category='Training')
place('ring_steps','RingSteps',(-2.2,0,4.7),category='Training')
for x,side in [(-6.9,'Left'),(6.9,'Right')]: place('front_window','FrontWindow'+side,(x,1.82,10.94),math.pi)
place('bathroom_exterior','BathroomExterior',(9,0,-8.6),category='Architecture')
place('back_door','BackDoor',(-8.65,0,-10.93))
place('exit_sign','RearExitSign',(-8.65,2.98,-10.88))
for i,z in enumerate([2.8,6.3]): place('heavy_bag',f'HeavyBag{i+1}',(-11.15,0,z),math.pi/2,'Training')
place('speed_bag','SpeedBag',(11.4,0,5.4),-math.pi/2,'Training')
place('weight_rack','WeightRack',(10.5,0,.2),-math.pi/2,'Training')
for i,x in enumerate([-4.8,-4.08,-3.36,-2.64,-1.92,1.7,2.42,3.14]): place('locker',f'Locker{i+1}',(x,0,-10.35))
for i,(x,z,yaw) in enumerate([(-3.4,-8.6,0),(5.4,1,math.pi/2),(-5.4,1,math.pi/2)]): place('bench',f'Bench{i+1}',(x,0,z),yaw)
for i,(x,z) in enumerate([(-10,2.8),(-10,6.3),(10.2,5.4),(9.8,0),(7.4,0)]): place('mat',f'TrainingMat{i+1}',(x,0,z))
for i,z in enumerate([-6,0,6]):
    for side in [-1,1]: place('boarded_window',f'Window{i}_{side}',(side*11.97,5.2,z),-side*math.pi/2)
for i,x in enumerate([-4,0,4]): place('poster',f'Poster{i+1}',(x,5.55,-10.94))
place('desk','OfficeDesk',(8.6,3.6,-8.2)); place('chair','OfficeChair',(8.6,3.6,-9.2))
place('bottle','OfficeBottle',(8.1,4.425,-8.1)); place('towel','OfficePapers',(9,4.425,-8.2))
place('crate','StorageCrate1',(5,0,-10)); place('crate','StorageCrate2',(5.75,0,-10))
place('duffel','KitBag',(-4,0,-8)); place('towel','BenchTowel',(-3.6,.54,-8.6)); place('bottle','WaterBottle',(-2.8,.54,-8.6))
for i,(x,z) in enumerate([(-4,-3),(4,-3),(-4,4),(4,4),(0,8)]): place('pendant',f'Pendant{i+1}',(x,7.6,z),category='Lighting')
for i,x in enumerate([-8,2,8]): place('wall_light',f'WallLight{i+1}',(x,5.6,-10.85),category='Lighting')

for a in assets.values(): a.export()
# Assemble source collections with linked mesh copies at the authored placements.
for p in placements:
    a=assets[p['kind']]
    parent=bpy.data.objects.new(p['name'],None); bpy.context.scene.collection.objects.link(parent)
    parent.location=bl(p['position']); parent.rotation_euler[2]=p['yaw']
    for src in a.objects:
        o=src.copy(); o.data=src.data; bpy.context.scene.collection.objects.link(o); o.parent=parent
        # Editable cutaway when opening Blender; exported Godot room remains enclosed.
        if p['name'] in ['Ceiling','FrontWall','EntranceDoor']: o.hide_set(True)
for a in assets.values():
    for o in a.objects: bpy.data.objects.remove(o,do_unlink=True)
for img in bpy.data.images:
    if img.source=='FILE': img.pack()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.color_type='MATERIAL'
            area.spaces.active.region_3d.view_distance=32
            area.spaces.active.region_3d.view_location=(0,0,2)
            area.spaces.active.region_3d.view_rotation=Vector((-.45,1,-.75)).to_track_quat('-Z','Y')
bpy.context.scene['dimensions_metres']='24 x 22 x 8; ring clear inside ropes 6.10 x 6.10; platform 7.4 x 7.4 x 1.0'
bpy.context.scene['budget']=50000
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/'boxing_gym.blend'))
(ROOT/'source'/'manifest.json').write_text(json.dumps({'materials':{k:{'color':list(m.diffuse_color),'metallic':m.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value,'texture':m['source_texture'],'emission':m.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value if k in ['Lamp','ExitGreen'] else 0} for k,m in MATS.items()},'assets':{k:{'collision':a.collision} for k,a in assets.items()},'placements':placements},indent=2))
print('BOXING_GYM_BLENDER_COMPLETE',len(assets),'reusable assets;',len(placements),'placements')
