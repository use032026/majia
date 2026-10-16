import 'revision_session.dart';

class SampleContent {
  const SampleContent({
    required this.title,
    required this.draft,
    required this.know,
    required this.feel,
    required this.wonder,
  });

  final String title;
  final String draft;
  final String know;
  final String feel;
  final String wonder;

  static SampleContent forLanguage(String code) =>
      code == 'zh' ? chinese : english;

  static const chinese = SampleContent(
    title: '雾站来信',
    draft:
        '晚班火车离站后，林秋才发现长椅下有一封没有署名的信。信封很旧，右下角却沾着刚落下的雨。\n\n她拆开信，第一句话写着：“不要搭明早六点的车。”她抬头看向时刻表，又看见玻璃里的自己。\n\n站外没有人。售票窗口已经熄灯，可远处的广播忽然报出了她的名字。',
    know: '车站里有人知道林秋的行程',
    feel: '安静里逐渐出现不安',
    wonder: '是谁写信，为什么不能上车',
  );

  static const english = SampleContent(
    title: 'The Letter at Fog Station',
    draft:
        'After the last train left, Mara found an unsigned letter beneath the station bench. The envelope looked old, but fresh rain darkened one corner.\n\nShe opened it. The first line read: “Do not take the six o’clock train.” She looked up at the timetable, then at her reflection in the glass.\n\nNo one waited outside. The ticket window was dark, yet the distant loudspeaker suddenly announced her name.',
    know: 'Someone at the station knows Mara’s plans',
    feel: 'Unease growing inside a quiet place',
    wonder: 'Who wrote the letter and why the train is dangerous',
  );
}

/// Localizes only an exact built-in manuscript that has not been rewritten.
/// This is a presentation copy: stored originals, progress and user notes stay
/// intact, including samples saved before locale-aware sample display existed.
RevisionSession localizeUneditedSample(RevisionSession session, String code) {
  final target = SampleContent.forLanguage(code);
  final source = code == 'zh' ? SampleContent.english : SampleContent.chinese;
  if (session.title != source.title ||
      session.knowPromise != source.know ||
      session.feelPromise != source.feel ||
      session.wonderPromise != source.wonder) {
    return session;
  }
  final originals = splitDraft(source.draft);
  if (session.passages.length != originals.length) return session;
  for (var i = 0; i < originals.length; i++) {
    if (session.passages[i].original != originals[i] ||
        session.passages[i].revised != originals[i]) {
      return session;
    }
  }
  final translated = splitDraft(target.draft);
  return RevisionSession(
    id: session.id,
    title: target.title,
    knowPromise: target.know,
    feelPromise: target.feel,
    wonderPromise: target.wonder,
    updatedAt: session.updatedAt,
    knowChecked: session.knowChecked,
    feelChecked: session.feelChecked,
    wonderChecked: session.wonderChecked,
    passages: [
      for (var i = 0; i < session.passages.length; i++)
        PassageRevision(
          id: session.passages[i].id,
          original: translated[i],
          revised: translated[i],
          signal: session.passages[i].signal,
          note: session.passages[i].note,
          isResolved: session.passages[i].isResolved,
        ),
    ],
  );
}
