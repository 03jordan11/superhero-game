"""Bundle a read-only Godot snapshot into one completely offline HTML file."""
from pathlib import Path
import base64
import collections
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
data = json.loads((HERE / 'snapshot.json').read_text(encoding='utf-8'))
assert not data['errors'], data['errors']
data['root'] = ROOT.as_posix()

# Godot scene instances can create equivalent resource objects. Deduplicate the
# embedded images by content, while retaining each original source path.
textures, lookup, remap = [], {}, {}
for i, t in enumerate(data['textures']):
    key = hashlib.sha256((t['preview'] + str((t['width'], t['height'], t['mipmaps'], t['format']))).encode()).hexdigest()
    if key not in lookup:
        lookup[key] = len(textures)
        textures.append(dict(t, sources=[]))
    j = lookup[key]
    remap[i] = j
    if t['source'] not in textures[j]['sources']:
        textures[j]['sources'].append(t['source'])
data['textures'] = textures
for m in data['materials']:
    m['maps'] = {k: remap[v] for k, v in m['maps'].items()}
for a in data['assets']:
    if 'texture' in a:
        a['texture'] = remap[a['texture']]

materials, lookup, remap = [], {}, {}
for i, m in enumerate(data['materials']):
    key = json.dumps({k: v for k, v in m.items() if k not in ('source',)}, sort_keys=True)
    if key not in lookup:
        lookup[key] = len(materials)
        materials.append(m)
    remap[i] = lookup[key]
data['materials'] = materials
for a in data['assets']:
    for p in a.get('parts', []):
        p['m'] = remap[p['m']]
    if 'material' in a:
        a['material'] = remap[a['material']]

# Static references include scripts as well as the engine's dependency index.
files = {f['path']: f for f in data['files']}
for folder in ('scripts', 'assets', 'scenes', 'resources', 'effects'):
    for p in (ROOT / folder).rglob('*'):
        if p.is_file() and p.suffix.lower() in ('.gd', '.gdshader', '.blend', '.ttf', '.otf') and not any(x in p.parts for x in ('__pycache__', 'tools')):
            source = 'res://' + p.relative_to(ROOT).as_posix()
            files.setdefault(source, dict(path=source, bytes=p.stat().st_size, type=p.suffix[1:], dependencies=[]))
used_by = collections.defaultdict(set)
for f in files.values():
    deps = set()
    for raw in f.get('dependencies', []):
        if 'res://' in raw:
            deps.add('res://' + raw.rsplit('res://', 1)[1])
    path = ROOT / f['path'][6:]
    if path.suffix in ('.tscn', '.tres', '.gd', '.gdshader'):
        text = path.read_text(encoding='utf-8', errors='replace')
        deps.update(re.findall(r'res://[^\s"\'<>]+', text))
    deps = {p for p in deps if (ROOT / p[6:]).is_file()}
    f['resolved_dependencies'] = sorted(deps)
    for dep in deps:
        used_by[dep].add(f['path'])
data['usedBy'] = {k: sorted(v) for k, v in used_by.items()}
data['files'] = list(files.values())

sources = {a['source'] for a in data['assets']}
for f in files.values():
    if f['path'] in sources or f['type'] not in ('gd', 'blend', 'ttf', 'otf'):
        continue
    a = dict(id=f"asset-{len(data['assets']):05d}", source=f['path'], name=Path(f['path']).name,
             kind='resource', level='resource', category='Scripts & source files')
    if f['type'] == 'gd':
        a['code'] = (ROOT / f['path'][6:]).read_text(encoding='utf-8')
    data['assets'].append(a)

for a in data['assets']:
    path = a['source'].split('#')[0]
    if a['kind'] == 'audio':
        p = ROOT / path[6:]
        mime = {'.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.ogg': 'audio/ogg'}.get(p.suffix)
        if mime:
            a['audio'] = f'data:{mime};base64,' + base64.b64encode(p.read_bytes()).decode()
    # Imported geometry is expandable supporting content when it has a wrapper.
    if a['kind'] == 'model' and Path(path).suffix in ('.glb', '.gltf', '.fbx'):
        if any(ref.endswith('.tscn') for ref in data['usedBy'].get(path, [])):
            a['level'] = 'resource'
    if a['kind'] == 'model':
        low, high = [float('inf')]*3, [-float('inf')]*3
        for p in a['parts']:
            if not p['visible']:
                continue
            m, t = data['meshes'][p['g']], p['t']
            for x in (m['min'][0], m['max'][0]):
                for y in (m['min'][1], m['max'][1]):
                    for z in (m['min'][2], m['max'][2]):
                        v = [t[r]*x+t[4+r]*y+t[8+r]*z+t[12+r] for r in range(3)]
                        low = [min(u,w) for u,w in zip(low,v)]
                        high = [max(u,w) for u,w in zip(high,v)]
        if low[0] != float('inf'):
            a['bounds'] = dict(min=low, max=high, center=[(u+w)/2 for u,w in zip(low,high)], size=[w-u for u,w in zip(low,high)])
        a.setdefault('notes', []).append('Static authored snapshot. Runtime-spawned geometry and script changes are not included.')

# Validate geometry and references independently of the viewer.
import struct
for i, m in enumerate(data['meshes']):
    positions = base64.b64decode(m['positions'])
    indices = base64.b64decode(m['indices'])
    assert len(positions) == m['vertices']*12, i
    assert m['triangles'] == (len(indices)//4 if indices else m['vertices'])//3, i
    if indices:
        assert max(struct.unpack('<'+'I'*(len(indices)//4), indices)) < m['vertices'], i
for a in data['assets']:
    for p in a.get('parts', []):
        assert 0 <= p['g'] < len(data['meshes']) and 0 <= p['m'] < len(data['materials'])
assert len({a['id'] for a in data['assets']}) == len(data['assets'])

# Compress the embedded JSON, including its inline textures and audio, so the
# double-clickable deliverable stays small. Decompression is local browser code.
import gzip
payload = base64.b64encode(gzip.compress(json.dumps(data, separators=(',', ':')).encode(), compresslevel=6)).decode()
page = (HERE / 'page.html').read_text(encoding='utf-8')
page = page.replace("const D=JSON.parse(document.getElementById('snapshot').textContent);document.getElementById('snapshot').remove();", """const packed=atob(document.getElementById('snapshot').textContent.trim());
const bytes=Uint8Array.from(packed,c=>c.charCodeAt(0));
const D=JSON.parse(await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))).text());
document.getElementById('snapshot').remove();""")
page = page.replace("'use strict';", "'use strict';\n(async()=>{try{")
page = page.replace('</script></body>', "}catch(error){document.getElementById('loading').textContent='Viewer could not start: '+error.message;console.error(error)}})();\n</script></body>")
page = page.replace('__SNAPSHOT__', payload).replace('__VIEWER__', (HERE / 'viewer.js').read_text(encoding='utf-8'))
output = ROOT / 'Asset Dashboard.html'
output.write_text(page, encoding='utf-8')
report = dict(entries=len(data['assets']), models=sum(a['kind']=='model' for a in data['assets']),
              textures=len(textures), materials=len(materials), geometries=len(data['meshes']),
              html_bytes=output.stat().st_size, errors=data['errors'], generated=data['generated'])
report['poi_triangles'] = {a['source']:sum(data['meshes'][p['g']]['triangles'] for p in a.get('parts',[]) if p['visible'])
                         for a in data['assets'] if a['source'].startswith('res://assets/buildings/') and a['source'].endswith('.tscn')}
(HERE / 'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
