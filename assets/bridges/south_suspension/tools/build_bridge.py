"""Run in Blender background mode. Coordinates below are Godot metres (Y up).
Source blend retains named, editable mesh groups; export contains no preview rig.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/bridges/south_suspension'
ART = ROOT / 'artifacts/south_bridge'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for data in list(bpy.data.materials): bpy.data.materials.remove(data)

def material(name, color, metallic=0.0, texture=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.73
    p.inputs['Metallic'].default_value=metallic
    if texture:
        im=bpy.data.images.load(str(ART/texture)); im.pack()
        t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=im
        m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
    return m

RED=material('International orange steel',(.57,.075,.027),.32)
DARK=material('Recessed steel',(.24,.032,.017),.28)
CONCRETE=material('Weathered pier concrete',(.38,.37,.33))
ROAD=material('Existing city road texture',(.12,.13,.14),texture='road_20m.png')
WALK=material('Existing city sidewalk texture',(.5,.5,.5),texture='sidewalk.png')

groups={}
def group(name,mat): groups[name]={'v':[],'f':[],'uv':[],'mat':mat}
for n,m in [('RoadDeck',ROAD),('Walkways',WALK),('DeckStructure',RED),('Towers',RED),('TowerRecesses',DARK),('MainCables',RED),('Hangers',RED),('Guardrails',RED),('Foundations',CONCRETE)]: group(n,m)

def face(name,points,uv=None):
    g=groups[name]; i=len(g['v']); g['v'].extend(points)
    g['f'].append(tuple(range(i,i+len(points))))
    g['uv'].append(uv or [(0,0)]*len(points))

def beam(name,a,b,w,d=None):
    a,b=Vector(a),Vector(b); direction=(b-a).normalized()
    side=direction.cross(Vector((0,1,0)))
    if side.length<.01: side=direction.cross(Vector((0,0,1)))
    side.normalize(); up=side.cross(direction).normalized()
    side*=w/2; up*=(d or w)/2
    vs=[tuple(c+side*s+up*t) for c in [a,b] for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    for inds in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]: face(name,[vs[i] for i in inds])

def box(name,c,size):
    x,y,z=c; w,h,d=size
    beam(name,(x,y-h/2,z),(x,y+h/2,z),w,d)

def height(z):
    t=min(1.,max(0.,(200-abs(z))/95))
    return .03+15*t*t*(3-2*t)

# Continuous closed deck and sidewalks follow the approach grade.
steps=[-200+i*10 for i in range(41)]
def ribbon(name,x0,x1,offset,depth,road_uv=False):
    for a,b in zip(steps,steps[1:]):
        oa=offset*min(1.,(200-abs(a))/10) if name=='Walkways' else offset
        ob=offset*min(1.,(200-abs(b))/10) if name=='Walkways' else offset
        ya,yb=height(a)+oa,height(b)+ob
        top=[(x0,ya,a),(x0,yb,b),(x1,yb,b),(x1,ya,a)]
        uv=[(0,(a+200)/8),(0,(b+200)/8),(1,(b+200)/8),(1,(a+200)/8)] if road_uv else [(p[0]/4,p[2]/4) for p in top]
        face(name,top,uv)
        face(name,[(x0,ya-depth,a),(x1,ya-depth,a),(x1,yb-depth,b),(x0,yb-depth,b)])
        face(name,[(x0,ya,a),(x0,ya-depth,a),(x0,yb-depth,b),(x0,yb,b)])
        face(name,[(x1,ya,a),(x1,yb,b),(x1,yb-depth,b),(x1,ya-depth,a)])
    for z in [-200,200]:
        y=height(z)+(0 if name=='Walkways' else offset)
        pts=[(x0,y,z),(x1,y,z),(x1,y-depth,z),(x0,y-depth,z)]
        face(name,pts if z<0 else pts[::-1])

ribbon('RoadDeck',-10,10,0,.55,True)
for s in [-1,1]:
    ribbon('Walkways',min(10*s,14*s),max(10*s,14*s),.15,.7)
    # The lower side trusses are intentionally omitted. Each hanger instead
    # terminates in a short bracket embedded in the solid walkway edge.
    # Low continuous pedestrian rails with 10 m stanchions; two horizontal rails.
    for offset in [.75,1.55]:
        for a,b in zip(steps[::2],steps[2::2]):
            beam('Guardrails',(s*13.75,height(a)+offset,a),(s*13.75,height(b)+offset,b),.14)
    for z in range(-200,201,10):
        rail_a=min(180,math.floor(z/20)*20)
        rail_height=height(rail_a)+(height(rail_a+20)-height(rail_a))*(z-rail_a)/20
        foot=height(z)+.15*min(1.,(200-abs(z))/10)-.03
        beam('Guardrails',(s*13.75,foot,z),(s*13.75,max(height(z),rail_height)+1.62,z),.15)
    # Raised curb separates the road from the walkway, without blocking entry.

# Two Art Deco portal towers: stepped columns, recessed flutes and four portals.
for z in [-112,112]:
    for s in [-1,1]:
        x=s*16.0
        box('Foundations',(x,-8,z),(9,12,12))
        box('Foundations',(x,-1.6,z),(7.6,1.0,10.5))
        for lo,hi,w,d in [(-1,19,4.5,6),(19,43,4.1,5.4),(43,66,3.7,4.8),(66,89,3.2,4.3)]:
            box('Towers',(x,(lo+hi)/2,z),(w,hi-lo,d))
            for side in [-1,1]:
                # Dark face recess with orange edge ribs; silhouette stays simple.
                rz=z+side*(d/2+.04)
                face('TowerRecesses',[(x-w*.245,lo+.4,rz),(x+w*.245,lo+.4,rz),(x+w*.245,hi-.4,rz),(x-w*.245,hi-.4,rz)])
                for rib in [-1,1]:
                    box('Towers',(x+rib*w*.36,(lo+hi)/2,z+side*d/2),(.23,hi-lo,.24))
        for y,w,d in [(19,4.9,6.5),(43,4.5,5.9),(66,4.1,5.3),(89,3.9,4.9)]:
            box('Towers',(x,y,z),(w,1.15,d))
        box('Towers',(x,90.1,z),(3.2,1.1,4.2))
        box('Towers',(x,91.1,z),(2.5,.9,3.5))
        box('Towers',(x,92.5,z),(1.25,2,1.5))
    for y in [33,51,70,87]:
        box('Towers',(0,y,z),(29,2.8,3.8))
        for side in [-1,1]:
            rz=z+side*1.96
            face('TowerRecesses',[(-12.5,y-.85,rz),(12.5,y-.85,rz),(12.5,y+.85,rz),(-12.5,y+.85,rz)])
        # Short angled haunches frame the rectangular openings.
        for s in [-1,1]: beam('Towers',(s*13.8,y-4,z),(s*10.8,y-1,z),1.15,2.7)
    box('DeckStructure',(0,height(z)-1.05,z),(33,1.5,5.0))

def cable_y(z):
    if abs(z)<=112: return 29+62*(z/112)**2
    t=(abs(z)-112)/80
    return 91*(1-t)+2.7*t-17*t*(1-t)

def tube(name,pts,radius,sides=6):
    # Shared ring positions avoid faceted corner gaps; smooth shaded on import.
    rings=[]
    for i,p in enumerate(pts):
        tangent=Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(0,i-1)])
        tangent.normalize(); u=Vector((1,0,0)); v=tangent.cross(u).normalized()
        rings.append([tuple(Vector(p)+radius*(math.cos(j*math.tau/sides)*u+math.sin(j*math.tau/sides)*v)) for j in range(sides)])
    for a,b in zip(rings,rings[1:]):
        for j in range(sides): face(name,[a[j],a[(j+1)%sides],b[(j+1)%sides],b[j]])
    face(name,rings[0][::-1]); face(name,rings[-1])

for s in [-1,1]:
    x=s*16
    zs=sorted(set([-192+i*8 for i in range(49)]+[-112,112]))
    tube('MainCables',[(x,cable_y(z),z) for z in zs],.36)
    for z in range(-180,181,10):
        if abs(abs(z)-112)<4: continue
        tube('Hangers',[(x,height(z)-.30,z),(x,cable_y(z),z)],.09,4)
        beam('DeckStructure',(s*13.8,height(z)-.25,z),(s*16.2,height(z)-.25,z),.42,.50)
    for z in [-192,192]:
        box('Foundations',(x,.4,z),(5.2,3.8,8))
        box('Towers',(x,2.6,z),(2.6,.65,5.0))

objects=[]
for name,g in groups.items():
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([(x,-z,y) for x,y,z in g['v']],[],g['f']); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    mesh.materials.append(g['mat']); objects.append(obj)
    uv=mesh.uv_layers.new(name='UVMap')
    for poly,coords in zip(mesh.polygons,g['uv']):
        for loop,value in zip(poly.loop_indices,coords): uv.data[loop].uv=value
    # Recalculate outward normals for all closed parts.
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.00001)
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)

triangles={}
for obj in objects:
    obj.data.calc_loop_triangles(); triangles[obj.name]=len(obj.data.loop_triangles)
assert sum(triangles.values()) < 9900, triangles
(OUT/'blender_geometry.json').write_text(json.dumps({'triangles':triangles,'total':sum(triangles.values()),'length_m':400,'road_width_m':20,'tower_height_m':93.5},indent=2))
(OUT/'deck_profile.json').write_text(json.dumps([[z,height(z),.15*min(1.,(200-abs(z))/10)] for z in steps]))
bpy.ops.object.select_all(action='DESELECT')
for obj in objects: obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'south_suspension.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)

# Preview rig is saved in Blender only, excluded from the exported model.
rig=bpy.data.collections.new('Preview rig - not exported'); bpy.context.scene.collection.children.link(rig)
def move_to_rig(obj):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    rig.objects.link(obj)
def cv(p): x,y,z=p; return Vector((x,-z,y))
bpy.ops.object.camera_add(location=cv((305,205,340)))
cam=bpy.context.object; cam.name='PreviewCamera'; move_to_rig(cam)
cam.rotation_euler=(cv((0,24,0))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO';cam.data.ortho_scale=510
bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='SUN',location=(0,0,200)); sun=bpy.context.object; move_to_rig(sun); sun.rotation_euler=(.45,-.5,-.45);sun.data.energy=3
scene=bpy.context.scene; scene.render.engine='CYCLES';scene.cycles.samples=24
scene.world.color=(.28,.32,.4)
scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'south_suspension.blend'))
scene.render.filepath=str(ART/'blender_bridge.png');bpy.ops.render.render(write_still=True)
print('BRIDGE_BLENDER_TRIANGLES',sum(triangles.values()),triangles)
