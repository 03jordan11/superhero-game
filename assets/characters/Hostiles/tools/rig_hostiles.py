"""Initial hostile rigs. Fit the gameplay skeleton; preserve approved meshes.
Blender --background --factory-startup --python this_file.py
"""
import bpy
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/characters/Hostiles'
sys.path.insert(0, str(ROOT/'assets/characters/hero_meshy/tools'))
from costume_shapes import smooth


def chain(value, anchors):
    if value <= anchors[0][0]:
        return [(anchors[0][1], 1)]
    for (a, first), (b, second) in zip(anchors, anchors[1:]):
        if value <= b:
            blend = smooth(a, b, value)
            return [(first, 1-blend), (second, blend)]
    return [(anchors[-1][1], 1)]


def build(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/Superhero-male/Superhero_Male_FullBody.gltf'))
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
    source = OUT/'prepared'/('thug_white_male_'+kind+'_mittens.glb')
    bpy.ops.import_scene.gltf(filepath=str(source))
    actor = next(o for o in set(bpy.data.objects)-before if o.type == 'MESH')
    bpy.ops.object.select_all(action='DESELECT')
    actor.select_set(True)
    bpy.context.view_layer.objects.active = actor
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = actor.data
    positions = np.array([tuple(v.co) for v in mesh.vertices])
    uvs = np.array([tuple(v.uv) for v in mesh.uv_layers.active.data])
    faces = [tuple(p.vertices) for p in mesh.polygons]
    skinny = kind == 'skinny'
    brute = kind == 'brute'
    body_scale = 2.3/1.8 if brute else 1.0
    # Work at the existing fitting scale, then enlarge the skeleton/donor only.
    # The approved target mesh stays untouched at its final height.
    wrist = (.375 if brute else .355 if skinny else .366)*1.8
    length = (.085 if brute else .079 if skinny else .094)*1.8
    width = (.025 if brute else .022 if skinny else .023)*1.8
    # Derive each wrist center from the approved cut loop, including asymmetry.
    wrists = {}
    for side in (1, -1):
        points = {tuple(v.co/body_scale) for v in mesh.vertices if abs(v.co.x-side*wrist*body_scale) < 1e-5}
        wrists[side] = sum((Vector(p) for p in points), Vector()) / len(points)

    def fit(point):
        x, y, z = point
        ax = abs(x)
        side = 1 if x >= 0 else -1
        height = float(np.interp(z, [0,.0865,.5424,.9712,1.072,1.3109,1.5205,1.5998,1.82],
                                [0,.12,.53,.92 if skinny else .94,1.04,1.30,1.48 if skinny else 1.52,1.57 if skinny else 1.60,1.75 if skinny else 1.80]))
        leg = 1-smooth(.94,1.12,z)
        leg_center = float(np.interp(z, [0,.5424,.9712], [.215,.19,.14]))
        torso_width = 1.15 if brute else 1.0
        result = Vector(((x+side*(leg_center-.1143)*leg)*torso_width, y-.035, height))
        arm = smooth(.13,.23,ax)*smooth(1.27,1.40,z)
        if arm:
            wx, wy, wz = wrists[side]
            arm_x = float(np.interp(ax, [0,.212,.463,.7065,.8219,.92,.97],
                                   [0,.27 if brute else .24 if skinny else .25,.48 if brute else .44 if skinny else .47,wrist,wrist+length*.53,wrist+length,wrist+length*1.20]))
            center_z = float(np.interp(ax, [.212,.463,.7065], [1.50 if brute else 1.46 if skinny else 1.48,1.49 if brute else 1.425 if skinny else 1.45,wz]))
            center_y = float(np.interp(ax, [.212,.7065], [0,wy]))
            result = result.lerp(Vector((side*arm_x,y-.0654+center_y,z-1.4555+center_z)), arm)
        return result*body_scale

    for v in donor.data.vertices:
        v.co = fit(v.co)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in rig.data.edit_bones:
        bone.use_connect = False
        head, tail = fit(bone.head), fit(bone.tail)
        bone.head, bone.tail = head, tail
    for side, suffix in [(1,'l'),(-1,'r')]:
        center = wrists[side]
        # Thumb follows the mitten's splayed branch, not separate finger shapes.
        points = [(center+Vector((side*length*f, -width*y, -.005)))*body_scale
                  for f,y in [(.16,.75),(.31,1.15),(.46,1.60),(.55,1.85),(.60,2.0)]]
        for i, name in enumerate(['thumb_01_', 'thumb_02_', 'thumb_03_', 'thumb_04_leaf_']):
            bone = rig.data.edit_bones[name+suffix]
            bone.head, bone.tail = points[i], points[i+1]
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
        for name, weight in pairs:
            if weight > 1e-5:
                merged[name] = merged.get(name, 0)+weight
        pairs = sorted(merged.items(), key=lambda p:-p[1])[:4]
        total = sum(w for _,w in pairs)
        assert total > 0, 'Unweighted vertex'
        for g in list(vertex.groups):
            actor.vertex_groups[g.group].remove([vertex.index])
        for name, weight in pairs:
            actor.vertex_groups[name].add([vertex.index], weight/total, 'REPLACE')

    for v in mesh.vertices:
        x,y,z = v.co/body_scale
        ax = abs(x)
        side = 1 if x >= 0 else -1
        suffix = 'l' if side == 1 else 'r'
        head_start = 1.48 if skinny else 1.52
        if ax < .19 and z > head_start:
            head = smooth(head_start, head_start+.045, z)
            assign(v, [('Head',head),('neck_01',1-head)])
        elif .95 < z < 1.13 and ax < .27:
            assign(v, chain(z,[(.95,'pelvis'),(1.13,'spine_01')]))
        elif ax > wrist-.035 and z > 1.25:
            # Wrist transition and a unified four-finger block prevent tearing.
            if ax < wrist:
                assign(v, chain(ax,[(wrist-.035,'lowerarm_'+suffix),(wrist,'hand_'+suffix)]))
                continue
            thumb = smooth(width*.8,width*1.25,wrists[side].y-y)*(1-smooth(wrist+length*.60,wrist+length*.75,ax))
            palm = chain(ax,[(wrist+length*.40,'hand_'+suffix),(wrist+length*.72,'middle_01_'+suffix)])
            if thumb > .001:
                bones = [rig.data.bones['thumb_%02d_'%i+suffix] for i in (1,2,3)]
                origin = bones[0].head_local
                axis = (bones[-1].head_local-origin).normalized()
                finger = chain((v.co-origin).dot(axis),[(float((b.head_local-origin).dot(axis)),b.name) for b in bones])
                assign(v,[(name,w*(1-thumb)) for name,w in palm]+[(name,w*thumb) for name,w in finger])
            else:
                assign(v,palm)
        else:
            assign(v,[(actor.vertex_groups[g.group].name,g.weight) for g in v.groups])
    seams = {}
    for v in mesh.vertices:
        key = tuple(round(value,6) for value in v.co)
        if key in seams:
            assign(v,seams[key])
        else:
            seams[key] = [(actor.vertex_groups[g.group].name,g.weight) for g in v.groups]
    assert np.array_equal(positions,np.array([tuple(v.co) for v in mesh.vertices]))
    assert np.array_equal(uvs,np.array([tuple(v.uv) for v in mesh.uv_layers.active.data]))
    assert faces == [tuple(p.vertices) for p in mesh.polygons]
    for obj in list(bpy.data.objects):
        if obj not in (rig,actor):
            bpy.data.objects.remove(obj,do_unlink=True)
    actor.parent = rig
    modifier = actor.modifiers.new('Humanoid rig','ARMATURE')
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
    filename = 'thug_white_male_'+kind+'_rigged'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/(filename+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/'prepared'/(filename+'.glb')),export_format='GLB',use_selection=True,
                             export_animations=False,export_apply=True,export_def_bones=False,export_all_influences=False,export_yup=True)
    return dict(model=kind,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                bones=len(rig.data.bones),max_influences=max(len(v.groups) for v in mesh.vertices),
                geometry_and_uvs_unchanged=True)


if __name__ == '__main__':
    selected = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['beard','skinny','brute']
    assert selected and all(kind in ('beard','skinny','brute') for kind in selected)
    audit_path = OUT/'prepared/rig_pass_audit.json'
    report = json.loads(audit_path.read_text()) if audit_path.exists() else []
    report = [row for row in report if row['model'] not in selected]
    report.extend(build(kind) for kind in selected)
    audit_path.write_text(json.dumps(report,indent=2)+'\n')
    print('HOSTILE_RIG_PASS',json.dumps(report))
