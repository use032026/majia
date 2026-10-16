"""Create original, non-personal demo workspaces; no UI images are synthesized."""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parent
DATE = '2026-10-16T09:41:00.000'
CONTENT = {
'en': dict(title='The Letter at Fog Station', chapter='Chapter 1 · The last train', description='A quiet station. An unsigned letter. One train to avoid.', paragraphs=[
'After the last train left, Mara found an unsigned letter beneath the station bench. The envelope looked old, but fresh rain darkened one corner.',
'She opened it. The first line read: “Do not take the six o’clock train.” She looked up at the timetable, then at her reflection in the glass.',
'No one waited outside. The ticket window was dark, yet the distant loudspeaker suddenly announced her name.'], revised='Mara unfolded the letter beneath the station lamp. “Do not take the six o’clock train.” Across the empty platform, the timetable clicked to 06:00.', note='Keep the warning in focus and make the next action concrete.', promises=['Someone knows Mara’s plans','Unease growing in a quiet place','Who wrote the letter?']),
'zh': dict(title='雾站来信', chapter='第一章 · 末班车后', description='一座安静的车站，一封没有署名的信。', paragraphs=[
'晚班火车离站后，林秋才发现长椅下有一封没有署名的信。信封很旧，右下角却沾着刚落下的雨。',
'她拆开信，第一句话写着：“不要搭明早六点的车。”她抬头看向时刻表，又看见玻璃里的自己。',
'站外没有人。售票窗口已经熄灯，可远处的广播忽然报出了她的名字。'],revised='林秋借着站灯展开信纸。“不要搭明早六点的车。”空荡荡的站台对面，时刻表刚好翻到了六点。', note='保留警告的悬念，让下一步动作更清楚。',promises=['有人知道林秋的行程','安静里逐渐出现不安','是谁写的信？'])}
for lang, c in CONTENT.items():
    passages=[dict(id=f'p{i}',original=p,revised=c['revised'] if i==1 else p,signal=['clear','dragging','lost'][i],note=c['note'] if i==1 else '',isResolved=i!=2) for i,p in enumerate(c['paragraphs'])]
    session=dict(id='demo-revision',title=c['title'],knowPromise=c['promises'][0],feelPromise=c['promises'][1],wonderPromise=c['promises'][2],updatedAt=DATE,passages=passages,knowChecked=False,feelChecked=False,wonderChecked=False)
    chapter=dict(id='demo-chapter',title=c['chapter'],content='\n\n'.join(c['paragraphs']),createdAt=DATE,updatedAt=DATE)
    novel=dict(id='demo-novel',title=c['title'],description=c['description'],chapters=[chapter],createdAt=DATE,updatedAt=DATE)
    (ROOT/f'demo-{lang}.json').write_text(json.dumps(dict(schemaVersion=2,sessions=[session],novels=[novel]),ensure_ascii=False,indent=2)+'\n')
print('Created English and Chinese original demo workspaces.')
