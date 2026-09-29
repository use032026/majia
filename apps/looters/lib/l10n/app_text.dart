import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class AppText {
  AppText(this.languageCode);

  final String languageCode;
  bool get isZh => languageCode == 'zh';

  static AppText of(BuildContext context) =>
      AppText(Localizations.localeOf(context).languageCode);

  String get(String key) =>
      (_values[languageCode] ?? _values['en']!)[key] ?? key;

  String date(DateTime value) => isZh
      ? '${value.year}年${value.month}月${value.day}日'
      : DateFormat('MMM d, yyyy', 'en').format(value);

  String eventCount(int value) =>
      isZh ? '$value 条事件' : '$value ${value == 1 ? 'event' : 'events'}';
  String planCount(int value) => isZh
      ? '$value 个计划版本'
      : '$value ${value == 1 ? 'plan version' : 'plan versions'}';
  String remainingWeeks(int value) =>
      isZh ? '约 $value 周' : 'About $value weeks';

  static const Map<String, Map<String, String>> _values = {
    'zh': {
      'appName': 'PaceJar · 节奏罐',
      'loading': '正在读取本地记录',
      'offlineBadge': '离线可用 · 不连接银行',
      'emptyTitle': '给波动留一点余地',
      'emptyBody': '只记录，不移动真实资金。把计划和实际分开，偏离后再选择怎样恢复。',
      'createGoal': '创建专注目标',
      'whyDifferent': '每次调整都会留下计划版本，不改写过去。',
      'pace': '节奏',
      'timeline': '时间线',
      'settings': '设置',
      'recordWeek': '记录本周',
      'planTrack': '计划应达',
      'actualTrack': '实际记录',
      'difference': '当前差额',
      'weeklyPlan': '当前周额',
      'weeklyNeeded': '到期所需周额',
      'remaining': '距离目标',
      'recentEvents': '最近变化',
      'viewAll': '查看全部',
      'noEvents': '还没有金额变化。第一次记录后，计划与实际才会开始分开。',
      'statusAhead': '提前',
      'statusOnTrack': '按节奏进行',
      'statusRecovery': '需要恢复',
      'statusExpired': '目标日期已过',
      'statusCompleted': '目标已达成',
      'aheadHelp': '实际记录高于当前计划，不需要加速。',
      'onTrackHelp': '当前记录与计划一致，继续按可承受周额前进。',
      'recoveryHelp': '实际或当前周额低于计划。选择一种方式重算未来，不改写过去。',
      'expiredHelp': '日期已过但目标未完成。先记录真实变化，再选择新的节奏。',
      'completedHelp': '你已经达到目标。复盘计划变化后，可以开始一个新目标。',
      'completedOn': '完成日期',
      'viewRecovery': '查看恢复方案',
      'viewReview': '查看复盘',
      'startNew': '开始新目标',
      'goalName': '目标名称',
      'goalNameHint': '例如：冬季旅行备用金',
      'currency': '货币符号',
      'targetAmount': '目标金额',
      'alreadySaved': '目前已存',
      'weeklyComfort': '当前可承受周额',
      'targetDate': '目标日期',
      'chooseDate': '选择日期',
      'create': '创建计划',
      'cancel': '取消',
      'required': '请填写此项',
      'invalidAmount': '请输入 0.01 至 9,999,999,999.99 的金额',
      'startingTooLarge': '目前已存必须小于目标金额',
      'dateInFuture': '目标日期必须在未来',
      'nameTooLong': '目标名称最多 40 个字符',
      'currencyInvalid': '货币符号需为 1–4 个字符',
      'planFeasible': '按这个周额，预计能在目标日前完成。',
      'planTight': '当前周额低于按期完成所需；创建后会提示恢复方案。',
      'manualOnly': '本 App 只保存手动记录，不代表银行余额，也不构成财务建议。',
      'eventTitle': '发生了什么？',
      'eventSubtitle': '选择最接近真实情况的一项。',
      'deposit': '已存',
      'depositHelp': '把真实放到目标里的金额记下来。',
      'withdrawal': '临时取出',
      'withdrawalHelp': '只减少本地记录，不会操作任何账户。',
      'skipped': '本周跳过',
      'skippedHelp': '保留一次真实偏离，方便之后选择恢复方式。',
      'amount': '金额',
      'reasonOptional': '原因（可选）',
      'reasonHint': '例如：这周收入较少',
      'noteTooLong': '原因最多 120 个字符',
      'withdrawalTooLarge': '取出金额不能超过当前记录',
      'saveEvent': '保存记录',
      'saved': '已保存',
      'saveFailed': '未能保存，本地旧数据没有改变。请重试或取消。',
      'loadFailed': '未能读取本地记录。请重启 App 后重试。',
      'loadFailedTitle': '本地记录暂时无法打开',
      'loadFailedSafety': '为避免覆盖旧记录，问题解决前不会开放新建或删除操作。',
      'invalidInput': '输入内容无效，请检查后重试。',
      'copyFailed': '未能写入剪贴板，本地记录没有改变。',
      'retry': '重试',
      'recoveryTitle': '选择未来怎样恢复',
      'recoveryIntro': '可用方案只改变未来计划；过去的金额和承诺会保留在时间线。',
      'keepDate': '保持目标日期',
      'keepDateHelp': '提高每周金额，日期不变。',
      'keepDateExpired': '原日期已过，请保持周额顺延，或自定新周额。',
      'keepWeekly': '保持当前周额',
      'keepWeeklyHelp': '周额不变，把目标日期顺延。',
      'customWeekly': '自定可承受周额',
      'customWeeklyHelp': '输入新的周额，自动计算目标日期。',
      'newWeekly': '新周额',
      'newDate': '新目标日期',
      'applyPlan': '保存新计划版本',
      'planSaved': '新的计划版本已保存',
      'timelineEmpty': '记录金额或调整计划后，变化会出现在这里。',
      'planChanged': '计划已调整',
      'initialPlan': '初始计划',
      'copySummary': '复制复盘摘要',
      'copied': '复盘摘要已复制',
      'appearance': '外观',
      'darkMode': '深色模式',
      'language': '语言',
      'privacyTitle': '隐私与边界',
      'privacyBody': '目标、金额和备注只保存在这台设备。无账号、无广告、无分析、无银行连接。卸载可能导致数据丢失。',
      'deleteAll': '删除全部本地数据',
      'deleteTitle': '永久删除当前目标？',
      'deleteBody': '目标、金额事件和全部计划版本都会从本机删除，App 无法恢复。',
      'delete': '永久删除',
      'replaceTitle': '开始新目标？',
      'replaceBody': '当前目标、事件和计划版本会被永久删除。可先复制复盘摘要。',
      'corruptTitle': '本地记录无法读取',
      'corruptBody': 'PaceJar 没有自动覆盖损坏内容。要继续使用，请确认清除后重新开始。',
      'clearCorrupt': '清除损坏记录',
      'appBoundary': 'PaceJar 不存钱，只帮你记录与调整计划。',
    },
    'en': {
      'appName': 'PaceJar',
      'loading': 'Reading your local record',
      'offlineBadge': 'Works offline · No bank connection',
      'emptyTitle': 'Leave room for uneven weeks',
      'emptyBody':
          'Track only—no money moves. Keep plan and reality separate, then choose how to recover.',
      'createGoal': 'Create a focus goal',
      'whyDifferent':
          'Every adjustment becomes a plan version. The past is never rewritten.',
      'pace': 'Pace',
      'timeline': 'Timeline',
      'settings': 'Settings',
      'recordWeek': 'Record this week',
      'planTrack': 'Planned by now',
      'actualTrack': 'Actually recorded',
      'difference': 'Current gap',
      'weeklyPlan': 'Current weekly pace',
      'weeklyNeeded': 'Weekly pace needed',
      'remaining': 'Remaining',
      'recentEvents': 'Recent changes',
      'viewAll': 'View all',
      'noEvents':
          'No money changes yet. Your plan and reality separate after the first record.',
      'statusAhead': 'Ahead',
      'statusOnTrack': 'On pace',
      'statusRecovery': 'Recovery needed',
      'statusExpired': 'Target date passed',
      'statusCompleted': 'Goal reached',
      'aheadHelp':
          'Your record is ahead of the current plan. No need to speed up.',
      'onTrackHelp':
          'Your record matches the plan. Keep the pace you can afford.',
      'recoveryHelp':
          'Reality or the current weekly pace is below plan. Recalculate the future without rewriting the past.',
      'expiredHelp':
          'The date passed before the goal was complete. Record reality, then choose a new pace.',
      'completedHelp':
          'You reached the goal. Review the plan changes before starting another.',
      'completedOn': 'Completed on',
      'viewRecovery': 'View recovery options',
      'viewReview': 'View review',
      'startNew': 'Start a new goal',
      'goalName': 'Goal name',
      'goalNameHint': 'For example: winter travel buffer',
      'currency': 'Currency symbol',
      'targetAmount': 'Target amount',
      'alreadySaved': 'Already saved',
      'weeklyComfort': 'Weekly amount you can afford',
      'targetDate': 'Target date',
      'chooseDate': 'Choose date',
      'create': 'Create plan',
      'cancel': 'Cancel',
      'required': 'This field is required',
      'invalidAmount': 'Enter an amount from 0.01 to 9,999,999,999.99',
      'startingTooLarge': 'Already saved must be below the target',
      'dateInFuture': 'Target date must be in the future',
      'nameTooLong': 'Goal name can have up to 40 characters',
      'currencyInvalid': 'Use 1–4 characters for currency',
      'planFeasible': 'At this pace, the plan can finish by the target date.',
      'planTight':
          'This pace is below what the date needs. Recovery options will be available after creation.',
      'manualOnly':
          'This app stores manual records only. It is not a bank balance or financial advice.',
      'eventTitle': 'What happened?',
      'eventSubtitle': 'Choose the option closest to reality.',
      'deposit': 'Saved',
      'depositHelp': 'Record money you actually set aside for this goal.',
      'withdrawal': 'Taken out',
      'withdrawalHelp': 'Reduces the local record only. No account is touched.',
      'skipped': 'Skipped this week',
      'skippedHelp':
          'Keep an honest gap so you can choose a recovery path later.',
      'amount': 'Amount',
      'reasonOptional': 'Reason (optional)',
      'reasonHint': 'For example: lower income this week',
      'noteTooLong': 'Reason can have up to 120 characters',
      'withdrawalTooLarge': 'You cannot take out more than the current record',
      'saveEvent': 'Save record',
      'saved': 'Saved',
      'saveFailed':
          'Could not save. Your previous local data is unchanged. Retry or cancel.',
      'loadFailed':
          'Could not read the local record. Restart the app and retry.',
      'loadFailedTitle': 'Local record is temporarily unavailable',
      'loadFailedSafety':
          'Create and delete stay locked until reading succeeds, so an older record cannot be overwritten.',
      'invalidInput': 'That input is invalid. Check it and try again.',
      'copyFailed':
          'Could not write to the clipboard. Your local record is unchanged.',
      'retry': 'Retry',
      'recoveryTitle': 'Choose how the future recovers',
      'recoveryIntro':
          'Available options change only the future plan. Past money and commitments remain on the timeline.',
      'keepDate': 'Keep the target date',
      'keepDateHelp': 'Raise the weekly amount and keep the date.',
      'keepDateExpired':
          'The original date passed. Extend at the current pace or set a new weekly amount.',
      'keepWeekly': 'Keep the weekly amount',
      'keepWeeklyHelp': 'Keep the amount and move the date later.',
      'customWeekly': 'Set an affordable weekly amount',
      'customWeeklyHelp': 'Enter a new amount and calculate the date.',
      'newWeekly': 'New weekly amount',
      'newDate': 'New target date',
      'applyPlan': 'Save new plan version',
      'planSaved': 'New plan version saved',
      'timelineEmpty': 'Money events and plan changes will appear here.',
      'planChanged': 'Plan adjusted',
      'initialPlan': 'Initial plan',
      'copySummary': 'Copy review summary',
      'copied': 'Review summary copied',
      'appearance': 'Appearance',
      'darkMode': 'Dark mode',
      'language': 'Language',
      'privacyTitle': 'Privacy and boundaries',
      'privacyBody':
          'Goals, amounts, and notes stay on this device. No account, ads, analytics, or bank connection. Uninstalling may remove the data.',
      'deleteAll': 'Delete all local data',
      'deleteTitle': 'Permanently delete this goal?',
      'deleteBody':
          'The goal, money events, and every plan version will be removed from this device. The app cannot recover them.',
      'delete': 'Delete permanently',
      'replaceTitle': 'Start a new goal?',
      'replaceBody':
          'The current goal, events, and plan versions will be permanently deleted. Copy the review first if needed.',
      'corruptTitle': 'The local record cannot be read',
      'corruptBody':
          'PaceJar did not overwrite the damaged content. To continue, confirm a clear start.',
      'clearCorrupt': 'Clear damaged record',
      'appBoundary':
          'PaceJar never holds money. It only helps you record and adjust a plan.',
    },
  };
}
