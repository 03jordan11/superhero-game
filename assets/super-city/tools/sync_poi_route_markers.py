"""Refresh editor marker overrides without changing district checkbox selections."""
from apply_poi_integration import ROOT, node_blocks, block_path
import hashlib,json,re
p=ROOT/'assets/super-city/pedestrians/network.json'
graph=json.loads(p.read_text())
scene=ROOT/'scenes/super_city.tscn'
blocks=node_blocks(scene.read_text())
changed=0
for i,b in enumerate(blocks):
    parts=block_path(b).split('/')
    if len(parts)!=4 or parts[0]!='CityPedestrianRoutes' or parts[-1]!='StartHere':continue
    module=graph['modules'].get(parts[1]+'_'+parts[2])
    if not module:continue
    x,y,z=graph['points'][module['start']]
    value=f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.9g}, {y:.9g}, {z:.9g})'
    new=re.sub(r'^transform = .*$',value,b,flags=re.M)
    changed+=new!=b
    blocks[i]=new
scene.write_text(''.join(blocks),newline='\n')
graph['source_scene_sha256']=hashlib.sha256(scene.read_bytes()).hexdigest()
p.write_text(json.dumps(graph,indent='\t'),newline='\n')
print('Synchronized editor route marker overrides:',changed)
