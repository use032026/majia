import 'domain.dart';

class AppCopy {
  const AppCopy(this.localeCode);

  final String localeCode;
  bool get isZh => localeCode == 'zh';
  String t(String zh, String en) => isZh ? zh : en;

  String get appName => t('微成', 'Steady21');
  String get today => t('今日', 'Today');
  String get journey => t('历程', 'Journey');
  String get settings => t('设置', 'Settings');
  String get cancel => t('取消', 'Cancel');
  String get save => t('保存', 'Save');
  String get delete => t('删除', 'Delete');
  String get edit => t('编辑', 'Edit');
  String get retry => t('重试', 'Retry');
  String get close => t('关闭', 'Close');
  String get continueLabel => t('继续', 'Continue');
  String get archive => t('归档实验', 'Archive experiment');
  String get restore => t('恢复为当前实验', 'Restore as active');
  String get loading => t('正在恢复本地实验…', 'Restoring your local experiment…');
  String get loadFailed => t('无法读取本地记录', 'Could not read local records');
  String get loadFailedBody => t(
    '原文件没有被覆盖。你可以重试；若问题持续，请先保留应用数据再处理。',
    'The original file was not overwritten. Retry, and preserve app data if the problem continues.',
  );
  String get saveFailed => t(
    '保存失败，先前记录没有改变。请重试。',
    'Save failed. Your previous records are unchanged. Please retry.',
  );
  String get emptyTitle => t('从一个微小实验开始', 'Start with one tiny experiment');
  String get emptyBody => t(
    '不是证明你有多自律，而是找出什么做法适合你。21 天是复盘里程碑，不是习惯保证。',
    'This is not a test of willpower. It helps you learn what works. Twenty-one days is a reflection milestone, not a guarantee.',
  );
  String get createExperiment => t('创建行为实验', 'Create behavior experiment');
  String get experimentTitle => t('实验名称', 'Experiment name');
  String get experimentTitleHint => t('例如：晚饭后读书', 'e.g. Read after dinner');
  String get cue => t('触发线索', 'When / where cue');
  String get cueHint => t('例如：收好餐具后', 'e.g. After putting dishes away');
  String get fullAction => t('标准行动', 'Standard action');
  String get fullActionHint => t('例如：读 10 页', 'e.g. Read 10 pages');
  String get minimumAction => t('最低行动', 'Minimum action');
  String get minimumActionHint => t('例如：读 1 页', 'e.g. Read 1 page');
  String get targetDays => t('目标练习天数', 'Target practice days');
  String get targetDaysHelp =>
      t('1–365 天，默认 21 天', '1–365 days; default is 21');
  String get required =>
      t('请完整填写，不要只输入空格', 'Complete every field; spaces do not count');
  String get targetRange =>
      t('请输入 1–365 之间的天数', 'Enter a number from 1 to 365');
  String get create => t('开始实验', 'Start experiment');
  String get update => t('保存修改', 'Save changes');
  String get todayDecision => t('今天怎样行动？', 'How will you act today?');
  String get cueLabel => t('触发线索', 'CUE');
  String get standardLabel => t('标准行动', 'STANDARD');
  String get minimumLabel => t('最低行动', 'MINIMUM');
  String get fullDone => t('完成标准行动', 'Standard action done');
  String get minimumDone => t('只做最低行动', 'Minimum action done');
  String get skipped => t('今天暂停观察', 'Pause and observe today');
  String get editToday => t('改正今天的记录', 'Correct today’s entry');
  String get undoToday => t('撤销今天的记录', 'Undo today’s entry');
  String get note => t('一句观察（可选）', 'One observation (optional)');
  String get noteHint => t('什么让今天更容易或更难？', 'What made today easier or harder?');
  String get obstacle => t('主要阻碍', 'Main obstacle');
  String get recovery => t('下一次怎样调整？', 'What will you adjust next?');
  String get recoveryNeeded => t(
    '检测到中断。先选择一个温和的重启策略。',
    'A break was detected. Choose a gentle restart strategy.',
  );
  String get obstacleRequired =>
      t('暂停时请选择主要阻碍', 'Choose the main obstacle when pausing');
  String get recoveryRequired => t('请选择下一次调整策略', 'Choose a restart strategy');
  String get saveEntry => t('保存今日观察', 'Save today’s observation');
  String get entrySaved => t('今天的观察已保存', 'Today’s observation is saved');
  String get undoTitle => t('撤销今天的记录？', 'Undo today’s entry?');
  String get undoBody => t(
    '统计会立即重新计算，其他日期不受影响。',
    'Stats will be recalculated. Other days stay unchanged.',
  );
  String get archiveTitle => t('归档当前实验？', 'Archive this experiment?');
  String get archiveBody => t(
    '报告和记录会保留，归档后可以开始新的实验。',
    'The report and entries remain, and you can start a new experiment.',
  );
  String get deleteExperimentTitle =>
      t('永久删除这个实验？', 'Delete this experiment permanently?');
  String get deleteExperimentBody =>
      t('本地记录将无法在应用内恢复。', 'Its local records cannot be recovered in the app.');
  String get progress => t('练习进度', 'Practice progress');
  String days(int value) => t('$value 天', '$value days');
  String dayNumber(int value) => t('第 $value 天', 'Day $value');
  String get practiceDays => t('累计练习', 'Practice days');
  String get currentStreak => t('当前连续', 'Current streak');
  String get bestStreak => t('最佳连续', 'Best streak');
  String get recoveries => t('恢复调整', 'Recoveries');
  String get calendarRate => t('日历完成率', 'Calendar practice rate');
  String get commonObstacle => t('常见阻碍', 'Common obstacle');
  String get noObstacle => t('还没有阻碍记录', 'No obstacle recorded yet');
  String get milestoneReview => t('阶段复盘', 'Milestone review');
  String reviewMilestone(int value) =>
      t('复盘第 $value 个练习日', 'Review practice day $value');
  String get reviewQuestion =>
      t('下一阶段，你决定怎样做？', 'What will you do in the next stage?');
  String get reviewNote =>
      t('给下一阶段留一句话（可选）', 'A note for the next stage (optional)');
  String get milestoneNoLongerReached => t(
    '练习记录已经变化，这个里程碑尚未到达。请回到历程页查看最新进度。',
    'Your practice record changed and this milestone is no longer reached. Return to Journey to see the latest progress.',
  );
  String get report => t('实验报告', 'Experiment report');
  String get reportIntro => t(
    '这是你的观察结果，不是对意志力的评分。',
    'These are observations, not a score of your willpower.',
  );
  String get targetReached => t('目标里程碑已到达', 'Target milestone reached');
  String get continueOrArchive => t(
    '你可以继续延展，也可以归档并保留报告。',
    'Continue beyond the target, or archive and keep the report.',
  );
  String get entries => t('逐日观察', 'Daily observations');
  String get noEntries => t('还没有记录', 'No entries yet');
  String get archivedExperiments => t('已归档实验', 'Archived experiments');
  String get currentExperiment => t('当前实验', 'Current experiment');
  String get noActive => t('当前没有进行中的实验', 'No active experiment');
  String get language => t('语言', 'Language');
  String get chinese => '简体中文';
  String get english => 'English';
  String get privacy => t('隐私与本地数据', 'Privacy & local data');
  String get privacyBody => t(
    '记录保存在应用沙盒，不会由本应用上传；不使用账号、广告或分析 SDK。系统备份是否包含这些数据取决于设备设置。卸载、换机或删除数据可能造成永久丢失，本版本不提供独立备份或同步。',
    'Records stay in the app sandbox and are not uploaded by this app. There are no accounts, ads, or analytics SDKs. Device settings decide whether system backups include the data. Uninstalling, changing devices, or deleting data may cause permanent loss; this version has no independent backup or sync.',
  );
  String get scienceBoundary => t('关于 21 天', 'About 21 days');
  String get scienceBody => t(
    '21 天在这里是启动与复盘里程碑，不是形成习惯的保证。不同人和行动需要的时间差异很大。',
    'Twenty-one days is a starting and reflection milestone here, not a guarantee of habit formation. Timing varies widely by person and behavior.',
  );
  String get deleteAll => t('删除全部本地数据', 'Delete all local data');
  String get deleteAllTitle => t('删除全部本地数据？', 'Delete all local data?');
  String get deleteAllBody => t(
    '所有实验与记录都会清除，语言选择会保留。此操作不可撤销。',
    'All experiments and entries will be erased. Your language choice remains. This cannot be undone.',
  );
  String get versionNote => t(
    'MVP 本地候选 · 不代表已通过 App Review',
    'Local MVP candidate · not App Review approval',
  );
  String get activeExists =>
      t('请先归档当前实验', 'Archive the active experiment first');
  String get archived => t('已归档', 'Archived');
  String get restoreBlocked => t(
    '已有进行中的实验，请先归档它',
    'Archive the active experiment before restoring another',
  );

  String tier(ProgressTier tier) => isZh ? tier.zh : tier.en;

  String entryKind(EntryKind kind) => switch (kind) {
    EntryKind.full => t('标准完成', 'Standard done'),
    EntryKind.minimum => t('最低完成', 'Minimum done'),
    EntryKind.skipped => t('暂停观察', 'Paused'),
  };

  String obstacleLabel(Obstacle value) => switch (value) {
    Obstacle.none => t('未选择', 'Not selected'),
    Obstacle.time => t('时间不合适', 'Timing'),
    Obstacle.energy => t('精力不足', 'Low energy'),
    Obstacle.forgot => t('忘记了', 'Forgot'),
    Obstacle.environment => t('环境受阻', 'Environment'),
    Obstacle.tooLarge => t('行动太大', 'Action too large'),
    Obstacle.other => t('其他', 'Other'),
  };

  String recoveryLabel(RecoveryPlan value) => switch (value) {
    RecoveryPlan.none => t('未选择', 'Not selected'),
    RecoveryPlan.makeSmaller => t('把行动再缩小', 'Make it smaller'),
    RecoveryPlan.changeTime => t('换一个时间', 'Change the time'),
    RecoveryPlan.changeCue => t('换一个触发线索', 'Change the cue'),
    RecoveryPlan.keepPlan => t(
      '保持计划，明天重启',
      'Keep the plan and restart tomorrow',
    ),
  };

  String decisionLabel(ReviewDecision value) => switch (value) {
    ReviewDecision.keep => t('保持现在的做法', 'Keep the current plan'),
    ReviewDecision.makeSmaller => t('缩小行动', 'Make the action smaller'),
    ReviewDecision.changeTime => t('调整时间', 'Change the time'),
    ReviewDecision.changeCue => t('调整触发线索', 'Change the cue'),
    ReviewDecision.finish => t('完成并准备结束', 'Finish this experiment'),
  };

  String date(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    return isZh
        ? '${parts[0]}年${int.parse(parts[1])}月${int.parse(parts[2])}日'
        : key;
  }
}
