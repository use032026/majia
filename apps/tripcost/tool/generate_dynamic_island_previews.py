#!/usr/bin/env python3
"""Adapt the approved 6.5-inch App Store set to Apple's current iPhone slot."""

from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "artifacts" / "app-store-previews" / "final" / "iphone-6.5"
OUTPUT = (
    ROOT
    / "artifacts"
    / "app-store-previews"
    / "final"
    / "iphone-dynamic-island"
)
TARGET_SIZE = (1206, 2622)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sources = sorted(SOURCE.glob("*.png"))
    if not sources:
        raise SystemExit(f"No approved App Store previews found in {SOURCE}")

    for source in sources:
        with Image.open(source) as image:
            output = ImageOps.fit(
                image.convert("RGB"),
                TARGET_SIZE,
                method=Image.Resampling.LANCZOS,
                centering=(0.5, 0.5),
            )
            destination = OUTPUT / source.name
            output.save(destination, format="PNG", optimize=True)
            print(destination.relative_to(ROOT))


if __name__ == "__main__":
    main()
