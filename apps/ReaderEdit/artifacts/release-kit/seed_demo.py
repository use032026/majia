"""Seed a release-materials-only simulator/emulator. Never use on a personal device."""
import argparse, json, plistlib, subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('platform',choices=['ios','android']);p.add_argument('device');p.add_argument('locale',choices=['en','zh']);a=p.parse_args()
root=Path(__file__).resolve().parent; demo=root/f'demo-{a.locale}.json'
if a.platform=='ios':
    devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True))['devices']
    device=next((d for ds in devices.values() for d in ds if d['udid']==a.device),None)
    if not device or not device['name'].startswith('ReaderEdit ReleaseKit'):
        raise SystemExit('Refusing to seed a simulator not named ReaderEdit ReleaseKit.')
    app='com.example.readerEdit'
    subprocess.run(['xcrun','simctl','terminate',a.device,app],capture_output=True)
    path=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.device,app,'data'],text=True).strip())
    support=path/'Library/Application Support';support.mkdir(parents=True,exist_ok=True)
    (support/'reader_edit_sessions_v1.json').write_bytes(demo.read_bytes())
    prefs=path/'Library/Preferences'/f'{app}.plist';prefs.parent.mkdir(parents=True,exist_ok=True)
    prefs.write_bytes(plistlib.dumps({'flutter.reader_edit_language_v1':a.locale,'flutter.reader_edit_dark_mode_v1':False,'flutter.reader_edit_onboarding_completed_v1':True}))
    subprocess.run(['xcrun','simctl','launch',a.device,app],check=True)
else:
    adb='/Users/starburst/Library/Android/sdk/platform-tools/adb';pkg='com.example.reader_edit'
    def run(*args,**kwargs):return subprocess.run([adb,'-s',a.device,*args],check=True,**kwargs)
    if subprocess.check_output([adb,'-s',a.device,'shell','getprop','ro.kernel.qemu'],text=True).strip()!='1':
        raise SystemExit('Refusing to seed a physical Android device.')
    previous=subprocess.run([adb,'-s',a.device,'shell','run-as',pkg,'cat','files/reader_edit_sessions_v1.json'],capture_output=True)
    if previous.returncode==0:
        old=json.loads(previous.stdout)
        if any(v.get('id')!='demo-novel' for v in old.get('novels',[])) or any(v.get('id')!='demo-revision' for v in old.get('sessions',[])):
            raise SystemExit('Existing non-demo workspace found; refusing to overwrite it.')
    run('shell','am','force-stop',pkg)
    run('shell','run-as',pkg,'mkdir','-p','files','shared_prefs')
    for src,dest in [(demo,'files/reader_edit_sessions_v1.json')]:
        run('shell',f'run-as {pkg} sh -c "cat > {dest}"',input=src.read_bytes())
    xml=f'<?xml version="1.0" encoding="utf-8"?><map><string name="flutter.reader_edit_language_v1">{a.locale}</string><boolean name="flutter.reader_edit_dark_mode_v1" value="false"/><boolean name="flutter.reader_edit_onboarding_completed_v1" value="true"/></map>'
    run('shell',f'run-as {pkg} sh -c "cat > shared_prefs/FlutterSharedPreferences.xml"',input=xml.encode())
    run('shell','am','start','-n',pkg+'/.MainActivity')
