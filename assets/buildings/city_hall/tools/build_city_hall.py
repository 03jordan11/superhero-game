"""Blender 5.2: original low-poly Capitol-inspired exterior, one unit = one metre.
Run: blender --background --python assets/buildings/city_hall/tools/build_city_hall.py
Props export separately; rebuilding overwrites generated assets, not the main game.
"""
import bpy
import math
import json
from pathlib import Path
from collections import defaultdict
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parents[1]
OUT = HERE.parents[2] / 'artifacts' / 'city_hall'
for folder in [HERE / 'props', OUT]:
    folder.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0
buffers = defaultdict(lambda: [[], [], [], []])
materials = {}
boxes, hulls, placements = [], [], []

def mat(key, color, texture=None, metallic=0.0):
    m = bpy.data.materials.new(key)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .78
    bs.inputs['Metallic'].default_value = metallic
    if texture:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(texture), check_existing=True)
        m.node_tree.links.new(tex.outputs['Color'], bs.inputs['Base Color'])
    materials[key] = m
    return m

def texture(name, rgba):
    h, w = rgba.shape[:2]
    im = bpy.data.images.new(name, width=w, height=h, alpha=True)
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = str(HERE / (name + '.png'))
    im.file_format = 'PNG'
    im.save()
    return im

mat('Limestone', (.68,.64,.55), HERE.parent / 'materials/limestone_warm_albedo.png')
mat('Pale trim', (.70,.69,.62))
mat('Recess stone', (.36,.37,.34))
mat('Steps and paving', (.52,.53,.49))
mat('Stair risers', (.27,.29,.27))
# Tread-only stone texture: a dark nosing strip makes every real step legible.
ty,tx = np.mgrid[:128,:256]
tread = np.ones((128,256,4), dtype=np.float32)
grain = np.random.default_rng(42128).normal(0,.006,(128,256))
tread[:,:,:3] = np.array([.43,.45,.42]) + grain[:,:,None]
tread[:12,:,:3] = [.16,.18,.17]
tread[12:17,:,:3] = [.53,.54,.50]
texture('city_hall_stair_treads',tread)
mat('Stair treads', (.43,.45,.42), HERE / 'city_hall_stair_treads.png')
mat('Lawn', (.19,.30,.105))
mat('Dark bronze', (.075,.10,.09), metallic=.3)
mat('Timber', (.27,.15,.075))
mat('Soil', (.10,.075,.04))
mat('Planting', (.24,.36,.12))
mat('Brass', (.48,.34,.12), metallic=.5)
mat('Windows', (.10,.17,.19))
# City Hall's own evening occupancy pattern, aligned to the existing 8x8 window UV atlas.
# The mask leaves the stone frame, mullions and sill black; only glass emits.
rng = np.random.default_rng(520272)
emission = np.ones((1024,1024,4), dtype=np.float32)
emission[:,:,:3] = 0
wy,wx = np.mgrid[:128,:128]
glass = (wx>12) & (wx<115) & (wy>13) & (wy<116)
glass &= (abs(wx-64)>=2) & (abs(wy-48)>=2) & (abs(wy-87)>=2)
window_atlas = np.ones((1024,1024,4), dtype=np.float32)
stone_image = bpy.data.images.load(str(HERE.parent / 'materials/limestone_warm_albedo.png'), check_existing=True)
stone_pixels = np.array(stone_image.pixels[:]).reshape(-1,4)[:,:3]
stone_color = np.median(stone_pixels,axis=0)
for row in range(8):
    for col in range(8):
        # Upper four atlas rows contain painted arches; every opening is one quad.
        arch_inside = (wy <= 88) | (((wx-64)/51)**2 + ((wy-88)/28)**2 < 1)
        opening = (wx>12) & (wx<115) & (wy>13) & (wy<116)
        if row >= 4:
            opening &= arch_inside
        cell_glass = glass & opening
        albedo = window_atlas[row*128:(row+1)*128,col*128:(col+1)*128,:3]
        albedo[:] = stone_color
        frame = (wx>7) & (wx<121) & (wy>8) & (wy<122)
        if row >= 4:
            frame &= (wy <= 88) | (((wx-64)/57)**2 + ((wy-88)/34)**2 < 1)
        albedo[frame] = [.70,.69,.62]
        albedo[opening] = [.075,.105,.115]
        albedo[cell_glass] = np.array([.085,.15,.20]) + (wy[cell_glass]/128*.025)[:,None]
        # Painted sill: highlight and a narrow shadow, with no projecting mesh.
        albedo[(wy>=5)&(wy<=11)&(wx>4)&(wx<124)] = [.72,.71,.65]
        albedo[(wy>=2)&(wy<5)&(wx>4)&(wx<124)] = [.30,.31,.28]
        if rng.random() >= .48:
            continue
        cell = emission[row*128:(row+1)*128,col*128:(col+1)*128,:3]
        color = np.array([1.0,.72,.40] if (row+col)%5 else [.82,.85,.72])
        cell[cell_glass] = color * rng.uniform(.55,.95)
        blind = wy > (91 if (row+col)%3 else 71)
        cell[cell_glass & blind] *= .60
window_albedo = texture('city_hall_windows_albedo',window_atlas)
window_tex = materials['Windows'].node_tree.nodes.new('ShaderNodeTexImage')
window_tex.image = window_albedo
materials['Windows'].node_tree.links.new(window_tex.outputs['Color'],materials['Windows'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
window_emission = texture('city_hall_windows_emission', emission)
window_nodes = materials['Windows'].node_tree
emission_node = window_nodes.nodes.new('ShaderNodeTexImage')
emission_node.image = window_emission
window_bsdf = window_nodes.nodes.get('Principled BSDF')
window_nodes.links.new(emission_node.outputs['Color'], window_bsdf.inputs['Emission Color'])
# Retain emission in the GLB; the Godot wrapper sets its intensity from the clock.
window_bsdf.inputs['Emission Strength'].default_value = 1.0
# Dense leaf mottling on a single rectangular hedge mesh; no leaf geometry.
hy,hx = np.mgrid[:256,:256]
hedge_noise = np.random.default_rng(6102).random((64,64)).repeat(4,0).repeat(4,1)
hedge = np.ones((256,256,4),dtype=np.float32)
hedge[:,:,:3] = np.array([.08,.19,.035]) + (hedge_noise*.10 + .015*np.sin(hx*.31)*np.cos(hy*.27))[:,:,None]
texture('city_hall_hedge',hedge)
mat('Hedge leaves',(.12,.24,.065),HERE/'city_hall_hedge.png')
mat('Door glass', (.065,.105,.105), metallic=.2)
# Restrained green tile pattern; authored procedurally, no photo imagery.
y,x = np.mgrid[:256,:256]
tile = ((y % 16) < 1) | (((x+(y//16%2)*8)%16)<1)
rgba = np.ones((256,256,4))
rgba[:,:,:3] = np.array([.20,.34,.17]) + (.018*np.sin(x*.23)*np.cos(y*.13)-tile*.035)[:,:,None]
texture('city_hall_green_tile', rgba)
mat('Green tile', (.20,.34,.17), HERE / 'city_hall_green_tile.png')
# One repeating balustrade motif in alpha, applied to rectangular planes.
y,x = np.mgrid[:256,:128]
t = y/255
half = 6 + 12*np.sin(t*math.pi)**2 + 4*np.cos(t*math.pi*6)**2
mask = (abs(x-64) < half[:,0,None]) | (y<20) | (y>233)
rgba = np.ones((256,128,4))
rgba[:,:,:3] = np.array([.67,.66,.58]) * (1-.18*abs(x-64)[:,:,None]/64)
rgba[:,:,3] = mask
texture('city_hall_balustrade', rgba)
m = mat('Balustrade panel', (.67,.66,.58), HERE / 'city_hall_balustrade.png')
nodes = m.node_tree.nodes
tex = next(n for n in nodes if n.type == 'TEX_IMAGE')
m.node_tree.links.new(tex.outputs['Alpha'], nodes.get('Principled BSDF').inputs['Alpha'])
m.surface_render_method = 'DITHERED'
m.use_backface_culling = False

def face(group, material, points, uv=None):
    vs,fs,uvs,ms = buffers[group]
    start = len(vs)
    vs.extend([tuple(p) for p in points])
    fs.append(tuple(range(start,start+len(points))))
    if uv is None:
        a,b,c = map(Vector, points[:3])
        normal = (b-a).cross(c-a)
        axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = [i for i in range(3) if i != axis]
        uv = [(p[axes[0]]/8,p[axes[1]]/8) for p in points]
    uvs.extend(uv)
    ms.append(material)

def solid(group, material, points, faces, collision=False):
    for f in faces:
        face(group, material, [points[i] for i in f])
    if collision:
        hulls.append({'name':group, 'points':[[p[0],p[2],-p[1]] for p in points]})

CUBE = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
def box(group, material, center, size, collision=False, top_material=None, rotation=0):
    x,y,z = center
    a,b,c = [s/2 for s in size]
    points = [(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
              (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
    if rotation:
        points = [(x+(px-x)*math.cos(rotation)-(py-y)*math.sin(rotation),
                   y+(px-x)*math.sin(rotation)+(py-y)*math.cos(rotation),pz) for px,py,pz in points]
    if top_material:
        for index,f in enumerate(CUBE):
            uv = [(0,0),(size[0]/2,0),(size[0]/2,1),(0,1)] if index==1 else None
            face(group,top_material if index==1 else material,[points[i] for i in f],uv)
    else:
        solid(group,material,points,CUBE)
    if collision:
        boxes.append({'name':group, 'center':[x,z,-y], 'size':[size[0],size[2],size[1]]})

def slope(group, material, x0,x1,y0,y1,z0,z1, collision=True):
    points=[(x0,y0,-.1),(x1,y0,-.1),(x1,y1,-.1),(x0,y1,-.1),
            (x0,y0,z0),(x1,y0,z0),(x1,y1,z1),(x0,y1,z1)]
    solid(group,material,points,CUBE,collision)

def lathe(group, material, center, rings, segments=16, collision=False):
    cx,cy = center
    points = [(cx+r*math.cos(i*math.tau/segments),cy+r*math.sin(i*math.tau/segments),z)
              for z,r in rings for i in range(segments)]
    fs=[tuple(reversed(range(segments)))]
    for j in range(len(rings)-1):
        for i in range(segments):
            k=(i+1)%segments
            fs.append((j*segments+i,j*segments+k,(j+1)*segments+k,(j+1)*segments+i))
    fs.append(tuple((len(rings)-1)*segments+i for i in range(segments)))
    solid(group,material,points,fs,collision)

def rail(group, a,b,z, height=1.15):
    ax,ay=a; bx,by=b
    length=math.hypot(bx-ax,by-ay)
    face(group,'Balustrade panel',[(ax,ay,z),(bx,by,z),(bx,by,z+height),(ax,ay,z+height)],
         [(0,0),(length/.72,0),(length/.72,1),(0,1)])
    size = (length+.15,.30,.16) if abs(ax-bx)>abs(ay-by) else (.30,length+.15,.16)
    box(group,'Pale trim',((ax+bx)/2,(ay+by)/2,z+height),size)
    box(group,'Pale trim',((ax+bx)/2,(ay+by)/2,z+.04),size)

def pediment(group, x,y,z,width,depth,height):
    points=[(x-width/2,y-depth/2,z),(x+width/2,y-depth/2,z),(x,y-depth/2,z+height),
            (x-width/2,y+depth/2,z),(x+width/2,y+depth/2,z),(x,y+depth/2,z+height)]
    solid(group,'Pale trim',points,[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],True)
    face(group,'Recess stone',[(x-width*.37,y-depth/2-.015,z+.4),
        (x+width*.37,y-depth/2-.015,z+.4),(x,y-depth/2-.015,z+height-.6)])

def window(group, p, tangent, width=2.1,height=3.5,arch=False, index=0):
    p,t = Vector(p),Vector(tangent)
    n=t.cross(Vector((0,0,1)))
    # Sill, frame and arch are all painted into one rectangular facade panel.
    outline=[(-width/2-.15,-.22),(width/2+.15,-.22),(width/2+.15,height+.20),(-width/2-.15,height+.20)]
    index=index%32+(32 if arch else 0)
    u=(index%8)/8; v=(index//8%8)/8
    face(group,'Windows',[p+t*a+Vector((0,0,b)) for a,b in outline],
         [(u+.001,v+.001),(u+.124,v+.001),(u+.124,v+.124),(u+.001,v+.124)])

# Flat interior lawns retained behind simple stone retaining walls.
box('Raised terrace','Limestone',(0,18,4),(184,94,8),True)
box('Terrace lawn','Lawn',(0,18,8.025),(184,94,.05))
for side in [-1,1]:
    box('Side garden paths','Steps and paving',(side*86,18,8.06),(4,94,.12),True)
    box('Retaining wall coping','Pale trim',(side*92,11.8,8.12),(.65,106.4,.24),True)
box('Rear garden path','Steps and paving',(0,61,8.06),(168,4,.12),True)
box('Courtyard path connection','Steps and paving',(0,58.5,8.06),(6,1,.12),True)
box('Rear retaining wall coping','Pale trim',(0,65,8.12),(184.65,.65,.24),True)
STAIR_WIDTH=42.0  # 3 m beyond each side of the 36 m entrance portico.

# Four central flights with flat planted terraces flanking each landing.
stair_y=-68.0
for flight in range(4):
    width=STAIR_WIDTH
    bottom=flight*2.0
    tier_depth=7.4 if flight<3 else 4.4
    garden_width=92-(width/2+.5)
    for side in [-1,1]:
        cx=side*(width/2+.5+garden_width/2)
        cy=stair_y+tier_depth/2
        box('Garden retaining walls','Limestone',(cx,cy,(bottom+2)/2),(garden_width,tier_depth,bottom+2),True)
        box('Front terrace lawns','Lawn',(cx,cy,bottom+2.025),(garden_width,tier_depth,.05))
        box('Garden coping','Pale trim',(cx,stair_y,bottom+2.12),(garden_width,.5,.24),True)
        box('Garden coping','Pale trim',(side*92,cy,bottom+2.12),(.65,tier_depth,.24),True)
    for step in range(10):
        z=bottom+(step+1)*.2
        box('Grand staircase','Stair risers',(0,stair_y+(step+.5)*.44,z/2),(width,.44,z),top_material='Stair treads')
    # Smooth invisible ramp collision preserves normal character movement over risers.
    pts=[(-width/2,stair_y,-.1),(width/2,stair_y,-.1),(width/2,stair_y+4.4,-.1),(-width/2,stair_y+4.4,-.1),
         (-width/2,stair_y,bottom),(width/2,stair_y,bottom),(width/2,stair_y+4.4,bottom+2),(-width/2,stair_y+4.4,bottom+2)]
    hulls.append({'name':'StairRamp%d'%flight,'points':[[p[0],p[2],-p[1]] for p in pts]})
    for side in [-1,1]:
        # Solid sloping cheek walls: no individual railing rungs.
        slope('Stair cheek walls','Pale trim',side*width/2-.4,side*width/2+.4,stair_y,stair_y+4.4,bottom+.8,bottom+2.8)
    stair_y+=4.4
    if flight<3:
        box('Stair landings','Steps and paving',(0,stair_y+1.5,(bottom+2)/2),(width,3,bottom+2),True)
        for side in [-1,1]:
            box('Landing piers','Pale trim',(side*width/2,stair_y+1.5,bottom+2.6),(1,3,1.2),True)
        stair_y+=3
box('Entrance esplanade','Limestone',(0,(-29+stair_y)/2,4),(184,-29-stair_y,8),True,top_material='Steps and paving')

# Main bar and two deep wings, leaving the rear courtyard open.
blocks=[('Central block',0,-3,32,30,33),('West link',-39,-3,46,26,29),('East link',39,-3,46,26,29),
        ('West wing',-64,18,28,78,29),('East wing',64,18,28,78,29)]
for name,x,y,w,d,h in blocks:
    box(name,'Limestone',(x,y,8+h/2),(w,d,h),True)
    for z,thick,over in [(8.3,.6,.65),(14,.45,.35),(20,.35,.25),(35.5,.55,.8),(37,.7,1.1)]:
        if z>8+h: continue
        box('Cornices','Pale trim',(x,y,z),(w+over,d+over,thick))
    top=8+h
    if name=='Central block':
        # A level cap supports the entire circular pedestal, with no roof intersection.
        box('Dome support cap','Pale trim',(x,y,41.75),(w,d,1.5),True)
        continue
    # Hipped roof with an inset flat ridge for superhero landing.
    pts=[(x-w/2,y-d/2,top),(x+w/2,y-d/2,top),(x+w/2,y+d/2,top),(x-w/2,y+d/2,top),
         (x-w/2+3,y-d/2+3,top+2),(x+w/2-3,y-d/2+3,top+2),(x+w/2-3,y+d/2-3,top+2),(x-w/2+3,y+d/2-3,top+2)]
    solid('Green roofs','Green tile',pts,CUBE,True)

# Exposed facade runs; overlaps are excluded explicitly.
idx=0
def row_windows(xvalues,y,tangent,levels=(9.5,15.5,21.5,28)):
    global idx
    for x in xvalues:
        for z in levels:
            window('Facade glazing',(x,y,z),tangent,height=3.8 if z>=21 else 3.0,arch=z>=28,index=idx)
            idx+=1
for side in [-1,1]:
    row_windows([side*x for x in [20,26,32,38,44,48]],-16.05,(1,0,0))
    row_windows([side*x for x in [53.5,59,64,69,74.5]],-21.05,(1,0,0))
    row_windows([side*x for x in [53.5,59,64,69,74.5]],57.05,(-1,0,0))
    row_windows([side*x for x in [20,26,32,38,44,48]],10.05,(-1,0,0))
    for y in range(-16,55,6):
        for z in [9.5,15.5,21.5,28]:
            window('Facade glazing',(side*78.05,y,z),(0,side,0),height=3.6,arch=z==28,index=idx); idx+=1
    for y in range(15,55,6):
        for z in [9.5,15.5,21.5,28]:
            window('Courtyard glazing',(side*49.95,y,z),(0,-side,0),height=3.6,arch=z==28,index=idx); idx+=1
    # End pavilion pediments remain; the unsupported outer-front columns are omitted.
    box('Wing portico entablature','Pale trim',(side*64,-22,34.8),(29,4,1.4),True)
    pediment('Wing pediments',side*64,-22,35.5,29,4,4.5)
    lathe('Small dome drums','Recess stone',(side*64,-1),[(39,9),(41,9)],16,True)
    lathe('Small domes','Green tile',(side*64,-1),[(41,9.4),(42.5,8.8),(44,7),(45.2,4.5),(45.8,1.1)],16,True)
    lathe('Small dome caps','Brass',(side*64,-1),[(45.8,1.1),(46.3,.7),(47,.2)],8)

# Central projecting entrance. Three arched doors at the top of the stairs.
box('Entrance base','Limestone',(0,-23,13),(32,10,10),True)
box('Entrance terrace slab','Pale trim',(0,-24,18.3),(35,12,.6),True)
for x in [-10,0,10]:
    p=Vector((x,-28.04,8.1))
    outline=[(-2,0),(2,0)] + [(math.cos(i*math.pi/8)*2,5+math.sin(i*math.pi/8)*2) for i in range(9)]
    face('Entrance doors','Door glass',[p+Vector((a,0,b)) for a,b in outline])
    box('Door frames','Dark bronze',(x,-28.10,11.1),(.09,.10,6))
    box('Door frames','Brass',(x,-28.15,10.5),(1.3,.08,.07))
    for side in [-1,1]:
        box('Door surrounds','Pale trim',(x+side*2.25,-28.10,10.6),(.35,.25,5))
    for i in range(8):
        a,b=i*math.pi/8,(i+1)*math.pi/8
        face('Door surrounds','Pale trim',[(x+math.cos(t)*r,-28.15,13.1+math.sin(t)*r) for t,r in [(a,2),(a,2.45),(b,2.45),(b,2)]])
    window('Central glazing',(x,-18.05,21),(1,0,0),3.4,10,True,idx); idx+=1
for x in [-14,-8,-3,3,8,14]:
    box('Entrance columns','Pale trim',(x,-27,19.05),(2,2,.9),True)
    lathe('Entrance columns','Pale trim',(x,-27),[(19.5,.70),(35.4,.61)],10,True)
    box('Entrance columns','Pale trim',(x,-27,35.8),(1.88,1.88,.8),True)
box('Central entablature','Pale trim',(0,-24,37),(36,12,1.6),True)
pediment('Central pediment',0,-24,37.8,36,12,5)
rail('Portico balustrade',(-15,-29),(15,-29),18.7)
row_windows([-10,-5,0,5,10],12.05,(-1,0,0),(9.5,15.5,22,29))
box('Rear door','Door glass',(0,12.08,10.6),(3.4,.08,5))

# Main dome: 24 radial facets, six curved profile bands, simple drum pilasters.
DOME_Y=-3.0
lathe('Dome pedestal','Pale trim',(0,DOME_Y),[(42.5,15),(43.2,15),(44.5,14.8)],24,True)
lathe('Dome drum','Recess stone',(0,DOME_Y),[(44.5,13.5),(57,13.5)],24,True)
for i in range(16):
    a=i*math.tau/16
    x,y=13.85*math.cos(a),DOME_Y+13.85*math.sin(a)
    box('Drum columns','Pale trim',(x,y,44.9),(1.3,1.3,.8),rotation=a+math.pi/4)
    box('Drum columns','Pale trim',(x,y,50.55),(.64,.64,10.5),rotation=a+math.pi/4)
    box('Drum columns','Pale trim',(x,y,56.2),(1.36,1.36,.8),rotation=a+math.pi/4)
    a+=math.pi/16
    window('Drum glazing',(13.54*math.cos(a),DOME_Y+13.54*math.sin(a),47),(-math.sin(a),math.cos(a),0),2.3,7.5,True,idx);idx+=1
lathe('Dome cornice','Pale trim',(0,DOME_Y),[(56.5,14),(57,15),(58,15),(58.4,14.4)],24,True)
profile=[(58.4,14.4),(62,13.9),(65.5,12.4),(68.5,10.1),(71,7),(72.4,3.3)]
lathe('Central green dome','Green tile',(0,DOME_Y),profile,24,True)
for i in range(12):
    a=i*math.tau/12
    for (z0,r0),(z1,r1) in zip(profile,profile[1:]):
        da=.012
        face('Dome ribs','Pale trim',[(r*math.cos(t),DOME_Y+r*math.sin(t),z+.035) for r,z,t in [(r0, z0,a-da),(r0,z0,a+da),(r1,z1,a+da),(r1,z1,a-da)]])
lathe('Lantern base','Pale trim',(0,DOME_Y),[(72.4,3.4),(73,3.4),(73.4,2.7)],12,True)
lathe('Lantern core','Recess stone',(0,DOME_Y),[(73.4,2),(76.8,2)],12,True)
for i in range(8):
    a=i*math.tau/8
    lathe('Lantern pillars','Pale trim',(2.3*math.cos(a),DOME_Y+2.3*math.sin(a)),[(73.4,.25),(76.8,.25)],6)
lathe('Lantern roof','Green tile',(0,DOME_Y),[(76.8,2.8),(77.4,2),(78,.35)],12,True)

# Rear lunch courtyard: open toward the garden, pavement and formal lawn beds.
box('Courtyard paving','Steps and paving',(0,35,8.075),(96,46,.15),True)
for side in [-1,1]:
    box('Courtyard lawn beds','Lawn',(side*35,35,8.18),(17,30,.20))
    for x in [side*26.3,side*43.7]:
        box('Garden edging','Pale trim',(x,35,8.2),(.3,30.5,.3))
    for y in [19.8,50.2]:
        box('Garden edging','Pale trim',(side*35,y,8.2),(17.7,.3,.3))

def objects_from_buffers(collection):
    result=[]
    for name,(vs,fs,uvs,slots) in buffers.items():
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(vs,[],fs)
        mesh.update()
        assert not mesh.validate(verbose=True), name
        ob=bpy.data.objects.new(name,mesh)
        collection.objects.link(ob)
        used=list(dict.fromkeys(slots))
        for key in used: mesh.materials.append(materials[key])
        layer=mesh.uv_layers.new(name='UVMap')
        cursor=0
        for poly,key in zip(mesh.polygons,slots):
            poly.material_index=used.index(key)
            for loop in poly.loop_indices:
                layer.data[loop].uv=uvs[cursor];cursor+=1
        result.append(ob)
    buffers.clear()
    return result

def export(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects: ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_cameras=False,export_lights=False)

architecture=bpy.data.collections.new('CITY HALL | architecture and grounds')
bpy.context.scene.collection.children.link(architecture)
asset=objects_from_buffers(architecture)
# Small inscription, low-resolution font geometry.
curve=bpy.data.curves.new('City Hall lettering','FONT')
curve.body='CITY HALL';curve.align_x='CENTER';curve.size=1.15;curve.extrude=0;curve.resolution_u=1
ob=bpy.data.objects.new('City Hall lettering',curve);architecture.objects.link(ob)
ob.location=(0,-30.02,36.6);ob.rotation_euler=(math.pi/2,0,0);curve.materials.append(materials['Dark bronze'])
bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
bpy.ops.object.convert(target='MESH');asset.append(bpy.context.object)
export(HERE/'city_hall.glb',asset)

# Reusable human-scale furniture. Each design is its own mesh with local ground origin.
props=bpy.data.collections.new('COURTYARD PROPS | independently editable')
bpy.context.scene.collection.children.link(props)
prop_sources={}
prop_stats={}
def finish_prop(kind):
    ob=objects_from_buffers(props)[0]
    prop_sources[kind]=ob
    export(HERE/'props'/(kind+'.glb'),[ob])
    ob.data.calc_loop_triangles()
    prop_stats[kind]=len(ob.data.loop_triangles)

for x in [-.78,.78]:
    box('Stone bench','Limestone',(x,0,.19),(.30,.48,.38))
box('Stone bench','Limestone',(0,0,.46),(2.4,.60,.16))
finish_prop('bench')
for x in [-.78,.78]:
    box('Stone table','Limestone',(x,0,.35),(.32,.72,.70))
box('Stone table','Limestone',(0,0,.78),(2.6,1.10,.16))
finish_prop('table')
box('Hedge row','Hedge leaves',(0,0,.65),(8,1.2,1.3))
finish_prop('hedge')

def place(kind,x,y,z=8.15,angle=0):
    placements.append({'kind':kind,'name':kind.title()+'_%02d'%sum(p['kind']==kind for p in placements),
                       'position':[x,z,-y],'rotation_y':angle})
for x in [-10,10]:
    for y in [25,36,47]:
        place('table',x,y)
        for dy in [-1.1,1.1]:
            place('bench',x,y+dy)
for side in [-1,1]:
    for y in [24,35,46]: place('bench',side*24,y,angle=-side*math.pi/2)
    for y in [-8,20,48]: place('bench',side*88,y,angle=-side*math.pi/2)
    for x in [22,46]:
        for y in [16,54]:place('hedge',side*x,y)
    for x in [23,48,74]:place('hedge',side*x,-33,z=8)
for kind,source in prop_sources.items():
    for entry in [p for p in placements if p['kind']==kind]:
        dup=bpy.data.objects.new(entry['name'],source.data);props.objects.link(dup)
        x,z,ny=entry['position'];dup.location=(x,-ny,z);dup.rotation_euler.z=entry['rotation_y']
    bpy.data.objects.remove(source,do_unlink=True)

def triangles(objects):
    total=0
    for ob in objects:ob.data.calc_loop_triangles();total+=len(ob.data.loop_triangles)
    return total
stats={'units':'metres','godot_front':'+Z','building_width_m':158,'building_depth_m':87,
       'height_m':78,'site_width_m':184.65,'site_depth_m':133.575,'base_triangles':triangles(asset),
       'base_meshes':len(asset),'prop_triangles':prop_stats,'placed_prop_count':len(placements),
       'total_triangles':triangles(asset)+sum(prop_stats[p['kind']] for p in placements),
       'collision_boxes':boxes,'collision_hulls':hulls,'props':placements,
       'dome_center_y_blender':DOME_Y,'stair_width_m':STAIR_WIDTH,
       'revision':'Textured hedge boxes and window trim, six stone dining sets, diamond dome columns; site ends at retaining walls and stair foot'}
(HERE/'city_hall_manifest.json').write_text(json.dumps(stats,indent=2))

# Separate Blender presentation rig, excluded from every GLB.
rig=bpy.data.collections.new('PREVIEW ONLY | not exported');bpy.context.scene.collection.children.link(rig)
def rig_ob(ob):
    for c in list(ob.users_collection):c.objects.unlink(ob)
    rig.objects.link(ob);return ob
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.34))
rig_ob(bpy.context.object).data.materials.append(materials['Steps and paving'])
bpy.ops.object.camera_add(location=(180,-260,150));camera=rig_ob(bpy.context.object)
camera.rotation_euler=(Vector((0,0,26))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=255;bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(0,0,180));sun=rig_ob(bpy.context.object)
sun.rotation_euler=(.45,-.5,-.45);sun.data.energy=2.5;sun.data.angle=.10
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.world.color=(.30,.30,.30);scene.view_settings.view_transform='AgX'
for im in bpy.data.images:
    if im.source=='FILE':im.pack();im.filepath=bpy.path.relpath(im.filepath,start=str(HERE))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.clip_end=4000;space.region_3d.view_location=Vector((0,0,28))
            space.region_3d.view_distance=280;space.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
            space.shading.color_type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'city_hall.blend'))
window_bsdf.inputs['Emission Strength'].default_value = 0.0
scene.render.filepath=str(OUT/'city_hall_blender_front.png')
bpy.ops.render.render(write_still=True)
print('CITY_HALL_COMPLETE '+json.dumps({k:v for k,v in stats.items() if k not in ['collision_boxes','collision_hulls','props']}))
