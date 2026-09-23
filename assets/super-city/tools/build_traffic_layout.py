"""Compile exported, current road surfaces into traffic-only straight corridors.
Run export_traffic_roads.gd first. Leaves layout.json and pedestrian data intact.
"""
from pathlib import Path
import json
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / 'assets/super-city/traffic'
snapshot = json.loads((DEST/'road_snapshot.json').read_text())
legacy = json.loads((ROOT/'assets/super-city/layout.json').read_text())
def center(r): return (round(r[0]+r[2]/2,3), round(r[1]+r[3]/2,3))
old_junctions = [r for r in legacy['roads'] if r['kind']=='junction']
old_ids = {center(r['rect']): i for i,r in enumerate(old_junctions)}
cores = {}
groups = defaultdict(list)
profiles = []
surfaces = []

def segment(rect, axis, source, height=.03):
    x,z,w,d = rect
    if min(w,d) < .01: return
    start, end, c, width = (x,x+w,z+d/2,d) if axis==0 else (z,z+d,x+w/2,w)
    groups[(axis,round(c,3))].append((start,end,width,source,height))

for piece in snapshot['pieces']:
    surfaces += [{'rect': r, 'node':piece['node']} for r in piece['rects']]
    if piece['type']!=1:
        for r in piece['rects']: segment(r,piece['axis'],piece['node'],piece['height'])
        continue
    core=piece['core']; c=center(core)
    cores[c]=core
    for r in piece['rects']:
        p=center(r)
        if abs(p[0]-c[0]) > core[2]/2-.01: axis=0
        elif abs(p[1]-c[1]) > core[3]/2-.01: axis=1
        else: continue
        segment(r,axis,piece['node'],piece['height'])

for bridge in snapshot['bridges']:
    points=bridge['profile']; a,b=points[0],points[-1]
    axis=0 if abs(b[0]-a[0])>abs(b[2]-a[2]) else 1
    c=(a[2]+b[2])/2 if axis==0 else (a[0]+b[0])/2
    lo,hi=sorted([a[axis*2],b[axis*2]])
    w=bridge['width']
    rect=[lo,c-w/2,hi-lo,w] if axis==0 else [c-w/2,lo,w,hi-lo]
    segment(rect,axis,bridge['node'])
    surfaces.append({'rect':rect,'node':bridge['node']})
    profiles.append({'axis':axis,'center':round(c,3),'samples':sorted([[p[axis*2],p[1]] for p in points])})

streets=[]
for (axis,c),parts in sorted(groups.items()):
    merged=[]
    for lo,hi,w,source,height in sorted(parts):
        if merged and lo<=merged[-1][1]+.003:
            prev=merged[-1];prev[1]=max(prev[1],hi);prev[2]=min(prev[2],w);prev[3].add(source)
        else: merged.append([lo,hi,w,{source},height])
    for lo,hi,w,sources,height in merged:
        intervals=[(lo,hi)]
        for core in cores.values():
            x,z,cw,cd=core
            cut0,cut1,side0,side1=(x,x+cw,z,z+cd) if axis==0 else (z,z+cd,x,x+cw)
            if not side0+.001<c<side1-.001: continue
            remaining=[]
            for a,b in intervals:
                if cut1<=a or cut0>=b: remaining.append((a,b));continue
                if cut0>a: remaining.append((a,cut0))
                if cut1<b: remaining.append((cut1,b))
            intervals=remaining
        for a,b in intervals:
            if b-a<12: continue
            rect=[a,c-w/2,b-a,w] if axis==0 else [c-w/2,a,w,b-a]
            samples=[[a,height],[b,height]]
            for p in profiles:
                if p['axis']==axis and abs(p['center']-c)<.01:
                    samples += [v for v in p['samples'] if a<=v[0]<=b]
            samples=sorted(dict(samples).items())
            if max(v[1] for v in samples)-min(v[1] for v in samples)<0.0001:
                samples=[samples[0],samples[-1]]
            streets.append({'kind':'street','axis':axis,'rect':[round(v,4) for v in rect],
                            'height_profile':samples,'sources':sorted(sources)})

junctions=[]
next_id=len(old_junctions)
for c,rect in sorted(cores.items()):
    if c in old_ids: junction_id=old_ids[c]
    else: junction_id=next_id;next_id+=1
    junctions.append({'kind':'junction','rect':rect,'junction_id':junction_id})
result={'version':1,'source':'Saved Main/SuperCity road modules and bridge decks; city roads only',
        'roads':streets+junctions,'surfaces':surfaces,'source_sha256':snapshot['source_sha256']}
(DEST/'layout.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'TRAFFIC_LAYOUT: {len(streets)} corridors, {len(junctions)} junctions; {next_id-len(old_junctions)} new junction IDs; bridge heights included')
