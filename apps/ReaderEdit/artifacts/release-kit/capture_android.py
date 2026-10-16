"""Capture ReaderEdit's actual Android UI using Android SDK accessibility tools."""
import argparse, subprocess, xml.etree.ElementTree as ET, re, time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('locale',choices=['en','zh']);a=p.parse_args()
adb='/Users/starburst/Library/Android/sdk/platform-tools/adb';root=Path(__file__).resolve().parents[1];out=root/'google-play-listing/source';out.mkdir(parents=True,exist_ok=True)
def run(*args):return subprocess.check_output([adb,'-s','emulator-5554',*args])
def state():
    run('shell','uiautomator','dump','/sdcard/readeredit-window.xml')
    return run('shell','cat','/sdcard/readeredit-window.xml')
def tap(label,prefix=False):
    tree=ET.fromstring(state());nodes=[n for n in tree.iter('node') if n.get('clickable')=='true' and ((n.get('content-desc','').startswith(label)) if prefix else n.get('content-desc')==label)]
    if len(nodes)!=1:raise RuntimeError(f'Expected one control {label!r}: {[(n.get("content-desc"),n.get("bounds")) for n in nodes]}')
    x1,y1,x2,y2=map(int,re.findall(r'\d+',nodes[0].get('bounds')));run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
def capture(scene):
    xml=state();name=f'android-{a.locale}-{scene}';(out/f'{name}.xml').write_bytes(xml);(out/f'{name}.png').write_bytes(run('exec-out','screencap','-p'));print(name)
def back():run('shell','input','keyevent','4');state()
# Do not reset or clear user data. seed_demo.py supplies the isolated demo workspace.
capture('01-library')
tap('雾站来信\n1 章' if a.locale=='zh' else 'The Letter at Fog Station\n1 chapters',True)
tap('1\n第一章' if a.locale=='zh' else '1\nChapter 1',True)
capture('02-read');back();back()
tap('100%, 雾站来信' if a.locale=='zh' else '100%, The Letter at Fog Station',True)
capture('03-queue')
tap('核对与导出' if a.locale=='zh' else 'Review & export')
tap('查看全部前后对照' if a.locale=='zh' else 'View every change')
capture('04-compare')
