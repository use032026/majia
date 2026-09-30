import 'package:flutter/widgets.dart';

class AppText {
  AppText(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode == 'zh';

  static AppText of(BuildContext context) {
    return AppText(Localizations.localeOf(context));
  }

  String get appName => isZh ? '回声页' : 'EchoPage';
  String get today => isZh ? '此刻' : 'Now';
  String get revisit => isZh ? '回看' : 'Revisit';
  String get archive => isZh ? '线索' : 'Threads';
  String get settings => isZh ? '设置' : 'Settings';
  String get newEntry => isZh ? '写下此刻' : 'Capture this moment';
  String get editEntry => isZh ? '编辑原页' : 'Edit original page';
  String get recentPages => isZh ? '最近的页' : 'Recent pages';
  String get dueNow => isZh ? '现在值得回看' : 'Ready to revisit';
  String get openThreads => isZh ? '仍在等待的线索' : 'Open threads';
  String get upcoming => isZh ? '之后再看' : 'Later';
  String get noEntriesTitle =>
      isZh ? '第一条线索从此刻开始' : 'Your first thread starts here';
  String get noEntriesBody => isZh
      ? '写下发生了什么，再留一个问题给未来的自己。'
      : 'Capture what happened, then leave one question for your future self.';
  String get noDueTitle => isZh ? '暂时没有到期的回看' : 'Nothing is due yet';
  String get noDueBody => isZh
      ? '新的问题会按你选择的日期回到这里。'
      : 'New questions will return here on the date you choose.';
  String get entryTitle => isZh ? '一句标题（可选）' : 'A short title (optional)';
  String get entryBody => isZh ? '此刻发生了什么？' : 'What is happening now?';
  String get futureQuestion =>
      isZh ? '留给未来自己的问题（可选）' : 'A question for your future self (optional)';
  String get futureQuestionHint => isZh
      ? '例如：一周后，我还会在意同一件事吗？'
      : 'For example: Will this still matter to me in a week?';
  String get requiredBody => isZh ? '请先写下此刻。' : 'Write this moment first.';
  String get revisitDate => isZh ? '什么时候再看' : 'When to revisit';
  String get reopenThread => isZh ? '重新打开这条线索' : 'Reopen this thread';
  String get reopenThreadHint => isZh
      ? '开启后可安排新的回看日期；关闭状态不会因普通编辑而改变。'
      : 'Turn this on to schedule another revisit. Normal edits keep the thread closed.';
  String get inThreeDays => isZh ? '3 天后' : 'In 3 days';
  String get inOneWeek => isZh ? '7 天后' : 'In 7 days';
  String get inOneMonth => isZh ? '30 天后' : 'In 30 days';
  String get save => isZh ? '保存' : 'Save';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get saving => isZh ? '正在保存…' : 'Saving…';
  String get savedFailure =>
      isZh ? '没有保存；原数据未改变。' : 'Not saved; existing data was unchanged.';
  String get mood => isZh ? '此刻的色调' : 'Tone of this moment';
  String get calm => isZh ? '平静' : 'Calm';
  String get bright => isZh ? '明亮' : 'Bright';
  String get heavy => isZh ? '沉重' : 'Heavy';
  String get uncertain => isZh ? '未定' : 'Uncertain';
  String get energized => isZh ? '有力' : 'Energized';
  String get originalPage => isZh ? '当时写下' : 'Original page';
  String get questionForLater => isZh ? '给未来的问题' : 'Question for later';
  String get echoes => isZh ? '后来的回声' : 'Later echoes';
  String get addEcho => isZh ? '补写回声' : 'Add an echo';
  String get echoPrompt => isZh ? '后来发生了什么？' : 'What happened afterward?';
  String get echoRequired =>
      isZh ? '请写下后来的变化。' : 'Write what changed afterward.';
  String get perspective => isZh ? '现在怎么看' : 'How it feels now';
  String get same => isZh ? '大致相同' : 'Mostly the same';
  String get clearer => isZh ? '更清楚了' : 'Clearer now';
  String get changed => isZh ? '方向变了' : 'Direction changed';
  String get resolved => isZh ? '可以放下' : 'Ready to close';
  String get closeThread =>
      isZh ? '写完后关闭这条线索' : 'Close this thread after saving';
  String get keepOpen => isZh ? '继续等待 7 天' : 'Revisit again in 7 days';
  String get closed => isZh ? '已关闭' : 'Closed';
  String get open => isZh ? '等待回看' : 'Waiting';
  String get plainPage => isZh ? '普通日记页' : 'Journal page';
  String get copyRecord => isZh ? '复制前后记录' : 'Copy full record';
  String get copied => isZh ? '已复制到系统剪贴板' : 'Copied to the system clipboard';
  String get copyFailed => isZh
      ? '无法写入系统剪贴板；内容没有被复制。'
      : 'Could not write to the system clipboard. Nothing was copied.';
  String get edit => isZh ? '编辑' : 'Edit';
  String get delete => isZh ? '移到最近删除' : 'Move to Recently Deleted';
  String get confirmDeleteTitle =>
      isZh ? '移到最近删除？' : 'Move to Recently Deleted?';
  String get confirmDeleteBody => isZh
      ? '之后仍可恢复，或再永久删除。'
      : 'You can restore it later or delete it permanently.';
  String get move => isZh ? '移入' : 'Move';
  String get search =>
      isZh ? '搜索标题、正文、问题或回声' : 'Search titles, pages, questions, or echoes';
  String get all => isZh ? '全部' : 'All';
  String get waiting => isZh ? '等待' : 'Waiting';
  String get completed => isZh ? '完成' : 'Closed';
  String get noResults => isZh ? '没有找到匹配的线索。' : 'No matching threads found.';
  String get recentlyDeleted => isZh ? '最近删除' : 'Recently Deleted';
  String get trashEmpty => isZh ? '最近删除为空。' : 'Recently Deleted is empty.';
  String get restore => isZh ? '恢复' : 'Restore';
  String get deleteForever => isZh ? '永久删除' : 'Delete forever';
  String get emptyTrash => isZh ? '清空最近删除' : 'Empty Recently Deleted';
  String get irreversible => isZh
      ? '这会从当前安装及应用内备份中移除所选内容，且无法在 App 内撤销；历史系统备份仍可能保留副本。'
      : 'This removes the selected content from this installation and its in-app backup and cannot be undone in the app. Past system backups may still contain a copy.';
  String get language => isZh ? '语言' : 'Language';
  String get followSystem => isZh ? '跟随系统' : 'System';
  String get chinese => '简体中文';
  String get english => 'English';
  String get appearance => isZh ? '外观' : 'Appearance';
  String get light => isZh ? '浅色' : 'Light';
  String get dark => isZh ? '深色' : 'Dark';
  String get dataPrivacy => isZh ? '数据与隐私' : 'Data & privacy';
  String get privacySummary => isZh
      ? '内容保存在应用沙盒中，开发者无法读取。无账号、无广告、无分析 SDK；只有你主动复制时，文本才会进入系统剪贴板。设备或云端的系统级备份由操作系统与用户设置控制。'
      : 'Content stays in the app sandbox and is not accessible to the developer. There are no accounts, ads, or analytics SDKs. Text reaches the system clipboard only when you choose Copy. Device or cloud backups are controlled by the operating system and your settings.';
  String get clearAll => isZh ? '清空全部本地数据' : 'Clear all local data';
  String get clearAllTitle => isZh ? '清空所有日记？' : 'Clear every diary entry?';
  String get clearAllBody => isZh
      ? '所有页面、问题和回声都会从当前安装及应用内备份中删除。语言与外观设置会保留；历史系统备份仍可能保留副本。'
      : 'Every page, question, and echo will be removed from this installation and its in-app backup. Language and appearance stay unchanged; past system backups may still contain a copy.';
  String get recoveredTitle =>
      isZh ? '已从本地备份恢复' : 'Recovered from a local backup';
  String get recoveredBody => isZh
      ? '主数据文件无法读取，本次已使用上一份可读备份。请检查内容是否完整。'
      : 'The primary data file could not be read, so the latest readable local backup was used. Please check your content.';
  String get dismiss => isZh ? '知道了' : 'Dismiss';
  String get retry => isZh ? '重试' : 'Retry';
  String get storageErrorTitle =>
      isZh ? '暂时无法读取本地日记' : 'Local diary data is unavailable';
  String get storageErrorBody => isZh
      ? '为了避免覆盖原数据，编辑功能已锁定。请重试；原文件不会被自动清空。'
      : 'Editing is locked to avoid overwriting existing data. Retry; the original files will not be cleared automatically.';
  String get noQuestion =>
      isZh ? '这页没有留下未来问题。' : 'This page has no question for later.';
  String get pageUntitled => isZh ? '无标题的一页' : 'Untitled page';
  String get due => isZh ? '到期' : 'Due';
  String get later => isZh ? '之后' : 'Later';
  String get wordCount => isZh ? '字' : 'characters';
}
