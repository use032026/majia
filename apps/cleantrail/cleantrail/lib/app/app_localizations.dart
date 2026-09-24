import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('zh')];
  static const delegate = _AppLocalizationsDelegate();

  bool get isChinese => locale.languageCode == 'zh';

  static const _en = <String, String>{
    'appName': 'CleanTrail',
    'tagline': 'Make every table ready to hand off.',
    'privacyPromise': 'On-device · No account · Source stays untouched',
    'importCsv': 'Import data',
    'trySample': 'Try built-in sample',
    'emptyTitle': 'A calm checkpoint before analysis',
    'emptyBody':
        'Open a CSV, TSV, or Excel file to find missing values, duplicates, mixed types, date formats, and stray spaces. You approve every change.',
    'howItWorks': 'Your repair trail',
    'step1': '1  Inspect locally',
    'step2': '2  Confirm each repair',
    'step3': '3  Export data + receipt',
    'language': '中文',
    'onboardingSkip': 'Skip',
    'onboardingNext': 'Next',
    'onboardingStart': 'Start checking',
    'onboardingImportTitle': 'Confirm before inspection',
    'onboardingImportBody':
        'Open CSV, TSV, or Excel. Confirm the detected format, text encoding, or worksheet before inspection begins.',
    'onboardingRepairTitle': 'Approve every repair',
    'onboardingRepairBody':
        'Review missing values, duplicates, mixed types, date formats, and stray spaces. Keep, fix, or undo each decision.',
    'onboardingPrivacyTitle': 'Your data stays with you',
    'onboardingPrivacyBody':
        'Everything runs on this device with no account or cloud upload. Export the cleaned CSV together with a compact audit report.',
    'moreOptions': 'More options',
    'reviewTab': 'Review',
    'previewTab': 'Preview',
    'exportTab': 'Export',
    'project': 'Local project',
    'rows': 'rows',
    'columns': 'columns',
    'openIssues': 'open issues',
    'qualityScore': 'Quality score',
    'reviewQueue': 'Repair queue',
    'preview': 'Data preview',
    'export': 'Export bundle',
    'undo': 'Undo',
    'newFile': 'New file',
    'newFileConfirmTitle': 'Replace this local project?',
    'newFileConfirmBody':
        'Importing another file replaces the saved working copy and clears its undo history. Export anything you need first.',
    'continueImport': 'Choose file',
    'confirmImport': 'Confirm import',
    'detectedAs': 'Detected as {value}',
    'dataFormat': 'Data format',
    'textEncoding': 'Text encoding',
    'worksheet': 'Worksheet',
    'csvFormat': 'CSV · comma separated',
    'tsvFormat': 'TSV · tab separated',
    'excelFormat': 'Excel · XLSX',
    'utf8Encoding': 'UTF-8',
    'gbkEncoding': 'GBK · Simplified Chinese',
    'importOptionsHelp':
        'Adjust the detected format or encoding only when automatic recognition is incorrect.',
    'startInspection': 'Start inspection',
    'privacy': 'Privacy & data',
    'privacyBody':
        'CleanTrail has no account, analytics, advertising, or cloud service. Imported table content is processed on this device. One project file containing the source snapshot, working copy, and audit actions is stored in the app’s private documents until you remove the project or uninstall the app. The original file is never overwritten. Export bundles are staged in a dedicated temporary directory and offered through the system share sheet. The app deletes them when the sheet returns and retries stale cleanup at the next launch or export. They leave the app only if you choose a destination.',
    'deleteConfirmTitle': 'Remove this local project?',
    'deleteConfirmBody':
        'This removes the saved working copy from CleanTrail. Your original file is never changed.',
    'cancel': 'Cancel',
    'remove': 'Remove',
    'fixed': 'fixed',
    'kept': 'kept',
    'allClear': 'Review complete',
    'allClearBody':
        'Every detected issue has a decision. Export the cleaned CSV and a compact Markdown receipt.',
    'row': 'Row',
    'column': 'Column',
    'original': 'Current value',
    'suggested': 'Suggested value',
    'applySuggestion': 'Apply suggestion',
    'removeDuplicate': 'Remove duplicate row',
    'enterValue': 'Enter replacement',
    'replacementHint': 'Replacement value',
    'apply': 'Apply',
    'keepOriginal': 'Keep as-is',
    'close': 'Close',
    'sourceProtected': 'The original file is never overwritten.',
    'exportNote':
        'Shares a cleaned CSV and a report without source row contents.',
    'exportDraftNote':
        'Open issues remain. The CSV will be clearly named as a draft and the report will show the unresolved count.',
    'missingValue': 'Missing value',
    'duplicateRow': 'Duplicate row',
    'surroundingWhitespace': 'Stray spaces',
    'inconsistentType': 'Mixed column type',
    'inconsistentDate': 'Mixed date format',
    'missingValueBody':
        'This cell is empty. Enter a value or explicitly keep it blank.',
    'duplicateRowBody':
        'This row repeats an earlier row after case and space normalization.',
    'surroundingWhitespaceBody':
        'Leading or trailing spaces can break matching and grouping.',
    'inconsistentTypeBody':
        'Most values in this column are numeric, but this one is not.',
    'inconsistentDateBody':
        'Dates in this column use more than one format. ISO format is suggested.',
    'chartTitle': 'Numeric check',
    'chartEmpty': 'No numeric series with at least two values was found.',
    'beforeAfter': 'First numeric column · validation preview only',
    'previewRows': 'Showing the first {shown} of {total} rows',
    'fileTooLarge': 'Choose a data file smaller than 5 MB.',
    'invalidEncoding': 'Choose UTF-8 or GBK for this text file.',
    'unreadableFile': 'The selected file could not be read.',
    'unsupportedFormat': 'Choose a CSV, TSV, TXT, or XLSX file.',
    'invalidSpreadsheet': 'The Excel workbook could not be read.',
    'missingSheet': 'Choose a worksheet to import.',
    'emptyFile': 'The selected file is empty.',
    'invalidCsv': 'The table structure is invalid or has unmatched quotes.',
    'noDataRows': 'The table needs a header and at least one data row.',
    'tooManyRows': 'CleanTrail supports up to 10,000 data rows per file.',
    'invalidColumnCount': 'CleanTrail supports 1–100 columns per file.',
    'tooManyCells': 'CleanTrail supports up to 100,000 cells per file.',
    'tooManyIssues':
        'More than 500 issues were found. Split the file before reviewing it on a mobile device.',
    'replacementRequired': 'Enter a replacement value first.',
    'importFailed': 'Import failed. Your existing project was kept.',
    'restoreFailed':
        'The saved project could not be restored. Its files were left untouched.',
    'saveFailed': 'The change could not be saved. Your prior project was kept.',
    'clearFailed':
        'The local project could not be removed. Nothing was hidden or reported as deleted.',
    'exportFailed': 'Export could not be opened. Try again.',
    'offlineFooter': 'No analytics, cloud sync, login, or network upload.',
  };

  static const _zh = <String, String>{
    'appName': 'CleanTrail',
    'tagline': '让每一份表格都经得起交付。',
    'privacyPromise': '本机处理 · 无需账号 · 原文件不改写',
    'importCsv': '导入数据',
    'trySample': '体验内置样例',
    'emptyTitle': '在分析之前，先做一次冷静检查',
    'emptyBody': '打开 CSV、TSV 或 Excel，检查缺失、重复、类型混杂、日期格式与多余空格。每一处修改都由你确认。',
    'howItWorks': '你的修复轨迹',
    'step1': '1  本机检查',
    'step2': '2  逐项确认修复',
    'step3': '3  导出数据与凭证',
    'language': 'EN',
    'onboardingSkip': '跳过',
    'onboardingNext': '下一步',
    'onboardingStart': '开始检查',
    'onboardingImportTitle': '开始检查前，先确认识别结果',
    'onboardingImportBody': '打开 CSV、TSV 或 Excel；检查识别到的数据格式、文本编码或工作表，再进入检查流程。',
    'onboardingRepairTitle': '每一次修复都由你确认',
    'onboardingRepairBody': '逐项检查缺失值、重复行、类型混杂、日期格式和多余空格；可以修复、保留，也可以撤销。',
    'onboardingPrivacyTitle': '数据只留在你的设备上',
    'onboardingPrivacyBody': '无需账号，不上传云端，全部在本机完成。最后一起导出清洗后的 CSV 和精简审计报告。',
    'moreOptions': '更多选项',
    'reviewTab': '修复',
    'previewTab': '预览',
    'exportTab': '导出',
    'project': '本地项目',
    'rows': '行',
    'columns': '列',
    'openIssues': '项待处理',
    'qualityScore': '质量分',
    'reviewQueue': '修复队列',
    'preview': '数据预览',
    'export': '导出文件包',
    'undo': '撤销',
    'newFile': '新文件',
    'newFileConfirmTitle': '替换当前本地项目？',
    'newFileConfirmBody': '导入另一份文件会替换已保存的工作副本，并清除其撤销记录。请先导出需要保留的内容。',
    'continueImport': '选择文件',
    'confirmImport': '确认导入',
    'detectedAs': '识别结果：{value}',
    'dataFormat': '数据格式',
    'textEncoding': '文本编码',
    'worksheet': '工作表',
    'csvFormat': 'CSV · 逗号分隔',
    'tsvFormat': 'TSV · 制表符分隔',
    'excelFormat': 'Excel · XLSX',
    'utf8Encoding': 'UTF-8',
    'gbkEncoding': 'GBK · 简体中文',
    'importOptionsHelp': '仅在自动识别不正确时调整格式或编码；确认后仍进入原有检查流程。',
    'startInspection': '开始检查',
    'privacy': '隐私与数据',
    'privacyBody':
        'CleanTrail 不含账号、分析、广告或云服务。导入的表格内容仅在本机处理；包含源数据快照、工作副本和审计操作的一个项目文件会保存在 App 私有目录中，直到你移除项目或卸载 App。原始文件不会被覆盖。导出文件包会暂存在 App 专用临时目录中，经系统分享面板提供；App 会在分享面板返回后删除，并在下次启动或导出时再次清理遗留文件。只有你主动选择目标时，它们才会离开本 App。',
    'deleteConfirmTitle': '移除这个本地项目？',
    'deleteConfirmBody': '这会删除 CleanTrail 保存的工作副本。你的原始文件从未被修改。',
    'cancel': '取消',
    'remove': '移除',
    'fixed': '已修复',
    'kept': '保留原样',
    'allClear': '复核完成',
    'allClearBody': '每个检测问题都已有决定。现在可导出清洗后的 CSV 和精简 Markdown 凭证。',
    'row': '行',
    'column': '列',
    'original': '当前值',
    'suggested': '建议值',
    'applySuggestion': '采用建议',
    'removeDuplicate': '删除重复行',
    'enterValue': '输入替换值',
    'replacementHint': '替换值',
    'apply': '确认修改',
    'keepOriginal': '保留原样',
    'close': '关闭',
    'sourceProtected': '原文件始终不会被覆盖。',
    'exportNote': '将分享清洗后的 CSV，以及不含原始行内容的质量报告。',
    'exportDraftNote': '仍有待处理问题。CSV 将明确标记为草稿，报告也会显示未处理数量。',
    'missingValue': '缺失值',
    'duplicateRow': '重复行',
    'surroundingWhitespace': '多余空格',
    'inconsistentType': '列类型混杂',
    'inconsistentDate': '日期格式不一致',
    'missingValueBody': '这个单元格为空。请输入值，或明确选择保留为空。',
    'duplicateRowBody': '忽略大小写和首尾空格后，这一行与更早的记录重复。',
    'surroundingWhitespaceBody': '首尾空格可能导致匹配或分组失败。',
    'inconsistentTypeBody': '这一列大多数值都是数字，但当前值不是。',
    'inconsistentDateBody': '这一列混用了多种日期格式，建议统一为 ISO 格式。',
    'chartTitle': '数值校验',
    'chartEmpty': '没有找到至少包含两个数值的序列。',
    'beforeAfter': '首个数值列 · 仅用于修复验证',
    'previewRows': '正在预览前 {shown} / {total} 行',
    'fileTooLarge': '请选择小于 5 MB 的数据文件。',
    'invalidEncoding': '请为文本文件选择 UTF-8 或 GBK 编码。',
    'unreadableFile': '无法读取所选文件。',
    'unsupportedFormat': '请选择 CSV、TSV、TXT 或 XLSX 文件。',
    'invalidSpreadsheet': '无法读取这个 Excel 工作簿。',
    'missingSheet': '请选择要导入的工作表。',
    'emptyFile': '所选文件为空。',
    'invalidCsv': '表格结构无效或引号未闭合。',
    'noDataRows': '表格至少需要表头和一行数据。',
    'tooManyRows': 'CleanTrail 每个文件最多支持 10,000 行数据。',
    'invalidColumnCount': 'CleanTrail 每个文件支持 1–100 列。',
    'tooManyCells': 'CleanTrail 每个文件最多支持 100,000 个单元格。',
    'tooManyIssues': '检测到超过 500 个问题。请拆分文件后再在移动设备上检查。',
    'replacementRequired': '请先输入替换值。',
    'importFailed': '导入失败，已有项目保持不变。',
    'restoreFailed': '无法恢复已保存项目；现有文件保持原样。',
    'saveFailed': '无法保存本次操作，先前的项目状态保持不变。',
    'clearFailed': '无法移除本地项目；App 不会隐藏失败，也不会误报已删除。',
    'exportFailed': '无法打开导出面板，请重试。',
    'offlineFooter': '不含分析、云同步、登录或网络上传。',
  };

  String get(String key) => (isChinese ? _zh : _en)[key] ?? key;

  String get appName => get('appName');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get s =>
      Localizations.of<AppLocalizations>(this, AppLocalizations)!;
}
