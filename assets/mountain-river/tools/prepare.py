"""Build the Main-only river corridor and prune mountain-obscured tree instances.
Run inspect.gd first. Uses the saved scene geometry, never regenerates the city.
"""
from pathlib import Path
import json, re, shutil, hashlib, math
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT/'artifacts/river_mountains'
OUT = ROOT/'assets/mountain-river'
SRC = json.loads((WORK/'source.json').read_text())
LAYOUT = json.loads((ROOT/'assets/super-city/layout.json').read_text())

def backup():
    if (WORK/'baseline.json').exists(): return
    records = {}
    for rel in ['scenes/main.tscn','scenes/city_life.tscn','scenes/coastal_region.tscn','scenes/super_city.tscn','scenes/waterfront.tscn','scenes/central_park.tscn','assets/super-city/layout.json','assets/super-city/pedestrians/network.json']:
        p=ROOT/rel; dest=WORK/'before'/rel; dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,dest); records[rel]=hashlib.sha256(p.read_bytes()).hexdigest()
    (WORK/'baseline.json').write_text(json.dumps(records,indent=2))

def triangles(source):
    s=source['surfaces'][0]; v=np.array(s['vertices']); c=np.array(s['colors'])
    if not len(c): c=np.ones((len(v),4))
    a=np.concatenate([v,c],axis=1)
    return a[np.array(s['indices']).reshape(-1,3)] if s['indices'] else a.reshape(-1,3,7)

MOUNTAINS=triangles(SRC['meshes']['PinePassMountains'])
T=MOUNTAINS[:,:,:3]; P=T[:,:,[0,2]]; A=P[:,0]; B=P[:,1]-A; C=P[:,2]-A
DET=B[:,0]*C[:,1]-B[:,1]*C[:,0]; VALID=abs(DET)>1e-7; DET=np.where(VALID,DET,1)

def mountain_height(x,z):
    d=np.array([x,z])-A
    u=(d[:,0]*C[:,1]-d[:,1]*C[:,0])/DET
    w=(B[:,0]*d[:,1]-B[:,1]*d[:,0])/DET
    mask=VALID&(u>=-1e-6)&(w>=-1e-6)&(u+w<=1+1e-6)
    y=T[:,0,1]+u*(T[:,1,1]-T[:,0,1])+w*(T[:,2,1]-T[:,0,1])
    return max([-.09,*y[mask]])

def smooth(z, knots):
    """Cubic Hermite interpolation, bounded tangents at extrema."""
    zs=np.array([p[0] for p in knots]); vs=np.array([p[1] for p in knots]); slopes=np.diff(vs)/np.diff(zs)
    tang=[slopes[0]]+[0 if slopes[i-1]*slopes[i]<=0 else (slopes[i-1]+slopes[i])/2 for i in range(1,len(slopes))]+[slopes[-1]]
    i=max(0,min(len(zs)-2,int(np.searchsorted(zs,z)-1))); d=zs[i+1]-zs[i]; t=(z-zs[i])/d
    return (2*t**3-3*t*t+1)*vs[i]+(t**3-2*t*t+t)*d*tang[i]+(-2*t**3+3*t*t)*vs[i+1]+(t**3-t*t)*d*tang[i+1]

# Ordered north to south. Narrow headwater widens gradually into the city river.
XK=[(-3160,490),(-3000,410),(-2790,370),(-2590,210),(-2380,250),(-2150,130),(-1860,325),(-1590,300),(-1330,130),(-1140,160),(-1000,180),(-720,250),(-440,190),(-160,140),(80,240),(320,360),(560,320),(800,180)]
YK=[(-3160,160),(-3040,120),(-2890,65),(-2680,20),(-2500,2),(-2370,-1.4),(800,-1.4)]
WK=[(-3160,0),(-3140,20),(-3100,25),(-2900,28),(-2600,35),(-2100,45),(-1400,52),(800,52)]

def city_x(z):
    # Round the original bends without Hermite overshoot into existing streets.
    knots=XK[-8:];zs=np.array([k[0] for k in knots]);xs=np.array([k[1] for k in knots])
    offsets=np.arange(-60,61,5);weights=np.exp(-.5*(offsets/20)**2);samples=z+offsets
    values=np.interp(samples,zs,xs)
    values=np.where(samples<zs[0],xs[0]+(samples-zs[0])*(xs[1]-xs[0])/(zs[1]-zs[0]),values)
    values=np.where(samples>zs[-1],xs[-1]+(samples-zs[-1])*(xs[-1]-xs[-2])/(zs[-1]-zs[-2]),values)
    return float(np.sum(values*weights)/weights.sum())

def row(z): return [float(z),city_x(z) if z>=-1000 else smooth(z,XK),smooth(z,YK),smooth(z,WK)]
ROWS=[row(z) for z in range(-3160,801,10)]
def bed_y(z): return smooth(z,YK)-8

def halfclip(poly,a,b,inside=True):
    # Clip XY here means world XZ; all other vertex attributes interpolate.
    if not len(poly): return []
    def dist(p): return (b[0]-a[0])*(p[2]-a[1])-(b[1]-a[1])*(p[0]-a[0])
    result=[]; last=poly[-1]; dl=dist(last); il=dl>=-1e-7 if inside else dl<=1e-7
    for p in poly:
        dp=dist(p); ip=dp>=-1e-7 if inside else dp<=1e-7
        if ip!=il: result.append(last+(p-last)*(dl/(dl-dp)))
        if ip: result.append(p)
        last=p;dl=dp;il=ip
    return result

def subtract(poly,quad):
    remaining=poly; pieces=[]
    for i,a in enumerate(quad):
        b=quad[(i+1)%len(quad)]
        out=halfclip(remaining,a,b,False)
        if len(out)>=3: pieces.append(out)
        remaining=halfclip(remaining,a,b,True)
        if len(remaining)<3: break
    return pieces

def area(tri):
    a,b,c=tri;return abs((b[0]-a[0])*(c[2]-a[2])-(b[2]-a[2])*(c[0]-a[0]))

def flatten(polys):
    return [np.array([p[0],p[i],p[i+1]]) for p in polys for i in range(1,len(p)-1) if area([p[0],p[i],p[i+1]])>1e-6]

# Convex trapezoids form one continuous channel; only Main's terrain is cut.
QUADS=[]
for a,b in zip(ROWS,ROWS[1:]):
    if b[0]>-1000:break
    z,x,y,w=a;zz,xx,yy,ww=b
    q=np.array([[x-w,z],[x+w,z],[xx+ww,zz],[xx-ww,zz]])
    QUADS.append(q)
QMIN=np.array([q.min(axis=0) for q in QUADS]); QMAX=np.array([q.max(axis=0) for q in QUADS])

def clip_terrain(name,source):
    original=triangles(source); output=[]; changed=0
    for tri in original:
        p=tri[:,[0,2]];lo=p.min(axis=0);hi=p.max(axis=0)
        candidates=np.nonzero(np.all(QMAX>=lo,axis=1)&np.all(QMIN<=hi,axis=1))[0]
        if not len(candidates): output.append(tri);continue
        polys=[list(tri)]
        for idx in candidates:polys=[piece for poly in polys for piece in subtract(poly,QUADS[idx])]
        output.extend(flatten(polys));changed+=1
    a=np.array(output).reshape(-1,7)
    return {'vertices':a[:,:3].tolist(),'colors':a[:,3:].tolist(),'before':len(original),'after':len(output),'touched':changed}

def bank_edges():
    # Split at mountain triangle edges so the new canyon walls meet the cut rock exactly.
    edges=[]
    ep=P.reshape(-1,2); en=P[:,[1,2,0]].reshape(-1,2); ev=en-ep
    for a,b in zip(ROWS,ROWS[1:]):
        if b[0]>-1000:break
        for side in [-1,1]:
            start=np.array([a[1]+side*a[3],a[0]]);end=np.array([b[1]+side*b[3],b[0]]);d=end-start
            det=d[0]*ev[:,1]-d[1]*ev[:,0];valid=abs(det)>1e-8;den=np.where(valid,det,1)
            delta=ep-start;tt=(delta[:,0]*ev[:,1]-delta[:,1]*ev[:,0])/den;uu=(delta[:,0]*d[1]-delta[:,1]*d[0])/den
            cuts=sorted(set([0.,1.,*np.round(tt[valid&(tt>0)&(tt<1)&(uu>=0)&(uu<=1)],8)]))
            for f,g in zip(cuts,cuts[1:]):
                p=start+d*f;q=start+d*g
                # Water/bed interpolation must exactly match the rendered segment, not the spline between samples.
                py=a[2]+(b[2]-a[2])*f-8;qy=a[2]+(b[2]-a[2])*g-8
                edges.append({'side':side,'a':[p[0],mountain_height(*p),p[1]],'b':[q[0],mountain_height(*q),q[1]],'bed_a':py,'bed_b':qy})
    return edges

def behind_range(x,z):
    # Test city-to-tree sightline against the actual seven mountain base outlines.
    if z>=-1800:return False
    for peak in [(-2550,-2850,800),(-2700,-3850,1300),(-1600,-3900,1000),(-1000,-3750,820),(50,-3400,850),(1000,-2900,850),(1900,-3650,1200)]:
        px,pz,r=peak;poly=[]
        for i in range(18):
            a=i/18*math.tau; rr=r*(1+math.sin(a*5+px)*.16+math.cos(a*3)*.08)
            poly.append((px+math.cos(a)*rr,pz+math.sin(a)*rr))
        for a,b in zip(poly,poly[1:]+poly[:1]):
            ex,ez=b[0]-a[0],b[1]-a[1];d=x*ez-z*ex
            if abs(d)<1e-7:continue
            t=(a[0]*ez-a[1]*ex)/d;u=(a[0]*z-a[1]*x)/d
            if 0<t<1 and 0<=u<=1:return True
    return False

def path_of(block):
    m=re.match(r'\[node name="([^"]+)"[^\n]*? parent="([^"]+)"',block)
    return ((m[2]+'/' if m[2]!='.' else '')+m[1]) if m else ''

def prune_trees():
    removed={};counts={}
    for scene,trees in SRC['trees'].items():
        if not trees:continue
        rows=[]
        for tree in trees:
            x,y,z=tree['position'];r=tree['radius'];reason=None
            if any(mountain_height(x+dx,z+dz)>y+.5 for dx,dz in [(0,0),(r,0),(-r,0),(0,r),(0,-r)]):reason='inside_mountain'
            elif behind_range(x,z):reason='behind_mountains'
            elif -3180-r<z<-1000+r and abs(x-smooth(max(-3160,min(-1000,z)),XK))<smooth(max(-3160,min(-1000,z)),WK)+r+9:reason='river_clearance'
            if reason:rows.append(dict(tree,reason=reason))
        removed[scene]=rows;paths={r['path'] for r in rows}
        text=(WORK/'before'/f'scenes/{scene}.tscn').read_text(encoding='utf-8')
        blocks=re.split(r'(?=^\[(?:node|editable|connection)\b)',text,flags=re.M)
        kept=[]
        for b in blocks:
            p=path_of(b);m=re.match(r'\[editable path="([^"]+)"',b)
            if m:p=m[1]
            if not any(p==v or p.startswith(v+'/') for v in paths):kept.append(b)
        updated=''.join(kept)
        if scene=='city_life': updated=re.sub(r'(&"background_trees": )\d+',lambda m:m[1]+str(len(trees)-len(rows)),updated)
        if scene=='coastal_region': updated=re.sub(r'(metadata/tree_count = )\d+',lambda m:m[1]+str(len(trees)-len(rows)),updated)
        (ROOT/f'scenes/{scene}.tscn').write_text(updated,encoding='utf-8')
        counts[scene]={'before':len(trees),'after':len(trees)-len(rows),'removed':len(rows),'reasons':{k:sum(r['reason']==k for r in rows) for k in ['inside_mountain','behind_mountains','river_clearance']}}
    return removed,counts

if __name__=='__main__':
    backup()
    build={'rows':ROWS,'terrain':{},'walls':SRC['walls'],'bank_edges':bank_edges()}
    for name,source in SRC['meshes'].items():
        build['terrain'][name]=clip_terrain(name,source);print(name,{k:v for k,v in build['terrain'][name].items() if k not in ['vertices','colors']},flush=True)
    removed,counts=prune_trees()
    (WORK/'build.json').write_text(json.dumps(build,separators=(',',':')))
    original_park=(WORK/'before/scenes/central_park.tscn').read_text(encoding='utf-8')
    tree_ids=re.findall(r'^\[ext_resource[^\n]*path="res://assets/trees/[^"/]+\.tscn"[^\n]*id="([^"]+)"',original_park,re.M)
    park_count=sum(len(re.findall(r'^\[node[^\n]*instance=ExtResource\("'+re.escape(rid)+r'"\)',original_park,re.M)) for rid in tree_ids)
    report={'tree_counts':counts,'before_tree_counts':dict({s:d['before'] for s,d in counts.items()},central_park=park_count),'source_hashes':json.loads((WORK/'baseline.json').read_text()),'removed_trees':removed,'river_rows':ROWS,'terrain':{n:{k:v for k,v in d.items() if k not in ['vertices','colors']} for n,d in build['terrain'].items()},'tree_pruning_view_origin':[0,0,0]}
    (OUT/'report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(counts,indent=2))
