"""Apply the reviewed bake without reserializing unrelated scene nodes."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
REPORT = json.loads((ROOT / 'assets/trees/forest_boundary_report.json').read_text())
BACKUP = ROOT / 'artifacts/forest_boundary_trim/before'
assert not BACKUP.exists(), 'Already applied; preserve the existing backup before rebuilding.'
assert len(REPORT['meshes']) == 5, 'Incomplete bake'
BACKUP.mkdir(parents=True)


def split(text):
    return re.split(r'(?=^\[(?:gd_scene|ext_resource|sub_resource|node|connection|editable)\b)', text, flags=re.M)


def node_path(block):
    if not block.startswith('[node '):
        return None
    header = block.splitlines()[0]
    name = re.search(r'name="([^"]+)"', header)[1]
    parent = re.search(r'parent="([^"]+)"', header)
    return '.' if parent is None else name if parent[1] == '.' else parent[1] + '/' + name


def resource_id(block):
    return re.search(r'id="([^"]+)"', block.splitlines()[0])[1]


def reachable(blocks, resources):
    pending = re.findall(r'SubResource\("([^"]+)"\)', ''.join(b for b in blocks if b.startswith('[node ')))
    seen = set()
    while pending:
        key = pending.pop()
        if key not in seen:
            seen.add(key)
            pending.extend(re.findall(r'SubResource\("([^"]+)"\)', resources[key]))
    return seen


audit = {}
prepared = {}
for scene_name in ('super_city', 'city_life', 'coastal_region'):
    path = ROOT / f'scenes/{scene_name}.tscn'
    original = path.read_bytes().decode('utf-8')
    newline = '\r\n' if '\r\n' in original else '\n'
    blocks = split(original)
    old = list(blocks)
    resources = {resource_id(b): b for b in old if b.startswith('[sub_resource ')}
    removed = {r['path'] for r in REPORT['removed_trees'].get(scene_name, [])}
    assert removed.issubset({node_path(b) for b in old})
    blocks = [b for b in blocks if node_path(b) not in removed]
    modified = set()
    for row in [r for r in REPORT['meshes'] if r['scene'] == scene_name]:
        assert hashlib.sha256((ROOT / row['source'].removeprefix('res://')).read_bytes()).hexdigest() == row['source_sha256']
        assert (ROOT / row['mesh'].removeprefix('res://')).exists()
        for prop, target, value in [('mesh', row['node'], row['mesh'])] + (
                [('shape', row['node'] + '/Solid/CollisionShape3D', row['collision'])] if 'collision' in row else []):
            index = next(i for i, b in enumerate(blocks) if node_path(b) == target)
            block = blocks[index]
            match = re.search(r'^' + prop + r' = (Ext|Sub)Resource\("([^"]+)"\)', block, re.M)
            assert match
            if match[1] == 'Ext':
                ext = next(i for i, b in enumerate(blocks) if b.startswith('[ext_resource ') and resource_id(b) == match[2])
                assert sum(b.count(f'ExtResource("{match[2]}")') for b in blocks) == 1
                blocks[ext] = re.sub(r'path="[^"]+"', f'path="{value}"', blocks[ext])
                blocks[ext] = re.sub(r' uid="[^"]+"', '', blocks[ext])
            else:
                key = 'boundary_' + Path(value).stem
                kind = 'Shape3D' if prop == 'shape' else 'ArrayMesh'
                blocks[index] = block[:match.start()] + f'{prop} = ExtResource("{key}")' + block[match.end():]
                ext = next(i for i, b in enumerate(blocks) if b.startswith('[ext_resource '))
                blocks.insert(ext, f'[ext_resource type="{kind}" path="{value}" id="{key}"]{newline}{newline}')
                modified.add(target)
    if scene_name in REPORT['tree_counts']:
        count = REPORT['tree_counts'][scene_name]['after']
        index = next(i for i, b in enumerate(blocks) if node_path(b) == '.')
        pattern = r'(&?"background_trees": )\d+' if scene_name == 'city_life' else r'(metadata/tree_count = )\d+'
        blocks[index], matches = re.subn(pattern, lambda m: m[1] + str(count), blocks[index])
        assert matches == 1
        modified.add('.')
    orphans = reachable(old, resources) - reachable(blocks, resources)
    blocks = [b for b in blocks if not (b.startswith('[sub_resource ') and resource_id(b) in orphans)]
    for block in old:
        name = node_path(block)
        if name is not None and name not in removed | modified:
            assert block in blocks, f'Unexpected change: {scene_name}/{name}'
    result = ''.join(blocks).encode('utf-8')
    prepared[path] = result
    audit[scene_name] = {'removed_tree_nodes': len(removed), 'removed_unused_shapes': len(orphans),
                         'other_node_blocks_preserved': True, 'before_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'after_sha256': hashlib.sha256(result).hexdigest()}
    (BACKUP / path.name).write_bytes(path.read_bytes())

# Write only once all three scene edits have passed preservation checks.
for path, contents in prepared.items():
    path.write_bytes(contents)
(BACKUP.parent / 'scene_edit_audit.json').write_text(json.dumps(audit, indent=2))
print(json.dumps(audit, indent=2))
