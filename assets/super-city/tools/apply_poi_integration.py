"""Surgical scene edits for the saved POI integration plan; preserve other edits."""
from pathlib import Path
import json, re, shutil, sys, hashlib
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'artifacts/poi_integration'
OUT=ROOT/'assets/super-city/poi-integration'

def backup():
    assert not (WORK/'baseline.json').exists(), 'Baseline already exists'
    files=[]
    for folder in ('assets/super-city/meshes','assets/super-city/materials','assets/super-city/textures'):
        files.extend(p for p in (ROOT/folder).iterdir() if p.is_file())
    files += [ROOT/p for p in ['scenes/main.tscn','scenes/super_city.tscn','scenes/city_life.tscn','scenes/npcs/city_pedestrian_routes.tscn','assets/super-city/layout.json','assets/super-city/pedestrians/network.json','assets/super-city/pedestrians/INVENTORY.md']]
    records={}
    for p in files:
        rel=p.relative_to(ROOT).as_posix();dest=WORK/'before'/rel
        dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
        records[rel]=hashlib.sha256(p.read_bytes()).hexdigest()
    (WORK/'baseline.json').write_text(json.dumps(records,indent=2))
    (WORK/'.gdignore').write_text('')
    print('Saved task baseline:',len(records),'files')

def node_blocks(text):
    return re.split(r'(?=^\[(?:node|editable|connection)\b)',text,flags=re.M)

def block_path(block):
    m=re.match(r'\[node name="([^"]+)"[^\n]*? parent="([^"]+)"',block)
    return (m[2]+'/' if m and m[2]!='.' else '')+m[1] if m else ''

def remove_nodes(text,paths):
    result=[]
    for b in node_blocks(text):
        p=block_path(b)
        edit=re.match(r'\[editable path="([^"]+)"',b)
        if edit:p=edit[1]
        if any(p==r or p.startswith(r+'/') for r in paths):continue
        result.append(b)
    return ''.join(result)

def apply():
    report=json.loads((OUT/'integration.json').read_text())
    city=(ROOT/'scenes/super_city.tscn').read_text()
    city=remove_nodes(city,report['removed_buildings'])
    added=[]
    blocks=node_blocks(city)
    for i,row in enumerate(report['surface_replacements']):
        rid=f'poi_shape_{i}'
        added.append(f'[ext_resource type="Shape3D" path="{row["shape"]}" id="{rid}"]\n')
        found=False
        for n,b in enumerate(blocks):
            if block_path(b)==row['node']:
                blocks[n]=re.sub(r'^shape = .*$',f'shape = ExtResource("{rid}")',b,flags=re.M);found=True
        assert found,row['node']
    city=''.join(blocks)
    poi_blocks=[]
    for i,row in enumerate(report['pois']):
        rid=f'poi_scene_{i}'
        added.append(f'[ext_resource type="PackedScene" path="{row["asset"]}" id="{rid}"]\n')
        import math
        c,s=math.cos(row['rotation_y']),math.sin(row['rotation_y'])
        x,y,z=row['position'];transform=f'Transform3D({c:.9g}, 0, {-s:.9g}, 0, 1, 0, {s:.9g}, 0, {c:.9g}, {x:.9g}, {y:.9g}, {z:.9g})'
        existing=next((b for b in node_blocks(city) if block_path(b)==row['node']),None)
        if existing:
            city=city.replace(existing,re.sub(r'^transform = .*$',f'transform = {transform}',existing,flags=re.M))
        else:
            poi_blocks.append(f'[node name="{row["node"]}" parent="." instance=ExtResource("{rid}")]\ntransform = {transform}\n\n')
    start=city.index('[ext_resource ')
    city=city[:start]+''.join(added)+city[start:]
    at=city.index('[editable ')
    city=city[:at]+''.join(poi_blocks)+city[at:]
    (ROOT/'scenes/super_city.tscn').write_text(city,newline='\n')
    # The earlier east-edge showroom is superseded by these city instances.
    main=(ROOT/'scenes/main.tscn').read_text()
    main=remove_nodes(main,[p['node'] for p in report['pois']])
    main=re.sub(r'^\[ext_resource[^\n]*path="res://assets/buildings/[^\n]*\n','',main,flags=re.M)
    (ROOT/'scenes/main.tscn').write_text(main,newline='\n')
    life=(ROOT/'scenes/city_life.tscn').read_text()
    life=remove_nodes(life,report['cleared_props'])
    (ROOT/'scenes/city_life.tscn').write_text(life,newline='\n')
    shutil.copyfile(OUT/'layout.json',ROOT/'assets/super-city/layout.json')
    # Restore byte-for-byte all chunks outside the touched neighborhoods.
    changed={Path(r['node']).parent.name+'.res' for r in report['surface_replacements']}
    changed.add('ground.res')
    baseline=json.loads((WORK/'baseline.json').read_text())
    restored=0
    for rel in baseline:
        if rel.startswith('assets/super-city/meshes/') and Path(rel).name not in changed:
            shutil.copy2(WORK/'before'/rel,ROOT/rel);restored+=1
    print('Applied six POIs; removed',len(report['removed_buildings']),'building instances;',restored,'unaffected meshes retained verbatim.')

if __name__=='__main__':
    {'backup':backup,'apply':apply}[sys.argv[1]]()
