from pathlib import Path
import json,re,hashlib
ROOT=Path(__file__).resolve().parents[3]
p=ROOT/'assets/super-city/pedestrians/network.json';graph=json.loads(p.read_text())
scene=ROOT/'scenes/super_city.tscn';s=scene.read_text(encoding='utf-8');result=[];removed=[]
for b in re.split(r'(?=^\[(?:node|editable|connection)\b)',s,flags=re.M):
 m=re.match(r'\[node name="([^"]+)"[^\n]*? parent="([^"]+)"',b)
 path=((m[2]+'/' if m[2]!='.' else '')+m[1]) if m else ''
 e=re.match(r'\[editable path="([^"]+)"',b)
 if e:path=e[1]
 parts=path.split('/')
 if parts[0]=='CityPedestrianRoutes':
  b=re.sub(r' index="\d+"','',b)
  if len(parts)>=3:
   key=parts[1]+'_'+parts[2]
   if key not in graph['modules']:removed.append(path);continue
   if len(parts)==4 and parts[3]=='StartHere':
    x,y,z=graph['points'][graph['modules'][key]['start']]
    b=re.sub(r'^transform = .*$',f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.9g}, {y:.9g}, {z:.9g})',b,flags=re.M)
    b=re.sub(r'^position = .*$',f'position = Vector3({x:.9g}, {y:.9g}, {z:.9g})',b,flags=re.M)
  if len(parts)==2:
   b=re.sub(r'^"([^"]+)": (true|false),?\n',lambda m:m[0] if m[1] in graph['modules'] else '',b,flags=re.M)
 result.append(b)
scene.write_text(''.join(result),encoding='utf-8')
graph['source_scene_sha256']=hashlib.sha256(scene.read_bytes()).hexdigest();p.write_text(json.dumps(graph,indent='\t'))
reportp=ROOT/'assets/mountain-river/mouth/report.json';report=json.loads(reportp.read_text())
removed=list(dict.fromkeys(report.get('routes',{}).get('removed_editor_overrides',[])+removed))
report['routes']={'modules':len(graph['modules']),'points':len(graph['points']),'edges':len(graph['edges']),'components':graph['component_sizes'],'removed_editor_overrides':removed};reportp.write_text(json.dumps(report,indent=2))
print('Synced route markers, retired',len(removed),'stale editor overrides;',report['routes'])
