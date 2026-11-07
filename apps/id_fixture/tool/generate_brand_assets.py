"""Reproduce original ID Fixture vector geometry in native icon assets.

All geometry is authored for this project; Pillow is only a rasterizer.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

def raster(size, transparent=False):
    scale = 32
    canvas = Image.new('RGBA', (64 * scale, 64 * scale), (0, 0, 0, 0) if transparent else '#1a5044')
    draw = ImageDraw.Draw(canvas)
    def stroke(points, color):
        coords = [(int(x * scale), int(y * scale)) for x, y in points]
        width = round(3.5 * scale)
        draw.line(coords, fill=color, width=width, joint='curve')
        r = width / 2
        for x, y in [coords[0], coords[-1]]:
            draw.ellipse((x-r, y-r, x+r, y+r), fill=color)
    stroke([(23,18),(16,18),(16,46),(23,46)], '#d8f1b0')
    stroke([(41,18),(48,18),(48,46),(41,46)], '#d8f1b0')
    stroke([(30,26),(34,22),(34,42)], '#ffffff')
    stroke([(28,42),(40,42)], '#ffffff')
    image = canvas.resize((size,size), Image.Resampling.LANCZOS)
    return image if transparent else image.convert('RGB')

icons=ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
contents=json.loads((icons/'Contents.json').read_text())
for entry in contents['images']:
    size=round(float(entry['size'].split('x')[0])*float(entry['scale'][:-1]))
    raster(size).save(icons/entry['filename'])
launch=ROOT/'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for suffix, factor in [('',1),('@2x',2),('@3x',3)]:
    raster(80*factor).save(launch/f'LaunchImage{suffix}.png')
res=ROOT/'android/app/src/main/res'
for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    raster(size).save(res/f'mipmap-{density}/ic_launcher.png')
print('Original platform icons and native launch images regenerated.')
