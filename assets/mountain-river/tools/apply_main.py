"""Apply river resources as Main instance overrides; leave standalone city unchanged."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'artifacts/river_mountains'
source=json.loads((WORK/'source.json').read_text())
text=(WORK/'before/scenes/main.tscn').read_text(encoding='utf-8')
resources=['[ext_resource type="PackedScene" path="res://scenes/mountain_river.tscn" id="river_scene"]']
blocks=['[node name="MountainRiver" parent="." instance=ExtResource("river_scene")]\n']
parents={'city_life':'CityLife','coastal_region':'CoastalRegion'}
for name,info in source['meshes'].items():
    path='SuperCity/'+parents[info['scene']]+'/'+info['path']
    for suffix,kind in [('', 'ArrayMesh'),('_collision','Shape3D')]:
        resources.append(f'[ext_resource type="{kind}" path="res://assets/mountain-river/meshes/{name}{suffix}.res" id="river_{name}{suffix}"]')
    parent,node=path.rsplit('/',1)
    blocks.append(f'[node name="{node}" parent="{parent}"]\nmesh = ExtResource("river_{name}")\n')
    blocks.append(f'[node name="CollisionShape3D" parent="{path}/Solid"]\nshape = ExtResource("river_{name}_collision")\n')
for path in ['Water/River','Riverbanks/RiverFoam']+[w['path'] for w in source['walls']]:
    full='SuperCity/Waterfront/'+path;parent,node=full.rsplit('/',1)
    blocks.append(f'[node name="{node}" parent="{parent}"]\nvisible = false\n')
for wall in source['walls']:
    for path in wall['shapes']:
        full='SuperCity/Waterfront/'+path;parent,node=full.rsplit('/',1)
        blocks.append(f'[node name="{node}" parent="{parent}"]\ndisabled = true\n')
pos=text.index('[node ');text=text[:pos]+'\n'.join(resources)+'\n\n'+text[pos:]
pos=text.index('[connection ');text=text[:pos]+'\n'.join(blocks)+'\n'+text[pos:]
text+='\n'+''.join(f'[editable path="{p}"]\n' for p in ['SuperCity','SuperCity/CityLife','SuperCity/CoastalRegion','SuperCity/Waterfront'])
(ROOT/'scenes/main.tscn').write_text(text,encoding='utf-8')
print('Main: river instance, three carved terrain overrides,',len(source['walls']),'old stepped walls hidden with collisions disabled.')
