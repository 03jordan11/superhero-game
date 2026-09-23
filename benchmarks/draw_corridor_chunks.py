"""Render the saved corridor membership over the city planning-map snapshot."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
from build_city_planning_map import DATA, font

ROOT = Path(__file__).resolve().parents[1]
chunks = json.loads((ROOT / "assets/super-city/chunks/corridor_chunks.json").read_text())["chunks"]
members = {path.rsplit("/", 1)[-1]: c["side"] for c in chunks for path in c["members"]}
image = Image.new("RGB", (3200, 1520), "#f5f3ed")
draw = ImageDraw.Draw(image)
scale = 3040 / 1910
colours = {"Left": "#277f93", "Right": "#b96f3b"}


def pixel(p):
    return 80 + (p[0] + 1560) * scale, 200 + (p[1] + 820) * scale


def label(text, p, size=28):
    draw.text(pixel(p), text, anchor="mm", font=font(size, True), fill="#273643", stroke_width=4, stroke_fill="#f5f3ed")


layer = Image.new("RGB", image.size, "#f5f3ed")
paint = ImageDraw.Draw(layer)
for kind, polygon in DATA["areas"]:
    paint.polygon([pixel(p) for p in polygon], fill="#d2e3eb" if kind == "water" else "#e2e8d8")
for polygon in DATA["roads"]:
    paint.polygon([pixel(p) for p in polygon], fill="#d3d2ce")
for building in DATA["buildings"]:
    colour = colours.get(members.get(building[0]), "#bcbdb9")
    paint.polygon([pixel(p) for p in building[2]], fill=colour)
crop = (80, 200, 3120, round(pixel((350, -140))[1]))
image.paste(layer.crop(crop), crop)
for chunk in chunks:
    x, z, w, h = chunk["cell"]
    draw.rectangle((*pixel((x, z)), *pixel((x+w, z+h))), outline=colours[chunk["side"]], width=4)
    label_z = -770 if chunk["side"] == "Left" else -185
    label(f"{chunk['name'].replace('_', ' ')} · {len(chunk['members'])} buildings", (x+w/2, label_z), 26)
label("City Hall — excluded", (-301, -402.8), 29)
label("Looking east →", (-760, -480), 28)
tx, tz = pixel((-1286.5, -478.6))
draw.line((tx-13, tz, tx+13, tz), fill="#273643", width=5)
draw.line((tx, tz-13, tx, tz+13), fill="#273643", width=5)
label("FPS test", (-1360, -480), 26)
draw.text((80, 40), "CORRIDOR / 250 METRE BUILDING CHUNKS", font=font(52, True), fill="#273643")
draw.text((80, 115), "7 left + 7 right • 386 whole buildings • negative Z up / east to the right", font=font(30), fill="#273643")
draw.text((80, 1340), "Left / north", font=font(30, True), fill=colours["Left"])
draw.text((410, 1340), "Right / south", font=font(30, True), fill=colours["Right"])
draw.text((790, 1340), "Grey buildings are outside this trial. City Hall remains separate.", font=font(29), fill="#273643")
draw.text((80, 1400), "Each cell is 250 × 250 m; whole buildings are assigned by bounds centre. Final cells stop taking members at the river (X = 100 m).", font=font(27), fill="#273643")
draw.text((80, 1450), "Grouping only: no replacement LOD meshes or distance switching are enabled yet.", font=font(27), fill="#273643")
output = ROOT / "artifacts/city_planning_map/corridor_chunks.png"
output.parent.mkdir(parents=True, exist_ok=True)
image.save(output)
print(output)
