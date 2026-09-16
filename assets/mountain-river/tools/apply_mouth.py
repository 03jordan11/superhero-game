from pathlib import Path
import json,re,hashlib
ROOT=Path(__file__).resolve().parents[3];WORK=ROOT/'artifacts/river_mouth';OUT=ROOT/'assets/mountain-river/mouth'
report=json.loads((OUT/'report.json').read_text());source=json.loads((WORK/'source.json').read_text());oldriver=json.loads((ROOT/'artifacts/river_mountains/source.json').read_text())
def blocks(s):return re.split(r'(?=^\[(?:node|editable|connection)\b)',s,flags=re.M)
def path(b):
 m=re.match(r'\[node name="([^"]+)"[^\n]*? parent="([^"]+)"',b);return ((m[2]+'/' if m[2]!='.' else '')+m[1]) if m else ''
def remove(s,paths):return ''.join(b for b in blocks(s) if not any(path(b)==p or path(b).startswith(p+'/') for p in paths))
def change(s,p,key,value):
 bs=blocks(s)
 for i,b in enumerate(bs):
  if path(b)==p:
   if re.search('^'+key+' = ',b,re.M):bs[i]=re.sub('^'+key+' = .*$',key+' = '+value,b,flags=re.M)
   else:bs[i]=b.rstrip()+'\n'+key+' = '+value+'\n\n'
   return ''.join(bs)
 parent,name=p.rsplit('/',1) if '/' in p else ('.',p)
 pos=s.find('[editable ');pos=len(s) if pos<0 else pos
 return s[:pos]+f'[node name="{name}" parent="{parent}"]\n{key} = {value}\n\n'+s[pos:]
city=(WORK/'before/scenes/super_city.tscn').read_text(encoding='utf-8');city=remove(city,report['removed_buildings'])
resources=['[ext_resource type="PackedScene" path="res://scenes/river_frontage.tscn" id="mouth_scene"]','[ext_resource type="ArrayMesh" path="res://assets/mountain-river/mouth/meshes/water.res" id="mouth_water"]']
for record in report['replacements']:
 p=record['body'];slug=p.split('/')[-1]
 for suffix,kind in [('', 'ArrayMesh'),('_collision','Shape3D')]:resources.append(f'[ext_resource type="{kind}" path="res://assets/mountain-river/mouth/meshes/{slug}{suffix}.res" id="mouth_{slug}{suffix}"]')
 city=change(city,p+'/MeshInstance3D','mesh',f'ExtResource("mouth_{slug}")');city=change(city,p+'/CollisionShape3D','shape',f'ExtResource("mouth_{slug}_collision")')
city=change(city,'Waterfront/Water/River','mesh','ExtResource("mouth_water")')
city=change(city,'Waterfront/Riverbanks/RiverFoam','visible','false')
for wall in oldriver['walls']:
 city=change(city,'Waterfront/'+wall['path'],'visible','false')
 for p in wall['shapes']:city=change(city,'Waterfront/'+p,'disabled','true')
# Shorten the eastern seawall to the widened mouth, including its collision and coping.
end=report['rows'][-1][2];scale=(1010-end)/750
pose=f'Transform3D(0, 0, {-scale}, 0, 1, 0, 1, 0, 0, {(1010+end)/2}, -5, 800)'
city=change(city,'Waterfront/Riverbanks/QuayWall172','transform',pose)
lamps=[]
for p in source['props']:
 if not p.get('lamp'):continue
 x,y,z=p['p'];a=next((r for r in report['rows'] if r[0]<=z<r[0]+10),None)
 if not a:continue
 old=next(r for r in json.loads((WORK/'before/assets/super-city/layout.json').read_text())['river_rects'] if r[1]<=z<r[1]+r[3]);left=x<old[0]+70
 nx=a[1]-2.5 if left else a[2]+2.5
 city=change(city,p['path'],'transform',f'Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {nx}, {y}, {z})');lamps.append(p['path'])
for p in report['cleared_props']:
 if p in lamps:continue
 city=change(city,p,'visible','false')
pos=city.index('[ext_resource ');city=city[:pos]+'\n'.join(resources)+'\n\n'+city[pos:]
pos=city.index('[editable ');city=city[:pos]+'[node name="RiverFrontage" parent="." instance=ExtResource("mouth_scene")]\n\n'+city[pos:]
if '[editable path="Waterfront"]' not in city:city+='\n[editable path="Waterfront"]\n'
(ROOT/'scenes/super_city.tscn').write_text(city,encoding='utf-8')
main=(WORK/'before/scenes/main.tscn').read_text(encoding='utf-8');main=change(main,'SuperCity/Waterfront/Water/River','visible','true')
(ROOT/'scenes/main.tscn').write_text(main,encoding='utf-8')
(ROOT/'assets/super-city/layout.json').write_text((OUT/'layout.json').read_text(),encoding='utf-8')
report['moved_lamps']=lamps
report['cleared_props']=[p for p in report['cleared_props'] if p not in lamps]
(OUT/'report.json').write_text(json.dumps(report,indent=2))
print('Updated Main and SuperCity; moved',len(lamps),'quay lamps; removed',len(report['removed_buildings']),'buildings.')
