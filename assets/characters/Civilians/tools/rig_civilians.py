"""Fit the existing humanoid rig to the four civilian preview meshes.

Run with Blender --background --factory-startup --python this_file.py.
Optional arguments after -- select individual model stems to rebuild.
Original GLBs are read only. Output geometry is uniformly sized and grounded,
but otherwise unchanged; only the donor mesh and skeleton are fitted.
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/characters/Civilians'
sys.path.insert(0, str(ROOT / 'assets/characters/Hostiles/tools'))
from rig_hostiles import chain, smooth

# Fractions of the final height, measured against each source T-pose.
MODELS = {
    'civilian_male_fat': dict(height=1.78, shoulder=.135, elbow=.255, wrist=.365,
                             hip=.51, knee=.30, ankle=.060, leg=.105, torso=1.25),
    'civilian_male_young': dict(height=1.80, shoulder=.115, elbow=.250, wrist=.357,
                               hip=.535, knee=.325, ankle=.075, leg=.105, torso=.98),
    'civilian_woman_athletic': dict(height=1.72, shoulder=.100, elbow=.228, wrist=.333,
                                   hip=.54, knee=.325, ankle=.072, leg=.096, torso=.86),
    'civilian_woman_sweater': dict(height=1.68, shoulder=.120, elbow=.265, wrist=.382,
                                  hip=.535, knee=.31, ankle=.060, leg=.105, torso=1.0),
}


def build(name):
    spec = MODELS[name]
    height = spec['height']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/Superhero-male/Superhero_Male_FullBody.gltf'))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    rig.name = 'Armature'
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    donor = bpy.data.objects['SuperHero_Male']
    donor.animation_data_clear()
    for modifier in list(donor.modifiers):
        donor.modifiers.remove(modifier)
    for obj in list(bpy.data.objects):
        if obj not in (rig, donor):
            bpy.data.objects.remove(obj, do_unlink=True)
    before = set(bpy.data.objects)
    source = OUT / (name + '.glb')
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in set(bpy.data.objects) - before if o.type == 'MESH']
    assert len(meshes) == 1, 'Review multiple source meshes before rebuilding'
    actor = meshes[0]
    world = actor.matrix_world.copy()
    actor.parent = None
    actor.matrix_world = world
    bpy.ops.object.select_all(action='DESELECT')
    actor.select_set(True)
    bpy.context.view_layer.objects.active = actor
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    actor.name = name
    mesh = actor.data
    low = min(v.co.z for v in mesh.vertices)
    scale = height / (max(v.co.z for v in mesh.vertices) - low)
    for vertex in mesh.vertices:
        vertex.co = (vertex.co - Vector((0, 0, low))) * scale
    positions = np.array([tuple(v.co) for v in mesh.vertices])
    uvs = np.array([tuple(v.uv) for v in mesh.uv_layers.active.data])
    faces = [tuple(p.vertices) for p in mesh.polygons]
    normalized = positions / height

    def arm_center(side, x):
        points = normalized[(np.abs(normalized[:, 0] - side*x) < .018)
                            & (normalized[:, 2] > .70)]
        assert len(points) > 0, (name, side, x)
        return (points.min(axis=0) + points.max(axis=0)) / 2

    centers = {side: [arm_center(side, x) for x in
                     (spec['shoulder']+.025, spec['elbow'], spec['wrist'])]
               for side in (1, -1)}
    tips = {side: max(normalized[:, 0]*side) for side in (1, -1)}

    def fit(point):
        x, y, z = point
        side = 1 if x >= 0 else -1
        ax = abs(x)
        mapped_z = float(np.interp(z, [0, .0865, .5424, .9712, 1.072, 1.3109, 1.5205, 1.5998, 1.82],
                                  [0, spec['ankle'], spec['knee'], spec['hip'], .60, .735, .85, .895, 1]))
        leg_blend = 1-smooth(.94, 1.12, z)
        leg_center = float(np.interp(z, [0, .5424, .9712],
                                    [spec['leg'], spec['leg']*.86, .072]))
        torso_scale = 1+(spec['torso']-1)*smooth(.9, 1.1, z)*(1-smooth(1.35, 1.52, z))
        result = Vector(((x/1.82 + side*(leg_center-.1143/1.82)*leg_blend)*torso_scale,
                         (y-.035)/1.82*torso_scale, mapped_z))
        arm_blend = smooth(.13, .23, ax)*smooth(1.27, 1.40, z)
        if arm_blend:
            shoulder, elbow, wrist = centers[side]
            hand_length = tips[side]-spec['wrist']
            arm_x = float(np.interp(ax, [0, .212, .463, .7065, .8219, .92, .97],
                                   [0, spec['shoulder'], spec['elbow'], spec['wrist'],
                                    spec['wrist']+hand_length*.53, tips[side], tips[side]+.02]))
            center_y = float(np.interp(ax, [.212, .463, .7065], [shoulder[1], elbow[1], wrist[1]]))
            center_z = float(np.interp(ax, [.212, .463, .7065], [shoulder[2], elbow[2], wrist[2]]))
            result = result.lerp(Vector((side*arm_x, (y-.0654)/1.82+center_y,
                                         (z-1.4555)/1.82+center_z)), arm_blend)
        return result*height

    for vertex in donor.data.vertices:
        vertex.co = fit(vertex.co)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in rig.data.edit_bones:
        bone.use_connect = False
        bone.head, bone.tail = fit(bone.head), fit(bone.tail)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    actor.select_set(True)
    bpy.context.view_layer.objects.active = actor
    for group in donor.vertex_groups:
        actor.vertex_groups.new(name=group.name)
    transfer = actor.modifiers.new('Fitted humanoid weight transfer', 'DATA_TRANSFER')
    transfer.object = donor
    transfer.use_vert_data = True
    transfer.data_types_verts = {'VGROUP_WEIGHTS'}
    transfer.vert_mapping = 'POLYINTERP_NEAREST'
    transfer.layers_vgroup_select_src = 'ALL'
    transfer.layers_vgroup_select_dst = 'NAME'
    bpy.ops.object.modifier_apply(modifier=transfer.name)

    def assign(vertex, pairs):
        merged = {}
        for bone, weight in pairs:
            if weight > 1e-5:
                merged[bone] = merged.get(bone, 0)+weight
        pairs = sorted(merged.items(), key=lambda pair: -pair[1])[:4]
        total = sum(weight for _, weight in pairs)
        assert total > 0, (name, 'Unweighted vertex', vertex.index)
        for group in list(vertex.groups):
            actor.vertex_groups[group.group].remove([vertex.index])
        for bone, weight in pairs:
            actor.vertex_groups[bone].add([vertex.index], weight/total, 'REPLACE')

    for vertex in mesh.vertices:
        x, y, z = vertex.co/height
        ax = abs(x)
        side = 1 if x >= 0 else -1
        suffix = 'l' if side == 1 else 'r'
        wrist = spec['wrist']
        if ax < .11 and z > .85:
            head = smooth(.85, .88, z)
            assign(vertex, [('Head', head), ('neck_01', 1-head)])
        elif spec['hip']+.015 < z < .625 and ax < .15:
            assign(vertex, chain(z, [(spec['hip']+.015, 'pelvis'), (.625, 'spine_01')]))
        elif ax > wrist-.02 and z > .70:
            # Keep the source's joined low-poly fingers together when curling.
            length = tips[side]-wrist
            if ax < wrist:
                pairs = chain(ax, [(wrist-.02, 'lowerarm_'+suffix), (wrist, 'hand_'+suffix)])
            else:
                thumb = smooth(.016, .030, centers[side][2][1]-y)*(1-smooth(wrist+length*.6, wrist+length*.8, ax))
                palm = chain(ax, [(wrist+length*.4, 'hand_'+suffix), (wrist+length*.75, 'middle_01_'+suffix)])
                pairs = [(bone, weight*(1-thumb)) for bone, weight in palm]+[('thumb_02_'+suffix, thumb)]
            assign(vertex, pairs)
        else:
            assign(vertex, [(actor.vertex_groups[g.group].name, g.weight) for g in vertex.groups])
    seams = {}
    for vertex in mesh.vertices:
        key = tuple(round(value, 6) for value in vertex.co)
        if key in seams:
            assign(vertex, seams[key])
        else:
            seams[key] = [(actor.vertex_groups[g.group].name, g.weight) for g in vertex.groups]
    assert np.array_equal(positions, np.array([tuple(v.co) for v in mesh.vertices]))
    assert np.array_equal(uvs, np.array([tuple(v.uv) for v in mesh.uv_layers.active.data]))
    assert faces == [tuple(p.vertices) for p in mesh.polygons]
    assert all(abs(sum(g.weight for g in v.groups)-1) < 1e-5 for v in mesh.vertices)
    for obj in list(bpy.data.objects):
        if obj not in (rig, actor):
            bpy.data.objects.remove(obj, do_unlink=True)
    actor.parent = rig
    modifier = actor.modifiers.new('Humanoid rig', 'ARMATURE')
    modifier.object = rig
    rig.show_in_front = True
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for image in bpy.data.images:
        if image.has_data:
            image.pack()
    bpy.ops.object.select_all(action='DESELECT')
    actor.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = actor
    for folder in ('source', 'prepared'):
        (OUT / folder).mkdir(exist_ok=True)
    filename = name+'_rigged'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source' / (filename+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'prepared' / (filename+'.glb')),
                             export_format='GLB', use_selection=True, export_animations=False,
                             export_apply=True, export_def_bones=False,
                             export_all_influences=False, export_yup=True)
    mesh.calc_loop_triangles()
    return dict(model=name, height_m=height, source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                bones=len(rig.data.bones), triangles=len(mesh.loop_triangles),
                max_influences=max(len(v.groups) for v in mesh.vertices),
                geometry_and_uvs_unchanged_after_uniform_sizing=True,
                arm_centers={str(side): [list(point) for point in points] for side, points in centers.items()})


if __name__ == '__main__':
    selected = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(MODELS)
    assert selected and all(name in MODELS for name in selected)
    audit = OUT / 'prepared/rig_pass_audit.json'
    report = json.loads(audit.read_text()) if audit.exists() else []
    report = [row for row in report if row['model'] not in selected]
    report.extend(build(name) for name in selected)
    audit.write_text(json.dumps(report, indent=2)+'\n')
    print('CIVILIAN_RIG_PASS', json.dumps(report))
