#!/usr/bin/env python3
"""Rasterize the original Figma vectors for native ASTFX launch resources.

Requires macOS, Xcode command line tools, Python 3 and Pillow.
Run from any directory; original SVG geometry is rendered by AppKit.
"""

from pathlib import Path
import json
import subprocess
import tempfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/astfx'
IOS = ROOT / 'ios/Runner/Assets.xcassets'
ANDROID = ROOT / 'android/app/src/main/res'
TEAL = '#0B6B63'
RENDERER = ROOT / 'build/brand-assets/rasterize-svg'


def raster(name, size, temporary):
    output = temporary / f'{name}-{size[0]}x{size[1]}.png'
    subprocess.run([
        str(RENDERER), str(SOURCE / name), str(size[0]), str(size[1]), str(output),
    ], check=True)
    with Image.open(output) as image:
        return image.convert('RGBA')


def backdrop(dark, scale, temporary):
    size = (390 * scale, 862 * scale)
    top, bottom = ('#178F85', '#1A9A90') if dark else ('#FFFFFF', '#EAF5F1')
    gradient = Image.linear_gradient('L').resize(size)
    image = Image.composite(
        Image.new('RGBA', size, bottom), Image.new('RGBA', size, top), gradient,
    )
    mode = 'dark' if dark else 'light'
    image.alpha_composite(
        raster(f'{mode}-glow.svg', (640 * scale, 720 * scale), temporary),
        (-125 * scale, -40 * scale),
    )
    pattern = raster(f'{mode}-pattern.svg', (640 * scale, 640 * scale), temporary)
    opacity = 0.09 if dark else 0.65
    pattern.putalpha(pattern.getchannel('A').point(lambda alpha: round(alpha * opacity)))
    image.alpha_composite(pattern, (24 * scale, 510 * scale))
    return image.convert('RGB')


def brand(dark, scale, temporary):
    image = Image.new('RGBA', (152 * scale, 200 * scale))
    mark = 'reverse-mark.svg' if dark else 'primary-mark.svg'
    image.alpha_composite(raster(mark, (152 * scale, 152 * scale), temporary))
    wordmark = raster('wordmark.svg', (132 * scale, 30 * scale), temporary)
    if dark:
        reverse = Image.new('RGBA', wordmark.size, '#FFFFFF')
        reverse.putalpha(wordmark.getchannel('A'))
        wordmark = reverse
    # The Figma wordmark is centered within a 40 pt row after an 8 pt gap.
    image.alpha_composite(wordmark, (10 * scale, round(166.051545 * scale)))
    return image


def write_image_set(name, images):
    folder = IOS / f'{name}.imageset'
    folder.mkdir(parents=True, exist_ok=True)
    entries = []
    for dark in (False, True):
        for scale in (1, 2, 3):
            suffix = '-dark' if dark else ''
            density = '' if scale == 1 else f'@{scale}x'
            filename = f'{name}{suffix}{density}.png'
            images[dark, scale].save(folder / filename, optimize=True)
            entry = {'idiom': 'universal', 'filename': filename, 'scale': f'{scale}x'}
            if dark:
                entry['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
            entries.append(entry)
    (folder / 'Contents.json').write_text(json.dumps({
        'images': entries, 'info': {'author': 'xcode', 'version': 1},
    }, indent=2) + '\n')


def main():
    RENDERER.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        'swiftc', '-module-cache-path', str(RENDERER.parent / 'ModuleCache'),
        str(ROOT / 'scripts/rasterize_svg.swift'), '-o', str(RENDERER),
    ], check=True)
    with tempfile.TemporaryDirectory(prefix='astfx-assets-') as directory:
        temporary = Path(directory)
        backgrounds, brands = {}, {}
        for dark in (False, True):
            for scale in (1, 2, 3):
                backgrounds[dark, scale] = backdrop(dark, scale, temporary)
                brands[dark, scale] = brand(dark, scale, temporary)
        write_image_set('LaunchBackdrop', backgrounds)
        write_image_set('LaunchImage', brands)

        icon = Image.new('RGBA', (1024, 1024), TEAL)
        icon.alpha_composite(raster('icon-mark.svg', (1024, 1024), temporary))
        icon = icon.convert('RGB')
        catalog = IOS / 'AppIcon.appiconset'
        for entry in json.loads((catalog / 'Contents.json').read_text())['images']:
            side = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
            icon.resize((side, side), Image.Resampling.LANCZOS).save(
                catalog / entry['filename'], optimize=True,
            )

        densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
        for density, factor in densities.items():
            icon.resize((round(48 * factor),) * 2, Image.Resampling.LANCZOS).save(
                ANDROID / f'mipmap-{density}/ic_launcher.png', optimize=True,
            )
            for dark in (False, True):
                qualifier = f'drawable-{"night-" if dark else ""}{density}'
                folder = ANDROID / qualifier
                folder.mkdir(parents=True, exist_ok=True)
                brands[dark, 3].resize(
                    (round(152 * factor), round(200 * factor)), Image.Resampling.LANCZOS,
                ).save(folder / 'astfx_launch_brand.png', optimize=True)
                # Android 12 reserves a centered 288 dp system icon area.
                system_icon = Image.new('RGBA', (round(288 * factor),) * 2)
                mark = 'reverse-mark.svg' if dark else 'primary-mark.svg'
                system_icon.alpha_composite(
                    raster(mark, (round(152 * factor),) * 2, temporary),
                    (round(68 * factor),) * 2,
                )
                system_icon.save(folder / 'astfx_splash_mark.png', optimize=True)
        for dark in (False, True):
            folder = ANDROID / ('drawable-night-nodpi' if dark else 'drawable-nodpi')
            folder.mkdir(parents=True, exist_ok=True)
            backgrounds[dark, 3].save(folder / 'astfx_launch_backdrop.png', optimize=True)


if __name__ == '__main__':
    main()
