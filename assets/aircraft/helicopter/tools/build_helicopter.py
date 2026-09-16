"""Author a utility helicopter in Blender; export GLB and Godot surface data.
Coordinates in helpers are Godot meters: +Y up, -Z forward, +X starboard.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/aircraft/helicopter'
WORK = ROOT / 'artifacts/helicopter'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
def bv(p): return Vector((p[0], -p[2], p[1]))
def gv(p): return [p.x, p.z, -p.y]

palettes = {
 'forest_cream': ['c4bb94','234943','d8b35b'],
 'rescue_red': ['e0dfd3','ad302d','e9b850'],
 'coastal_blue': ['d9dcd6','285c83','64b3be'],
 'charcoal_orange': ['4c5357','252e34','d98439'],
}
def rgb(h): return [int(h[i:i+2],16)/255 for i in (0,2,4)]
images={}
for name, colors in palettes.items():
    colors += ['647078','203f50','20272b','e2e2d7','ac2725','237847','a2afba','727267','363d3b','d9bf7e','56656b','344956','22292c']
    image=bpy.data.images.new(name,512,512,alpha=True)
    pixels=[]
    for y in range(512):
        for x in range(512):
            tile=x//128+(y//128)*4; u=x%128; v=y%128
            color=rgb(colors[tile]); factor=1.0
            if tile in (0,1):
                factor=.96+.04*v/127
                if v in (9,118): factor*=.87
                if u in (10,117) and v in (12,115): factor*=.6
            if tile==4:
                factor=.74+.35*v/127
                if 30 < u+v//2 < 40: factor*=1.15
            pixels.extend([min(c*factor,1) for c in color]+[1])
    image.pixels.foreach_set(pixels); image.filepath_raw=str(OUT/'textures'/f'{name}.png'); image.file_format='PNG'; image.save(); images[name]=image

paint=bpy.data.materials.new('Livery'); paint.use_nodes=True
tex=paint.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=images['forest_cream']
paint.node_tree.links.new(tex.outputs['Color'],paint.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
paint.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.65
parts={'Body':[], 'MainRotor':[], 'TailRotor':[]}
pivots={'Body':(0,0,0),'MainRotor':(0,4.13,-.1),'TailRotor':(-.43,3.56,7.58)}

def mesh(name, verts, faces, tile=0, part='Body'):
    if len(faces)==1:
        normal=(Vector(verts[1])-Vector(verts[0])).cross(Vector(verts[2])-Vector(verts[0]))
        desired=Vector((0,1,-1)) if name=='Windshield' else Vector((1 if verts[0][0]>0 else -1,0,0))
        if normal.dot(desired)<0: faces=[tuple(reversed(faces[0]))]
    data=bpy.data.meshes.new(name); data.from_pydata([bv(v) for v in verts],[],faces); data.update()
    ob=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(ob); data.materials.append(paint)
    uv=data.uv_layers.new(name='LiveryUV')
    for poly in data.polygons:
        n=len(poly.loop_indices)
        for j,li in enumerate(poly.loop_indices):
            # Every panel uses an inset tile, leaving generous filtering gutters.
            coords=[(.08,.08),(.92,.08),(.92,.92),(.08,.92)]
            u,v=coords[j%4] if n==4 else (.5+.42*math.cos(j*math.tau/n),.5+.42*math.sin(j*math.tau/n))
            uv.data[li].uv=((tile%4+u)/4,(tile//4+v)/4)
    bpy.context.view_layer.objects.active=ob; ob.select_set(True)
    # Open glass/paint panels already have explicit outward winding. Blender's
    # volume-based recalculation can flip an isolated pane inward and hide it.
    if len(faces)>1:
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    ob.select_set(False)
    parts[part].append(ob); return ob

def box(name,center,size,tile=0,part='Body'):
    v=[(center[0]+sx*size[0]/2,center[1]+sy*size[1]/2,center[2]+sz*size[2]/2) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],tile,part)

def rod(name,a,b,r,tile=3,part='Body',sides=8,r2=None):
    axis=(Vector(b)-Vector(a)).normalized(); e=axis.cross(Vector((0,1,0)))
    if e.length<.1: e=axis.cross(Vector((1,0,0)))
    e.normalize(); f=axis.cross(e); v=[]
    for p,radius in [(a,r),(b,r if r2 is None else r2)]:
        for i in range(sides): v.append(Vector(p)+(e*math.cos(i*math.tau/sides)+f*math.sin(i*math.tau/sides))*radius)
    faces=[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    return mesh(name,v,faces,tile,part)

def ring(w,bot,top,z):
    return [(-w*.7,bot,z),(w*.7,bot,z),(w,bot+.25,z),(w,top-.27,z),(w*.72,top,z),(-w*.72,top,z),(-w,top-.27,z),(-w,bot+.25,z)]
rings=[ring(.65,1.57,2.2,-3.65),ring(1.2,1.2,3.14,-2.6),ring(1.2,1.2,3.14,1.05),ring(.77,1.52,2.94,2.15),ring(.42,2.03,2.73,2.7)]
verts=sum(rings,[]); faces=[tuple(reversed(range(8))),tuple(range(32,40))]
faces += [(k*8+i,k*8+(i+1)%8,(k+1)*8+(i+1)%8,(k+1)*8+i) for k in range(4) for i in range(8)]
mesh('Cabin_shell',verts,faces,0)
# Forward glazing follows the upper nose facets, inset for painted structural frames.
def interpolate(a,b,t): return Vector(a).lerp(Vector(b),t)
for seg in [3,4,5]:
    a,b,c,d=map(Vector,[rings[0][seg],rings[0][seg+1],rings[1][seg+1],rings[1][seg]])
    strips=2 if seg==4 else 1
    for j in range(strips):
        u0=(j+.055)/strips;u1=(j+.945)/strips
        q=[]
        for u,v in [(u0,.19),(u1,.19),(u1,.91),(u0,.91)]:
            p=a.lerp(b,u).lerp(d.lerp(c,u),v);p.y+=.015;p.z-=.015;q.append(p)
        mesh('Windshield',q,[(0,1,2,3)],4)

for s in [-1,1]:
    x=s*1.213
    for z0,z1 in [(-2.48,-1.35),(-1.15,-.05),(.13,.91)]:
        mesh('Side_window',[(x,2.04,z0),(x,2.04,z1),(x,2.81,z1),(x,2.81,z0)],[(0,1,2,3)],4)
    # Painted livery stripe and lower side; door outlines remain texture/very thin trim.
    mesh('Lower_livery',[(x,1.49,-2.5),(x,1.49,1.02),(x,1.88,1.02),(x,1.88,-2.5)],[(0,1,2,3)],1)
    mesh('Accent_stripe',[(x+s*.003,1.86,-2.5),(x+s*.003,1.86,1.02),(x+s*.003,1.95,1.02),(x+s*.003,1.95,-2.5)],[(0,1,2,3)],2)
    for z in [-1.25,1.0]: rod('Door_seam',(x+s*.006,1.48,z),(x+s*.006,2.86,z),.013,5,sides=4)
    box('Door_handle',(x+s*.04,1.99,-.86),(.035,.045,.21),3)
    rod('Sliding_door_rail',(x+s*.03,2.94,-1.22),(x+s*.03,2.94,1.48),.025,3,sides=6)
    # Skid tubes and sloped supports.
    rod('Skid',(s*1.48,.18,-3.1),(s*1.48,.18,2.0),.085,3,sides=10)
    rod('Skid_upturned_toe',(s*1.48,.18,-3.1),(s*1.48,.37,-3.56),.085,3,sides=10)
    for z in [-1.8,1.05]: rod('Landing_strut',(s*.86,1.28,z),(s*1.48,.26,z),.065,3)
    rod('Cabin_step',(s*1.49,.89,-.95),(s*1.49,.89,.82),.045,3)
    for z in [-.8,.65]: rod('Step_bracket',(s*1.18,1.22,z),(s*1.49,.89,z),.035,3,sides=6)
    box('Navigation_lens_mount',(s*1.265,2.0,.98),(.14,.12,.21),5)
    box('Navigation_lens',(s*1.343,2.0,.98),(.035,.075,.12),7 if s<0 else 8)

# Tail boom: tapered octagonal structure, with a colored dorsal panel.
rod('Tail_boom',(0,2.38,2.02),(0,3.13,7.7),.47,1,sides=8,r2=.135)
rod('Tail_accent',(0,2.14,2.62),(0,3.01,7.64),.07,2,sides=6,r2=.027)
# Thin airfoil-like fins, made as closed wedges.
def prism(name,outline,thickness,tile=1,axis=0):
    v=[]
    for offset in [-thickness/2,thickness/2]:
        for p in outline:
            q=list(p);q[axis]+=offset;v.append(q)
    n=len(outline);f=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,v,f,tile)
prism('Vertical_tail',[(0,3.04,6.94),(0,4.72,7.02),(0,4.48,7.63),(0,2.79,8.15)],.15)
prism('Tail_fin_accent',[(-.081,3.87,7.09),(-.081,4.42,7.10),(-.081,4.26,7.56),(-.081,3.82,7.67)],.009,2)
prism('Horizontal_stabilizer',[(-1.6,2.92,5.65),(1.6,2.92,5.65),(1.5,2.92,6.25),(-1.5,2.92,6.25)],.09,1,axis=1)
rod('Tail_rotor_shaft',(-.48,3.56,7.58),(.17,3.56,7.58),.095,3)
# Engine cowling and functional-looking vents above the cabin.
box('Transmission_base',(0,3.22,-.02),(1.24,.32,1.62),1)
rod('Engine_cowling',(0,3.38,.35),(0,3.25,1.68),.5,0,sides=10,r2=.37)
for s in [-1,1]:
    rod('Exhaust',(s*.44,3.35,1.12),(s*.51,3.37,1.98),.19,3,sides=10,r2=.22)
    rod('Exhaust_dark_outlet',(s*.51,3.37,1.982),(s*.511,3.371,2.003),.168,5,sides=10)
    for z in [.1,.27,.44,.61]: box('Intake_louver',(s*.61,3.34,z),(.022,.16,.07),5)
rod('Rotor_mast',(0,3.31,-.1),(0,4.16,-.1),.11,3,sides=12)
rod('Swashplate',(0,3.69,-.1),(0,3.79,-.1),.28,3,sides=12)
for s in [-1,1]: rod('Pitch_link',(s*.22,3.76,-.1),(s*.32,4.11,-.1),.028,3,sides=6)
rod('Nose_sensor',(0,1.54,-3.49),(0,1.27,-3.49),.1,5)
rod('Roof_antenna',(.37,3.1,-1.5),(.37,3.62,-1.35),.022,5,sides=6)
rod('Tail_antenna',(0,3.47,5.83),(0,3.87,5.69),.016,5,sides=5)

# Rotor vertices authored around their real pivots. Both assemblies stay separate.
rod('Main_hub',(0,4.06,-.1),(0,4.23,-.1),.28,3,'MainRotor',12)
for s in [-1,1]:
    rod('Blade_grip',(s*.1,4.15,-.1),(s*.85,4.15,-.1),.065,3,'MainRotor')
    v=[(s*.68,4.17,-.36),(s*6.9,4.14,-.27),(s*6.9,4.1,.09),(s*.68,4.12,.13)]
    # Solid blade thickness, no alpha cards.
    w=v+[(x,y-.035,z) for x,y,z in v]
    mesh('Main_blade',w,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],5,'MainRotor')
    box('Main_tip',(s*6.7,4.148,-.085),(.33,.018,.355),6,'MainRotor')
rod('Tail_hub',(-.52,3.56,7.58),(-.34,3.56,7.58),.15,3,'TailRotor',10)
for s in [-1,1]:
    box('Tail_blade',(-.5,3.56+s*.67,7.58),(.045,1.22,.18),5,'TailRotor')
    box('Tail_tip',(-.527,3.56+s*1.18,7.58),(.008,.18,.18),6,'TailRotor')

result={'parts':{},'pivots':pivots,'liveries':list(palettes)}
collision=[]
for ob in parts['Body']:
    if ob.name.startswith(('Cabin_shell','Tail_boom','Vertical_tail','Horizontal_stabilizer','Skid','Landing_strut','Engine_cowling','Transmission_base')):
        collision.append([gv(ob.matrix_world @ v.co) for v in ob.data.vertices])
(WORK/'collision_data.json').write_text(json.dumps(collision),encoding='utf-8')
for name, objects in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=name
    bpy.context.scene.cursor.location=bv(pivots[name]);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    ob.data.calc_loop_triangles();uv=ob.data.uv_layers.active.data
    rows={'vertices':[],'normals':[],'uv':[]}
    # Godot uses clockwise front faces, hence reversed loop order.
    for tri in ob.data.loop_triangles:
        for li in reversed(tri.loops):
            loop=ob.data.loops[li];rows['vertices'].append(gv(ob.data.vertices[loop.vertex_index].co));rows['normals'].append(gv(tri.normal));rows['uv'].append([uv[li].uv.x,1-uv[li].uv.y])
    result['parts'][name]=rows
    print(name,len(ob.data.loop_triangles),'triangles',flush=True)

# Solid parked collision source, kept separate from render export.
result['colliders']=[{'position':[0,2.13,-.55],'size':[2.38,1.7,4.1]}, {'position':[0,1.95,-3.0],'size':[1.35,.75,1.25]}]
WORK.mkdir(parents=True,exist_ok=True)
(WORK/'mesh_data.json').write_text(json.dumps(result),encoding='utf-8')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'helicopter.glb'),export_format='GLB',use_selection=True,export_yup=True)
for im in images.values(): im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'blender/helicopter.blend'))
print('HELICOPTER_BLENDER_COMPLETE',flush=True)
