import 'package:flutter/material.dart';

class AppStrings {
  AppStrings(Locale locale) : useChinese = locale.languageCode == 'zh';

  final bool useChinese;

  static const Map<String, String> _zh = <String, String>{
    'appName': 'Almanac',
    'tagline': '一日一笺，留一寸清明',
    'introEyebrow': '现代日笺 · 本地生成',
    'introTitle': '把宜与忌，变成\n今天自己的选择',
    'introBody': '借鉴传统黄历的表达方式，用本机规则生成反思提示与原创短诗。没有账号，也不需要联网。',
    'notDivination': '不是择日或吉凶预测',
    'privateByDesign': '你的选择与文字只写在本机；系统备份或主动复制除外。',
    'openToday': '打开今日笺',
    'onboardingNext': '继续',
    'onboardingSkip': '跳过',
    'onboardingStep2Eyebrow': '01 / 一日一笺',
    'onboardingStep2Title': '选一项宜，留一项忌',
    'onboardingStep2Body': '读一段原创短诗，选下今天想尝试与放下的事；可以写一句意图，晚些时候再回看。',
    'onboardingStep3Eyebrow': '02 / 留在本机',
    'onboardingStep3Title': '只属于你的笺册',
    'onboardingStep3Body': '日笺和回看保存在应用本地。无需账号或联网；你可以在设置中复制或清除记录。',
    'onboardingPreviewTry': '试着慢一点',
    'onboardingPreviewSkip': '少一点分心',
    'onboardingPreviewIntention': '留一寸清明',
    'onboardingPreviewFolio': '笺册',
    'today': '今日',
    'folio': '笺册',
    'settings': '设置',
    'culturalLabel': '文化灵感 · 非运势',
    'chooseOneEach': '各选一项，作为今天的轻提醒',
    'suitable': '宜',
    'avoid': '忌',
    'verseLabel': '今日成句',
    'composedLocally': '由本机规则组合 · 项目原创文字',
    'intentionLabel': '留一句今日意图（可选）',
    'intentionHint': '例如：午后先把桌面清出一角',
    'seal': '收下今日笺',
    'saving': '正在写入本机…',
    'sealed': '今日已收笺',
    'yourChoice': '你的今日选择',
    'todayIntention': '今日意图',
    'reflect': '回看今日',
    'reflectionPrompt': '今天更接近哪一种？',
    'practiced': '践行',
    'reframed': '调整',
    'released': '放下',
    'notReflected': '尚未回看',
    'emptyFolio': '笺册还是空的',
    'emptyFolioBody': '收下第一张今日笺后，它会安静地留在这里。',
    'language': '语言',
    'settingsIntroTitle': '让日笺更合手',
    'settingsIntroBody': '默认跟随系统；手动选择的语言和外观会保留。',
    'languageHint': '跟随设备语言，或固定一种语言',
    'systemLanguage': '跟随系统',
    'chinese': '简体中文',
    'english': 'English',
    'appearance': '外观',
    'appearanceHint': '跟随设备外观，或固定浅色与深色',
    'system': '跟随系统',
    'light': '浅色',
    'dark': '深色',
    'dataAndPrivacy': '数据与隐私',
    'copyArchive': '复制岁时册（Markdown）',
    'copyArchiveHint': '将已收笺复制到剪贴板',
    'copied': '已复制到系统剪贴板',
    'clearRecords': '清除全部日笺',
    'clearRecordsHint': '删除日笺内容，保留偏好设置',
    'clearConfirmTitle': '清除全部日笺？',
    'clearConfirmBody': '这会删除应用管理的全部选择与文字，无法撤销。语言与外观设置会保留。',
    'cancel': '取消',
    'clear': '确认清除',
    'privacyTitle': '本地隐私说明',
    'privacyHint': '查看本地存储、备份与复制说明',
    'privacyIntro': '这里说明当前版本如何在设备上处理你的日笺。',
    'privacyStorageTitle': '本地记录',
    'privacyStorageBody':
        '安装种子、每日选择、意图、回看和偏好保存在应用本地。当前版本不向开发者服务器发送这些内容，也不含账号、广告或分析 SDK。',
    'privacyBackupTitle': '备份与主动复制',
    'privacyBackupBody': '系统备份、设备迁移以及你主动复制到剪贴板的内容，可能由操作系统或其他应用处理。',
    'privacyDeleteTitle': '清除与保留',
    'privacyDeleteBody':
        '“清除全部日笺”会删除应用管理的选择和文字，语言与外观偏好仍保留；复制的 Markdown 不是可恢复备份。',
    'methodTitle': '内容方法',
    'methodBody':
        '宜忌与短诗均为项目原创内容，由日期和本机安装种子稳定组合。切换语言不会改变当天内容 ID。内容不构成医疗、法律、财务或安全建议。',
    'loadErrorTitle': '无法安全读取本地日笺',
    'loadErrorBody': '为避免把读取失败误当成空数据，Almanac 已停止写入。你可以先重试；确认无需保留旧数据后再重置。',
    'saveError': '未能保存。原有本地记录没有被替换，请重试。',
    'dayChanged': '日期已经更新。请重新选择今天的宜与忌。',
    'retry': '重试读取',
    'resetLocal': '重置本地数据',
    'resetConfirmTitle': '重置本地数据？',
    'resetConfirmBody': '仅在旧数据无需恢复时继续。此操作不可撤销。',
    'back': '返回',
    'noIntention': '未写今日意图',
    'detail': '日笺详情',
    'close': '关闭',
  };

  static const Map<String, String> _en = <String, String>{
    'appName': 'Almanac',
    'tagline': 'One leaf a day, one clear intention',
    'introEyebrow': 'A MODERN DAILY LEAF · MADE LOCALLY',
    'introTitle': 'Turn “try and skip”\ninto your own choice',
    'introBody':
        'Inspired by the form of traditional almanacs, local rules compose reflection prompts and original verse. No account or network needed.',
    'notDivination': 'Not divination or auspicious-date advice',
    'privateByDesign':
        'Your choices and writing stay in the app, except for system backups or copies you make.',
    'openToday': 'Open today’s leaf',
    'onboardingNext': 'Continue',
    'onboardingSkip': 'Skip',
    'onboardingStep2Eyebrow': '01 / ONE DAILY LEAF',
    'onboardingStep2Title': 'Choose one Try and one Skip',
    'onboardingStep2Body':
        'Read an original verse, choose what to try and set aside, then leave an optional intention to revisit later.',
    'onboardingStep3Eyebrow': '02 / KEPT ON YOUR DEVICE',
    'onboardingStep3Title': 'A folio of your own',
    'onboardingStep3Body':
        'Your leaves and reflections stay in local app storage. No account or network is needed; you can copy or clear records in Settings.',
    'onboardingPreviewTry': 'Take it slowly',
    'onboardingPreviewSkip': 'Less distraction',
    'onboardingPreviewIntention': 'Make room for clarity',
    'onboardingPreviewFolio': 'Folio',
    'today': 'Today',
    'folio': 'Folio',
    'settings': 'Settings',
    'culturalLabel': 'Cultural prompt · Not a prediction',
    'chooseOneEach': 'Choose one of each as a gentle cue for today',
    'suitable': 'Try',
    'avoid': 'Skip',
    'verseLabel': 'Today’s composed verse',
    'composedLocally': 'Composed locally · Original project text',
    'intentionLabel': 'Leave one intention (optional)',
    'intentionHint': 'For example: clear one corner after lunch',
    'seal': 'Seal today’s leaf',
    'saving': 'Saving on this device…',
    'sealed': 'Today’s leaf is sealed',
    'yourChoice': 'Your choices for today',
    'todayIntention': 'Today’s intention',
    'reflect': 'Reflect on today',
    'reflectionPrompt': 'Which feels closest today?',
    'practiced': 'Practiced',
    'reframed': 'Reframed',
    'released': 'Released',
    'notReflected': 'Not reflected yet',
    'emptyFolio': 'Your folio is still empty',
    'emptyFolioBody': 'Seal your first daily leaf and it will rest here.',
    'language': 'Language',
    'settingsIntroTitle': 'Make Almanac yours',
    'settingsIntroBody':
        'Language and appearance follow your device until you choose otherwise.',
    'languageHint': 'Follow your device or choose a language',
    'systemLanguage': 'Use system language',
    'chinese': '简体中文',
    'english': 'English',
    'appearance': 'Appearance',
    'appearanceHint': 'Follow your device or choose light or dark',
    'system': 'Use system setting',
    'light': 'Light',
    'dark': 'Dark',
    'dataAndPrivacy': 'Data & privacy',
    'copyArchive': 'Copy folio as Markdown',
    'copyArchiveHint': 'Copy sealed leaves to the clipboard',
    'copied': 'Copied to the system clipboard',
    'clearRecords': 'Clear all daily leaves',
    'clearRecordsHint': 'Remove leaves and keep your preferences',
    'clearConfirmTitle': 'Clear every daily leaf?',
    'clearConfirmBody':
        'This permanently removes all app-managed choices and writing. Language and appearance settings remain.',
    'cancel': 'Cancel',
    'clear': 'Clear permanently',
    'privacyTitle': 'Local privacy note',
    'privacyHint': 'Read about local storage, backups, and copying',
    'privacyIntro':
        'How this version handles your daily leaves on your device.',
    'privacyStorageTitle': 'Local records',
    'privacyStorageBody':
        'The installation seed, daily choices, intentions, reflections, and preferences stay in local app storage. This version does not send them to a developer server and has no account, ads, or analytics SDK.',
    'privacyBackupTitle': 'Backups and copies',
    'privacyBackupBody':
        'System backups, device migration, and content you copy to the clipboard may be handled by the operating system or other apps.',
    'privacyDeleteTitle': 'Clearing and keeping',
    'privacyDeleteBody':
        '“Clear all daily leaves” removes app-managed choices and writing but keeps language and appearance preferences. Copied Markdown is not a restorable backup.',
    'methodTitle': 'Content method',
    'methodBody':
        'Prompts and verse are original project text, combined deterministically from the date and a local installation seed. Language changes do not change content IDs. Nothing here is medical, legal, financial, or safety advice.',
    'loadErrorTitle': 'Local leaves could not be read safely',
    'loadErrorBody':
        'Almanac stopped writing so a read failure cannot be mistaken for empty data. Retry first, or reset only when the old data is no longer needed.',
    'saveError':
        'Not saved. Existing local records were not replaced. Please retry.',
    'dayChanged':
        'The date has changed. Please choose today’s Try and Skip again.',
    'retry': 'Retry reading',
    'resetLocal': 'Reset local data',
    'resetConfirmTitle': 'Reset local data?',
    'resetConfirmBody':
        'Continue only if the old data does not need recovery. This cannot be undone.',
    'back': 'Back',
    'noIntention': 'No intention added',
    'detail': 'Daily leaf detail',
    'close': 'Close',
  };

  String text(String key) => (useChinese ? _zh : _en)[key] ?? key;

  String formatDate(DateTime date) {
    if (useChinese) {
      const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
      return '${date.year}年${date.month}月${date.day}日 · 周${weekdays[date.weekday - 1]}';
    }
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String outcome(String? name) {
    if (name == null) return text('notReflected');
    return text(name);
  }
}
