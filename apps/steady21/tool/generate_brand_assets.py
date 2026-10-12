"""Build platform icons and native launch marks from the onboarding artwork."""

import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/onboarding/seed.png"
IOS = ROOT / "ios/Runner/Assets.xcassets"
ANDROID = ROOT / "android/app/src/main/res"
PAPER = "#F7F1E6"


def cropped_art():
    image = Image.open(SOURCE).convert("RGBA")
    visible = image.getchannel("A").point(lambda value: 255 if value > 28 else 0)
    return image.crop(visible.getbbox())


def fit_art(art, size, fraction):
    edge = round(size * fraction)
    fitted = ImageOps.contain(art, (edge, edge), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    return canvas


def main():
    art = cropped_art()
    icon = Image.new("RGBA", (1024, 1024), PAPER)
    icon.alpha_composite(fit_art(art, 1024, 0.86))
    icon = icon.convert("RGB")
    icon.save(ROOT / "assets/brand/app_icon.png", optimize=True)

    icon_set = IOS / "AppIcon.appiconset"
    contents = json.loads((icon_set / "Contents.json").read_text())
    for entry in contents["images"]:
        if "filename" not in entry:
            continue
        logical_size = float(entry["size"].split("x")[0])
        pixels = round(logical_size * int(entry["scale"][0]))
        icon.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
            icon_set / entry["filename"], optimize=True
        )

    for scale in (1, 2, 3):
        name = "LaunchImage.png" if scale == 1 else f"LaunchImage@{scale}x.png"
        fit_art(art, 168 * scale, 0.9).save(
            IOS / "LaunchImage.imageset" / name, optimize=True
        )

    for density, scale in (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
                           ("xxhdpi", 3), ("xxxhdpi", 4)):
        icon_edge = round(48 * scale)
        icon.resize((icon_edge, icon_edge), Image.Resampling.LANCZOS).save(
            ANDROID / f"mipmap-{density}" / "ic_launcher.png", optimize=True
        )
        launch_edge = round(180 * scale)
        (ANDROID / f"drawable-{density}").mkdir(parents=True, exist_ok=True)
        fit_art(art, launch_edge, 0.9).save(
            ANDROID / f"drawable-{density}" / "launch_mark.png", optimize=True
        )

    foreground = fit_art(art, 432, 0.58)
    foreground.save(ANDROID / "drawable-nodpi" / "ic_launcher_foreground.png", optimize=True)


if __name__ == "__main__":
    main()
