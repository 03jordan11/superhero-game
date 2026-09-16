"""Offline original starscape. Run with Python + NumPy; no external sky assets.
Writes linear RGB half-float cube faces; pack_starscape.gd creates GPU resources.
Cube face convention: +X, -X, +Y, -Y, +Z, -Z, image rows top to bottom.
"""
from pathlib import Path
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'artifacts' / 'starscape_bake'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').write_text('')
SEED = 842119
GALAXY_SIZE = 1024
STAR_SIZE = 2048
rng = np.random.default_rng(SEED)
# Direction = normalize(center + u*right + v*down).
FRAMES = np.array([
    [[1,0,0],[0,0,-1],[0,-1,0]],
    [[-1,0,0],[0,0,1],[0,-1,0]],
    [[0,1,0],[1,0,0],[0,0,1]],
    [[0,-1,0],[1,0,0],[0,0,-1]],
    [[0,0,1],[1,0,0],[0,-1,0]],
    [[0,0,-1],[-1,0,0],[0,-1,0]],
], dtype=np.float32)


def normalize(v):
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def directions(face, u, v):
    center, right, down = FRAMES[face]
    return normalize(center + u[...,None]*right + v[...,None]*down)


def noise(p):
    cell = np.floor(p).astype(np.int32)
    f = p - cell
    f = f*f*(3-2*f)
    result = np.zeros(p.shape[:-1], np.float32)
    for x in range(2):
        for y in range(2):
            for z in range(2):
                h = ((cell[...,0]+x).astype(np.uint32)*np.uint32(374761393)
                    + (cell[...,1]+y).astype(np.uint32)*np.uint32(668265263)
                    + (cell[...,2]+z).astype(np.uint32)*np.uint32(2246822519))
                h = (h ^ (h >> 13))*np.uint32(1274126177)
                h ^= h >> 16
                weight = (f[...,0] if x else 1-f[...,0])*(f[...,1] if y else 1-f[...,1])*(f[...,2] if z else 1-f[...,2])
                result += (h.astype(np.float32)/4294967295)*weight
    return result


normal = normalize(np.array([.35,.83,.43],np.float32))
axis_a = normalize(np.cross(normal,np.array([0,0,1],np.float32)))
axis_b = np.cross(normal,axis_a)
core = normalize(axis_a*.7 + axis_b*.7)


def galaxy(d):
    # All detail is a continuous function of 3D direction, including face boundaries.
    broad = noise(d*4.3+12.7)
    medium = noise(d*15.0+3.2)
    fine = noise(d*49.0+17.1)
    grain = noise(d*160.0+31.2)
    latitude = np.sum(d*normal,axis=-1)
    bulge = np.exp((np.sum(d*core,axis=-1)-1)*3.8)
    warp = (broad-.5)*.08
    band = np.exp(-((latitude+warp)/(.105+.10*bulge))**2)
    veil = np.exp(-(latitude/.29)**2)*.018
    clouds = .25 + medium*.9 + fine*.28 + grain*.12
    lane_center = (medium-.5)*.05 + np.sin(np.sum(d*axis_a,axis=-1)*7)*.015
    lane = np.exp(-((latitude-lane_center)/(.012+.023*broad))**2)
    dust = 1-lane*(.68+.23*fine)
    strength = (band*(.095+.29*bulge)*clouds*dust + veil)*(.65+.65*broad)
    cool = np.array([.48,.62,.95],np.float32)
    warm = np.array([1.0,.79,.56],np.float32)
    tint = cool + (warm-cool)*bulge[...,None]*.8
    tint += np.array([.08,-.015,.075],np.float32)*(medium[...,None]-.45)
    return np.maximum(strength[...,None]*tint,0).astype(np.float32)


# Uniform sphere field plus a dense galactic population. No lat/long raster.
field = normalize(rng.normal(size=(75000,3)))
longitude = rng.uniform(0,np.pi*2,145000)
latitude = np.clip(rng.normal(0,.12,145000),-.7,.7)
band_stars = (np.cos(latitude)[:,None]*(np.cos(longitude)[:,None]*axis_a + np.sin(longitude)[:,None]*axis_b)
              + np.sin(latitude)[:,None]*normal)
stars = np.concatenate([field,band_stars])
count = len(stars)
brightness = rng.uniform(.055,.30,count)
bright = rng.random(count)<.035
brightness[bright] = rng.uniform(.5,2.4,bright.sum())
beacons = rng.choice(count,180,replace=False)
brightness[beacons] = rng.uniform(2.8,6.0,len(beacons))
sigma = rng.uniform(.00034,.00059,count)
sigma[bright] *= 1.25
sigma[beacons] *= 1.5
palette = np.array([[.80,.89,1.0],[1.0,.96,.85],[1.0,.77,.51],[.65,.78,1.0],[1.0,.87,.70]])
colors = palette[rng.choice(len(palette),count,p=[.34,.33,.08,.17,.08])]


def star_face(face, size):
    center,right,down = FRAMES[face]
    denom = stars @ center
    front = np.flatnonzero(denom>.01)
    u = (stars[front]@right)/denom[front]
    v = (stars[front]@down)/denom[front]
    selected = (np.abs(u)<1.015)&(np.abs(v)<1.015)
    indices,u,v = front[selected],u[selected],v[selected]
    result = np.zeros((size,size,3),np.float32)
    for index,uc,vc in zip(indices,u,v):
        cx,cy=(uc+1)*size*.5-.5,(vc+1)*size*.5-.5
        # A Gaussian in angular space stays round across cube edges and corners.
        footprint = 2/size/(1+uc*uc+vc*vc)
        effective_sigma = np.sqrt(sigma[index]**2 + (footprint*.28)**2)
        radius = max(2,int(np.ceil(3.6*effective_sigma/footprint)))
        x0,x1=max(0,int(np.floor(cx))-radius),min(size,int(np.floor(cx))+radius+2)
        y0,y1=max(0,int(np.floor(cy))-radius),min(size,int(np.floor(cy))+radius+2)
        if x0>=x1 or y0>=y1:
            continue
        py,px=np.mgrid[y0:y1,x0:x1]
        d=directions(face,(px+.5)/size*2-1,(py+.5)/size*2-1)
        dist2=np.sum((d-stars[index])**2,axis=-1)
        core_value=np.exp(-dist2/(2*effective_sigma**2))
        energy = sigma[index]**2/effective_sigma**2
        value=core_value*brightness[index]*energy
        result[y0:y1,x0:x1]+=value[...,None]*colors[index]
    return result


for face in range(6):
    result=np.empty((GALAXY_SIZE,GALAXY_SIZE,3),np.float32)
    for y0 in range(0,GALAXY_SIZE,128):
        y,x=np.mgrid[y0:y0+128,:GALAXY_SIZE].astype(np.float32)
        result[y0:y0+128]=galaxy(directions(face,(x+.5)/GALAXY_SIZE*2-1,(y+.5)/GALAXY_SIZE*2-1))
    result.astype('<f2').tofile(OUT/f'galaxy_{face}.rgbh')
    star_face(face,STAR_SIZE).astype('<f2').tofile(OUT/f'stars_{face}.rgbh')
    print(f'Baked cube face {face+1}/6',flush=True)

manifest={'seed':SEED,'stars':count,'galaxy_face_size':GALAXY_SIZE,'stars_face_size':STAR_SIZE,
          'face_order':['+X','-X','+Y','-Y','+Z','-Z'],'format':'linear RGB half float',
          'provenance':'Original procedural galaxy and synthetic spherical star distribution; no external images.'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('STARSCAPE_BAKE_COMPLETE',flush=True)
