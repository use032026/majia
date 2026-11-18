"""Render the ISDFX SVG into native launcher, launch and Flutter assets.

Requires Python 3 and ImageMagick 7 (magick).
"""

import json
from pathlib import Path
import re
import subprocess
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)



def render_master(square=False):
    icon = ET.parse(ROOT / "branding/icon.svg").getroot()
    if square:
        tile = icon.find(f"{{{SVG}}}path[@id='tile']")
        icon.remove(tile)
        icon.insert(0, ET.Element(f"{{{SVG}}}rect", {
            "width": "160",
            "height": "160",
            "fill": tile.attrib["fill"],
        }))
    # Render above the largest requested size for clean downsampling.
    icon.set("width", "2048")
    icon.set("height", "2048")
    return subprocess.run(
        ["magick", "-background", "none", "SVG:-", "-strip", "PNG32:-"],
        input=ET.tostring(icon),
        capture_output=True,
        check=True,
    ).stdout


def write_png(master, path, size, opaque=False):
    png_format = "PNG24" if opaque else "PNG32"
    subprocess.run(
        [
            "magick", "PNG:-", "-filter", "Lanczos", "-resize", f"{size}x{size}",
            "-strip", "-define", "png:exclude-chunks=date,time", f"{png_format}:{path}",
        ],
        input=master,
        check=True,
    )


def write_android_foreground(path):
    icon = ET.parse(ROOT / "branding/icon.svg").getroot()
    motif_paths = [item for item in icon if item.attrib.get("id") != "tile"]
    # The 160-unit tile becomes the 72dp visible area on a 108dp layer.
    # Its farthest motif vertex is 32.6dp from center, inside the 33dp safe radius.
    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
        '    android:width="108dp" android:height="108dp"',
        '    android:viewportWidth="108" android:viewportHeight="108">',
        '  <group android:scaleX="0.45" android:scaleY="0.45"',
        '      android:translateX="18" android:translateY="18">',
    ]
    for item in motif_paths:
        lines.extend([
            f'    <path android:fillColor="{item.attrib["fill"]}"',
            f'        android:pathData="{item.attrib["d"]}" />',
        ])
    lines.extend(['  </group>', '</vector>'])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def flutter_path(source):
    # The master uses one absolute command per segment, with space-separated coordinates.
    methods = {"M": ("moveTo", 2), "C": ("cubicTo", 6), "L": ("lineTo", 2),
               "H": ("lineTo", 1), "V": ("lineTo", 1), "Z": ("close", 0)}
    x = y = "0"
    for command, values in re.findall(r"([A-Za-z])([^A-Za-z]*)", source):
        method, length = methods[command]
        args = values.split()
        if len(args) != length or any(not re.fullmatch(r"-?\d+(\.\d+)?", arg) for arg in args):
            raise ValueError(f"Unsupported mark segment: {command}{values}")
        if command == "H":
            args = [args[0], y]
        elif command == "V":
            args = [x, args[0]]
        if args:
            x, y = args[-2:]
        yield f"      ..{method}({', '.join(args)})"


def write_flutter_mark(path):
    icon = ET.parse(ROOT / "branding/icon.svg").getroot()
    _, _, width, height = icon.attrib["viewBox"].split()
    layers = []
    for item in icon:
        outline = "\n".join(flutter_path(item.attrib["d"]))
        color = item.attrib["fill"].removeprefix("#").lower()
        layers.append(f"  (\n    Path()\n{outline},\n    const Color(0xff{color}),\n  ),")
    path.write_text(
        "// Generated from branding/icon.svg by tool/generate_brand_assets.py.\n"
        "// Draws synchronously so the mark is present on the first Flutter frame.\n"
        "import 'dart:ui';\n\n"
        "final List<(Path, Color)> _layers = [\n" + "\n".join(layers) + "\n];\n\n"
        "void paintIsdfxMark(Canvas canvas, Size size) {\n"
        "  canvas.save();\n"
        f"  canvas.scale(size.width / {width}, size.height / {height});\n"
        "  final paint = Paint();\n"
        "  for (final (path, color) in _layers) {\n"
        "    canvas.drawPath(path, paint..color = color);\n"
        "  }\n"
        "  canvas.restore();\n"
        "}\n",
        encoding="utf-8",
    )


def main():
    square = render_master(square=True)
    rounded = render_master()
    assets = ROOT / "ios/Runner/Assets.xcassets"
    ios_icons = assets / "AppIcon.appiconset"
    contents = json.loads((ios_icons / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        scale = float(entry["scale"].removesuffix("x"))
        write_png(square, ios_icons / entry["filename"], round(points * scale), opaque=True)

    launch = assets / "LaunchImage.imageset"
    for suffix, scale in [("", 1), ("@2x", 2), ("@3x", 3)]:
        write_png(rounded, launch / f"LaunchImage{suffix}.png", 80 * scale)

    res = ROOT / "android/app/src/main/res"
    for density, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        write_png(rounded, res / f"mipmap-{density}/ic_launcher.png", size)
    write_android_foreground(res / "drawable/ic_isdfx_foreground.xml")
    write_png(rounded, ROOT / "branding/mark.png", 192)
    write_flutter_mark(ROOT / "lib/ui/widgets/brand_mark.g.dart")
    print("ISDFX icon and launch assets regenerated.")


if __name__ == "__main__":
    main()
