"""Blender source generator. Coordinates below are Godot x/y(up)/z.

blender --background --python <this file>
Builds all 24 static configurations from one model definition and an editable
Blender showcase. Slots remain open above every ramp, including the top deck.
"""
import bpy
import json
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source'
SOURCE.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'

def material(name, color, texture=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .85
    if texture:
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(ROOT / 'textures' / texture), check_existing=True)
        mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return mat

MATS = {
    'Concrete': material('GarageConcrete', (.55,.56,.54), 'concrete.png'),
    'Asphalt': material('GarageAsphalt', (.20,.22,.23), 'asphalt.png'),
    'Paint': material('GaragePaint', (.86,.85,.76)),
    'Teal': material('GarageTeal', (.035,.18,.21)),
    'Yellow': material('GarageYellow', (.87,.57,.13)),
    'Signs': material('GarageSigns', (.86,.85,.76)),
}

def blender(v):
    return (v[0], -v[2], v[1])

class Garage:
    def __init__(self, width, floors, label):
        self.width, self.floors, self.label = width, floors, label
        self.buffers = {key: [[], [], []] for key in MATS}
        self.collisions = []
        self.objects = []

    def face(self, points, mat, uv=None):
        verts, faces, uvs = self.buffers[mat]
        start = len(verts)
        verts.extend(blender(p) for p in points)
        # Godot coordinates and Blender mapping both preserve handedness.
        faces.append(tuple(range(start, start+len(points))))
        if uv is None:
            a,b,c = points[:3]
            normal = ((b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]),
                      (b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2]),
                      (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))
            axis = max(range(3), key=lambda i:abs(normal[i]))
            axes = [i for i in range(3) if i != axis]
            uv = [(p[axes[0]]/4, p[axes[1]]/4) for p in points]
        uvs.extend(uv)

    def box(self, center, size, mat='Concrete', solid=True, slope=0):
        x,y,z = center
        a,b,c = (v/2 for v in size)
        pts = [(x+dx, y+dy+slope*dz, z+dz) for dx,dy,dz in
               [(-a,-b,-c),(a,-b,-c),(a,-b,c),(-a,-b,c),(-a,b,-c),(a,b,-c),(a,b,c),(-a,b,c)]]
        for face in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2)]:
            self.face([pts[i] for i in face], mat)
        if solid:
            if slope:
                self.collisions.append({'points': pts})
            else:
                self.collisions.append({'center':center, 'size':size})

    def plane(self, x1,x2,z1,z2,y,mat='Asphalt', slope=0):
        self.face([(x1,y+slope*z1,z1),(x1,y+slope*z2,z2),
                   (x2,y+slope*z2,z2),(x2,y+slope*z1,z1)], mat)

    def wall_arrow(self, x, upward):
        # Painted on the concrete parapet above the entrance, facing local -Z.
        direction = 1 if upward else -1
        for polygon in [[(-.11,-.36),(-.11,.04),(.11,.04),(.11,-.36)],
                        [(-.34,.04),(0,.36),(.34,.04)]]:
            points = [(x+dx,4.1+direction*dy,-27.025) for dx,dy in polygon]
            self.face(points if upward else points[::-1], 'Signs')

    def build(self):
        w,n = self.width,self.floors
        left,right = -w/2,w/2
        split = right-8
        islands = (w-32)//12
        gap = (w-20-islands*10)/(islands+1)
        aisle = left+6+gap/2
        self.entrance_x = aisle
        island_starts = [left+6+gap+i*(10+gap) for i in range(islands)]
        # Leave the entire ramp-side row unmarked for circulation and landings.
        bands = [(left+1,left+6)]
        for start in island_starts:
            bands.extend([(start,start+5),(start+5,start+10)])
        top = (n-1)*3.6
        # Continuous columns: the same footprint and ramp clearance at all heights.
        for x in [left+.4, split-.4, right-.4]:
            for z in [-25,-12,0,12,25]:
                if x > split and abs(z) < 20:
                    continue  # Keep outer ramp lane completely clear.
                self.box((x,top/2,z),(.65,top,.65))
                self.box((x,.8,z),(.67,1.6,.67),'Teal',False)
        for start in island_starts:
            for z in [-19.5,-7.5,4.5,16.5]:
                self.box((start+5,top/2,z),(.65,top,.65))
                self.box((start+5,.8,z),(.67,1.6,.67),'Teal',False)
        for level in range(n):
            y = level*3.6
            # The eight-metre side bay is intentionally open along the ramp run.
            plates = [(left,split,-27,27),(split,right,-27,-15),(split,right,15,27)]
            if level == 0:
                plates = [(left,right,-27,27)]
            for x1,x2,z1,z2 in plates:
                self.box(((x1+x2)/2,y-.16,(z1+z2)/2),(x2-x1,.32,z2-z1))
                self.plane(x1+.015,x2-.015,z1+.015,z2-.015,y+.008)
            # Strong horizontal slab bands and open sides, inspired by reference photos.
            self.box((left+.14,y+.5,0),(.28,1,54))
            self.box((right-.14,y+.5,0),(.28,1,54))
            self.box((0,y+.5,26.86),(w,1,.28))
            self.box((left+.15,y+1.1,0),(.13,.12,54),'Teal')
            self.box((right-.15,y+1.1,0),(.13,.12,54),'Teal')
            self.box((0,y+1.1,26.85),(w,.12,.13),'Teal')
            # Open entrance at ground level. Upper decks have full edge protection.
            fronts = [(left,aisle-4),(aisle+4,right)] if level==0 else [(left,right)]
            for x1,x2 in fronts:
                self.box(((x1+x2)/2,y+.5,-26.86),(x2-x1,1,.28))
                self.box(((x1+x2)/2,y+1.1,-26.85),(x2-x1,.12,.13),'Teal')
            # Stall markings occupy edge rows; broad centre aisle links both ramp landings.
            for z in range(-21,22,3):
                for x1,x2 in bands:
                    self.plane(x1,x2,z-.045,z+.045,y+.022,'Paint')
            for x in [left+6] + [start+5 for start in island_starts]:
                self.plane(x-.045,x+.045,-21,21,y+.022,'Paint')
            # Guard the inside edge of the slot, with open landings at either end.
            if level > 0:
                self.box((split-.12,y+.52,0),(.24,1.04,30))
                self.box((split-.12,y+1.1,0),(.14,.12,30),'Teal')
            if level < n-1:
                # Every ramp rises in +Z, parallel to the one above: 12% grade,
                # 3.28m vertical clearance, both ends flush with the parking decks.
                rx = (split+right)/2
                self.box((rx,y+1.8-.16,0),(8,.32,30),'Concrete',True,.12)
                self.plane(split+.02,right-.02,-15,15,y+1.808,'Asphalt',.12)
                for x in [split+.15,right-.15]:
                    self.box((x,y+1.8+.5,0),(.26,1,30),'Concrete',True,.12)
                    self.box((x,y+1.8+1.08,0),(.12,.12,30),'Teal',False,.12)
                self.plane(rx-.055,rx+.055,-14.8,14.8,y+1.825,'Yellow',.12)
        # From outside: IN was on the right (-X), OUT on the left (+X).
        self.wall_arrow(aisle-2, upward=True)
        self.wall_arrow(aisle+2, upward=False)
        for key,(verts,faces,uvs) in self.buffers.items():
            mesh = bpy.data.meshes.new(self.label+'_'+key)
            mesh.from_pydata(verts,[],faces)
            mesh.materials.append(MATS[key])
            uv = mesh.uv_layers.new(name='UVMap')
            for loop in mesh.loops:
                uv.data[loop.index].uv = uvs[loop.vertex_index]
            mesh.update()
            obj = bpy.data.objects.new(self.label+'_'+key,mesh)
            bpy.context.collection.objects.link(obj)
            self.objects.append(obj)
        return self

    def export(self):
        bpy.ops.object.select_all(action='DESELECT')
        for obj in self.objects: obj.select_set(True)
        bpy.context.view_layer.objects.active = self.objects[0]
        bpy.ops.export_scene.gltf(filepath=str(SOURCE/(self.label+'.glb')),
                                  use_selection=True,export_format='GLB',export_yup=True,
                                  export_materials='EXPORT',export_cameras=False,export_lights=False)
        return {'name':self.label,'width':self.width,'floors':self.floors,'entrance_x':self.entrance_x,
                'collision':self.collisions}

manifest=[]
showcase=[]
for preset,width in [('small',32),('medium',44),('large',56)]:
    for floors in range(3,11):
        garage=Garage(width,floors,f'{preset}_{floors:02d}').build()
        manifest.append(garage.export())
        if (preset,floors) in [('small',3),('medium',6),('large',10)]:
            showcase.append((garage,{'small':-58,'medium':0,'large':70}[preset]))
        else:
            for obj in garage.objects: bpy.data.objects.remove(obj,do_unlink=True)
for garage,offset in showcase:
    collection=bpy.data.collections.new(garage.label)
    bpy.context.scene.collection.children.link(collection)
    collection['width_metres']=garage.width
    collection['parking_levels']=garage.floors
    collection['generator']='../tools/build_garage.py'
    for obj in garage.objects:
        for old in list(obj.users_collection): old.objects.unlink(obj)
        collection.objects.link(obj)
        obj.location.x=offset
for image in bpy.data.images:
    if image.source=='FILE': image.pack()
bpy.context.scene['README']='One procedural source, 24 baked exports. Rebuild using tools/build_garage.py. 3-10 levels, widths 32/44/56m, depth 54m.'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.color_type = 'MATERIAL'
            area.spaces.active.region_3d.view_distance = 170
            area.spaces.active.region_3d.view_location = (0,0,12)
            area.spaces.active.region_3d.view_rotation = Vector((-.25,-1,-.5)).to_track_quat('-Z','Y')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'parking_garage.blend'))
(SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('GARAGE_BLENDER_COMPLETE: 24 configurations; editable source saved')
