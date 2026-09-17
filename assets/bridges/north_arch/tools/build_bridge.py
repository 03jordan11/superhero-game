"""Blender authoring for the northern tied arch. All design coordinates are Y-up metres.
Run from the repository root: blender --background --python <this file>.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'assets/bridges/north_arch'
ART=ROOT/'artifacts/city_hall_bridge'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name,color,metal=0,texture=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.6
    if texture:
        image=bpy.data.images.load(str(ART/texture)); image.pack()
        tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    return m
STEEL=mat('International orange steel',(.57,.075,.027),.32)
STEEL.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.73
DARK=mat('Graphite railings and hangers',(.065,.095,.11),.4)
STONE=mat('Warm concrete abutments',(.44,.42,.37))
ROAD=mat('Existing city avenue',(.16,.17,.18),texture='road_28m.png')
WALK=mat('Existing city paving',(.5,.5,.5),texture='sidewalk.png')
groups={n:{'v':[],'f':[],'uv':[],'mat':m} for n,m in [('RoadDeck',ROAD),('Walkways',WALK),('Arches',STEEL),('TieBeams',STEEL),('Hangers',DARK),('Guardrails',DARK),('Supports',STONE)]}
def face(name,points,uv=None):
    g=groups[name]; start=len(g['v']); g['v'].extend(points)
    g['f'].append(tuple(range(start,start+len(points)))); g['uv'].append(uv or [(0,0)]*len(points))
def beam(name,a,b,w,d=None):
    a,b=Vector(a),Vector(b); v=(b-a).normalized(); u=v.cross(Vector((0,1,0)))
    if u.length<.01: u=v.cross(Vector((0,0,1)))
    u.normalize(); t=u.cross(v).normalized(); u*=w/2;t*=(d or w)/2
    pts=[tuple(c+u*i+t*j) for c in [a,b] for i,j in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    for ids in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:face(name,[pts[i] for i in ids])
def box(name,c,size):
    x,y,z=c;w,h,d=size;beam(name,(x,y-h/2,z),(x,y+h/2,z),w,d)
def height(z):return .03
def kerb(z):return 0.0 # Flush paving lets river pedestrians cross without a curb step.
ZS=[-79+i*158/16 for i in range(17)]
def ribbon(name,x0,x1,offset,depth):
    for a,b in zip(ZS,ZS[1:]):
        ya,yb=height(a)+(kerb(a) if offset else 0),height(b)+(kerb(b) if offset else 0)
        pts=[(x0,ya,a),(x0,yb,b),(x1,yb,b),(x1,ya,a)]
        uv=[(0,(a+79)/8),(0,(b+79)/8),(1,(b+79)/8),(1,(a+79)/8)] if name=='RoadDeck' else [(p[0]/4,p[2]/4) for p in pts]
        face(name,pts,uv)
        face(name,[(x0,ya-depth,a),(x1,ya-depth,a),(x1,yb-depth,b),(x0,yb-depth,b)])
        face(name,[(x0,ya,a),(x0,ya-depth,a),(x0,yb-depth,b),(x0,yb,b)])
        face(name,[(x1,ya,a),(x1,yb,b),(x1,yb-depth,b),(x1,ya-depth,a)])
    for z in [-79,79]:
        y=height(z); pts=[(x0,y,z),(x1,y,z),(x1,y-depth,z),(x0,y-depth,z)]
        face(name,pts if z<0 else pts[::-1])
def strip(name,points,width,depth):
    # Continuous box section: four faces per span and only two end caps.
    rings=[]
    for p in points:
        x,y,z=p
        rings.append([(x-width/2,y-depth/2,z),(x+width/2,y-depth/2,z),(x+width/2,y+depth/2,z),(x-width/2,y+depth/2,z)])
    for a,b in zip(rings,rings[1:]):
        for j in range(4):face(name,[a[j],a[(j+1)%4],b[(j+1)%4],b[j]])
    face(name,rings[0][::-1]);face(name,rings[-1])
ribbon('RoadDeck',-10,10,False,1.1)
# Openings across both promenades preserve at-grade walking access.
# Local z maps to world x-195; shore paths curve across the bridge footprint.
rail_ranges=[(-79,-73),(-49,41),(67,79)]
for s in [-1,1]:
    ribbon('Walkways',min(s*10,s*14),max(s*10,s*14),True,1.25)
    for a,b in rail_ranges:
        for offset in [.70,1.45]:
            strip('Guardrails',[(s*13.7,height(z)+offset,z) for z in [a,b]],.10,.12)
        steps=max(1,math.ceil((b-a)/8))
        for i in range(steps+1):
            z=a+(b-a)*i/steps
            beam('Guardrails',(s*13.7,height(z)+kerb(z)-.03,z),(s*13.7,height(z)+1.51,z),.12)
# 152 m arch. End abutments sit outside both river paths.
def arch_y(z):return .8+22*(1-(z/76)**2)
arch_stations=[-76+i*152/24 for i in range(25)]
for s in [-1,1]:
    strip('Arches',[(s*14.5,arch_y(z),z) for z in arch_stations],1.0,1.3)
    box('TieBeams',(s*14.5,-.55,0),(1.0,.9,153))
    for z in [-76+i*152/12 for i in range(1,12)]:
        # No hanging members across the promenade entrances.
        if -73<z<-49 or 41<z<67:continue
        beam('Hangers',(s*14.5,-.55,z),(s*14.5,arch_y(z),z),.11)
    for z in [-76,76]:box('TieBeams',(s*14.5,.25,z),(1.7,1.4,2.8))
for z in [-38,0,38]:beam('Arches',(-14.5,arch_y(z),z),(14.5,arch_y(z),z),.65)
for z in [-76,76]:
    box('Supports',(0,-1.2,z),(30,2.0,3.0))
    box('Supports',(0,-2.4,z),(32,1.0,5.0))

objects=[];counts={}
for name,g in groups.items():
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([(x,-z,y) for x,y,z in g['v']],[],g['f']);mesh.update()
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);mesh.materials.append(g['mat']);objects.append(ob)
    uv=mesh.uv_layers.new(name='UVMap')
    for p,coords in zip(mesh.polygons,g['uv']):
        for idx,coord in zip(p.loop_indices,coords):uv.data[idx].uv=coord
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.00001);bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');ob.select_set(False)
    mesh.calc_loop_triangles();counts[name]=len(mesh.loop_triangles)
assert sum(counts.values())<2500,counts
(OUT/'blender_geometry.json').write_text(json.dumps({'meshes':counts,'total':sum(counts.values()),'length_m':158,'width_m':20,'promenade_connection':'at grade with railing openings'},indent=2))
(OUT/'deck_profile.json').write_text(json.dumps([[z,height(z),kerb(z)] for z in ZS]))
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'north_arch.glb'),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
# This rig is saved in .blend only and is excluded from geometry/export counts.
rig=bpy.data.collections.new('Preview rig - not exported');bpy.context.scene.collection.children.link(rig)
def to_rig(ob):
    for c in list(ob.users_collection):c.objects.unlink(ob)
    rig.objects.link(ob)
def cv(v):x,y,z=v;return Vector((x,-z,y))
bpy.ops.object.camera_add(location=cv((235,150,270)));cam=bpy.context.object;to_rig(cam)
cam.rotation_euler=(cv((0,8,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=385;bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='SUN');sun=bpy.context.object;to_rig(sun);sun.rotation_euler=(.45,-.5,-.4);sun.data.energy=3
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world.color=(.3,.34,.4)
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'north_arch.blend'))
# Preview camera is available for optional rendering in Blender.
print('NORTH_BLENDER_TRIANGLES',sum(counts.values()),counts)
