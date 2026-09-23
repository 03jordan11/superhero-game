"""Blender-authored exterior for the 24 x 22 x 8 m boxing hall.
Godot coordinates in metres, +Z front. Does not edit or include the interior.
"""
import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.context.scene.unit_settings.system='METRIC'
rng=np.random.default_rng(317)
N=512
yy,xx=np.mgrid[0:N,0:N]/N
noise=rng.normal(0,.010,(N,N))
cloud=.012*np.sin(xx*math.tau*3)*np.sin(yy*math.tau*4)+.008*np.cos((xx+yy)*math.tau*9)
def rgb(h): return np.array([int(h[i:i+2],16)/255 for i in (0,2,4)])
def linear(c): return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
def texture(name,colors):
    img=bpy.data.images.new(name,width=N,height=N)
    pixels=np.ones((N,N,4),np.float32); pixels[:,:,:3]=linear(np.clip(colors,0,1))
    img.pixels.foreach_set(pixels.ravel())
    img.filepath_raw=str(BASE/'textures'/f'{name}.png'); img.file_format='PNG'; img.save()
    return img

# Low-contrast running-bond masonry: physical tile spans 2.4 x 1.2 m.
row=np.floor(yy*12).astype(int); col=np.floor(xx*8+(row%2)*.5).astype(int)%8
variation=rng.uniform(-.035,.035,(12,8))[row,col]
brick=rgb('80685F')+(variation+noise+cloud)[:,:,None]
mortar=((yy*12)%1 < .065)|(((xx*8+(row%2)*.5)%1)<.027)
brick[mortar]=rgb('787A76')+noise[mortar,None]
maps={'Brick':texture('muted_brick',brick),
      'Concrete':texture('weathered_concrete',rgb('858A8D')+(noise*.6+cloud*.6)[:,:,None]),
      'Roof':texture('roof_membrane',rgb('303946')+(noise*.5+cloud*.4)[:,:,None]),
      'Wood':texture('aged_boards',rgb('79665C')+(noise*.4+.018*np.sin(yy*math.tau*41+.25*np.sin(xx*math.tau*3)))[:,:,None])}
MATS={}; specs={}
def material(name,h,tex=None,metal=0,rough=.85,emission=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    color=rgb(h); m.diffuse_color=(*linear(color),1)
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*linear(color),1)
    bs.inputs['Roughness'].default_value=rough; bs.inputs['Metallic'].default_value=metal
    if tex:
        node=m.node_tree.nodes.new('ShaderNodeTexImage'); node.image=maps[tex]
        m.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    if emission:
        bs.inputs['Emission Color'].default_value=(*linear(color),1); bs.inputs['Emission Strength'].default_value=emission
    MATS[name]=m
    specs[name]={'color':h,'texture':f'textures/{maps[tex].name}.png' if tex else '', 'metallic':metal,'roughness':rough,'emission':emission}
material('Brick','FFFFFF','Brick')
material('Concrete','FFFFFF','Concrete')
material('Roof','FFFFFF','Roof')
material('Wood','FFFFFF','Wood')
material('Plinth','465B54')
material('Steel','303946',metal=.5,rough=.6)
material('Trim','677477',metal=.25,rough=.65)
material('Glass','263644',metal=.25,rough=.3)
material('GlassHighlight','415462',metal=.25,rough=.34)
material('Sign','4B5867')
material('Bronze','B68B59',metal=.15,rough=.7)
material('Lamp','E4C58A',rough=.5,emission=1.3)

def bl(p): return (p[0],-p[2],p[1])
parts={}
class Part:
    def __init__(self,name):
        self.name=name; self.buffers={}; self.collision=[]; self.objects=[]; parts[name]=self
    def face(self,p,mat):
        vs,fs,uv=self.buffers.setdefault(mat,([],[],[])); start=len(vs)
        vs.extend(bl(v) for v in p); fs.append(tuple(range(start,start+len(p))))
        norm=(Vector(p[1])-Vector(p[0])).cross(Vector(p[2])-Vector(p[0])); axis=max(range(3),key=lambda i:abs(norm[i]))
        axes=[2,1] if axis==0 else ([0,2] if axis==1 else [0,1])
        scale=(2.4,1.2) if mat=='Brick' else (2,2)
        uv.extend([(q[axes[0]]/scale[0],q[axes[1]]/scale[1]) for q in p])
    def box(self,c,s,mat,solid=False):
        x,y,z=c; a,b,d=[v/2 for v in s]
        p=[(x+dx,y+dy,z+dz) for dx,dy,dz in [(-a,-b,-d),(a,-b,-d),(a,-b,d),(-a,-b,d),(-a,b,-d),(a,b,-d),(a,b,d),(-a,b,d)]]
        for f in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2)]: self.face([p[i] for i in f],mat)
        if solid: self.collision.append({'center':c,'size':s})
    def beam(self,a,b,r,mat,sides=8):
        a,b=Vector(a),Vector(b); axis=(b-a).normalized()
        u=axis.cross(Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))).normalized(); v=axis.cross(u)
        rings=[[p+r*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)] for p in [a,b]]
        for i in range(sides):
            j=(i+1)%sides; self.face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],mat)
        self.face(list(reversed(rings[0])),mat); self.face(rings[1],mat)
    def glyph(self,outline,c,scale,mat):
        # A shallow wordless glove silhouette: bevel-free painted metal emblem.
        x,y,z=c
        self.face([(x+dx*scale,y+dy*scale,z) for dx,dy in outline],mat)
    def export(self):
        collection=bpy.data.collections.new(self.name); bpy.context.scene.collection.children.link(collection)
        for mat,(vs,fs,uvs) in self.buffers.items():
            mesh=bpy.data.meshes.new(self.name+'_'+mat); mesh.from_pydata(vs,[],fs); mesh.materials.append(MATS[mat]); mesh.update()
            uv=mesh.uv_layers.new(name='UVMap')
            for loop in mesh.loops: uv.data[loop.index].uv=uvs[loop.vertex_index]
            obj=bpy.data.objects.new(self.name+'_'+mat,mesh); collection.objects.link(obj); self.objects.append(obj)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in self.objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=self.objects[0]
        bpy.ops.export_scene.gltf(filepath=str(BASE/'source'/f'{self.name}.glb'),use_selection=True,export_format='GLB',export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)

p=Part('shell')
p.box((0,4.1,0),(24.8,8.2,22.8),'Brick',True)
# Durable painted lower wall, lintel course and a modest cornice.
for x in [-12.42,12.42]:
    p.box((x,.67,0),(.04,1.34,22.8),'Plinth')
    p.box((x,3.35,0),(.06,.22,22.8),'Concrete')
for z in [-11.42,11.42]:
    p.box((0,.67,z),(24.8,1.34,.04),'Plinth')
    p.box((0,3.35,z),(24.85,.22,.06),'Concrete')
for x in [-12.25,-1.98,1.98,12.25]:
    p.box((x,4.09,11.49),(.38,8.18,.18),'Concrete')
    p.box((x,.32,11.54),(.47,.64,.25),'Concrete')
for x in [-12.48,12.48]:
    for z in [-10.9,-3,4.4,10.9]: p.box((x,4.1,z),(.16,8.2,.35),'Concrete')
p.box((0,8.11,0),(24.98,.18,22.98),'Concrete')
p.box((0,8.205,0),(24.3,.01,22.3),'Roof')
# Solid parapet; roof remains usable by the superhero.
for x in [-12.29,12.29]:
    p.box((x,8.5,0),(.22,.6,22.8),'Brick',True)
    p.box((x,8.84,0),(.36,.08,23),'Concrete')
for z in [-11.29,11.29]:
    p.box((0,8.5,z),(24.8,.6,.22),'Brick',True)
    p.box((0,8.84,z),(25,.08,.36),'Concrete')
# Rear pilasters and rainwater pipes, kept out of the rear exit.
for x in [-11.9,-5.6,5.6,11.9]: p.box((x,4.1,-11.47),(.3,8.2,.14),'Concrete')
for x in [-11.45,11.45]:
    p.beam((x,.25,-11.61),(x,8.25,-11.61),.055,'Trim')
    for y in [1,3.5,6.2]: p.box((x,y,-11.59),(.2,.07,.15),'Steel')

p=Part('entrance')
for x in [-.79,.79]:
    p.box((x,1.55,0),(1.55,3.1,.13),'Steel')
    p.box((x,2.25,.076),(1.15,1.1,.025),'Glass')
    p.box((x,.32,.08),(1.35,.44,.024),'Trim')
    # Pull handles outside; matching door dimensions to the indoor push doors.
    hx=x+(.50 if x<0 else -.50)
    p.beam((hx,1.05,.16),(hx,1.65,.16),.021,'Trim')
    for y in [1.08,1.62]: p.beam((hx,y,.08),(hx,y,.16),.019,'Trim')
for x in [-1.72,1.72]: p.box((x,1.64,0),(.16,3.28,.25),'Steel')
p.box((0,3.2,0),(3.6,.16,.25),'Steel')
p.box((0,.035,.17),(3.65,.07,.5),'Concrete',True)

p=Part('front_window')
p.box((0,0,0),(8.8,2.05,.09),'Glass')
# Subtle pane-value variation, no baked occupants or invented window lighting.
for i in range(7):
    if i%3!=1: p.box((-3.78+i*1.26,.34,.049),(1.19,1.31,.008),'GlassHighlight')
for x in [-4.45,4.45]: p.box((x,0,.035),(.12,2.2,.16),'Steel')
for y in [-1.075,1.075]: p.box((0,y,.035),(9,.1,.16),'Steel')
for x in [-3.15,-1.9,-.63,.63,1.9,3.15]: p.box((x,0,.065),(.055,2.1,.09),'Steel')
for y in [-.36,.36]: p.box((0,y,.065),(8.9,.055,.09),'Steel')

p=Part('upper_window')
p.box((0,0,0),(2.65,2.75,.07),'Glass')
for i in range(7): p.box((0,-1.2+i*.39,.05),(2.52,.32,.025),'Wood')
for x in [-1.3,0,1.3]: p.box((x,0,.09),(.065,2.8,.075),'Steel')
for y in [-1.35,0,1.35]: p.box((0,y,.09),(2.65,.065,.075),'Steel')

p=Part('sign_panel')
p.box((0,0,0),(7.2,1.45,.13),'Steel')
p.box((0,0,.073),(7.03,1.28,.025),'Sign')
for y in [-.6,.6]: p.box((0,y,.09),(6.9,.025,.008),'Trim')
# Two abstract glove silhouettes on the left; the remainder stays blank for a name.
glove=[(-.32,-.48),(.22,-.48),(.25,-.13),(.43,.02),(.43,.2),(.32,.25),(.24,.14),(.24,.50),(.16,.62),(-.18,.65),(-.33,.53),(-.37,.2)]
for x,mirror in [(-2.83,1),(-2.18,-1)]:
    points=[(dx*mirror,dy) for dx,dy in glove]
    # Front-face winding follows +Z for both mirrored emblems.
    area=sum(points[i][0]*points[(i+1)%len(points)][1]-points[(i+1)%len(points)][0]*points[i][1] for i in range(len(points)))
    if area<0: points.reverse()
    p.glyph(points,(x,0,.097),.7,'Bronze')
    p.box((x,-.25,.101),(.34,.035,.006),'Sign')

p=Part('canopy')
p.box((0,0,.6),(4.25,.14,1.45),'Steel',True)
p.box((0,.08,.6),(4.3,.02,1.5),'Roof')
for x in [-1.85,1.85]: p.beam((x,.62,-.08),(x,.04,1.17),.026,'Trim')
p.box((0,-.075,1.3),(4.25,.12,.05),'Trim')

p=Part('rear_door')
p.box((0,1.32,0),(1.35,2.64,.12),'Steel')
for x in [-.73,.73]: p.box((x,1.36,.01),(.12,2.72,.19),'Concrete')
p.box((0,2.68,.01),(1.58,.1,.19),'Concrete')
p.box((0,.3,.069),(1.2,.42,.025),'Trim')
p.box((.45,1.16,.12),(.045,.22,.07),'Trim')
p.box((0,2.06,.067),(.55,.48,.025),'Steel')
p.box((0,2.06,.085),(.46,.39,.025),'Glass')

p=Part('roof_unit')
for x in [-.9,.9]: p.box((x,.13,0),(.14,.26,1.9),'Steel',True)
p.box((0,.63,0),(2.3,.8,1.7),'Trim',True)
p.box((0,1.055,0),(2.37,.05,1.78),'Steel')
for i in range(8):
    for z in [-.857,.857]: p.box((0,.34+i*.077,z),(2.05,.025,.02),'Steel')
for x in [-.55,.55]:
    p.beam((x,1.082,0),(x,1.102,0),.41,'Roof',20)
    p.beam((x,1.1,0),(x,1.14,0),.085,'Trim',12)
    for i in range(8):
        a=i*math.tau/8
        p.beam((x,1.125,0),(x+.39*math.cos(a),1.125,.39*math.sin(a)),.011,'Trim',4)

p=Part('wall_lamp')
p.box((0,0,0),(.24,.5,.17),'Steel')
p.box((0,0,.105),(.15,.34,.045),'Lamp')
for y in [-.14,0,.14]: p.box((0,y,.137),(.2,.02,.018),'Steel')

placements=[]
def place(kind,name,pos=(0,0,0),yaw=0): placements.append({'kind':kind,'name':name,'position':pos,'yaw':yaw})
place('shell','BuildingShell')
place('entrance','FrontDoor',(0,0,11.48))
for x,side in [(-6.9,'Left'),(6.9,'Right')]: place('front_window','FrontWindow'+side,(x,1.82,11.47))
place('sign_panel','BlankGymSign',(0,5.03,11.65))
place('canopy','EntryCanopy',(0,3.46,11.48))
for side in [-1,1]:
    for i,z in enumerate([-6,0,6]): place('upper_window',f'UpperWindow_{side}_{i}',(side*12.43,5.2,z),side*math.pi/2)
place('rear_door','RearDoor',(-8.65,0,-11.47),math.pi)
for i,x in enumerate([-5,5]): place('roof_unit',f'RoofUnit{i+1}',(x,8.21,-4))
for i,x in enumerate([-2.08,2.08]): place('wall_lamp',f'EntranceLamp{i+1}',(x,2.37,11.65))
place('wall_lamp','RearLamp',(-8.65,3.18,-11.55),math.pi)
for p in parts.values(): p.export()
for spec in placements:
    parent=bpy.data.objects.new(spec['name'],None); bpy.context.scene.collection.objects.link(parent)
    parent.location=bl(spec['position']); parent.rotation_euler[2]=spec['yaw']
    for original in parts[spec['kind']].objects:
        obj=original.copy(); obj.data=original.data; bpy.context.scene.collection.objects.link(obj); obj.parent=parent
for p in parts.values():
    for obj in p.objects: bpy.data.objects.remove(obj,do_unlink=True)
for img in bpy.data.images:
    if img.source=='FILE': img.pack()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.color_type='MATERIAL'
            area.spaces.active.region_3d.view_distance=37
            area.spaces.active.region_3d.view_location=(0,0,3)
            area.spaces.active.region_3d.view_rotation=Vector((-.8,1,-.6)).to_track_quat('-Z','Y')
bpy.context.scene['description']='Boxing gym exterior; +Z front, matching the indoor hall. No name assigned. No transition.'
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'source'/'boxing_gym_exterior.blend'))
(BASE/'source'/'manifest.json').write_text(json.dumps({'materials':specs,'parts':{k:{'collision':p.collision} for k,p in parts.items()},'placements':placements},indent=2))
print('GYM_EXTERIOR_BLENDER_COMPLETE',len(parts),'parts',len(placements),'placements')
