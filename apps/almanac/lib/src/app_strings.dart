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
    'reflect': '回看今日',
    'reflectionPrompt': '今天更接近哪一种？',
    'practiced': '践行',
    'reframed': '调整',
    'released': '放下',
    'notReflected': '尚未回看',
    'emptyFolio': '笺册还是空的',
    'emptyFolioBody': '收下第一张今日笺后，它会安静地留在这里。',
    'language': '语言',
    'systemLanguage': '跟随系统',
    'chinese': '简体中文',
    'english': 'English',
    'appearance': '外观',
    'system': '跟随系统',
    'light': '浅色',
    'dark': '深色',
    'dataAndPrivacy': '数据与隐私',
    'copyArchive': '复制岁时册（Markdown）',
    'copied': '已复制到系统剪贴板',
    'clearRecords': '清除全部日笺',
    'clearConfirmTitle': '清除全部日笺？',
    'clearConfirmBody': '这会删除应用管理的全部选择与文字，无法撤销。语言与外观设置会保留。',
    'cancel': '取消',
    'clear': '确认清除',
    'privacyTitle': '本地隐私说明',
    'privacyBody':
        '应用不向开发者服务器发送数据，不含账号、广告或分析 SDK。你的意图与回看文字保存在应用本地。系统备份和你主动复制的内容可能离开设备。',
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
    'reflect': 'Reflect on today',
    'reflectionPrompt': 'Which feels closest today?',
    'practiced': 'Practiced',
    'reframed': 'Reframed',
    'released': 'Released',
    'notReflected': 'Not reflected yet',
    'emptyFolio': 'Your folio is still empty',
    'emptyFolioBody': 'Seal your first daily leaf and it will rest here.',
    'language': 'Language',
    'systemLanguage': 'Use system language',
    'chinese': '简体中文',
    'english': 'English',
    'appearance': 'Appearance',
    'system': 'Use system setting',
    'light': 'Light',
    'dark': 'Dark',
    'dataAndPrivacy': 'Data & privacy',
    'copyArchive': 'Copy folio as Markdown',
    'copied': 'Copied to the system clipboard',
    'clearRecords': 'Clear all daily leaves',
    'clearConfirmTitle': 'Clear every daily leaf?',
    'clearConfirmBody':
        'This permanently removes all app-managed choices and writing. Language and appearance settings remain.',
    'cancel': 'Cancel',
    'clear': 'Clear permanently',
    'privacyTitle': 'Local privacy note',
    'privacyBody':
        'The app sends no data to a developer server and includes no account, ads, or analytics SDK. Intentions and reflections stay in local app storage. System backups and copies you make can leave the device.',
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
