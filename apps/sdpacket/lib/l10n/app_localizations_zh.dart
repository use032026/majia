// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'KIFXPRO';

  @override
  String get loading => '正在读取本地数据…';

  @override
  String get retry => '重试';

  @override
  String get projects => '搬家项目';

  @override
  String get activeProjects => '进行中';

  @override
  String get newProject => '新建项目';

  @override
  String get globalSearch => '全局搜索';

  @override
  String get archivedProjects => '已归档项目';

  @override
  String get settings => '设置';

  @override
  String get moreActions => '更多操作';

  @override
  String get language => '语言';

  @override
  String get chooseLanguage => '选择语言';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get languageChangeFailed => '语言切换失败，请重试。';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingGetStarted => '开始使用';

  @override
  String get onboardingQuickTitle => '十几秒登记一只箱子';

  @override
  String get onboardingQuickBody => '拍张照片或补一句备注，箱子记录会立即保存在本机。';

  @override
  String get onboardingFindTitle => '没网也能快速找到物品';

  @override
  String get onboardingFindBody => '离线搜索箱号、房间、备注和物品名称，搬家现场没有信号也不受影响。';

  @override
  String get onboardingTrackTitle => '每个搬运阶段都清清楚楚';

  @override
  String get onboardingTrackBody => '追踪已打包、已装车、已到达和已拆箱状态，同时避免数字记录与现实箱体标签错位。';

  @override
  String onboardingProgress(int current, int total) {
    return '第 $current 页，共 $total 页';
  }

  @override
  String get onboardingSavingFailed => '无法保存引导状态，请重试。';

  @override
  String get noProjects => '还没有搬家项目';

  @override
  String get noProjectsHint => '创建一个项目后，即可开始快速登记纸箱。';

  @override
  String get sampleProjectName => '示例搬家';

  @override
  String get sampleOrigin => '旧家';

  @override
  String get sampleDestination => '新家';

  @override
  String get sampleMemo => '咖啡机、杯子和滤纸';

  @override
  String get projectName => '项目名称';

  @override
  String get origin => '原位置（可选）';

  @override
  String get destination => '目标位置（可选）';

  @override
  String get boxPrefix => '箱号前缀';

  @override
  String get create => '创建';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get edit => '编辑';

  @override
  String get archive => '归档';

  @override
  String get restore => '恢复';

  @override
  String get delete => '删除';

  @override
  String get deleteProjectConfirm =>
      '删除项目后，项目内箱子记录也会一并删除。现实箱体上的旧标签可能仍然存在。是否继续？';

  @override
  String get deleteBoxConfirm => '删除记录后不会复用该箱号。现实箱体上的旧标签可能仍然存在。是否继续？';

  @override
  String boxCount(int count) {
    return '$count 个箱子';
  }

  @override
  String get quickEntry => '快速登记';

  @override
  String get takePhoto => '拍照登记';

  @override
  String get continuousCamera => '连续拍照';

  @override
  String get choosePhotos => '批量选照片';

  @override
  String get voiceEntry => '语音登记';

  @override
  String get manualEntry => '手动登记';

  @override
  String get photoLimit => '每批最多选择 30 张照片。';

  @override
  String batchCaptureCount(int count) {
    return '本批已拍 $count 箱';
  }

  @override
  String get batchCaptureHint => '每拍一张就立即创建并保存箱子草稿。可以继续拍摄，完成后再逐箱编辑。';

  @override
  String get noBatchPhotos => '拍下第一只箱子，开始本批登记。';

  @override
  String get editBatch => '编辑本批';

  @override
  String get takeNextPhoto => '拍下一箱';

  @override
  String batchProgress(int current, int total) {
    return '第 $current / $total 箱';
  }

  @override
  String get applyToRemaining => '批量套用';

  @override
  String get applyToRemainingHint => '“批量套用”会把当前房间和标签应用到本箱及本批后续箱子。';

  @override
  String get batchDetailsApplied => '房间和标签已应用到本批剩余箱子';

  @override
  String get skip => '跳过';

  @override
  String get saveAndNext => '保存并下一箱';

  @override
  String get finishBatch => '保存并完成本批';

  @override
  String get batchUnavailable => '这个登记批次已完成或不存在。';

  @override
  String get resumeBatch => '继续未完成批次';

  @override
  String batchCreated(int count, Object from, Object to) {
    return '已创建 $count 个箱子记录：$from 至 $to';
  }

  @override
  String get physicalMarkTitle => '请标记现实箱体';

  @override
  String physicalMarkMessage(Object code) {
    return '数字记录 $code 已创建。请在对应纸箱上手写箱号、粘贴便利贴或打印二维码标签。';
  }

  @override
  String physicalMarkBatchMessage(int count) {
    return '已创建 $count 个数字记录。请根据照片与箱号逐一标记现实箱体，避免错位。';
  }

  @override
  String get qrLabel => '二维码标签已粘贴';

  @override
  String get handwritten => '已手写编号';

  @override
  String get stickyNote => '已粘贴便利贴';

  @override
  String get other => '其他方式';

  @override
  String get later => '稍后处理';

  @override
  String get pendingPhysicalMark => '待实体标记';

  @override
  String get marked => '已确认标记';

  @override
  String get progress => '搬家进度';

  @override
  String get total => '总数';

  @override
  String get packed => '已打包';

  @override
  String get loaded => '已装车';

  @override
  String get arrived => '已到达';

  @override
  String get unpacked => '已拆箱';

  @override
  String get draft => '草稿';

  @override
  String get suspectedMissing => '疑似遗漏';

  @override
  String get damagedBox => '箱体损坏';

  @override
  String get damagedContents => '内容物损坏';

  @override
  String get priority => '优先拆箱';

  @override
  String get normal => '普通';

  @override
  String get searchBoxes => '搜索箱号、备注、物品、房间或标签';

  @override
  String get noResults => '没有匹配结果';

  @override
  String get boxCode => '箱号';

  @override
  String get boxInformation => '箱子信息';

  @override
  String get contentsAndNotes => '内容与备注';

  @override
  String get movingAndFlags => '搬运与标记';

  @override
  String get boxTitle => '标题（可选）';

  @override
  String get destinationRoom => '目的房间（可选）';

  @override
  String get currentLocation => '当前位置（可选）';

  @override
  String get memo => '备注（可选）';

  @override
  String get tags => '标签';

  @override
  String get tagsHint => '用逗号分隔，例如：易碎, 怕潮';

  @override
  String get items => '结构化物品';

  @override
  String get itemsHint => '用逗号分隔物品名称（可选）';

  @override
  String get addItem => '添加物品';

  @override
  String get editItem => '编辑物品';

  @override
  String get itemName => '物品名称';

  @override
  String get itemNameRequired => '请输入物品名称';

  @override
  String get itemQuantity => '数量（可选）';

  @override
  String get itemQuantityInvalid => '请输入大于 0 的整数';

  @override
  String itemQuantityValue(int quantity) {
    return '数量 $quantity';
  }

  @override
  String get itemNote => '物品备注（可选）';

  @override
  String get noStructuredItems => '尚未添加结构化物品。可继续只使用整段备注。';

  @override
  String get quickTemplates => '快捷模板';

  @override
  String get templateKitchen => '厨房';

  @override
  String get templateBedroom => '卧室';

  @override
  String get templateOldHome => '旧家';

  @override
  String get templateNewHome => '新家';

  @override
  String get templateStorage => '储物间';

  @override
  String get templateFragile => '易碎';

  @override
  String get templateKeepDry => '怕潮';

  @override
  String get templateUnpackFirst => '优先拆箱';

  @override
  String get duplicateCode => '该箱号已在当前项目中使用';

  @override
  String get boxSaved => '箱子记录已保存';

  @override
  String get addPhoto => '添加照片';

  @override
  String get qrAndPrint => '二维码与打印';

  @override
  String get labelDocumentTitle => 'KIFXPRO 标签';

  @override
  String get labelBrand => 'KIFXPRO';

  @override
  String get scanOrSearchCode => '扫码或搜索箱号';

  @override
  String get scan => '扫描箱子标签';

  @override
  String get movingScanMode => '搬家现场扫码';

  @override
  String get scanTargetStatus => '扫码后推进到';

  @override
  String repeatedScan(Object code, Object status) {
    return '$code 已扫描或当前已是“$status”及之后状态';
  }

  @override
  String scanUpdated(Object code, Object status) {
    return '$code 已更新为“$status”';
  }

  @override
  String scannedCount(int count) {
    return '本次已扫描 $count 箱';
  }

  @override
  String unscannedCount(int count) {
    return '仍需扫描 $count 箱';
  }

  @override
  String get viewUnscanned => '未扫描清单';

  @override
  String get allScanned => '当前目标阶段没有未扫描箱子。';

  @override
  String get unsupportedQr => '这不是本应用支持的箱子标签。可返回后手动搜索箱号。';

  @override
  String get boxNotFound => '标签格式正确，但本机没有对应箱子记录。';

  @override
  String get moveStatus => '搬运状态';

  @override
  String get statusHistory => '状态历史';

  @override
  String get undoLastStatus => '撤销上次';

  @override
  String get noStatusHistory => '还没有状态变化记录。';

  @override
  String get statusUndoSuccess => '已撤销最后一次状态变化';

  @override
  String get statusSourceManual => '手动修改';

  @override
  String get statusSourceScanner => '现场扫码';

  @override
  String get issues => '异常标记';

  @override
  String get physicalMark => '实体标记';

  @override
  String get exportSinglePdf => '分享单个 PDF';

  @override
  String get exportPng => '分享高清 PNG';

  @override
  String get printLabel => '系统打印';

  @override
  String get exportA4Pdf => '分享全部 A4 标签';

  @override
  String get labelExportedNotice => '标签已导出，但仍需确认标签已粘贴或箱号已写到现实箱体。';

  @override
  String noPrinterHint(Object code) {
    return '没有打印机也可以继续。请将 $code 写在纸箱明显位置，或写在便利贴上粘贴到箱体。';
  }

  @override
  String get exportCsv => '导出项目 CSV';

  @override
  String get projectReport => '项目收尾报告';

  @override
  String reportGeneratedAt(Object value) {
    return '生成时间：$value';
  }

  @override
  String get reportDamaged => '损坏箱';

  @override
  String get roomDistribution => '房间分布';

  @override
  String get reportNone => '无';

  @override
  String get unassignedRoom => '未指定房间';

  @override
  String get moreRooms => '其他房间';

  @override
  String get backup => '分享本地备份';

  @override
  String get restoreBackup => '从文件恢复备份';

  @override
  String get restoreWarning => '恢复会先完整校验备份；成功后替换当前本地数据。无效备份不会覆盖现有记录。';

  @override
  String get restoreSuccess => '备份恢复成功';

  @override
  String restoreSuccessMissingPhotos(int count) {
    return '备份恢复成功，$count 张照片在备份中缺失';
  }

  @override
  String get invalidBackup => '备份无效或版本不受支持，现有数据未被修改。';

  @override
  String get privacy => '隐私说明';

  @override
  String get localPrivacyFallback => '公开网页未配置，当前显示内置隐私说明';

  @override
  String get privacyBody =>
      '项目、箱子、备注和照片默认只保存在本机。核心功能不依赖账号、广告 SDK 或第三方 AI。二维码仅包含格式版本、项目 ID、箱子 ID 和可读箱号，不包含地址、照片或物品清单。照片、相机、麦克风和语音识别权限仅在您主动使用对应功能时请求。';

  @override
  String get about => '关于 KIFXPRO';

  @override
  String get contactSupport => '联系支持';

  @override
  String get supportEmailSubject => 'KIFXPRO App 用户支持';

  @override
  String get supportNotConfigured => '支持邮箱尚未配置。发布构建需通过 SUPPORT_EMAIL 注入公开联系邮箱。';

  @override
  String versionBuild(Object version, Object build) {
    return '版本 $version（$build）';
  }

  @override
  String get aboutBody => '用于快速登记纸箱、离线搜索物品并追踪搬运状态。全部功能免费，无订阅、试用倒计时或付费墙。';

  @override
  String get platformSupport => '系统要求';

  @override
  String get platformSupportBody => 'iOS 15 或更高版本；Android 14 或更高版本。';

  @override
  String get noArchived => '没有已归档项目';

  @override
  String get voiceTitle => '语音登记';

  @override
  String get voiceHint => '说出箱内物品、目的房间和注意事项。转写内容可在保存前修改。';

  @override
  String get startListening => '开始录音';

  @override
  String get stopListening => '停止录音';

  @override
  String get speechUnavailable => '语音识别暂不可用';

  @override
  String get speechUnavailableHint =>
      '设备、语言或权限可能不支持当前识别。可以立即切换为手动文字登记，不影响其他功能。';

  @override
  String get switchManual => '改用手动登记';

  @override
  String get transcript => '语音转写';

  @override
  String get createFromVoice => '创建箱子记录';

  @override
  String get voiceEmpty => '请先录入或手动输入备注';

  @override
  String get permissionDenied => '权限未授予，可改用不需要该权限的登记方式。';

  @override
  String get photoFailed => '照片处理失败，未创建对应记录。';

  @override
  String get dataError => '本地数据读取失败';

  @override
  String get editProject => '编辑项目';

  @override
  String get projectDashboard => '项目总览';

  @override
  String get waitingToLoad => '待装车';

  @override
  String get notArrived => '未到达';

  @override
  String get notUnpacked => '未拆箱';

  @override
  String get stageFilterHint => '点击阶段可直接筛选；可同时选择多个阶段。';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get boxes => '箱子';

  @override
  String get viewPending => '查看待标记';

  @override
  String get noPending => '所有箱子均已确认实体标记';

  @override
  String get markConfirmed => '确认实体标记';

  @override
  String get labelExported => '标签已导出';

  @override
  String get close => '关闭';

  @override
  String get shareCsv => '分享 CSV';

  @override
  String get shareBackup => '分享备份';

  @override
  String get createdAt => '创建时间';

  @override
  String get searchAllHint => '搜索全部项目中的箱子';

  @override
  String get projectArchived => '项目已归档';

  @override
  String get projectRestored => '项目已恢复';

  @override
  String get projectDeleted => '项目已删除';

  @override
  String get boxDeleted => '箱子记录已删除';

  @override
  String get selectMarkMethod => '选择已完成的实体标记方式';

  @override
  String get statusUpdated => '状态已更新';

  @override
  String get camera => '相机';

  @override
  String get gallery => '照片选择器';

  @override
  String get removePhoto => '移除照片';

  @override
  String get exportFailed => '导出失败，请稍后重试';

  @override
  String get share => '分享';

  @override
  String get print => '打印';

  @override
  String get allLabels => '全部标签';

  @override
  String get unknownProject => '未知项目';
}
