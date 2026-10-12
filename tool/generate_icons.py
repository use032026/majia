"""Generate the original FilePeek icon and platform raster sizes.

Requires Pillow. The source geometry and colors live here so the asset can be
regenerated without using a store screenshot or competitor artwork.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SIZE = 2048
OUT = ROOT / "assets" / "branding" / "filepeek_icon_1024.png"

canvas = Image.new("RGB", (SIZE, SIZE))
pixels = canvas.load()
for y in range(SIZE):
    t = y / (SIZE - 1)
    color = (
        round(13 + 1 * t),
        round(63 + 37 * t),
        round(67 + 34 * t),
    )
    for x in range(SIZE):
        pixels[x, y] = color

base = canvas.convert("RGBA")
accent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
a = ImageDraw.Draw(accent)
a.ellipse((1210, -500, 2630, 920), fill=(130, 225, 211, 22))
a.ellipse((-540, 1370, 700, 2610), fill=(93, 212, 197, 18))
base = Image.alpha_composite(base, accent)

shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
s = ImageDraw.Draw(shadow)
s.rounded_rectangle((444, 302, 1450, 1752), radius=150, fill=(0, 0, 0, 95))
s.ellipse((1020, 1030, 1870, 1880), fill=(0, 0, 0, 105))
base = Image.alpha_composite(base, shadow.filter(ImageFilter.GaussianBlur(95)))

draw = ImageDraw.Draw(base)
draw.rounded_rectangle((400, 240, 1410, 1670), radius=150, fill=(239, 250, 247, 255))
draw.polygon([(1120, 240), (1410, 530), (1120, 530)], fill=(186, 225, 218, 255))
draw.line([(1120, 240), (1120, 530), (1410, 530)], fill=(133, 195, 188, 255), width=28, joint="curve")

# Three restrained data rows remain legible at small launcher sizes.
for y, bar in [(710, 515), (935, 435), (1160, 335)]:
    draw.rounded_rectangle((570, y, 675, y + 105), radius=28, fill=(35, 146, 143, 255))
    draw.rounded_rectangle((755, y + 16, 755 + bar, y + 86), radius=34, fill=(112, 174, 174, 255))

# A single confirmation lens carries the product's inspect-and-recheck idea.
draw.ellipse((995, 1010, 1845, 1860), fill=(10, 78, 81, 255))
draw.ellipse((995, 1010, 1845, 1860), outline=(119, 229, 215, 255), width=82)
draw.line([(1190, 1430), (1350, 1585), (1658, 1265)], fill=(239, 250, 247, 255), width=106, joint="curve")
for x, y in [(1190, 1430), (1350, 1585), (1658, 1265)]:
    draw.ellipse((x - 53, y - 53, x + 53, y + 53), fill=(239, 250, 247, 255))

OUT.parent.mkdir(parents=True, exist_ok=True)
master = base.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
master.save(OUT, optimize=True)

catalog = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
contents = json.loads((catalog / "Contents.json").read_text())
for item in contents["images"]:
    filename = item.get("filename")
    if not filename:
        continue
    side = round(float(item["size"].split("x")[0]) * int(item["scale"].rstrip("x")))
    master.resize((side, side), Image.Resampling.LANCZOS).save(catalog / filename, optimize=True)

for density, side in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    target = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}" / "ic_launcher.png"
    master.resize((side, side), Image.Resampling.LANCZOS).save(target, optimize=True)

print(OUT)
