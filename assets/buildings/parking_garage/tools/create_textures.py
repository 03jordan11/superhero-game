"""Small authored texture atlas; run with Python + Pillow before build_garage.py."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import random

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'textures'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(218)
for name, base in [('concrete', (160, 163, 159)), ('asphalt', (62, 67, 70))]:
    image = Image.new('RGB', (256, 256))
    image.putdata([tuple(max(0, min(255, c + rng.randint(-7, 7))) for c in base) for _ in range(256*256)])
    if name == 'concrete':
        draw = ImageDraw.Draw(image)
        for y in range(0, 256, 64):
            draw.line((0, y, 256, y), fill=(143, 146, 142))
    image.save(OUT / f'{name}.png')
atlas = Image.new('RGB', (1024, 512), (20, 68, 79))
draw = ImageDraw.Draw(atlas)
font_path = 'C:/Windows/Fonts/arialbd.ttf'
for i, label in enumerate(['P', 'IN', 'OUT', 'UP', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', 'PARK', 'EXIT']):
    x, y = (i % 8)*128, (i // 8)*256
    draw.rounded_rectangle((x+5, y+5, x+123, y+251), radius=8, outline=(190, 220, 214), width=4)
    font = ImageFont.truetype(font_path, 78 if len(label) <= 2 else 39)
    draw.text((x+64, y+128), label, font=font, anchor='mm', fill=(239, 236, 208))
atlas.save(OUT / 'signs.png')
