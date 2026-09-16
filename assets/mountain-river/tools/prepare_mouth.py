"""One-off river mouth revision against artifacts/river_mouth/before."""
from pathlib import Path
import json,math,re,sys
import numpy as np
from prepare import subtract,flatten,area,halfclip
ROOT=Path(__file__).resolve().parents[3];WORK=ROOT/'artifacts/river_mouth';OUT=ROOT/'assets/mountain-river/mouth'
OUT.mkdir(exist_ok=True)
S=json.loads((WORK/'source.json').read_text());L=json.loads((WORK/'before/assets/super-city/layout.json').read_text())
R=json.loads((WORK/'before/assets/mountain-river/report.json').read_text())
rows=[]
for z,x,y,w in R['river_rows']:
    if z<-1000:continue
    left=x-w;right=x+w;t=max(0,min(1,(z-400)/400));t=t*t*(3-2*t)
    right=right+(398+80*((z-400)/400)-right)*t if z>400 else right
    rows.append([z,left,right])

def quad(l,r,z,zz):return np.array([[l,z],[r,z],[r,zz],[l,zz]])
def rectquad(r):x,z,w,d=r;return quad(x,x+w,z,z+d)
def intersects(a,b):return a[0]<b[0]+b[2]-1e-6 and a[0]+a[2]>b[0]+1e-6 and a[1]<b[1]+b[3]-1e-6 and a[1]+a[3]>b[1]+1e-6
def difference(a,b):
    if not intersects(a,b):return [a]
    x,z,w,d=a;xx,zz,ww,dd=b;l=max(x,xx);r=min(x+w,xx+ww);n=max(z,zz);s=min(z+d,zz+dd)
    return [p for p in [[x,z,w,n-z],[x,s,w,z+d-s],[x,n,l-x,s-n],[r,n,x+w-r,s-n]] if p[2]>1e-6 and p[3]>1e-6]
def diff_all(rects,cuts):
    for cut in cuts:rects=[p for r in rects for p in difference(r,cut)]
    return rects
def polysub(polys,cuts):
    for cut in cuts:
        lo=cut.min(axis=0);hi=cut.max(axis=0);new=[]
        for p in polys:
            v=np.array(p)[:,[0,2]]
            if np.any(v.max(axis=0)<lo+1e-7) or np.any(v.min(axis=0)>hi-1e-7):new.append(p)
            else:new.extend(subtract(p,cut))
        polys=new
    return polys
def vertices(poly,y):return [np.array([p[0],y,p[1],0,1,0,p[0]/4,p[1]/4]) for p in poly]

bands=[];water=[];ribbons=[];nav_ribbons=[]
for a,b in zip(rows,rows[1:]):
    z,l,r=a;zz,ll,rr=b;old=L['river_rects'][min(44,int((z+5+1000)//40))]
    bands.append([min(old[0]-10,l-12,ll-12),z,max(old[0]+old[2]+10,r+12,rr+12)-min(old[0]-10,l-12,ll-12),10])
    water.append([min(l,ll),z,max(r,rr)-min(l,ll),10])
    ribbons.extend([np.array([[l-12,z],[l,z],[ll,zz],[ll-12,zz]]),np.array([[r,z],[r+12,z],[rr+12,zz],[rr,zz]])])
    nav_ribbons.extend([[max(l,ll)-12,z,12-abs(ll-l),10],[max(r,rr),z,12-abs(rr-r),10]])

# Retain all horizontal bridge decks. Remove complete street/alley pieces cut by the new mouth.
removed_roads=[];kept=[]
for road in L['roads']:
    remove=not road.get('crossing_corridor',False) and road['kind']!='junction' and any(intersects(road['rect'],w) for w in water if w[1]>=400)
    (removed_roads if remove else kept).append(road)
for road in kept:
    if road['kind']!='junction':continue
    x,z,w,d=road['rect'];arms=0
    for bit,p in [(1,(x+w/2,z-.1)),(2,(x+w+.1,z+d/2)),(4,(x+w/2,z+d+.1)),(8,(x-.1,z+d/2))]:
        if any(s['kind']=='street' and s['rect'][0]<=p[0]<=s['rect'][0]+s['rect'][2] and s['rect'][1]<=p[1]<=s['rect'][1]+s['rect'][3] for s in kept):arms|=bit
    road['arms']=arms
L['roads']=kept;roadrects=[r['rect'] for r in kept];roadcuts=[rectquad(r) for r in roadrects]

# Reconnect the ordinary street-side walks to a continuous, 12m-wide river promenade.
connectors=[];bridge_walks=[]
for road in kept:
    if road['kind']=='alley':continue
    x,z,w,d=road['rect']
    options=[[x,z-4,w,4],[x,z+d,w,4]] if road['axis']==0 else [[x-4,z,4,d],[x+w,z,4,d]]
    if road['kind']=='junction':
        options=[[xx,zz,4,4] for xx in [x-4,x+w] for zz in [z-4,z+d]]
        for bit,rect in [(1,[x,z-4,w,4]),(4,[x,z+d,w,4]),(8,[x-4,z,4,d]),(2,[x+w,z,4,d])]:
            if not road['arms']&bit:options.append(rect)
    for r in options:
        for band in bands:
            if not intersects(r,band):continue
            xx=max(r[0],band[0]);zz=max(r[1],band[1]);endx=min(r[0]+r[2],band[0]+band[2]);endz=min(r[1]+r[3],band[1]+band[3])
            pieces=diff_all([[xx,zz,endx-xx,endz-zz]],roadrects)
            connectors.extend(pieces)
            if road.get('crossing_corridor',False):bridge_walks.extend(pieces)

removed_buildings=[]
for b in S['buildings']:
    rect=b['rect'];grown=[rect[0]-2,rect[1]-2,rect[2]+4,rect[3]+4]
    if any(intersects(grown,[w[0]-12,w[1],w[2]+24,w[3]]) for w in water if w[1]>=400):removed_buildings.append(b['path'])
L['buildings']=[b for b in L['buildings'] if b['node'] not in removed_buildings]

# Rectangle navigation surfaces conservatively fit inside the actual curved sidewalk.
nav=[]
for r in L['sidewalks']:nav.extend(diff_all([r],bands))
for r in connectors+nav_ribbons:
    pieces=diff_all([r],water+roadrects)
    pieces=diff_all(pieces,[v for v in nav if intersects(r,v)])
    nav.extend(p for p in pieces if min(p[2:])>=1.2)
L['sidewalks']=nav;L['river_rects']=water
L['river_curve_rows']=rows;L['river_mouth_revision']='350m eastward mouth and continuous curved promenades'

output={'replacements':[],'frontage':{},'rows':rows,'removed_buildings':removed_buildings,'removed_roads':removed_roads,'cleared_props':[]}
bandcuts=[rectquad(r) for r in bands];bandmin=np.array([q.min(axis=0) for q in bandcuts]);bandmax=np.array([q.max(axis=0) for q in bandcuts])
removedcuts=[rectquad(r['rect']) for r in removed_roads]
for record in S['meshes']:
    category=record['body'].split('/')[0];cuts=removedcuts if category=='Roads' else bandcuts
    if not cuts:continue
    mins=np.array([q.min(axis=0) for q in cuts]);maxs=np.array([q.max(axis=0) for q in cuts]);surfaces=[];changed=False
    for surface in record['surfaces']:
        result=[];vv=np.array(surface['v']).reshape(-1,3,8)
        for tri in vv:
            pp=tri[:,[0,2]];lo=pp.min(axis=0);hi=pp.max(axis=0)
            ids=np.nonzero(np.all(maxs>=lo-1e-7,axis=1)&np.all(mins<=hi+1e-7,axis=1))[0]
            if not len(ids):result.append(tri);continue
            polys=[list(tri)]
            for idx in ids:
                pieces=[];cut=cuts[idx]
                for poly in polys:
                    remaining=poly
                    for k,aa in enumerate(cut):
                        bb=cut[(k+1)%4]
                        dist=[(bb[0]-aa[0])*(v[2]-aa[1])-(bb[1]-aa[1])*(v[0]-aa[0]) for v in remaining]
                        outside=[] if dist and max(abs(v) for v in dist)<1e-6 else halfclip(remaining,aa,bb,False)
                        if len(outside)>=3:pieces.append(outside)
                        remaining=halfclip(remaining,aa,bb,True)
                        if len(remaining)<3:break
                polys=pieces
            ft=[np.array([p[0],p[k],p[k+1]]) for p in polys for k in range(1,len(p)-1) if np.linalg.norm(np.cross(p[k][:3]-p[0][:3],p[k+1][:3]-p[0][:3]))>1e-6]
            result.extend(ft)
            if len(ft)!=1 or not np.allclose(ft[0],tri):changed=True
        if result:surfaces.append({'v':np.array(result).reshape(-1,8).tolist(),'material':surface['material']})
    if changed:output['replacements'].append(dict(record,surfaces=surfaces));print('Trimmed',record['body'],flush=True)

patch={'Quay':[],'Ground':[],'Water':[],'Stone':[],'Bed':[],'Rail':[]}
connectorcuts=[rectquad(r) for r in connectors]
bridgecuts=[rectquad(r) for r in bridge_walks]
def addpoly(key,polys):patch[key].extend(flatten(polys))
for i,(a,b) in enumerate(zip(rows,rows[1:])):
    z,l,r=a;zz,ll,rr=b
    inner=np.array([[l,z],[r,z],[rr,zz],[ll,zz]])
    addpoly('Water',[vertices(inner,-1.4)]);addpoly('Bed',[vertices(inner,-12)])
    localroads=[q for q in roadcuts if q[:,1].min()<zz and q[:,1].max()>z]
    localbridges=[q for q in bridgecuts if q[:,1].min()<zz and q[:,1].max()>z]
    for ribbon in ribbons[i*2:i*2+2]:addpoly('Quay',polysub([vertices(ribbon,.03)],[*localroads,*localbridges]))
    localconnectors=[q for q in connectorcuts if q[:,1].min()<zz and q[:,1].max()>z]
    for q in localbridges:addpoly('Quay',polysub([vertices(q,.03)],localroads))
    for q in localconnectors:
        addpoly('Quay',polysub([vertices(q,.03)],[inner,*ribbons[i*2:i*2+2],*localroads,*localbridges]))
    # Fill the old rectangular quay footprints with matching city ground outside the new walks.
    addpoly('Ground',polysub([vertices(rectquad(bands[i]),0)],[inner,*ribbons[i*2:i*2+2],*localroads,*localconnectors]))
    for side,p,q in [(-1,[l,z],[ll,zz]),(1,[r,z],[rr,zz])]:
        verts=[np.array([p[0],.03,p[1],0,0,0,0,0]),np.array([p[0],-12,p[1],0,0,0,0,0]),np.array([q[0],-12,q[1],0,0,0,0,0]),np.array([q[0],.03,q[1],0,0,0,0,0])]
        if side==1:verts.reverse()
        patch['Stone'].extend([np.array([verts[0],verts[1],verts[2]]),np.array([verts[0],verts[2],verts[3]])])
        # No rail where a road or bridge sidewalk crosses the riverbank.
        if not any(abs((z+zz)/2-c)<43 for c in L['crossings']):
            pp=[p[0]+side*.18,p[1]];qq=[q[0]+side*.18,q[1]]
            v=[np.array([pp[0],.18,pp[1],0,0,0,z,0]),np.array([pp[0],1.28,pp[1],0,0,0,z,1.1]),np.array([qq[0],1.28,qq[1],0,0,0,zz,1.1]),np.array([qq[0],.18,qq[1],0,0,0,zz,0])]
            patch['Rail'].extend([np.array([v[0],v[1],v[2]]),np.array([v[0],v[2],v[3]])])
output['frontage']={k:np.array(v).reshape(-1,8).tolist() for k,v in patch.items()}
for prop in S['props']:
    x,y,z=prop['p'];near=next((w for w in water if w[1]<=z<w[1]+w[3]),None)
    if near and near[0]-1<x<near[0]+near[2]+1:output['cleared_props'].append(prop['path'])
(WORK/'build.json').write_text(json.dumps(output,separators=(',',':')))
(OUT/'layout.json').write_text(json.dumps(L,indent=2))
report={k:v for k,v in output.items() if k not in ['frontage','replacements']};report['replacements']=[{'body':r['body']} for r in output['replacements']];report['mouth_width']=rows[-1][2]-rows[-1][1]
(OUT/'report.json').write_text(json.dumps(report,indent=2))
print('Removed buildings:',removed_buildings,'roads:',len(removed_roads),'props:',len(output['cleared_props']),'mouth width:',report['mouth_width'])
