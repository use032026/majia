import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/sample_content.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get isChinese => locale.languageCode == 'zh';

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  String text(String zh, String en) => isChinese ? zh : en;

  String get appName => 'ReaderEdit';
  String get tagline => text(
    '写作、阅读、修订，在同一本小说里完成。',
    'Write, read, and revise in one local novel workspace.',
  );
  String get localOnly => text('仅保存在此设备', 'Saved on this device only');
  String get newRevision => text('开始一次修订', 'Start a revision');
  String get trySample => text('用示例体验', 'Try a sample');
  String get yourSessions => text('修订台', 'Revision desk');
  String get emptyTitle => text('给初稿留一点距离', 'Give your draft some distance');
  String get emptyBody => text(
    'ReaderEdit 会先冻结原稿，再让你逐段记录读者感受，最后只处理真正需要修改的地方。',
    'ReaderEdit freezes the original, captures your reader response passage by passage, then focuses the rewrite on what needs attention.',
  );
  String get settings => text('设置与隐私', 'Settings & privacy');
  String get language => text('界面语言', 'Interface language');
  String get chinese => '简体中文';
  String get english => 'English';
  String get darkMode => text('深色外观', 'Dark appearance');
  String get tour => text('使用引导', 'Quick tour');
  String get help => text('帮助', 'Help');
  String get skipTour => text('跳过', 'Skip');
  String get nextTour => text('下一步', 'Next');
  String get finishTour => text('开始创作', 'Open my workspace');
  String tourTitle(int step) => [
    text('把故事留在自己手中', 'Your story, in your hands'),
    text('换个视角，读自己的故事', 'Read with fresh eyes'),
    text('让每次修改都有方向', 'Revise with a clear purpose'),
  ][step];
  String tourBody(int step) => [
    text(
      '创建一本小说，或导入 TXT / Markdown。按章节写作与阅读，作品保存在此设备，无需账号。',
      'Create a novel or import TXT / Markdown. Write and read by chapter, with your work on this device and no account needed.',
    ),
    text(
      '先读，再改。逐段记录“清楚”“拖沓”或“迷失”，留下你的第一感受。',
      'Read before you rewrite. Mark each passage Clear, Dragging, or Lost and capture your first response.',
    ),
    text(
      '集中处理需要调整的段落，保留原稿与前后对照，再核对你想带给读者的感受。',
      'Focus on passages that need attention. Keep the original, compare your edits, and check what the reader should take away.',
    ),
  ][step];

  String get privacyPolicy => text('隐私政策', 'Privacy policy');
  String get privacyUnpublished =>
      text('隐私政策暂未发布', 'Privacy policy is not published yet');
  String get privacyUnpublishedBody => text(
    '在线隐私政策发布后，可在此页面查看。',
    'The online privacy policy will be available here once it is published.',
  );
  String get privacyLoadFailed =>
      text('暂时无法打开隐私政策', 'Unable to open the privacy policy');
  String get privacyLoadFailedBody =>
      text('请检查网络连接后重试。', 'Check your connection and try again.');
  String get dataPrivacy => text('数据与隐私', 'Data & privacy');
  String get dataPrivacyBody => text(
    '小说、章节、草稿、信号和修订记录只保存在应用沙盒内。没有账号、后台、分析或广告。导入文件会复制到本地数据中；复制导出后，文本将进入系统剪贴板并受其他应用管理。',
    'Novels, chapters, drafts, signals, and revision logs stay in the app sandbox. There is no account, backend, analytics, or advertising. Imported text is copied into local data; copied exports enter the system clipboard and are then managed outside ReaderEdit.',
  );
  String get clearAll => text('清空全部本地数据', 'Erase all local data');
  String get clearAllTitle => text('清空全部本地数据？', 'Erase all local data?');
  String get clearAllBody => text(
    '此操作不可撤销，应用内的小说、章节、原稿与修订记录都会删除。',
    'This cannot be undone. Every novel, chapter, draft, and revision record in the app will be deleted.',
  );
  String get cancel => text('取消', 'Cancel');
  String get erase => text('清空', 'Erase');
  String get close => text('关闭', 'Close');
  String get createTitle => text('建立读者视角', 'Set the reader lens');
  String get createIntro => text(
    '原稿不会被覆盖。之后的修改会保留前后对照。',
    'The original stays frozen. Later edits keep a before-and-after record.',
  );
  String get titleLabel => text('稿件标题', 'Draft title');
  String get draftLabel => text('粘贴或输入草稿', 'Paste or type the draft');
  String get draftHint => text(
    '用空行分隔段落，至少 2 段。',
    'Separate passages with blank lines. Minimum: 2.',
  );
  String get readerPromise => text('读者承诺', 'Reader promise');
  String get knowPrompt =>
      text('读完后，读者应该知道什么？', 'What should the reader know?');
  String get feelPrompt => text('读者应该感受到什么？', 'What should the reader feel?');
  String get wonderPrompt =>
      text('读者还应该好奇什么？', 'What should the reader still wonder?');
  String get startScan => text('冻结原稿并开始通读', 'Freeze draft & start scan');
  String get requiredField => text('请填写这一项', 'This field is required');
  String get twoPassages => text(
    '至少需要 2 个由空行分隔的段落',
    'Add at least 2 passages separated by a blank line',
  );
  String get tooLong =>
      text('草稿最多 30,000 个字符', 'Draft limit: 30,000 characters');
  String get tooManyPassages =>
      text('一次最多处理 80 段', 'A session can contain up to 80 passages');
  String get scanTitle => text('读者通读', 'Reader scan');
  String get scanRule => text(
    '先别改字。只记录这一段带来的第一反应。',
    'Do not rewrite yet. Capture only your first reader response.',
  );
  String passageProgress(int current, int total) =>
      text('第 $current / $total 段', 'Passage $current of $total');
  String get signalQuestion =>
      text('作为读者，这一段……', 'As a reader, this passage feels…');
  String get signalClear => text('清楚', 'Clear');
  String get signalDragging => text('拖沓', 'Dragging');
  String get signalLost => text('迷失', 'Lost');
  String get optionalNote => text('读者备注（可选）', 'Reader note (optional)');
  String get noteHint => text(
    '例如：不知道“他”指谁，或转折出现得太晚。',
    'For example: I lost track of who “they” refers to.',
  );
  String get chooseSignal => text('先选择一个读者信号', 'Choose a reader signal first');
  String get unsavedTitle => text('放弃未保存的标记？', 'Discard the unsaved signal?');
  String get unsavedBody => text(
    '当前段落的信号和备注还没有保存。',
    'The current passage signal and note have not been saved.',
  );
  String get discard => text('放弃', 'Discard');
  String get createUnsavedTitle =>
      text('放弃未保存的草稿？', 'Discard this unsaved draft?');
  String get createUnsavedBody => text(
    '已输入的稿件和读者承诺还没有保存。',
    'The draft and reader promise you entered have not been saved.',
  );
  String get previous => text('上一段', 'Previous');
  String get saveNext => text('保存并继续', 'Save & continue');
  String get saveAndReturn => text('保存并返回队列', 'Save & return to queue');
  String get buildQueue => text('保存并建立修订队列', 'Save & build queue');
  String get queueTitle => text('修订队列', 'Revision queue');
  String get queueIntro => text(
    '这里只出现被标记为“拖沓”或“迷失”的段落。修改前版本会一直保留。',
    'Only passages marked Dragging or Lost appear here. The original version remains available.',
  );
  String flaggedSummary(int flagged, int unresolved) => text(
    '$flagged 个信号 · $unresolved 个待处理',
    '$flagged signals · $unresolved open',
  );
  String get noFlagsTitle => text('通读没有发现阻塞点', 'No blockers in this scan');
  String get noFlagsBody => text(
    '你仍可以进入总结，核对最初的读者承诺并导出稿件。',
    'Continue to the summary to check the reader promise and export the draft.',
  );
  String get resolved => text('已解决', 'Resolved');
  String get openIssue => text('待修改', 'Open');
  String get revise => text('修改', 'Revise');
  String get reopen => text('重新打开', 'Reopen');
  String get reassessSignal => text('重判信号', 'Reassess signal');
  String get goToSummary => text('核对与导出', 'Review & export');
  String get revisionTitle => text('前后对照', 'Before & after');
  String get before => text('修改前', 'Before');
  String get after => text('修改后', 'After');
  String get markResolved =>
      text('这条读者信号已经解决', 'This reader signal is resolved');
  String get saveRevision => text('保存修改', 'Save revision');
  String get emptyRevision =>
      text('修订文本不能为空', 'Revised passage cannot be empty');
  String get resolutionNeedsChange => text(
    '要标记为已解决，请先修改正文；也可以返回通读页重新判断信号。',
    'Change the passage before marking it resolved, or return to the scan and reassess the signal.',
  );
  String get summaryTitle => text('核对与导出', 'Review & export');
  String get completionCheck =>
      text('回到最初的读者承诺', 'Return to the reader promise');
  String get promiseKnow => text('读者现在知道：', 'The reader now knows:');
  String get promiseFeel => text('读者现在感受到：', 'The reader now feels:');
  String get promiseWonder => text('读者现在还会好奇：', 'The reader still wonders:');
  String get revisionResult => text('修订结果', 'Revision result');
  String changedSummary(int changed, int total) =>
      text('$total 段中有 $changed 段发生修改', '$changed of $total passages changed');
  String get compareChanges => text('查看全部前后对照', 'View every change');
  String get revisedDraft => text('修订稿', 'Revised draft');
  String get copyDraft => text('复制修订稿', 'Copy revised draft');
  String get copyLog => text('复制修订记录', 'Copy revision log');
  String get copied => text('已复制到系统剪贴板', 'Copied to the system clipboard');
  String get copyFailed => text(
    '无法写入系统剪贴板，请重试。',
    'Could not write to the system clipboard. Please try again.',
  );
  String get incomplete => text('还未完成', 'Still in progress');
  String get complete => text('本轮修订完成', 'Revision complete');
  String get completeBody => text(
    '所有读者信号已处理，三项承诺也已核对。',
    'Every reader signal is resolved and all three promises are checked.',
  );
  String get compareTitle => text('修改记录', 'Change history');
  String get noChanges =>
      text('正文还没有发生修改。', 'No passage text has changed yet.');
  String get deleteSession => text('删除这次修订', 'Delete this revision');
  String get deleteTitle => text('删除“{title}”？', 'Delete “{title}”?');
  String get deleteBody => text(
    '原稿、信号和修订记录都会从本设备删除，无法恢复。',
    'The draft, signals, and revision history will be removed from this device and cannot be recovered.',
  );
  String get delete => text('删除', 'Delete');
  String get saveFailed => text(
    '本地保存失败，刚才的更改没有提交。请重试。',
    'Local save failed. The latest change was not committed. Please try again.',
  );
  String get loadFailed => text(
    '无法读取本地工作区数据。为避免覆盖，ReaderEdit 已停止写入。',
    'Local workspace data could not be read. ReaderEdit stopped before overwriting it.',
  );
  String get retry => text('重试', 'Retry');
  String get recovered => text(
    '主数据异常，已从上一份本地工作区恢复副本打开。请核对最近一次修改。',
    'The primary data was invalid, so ReaderEdit opened the previous local workspace recovery copy. Check your latest edit.',
  );
  String get understood => text('知道了', 'Got it');
  String sessionStage(bool allScanned, int unresolved, bool complete) {
    if (complete) return text('已完成', 'Complete');
    if (!allScanned) return text('通读中', 'Reader scan');
    if (unresolved > 0) return text('修订中', 'Revising');
    return text('待核对', 'Final check');
  }

  String counts(int cjk, int words, int passages) => text(
    '$passages 段 · $cjk 汉字 · $words 英文词',
    '$passages passages · $words words · $cjk CJK characters',
  );
  SampleContent get _sample => SampleContent.forLanguage(locale.languageCode);
  String get sampleTitle => _sample.title;
  String get sampleDraft => _sample.draft;
  String get sampleKnow => _sample.know;
  String get sampleFeel => _sample.feel;
  String get sampleWonder => _sample.wonder;
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
