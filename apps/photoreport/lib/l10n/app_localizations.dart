import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lightweight, project-owned localization used by the app and native bridge.
///
/// Chinese copy remains the stable lookup key so existing product wording stays
/// readable at call sites while English copy is kept in one auditable table.
class AppLocalizations {
  const AppLocalizations._();

  static const supportedLocales = <Locale>[Locale('zh', 'CN'), Locale('en')];

  static Locale activeLocale = const Locale('zh', 'CN');

  static Locale resolve(Locale? locale) {
    return locale?.languageCode.toLowerCase() == 'zh'
        ? const Locale('zh', 'CN')
        : const Locale('en');
  }

  static bool isEnglish([Locale? locale]) {
    return (locale ?? activeLocale).languageCode.toLowerCase() == 'en';
  }

  static String text(String source, {Locale? locale}) {
    if (!isEnglish(locale) || source.isEmpty) return source;
    final exact = _english[source];
    if (exact != null) return exact;
    return _translateDynamic(source);
  }

  static bool hasEnglish(String source) => _english.containsKey(source);

  static String _translateDynamic(String source) {
    final patterns = <(RegExp, String Function(Match))>[
      (RegExp(r'^删除“(.+)”？$'), (match) => 'Delete “${match.group(1)}”?'),
      (RegExp(r'^删除记录 (.+)？$'), (match) => 'Delete record ${match.group(1)}?'),
      (
        RegExp(r'^正式记录 · 第 (\d+)/3 步$'),
        (match) => 'Formal record · Step ${match.group(1)} of 3',
      ),
      (RegExp(r'^(\d+) 项高优先级$'), (match) => 'High: ${match.group(1)}'),
      (
        RegExp(r'^(快速图文记录|正式记录|编辑记录) (.+)$'),
        (match) => '${text(match.group(1)!)} ${match.group(2)}',
      ),
      (
        RegExp(r'^保存到“(.+)”；添加照片和说明即可。$'),
        (match) => 'Saving to “${match.group(1)}”. Just add photos and a note.',
      ),
      (RegExp(r'^(处理前|处理后)照片$'), (match) => '${text(match.group(1)!)} photos'),
      (RegExp(r'^(\d+) 个标注$'), (match) => '${match.group(1)} annotations'),
      (RegExp(r'^(\d+) 项待确认$'), (match) => '${match.group(1)} items to review'),
      (
        RegExp(r'^另有 (\d+) 项，可返回项目继续补充。$'),
        (match) =>
            '${match.group(1)} more items can be completed from the project.',
      ),
      (
        RegExp(r'^已添加 (\d+) 条，可继续添加或进入整理复核。$'),
        (match) =>
            '${match.group(1)} records added. Add more or continue to review.',
      ),
      (RegExp(r'^记录人：(.+)$'), (match) => 'Recorder: ${match.group(1)}'),
      (RegExp(r'^客户：(.+)$'), (match) => 'Client: ${match.group(1)}'),
      (RegExp(r'^(\d+) 张处理后$'), (match) => '${match.group(1)} after photos'),
      (RegExp(r'^(.+) 生成$'), (match) => 'Generated ${match.group(1)}'),
      (
        RegExp(r'^读取照片记录失败：(.+)$'),
        (match) =>
            'Could not load photo records: ${errorText(match.group(1)!)}',
      ),
      (
        RegExp(r'^操作失败：(.+)$'),
        (match) => 'Operation failed: ${errorText(match.group(1)!)}',
      ),
      (
        RegExp(r'^照片文件缺失，无法完成备份：(.+)$'),
        (match) =>
            'Photo file missing; backup cannot be completed: ${match.group(1)}',
      ),
      (
        RegExp(r'^备份中的(.+)数据不完整$'),
        (match) => '${text(match.group(1)!)} data in the backup is incomplete',
      ),
      (
        RegExp(r'^备份中的(.+)格式错误$'),
        (match) =>
            '${text(match.group(1)!)} data in the backup has an invalid format',
      ),
      (
        RegExp(r'^(.+) 尚未填写区域$'),
        (match) => '${match.group(1)} is missing an area',
      ),
      (
        RegExp(r'^(.+) 尚未填写标题$'),
        (match) => '${match.group(1)} is missing a title',
      ),
      (
        RegExp(r'^(.+) 尚未填写说明$'),
        (match) => '${match.group(1)} is missing a description',
      ),
      (
        RegExp(r'^(.+) 尚未添加现场照片$'),
        (match) => '${match.group(1)} has no site photos',
      ),
      (
        RegExp(r'^(.+) 待跟进但未填写负责人$'),
        (match) => '${match.group(1)} needs follow-up but has no assignee',
      ),
      (
        RegExp(r'^(.+) 待跟进但未填写期限$'),
        (match) => '${match.group(1)} needs follow-up but has no due date',
      ),
      (
        RegExp(r'^项目资料可补充：(.+)$'),
        (match) =>
            'Optional project details: ${_translateList(match.group(1)!)}',
      ),
    ];
    for (final (pattern, replacement) in patterns) {
      final match = pattern.firstMatch(source);
      if (match != null) return replacement(match);
    }
    return source;
  }

  static String _translateList(String value) {
    return value.split('、').map((part) => text(part)).join(', ');
  }

  static String errorText(String source, {Locale? locale}) {
    if (!isEnglish(locale)) return source;
    for (final prefix in const ['Exception: ', 'FormatException: ']) {
      if (source.startsWith(prefix)) {
        final detail = source.substring(prefix.length);
        return '$prefix${text(detail, locale: const Locale('en'))}';
      }
    }
    var result = source;
    for (final entry in _english.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }
    return result;
  }

  static const Map<String, String> _english = {
    '编号 · 标注 · 整理分享': 'Number · Mark up · Organize · Share',
    '本地数据': 'Local data',
    '设置与数据': 'Settings & data',
    '更多操作': 'More actions',
    '导出本地备份': 'Export local backup',
    '保存项目、记录和照片': 'Save projects, records, and photos',
    '从备份恢复': 'Restore from backup',
    '将替换当前本机数据': 'Replaces the current data on this device',
    '显示语言': 'Display language',
    '所有数据默认保存在本机': 'All data stays on this device by default',
    '语言': 'Language',
    '隐私与支持': 'Privacy & support',
    '隐私政策': 'Privacy Policy',
    '在浏览器中查看官方隐私政策': 'View the official policy in your browser',
    '隐私概览': 'Privacy overview',
    'JOVFX 是一款本地优先的照片记录工具。本政策说明本版本如何处理你在使用过程中提供的内容。':
        'JOVFX is a local-first photo documentation tool. This policy explains how this version handles the content you provide while using it.',
    '最后更新：2026 年 11 月 17 日': 'Last updated: November 17, 2026',
    '我们处理的信息': 'Information we process',
    '你主动输入的项目名称、地址、记录人、联系人、说明、负责人和期限。':
        'Project names, addresses, recorders, contacts, descriptions, assignees, and due dates that you enter.',
    '你通过相机拍摄或从系统相册选择的照片，以及添加的方框、箭头和文字标注。':
        'Photos you take with the camera or select from the system photo library, including boxes, arrows, and text annotations you add.',
    '本地存储与传输': 'On-device storage and transmission',
    '上述内容默认保存在本设备的应用沙盒中。本版本不提供账号、云同步、广告或分析服务，开发者服务器不会接收这些内容。':
        'This content is stored in the app sandbox on this device by default. This version does not provide accounts, cloud sync, advertising, or analytics, and developer servers do not receive this content.',
    '系统权限': 'System permissions',
    '只有在你选择拍照或导入照片时，App 才会调用系统相机或照片选择器。如果系统提示授权，你可以拒绝。':
        'The app uses the system camera or photo picker only when you choose to take or import a photo. You can decline any permission prompt shown by the system.',
    '分享与备份': 'Sharing and backups',
    'PDF 和本地备份均在设备上生成。只有当你主动使用系统分享面板时，文件才会发送给你选择的接收方或服务。':
        'PDF files and local backups are generated on the device. A file is sent to a recipient or service only when you choose it through the system share sheet.',
    '文件导出应用后，由你选择的存储位置或第三方服务按照其隐私政策处理。':
        'After a file leaves the app, the storage location or third-party service you choose handles it under its own privacy policy.',
    '保留与删除': 'Retention and deletion',
    '本地内容会保留到你删除项目、恢复其他备份或卸载应用。删除项目会同步删除其记录和应用管理的照片副本。':
        'Local content remains until you delete a project, restore another backup, or uninstall the app. Deleting a project also removes its records and app-managed photo copies.',
    '已导出的 PDF、备份或已分享的副本不在本应用控制范围内，需要由你在对应位置另行删除。':
        'Exported PDF files, backups, and shared copies are outside the app control and must be deleted separately from their respective locations.',
    '第三方服务': 'Third-party services',
    '本版本使用 Flutter 和设备提供的相机、照片选择、文件预览及分享功能，不包含广告或用户行为分析 SDK。':
        'This version uses Flutter and device features for the camera, photo selection, file preview, and sharing. It does not include advertising or user-behavior analytics SDKs.',
    '打开线上隐私政策时，系统浏览器会访问 JOVFX 官网。浏览器与网站托管服务可能处理连接信息。':
        'Opening the online privacy policy visits the JOVFX website in your system browser. The browser and website host may process connection information.',
    '政策更新与联系': 'Policy updates and contact',
    '如果功能或数据处理方式发生变化，我们会更新本政策。':
        'We will update this policy if features or data practices change.',
    '运营主体为独立开发者。若有隐私问题，请联系 PadonSolmonson469@outlook.com。':
        'JOVFX is operated by an independent developer. For privacy questions, contact PadonSolmonson469@outlook.com.',
    '跟随系统': 'System default',
    '简体中文': '简体中文',
    '跳过': 'Skip',
    '下一步': 'Next',
    '开始记录': 'Start recording',
    '现场记录，从拍下开始': 'Site records start with a photo',
    '照片、位置与说明放在一起，现场信息不再散落。':
        'Keep photos, locations, and notes together instead of scattered.',
    '重点一眼可见': 'Make the important details obvious',
    '用方框、箭头和文字标出重点，并保留处理前后对照。':
        'Use boxes, arrows, and notes to highlight details and compare before and after.',
    '离线整理，放心分享': 'Organize offline and share with confidence',
    '资料默认保存在本机，整理完成后可生成清晰的 PDF 记录。':
        'Your data stays on this device by default, ready for a clear PDF when organized.',
    '新建': 'New',
    '删除项目': 'Delete project',
    '编辑项目': 'Edit project',
    '项目操作': 'Project actions',
    '记录操作': 'Record actions',
    '删除记录': 'Delete record',
    '编辑记录': 'Edit record',
    '取消': 'Cancel',
    '确认删除': 'Delete',
    '确认恢复': 'Restore',
    '暂时无法读取本地项目': 'Could not load local projects',
    '重新载入': 'Reload',
    '记录项目': 'Record projects',
    '每个地点独立整理，可继续补充照片并再次分享。':
        'Keep each location organized, add photos later, and share again.',
    '地点待补充': 'Location not added',
    '全部记录': 'All records',
    '条记录': 'records',
    '待处理': 'Pending',
    '处理中': 'In progress',
    '已完成': 'Completed',
    '从一个记录项目开始': 'Start with a record project',
    '从第一个记录项目开始': 'Start with your first record project',
    '把同一现场的照片归在一起，': 'Keep photos from the same site together.',
    '边拍边编号，整理后直接分享。': 'Number them as you shoot, then organize and share.',
    '新建项目': 'Create project',
    '添加照片': 'Add photos',
    '现场边拍边编号，补充位置与说明，整理后直接生成便于沟通的照片记录。':
        'Number photos on site, add locations and notes, then create a shareable record.',
    '开始新建': 'Create a project',
    '仅用于现场沟通与情况记录 · 数据保存在本机':
        'For site communication and documentation · Data stays on this device',
    '内容仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见。数据默认保存在本机，可从右上角导出备份。':
        'For site communication and documentation only. This is not a professional assessment, acceptance decision, or legal opinion. Data stays on this device by default; export a backup from the top-right menu.',
    '项目内的记录、照片和标注都会从本机删除，此操作无法撤销。':
        'All records, photos, and annotations in this project will be deleted from this device. This cannot be undone.',
    '本地备份已生成，可保存到“文件”或发送到其他设备':
        'Local backup created. Save it to Files or send it to another device.',
    '恢复这份本地备份？': 'Restore this local backup?',
    '当前项目、记录和照片会被备份内容替换。建议先导出一份当前备份。':
        'Current projects, records, and photos will be replaced. Export a current backup first.',
    '备份已恢复': 'Backup restored',
    '这次要怎样记录？': 'How would you like to record this?',
    '两种方式使用同一套项目和编号，快速记录以后也能随时补充完整。':
        'Both modes share the same projects and numbering. Quick records can be completed later.',
    '快速图文记录': 'Quick photo note',
    '照片加一句说明即可，适合现场连续记录。':
        'Add photos and one short note—ideal for continuous site work.',
    '约 1 分钟': 'About 1 min',
    '首次使用时，再补一个简短的项目名称。': 'For your first record, add a short project name.',
    '将保存到': 'Save to',
    '正式记录': 'Formal record',
    '第 2/3 步 · 继续添加记录': 'Step 2 of 3 · Continue adding records',
    '第 3/3 步 · 继续整理复核': 'Step 3 of 3 · Continue review',
    '按项目资料、现场记录、整理复核三步完成。':
        'Complete project details, site records, and final review in three steps.',
    '3 个步骤': '3 steps',
    '开始快速记录': 'Start quick record',
    '开始正式记录': 'Start formal record',
    '先给这组记录起个名字': 'Name this set of records',
    '其他项目资料可以稍后补充。': 'Other project details can be added later.',
    '项目名称 *': 'Project name *',
    '例如：8 月 27 日现场记录': 'Example: Aug 27 site record',
    '请输入项目名称': 'Enter a project name',
    '继续添加照片': 'Continue to photos',
    '步骤 1/3 · 项目资料': 'Step 1 of 3 · Project details',
    '新建记录项目': 'New record project',
    '编辑项目信息': 'Edit project details',
    '先确认项目基本资料，保存后继续添加现场记录。':
        'Confirm the project basics, then continue to site records.',
    '先填写名称和地点，其余资料可按实际沟通需要补充。':
        'Start with a name and location. Add other details as needed.',
    '例如：云栖花园 8-1202 现场记录': 'Example: Building 8, Unit 1202 site record',
    '项目地址 *': 'Project address *',
    '楼盘、楼栋及房号': 'Property, building, and unit',
    '请输入项目地址': 'Enter a project address',
    '记录日期': 'Record date',
    '选择记录日期': 'Select record date',
    '选择日期': 'Select date',
    '企业/团队名称': 'Company / team',
    '编号前缀': 'Code prefix',
    '必填': 'Required',
    '记录人': 'Recorder',
    '业主/客户': 'Owner / client',
    '补充说明': 'Additional notes',
    '沟通范围、背景或其他备注': 'Scope, context, or other notes',
    '保存并继续': 'Save and continue',
    '创建项目': 'Create project',
    '保存修改': 'Save changes',
    '复用标题': 'Reuse name',
    '现场拍照': 'Take a site photo',
    '添加现场照片': 'Add a site photo',
    '选择拍摄新照片或从系统相册导入': 'Take a new photo or import one from the photo library',
    '打开相机拍摄一张照片': 'Open the camera to take a photo',
    '从相册选择': 'Choose from library',
    '导入已有的现场照片': 'Import an existing site photo',
    '请至少添加一张现场照片': 'Add at least one site photo',
    '放弃这条记录？': 'Discard this record?',
    '已添加的照片和填写内容不会保存。': 'Added photos and entered details will not be saved.',
    '放弃记录': 'Discard',
    '保存': 'Save',
    '步骤 2/3：交代位置与内容，责任和进度按需补充。':
        'Step 2 of 3: add the location and details; ownership and progress are optional.',
    '位置与内容': 'Location and details',
    '用简短标题和说明把照片交代清楚。':
        'Use a short title and description to explain the photos.',
    '房间/区域 *': 'Room / area *',
    '主卫': 'Primary bathroom',
    '具体位置（可选）': 'Exact location (optional)',
    '东侧墙面': 'East wall',
    '常用区域': 'Recent areas',
    '记录标题 *': 'Record title *',
    '例如：墙面裂缝、设备位置、到货情况':
        'Example: wall crack, equipment location, delivery status',
    '常用标题': 'Recent titles',
    '照片说明 *': 'Photo description *',
    '说明现场情况、关注点或后续安排': 'Describe the site condition, concern, or next action',
    '常用说明': 'Recent descriptions',
    '补充责任与进度': 'Add ownership and progress',
    '可选：优先级、状态、负责人和期限': 'Optional: priority, status, assignee, and due date',
    '优先级': 'Priority',
    '处理状态': 'Status',
    '负责人': 'Assignee',
    '处理期限': 'Due date',
    '选择处理期限': 'Select due date',
    '清除期限': 'Clear due date',
    '未设置': 'Not set',
    '正在保存…': 'Saving…',
    '保存图文记录': 'Save photo note',
    '保存完整记录': 'Save full record',
    '现场照片': 'Site photos',
    '先拍下现场情况，可继续添加照片或标注重点。':
        'Capture the site first, then add more photos or annotations.',
    '事情说明': 'What happened',
    '用一句或几句话把照片中的事情交代清楚。':
        'Use one or two sentences to explain what the photos show.',
    '例如：主卫天花板持续漏水，需要尽快检查上层管道。':
        'Example: The bathroom ceiling is leaking; inspect the pipework above.',
    '补充位置与标题（可选）': 'Add location and title (optional)',
    '不填写时会自动生成标题，并显示为“未分类”':
        'If left blank, a title is generated and the area shows as “Uncategorized”.',
    '房间/区域': 'Room / area',
    '具体位置': 'Exact location',
    '记录标题': 'Record title',
    '留空时取说明第一行': 'Uses the first line of the description if blank',
    '补充为完整记录': 'Complete this record',
    '此项必填': 'This field is required',
    '保留现场原貌，可添加红框、箭头和文字。':
        'Keep the original site view and add boxes, arrows, or text.',
    '关联后续情况，形成同一编号下的前后对比。':
        'Link follow-up photos for a before-and-after comparison under one code.',
    '添加': 'Add',
    '拍照或从相册导入': 'Take a photo or import from library',
    '继续添加': 'Add more',
    '点击标注': 'Tap to annotate',
    '移除照片': 'Remove photo',
    '图文记录已保存': 'Photo note saved',
    '接下来要做什么？': 'What would you like to do next?',
    '继续记录下一条': 'Record another',
    '查看项目记录': 'View project records',
    '完成': 'Done',
    '标注照片重点': 'Annotate key details',
    '拖动绘制方框或箭头；文字模式下点击照片定位。':
        'Drag to draw a box or arrow. In text mode, tap the photo to place text.',
    '颜色': 'Color',
    '红色': 'Red',
    '绿色': 'Green',
    '蓝色': 'Blue',
    '黑色': 'Black',
    '白色': 'White',
    '方框': 'Box',
    '箭头': 'Arrow',
    '文字': 'Text',
    '撤销': 'Undo',
    '添加文字标注': 'Add text annotation',
    '文字会添加在刚才点击的位置。': 'The text will be placed where you just tapped.',
    '例如：开裂处': 'Example: crack',
    '对应的前后照片和全部标注也会从本机删除。':
        'Its before/after photos and all annotations will also be deleted from this device.',
    '整理分享': 'Organize and share',
    '步骤 3/3 · 整理复核': 'Step 3 of 3 · Review',
    '全部': 'All',
    '添加记录后可整理分享': 'Add a record to organize and share',
    '步骤 3：整理复核': 'Step 3: Review',
    '整理并生成 PDF': 'Organize and create PDF',
    '最近生成的沟通记录': 'Most recent shared record',
    '可直接再次预览或分享': 'Preview or share it again',
    '预览最近 PDF': 'Preview latest PDF',
    '再次分享': 'Share again',
    '照片记录': 'Photo records',
    '按编号整理，每项都能回到具体位置与前后照片。':
        'Organized by code, with each item linked to its location and before/after photos.',
    '按编号整理，随时回到具体位置。':
        'Organized by code, so you can return to the exact location anytime.',
    '搜索编号、区域、标题或负责人': 'Search code, area, title, or assignee',
    '筛选记录': 'Filter records',
    '收起筛选': 'Hide filters',
    '全部状态': 'All statuses',
    '全部区域': 'All areas',
    '当前筛选下没有记录': 'No records match these filters',
    '添加记录': 'Add record',
    '快速记录': 'Quick record',
    '整理复核': 'Review and organize',
    '添加现场记录': 'Add site records',
    '检查缺失项后生成完整记录。': 'Review missing items, then create the complete record.',
    '先添加第一条记录，可随时暂存退出。':
        'Add the first record. You can save and leave at any time.',
    '还没有现场记录': 'No site records yet',
    '拍照、写下位置与说明，需要时再补充负责人和期限。':
        'Take photos and add a location and note. Add an assignee and due date when needed.',
    '添加第一条记录': 'Add the first record',
    '添加记录后即可整理分享': 'Add a record to organize and share',
    '生成报告，与同事或业主沟通更高效。':
        'Create a report for clearer communication with colleagues or owners.',
    '生成 PDF': 'Create PDF',
    '图文记录': 'Photo note',
    '未分类': 'Uncategorized',
    '低': 'Low',
    '中': 'Medium',
    '高': 'High',
    '处理前': 'Before',
    '处理后': 'After',
    '低优先级': 'Low priority',
    '中优先级': 'Medium priority',
    '高优先级': 'High priority',
    '地点尚未补充': 'Location not added',
    '记录总数': 'Total records',
    '涉及区域': 'Areas',
    '分享内容': 'Share content',
    '选择正式输出': 'Choose formal output',
    '默认使用完整记录；缺失项不会阻止生成，可返回继续补充。':
        'The full record is selected by default. Missing items do not block output and can be added later.',
    '默认只保留照片和说明，也可按需增加沟通字段。':
        'By default, only photos and descriptions are included. Add other fields as needed.',
    '正在整理现场照片与说明…': 'Organizing site photos and descriptions…',
    '全部在本机完成，无需上传照片。':
        'Everything stays on this device; photos are not uploaded.',
    'PDF 生成失败': 'Could not create PDF',
    '重新生成': 'Generate again',
    '确认内容后生成 PDF': 'Review the content, then create the PDF',
    '选项已更新，请重新生成 PDF': 'Options changed. Create the PDF again.',
    'PDF 已生成': 'PDF created',
    '预览 PDF': 'Preview PDF',
    '分享': 'Share',
    '按当前选项重新生成': 'Create again with current options',
    '内容仅用于现场沟通与情况记录，不构成专业鉴定、验收结论或法律意见。':
        'For site communication and documentation only. This is not a professional assessment, acceptance decision, or legal opinion.',
    '资料完整，可以整理': 'Ready to organize',
    '项目资料和现场记录已具备完整输出条件。':
        'Project details and site records are ready for complete output.',
    '这些是补充提醒，不会阻止继续生成：': 'These reminders do not block output:',
    '版式': 'Layout',
    '简洁记录': 'Concise record',
    '完整记录': 'Full record',
    '包含字段': 'Included fields',
    '位置': 'Location',
    '状态': 'Status',
    '期限': 'Due date',
    '项目资料': 'Project details',
    '按当前选项生成 PDF': 'Create PDF with current options',
    '项目地点尚未填写': 'Project location is missing',
    '企业/团队': 'Company / team',
    '项目还没有现场记录': 'The project has no site records',
    '项目': 'Project',
    '记录': 'Record',
    '照片': 'Photo',
    '操作失败：': 'Operation failed: ',
    '报告生成成功但未返回文件地址': 'The report was created but no file path was returned',
    '项目不存在，无法分配问题编号':
        'The project does not exist, so a record code cannot be assigned',
    '备份中的项目数据不完整': 'Project data in the backup is incomplete',
    '备份中的记录数据不完整': 'Record data in the backup is incomplete',
    '备份中的照片数据不完整': 'Photo data in the backup is incomplete',
    '备份中的项目格式错误': 'Project data in the backup has an invalid format',
    '备份中的记录格式错误': 'Record data in the backup has an invalid format',
    '备份中的照片格式错误': 'Photo data in the backup has an invalid format',
    '这不是受支持的 JOVFX 备份': 'This is not a supported JOVFX backup',
  };
}

String tr(String source, {Locale? locale}) {
  return AppLocalizations.text(source, locale: locale);
}

class LanguagePreference {
  const LanguagePreference._();

  static const _channel = MethodChannel('com.starburst.photo_report/report');

  static Future<Locale?> load() async {
    try {
      final code = await _channel.invokeMethod<String>(
        'getPreferredLanguage',
        const <String, Object?>{},
      );
      if (code == null || code.isEmpty) return null;
      return AppLocalizations.resolve(Locale(code));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> save(Locale locale) async {
    try {
      await _channel.invokeMethod<void>('setPreferredLanguage', {
        'languageCode': locale.languageCode,
      });
    } on PlatformException {
      // Language still changes for this session if persistence is unavailable.
    } on MissingPluginException {
      // Widget tests and non-iOS hosts do not install the native preference API.
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>(
        'clearPreferredLanguage',
        const <String, Object?>{},
      );
    } on PlatformException {
      // Following the system still applies for this session.
    } on MissingPluginException {
      // Widget tests and non-iOS hosts do not install the native preference API.
    }
  }
}

class OnboardingPreference {
  const OnboardingPreference._();

  static const _channel = MethodChannel('com.starburst.photo_report/report');

  static Future<bool> load() async {
    try {
      return await _channel.invokeMethod<bool>(
            'getOnboardingComplete',
            const <String, Object?>{},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> complete() async {
    try {
      await _channel.invokeMethod<void>('setOnboardingComplete', {
        'isComplete': true,
      });
    } on PlatformException {
      // The user can still enter the app if persistence is unavailable.
    } on MissingPluginException {
      // Widget tests and non-iOS hosts do not install the native preference API.
    }
  }
}

class LText extends StatelessWidget {
  const LText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.translate = true,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  final bool translate;

  @override
  Widget build(BuildContext context) {
    return Text(
      translate
          ? AppLocalizations.text(data, locale: Localizations.localeOf(context))
          : data,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
