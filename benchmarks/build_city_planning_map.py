"""Draw planning maps from export_city_planning_map.gd output (requires Pillow).

Optional --fragment points to an inline map template to refresh its embedded data.
No game assets or scenes are changed.
"""
import argparse
import json
import math
import re
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "artifacts/city_planning_map"
DATA = json.loads((DEST / "layout.json").read_text(encoding="utf-8"))
PALETTE = dict(background="#f5f3ed", roads="#d3d2ce", buildings="#49677a", poi="#ac653c", water="#d2e3eb", park="#d9e4cf", ink="#273643", grid="#a1acb1")
FONTS = Path("C:/Windows/Fonts")


def font(size, bold=False):
    return ImageFont.truetype(str(FONTS / ("segoeuib.ttf" if bold else "segoeui.ttf")), size)


def centre(building):
    p = building[2]
    return sum(v[0] for v in p) / len(p), sum(v[1] for v in p) / len(p)


def draw_map(grid=0):
    image = Image.new("RGB", (3800, 2800), PALETTE["background"])
    draw = ImageDraw.Draw(image)
    points = [p for b in DATA["buildings"] for p in b[2]]
    xmin = math.floor(min(p[0] for p in points) / 100) * 100
    xmax = math.ceil(max(p[0] for p in points) / 100) * 100
    zmin = math.floor(min(p[1] for p in points) / 100) * 100 - 50
    zmax = math.ceil(max(p[1] for p in points) / 100) * 100 + 100
    box = (150, 250, 3650, 2370)
    scale = min((box[2] - box[0]) / (xmax - xmin), (box[3] - box[1]) / (zmax - zmin))
    ox = (box[0] + box[2] - (xmax - xmin) * scale) / 2
    oz = box[1]

    def pixel(p):
        return ox + (p[0] - xmin) * scale, oz + (p[1] - zmin) * scale

    # Clip ocean and connecting roads to the city map extent.
    layer = Image.new("RGB", image.size, PALETTE["background"])
    paint = ImageDraw.Draw(layer)
    for category, polygon in DATA["areas"]:
        paint.polygon([pixel(p) for p in polygon], fill=PALETTE[category])
    for polygon in DATA["roads"]:
        paint.polygon([pixel(p) for p in polygon], fill=PALETTE["roads"])
    for building in DATA["buildings"]:
        paint.polygon([pixel(p) for p in building[2]], fill=PALETTE["poi" if building[1] == "Landmark" else "buildings"])
    if grid:
        for x in range(math.ceil(xmin / grid) * grid, int(xmax) + 1, grid):
            paint.line([pixel((x, zmin)), pixel((x, zmax))], fill=PALETTE["grid"], width=2)
        for z in range(math.ceil(zmin / grid) * grid, int(zmax) + 1, grid):
            paint.line([pixel((xmin, z)), pixel((xmax, z))], fill=PALETTE["grid"], width=2)
    crop = (round(ox), round(oz), round(ox + (xmax - xmin) * scale), round(oz + (zmax - zmin) * scale))
    image.paste(layer.crop(crop), crop)

    def text_label(text, x, z, size=32):
        draw.text(pixel((x, z)), text, font=font(size, True), fill=PALETTE["ink"], anchor="mm", stroke_width=5, stroke_fill=PALETTE["background"])

    districts = defaultdict(list)
    for b in DATA["buildings"]:
        if b[1] != "Landmark":
            districts[b[1]].append(centre(b))
    for name, pts in districts.items():
        label = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name)
        text_label(label, sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    text_label("Central Park", -292, 0)
    text_label("RIVER", 285, 0, 28)

    names = {"GasStationHideout": "Gas station", "CityHall": "City hall", "PoliceStation": "Police station", "BoxingGymExterior": "Boxing gym"}
    for i, (name, x, z) in enumerate(DATA["landmarks"], 1):
        px, py = pixel((x, z))
        draw.ellipse((px-19, py-19, px+19, py+19), fill=PALETTE["background"], outline=PALETTE["poi"], width=3)
        draw.text((px, py-1), str(i), anchor="mm", font=font(23, True), fill=PALETTE["poi"])
        label = names.get(name, re.sub(r"(?<=[a-z])(?=[A-Z0-9])", " ", name))
        cx, cy = 160 + ((i-1) % 4) * 900, 2530 + ((i-1) // 4) * 48
        draw.text((cx, cy), f"{i:02d}  {label}", font=font(26), fill=PALETTE["ink"])

    test = (-1286.5, -478.6)
    tx, tz = pixel(test)
    draw.line((tx-15, tz, tx+15, tz), fill=PALETTE["ink"], width=5)
    draw.line((tx, tz-15, tx, tz+15), fill=PALETTE["ink"], width=5)
    text_label("FPS test", test[0]+65, test[1]+36, 26)

    for x in range(math.ceil(xmin / 500) * 500, int(xmax)+1, 500):
        px, _ = pixel((x, zmin))
        draw.text((px, 220), f"X {x:,} m", anchor="ms", font=font(25), fill=PALETTE["ink"])
    for z in range(math.ceil(zmin / 500) * 500, int(zmax)+1, 500):
        _, py = pixel((xmin, z))
        draw.text((ox-18, py), f"{z:,}", anchor="rm", font=font(25), fill=PALETTE["ink"])

    draw.text((150, 60), "CITY / OVERHEAD PLANNING MAP", font=font(58, True), fill=PALETTE["ink"])
    regular = sum(b[1] != "Landmark" for b in DATA["buildings"])
    subtitle = f"Saved Main scene • {regular:,} regular buildings + {len(DATA['landmarks'])} landmark sites • metres • −Z up / +X right"
    draw.text((153, 142), subtitle, font=font(28), fill=PALETTE["ink"])
    draw.text((3650, 106), f"{grid} m candidate grid" if grid else "Current layout", anchor="rm", font=font(34), fill=PALETTE["ink"])
    draw.line((150, 2460, 150+500*scale, 2460), fill=PALETTE["ink"], width=5)
    draw.text((150, 2418), "500 metres", font=font(26), fill=PALETTE["ink"])
    draw.text((920, 2435), "Building bounds     •     Numbered landmark sites     •     Cross = measured FPS position", font=font(28), fill=PALETTE["ink"])
    draw.text((150, 2750), "Planning footprints use mesh bounds; landmark sites include grounds/props. Outer terrain, small props and runtime actors are omitted.", font=font(24), fill=PALETTE["ink"])
    path = DEST / (f"city_overhead_grid_{grid}m.png" if grid else "city_overhead.png")
    image.save(path)
    print(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--fragment", type=Path)
    args = parser.parse_args()
    assert len(DATA["buildings"]) == len({b[0] for b in DATA["buildings"]}), "Duplicate building roots"
    assert DATA["buildings"] and DATA["roads"], "Empty city export"
    draw_map()
    draw_map(250)
    if args.fragment:
        source = args.fragment.read_text(encoding="utf-8")
        compact = json.dumps(DATA, separators=(",", ":"))
        source, count = re.subn(r'(<script type="application/json" data-layout>).*?(</script>)', lambda m: m[1]+compact+m[2], source, flags=re.S)
        assert count == 1
        assert len(source.encode("utf-8")) < 1_000_000
        args.fragment.write_text(source, encoding="utf-8")
        print(f"Inline map: {len(source.encode('utf-8')):,} bytes")
