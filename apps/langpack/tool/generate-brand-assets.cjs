#!/usr/bin/env node
// Regenerate only this app's mobile raster assets from its checked-in SVGs.
// Requires an existing sharp installation, optionally supplied through NODE_PATH.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const local = relative => path.join(root, relative);
const source = fs.readFileSync(local('assets/brand/app-icon.svg'));
const mark = fs.readFileSync(local('assets/brand/mark.svg'));
const rounded = Buffer.from(source.toString().replace(
  '<rect width="1024" height="1024" fill="#197E64"/>',
  '<rect width="1024" height="1024" rx="224" fill="#197E64"/>',
));
const foreground = Buffer.from(mark.toString()
  .replace('<g id="language-cards">', '<g transform="translate(92 92) scale(.82)"><g id="language-cards">')
  .replace('</svg>', '</g></svg>'));

async function render(svg, size, relative, opaque = false) {
  const output = local(relative);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  let image = sharp(svg).resize(size, size);
  if (opaque) image = image.flatten({ background: '#197E64' }).removeAlpha();
  await image.png().toFile(output);
}

async function main() {
  await render(source, 1024, 'assets/brand/app-icon.png');
  await render(mark, 1024, 'assets/brand/mark.png');

  const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const catalogue = JSON.parse(fs.readFileSync(local(`${ios}/Contents.json`), 'utf8'));
  for (const image of catalogue.images) {
    if (!image.filename) continue;
    const size = Math.round(parseFloat(image.size) * parseFloat(image.scale));
    await render(source, size, `${ios}/${image.filename}`, true);
  }

  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    const res = 'android/app/src/main/res';
    await render(rounded, size, `${res}/mipmap-${density}/ic_launcher.png`);
    await render(foreground, Math.round(size * 2.25), `${res}/drawable-${density}/ic_launcher_foreground.png`);
    await render(rounded, Math.round(size * 2), `${res}/drawable-${density}/launch_logo.png`);
  }

  const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  for (const scale of [1, 2, 3]) {
    await render(rounded, 96 * scale, `${launch}/LaunchImage${scale === 1 ? '' : `@${scale}x`}.png`);
  }
  console.log('Generated LangPack Flutter, iOS and Android images inside this app.');
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
