#!/usr/bin/env python3
"""Compose RhinoSmart App Store screenshots from real rendered app surfaces."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts" / "app-store-previews"
FONT_PATH = Path("/System/Library/Fonts/SFNS.ttf")
APP_ICON = ROOT / "assets" / "branding" / "rhinosmart_app_icon.png"


@dataclass(frozen=True)
class Layout:
    canvas_size: tuple[int, int]
    raw_dir: Path
    final_dir: Path
    brand_y: int
    brand_icon: int
    title_y: int
    title_size: int
    subtitle_y: int
    subtitle_size: int
    screenshot_widths: dict[str, int]
    screenshot_y: dict[str, int]
    crop_bottoms: dict[str, int]
    corner_radius: int
    shadow_blur: int


@dataclass(frozen=True)
class Preview:
    source: str
    output: str
    title: str
    subtitle: str
    decoration: Path | None = None


PREVIEWS = (
    Preview(
        source="01-plan.png",
        output="01-plan-every-trip.png",
        title="Plan Every Trip\nWith Confidence",
        subtitle="Routes, budgets, and daily spend — always in view.",
        decoration=ROOT / "assets" / "onboarding" / "track_budget.png",
    ),
    Preview(
        source="02-scan.png",
        output="02-scan-and-understand.png",
        title="Scan Prices.\nUnderstand Costs.",
        subtitle="On-device recognition keeps your receipts private.",
    ),
    Preview(
        source="03-compare.png",
        output="03-compare-before-paying.png",
        title="Compare Before\nYou Pay",
        subtitle="See fees, markups, and rewards side by side.",
        decoration=ROOT / "assets" / "onboarding" / "compare_payments.png",
    ),
    Preview(
        source="04-ledger.png",
        output="04-true-trip-cost.png",
        title="See What Your\nTrip Really Cost",
        subtitle="Every expense and final charge, all in one place.",
    ),
)


IPHONE = Layout(
    canvas_size=(1242, 2688),
    raw_dir=ARTIFACTS / "raw" / "iphone-6.5",
    final_dir=ARTIFACTS / "final" / "iphone-6.5",
    brand_y=84,
    brand_icon=84,
    title_y=228,
    title_size=104,
    subtitle_y=505,
    subtitle_size=38,
    screenshot_widths={
        "01-plan.png": 1090,
        "02-scan.png": 1090,
        "03-compare.png": 1030,
        "04-ledger.png": 1000,
    },
    screenshot_y={
        "01-plan.png": 735,
        "02-scan.png": 700,
        "03-compare.png": 680,
        "04-ledger.png": 665,
    },
    crop_bottoms={
        "01-plan.png": 1545,
        "02-scan.png": 1990,
        "03-compare.png": 2340,
        "04-ledger.png": 2520,
    },
    corner_radius=58,
    shadow_blur=46,
)


IPAD = Layout(
    canvas_size=(2064, 2752),
    raw_dir=ARTIFACTS / "raw" / "ipad-13",
    final_dir=ARTIFACTS / "final" / "ipad-13",
    brand_y=96,
    brand_icon=112,
    title_y=254,
    title_size=132,
    subtitle_y=594,
    subtitle_size=50,
    screenshot_widths={preview.source: 1840 for preview in PREVIEWS},
    screenshot_y={
        "01-plan.png": 790,
        "02-scan.png": 720,
        "03-compare.png": 790,
        "04-ledger.png": 785,
    },
    crop_bottoms={
        "01-plan.png": 1050,
        "02-scan.png": 2310,
        "03-compare.png": 1560,
        "04-ledger.png": 1850,
    },
    corner_radius=78,
    shadow_blur=62,
)


def sf_font(size: int, weight: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_PATH), size=size)
    try:
        font.set_variation_by_axes(
            [100, min(max(size, 17), 96), max(weight - 80, 400), weight]
        )
    except (AttributeError, OSError):
        pass
    return font


def flattened(image: Image.Image, background=(255, 255, 255)) -> Image.Image:
    source = image.convert("RGBA")
    result = Image.new("RGB", source.size, background)
    result.paste(source, mask=source.getchannel("A"))
    return result


def rounded_asset(path: Path, size: int, radius: int) -> Image.Image:
    source = flattened(Image.open(path))
    source = ImageOps.fit(source, (size, size), method=Image.Resampling.LANCZOS)
    mask = Image.new("L", source.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result.paste(source, mask=mask)
    return result


def add_top_contrast(canvas: Image.Image, fade_height: int) -> None:
    overlay = Image.new("RGBA", canvas.size, (0, 15, 57, 0))
    alpha = Image.new("L", canvas.size, 0)
    draw = ImageDraw.Draw(alpha)
    for y in range(fade_height):
        opacity = round(150 * (1 - y / fade_height) ** 1.55)
        draw.line((0, y, canvas.width, y), fill=opacity)
    overlay.putalpha(alpha)
    canvas.alpha_composite(overlay)


def brand_background(size: tuple[int, int]) -> Image.Image:
    """Draw the blue brand field without external generated-background files."""
    width, height = size
    top = (7, 95, 255)
    bottom = (7, 27, 82)
    canvas = Image.new("RGB", size)
    draw = ImageDraw.Draw(canvas)
    for y in range(height):
        ratio = y / max(1, height - 1)
        color = tuple(round(a * (1 - ratio) + b * ratio) for a, b in zip(top, bottom))
        draw.line((0, y, width, y), fill=color)
    canvas = canvas.convert("RGBA")
    decoration = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(decoration)
    for inset in range(0, 4):
        offset = round(width * inset * 0.075)
        draw.ellipse(
            (round(width * 0.60) + offset, -round(width * 0.62) - offset,
             round(width * 1.58) + offset, round(width * 0.36) + offset),
            outline=(207, 232, 255, 24), width=max(2, width // 440),
        )
    canvas.alpha_composite(decoration)
    return canvas


def add_brand(canvas: Image.Image, layout: Layout) -> None:
    x = round(canvas.width * 0.066)
    icon = rounded_asset(
        APP_ICON, layout.brand_icon, max(18, round(layout.brand_icon * 0.22))
    )
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle(
        (
            x,
            layout.brand_y + 6,
            x + layout.brand_icon,
            layout.brand_y + layout.brand_icon + 6,
        ),
        radius=round(layout.brand_icon * 0.22),
        fill=95,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(16))
    shadow.paste((0, 4, 35, 130), mask=shadow_mask)
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(icon, (x, layout.brand_y))
    draw = ImageDraw.Draw(canvas)
    brand_font = sf_font(round(layout.brand_icon * 0.46), 660)
    draw.text(
        (x + layout.brand_icon + round(layout.brand_icon * 0.25),
         layout.brand_y + round(layout.brand_icon * 0.19)),
        "RhinoSmart",
        font=brand_font,
        fill=(255, 255, 255, 255),
    )


def add_copy(canvas: Image.Image, layout: Layout, preview: Preview) -> None:
    x = round(canvas.width * 0.066)
    draw = ImageDraw.Draw(canvas)
    mint = (94, 243, 205, 255)
    bar_width = 76 if canvas.width < 1500 else 112
    bar_height = 10 if canvas.width < 1500 else 14
    draw.rounded_rectangle(
        (x, layout.title_y - 38, x + bar_width, layout.title_y - 38 + bar_height),
        radius=bar_height // 2,
        fill=mint,
    )
    draw.multiline_text(
        (x, layout.title_y),
        preview.title,
        font=sf_font(layout.title_size, 780),
        fill=(255, 255, 255, 255),
        spacing=6 if canvas.width < 1500 else 10,
    )
    draw.text(
        (x, layout.subtitle_y),
        preview.subtitle,
        font=sf_font(layout.subtitle_size, 510),
        fill=(214, 229, 255, 255),
    )


def add_decoration(
    canvas: Image.Image, layout: Layout, preview: Preview, frame_y: int
) -> None:
    if preview.decoration is None:
        return
    source = Image.open(preview.decoration).convert("RGBA")
    if layout.canvas_size[0] < 1500:
        width = 730 if preview.source == "01-plan.png" else 600
        x = canvas.width - width + 55
        y = frame_y + (1030 if preview.source == "01-plan.png" else 1350)
    else:
        width = 1040 if preview.source == "01-plan.png" else 900
        x = canvas.width - width + 70
        y = frame_y + (780 if preview.source == "01-plan.png" else 1110)
    height = round(source.height * width / source.width)
    source = source.resize((width, height), Image.Resampling.LANCZOS)
    canvas.alpha_composite(source, (x, y))


def screenshot_panel(
    source_path: Path,
    crop_bottom: int,
    target_width: int,
    radius: int,
    shadow_blur: int,
) -> tuple[Image.Image, Image.Image]:
    source = flattened(Image.open(source_path))
    crop_bottom = min(crop_bottom, source.height)
    source = source.crop((0, 0, source.width, crop_bottom))
    target_height = round(source.height * target_width / source.width)
    source = source.resize((target_width, target_height), Image.Resampling.LANCZOS)

    mask = Image.new("L", source.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, source.width - 1, source.height - 1), radius=radius, fill=255
    )
    panel = Image.new("RGBA", source.size, (0, 0, 0, 0))
    panel.paste(source, mask=mask)
    border = ImageDraw.Draw(panel)
    border.rounded_rectangle(
        (1, 1, panel.width - 2, panel.height - 2),
        radius=radius,
        outline=(255, 255, 255, 125),
        width=3 if target_width < 1500 else 4,
    )

    shadow_margin = shadow_blur * 2
    shadow = Image.new(
        "RGBA",
        (panel.width + shadow_margin * 2, panel.height + shadow_margin * 2),
        (0, 0, 0, 0),
    )
    shadow_mask = Image.new("L", shadow.size, 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle(
        (
            shadow_margin,
            shadow_margin + round(shadow_blur * 0.32),
            shadow_margin + panel.width,
            shadow_margin + panel.height + round(shadow_blur * 0.32),
        ),
        radius=radius,
        fill=145,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(shadow_blur))
    shadow.paste((0, 8, 40, 165), mask=shadow_mask)
    return panel, shadow


def compose(layout: Layout, preview: Preview) -> Path:
    canvas = brand_background(layout.canvas_size)
    add_top_contrast(canvas, 760 if canvas.width < 1500 else 820)
    add_brand(canvas, layout)
    add_copy(canvas, layout, preview)

    target_width = layout.screenshot_widths[preview.source]
    frame_y = layout.screenshot_y[preview.source]
    add_decoration(canvas, layout, preview, frame_y)
    panel, shadow = screenshot_panel(
        layout.raw_dir / preview.source,
        layout.crop_bottoms[preview.source],
        target_width,
        layout.corner_radius,
        layout.shadow_blur,
    )
    frame_x = (canvas.width - panel.width) // 2
    margin = layout.shadow_blur * 2
    canvas.alpha_composite(shadow, (frame_x - margin, frame_y - margin))
    canvas.alpha_composite(panel, (frame_x, frame_y))

    layout.final_dir.mkdir(parents=True, exist_ok=True)
    output = layout.final_dir / preview.output
    canvas.convert("RGB").save(output, format="PNG", optimize=True)
    return output


def contact_sheet(paths: list[Path], name: str) -> Path:
    """Keep one review sheet for each established App Store output group."""
    gap = 18
    thumb_width = 320 if name == "ipad-13" else 260
    size = Image.open(paths[0]).size
    thumb_height = round(size[1] * thumb_width / size[0])
    sheet = Image.new("RGB", (len(paths) * (thumb_width + gap) + gap,
                              thumb_height + gap * 2), "#E8EFED")
    for index, path in enumerate(paths):
        with Image.open(path) as source:
            thumbnail = source.convert("RGB").resize(
                (thumb_width, thumb_height), Image.Resampling.LANCZOS
            )
        sheet.paste(thumbnail, (gap + index * (thumb_width + gap), gap))
    output = ARTIFACTS / "qa" / f"contact-sheet-{name}.jpg"
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, quality=92, optimize=True)
    return output


def write_preview_manifest() -> None:
    """Document real inputs and stable outputs for the specialized compositor."""
    items = []
    layouts = (("iphone-6.5", IPHONE), ("ipad-13", IPAD),
               ("iphone-dynamic-island", IPHONE))
    for name, layout in layouts:
        for preview in PREVIEWS:
            items.append({
                "kind": "screenshot",
                "locale": "en-US",
                "source": str((layout.raw_dir / preview.source).relative_to(ARTIFACTS)),
                "output": f"final/{name}/{preview.output}",
                "size": [1206, 2622] if name == "iphone-dynamic-island" else list(layout.canvas_size),
                "headline": preview.title.replace("\n", " "),
                "subheadline": preview.subtitle,
            })
    manifest = {
        "schema_version": 2,
        "store": "app_store",
        "app_name": "RhinoSmart",
        "icon": "../../assets/branding/rhinosmart_app_icon.png",
        "font_path": str(FONT_PATH),
        "qa_dir": "qa",
        "renderer": "python3 tool/generate_app_store_previews.py && python3 tool/generate_dynamic_island_previews.py",
        "provenance": "Existing iOS Flutter-rendered deterministic UI captures reused unchanged; brand overlay regenerated on 2026-11-03. Dynamic Island images adapt the 6.5-inch composition; no new device capture is claimed.",
        "defaults": {"background_top": "#075FFF", "background_bottom": "#071B52"},
        "items": items,
    }
    (ARTIFACTS / "preview-spec.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> None:
    outputs = [
        compose(layout, preview)
        for layout in (IPHONE, IPAD)
        for preview in PREVIEWS
    ]
    for output in outputs:
        print(output.relative_to(ROOT))
    for layout in (IPHONE, IPAD):
        paths = [layout.final_dir / preview.output for preview in PREVIEWS]
        print(contact_sheet(paths, layout.final_dir.name).relative_to(ROOT))
    write_preview_manifest()


if __name__ == "__main__":
    main()
