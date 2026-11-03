#!/usr/bin/env python3
"""Resize the supplied RhinoSmart artwork into the app's branding assets.

Run from any directory with Python 3 and Pillow installed. The source artwork
is kept intact; no cropping, recoloring, or generated replacement is applied.
"""

from __future__ import annotations

import json
from decimal import Decimal
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/rhinosmart_app_icon.png"


def main() -> None:
    with Image.open(SOURCE) as original:
        if original.width != original.height:
            raise ValueError("The app icon source must be square")
        if "A" in original.getbands() and original.getextrema()[-1] != (255, 255):
            raise ValueError("The app icon source must be fully opaque")
        icon = original.convert("RGB")

    def save(relative_path: str | Path, edge: int, mode: str = "RGB") -> None:
        destination = ROOT / relative_path
        icon.resize((edge, edge), Image.Resampling.LANCZOS).convert(mode).save(destination)

    appicon = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
    contents = json.loads((ROOT / appicon / "Contents.json").read_text())
    generated = set()
    for entry in contents["images"]:
        edge = int(Decimal(entry["size"].split("x")[0]) * Decimal(entry["scale"][:-1]))
        filename = entry["filename"]
        if filename not in generated:
            save(appicon / filename, edge)
            generated.add(filename)

    for density, edge in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", edge)

    save("website/assets/app-icon.png", 512)
    # Play listing icons require 32-bit PNG; keep all supplied pixels opaque.
    save("artifacts/google-play-listing/app-icon-512.png", 512, "RGBA")
    save("assets/branding/launch_mark.png", 512)
    save("android/app/src/main/res/drawable-nodpi/launch_mark.png", 160)
    for appearance in ("", "-dark"):
        for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
            save(
                f"ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{appearance}{suffix}.png",
                96 * scale,
            )

    print(f"Generated {len(generated) + 15} RhinoSmart app icons and launch assets.")


if __name__ == "__main__":
    main()
