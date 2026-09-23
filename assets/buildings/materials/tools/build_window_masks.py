"""Recover complete POI glass masks from authored emission tiles (no model edits)."""
from pathlib import Path
import numpy as np
from PIL import Image

BASE = Path(__file__).resolve().parents[2]
OUTPUT = BASE / "materials" / "window_masks"
# name, original imported texture, cell dimensions, separate arch/rectangle halves
SOURCES = [
    ("bank1", "bank1/bank1_bank1_windows_emission.png", (128, 128), True),
    ("bank1_great", "bank1/bank1_bank1_great_window_emission.png", None, False),
    ("bank2", "bank2/bank2_bank2_windows_emission.png", (128, 128), False),
    ("police_station", "police_station/police_station_police_station_windows_emission.png", (128, 128), False),
    ("city_hall", "city_hall/city_hall_city_hall_windows_emission.png", (128, 128), True),
    ("hospital", "hospital/hospital_hospital_windows_emission.png", (128, 128), False),
    ("hospital_curtain", "hospital/hospital_hospital_curtain_emission.png", (128, 85), False),
    ("firehouse", "firehouse/firehouse_firehouse_details_emission.png", None, False),
]

def build():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, source, cell, split_arches in SOURCES:
        # Work in the author's bottom-up coordinates, then restore PNG orientation.
        pixels = np.asarray(Image.open(BASE / source).convert("RGB"))[::-1]
        glass = pixels.max(axis=2) > 0
        result = glass.copy() if cell is None else np.zeros_like(glass)
        if cell:
            width, height = cell
            rows, cols = glass.shape[0] // height, glass.shape[1] // width
            for start, end in ([(0, rows//2), (rows//2, rows)] if split_arches else [(0, rows)]):
                silhouette = np.zeros((height, width), dtype=bool)
                for y in range(start, end):
                    for x in range(cols):
                        silhouette |= glass[y*height:(y+1)*height, x*width:(x+1)*width]
                assert silhouette.any(), f"No glass found: {name}"
                for y in range(start, end):
                    for x in range(cols):
                        result[y*height:(y+1)*height, x*width:(x+1)*width] = silhouette
        assert np.all(result[glass]), f"Authored glass lost: {name}"
        Image.fromarray(result[::-1].astype(np.uint8) * 255).save(OUTPUT / (name + ".png"))
        print(name, "glass pixels", int(result.sum()))

if __name__ == "__main__":
    build()
