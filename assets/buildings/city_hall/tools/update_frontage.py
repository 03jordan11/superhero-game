"""Blender update of the existing asset; never exports or moves native Godot props.
Run after the original builder if rebuilding the historical base model.
"""
import bpy, json
import numpy as np
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'city_hall.blend'))
architecture = bpy.data.collections['CITY HALL | architecture and grounds']
removed = {'Garden retaining walls', 'Front terrace lawns', 'Garden coping'}
for obj in list(architecture.objects):
    if obj.name in removed or obj.name.startswith('Front setback'):
        bpy.data.objects.remove(obj, do_unlink=True)

def linear(hex_value):
    rgb = np.array([int(hex_value[i:i+2],16)/255 for i in (0,2,4)])
    return np.where(rgb<=.04045, rgb/12.92, ((rgb+.055)/1.055)**2.4)

palette = {'Limestone':'C4C0B6','Pale trim':'CCC8BE','Recess stone':'858A8D',
           'Lawn':'687763','Green tile':'53645C','Brass':'B68B59'}
copies = {}
for obj in architecture.objects:
    if obj.type != 'MESH': continue
    for slot in obj.material_slots:
        old = slot.material
        name = old.name.split(' | Civic')[0]
        if name not in palette and name not in ['Windows','Balustrade panel']: continue
        if name in copies:
            slot.material = copies[name]
            continue
        mat = old.copy()
        mat.name = name+' | Civic'
        copies[name] = mat
        slot.material = mat
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        target = linear(palette.get(name,'C4C0B6'))
        mat.diffuse_color = (*target,1)
        bsdf.inputs['Base Color'].default_value = (*target,1)
        # Only recolor the base-color image: preserve emission and all window masks.
        for link in list(mat.node_tree.links):
            if link.to_node != bsdf or link.to_socket.name != 'Base Color': continue
            if link.from_node.type != 'TEX_IMAGE': continue
            source = link.from_node.image
            pixels = np.array(source.pixels[:],dtype=np.float32).reshape(source.size[1],source.size[0],4)
            color = pixels[:,:,:3]
            if name == 'Windows':
                # Gray/warm painted stone surrounds; blue glass stays unchanged.
                mask = (color[:,:,0] >= color[:,:,2]*.97) & (color.mean(axis=2)>.16)
            else:
                mask = np.ones(color.shape[:2],dtype=bool)
            luminance = color.mean(axis=2)
            median = np.median(luminance[mask])
            variation = np.clip(luminance/max(float(median),.001),.65,1.12)
            color[mask] = (variation[:,:,None]*target)[mask]
            image = bpy.data.images.new('civic_'+name.replace(' ','_'),width=source.size[0],height=source.size[1],alpha=True)
            image.pixels.foreach_set(pixels.ravel())
            image.filepath_raw = str(HERE/('civic_'+name.lower().replace(' ','_')+'.png'))
            image.file_format = 'PNG'
            image.save()
            link.from_node.image = image
            bsdf.inputs['Base Color'].default_value=(1,1,1,1)

def box(name, center, size, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for collection in list(obj.users_collection): collection.objects.unlink(obj)
    architecture.objects.link(obj)
    obj.data.materials.append(material)
    uv = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(polygon.normal[i]))
        axes=[i for i in range(3) if i!=axis]
        for loop_id in polygon.loop_indices:
            point=obj.data.vertices[obj.data.loops[loop_id].vertex_index].co+obj.location
            uv.data[loop_id].uv=(point[axes[0]]/8,point[axes[1]]/8)
    return {'name':name,'center':[center[0],center[2],-center[1]],'size':[size[0],size[2],size[1]]}

new_boxes=[]
for side in [-1,1]:
    # Full-height wall at the upper esplanade edge, rather than stepped terraces.
    x=side*56.75
    new_boxes.append(box('Front setback wall '+str(side),(x,-41.6,4),(70.5,.4,8),copies['Limestone']))
    new_boxes.append(box('Front setback coping '+str(side),(x,-41.6,8.12),(70.5,.65,.24),copies['Pale trim']))
    new_boxes.append(box('Front setback plaza '+str(side),(x,-54.9,-.04),(70.5,26.2,.14),bpy.data.materials['Steps and paving']))

manifest_path=HERE/'city_hall_manifest.json'
manifest=json.loads(manifest_path.read_text())
manifest['collision_boxes']=[b for b in manifest['collision_boxes'] if b['name'] not in removed and not b['name'].startswith('Front setback')]+new_boxes
manifest['revision']='Setback retaining walls and ground-level forecourts; muted civic palette; native props preserved separately'
manifest['base_triangles']=0
for obj in architecture.objects:
    if obj.type=='MESH':
        obj.data.calc_loop_triangles()
        manifest['base_triangles']+=len(obj.data.loop_triangles)
manifest['base_meshes']=len(architecture.objects)
# Current native scene props are authoritative; these original-generation counts
# are not used as the complete POI audit. See TRIANGLE_AUDIT.json.
manifest_path.write_text(json.dumps(manifest,indent=2))
bpy.ops.object.select_all(action='DESELECT')
for obj in architecture.objects: obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(HERE/'city_hall.glb'),export_format='GLB',use_selection=True,
                         export_yup=True,export_apply=True,export_cameras=False,export_lights=False)
for image in bpy.data.images:
    if image.name.startswith('civic_'): image.pack()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'city_hall.blend'))
print('CITY_HALL_FRONTAGE_UPDATED: architecture only; props were not exported')
