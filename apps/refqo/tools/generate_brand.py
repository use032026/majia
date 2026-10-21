"""Original Refqo refill-loop mark. Drawn from geometric primitives; no third-party art."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
root=Path(__file__).resolve().parent.parent
out=root/'assets/brand'; out.mkdir(parents=True,exist_ok=True)
svg='''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#493447"/><g fill="none" stroke="#E9AA77" stroke-width="72" stroke-linecap="round" stroke-linejoin="round"><path d="M320 340H654V620M584 546L654 620L728 546"/><path d="M704 684H370V404M296 478L370 404L440 478"/></g><path d="M476 444H548V580H476Z" fill="#FAF6F0"/></svg>'''
(out/'refqo.svg').write_text(svg)
im=Image.new('RGB',(2048,2048),'#493447');d=ImageDraw.Draw(im)
def line(points):
    pts=[(x*2,y*2) for x,y in points];d.line(pts,fill='#E9AA77',width=144,joint='curve')
    for x,y in pts:d.ellipse((x-72,y-72,x+72,y+72),fill='#E9AA77')
line([(320,340),(654,340),(654,620)]);line([(584,546),(654,620),(728,546)])
line([(704,684),(370,684),(370,404)]);line([(296,478),(370,404),(440,478)])
d.rounded_rectangle((952,888,1096,1160),radius=20,fill='#FAF6F0')
im=im.resize((1024,1024),Image.Resampling.LANCZOS);im.save(out/'refqo-1024.png')
icons=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset';config=json.loads((icons/'Contents.json').read_text())
for spec in config['images']:
    size=float(spec['size'].split('x')[0])*float(spec['scale'].replace('x',''));im.resize((int(size),int(size)),Image.Resampling.LANCZOS).save(icons/spec['filename'])
for bucket,px in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    folder=root/f'android/app/src/main/res/mipmap-{bucket}';im.resize((px,px),Image.Resampling.LANCZOS).save(folder/'ic_launcher.png')
res=root/'android/app/src/main/res'
(res/'drawable/refqo_foreground.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024"><path android:fillColor="#493447" android:pathData="M0,0H1024V1024H0Z"/><path android:strokeColor="#E9AA77" android:strokeWidth="64" android:strokeLineCap="round" android:strokeLineJoin="round" android:fillColor="@android:color/transparent" android:pathData="M320,340H654V620M584,546L654,620L728,546M704,684H370V404M296,478L370,404L440,478"/><path android:fillColor="#FAF6F0" android:pathData="M476,444H548V580H476Z"/></vector>''')
folder=res/'mipmap-anydpi-v26';folder.mkdir(exist_ok=True)
(folder/'ic_launcher.xml').write_text('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/brand"/><foreground android:drawable="@drawable/refqo_foreground"/></adaptive-icon>')
for night,bg in [('', '#FAF6F0'),('-night','#211E24')]:
    folder=res/f'values{night}';folder.mkdir(exist_ok=True)
    (folder/'colors.xml').write_text(f'<resources><color name="launch_background">{bg}</color><color name="brand">#493447</color></resources>')
    (folder/'styles.xml').write_text('''<resources><style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar"><item name="android:windowBackground">@color/launch_background</item></style><style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar"><item name="android:windowBackground">@color/launch_background</item></style></resources>''')
    folder=res/f'values{night}-v31';folder.mkdir(exist_ok=True)
    (folder/'styles.xml').write_text('''<resources><style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar"><item name="android:windowSplashScreenBackground">@color/launch_background</item><item name="android:windowSplashScreenAnimatedIcon">@drawable/refqo_foreground</item><item name="android:windowSplashScreenIconBackgroundColor">@color/brand</item><item name="android:windowBackground">@color/launch_background</item></style></resources>''')
for folder in ['drawable','drawable-v21']:
    (res/f'{folder}/launch_background.xml').write_text('<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:drawable="@color/launch_background"/></layer-list>')
assets=root/'ios/Runner/Assets.xcassets';colors=assets/'LaunchBackground.colorset';colors.mkdir(exist_ok=True)
(colors/'Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'0.9804','green':'0.9647','blue':'0.9412','alpha':'1.000'}}},{'idiom':'universal','appearances':[{'appearance':'luminosity','value':'dark'}],'color':{'color-space':'srgb','components':{'red':'0.1294','green':'0.1176','blue':'0.1412','alpha':'1.000'}}}],'info':{'author':'xcode','version':1}},indent=2))
p=root/'ios/Runner/Base.lproj/LaunchScreen.storyboard';s=p.read_text();import re
s=re.sub(r'<subviews>.*?</subviews>','',s,flags=re.S);s=re.sub(r'<constraints>.*?</constraints>','',s,flags=re.S);s=re.sub(r'<color key="backgroundColor"[^>]*/>','<color key="backgroundColor" name="LaunchBackground"/>',s);s=re.sub(r'<resources>.*?</resources>','<resources><namedColor name="LaunchBackground"><color red="0.9804" green="0.9647" blue="0.9412" alpha="1" colorSpace="custom" customColorSpace="sRGB"/></namedColor></resources>',s,flags=re.S);p.write_text(s)
