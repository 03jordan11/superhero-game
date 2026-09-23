"""Patch only the affected collision in the native scene; preserve prop text exactly."""
from pathlib import Path
import re, json
here=Path(__file__).resolve().parents[1]
path=here/'city_hall.tscn'
raw=path.read_bytes().decode('utf-8')
newline='\r\n' if '\r\n' in raw else '\n'
text=raw.replace('\r\n','\n')
props=text[text.index('[node name="GardenProps"'):]
blocks=re.split(r'(?=^\[)',text,flags=re.M)
removed_shapes=[]
kept=[]
for block in blocks:
    if re.match(r'\[node name="(?:Gardenretainingwalls|Gardencoping|FrontSetback)[^"]*"',block):
        match=re.search(r'shape = SubResource\("([^"]+)"\)',block)
        if match: removed_shapes.append(match[1])
        continue
    kept.append(block)
text=''.join(kept)
for shape in removed_shapes:
    if f'SubResource("{shape}")' not in text:
        text=re.sub(r'^\[sub_resource [^\n]*id="'+re.escape(shape)+r'"\]\n.*?(?=^\[|\Z)','',text,flags=re.M|re.S)
resources=[]
nodes=[]
manifest=json.loads((here/'city_hall_manifest.json').read_text())
for i,entry in enumerate(b for b in manifest['collision_boxes'] if b['name'].startswith('Front setback')):
    resource=f'FrontSetbackShape_{i}'
    size=', '.join(map(str,entry['size']))
    center=', '.join(map(str,entry['center']))
    resources.append(f'[sub_resource type="BoxShape3D" id="{resource}"]\nsize = Vector3({size})\n\n')
    nodes.append(f'[node name="FrontSetback_{i}" type="CollisionShape3D" parent="ExteriorCollision"]\nposition = Vector3({center})\nshape = SubResource("{resource}")\n\n')
index=text.index('[node ')
text=text[:index]+''.join(resources)+text[index:]
index=text.index('[node name="GardenProps"')
text=text[:index]+''.join(nodes)+text[index:]
assert text[text.index('[node name="GardenProps"'):]==props
path.write_bytes(text.replace('\n',newline).encode('utf-8'))
import_path=here/'city_hall.glb.import'
raw=import_path.read_bytes().decode('utf-8')
raw=re.sub(r'import_script/path="[^"]*"','import_script/path="res://assets/buildings/city_hall/tools/city_sidewalk_import.gd"',raw)
import_path.write_bytes(raw.encode('utf-8'))
print('Updated frontage collision and shared paving importer; GardenProps preserved verbatim')
