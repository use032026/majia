"""Rebuild local ReaderEdit release materials from audited copy and real captures."""
from pathlib import Path
from html import escape
import json, shutil, re
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SKILL=ROOT.parents[1]/'.codex/skills/app-store-release-kit'
ART=ROOT/'artifacts'; WEB=ROOT/'website'; (WEB/'assets').mkdir(parents=True,exist_ok=True)
existing_manifest=ROOT/'release-kit.yml'
if existing_manifest.exists():
    for key in ['operator','support_email','production_domain','effective_date']:
        m=re.search(r'(?m)^\s*'+key+r':\s*(.*)$',existing_manifest.read_text())
        if m and m.group(1).strip().strip(chr(34)+chr(39)):
            raise SystemExit('Confirmed release facts exist. Update the draft generator before rebuilding; refusing to overwrite '+key)
for d in ['app-store-listing','app-store-previews','google-play-listing','release-kit']:(ART/d).mkdir(parents=True,exist_ok=True)
def write(path, text):path.write_text('\n'.join(line.rstrip() for line in text.rstrip().splitlines())+'\n')
description='''ReaderEdit is a local writing and revision workspace for novels and chapters, with English and Simplified Chinese interfaces.

KEEP YOUR MANUSCRIPT TOGETHER
Create novels and chapters on your device. Import TXT or Markdown files through the system file picker. ReaderEdit decodes UTF-8 and BOM-marked UTF-16 text and separates supported Chinese or Markdown chapter headings into chapters. Imported text becomes a working copy; the original file is left unchanged.

READ AND EDIT IN ONE PLACE
Open a chapter in a reading view, then switch directly into editing. Chapter titles and text are saved in your local workspace.

REVISE FROM A READER'S PERSPECTIVE
Create a separate revision session for a passage. Set what you want a reader to know, feel, and wonder. Mark each paragraph Clear, Dragging, or Lost, and add your own reader notes. Flagged paragraphs form a focused revision queue.

SEE WHAT CHANGED
Revise selected paragraphs while preserving their original versions. Compare before and after, reopen an item, reassess its signal, and check the result against your reader promises. Copy the revised draft or revision log to the system clipboard when you choose.

A WORKSPACE ON YOUR DEVICE
Writing, reading, and revision work without an account or cloud sync. Local snapshots support save recovery. Delete individual novels, chapters, or revision sessions, or erase all manuscript and revision data from Settings. Separately created revision sessions remain independent of novel and chapter deletions.

CHOOSE YOUR READING ENVIRONMENT
Switch between English and Simplified Chinese, use light or dark appearance, and replay the quick tour from Settings.

The core manuscript workflow works offline. Opening an online privacy policy requires a connection when a policy URL has been configured. Files selected from a cloud provider and operating-system backups follow that provider's or system's settings. Clipboard export does not publish your writing.'''
write(ART/'app-store-listing/description-en.txt',description)
write(ART/'app-store-listing/keywords-en.txt','novel,chapter,manuscript,revision,writing,reader,editing,draft,markdown,offline,notes')
write(ART/'google-play-listing/short-description-en.txt','Write novels, read chapters, and revise with reader signals on your device')
icon=ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'
shutil.copy2(icon,WEB/'assets/app-icon.png')
Image.open(icon).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS).save(ART/'google-play-listing/app-icon-512.png')
# Empty facts are intentional: user explicitly confirmed all four remain undecided.
manifest='''schema_version: 2
identity:
  app_name: "ReaderEdit"
  operator: ""
  bundle_id: "com.example.readerEdit"
  android_package: "com.example.reader_edit"
contact:
  support_email: ""
  production_domain: ""
platforms:
  ios:
    iphone: true
    ipad: true
  android:
    phone: true
    tablets: true
listing:
  shared_full_description: artifacts/app-store-listing/description-en.txt
  app_store:
    primary_locale: en-US
  google_play:
    primary_locale: en-US
    localized_graphics:
      - en-US
      - zh-CN
  tone: clear, specific, trustworthy
privacy:
  effective_date: ""
  confirmed:
    - "2026-10-16 user: operator, support email, production domain and effective date are all undecided."
    - "Core manuscript and revision data are stored locally; no account or app backend is implemented."
    - "Online policy WebView is conditional on build-time HTTPS configuration; JavaScript is disabled."
    - "File import uses the system picker; exports write to the system clipboard on user action."
    - "OS backups, file providers and clipboard behavior are controlled outside ReaderEdit."
  open_questions:
    - "Legal operator, monitored support address, production domain and effective date."
    - "Intended audience, launch regions, final distribution SDK inventory and legal review."
website:
  default_locale: en
  locales:
    - en
    - zh-Hans
screenshots:
  source_policy: real-runtime-only
  app_store:
    locale: en-US
    locales:
      - en-US
      - zh-Hans
    scenes:
      - id: library
        source: source/iphone-en-01-library.png
      - id: read
        source: source/iphone-en-02-read.png
      - id: queue
        source: source/iphone-en-03-queue.png
      - id: compare
        source: source/iphone-en-04-compare.png
  google_play:
    locales:
      - en-US
      - zh-CN
    scenes:
      - id: library
        source: source/prepared/android-en-01-library.png
      - id: read
        source: source/prepared/android-en-02-read.png
      - id: queue
        source: source/prepared/android-en-03-queue.png
      - id: compare
        source: source/prepared/android-en-04-compare.png
paths:
  app_root: "apps/ReaderEdit"
'''
# Android has no manifest screen-size exclusion; this package supplies phone assets.
write(ROOT/'release-kit.yml',manifest)
scenes=[('01-library','Your writing, together','整理小说与章节','Keep novels and chapters in a local workspace.','在本地工作区管理小说与章节。'),('02-read','Read. Then revise.','阅读之后，直接修改','Switch from chapter reading to editing.','从章节阅读直接切换到编辑。'),('03-queue','Follow reader signals','跟随读者信号修订','Focus on passages marked Dragging or Lost.','集中处理“拖沓”与“迷失”的段落。'),('04-compare','See every change','看清每一处修改','Compare your original and revised passages.','对照原文与修订后的段落。')]
# Remove only Android OS status/navigation chrome; preserve every app pixel.
# Raw 1080x2400 captures remain beside these 1080x2200 preparation copies.
prepared=ART/'google-play-listing/source/prepared';prepared.mkdir(exist_ok=True)
for raw in (ART/'google-play-listing/source').glob('android-*.png'):
    im=Image.open(raw)
    assert im.size==(1080,2400)
    im.crop((0,115,1080,2315)).convert('RGB').save(prepared/raw.name)
font=next(str(p) for p in [Path('/System/Library/Fonts/PingFang.ttc'),Path('/System/Library/Fonts/Supplemental/Arial Unicode.ttf')] if p.exists())
def spec(store):return dict(schema_version=2,store=store,app_name='ReaderEdit',font_path=font,qa_dir='qa',defaults=dict(background_top='#5142CF',background_bottom='#242039',text_color='#FFFCF7',muted_text_color='#E0D9FA'),items=[])
apple=spec('app_store');play=spec('google_play')
for lang, apple_locale, play_locale in [('en','en-US','en-US'),('zh','zh-Hans','zh-CN')]:
    for scene,en,zh,suben,subzh in scenes:
        apple['items'].append(dict(kind='screenshot',locale=apple_locale,source=f'source/iphone-{lang}-{scene}.png',output=f'final/{apple_locale}/iphone/{scene}.png',size=[1206,2622],headline=en if lang=='en' else zh,subheadline=suben if lang=='en' else subzh,icon='../../website/assets/app-icon.png'))
        play['items'].append(dict(kind='screenshot',locale=play_locale,source=f'source/prepared/android-{lang}-{scene}.png',output=f'final/{play_locale}/phone/{scene}.png',size=[1080,1920],headline=en if lang=='en' else zh))
    for scene,en,zh,suben,subzh in [scenes[0],scenes[2]]:
        apple['items'].append(dict(kind='screenshot',locale=apple_locale,source=f'source/ipad-{lang}-{scene}.png',output=f'final/{apple_locale}/ipad/{scene}.png',size=[2064,2752],headline=en if lang=='en' else zh,subheadline=suben if lang=='en' else subzh,icon='../../website/assets/app-icon.png'))
    play['items'].append(dict(kind='feature_graphic',locale=play_locale,output=f'final/feature-graphic-{lang}.png',size=[1024,500],headline='A reader’s eye on your draft' if lang=='en' else '用读者的眼光，打磨文字'))
for name,data in [('app-store-previews',apple),('google-play-listing',play)]:write(ART/name/'preview-spec.json',json.dumps(data,ensure_ascii=False,indent=2))
# Adapt the skill's complete bilingual product template.
values={
'APP_NAME':'ReaderEdit','META_DESCRIPTION_EN':'A local novel and chapter workspace with reading, editing, reader signals, and revision comparisons.','META_DESCRIPTION_ZH':'本地小说与章节工作区，支持阅读、编辑、读者信号和修订前后对照。','TAGLINE_EN':'Write with a reader’s eye.','TAGLINE_ZH':'用读者的眼光，打磨文字。','EYEBROW_EN':'NOVELS · CHAPTERS · REVISION','EYEBROW_ZH':'小说 · 章节 · 读者视角修订','HERO_BODY_EN':'Keep your manuscript on your device. Read a chapter, edit in place, and turn your own reader signals into a focused revision queue.','HERO_BODY_ZH':'把稿件保存在设备上。阅读章节、就地编辑，再用自己的读者信号整理出清晰的修订队列。','FEATURES_HEADING_EN':'From first draft to a closer read.','FEATURES_HEADING_ZH':'从初稿出发，再认真读一遍。','FEATURE_1_TITLE_EN':'A local manuscript library','FEATURE_1_TITLE_ZH':'本地稿件书架','FEATURE_1_BODY_EN':'Create novels and chapters, or import TXT and Markdown through the system picker. UTF-8 and BOM-marked UTF-16 are supported. The original file stays unchanged.','FEATURE_1_BODY_ZH':'创建小说与章节，或通过系统选择器导入 TXT、Markdown。支持 UTF-8 和带字节顺序标记的 UTF-16，原始文件保持不变。','FEATURE_2_TITLE_EN':'Read, then edit','FEATURE_2_TITLE_ZH':'边读，边改','FEATURE_2_BODY_EN':'Move directly from chapter reading into editing. English and Simplified Chinese interfaces, light and dark appearance, and a replayable quick tour keep the workspace familiar.','FEATURE_2_BODY_ZH':'从章节阅读直接切换到编辑。支持简体中文和英文界面、浅色与深色外观，也可随时重看使用引导。','FEATURE_3_TITLE_EN':'Follow your reader signals','FEATURE_3_TITLE_ZH':'把阅读感受变成修订行动','FEATURE_3_BODY_EN':'Mark passages Clear, Dragging, or Lost. Revise flagged paragraphs, compare before and after, check your reader promises, and copy the revised draft or revision log.','FEATURE_3_BODY_ZH':'将段落标记为清楚、拖沓或迷失。修改被标记的段落、查看前后对照、核对读者承诺，并复制修订稿或修订记录。','COPYRIGHT_YEAR':'2026','OPERATOR':'','SUPPORT_EMAIL':''}
index=(SKILL/'assets/website/index.html.tmpl').read_text()
# Pending contact details remain visible prose, never invented mailbox links.
index=index.replace('<a href="mailto:[[SUPPORT_EMAIL]]"><span data-lang="en">Support</span><span data-lang="zh">支持</span></a>','<a href="#support"><span data-lang="en">Support</span><span data-lang="zh">支持</span></a>')
index=index.replace('<a class="button" href="mailto:[[SUPPORT_EMAIL]]">Contact support</a>','<a class="button" href="#features">Explore the workflow</a>')
index=index.replace('<a class="button" href="mailto:[[SUPPORT_EMAIL]]">联系支持</a>','<a class="button" href="#features">了解使用流程</a>')
index=index.replace('<img class="hero-image" src="assets/app-preview.png" alt="" role="presentation">','<div class="hero-art"><img class="hero-image" data-lang="en" src="assets/library-en.png" alt="ReaderEdit manuscript library on iPhone"><img class="hero-image" data-lang="zh" src="assets/library-zh.png" alt="ReaderEdit 的 iPhone 小说书架"></div>')
index=index.replace('<h1>[[TAGLINE_ZH]]</h1>', '<h1>用读者的眼光，<br>打磨文字。</h1>')
index=index.replace('<main>','<main><aside class="draft-note"><span data-lang="en">Local materials draft · operator, support contact, domain, and effective date remain undecided.</span><span data-lang="zh">本地素材草稿 · 运营主体、支持联系方式、正式域名和生效日期均待定。</span></aside>')
extra='''<section class="section gallery-section"><div data-lang="en"><p class="eyebrow">A closer look</p><h2>A revision stays traceable.</h2><p>Original demo manuscript shown in real iPhone captures. No account is required for the core writing workflow.</p></div><div data-lang="zh"><p class="eyebrow">看看实际界面</p><h2>每次修订，都有迹可循。</h2><p>真实 iPhone 运行界面，使用原创示例稿件。核心写作流程无需账号。</p></div><div class="screen-grid">'''
for lang in ['en','zh']:
    for scene,en,zh,suben,subzh in scenes[1:]:
        extra+=f'<figure data-lang="{lang}"><img loading="lazy" src="assets/{scene}-{lang}.png" alt="{escape(en if lang=="en" else zh)}"><figcaption>{escape(en if lang=="en" else zh)}</figcaption></figure>'
extra+='''</div></section><section class="support-panel" id="support"><div data-lang="en"><p class="eyebrow">Support &amp; local data</p><h2>Support contact is awaiting confirmation.</h2><p>This local draft has no published support channel or production domain. No support address has been invented. For local data controls, open Settings in ReaderEdit. Deleting a novel does not remove separately created revision sessions; delete those too or erase all manuscript data.</p><p>The core workflow works offline. A configured online privacy page, cloud file provider, clipboard, or operating-system backup may involve services outside ReaderEdit. <a href="privacy.html" data-local-page>Read the privacy draft</a>.</p></div><div data-lang="zh"><p class="eyebrow">支持与本地数据</p><h2>支持联系方式待确认。</h2><p>本地草稿尚无已发布的支持渠道和正式域名，也未编造联系地址。数据管理可在 ReaderEdit 设置中操作。删除小说不会删除独立创建的修订会话；请单独删除这些会话，或清除全部稿件数据。</p><p>核心流程可离线使用。已配置的在线隐私页面、云端文件提供方、剪贴板或系统备份可能涉及 ReaderEdit 之外的服务。<a href="privacy.html" data-local-page>阅读隐私草稿</a>。</p></div></section>'''
index=index.replace('</main>',extra+'</main>')
index=index.replace('<span>© [[COPYRIGHT_YEAR]] [[OPERATOR]].</span>','<span data-lang="en">ReaderEdit · local release materials draft</span><span data-lang="zh">ReaderEdit · 本地上架素材草稿</span>')
index=index.replace(' · <a href="mailto:[[SUPPORT_EMAIL]]">[[SUPPORT_EMAIL]]</a>','')
for key,value in values.items():index=index.replace('[['+key+']]',escape(value,quote=True))
assert not re.search(r'\[\[[^]]+\]\]',index)
write(WEB/'index.html',index)
for lang in ['en','zh']:
    shutil.copy2(ART/f'app-store-previews/source/iphone-{lang}-01-library.png',WEB/f'assets/library-{lang}.png')
    for scene,*_ in scenes[1:]:shutil.copy2(ART/f'app-store-previews/source/iphone-{lang}-{scene}.png',WEB/f'assets/{scene}-{lang}.png')
privacy_values={
'APP_NAME':'ReaderEdit','EFFECTIVE_DATE_EN':'date undecided — local draft only','EFFECTIVE_DATE_ZH':'待定，仅为本地草稿',
'PRIVACY_SUMMARY_EN':'This draft describes the ReaderEdit 1.0.0 implementation inspected on 16 October 2026. The operator, monitored support address, production domain, and effective date have not been confirmed. It is not a published or legally reviewed policy.',
'PRIVACY_SUMMARY_ZH':'本草稿基于 2026 年 10 月 16 日检查的 ReaderEdit 1.0.0 实现。运营主体、有人处理的支持邮箱、正式域名及生效日期尚未确认。本文件不是已发布或已完成法律审核的政策。',
'DATA_PRACTICES_EN':'ReaderEdit handles novel and chapter titles, descriptions, text you type or import, separate revision sessions, reader promises, paragraph signals, notes, revised passages, and completion checks. These are stored in the app’s local workspace. Language, appearance, and tour-completion preferences are also stored locally. No account, app-owned backend, analytics, advertising, tracking, payment, or AI processing service is implemented in the inspected code. Manuscript and revision content is not sent to an app-operated server by that code.',
'DATA_PRACTICES_ZH':'ReaderEdit 处理小说和章节标题、简介、您输入或导入的正文、独立修订会话、读者承诺、段落信号、备注、修订段落及完成核对。这些内容保存在应用的本地工作区。语言、外观和引导完成状态也保存在本地。检查的代码未实现账号、应用自有后端、分析、广告、跟踪、支付或 AI 处理服务；该代码不会将稿件和修订内容发送到应用运营的服务器。',
'PERMISSIONS_EN':'Text import opens the operating system’s file picker and reads the file you select. It does not request general access to your file library. The inspected iOS target has no camera, photos, microphone, contacts, location, speech, or notification usage prompts. The Android main manifest includes INTERNET permission for optional web content; the reviewed app does not request runtime access to those sensors or personal-data libraries. A system or file provider may show its own access or authentication prompts.',
'PERMISSIONS_ZH':'文本导入会打开操作系统的文件选择器，并读取您选中的文件，不会请求读取整个文件库。检查的 iOS 目标未配置相机、照片、麦克风、通讯录、位置、语音或通知用途提示。Android 主清单包含用于可选网页内容的 INTERNET 权限；受审应用不请求上述传感器或个人资料库的运行时访问权限。系统或文件提供方可能显示自己的访问或身份验证提示。',
'NETWORK_AND_SERVICES_EN':'Writing, reading, revision, and decoding selected UTF-8 or BOM-marked UTF-16 files run on the device. The app uses Flutter, file_selector, path_provider, shared_preferences, and webview_flutter. These dependencies provide interface, file selection, storage, and web rendering. No production privacy URL is configured by default. When an HTTPS policy URL is supplied at build time, opening Privacy policy loads that page in the system WebView with JavaScript disabled. The website host and network providers can then receive ordinary request information such as IP address and requested page, and WebView behavior is governed by the operating system. Redirects and services on the final hosted page require a separate review. Cloud file providers may download selected files under your provider settings. ReaderEdit has no app-managed cloud sync. System backups or device migration may copy app data under your operating-system settings; this is separate from app-managed sync. This generated website stores only your language choice in browser local storage. It includes no analytics script, advertising script, external font, or third-party image request. Final hosting logs and services must be reviewed before publication.',
'NETWORK_AND_SERVICES_ZH':'写作、阅读、修订以及所选 UTF-8 或带字节顺序标记的 UTF-16 文件解码均在设备上执行。应用使用 Flutter、file_selector、path_provider、shared_preferences 和 webview_flutter，分别提供界面、文件选择、存储及网页渲染能力。默认未配置正式隐私政策网址。在构建时提供 HTTPS 政策网址后，打开“隐私政策”会在禁用 JavaScript 的系统 WebView 中加载该页面。此时网站主机与网络提供方可能接收 IP 地址、请求页面等常规请求信息，WebView 行为受操作系统管理。正式托管页面的跳转和服务仍需单独审核。云端文件提供方可能依据您的设置下载所选文件。ReaderEdit 没有应用管理的云同步；系统备份或设备迁移可能依据系统设置复制应用数据，这与应用主动同步不同。本次生成的网站仅在浏览器本地存储中记住语言选择，未加入分析脚本、广告脚本、外部字体或第三方图片请求。正式托管的日志和服务仍需在发布前审核。',
'STORAGE_RETENTION_DELETION_EN':'Manuscript and revision records remain in the app sandbox until you delete the relevant records or erase all manuscript and revision data in Settings. The app maintains local primary, recovery, and pending snapshots to reduce interrupted-save loss. Successful deletion updates app-managed recovery snapshots so deleted records are not intentionally restored by that recovery path. Novel or chapter deletion does not remove separately created revision sessions. Erase all local data clears novels and revision sessions while language, appearance, and tour preferences remain. Uninstall and system backup retention depend on your operating system; deletion here does not remove the original imported file, system backups, or copies you have made outside the app. The app does not claim secure forensic erasure.',
'STORAGE_RETENTION_DELETION_ZH':'稿件和修订记录会保留在应用沙盒中，直到您删除相应记录，或在设置中清除全部稿件和修订数据。应用维护本地主快照、恢复快照及待提交快照，以降低保存中断造成的数据丢失。成功删除后会更新应用管理的恢复快照，避免通过该恢复路径主动还原已删除记录。删除小说或章节不会删除独立创建的修订会话。“清空全部本地数据”会清除小说和修订会话，语言、外观及引导设置仍保留。卸载与系统备份的保留行为取决于操作系统；应用内删除不会删除导入的原始文件、系统备份或您在应用外保存的副本。应用不承诺取证级安全擦除。',
'EXPORTS_AND_SHARING_EN':'Copy revised draft and Copy revision log write the chosen text to the system clipboard only when you tap them. Other apps and clipboard-sync services may access or retain clipboard content according to system permissions and settings. ReaderEdit does not automatically publish your writing, and the inspected code does not read the clipboard. Import creates a local working copy and leaves the original file unchanged. Copies you paste, share, or save elsewhere are controlled by you and the receiving service.',
'EXPORTS_AND_SHARING_ZH':'只有在您点击“复制修订稿”或“复制修订记录”时，相应文字才会写入系统剪贴板。其他应用及剪贴板同步服务可能根据系统权限和设置访问或保留这些内容。ReaderEdit 不会自动发布您的文字，检查的代码也不读取剪贴板。导入会创建本地工作副本，原始文件保持不变。您粘贴、分享或另存的副本由您及接收服务管理。',
'CHILDREN_EN':'The inspected app is a general writing workspace and does not request age or date of birth. It has no account or developer-operated service for receiving children’s manuscript data. Intended audience, launch regions, and any region-specific requirements for children must be confirmed before this policy is published. This draft does not establish an age rating or parental-consent process.',
'CHILDREN_ZH':'受审应用是通用写作工作区，不要求填写年龄或出生日期，也没有用于接收儿童稿件的账号或开发者运营服务。正式发布政策前，仍需确认目标受众、发行地区及当地涉及儿童的要求。本草稿不构成年龄分级或家长同意机制。',
'POLICY_CHANGES_EN':'Before publication, confirm the operator, support contact, domain, effective date, final SDK inventory, hosting behavior, and legal wording. If product data handling changes, the published policy and date should be updated to match. This local draft makes no claim that a notice has already been delivered to users.',
'POLICY_CHANGES_ZH':'发布前需确认运营主体、支持联系方式、域名、生效日期、最终 SDK 清单、网站托管行为及法律表述。若产品的数据处理方式发生变化，应同步更新已发布政策及日期。本地草稿不表示已经向用户发出通知。',
'OPERATOR':'','SUPPORT_EMAIL':''}
privacy=(SKILL/'assets/website/privacy.html.tmpl').read_text()
privacy=privacy.replace('<a href="mailto:[[SUPPORT_EMAIL]]"><span data-lang="en">Support</span><span data-lang="zh">支持</span></a>','<a href="index.html#support" data-local-page><span data-lang="en">Support</span><span data-lang="zh">支持</span></a>')
privacy=privacy.replace('<p>[[OPERATOR]] · <a href="mailto:[[SUPPORT_EMAIL]]">[[SUPPORT_EMAIL]]</a></p>','<p data-contact-pending>Operator and support email remain undecided. No contact channel is published in this local draft.</p>',1)
privacy=privacy.replace('<p>[[OPERATOR]] · <a href="mailto:[[SUPPORT_EMAIL]]">[[SUPPORT_EMAIL]]</a></p>','<p data-contact-pending>运营主体及支持邮箱待定。本地草稿未提供已发布的联系渠道。</p>',1)
for key,value in privacy_values.items():privacy=privacy.replace('[['+key+']]',escape(value,quote=True))
assert not re.search(r'\[\[[^]]+\]\]',privacy)
# Serve both complete languages when scripting is disabled. Static locale variants
# are suitable for the app's JavaScript-disabled WebView once a domain is confirmed.
privacy=privacy.replace('<link rel="stylesheet" href="styles.css">','<link rel="stylesheet" href="styles.css"><noscript><style>[data-lang]{display:block!important}.language-switch{display:none}</style></noscript>')
write(WEB/'privacy.html',privacy)
for lang in ['en','zh']:
    static=re.sub(r'<article data-lang="'+('zh' if lang=='en' else 'en')+r'">.*?</article>','',privacy,flags=re.S)
    static=static.replace('<html lang="en">',f'<html lang="{"en" if lang=="en" else "zh-Hans"}">')
    static=re.sub(r'<script src="site.js" defer></script>','',static)
    static=re.sub(r'<noscript>.*?</noscript>','',static,flags=re.S)
    static=re.sub(r'<div class="language-switch".*?</div>', '<div class="static-languages"><a href="privacy-en.html">EN</a> · <a href="privacy-zh.html">中文</a></div>',static,flags=re.S)
    static=static.replace('<title>Privacy Policy — ReaderEdit</title>',f'<title>{"Privacy Policy" if lang=="en" else "隐私政策"} — ReaderEdit</title>')
    static=static.replace('content="Privacy Policy for ReaderEdit"', 'content="'+('Privacy Policy for ReaderEdit' if lang=='en' else 'ReaderEdit 隐私政策')+'"')
    write(WEB/f'privacy-{lang}.html',static)
css=(SKILL/'assets/website/styles.css').read_text()
for src,dest in [('#17312e','#23212B'),('#59716d','#625C6C'),('#0b6b63','#5142CF'),('#07544e','#4033AA'),('#f4f7f6','#FCF8F1'),('#dbe5e2','#E2DAD2')]:css=css.replace(src,dest)
css+='''
:focus-visible{outline:3px solid #D96C42;outline-offset:5px}
.draft-note{margin:18px 0 0;padding:12px 18px;background:#F1EBD9;border:1px solid #DCD2B7;border-radius:12px;font-size:.85rem;color:#625838}
.hero{min-height:740px;padding:64px 0 80px;gap:72px}
.hero h1{font-size:clamp(3.2rem,6vw,5.7rem);line-height:1.05;max-width:11ch}
html[lang^="zh"] .hero h1{max-width:none;font-size:clamp(3.2rem,4.8vw,4.5rem);line-height:1.2;letter-spacing:-.04em}
.hero-art{display:flex;align-items:center;justify-content:center;padding:30px;border-radius:44px;background:#E9E3FF;transform:rotate(2deg)}
.hero-image{display:block;width:280px;border-radius:28px;box-shadow:0 25px 55px #24203935;transform:rotate(-2deg)}
.section{padding:64px 0 80px}.section h2{max-width:22ch;line-height:1.12}
.screen-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:28px;margin-top:36px}.screen-grid figure{margin:0;padding:20px;background:#F1EDE6;border:1px solid var(--line);border-radius:24px}.screen-grid img{display:block;border-radius:18px}.screen-grid figcaption{font-weight:700;margin-top:15px}
.support-panel{padding:36px 42px;margin:20px 0 80px;border-radius:24px;border:1px solid var(--line);background:#F4F0E8;scroll-margin-top:20px}.support-panel h2{font-size:1.8rem;line-height:1.25}.support-panel p{max-width:86ch}
.policy{padding-top:54px}.policy h1{font-size:clamp(2.5rem,6vw,4.6rem);line-height:1.12}.policy p{overflow-wrap:anywhere}.static-languages{white-space:nowrap}
@media(max-width:760px){.site-header{display:grid;grid-template-columns:1fr auto;gap:18px}.site-header nav{grid-row:2;grid-column:1/-1;font-size:.92rem}.language-switch{grid-row:1;grid-column:2}.hero{min-height:auto;padding-top:38px;gap:38px}.hero h1{font-size:3.5rem}html[lang^="zh"] .hero h1{font-size:2.9rem;max-width:none}.hero-art{padding:26px;max-width:420px;margin:0 auto}.hero-image{width:250px}.screen-grid{grid-template-columns:1fr}.screen-grid figure{max-width:400px;margin:auto;width:100%}.support-panel{padding:25px}.feature-grid{gap:14px}.policy{padding-top:36px}}
'''
write(WEB/'styles.css',css)
js=(SKILL/'assets/website/site.js').read_text().replace('release-kit-language','readeredit-release-kit-language')
js=js.replace('    document.documentElement.lang =', '    const pageUrl = new URL(window.location.href);\n    pageUrl.searchParams.set("lang", language);\n    window.history.replaceState(null, "", pageUrl);\n    document.documentElement.lang =')
write(WEB/'site.js',js)
print(json.dumps({'description_characters':len(description),'keywords_utf8_bytes':len((ART/'app-store-listing/keywords-en.txt').read_text().strip().encode()),'short_description_characters':len((ART/'google-play-listing/short-description-en.txt').read_text().strip()),'app_store_items':len(apple['items']),'play_items':len(play['items'])}))
