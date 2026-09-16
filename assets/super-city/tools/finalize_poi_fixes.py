from apply_poi_integration import ROOT, OUT, remove_nodes, node_blocks, block_path
import json,re
p=ROOT/'scenes/super_city.tscn'
s=p.read_text()
header='[ext_resource type="Shape3D" path="res://assets/super-city/poi-integration/sidewalks_1_2_collision.res" id="poi_apron_seam"]\n[ext_resource type="Script" path="res://scripts/encounter-scripts/hospital_rescue_zone.gd" id="poi_rescue_zone"]\n'
s=s.replace('[ext_resource ',header+'[ext_resource ',1)
blocks=node_blocks(s)
for i,b in enumerate(blocks):
    if block_path(b)=='Sidewalks/sidewalks_1_2/CollisionShape3D':
        blocks[i]=re.sub(r'^shape = .*$', 'shape = ExtResource("poi_apron_seam")',b,flags=re.M)
s=''.join(blocks)
at=s.index('[editable ')
s=s[:at]+'[node name="RescueDropOff" type="Node3D" parent="Hospital"]\nposition = Vector3(0, 0.03, 36)\nscript = ExtResource("poi_rescue_zone")\n\n'+s[at:]
p.write_text(s,newline='\n')
p=ROOT/'scenes/city_life.tscn'
p.write_text(remove_nodes(p.read_text(),['Benches/Benches19']),newline='\n')
report=json.loads((OUT/'integration.json').read_text())
report['cleared_props'].append('Benches/Benches19')
report['surface_replacements'].append({'node':'Sidewalks/sidewalks_1_2/CollisionShape3D','shape':'res://assets/super-city/poi-integration/sidewalks_1_2_collision.res'})
(OUT/'integration.json').write_text(json.dumps(report,indent=2))
