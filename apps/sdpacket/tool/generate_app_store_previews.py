#!/usr/bin/env python3
"""Generate KIFXPRO App Store preview artwork from approved UI captures."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts" / "app-store-previews"
SOURCES = ARTIFACTS / "source"
FINAL = ARTIFACTS / "final"
QA = ARTIFACTS / "qa"

FONT_PATH = ROOT / "assets" / "fonts" / "NotoSansSC-VF.ttf"
ICON_PATH = ROOT / "assets" / "branding" / "app_icon_master.png"
HOME_PATH = ROOT / "Docs" / "design" / "home_projects_final.png"
DETAIL_PATH = ROOT / "Docs" / "design" / "project_detail_option3_simulator_pass2.png"
TRACK_PATH = ROOT / "assets" / "onboarding" / "track_move.png"
PAD_HOME_PATH = SOURCES / "ipad-runtime-home.png"
PAD_DETAIL_PATH = SOURCES / "ipad-runtime-detail.png"

PHONE_SIZE = (1242, 2688)
PAD_SIZE = (2732, 2048)

INK = "#10201D"
MUTED = "#52635F"
GREEN = "#0F765F"
CREAM = "#F7F3EA"
CORAL = "#EF715B"


def font(size: int, weight: str = "Regular") -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(str(FONT_PATH), size=size)
    try:
        face.set_variation_by_name(weight)
    except OSError:
        pass
    return face


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)


def rounded(image: Image.Image, radius: int) -> Image.Image:
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius=radius, fill=255)
    image.putalpha(mask)
    return image


def paste_shadowed(
    canvas: Image.Image,
    image: Image.Image,
    position: tuple[int, int],
    *,
    radius: int,
    shadow_blur: int = 34,
    shadow_offset: tuple[int, int] = (0, 24),
    shadow_alpha: int = 72,
    border: int = 0,
    border_color: str = "#FFFFFF",
) -> None:
    x, y = position
    content = rounded(image, radius)
    if border:
        framed = Image.new(
            "RGBA",
            (content.width + border * 2, content.height + border * 2),
            border_color,
        )
        framed = rounded(framed, radius + border)
        framed.alpha_composite(content, (border, border))
        content = framed
        x -= border
        y -= border

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_shape = Image.new("RGBA", content.size, (15, 42, 36, shadow_alpha))
    shadow_shape = rounded(shadow_shape, radius + border)
    shadow.alpha_composite(
        shadow_shape,
        (x + shadow_offset[0], y + shadow_offset[1]),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(content, (x, y))


def text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    value: str,
    *,
    size: int,
    fill: str,
    weight: str = "Regular",
    anchor: str | None = None,
) -> None:
    draw.text(xy, value, font=font(size, weight), fill=fill, anchor=anchor)


def brand_lockup(canvas: Image.Image, *, x: int, y: int, light: bool, scale: float = 1.0) -> None:
    icon_size = int(76 * scale)
    icon = rounded(cover(Image.open(ICON_PATH), (icon_size, icon_size)), int(18 * scale))
    canvas.alpha_composite(icon, (x, y))
    draw = ImageDraw.Draw(canvas)
    text(
        draw,
        (x + icon_size + int(22 * scale), y + icon_size // 2),
        "KIFXPRO",
        size=int(34 * scale),
        weight="Bold",
        fill="#FFFFFF" if light else INK,
        anchor="lm",
    )


def phone_copy(
    canvas: Image.Image,
    headline: str,
    subhead: str,
    *,
    light: bool,
) -> None:
    draw = ImageDraw.Draw(canvas)
    primary = "#FFFFFF" if light else INK
    secondary = "#D8E5DF" if light else MUTED
    brand_lockup(canvas, x=96, y=104, light=light)
    text(draw, (96, 242), headline, size=76, weight="Bold", fill=primary)
    text(draw, (98, 356), subhead, size=37, weight="Medium", fill=secondary)


def phone_screen(source: Path, width: int = 868) -> Image.Image:
    image = Image.open(source).convert("RGB")
    height = round(width * image.height / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def qr_glyph(size: int, color: str = GREEN) -> Image.Image:
    glyph = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glyph)
    unit = max(4, size // 18)
    stroke = max(5, size // 13)
    corner = size // 3
    for x, y in ((unit, unit), (size - unit - corner, unit), (unit, size - unit - corner)):
        draw.rounded_rectangle((x, y, x + corner, y + corner), radius=stroke, outline=color, width=stroke)
        inner = stroke * 2
        draw.rectangle((x + inner, y + inner, x + corner - inner, y + corner - inner), fill=color)
    blocks = [
        (11, 10), (13, 10), (10, 12), (12, 12), (14, 12),
        (10, 14), (12, 14), (14, 14), (14, 16), (16, 14),
    ]
    for gx, gy in blocks:
        x = gx * size // 18
        y = gy * size // 18
        draw.rectangle((x, y, x + unit, y + unit), fill=color)
    return glyph


def scan_callout(width: int, height: int, *, landscape: bool = False) -> Image.Image:
    card = Image.new("RGBA", (width, height), "#FFFDF8")
    card = rounded(card, 48 if landscape else 42)
    draw = ImageDraw.Draw(card)
    glyph_size = 152 if landscape else 126
    card.alpha_composite(qr_glyph(glyph_size), (54, (height - glyph_size) // 2))
    tx = 54 + glyph_size + 42
    text(draw, (tx, height // 2 - 34), "扫码更新箱子状态", size=40 if landscape else 32, weight="Bold", fill=INK)
    text(draw, (tx, height // 2 + 30), "本地记录 · 进度清晰", size=28 if landscape else 24, weight="Medium", fill=MUTED)
    draw.ellipse((width - 92, height // 2 - 18, width - 56, height // 2 + 18), fill=CORAL)
    return card


def build_phone(index: int) -> Path:
    specs = {
        1: (
            SOURCES / "iphone-01-bg.png",
            "搬家流程，一目了然",
            "项目、箱子与进度集中管理",
            HOME_PATH,
            True,
        ),
        2: (
            SOURCES / "iphone-02-bg.png",
            "每个箱子，都有迹可循",
            "照片、物品、房间和标签随手记录",
            DETAIL_PATH,
            False,
        ),
        3: (
            SOURCES / "iphone-03-bg.png",
            "扫码推进，离线也安心",
            "现场批量更新状态，遗漏及时发现",
            DETAIL_PATH,
            True,
        ),
    }
    bg, headline, subhead, source, light = specs[index]
    canvas = cover(Image.open(bg), PHONE_SIZE).convert("RGBA")
    if index == 1:
        overlay = Image.new("RGBA", PHONE_SIZE, (0, 0, 0, 0))
        ImageDraw.Draw(overlay).rectangle((0, 0, PHONE_SIZE[0], 610), fill=(4, 45, 35, 45))
        canvas.alpha_composite(overlay)
    phone_copy(canvas, headline, subhead, light=light)

    screen = phone_screen(source)
    paste_shadowed(canvas, screen, ((PHONE_SIZE[0] - screen.width) // 2, 602), radius=76, border=12)

    if index == 3:
        callout = scan_callout(930, 190)
        paste_shadowed(canvas, callout, (156, 2150), radius=42, shadow_blur=28, shadow_offset=(0, 18))
        track = Image.open(TRACK_PATH).convert("RGBA")
        track.thumbnail((310, 310), Image.Resampling.LANCZOS)
        canvas.alpha_composite(track, (890, 2295))

    out = FINAL / f"iphone-6.5-{index:02d}.png"
    canvas.convert("RGB").save(out, optimize=True)
    return out


def crop_panel(source: Path, crop: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    image = Image.open(source).convert("RGB").crop(crop)
    return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)


def pad_copy(
    canvas: Image.Image,
    headline: str,
    subhead: str,
    *,
    light: bool,
    centered: bool = False,
) -> None:
    draw = ImageDraw.Draw(canvas)
    primary = "#FFFFFF" if light else INK
    secondary = "#D8E5DF" if light else MUTED
    if centered:
        brand_lockup(canvas, x=136, y=90, light=light, scale=0.92)
        text(draw, (PAD_SIZE[0] // 2, 112), headline, size=76, weight="Bold", fill=primary, anchor="ma")
        text(draw, (PAD_SIZE[0] // 2, 220), subhead, size=34, weight="Medium", fill=secondary, anchor="ma")
    else:
        brand_lockup(canvas, x=150, y=150, light=light, scale=1.05)
        text(draw, (150, 345), headline, size=82, weight="Bold", fill=primary)
        text(draw, (154, 470), subhead, size=36, weight="Medium", fill=secondary)


def build_pad(index: int) -> Path:
    specs = {
        1: (
            SOURCES / "ipad-01-bg.png",
            "搬家流程，一目了然",
            "项目、箱子与进度集中管理",
            True,
        ),
        2: (
            SOURCES / "ipad-02-bg.png",
            "每个箱子，都有迹可循",
            "照片、物品、房间和标签随手记录",
            False,
        ),
        3: (
            SOURCES / "ipad-03-bg.png",
            "扫码推进，离线也安心",
            "现场批量更新状态，遗漏及时发现",
            True,
        ),
    }
    bg, headline, subhead, light = specs[index]
    canvas = cover(Image.open(bg), PAD_SIZE).convert("RGBA")

    if index == 1:
        pad_copy(canvas, headline, subhead, light=light, centered=False)
        home = cover(Image.open(PAD_HOME_PATH), (1700, 1275))
        paste_shadowed(canvas, home, (875, 430), radius=58, border=10, shadow_blur=36)
    elif index == 2:
        pad_copy(canvas, headline, subhead, light=light, centered=True)
        detail = cover(Image.open(PAD_DETAIL_PATH), (1900, 1425))
        paste_shadowed(canvas, detail, (416, 410), radius=58, border=10, shadow_blur=38)
        find = Image.open(ROOT / "assets" / "onboarding" / "find_offline.png").convert("RGBA")
        find.thumbnail((360, 360), Image.Resampling.LANCZOS)
        canvas.alpha_composite(find, (90, 1580))
    else:
        pad_copy(canvas, headline, subhead, light=light, centered=False)
        detail = cover(Image.open(PAD_DETAIL_PATH), (1370, 1028))
        paste_shadowed(canvas, detail, (1240, 335), radius=58, border=10, shadow_blur=38)
        track = Image.open(TRACK_PATH).convert("RGBA")
        track.thumbnail((610, 610), Image.Resampling.LANCZOS)
        canvas.alpha_composite(track, (170, 690))
        callout = scan_callout(1080, 230, landscape=True)
        paste_shadowed(canvas, callout, (170, 1465), radius=48, shadow_blur=30)

    out = FINAL / f"ipad-12.9-{index:02d}.png"
    canvas.convert("RGB").save(out, optimize=True)
    return out


def contact_sheet(paths: list[Path], out: Path, thumb: tuple[int, int], columns: int) -> None:
    rows = (len(paths) + columns - 1) // columns
    gap = 30
    label_h = 52
    sheet = Image.new(
        "RGB",
        (columns * thumb[0] + (columns + 1) * gap, rows * (thumb[1] + label_h) + (rows + 1) * gap),
        "#E7ECE9",
    )
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        col, row = i % columns, i // columns
        x = gap + col * (thumb[0] + gap)
        y = gap + row * (thumb[1] + label_h + gap)
        preview = ImageOps.contain(Image.open(path).convert("RGB"), thumb, Image.Resampling.LANCZOS)
        px = x + (thumb[0] - preview.width) // 2
        sheet.paste(preview, (px, y))
        text(draw, (x + thumb[0] // 2, y + thumb[1] + 18), path.name, size=22, weight="Medium", fill=INK, anchor="ma")
    sheet.save(out, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=("iphone", "ipad", "all"), default="all")
    args = parser.parse_args()

    FINAL.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)

    generated: list[Path] = []
    if args.only in ("iphone", "all"):
        generated.extend(build_phone(index) for index in range(1, 4))
    if args.only in ("ipad", "all"):
        generated.extend(build_pad(index) for index in range(1, 4))

    iphone = sorted(FINAL.glob("iphone-*.png"))
    ipad = sorted(FINAL.glob("ipad-*.png"))
    if iphone:
        contact_sheet(iphone, QA / "iphone-contact-sheet.png", (310, 672), 3)
    if ipad:
        contact_sheet(ipad, QA / "ipad-contact-sheet.png", (683, 512), 3)
    for path in generated:
        print(path)


if __name__ == "__main__":
    main()
