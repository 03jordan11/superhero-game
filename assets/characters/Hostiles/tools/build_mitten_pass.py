"""Blender background build: replace only distal hands; preserve original GLBs.

Run with Blender --background --factory-startup --python this_file.py.
Prepared models are feet-origin, meter-scale, unrigged copies for NPCTestScene.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

ROOT = Path(__file__).resolve().parents[4]
ASSETS = ROOT / "assets/characters/Hostiles"
AUDIT = ROOT / "artifacts/hostile_mesh_audit"
CONFIG = {
    "beard": (1.80, 0.366, 0.094, 0.023, 0.010),
    "brute": (2.3, 0.375, 0.085, 0.025, 0.011),
    "skinny": (1.80, 0.355, 0.079, 0.022, 0.009),
}
SKIN_COLORS = {
    # Median original fingertip albedo, converted from sRGB to linear.
    'beard': (.6514, .3712, .2423, 1),
    'brute': (.7835, .4508, .3419, 1),
    'skinny': (.7529, .4564, .3325, 1),
}


def loop_key(position, uv):
    return tuple(round(x, 6) for x in (*position, *uv))


def rebuild_hand(bm, side, wrist, length, width, thickness, source_tree, source_triangles, source_uvs, kind):
    uv_layer = bm.loops.layers.uv.active
    # Cut beyond bracelets/cuffs. UV interpolation on cut faces is handled by BMesh.
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                          plane_co=(side * wrist, 0, 0), plane_no=(side, 0, 0),
                          dist=0.000001, clear_outer=True, clear_inner=False)
    seam_verts = [v for v in bm.verts if abs(v.co.x - side * wrist) < 0.000002]
    # Only weld the new wrist boundary; body/accessory seams stay untouched.
    bmesh.ops.remove_doubles(bm, verts=seam_verts, dist=0.00001)
    seam_edges = [e for e in bm.edges if e.is_boundary and all(abs(v.co.x-side*wrist)<0.000002 for v in e.verts)]
    seam_verts = set(v for e in seam_edges for v in e.verts)
    assert len(seam_verts) >= 3, "No wrist boundary found"
    center = sum((v.co for v in seam_verts), Vector()) / len(seam_verts)
    original_faces = set(bm.faces)
    rings = []
    # Palm, knuckle and finger loops; a single rounded mass for four fingers.
    sections = [(0.10, .78, .92), (.33, 1.0, 1.0), (.58, 1.0, .92),
                (.80, .94, .80), (.94, .72, .55), (1.0, .30, .25)]
    for fraction, wide, thick in sections:
        ring = []
        for j in range(12):
            angle = math.tau*j/12
            co = center + Vector((side*length*fraction,
                                  width*wide*math.cos(angle) + .004*fraction,
                                  thickness*thick*math.sin(angle) - .004*fraction))
            ring.append(bm.verts.new(co))
        rings.append(ring)
    edges = [bm.edges.new((rings[0][j], rings[0][(j+1)%12])) for j in range(12)]
    bmesh.ops.bridge_loops(bm, edges=seam_edges+edges, use_pairs=False)
    thumb_faces = []
    for k in range(len(rings)-1):
        for j in range(12):
            face = bm.faces.new((rings[k][j], rings[k][(j+1)%12], rings[k+1][(j+1)%12], rings[k+1][j]))
            if k == 0 and j in (5, 6):
                thumb_faces.append(face)
    tip = bm.verts.new(center+Vector((side*length*1.012, .004, -.004)))
    for j in range(12):
        bm.faces.new((rings[-1][j], rings[-1][(j+1)%12], tip))
    # Connected thumb branch, extruded from the side of the palm (no intersecting shells).
    branch = thumb_faces
    for offset, taper in [((side*.008, -.010, -.001), 1.12),
                          ((side*.011, -.008, -.001), .95),
                          ((side*.006, -.004, 0), .80),
                          ((side*.003, -.002, 0), .50)]:
        result = bmesh.ops.extrude_face_region(bm, geom=branch)
        verts = [v for v in result['geom'] if isinstance(v, bmesh.types.BMVert)]
        new_faces = [f for f in result['geom'] if isinstance(f, bmesh.types.BMFace) and all(v in verts for v in f.verts)]
        bmesh.ops.delete(bm, geom=branch, context='FACES_ONLY')
        c = sum((v.co for v in verts), Vector())/len(verts)
        for v in verts:
            v.co = c+(v.co-c)*taper+Vector(offset)
        branch = new_faces
    # Extrusion leaves an unused interior edge where the two root faces met.
    loose = [e for e in bm.edges if not e.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='EDGES')
    new_faces = [f for f in bm.faces if f not in original_faces]
    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    for face in new_faces:
        face.smooth = True
        # A continuous skin/glove material avoids interpolating across unrelated
        # islands in the original atlas when replacing the hand topology.
        fraction = (face.calc_center_median().x*side-wrist)/length
        face.material_index = 2 if kind == 'brute' and fraction < .50 else 1
        for loop in face.loops:
            nearest, normal, index, distance = source_tree.find_nearest(loop.vert.co)
            triangle = source_triangles[index]
            uv = barycentric_transform(nearest, *triangle, *source_uvs[index])
            loop[uv_layer].uv = uv.xy
    # Geometric hand closure check, including only the newly joined wrist/hand.
    assert not [e for e in bm.edges if e.is_boundary and any(v.co.x*side > wrist+0.00001 for v in e.verts)], "Open mitten"
    return len(new_faces)


def render_hand(obj, stem, height):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    camera = bpy.data.objects.new('AuditCamera', bpy.data.cameras.new('AuditCamera'))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = .18*height
    hand = [v.co for v in obj.data.vertices if v.co.x > .36*height]
    center = sum(hand, Vector())/len(hand)
    for label, direction in [('top', Vector((0, 0, 1))), ('front', Vector((0, -1, .3)))]:
        camera.location = center+direction*3
        camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath = str(AUDIT/(stem+'_mitten_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)


def main():
    reports = []
    AUDIT.mkdir(parents=True, exist_ok=True)
    for kind, (height, wrist, length, width, thickness) in CONFIG.items():
        stem = 'thug_white_male_'+kind
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(ASSETS/(stem+'.glb')))
        obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
        for name, color in [('Mitten skin', SKIN_COLORS[kind]), ('Mitten leather', (.018, .024, .029, 1))]:
            material = bpy.data.materials.new(name)
            material.use_nodes = True
            material.diffuse_color = color
            shader = material.node_tree.nodes.get('Principled BSDF')
            shader.inputs['Base Color'].default_value = color
            shader.inputs['Roughness'].default_value = .78
            obj.data.materials.append(material)
        obj.data.calc_loop_triangles()
        uv = obj.data.uv_layers.active.data
        original_normals = {loop_key(obj.data.vertices[l.vertex_index].co, uv[l.index].uv): obj.data.corner_normals[l.index].vector.copy() for l in obj.data.loops}
        triangles = [tuple(obj.data.vertices[i].co.copy() for i in t.vertices) for t in obj.data.loop_triangles]
        uvs = [tuple(Vector((*uv[i].uv, 0)) for i in t.loops) for t in obj.data.loop_triangles]
        points = [v for tri in triangles for v in tri]
        tree = BVHTree.FromPolygons(points, [(i,i+1,i+2) for i in range(0,len(points),3)], all_triangles=True)
        original_body = {loop_key(obj.data.vertices[l.vertex_index].co, uv[l.index].uv) for l in obj.data.loops if abs(obj.data.vertices[l.vertex_index].co.x)<wrist-.00001}
        bm = bmesh.new(); bm.from_mesh(obj.data)
        for side in (1, -1):
            rebuild_hand(bm, side, wrist, length, width, thickness, tree, triangles, uvs, kind)
        bm.to_mesh(obj.data); bm.free(); obj.data.update()
        uv = obj.data.uv_layers.active.data
        after_body = {loop_key(obj.data.vertices[l.vertex_index].co, uv[l.index].uv) for l in obj.data.loops if abs(obj.data.vertices[l.vertex_index].co.x)<wrist-.00001}
        assert original_body == after_body, 'Body vertices/UVs changed outside hands'
        normals = [original_normals.get(loop_key(obj.data.vertices[l.vertex_index].co, uv[l.index].uv), obj.data.corner_normals[l.index].vector.copy()) if abs(obj.data.vertices[l.vertex_index].co.x)<wrist else obj.data.corner_normals[l.index].vector.copy() for l in obj.data.loops]
        obj.data.normals_split_custom_set(normals)
        # Only uniform size and feet-origin adjustment beyond the hand edit.
        for v in obj.data.vertices:
            v.co = (v.co+Vector((0,0,.5)))*height
        obj.name = 'Hostile_'+kind.title()
        obj.data.name = obj.name+'_Mittens'
        obj.data.calc_loop_triangles()
        reports.append(dict(model=stem, height_m=height, triangles=len(obj.data.loop_triangles), body_vertices_and_uvs_preserved=True, hands_closed=True))
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(ASSETS/'source'/(stem+'_mittens.blend')))
        bpy.ops.export_scene.gltf(filepath=str(ASSETS/'prepared'/(stem+'_mittens.glb')), export_format='GLB', use_selection=True, export_animations=False, export_yup=True)
        render_hand(obj, stem, height)
    (ASSETS/'prepared/mesh_pass_audit.json').write_text(json.dumps(reports, indent=2)+'\n')


if __name__ == '__main__':
    main()
