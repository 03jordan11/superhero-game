"""Rasterize saved world triangles into a static, north-up map; no camera or AI art.

Requires numpy and Pillow. Run export_region_map.gd first.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'artifacts/minimap'
meta = json.loads((DEST / 'region_geometry.json').read_text())
x0, z0, x1, z1 = meta['bounds_xz']
SCALE = 0.75
W, H = round((x1-x0)*SCALE), round((z1-z0)*SCALE)
depth = np.full((H, W), -np.inf, np.float32)
kind = np.zeros((H, W), np.uint8)
triangles = np.fromfile(DEST / 'region_triangles.bin', dtype='<f4').reshape(-1, 10)
assert len(triangles) == meta['triangle_count']
for n, row in enumerate(triangles):
    cat = int(row[0])
    v = row[1:].reshape(3, 3)
    px, py = (v[:, 0]-x0)*SCALE, (v[:, 2]-z0)*SCALE
    left, right = max(0, int(np.floor(px.min()))), min(W-1, int(np.ceil(px.max())))
    top, bottom = max(0, int(np.floor(py.min()))), min(H-1, int(np.ceil(py.max())))
    if left > right or top > bottom:
        continue
    denom = (py[1]-py[2])*(px[0]-px[2])+(px[2]-px[1])*(py[0]-py[2])
    if abs(denom) < 1e-8:
        continue
    # Tile large ground triangles to bound temporary allocation.
    for ty in range(top, bottom+1, 128):
        by = min(bottom+1, ty+128)
        yy, xx = np.ogrid[ty:by, left:right+1]
        a = ((py[1]-py[2])*(xx+0.5-px[2])+(px[2]-px[1])*(yy+0.5-py[2]))/denom
        b = ((py[2]-py[0])*(xx+0.5-px[2])+(px[0]-px[2])*(yy+0.5-py[2]))/denom
        c = 1-a-b
        heights = a*v[0,1]+b*v[1,1]+c*v[2,1]
        target = depth[ty:by, left:right+1]
        mask = (a >= -1e-6) & (b >= -1e-6) & (c >= -1e-6) & (heights >= target)
        target[mask] = heights[mask]
        kind[ty:by, left:right+1][mask] = cat
    if n % 25000 == 0:
        print(f'Rasterized {n:,}/{len(triangles):,}', flush=True)

# Flat cartographic colors. All geometry boundaries remain fixed.
palette = np.array([[25,81,96], [120,143,111], [151,148,129],
                    [63,103,79], [214,207,187], [52,66,70],
                    [242,227,181], [35,61,72], [171,126,70], [135,151,147]], dtype=np.float32)
rgb = palette[kind]
height = np.where(np.isfinite(depth), depth, -1.4)
terrain = (kind == 1) | (kind == 2)
dz, dx = np.gradient(height)
shade = np.clip((dx-dz)*0.024, -0.12, 0.12)
rgb *= np.where(terrain, 1+shade, 1)[..., None]
# Contours derive exclusively from the exported terrain elevation.
contours = terrain & (height > 35) & (np.mod(height, 25) < 0.9)
rgb[contours] *= 0.78
edge = np.zeros((H,W), bool)
edge[1:] |= kind[1:] != kind[:-1]
edge[:,1:] |= kind[:,1:] != kind[:,:-1]
rgb[edge] *= 0.72
image = Image.fromarray(np.clip(rgb, 0, 255).astype('uint8'))
image.save(DEST / 'accurate_region_map_v3.png')
image.resize((1800, round(H*1800/W)), Image.Resampling.LANCZOS).save(DEST / 'accurate_region_map_v3_preview.png')
# A crop at full resolution lets the user inspect the dense city road network.
city_box = tuple(round(v*SCALE) for v in (-1600-x0, -1100-z0, 1650-x0, 900-z0))
image.crop(city_box).save(DEST / 'accurate_region_map_v3_city_detail.png')
meta.update({'image': 'accurate_region_map_v3.png', 'width': W, 'height': H,
             'pixels_per_metre': SCALE, 'mapping': 'u=(x-x_min)*pixels_per_metre; v=(z-z_min)*pixels_per_metre',
             'categories_key': ['water','ground','rock','vegetation','paving','runway','markings','buildings','landmarks','urban_ground'],
             'visible_pixel_counts': {str(i): int((kind==i).sum()) for i in range(10)}})
(DEST / 'accurate_region_map_v3.json').write_text(json.dumps(meta, indent=2)+'\n')
print(f'Saved {W}x{H} accurate_region_map_v3.png', flush=True)
