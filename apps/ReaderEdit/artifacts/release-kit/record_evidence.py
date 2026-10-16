"""Record material inventories and fingerprints after rendering and visual review."""
from pathlib import Path
from PIL import Image
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, subprocess, plistlib
ROOT=Path(__file__).resolve().parents[2]; ART=ROOT/'artifacts'; OUT=ART/'release-kit'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(name, data):(OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
source=[]
for base in ['lib','ios/Runner','android/app/src/main']:
 for p in sorted((ROOT/base).rglob('*')):
  if p.is_file():source.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p)))
for name in ['pubspec.yaml','pubspec.lock','ios/Runner.xcodeproj/project.pbxproj','android/app/build.gradle.kts']:
 p=ROOT/name;source.append(dict(path=name,sha256=sha(p)))
binaries=[]
for rel in ['build/ios/iphonesimulator/Runner.app/Runner','build/ios/iphonesimulator/Runner.app/Frameworks/App.framework/flutter_assets/kernel_blob.bin','build/app/outputs/flutter-apk/app-debug.apk']:
 p=ROOT/rel
 if p.exists():binaries.append(dict(path=rel,sha256=sha(p),bytes=p.stat().st_size,existing_local_artifact=True))
info=plistlib.loads((ROOT/'build/ios/iphonesimulator/Runner.app/Info.plist').read_bytes())
captures=[]
for platform,rel,device in [('ios','app-store-previews/source','iPhone 17 Pro / iOS 26.5 Simulator or iPad Pro 13-inch (M5) / iOS 26.5 Simulator'),('android','google-play-listing/source','Pixel 7 / Android 15 API 35 emulator')]:
 for p in sorted((ART/rel).glob('*.png')):
  with Image.open(p) as im:
   captures.append(dict(path=str(p.relative_to(ROOT)),platform=platform,device=('iPad Pro 13-inch (M5) / iOS 26.5 Simulator' if p.name.startswith('ipad-') else 'iPhone 17 Pro / iOS 26.5 Simulator') if platform=='ios' else device,size=list(im.size),mode=im.mode,sha256=sha(p),captured_at_local=datetime.fromtimestamp(p.stat().st_mtime,ZoneInfo('Asia/Shanghai')).isoformat(),demo_only=True))
write('capture-manifest.json',dict(date='2026-10-16',timezone='Asia/Shanghai',git_head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),version=info.get('CFBundleShortVersionString'),build=info.get('CFBundleVersion'),built_in_this_run=False,source_files=source,existing_binaries=binaries,captures=captures,android_preparation=dict(crop=[0,115,1080,2315],preserves_all_app_pixels=True)))
assets=[]
for base in ['app-store-previews/final','google-play-listing/final']:
 for p in sorted((ART/base).rglob('*.png')):
  with Image.open(p) as im:
   assert im.mode=='RGB';assets.append(dict(path=str(p.relative_to(ROOT)),size=list(im.size),mode=im.mode,bytes=p.stat().st_size,sha256=sha(p),visual_review='inspected at original resolution; current source English pluralization note in OPEN_ITEMS.md'))
p=ART/'google-play-listing/app-icon-512.png'
with Image.open(p) as im:assert im.size==(512,512) and im.mode=='RGBA' and p.stat().st_size<=1024*1024
assets.append(dict(path=str(p.relative_to(ROOT)),size=[512,512],mode='RGBA',bytes=p.stat().st_size,sha256=sha(p),source='current production icon',visual_review='same branding as inspected app icon'))
write('asset-inventory.json',assets)
class Links(HTMLParser):
 def __init__(self):super().__init__();self.refs=[]
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k in ['src','href'] and v:self.refs.append(v)
checks=[]
for p in sorted((ROOT/'website').glob('*.html')):
 h=Links();h.feed(p.read_text());count=0
 for ref in h.refs:
  parts=urlsplit(ref)
  assert not parts.scheme and not parts.netloc, f'Unexpected external resource: {ref}'
  if parts.path:
   target=p.parent/unquote(parts.path);assert target.is_file(),target;count+=1
 checks.append(dict(page=p.name,local_references=count,all_exist=True,no_external_resources=True))
write('website-links.json',checks)
alts={}
for specname in ['app-store-previews','google-play-listing']:
 spec=json.loads((ART/specname/'preview-spec.json').read_text())
 for item in spec['items']:
  lang='zh' if item.get('locale','').startswith('zh') else 'en'
  label=('ReaderEdit ' + ('feature graphic' if item['kind']=='feature_graphic' else {'01-library':'local novel and revision library','02-read':'chapter reading with an Edit control','03-queue':'revision queue with reader signals','04-compare':'original and revised paragraph comparison'}[Path(item['output']).stem])) if lang=='en' else ('ReaderEdit '+('品牌横幅' if item['kind']=='feature_graphic' else {'01-library':'本地小说与修订书架','02-read':'带有编辑入口的章节阅读页','03-queue':'显示读者信号的修订队列','04-compare':'原文与修订段落的前后对照'}[Path(item['output']).stem]))
  assert len(label)<=140;alts['artifacts/'+specname+'/'+item['output']]=label
write('graphic-alt-text.json',alts)
print(f'{len(captures)} real runtime captures, {len(assets)} final graphics/icon assets, {len(checks)} HTML pages with valid local references.')
