// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'RoamSum';

  @override
  String get homeTab => '首页';

  @override
  String get tripsTab => '行程';

  @override
  String get ledgerTab => '账本';

  @override
  String get settingsTab => '设置';

  @override
  String get scanAction => '扫一扫';

  @override
  String get homeTitle => '看懂真实消费成本';

  @override
  String get homeSubtitle => '换算当地价格，并比较不同支付方式。';

  @override
  String get tripsTitle => '行程';

  @override
  String get tripsSubtitle => '行程预算和离线旅行包将在这里展示。';

  @override
  String get ledgerTitle => '账本';

  @override
  String get ledgerSubtitle => '已保存的消费和实际入账将在这里展示。';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '管理货币、汇率、支付方式、同步与隐私。';

  @override
  String get scanTitle => '扫描';

  @override
  String get scanPurposeCompare => '比价';

  @override
  String get scanPurposeRecord => '记账';

  @override
  String get scanSubtitle => '拍下价签或账单，确认价格后再比较支付方式';

  @override
  String get scanRecordSubtitle => '扫描小票或账单，自动填写消费记录';

  @override
  String get scanCamera => '相机';

  @override
  String get scanPhotoLibrary => '相册';

  @override
  String get scanPrivacy => '识别仅在本机完成，原图不会上传。';

  @override
  String get scanRecognizing => '正在本机识别文字…';

  @override
  String get scanPreparingExpense => '正在识别并整理消费信息…';

  @override
  String get scanDetectedPrices => '识别出的价格';

  @override
  String scanDetectedPriceCount(int count) {
    return '已识别 $count 个价格';
  }

  @override
  String get scanSelectHint => '可选择一个价格，也可多选后求和。';

  @override
  String get scanLowConfidence => '置信度较低，请核对';

  @override
  String get scanManualEntry => '手动输入金额';

  @override
  String get scanManualEntryHint => '没有图片也可以继续';

  @override
  String get scanRecordManualEntry => '直接手动记账';

  @override
  String get scanRecordManualEntryHint => '不扫描也可以继续';

  @override
  String get scanCameraAction => '拍照扫描';

  @override
  String get scanRetake => '重新拍照';

  @override
  String get scanPhotoLibraryAction => '从相册选择';

  @override
  String get scanManualSheetTitle => '手动输入金额';

  @override
  String get scanManualSheetSubtitle => '直接输入商品标价';

  @override
  String get scanEditSheetTitle => '确认价格';

  @override
  String get scanEditSheetSubtitle => '修改识别结果';

  @override
  String get scanAmount => '金额';

  @override
  String get scanTransactionCurrency => '交易币种';

  @override
  String get scanChooseCurrency => '选择币种';

  @override
  String get scanInvalidEdit => '请输入有效金额并选择币种。';

  @override
  String get scanReviewBeforeContinue => '请核对金额与币种后再继续。';

  @override
  String get scanSaveAndUse => '保存并使用';

  @override
  String get scanCurrencyRequired => '请为每个已选价格确认币种。';

  @override
  String get scanMixedCurrencies => '已选价格包含不同币种，请编辑确认后继续。';

  @override
  String scanSelectedTotal(String currency, String amount) {
    return '已选合计 · $currency $amount';
  }

  @override
  String get scanContinue => '比较支付方式';

  @override
  String get scanPermissionDenied => '未获得访问权限。可改用另一种图片来源，或手动输入金额。';

  @override
  String get permissionCameraUnavailableTitle => '无法使用相机';

  @override
  String get permissionCameraUnavailableBody =>
      '请前往系统设置允许 RoamSum 使用相机，然后重试。如果权限受屏幕使用时间或设备管理限制，请先解除相应限制。';

  @override
  String get permissionPhotoLibraryUnavailableTitle => '无法访问相册';

  @override
  String get permissionPhotoLibraryUnavailableBody =>
      '请前往系统设置允许 RoamSum 访问相册，然后重试。如果权限受屏幕使用时间或设备管理限制，请先解除相应限制。';

  @override
  String get permissionOpenSettings => '前往设置';

  @override
  String get scanImageUnavailable => '图片已不可用，请重新选择或手动输入金额。';

  @override
  String get scanRecognitionFailed => '无法识别这张图片，请换一张或手动输入金额。';

  @override
  String get scanNoCandidates => '没有找到价格，请换一张图片或手动输入金额。';

  @override
  String get scanRateUnavailable => '该币种暂无参考汇率，请先在首页输入手动汇率后重试。';

  @override
  String get languageTitle => '语言';

  @override
  String get systemLanguage => '跟随系统';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get scaffoldNotice => '工程骨架已就绪';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始使用';

  @override
  String get onboardingScanTitle => '快速看懂当地价格';

  @override
  String get onboardingScanSubtitle => '扫描价签、菜单和账单，让陌生的当地价格一目了然。';

  @override
  String get onboardingCompareTitle => '比较不同支付成本';

  @override
  String get onboardingCompareSubtitle => '结合手续费与返现，比较不同支付方式的预计实际成本。';

  @override
  String get onboardingBudgetTitle => '持续掌握旅行预算';

  @override
  String get onboardingBudgetSubtitle => '将消费加入行程，随时了解已用预算和剩余金额。';

  @override
  String get onboardingSetupStart => '开始设置';

  @override
  String get onboardingSetupTitle => '快速设置';

  @override
  String get onboardingSetupSubtitle => '约 1 分钟，行程和支付方式也可以稍后添加。';

  @override
  String onboardingSetupProgress(int completed, int total) {
    return '已完成 $completed/$total';
  }

  @override
  String get onboardingSetupEnterHome => '进入首页';

  @override
  String get onboardingSetupContinue => '继续完善设置';

  @override
  String get onboardingSetupDismiss => '暂时关闭';

  @override
  String get onboardingSetupTripNotCreated => '未创建';

  @override
  String onboardingSetupTripCount(int count) {
    return '已创建 $count 个行程';
  }

  @override
  String get onboardingSetupPaymentNotAdded => '未添加';

  @override
  String onboardingSetupPaymentCount(int count) {
    return '已添加 $count 种';
  }

  @override
  String onboardingSetupCurrencySelected(String code) {
    return '$code · 已选择';
  }

  @override
  String get converterInputLabel => '当地价格或算式';

  @override
  String get converterInputHint => '例如：1200 * 3 + 500';

  @override
  String get converterResultLabel => '参考换算';

  @override
  String get converterInvalidExpression => '请检查算式，可直接在原处修改。';

  @override
  String get converterPositiveAmount => '请输入大于零的金额。';

  @override
  String get converterRateLoading => '正在获取最新参考汇率…';

  @override
  String get converterRateUnavailable => '暂无可用参考汇率，可添加手动汇率后继续。';

  @override
  String converterRateLive(String source, String time) {
    return '最新参考汇率 · $source · $time';
  }

  @override
  String converterRateCached(String time, String source) {
    return '缓存于 $time · $source';
  }

  @override
  String converterRateStale(String time) {
    return '较旧缓存于 $time · 支付前请复核';
  }

  @override
  String get converterRateManual => '当前使用手动参考汇率';

  @override
  String converterRateCard(String source, String time) {
    return '卡组织参考汇率 · $source · $time';
  }

  @override
  String get converterRateIdentity => '相同币种 · 汇率为 1';

  @override
  String get converterManualRate => '输入手动汇率';

  @override
  String get converterManualRateHint => '1 单位交易币种等于多少本位币';

  @override
  String get converterAdjustRate => '调整';

  @override
  String get converterRateSheetTitle => '选择换算汇率';

  @override
  String get converterMarketReference => '接口参考汇率';

  @override
  String get converterMarketUnavailable => '暂无接口参考汇率';

  @override
  String get converterManualReference => '手动汇率';

  @override
  String converterRateSourceDetail(String source, String time) {
    return '$source · $time';
  }

  @override
  String converterRateUnit(String quote, String base) {
    return '$quote / $base';
  }

  @override
  String get converterUseMarketRate => '改用接口参考汇率';

  @override
  String get converterSaveAndUse => '保存并使用';

  @override
  String converterRateDifferenceLower(String percent) {
    return '比接口参考汇率低 $percent%';
  }

  @override
  String converterRateDifferenceHigher(String percent) {
    return '比接口参考汇率高 $percent%';
  }

  @override
  String get converterRateDifferenceSame => '与接口参考汇率一致';

  @override
  String get converterRefresh => '刷新汇率';

  @override
  String get converterCompare => '比较支付方式';

  @override
  String get converterDcc => '检查 DCC';

  @override
  String get converterRecentTitle => '最近消费';

  @override
  String get converterRecentEmpty => '已保存的消费会显示在这里。';

  @override
  String get currencyLocal => '交易币种';

  @override
  String get currencyHome => '本位币';

  @override
  String get currencyCommonTrading => '常用交易货币';

  @override
  String get currencyAllTrading => '全部交易货币';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonDone => '完成';

  @override
  String get commonAdd => '添加';

  @override
  String get commonManage => '管理';

  @override
  String get commonEstimated => '预计';

  @override
  String get paymentMethodsTitle => '支付方式';

  @override
  String get paymentMethodsSubtitle => '仅保存费用规则。请勿输入卡号、有效期、CVV、身份信息或银行登录凭据。';

  @override
  String get paymentMethodsEmpty => '添加现金或银行卡后，即可比较预计成本。';

  @override
  String get paymentAddTitle => '添加支付方式';

  @override
  String get paymentEditorQuickStart => '快速设置';

  @override
  String get paymentEditorTemplateHint => '先套用常见规则，再按实际情况微调';

  @override
  String get paymentEditorBasics => '基本信息';

  @override
  String get paymentEditorFees => '费用规则';

  @override
  String get paymentEditorOptional => '可选信息';

  @override
  String get paymentEditName => '名称';

  @override
  String get paymentNamePlaceholder => '请输入支付方式名称';

  @override
  String get paymentOptionalPlaceholder => '选填';

  @override
  String get paymentNotesPlaceholder => '选填，例如适用条件或备注';

  @override
  String get paymentType => '类型';

  @override
  String get paymentNetwork => '卡组织';

  @override
  String get paymentBillingCurrency => '账单币种';

  @override
  String get paymentTemplate => '通用模板';

  @override
  String get paymentForeignFee => '外币转换费率 %';

  @override
  String get paymentCrossBorderFee => '境外交易费率 %';

  @override
  String get paymentRateMarkup => '汇率额外加价率 %';

  @override
  String get paymentFixedFee => '固定手续费';

  @override
  String get paymentCashback => '返现比例 %';

  @override
  String get paymentMinimumFee => '最低浮动手续费（可选）';

  @override
  String get paymentMaximumFee => '最高浮动手续费（可选）';

  @override
  String get paymentCashRate => '现金实际购汇汇率（可选）';

  @override
  String get paymentNotes => '备注（可选）';

  @override
  String get paymentTransactionScope => '适用交易';

  @override
  String get paymentPurchase => '消费';

  @override
  String get paymentAtm => 'ATM';

  @override
  String get paymentAll => '消费和 ATM';

  @override
  String get paymentTypeCredit => '信用卡';

  @override
  String get paymentTypeDebit => '借记卡';

  @override
  String get paymentTypeCash => '现金';

  @override
  String get paymentTypeWallet => '电子钱包';

  @override
  String get paymentTypeCustom => '自定义';

  @override
  String get paymentNetworkUnknown => '未知';

  @override
  String get paymentNetworkOther => '其他';

  @override
  String get paymentInvalidForm => '请检查名称、非负费率和手续费上下限。';

  @override
  String get paymentDeleteTitle => '删除这个支付方式？';

  @override
  String get paymentDeleteMessage => '历史消费保存的规则快照不会改变。';

  @override
  String get paymentPolicyNotice => '仅为通用估算；银行和卡组织政策可能变化。';

  @override
  String get paymentComparisonTitle => '支付方式预计成本';

  @override
  String get paymentComparisonMissing => '请先完成一次有效换算，再比较支付成本。';

  @override
  String get paymentComparisonNeedTwo => '至少添加两个适用的支付方式，比较才更有意义。';

  @override
  String paymentComparisonNoApplicable(String currency) {
    return '已有支付方式，但没有适用于以 $currency 入账的消费。请检查其账单币种和适用交易。';
  }

  @override
  String paymentComparisonOnlyOne(String currency) {
    return '当前只有一个支付方式适用于以 $currency 入账的消费。管理现有规则后可继续比较。';
  }

  @override
  String get paymentComparisonConfiguredButUnavailable =>
      '支付方式仍已保存，只是当前换算无法使用。';

  @override
  String get paymentRecommended => '最低预计成本';

  @override
  String paymentDifference(String amount) {
    return '比最低预计多 $amount';
  }

  @override
  String get paymentBaseAmount => '基础换算';

  @override
  String get paymentRateMarkupAmount => '汇率加价';

  @override
  String get paymentForeignFeeAmount => '外币转换费';

  @override
  String get paymentCrossBorderFeeAmount => '境外交易费';

  @override
  String get paymentVariableFee => '上下限修正后浮动手续费';

  @override
  String get paymentFixedFeeAmount => '固定手续费';

  @override
  String get paymentCashbackAmount => '预计返现';

  @override
  String get paymentEstimatedTotal => '预计实际成本';

  @override
  String get paymentCashRateUsed => '已优先使用你的现金实际购汇汇率';

  @override
  String get paymentEstimateDisclaimer => '所有金额均为估算，最终入账取决于商户、卡组织、发卡行和入账日期。';

  @override
  String get dccTitle => 'DCC 检查';

  @override
  String get dccLocalAmount => '当地货币金额';

  @override
  String get dccMerchantQuote => '商户本位币报价';

  @override
  String get dccOptionalPayment => '支付方式（可选）';

  @override
  String get dccNoPayment => '不选择支付方式';

  @override
  String get dccImpliedRate => '商户隐含汇率';

  @override
  String get dccReferenceRate => '参考汇率';

  @override
  String get dccReferenceAmount => '参考换算金额';

  @override
  String get dccExtraAmount => 'DCC 额外金额';

  @override
  String get dccExtraPercent => 'DCC 额外比例';

  @override
  String get dccLocalPaymentEstimate => '选择当地货币结算的预计成本';

  @override
  String dccGuidanceHigher(String percent) {
    return '商户提供的本位币报价比当前参考换算高约 $percent%。通常选择当地货币结算更透明，但最终入账金额仍取决于发卡机构。';
  }

  @override
  String get dccGuidanceLower => '商户报价未高于当前参考换算，但这仍只是成本比较；请在终端上复核币种和最终金额。';

  @override
  String get dccInvalidLocal => '请输入大于零的当地货币金额。';

  @override
  String get dccInvalidQuote => '请输入大于零的商户报价。';

  @override
  String get dccSameCurrency => 'DCC 检查需要两个不同币种。';

  @override
  String get dccMissingRate => '需要先获得参考汇率才能检查 DCC。';

  @override
  String get templateNoForeignFee => '无外币手续费卡';

  @override
  String get templateOnePercent => '1% 手续费卡';

  @override
  String get templateOnePointFivePercent => '1.5% 手续费卡';

  @override
  String get templateTwoPercent => '2% 手续费卡';

  @override
  String get templateUnionPayCny => '银联人民币结算卡';

  @override
  String get templateCash => '现金兑换';

  @override
  String get templateCustom => '完全自定义';

  @override
  String get onboardingHomeCurrency => '建议本位币';

  @override
  String get onboardingCreateTrip => '创建行程';

  @override
  String get onboardingAddPayment => '添加支付方式';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonNone => '无';

  @override
  String get commonAll => '全部';

  @override
  String get tripCreate => '新建行程';

  @override
  String get tripEdit => '编辑行程';

  @override
  String get tripCopy => '复制配置';

  @override
  String get tripArchive => '归档';

  @override
  String get tripDeleteTitle => '删除这个行程？';

  @override
  String get tripDeleteMessage => '消费会保留在账本中但不再关联此行程。请选择是否同时移除其本地票据图片；此操作无法撤销。';

  @override
  String get tripExport => '导出此行程';

  @override
  String get tripDeleteKeepReceipts => '删除行程，保留票据';

  @override
  String get tripDeleteWithReceipts => '删除行程及票据';

  @override
  String get tripReceiptDeletePartial => '行程已删除，但部分票据图片无法移除。';

  @override
  String get tripName => '行程名称';

  @override
  String get tripDestinations => '国家或地区';

  @override
  String get tripDestinationsHint => '例如：JP, KR';

  @override
  String get tripDestinationsEmpty => '请选择';

  @override
  String get tripCurrentAndUpcoming => '当前与即将';

  @override
  String get tripHistoryTab => '历史';

  @override
  String get tripRoutePlannerTitle => '规划多国路线';

  @override
  String get tripRoutePlannerSubtitle => '按顺序添加停留地，预算与统计将汇总整趟行程。';

  @override
  String get tripStopsTitle => '目的地与停留';

  @override
  String get tripAddNextStop => '添加下一站';

  @override
  String get tripWholeRange => '整段行程';

  @override
  String get tripDateRangePickerTitle => '选择日期范围';

  @override
  String get tripWholeBudget => '整趟预算';

  @override
  String get tripMoreSettings => '更多设置';

  @override
  String get tripCurrentStop => '当前';

  @override
  String get tripNextStop => '下一站';

  @override
  String tripDaysLater(int count) {
    return '$count天后';
  }

  @override
  String tripDayCount(int count) {
    return '$count天';
  }

  @override
  String tripStopDayProgress(int day, int total) {
    return '第$day天/$total天';
  }

  @override
  String tripBudgetUsed(String percent) {
    return '$percent% 已用';
  }

  @override
  String tripBudgetRemainingPercent(String percent) {
    return '$percent% 剩余';
  }

  @override
  String get tripDailyBudgetHint => '基于剩余天数 · 动态更新';

  @override
  String tripDailyBudgetApprox(String amount) {
    return '约 $amount / 天';
  }

  @override
  String get tripViewAction => '查看行程';

  @override
  String get tripRecordAction => '记一笔';

  @override
  String get tripRouteRequired => '至少添加一个目的地。';

  @override
  String get tripAdjustStopEnd => '调整离开日期';

  @override
  String get tripChangeDestination => '修改目的地';

  @override
  String get tripChangeStopCurrency => '修改当地货币';

  @override
  String get tripRemoveStop => '移除此站';

  @override
  String get tripOfflineMultiHint => '包含全部当地货币，无需定位权限。';

  @override
  String get countrySearchEmpty => '未找到国家或地区';

  @override
  String get countryUnknownSaved => '已保存但未识别，请选择有效地区后移除';

  @override
  String get tripStartDate => '开始日期';

  @override
  String get tripEndDate => '结束日期';

  @override
  String get tripLocalCurrencies => '当地货币';

  @override
  String get tripLocalCurrenciesPending => '选择目的地后推荐';

  @override
  String get tripLocalCurrenciesMissing => '未识别，请手动选择';

  @override
  String tripLocalCurrenciesRecommended(String currencies) {
    return '$currencies · 已推荐';
  }

  @override
  String get tripCurrencyRecommendationTitle => '更新当地货币？';

  @override
  String tripCurrencyRecommendationMessage(String currencies) {
    return '所选国家或地区通常使用 $currencies。是否更新当地货币？';
  }

  @override
  String get tripCurrencyRecommendationKeep => '保留当前';

  @override
  String get tripCurrencyRecommendationUpdate => '更新';

  @override
  String get tripBudget => '总预算';

  @override
  String get tripBudgetOptional => '可选；允许为零';

  @override
  String get tripParticipants => '同行人数';

  @override
  String get tripDefaultPayment => '默认支付方式';

  @override
  String get tripOfflinePack => '离线汇率包';

  @override
  String get tripOfflinePackHint => '准备选定的当地货币与本位币，不请求定位权限。';

  @override
  String get tripInvalid => '请检查名称、日期、货币、预算和人数。';

  @override
  String get tripActive => '进行中';

  @override
  String get tripUpcoming => '即将开始';

  @override
  String get tripHistory => '历史行程';

  @override
  String get tripMissing => '此行程已不可用。';

  @override
  String get tripNoBudget => '未设置预算';

  @override
  String get tripSpent => '已消费';

  @override
  String get tripRemaining => '剩余预算';

  @override
  String get tripDailyRemaining => '剩余每日可用';

  @override
  String get tripDayProgress => '行程天数';

  @override
  String get tripDailyAverage => '当前日均消费';

  @override
  String get tripPaymentBreakdown => '支付方式占比';

  @override
  String get tripOfflineReady => '离线包已就绪';

  @override
  String get tripOfflineMissing => '离线包未下载';

  @override
  String get expenseManualAdd => '手动记账';

  @override
  String expenseOcrPrefillBanner(int count) {
    return '已从票据填入 $count 项，请核对';
  }

  @override
  String get expenseOcrNeedsConfirmation => '待确认';

  @override
  String get expenseSave => '保存消费';

  @override
  String get expenseRecent => '最近消费';

  @override
  String get expenseEditorBasics => '基本信息';

  @override
  String get expenseEditorAmount => '金额';

  @override
  String get expenseEditorPaymentStatus => '支付与状态';

  @override
  String get expenseEditorTripCategory => '行程与分类';

  @override
  String get expenseEditorAdjustments => '附加费用与人数';

  @override
  String get expenseEditorLiveHint => '随行程、币种和支付方式实时更新';

  @override
  String get expenseTitle => '商户或项目';

  @override
  String get expenseTitlePlaceholder => '请输入商户或项目';

  @override
  String get expenseTrip => '行程';

  @override
  String get expenseCategory => '分类';

  @override
  String get expenseTransactionAmount => '交易金额';

  @override
  String get expenseTransactionAmountPlaceholder => '请输入交易金额';

  @override
  String get expenseReferenceAmount => '参考换算';

  @override
  String get expenseEstimatedAmount => '预计最终';

  @override
  String get expenseActualAmount => '实际入账金额';

  @override
  String get expensePaymentMethod => '支付方式';

  @override
  String get expenseTax => '税费（本位币）';

  @override
  String get expenseTip => '小费（本位币）';

  @override
  String get expenseDiscount => '优惠（本位币）';

  @override
  String get expenseDate => '消费日期';

  @override
  String get expenseReceiptPath => '票据附件（可选）';

  @override
  String get expenseReceiptSection => '票据附件';

  @override
  String get expenseReceiptReplace => '更换';

  @override
  String get expenseReceiptAdd => '添加照片';

  @override
  String get expenseReceiptRemove => '移除票据';

  @override
  String get expenseNotes => '备注';

  @override
  String get expenseBudgetIncluded => '计入行程预算';

  @override
  String get expenseStatus => '状态';

  @override
  String get expenseAmountStatus => '金额状态';

  @override
  String get expensePending => '待入账';

  @override
  String get expenseConfirmed => '已入账';

  @override
  String get expenseInvalid => '请检查名称、正数金额、币种和人数。';

  @override
  String get expenseMissingRequired => '还需填写商户名称和交易金额';

  @override
  String get expenseDuplicateTitle => '可能重复保存';

  @override
  String get expenseDuplicateMessage => '五分钟内已有相同消费，仍要再保存一笔吗？';

  @override
  String get expenseSaveAnyway => '仍然保存';

  @override
  String get expenseMissing => '此消费已不可用。';

  @override
  String get expenseDifference => '与预计金额差额';

  @override
  String get expenseRateSnapshot => '已保存汇率快照';

  @override
  String get expensePaymentSnapshot => '已保存费用规则快照';

  @override
  String get expenseActualConflict => '存在两个实际入账金额，需要解决冲突后才能继续同步。';

  @override
  String get expenseRecordActual => '补录实际入账';

  @override
  String get expenseEditActual => '修改实际入账';

  @override
  String get expenseAdjust => '退款或撤销';

  @override
  String get expenseRefund => '退款';

  @override
  String get expensePartialRefund => '部分退款';

  @override
  String get expenseVoid => '已撤销';

  @override
  String get expenseRefundInvalid => '退款金额必须大于零，且不能超过原消费的实际入账金额。';

  @override
  String get expenseRefundStatus => '退款状态';

  @override
  String get expenseRefundNone => '无退款';

  @override
  String get expenseRefundPartialStatus => '部分退款';

  @override
  String get expenseRefundFullStatus => '已全部退款';

  @override
  String get expenseRefundInvalidStatus => '退款金额异常';

  @override
  String get expenseRefundedTotal => '累计退款';

  @override
  String get expenseNetAmount => '净支出';

  @override
  String get expenseRefundRecords => '退款记录';

  @override
  String get expenseRelatedOriginal => '关联原交易';

  @override
  String get expenseViewOriginal => '查看原交易';

  @override
  String get expenseCorrectOriginal => '更正原交易金额';

  @override
  String get expenseCorrectRefund => '更正退款金额';

  @override
  String get expenseRecordRefund => '记录退款';

  @override
  String get expenseContinueRefund => '继续退款';

  @override
  String get expenseVoidAction => '撤销记录';

  @override
  String get expenseVoidConfirm => '仅未实际入账的记录可以撤销。确定撤销这条记录吗？';

  @override
  String get expenseCorrectionWarning => '修改原交易金额可能改变退款状态，但不会修改已有退款金额。';

  @override
  String get expenseAdjustmentInvalid => '操作无法完成，请检查原交易金额与累计退款。';

  @override
  String get expenseManualRateSource => '手动记账汇率';

  @override
  String get expenseManualPaymentRule => '手动录入';

  @override
  String get ledgerTimeline => '明细';

  @override
  String get ledgerCalendar => '日历';

  @override
  String get ledgerCategories => '分类';

  @override
  String get ledgerFilters => '筛选';

  @override
  String get ledgerClearFilters => '清除';

  @override
  String get ledgerThisMonth => '本月';

  @override
  String get ledgerLastMonth => '上月';

  @override
  String get ledgerAllTime => '全部';

  @override
  String get ledgerThisMonthSpending => '本月支出';

  @override
  String get ledgerLastMonthSpending => '上月支出';

  @override
  String get ledgerTotalSpending => '累计支出';

  @override
  String ledgerSummaryCount(int count, String currencyCode) {
    return '$count 笔 · 按本位币 $currencyCode 统计';
  }

  @override
  String ledgerToday(String date) {
    return '今天 · $date';
  }

  @override
  String ledgerDayCount(int count) {
    return '$count 笔';
  }

  @override
  String get ledgerEmpty => '暂无符合条件的消费。';

  @override
  String get ledgerMinimumAmount => '最低金额';

  @override
  String get ledgerMaximumAmount => '最高金额';

  @override
  String get ledgerInvalidFilters => '请输入有效的非负金额范围。';

  @override
  String ledgerFilteredCount(int count) {
    return '共 $count 笔消费';
  }

  @override
  String ledgerRecentDays(int count) {
    return '最近 $count 天';
  }

  @override
  String ledgerRecentDaysShort(int count) {
    return '$count天';
  }

  @override
  String get ledgerCustomDate => '自定义';

  @override
  String get ledgerDateRangePickerTitle => '选择日期范围';

  @override
  String get ledgerStartDate => '开始日期';

  @override
  String get ledgerEndDate => '结束日期';

  @override
  String ledgerViewRecords(int count) {
    return '查看 $count 笔记录';
  }

  @override
  String get ledgerSelectionSeparator => '、';

  @override
  String get calibrationNone => '补录实际金额后，会在本地形成费用对比。';

  @override
  String calibrationRange(int count, String minimum, String maximum) {
    return '最近 $count 笔可比较交易的综合加价为 $minimum%～$maximum%；至少三笔后才建议调整规则。';
  }

  @override
  String calibrationRangeReady(int count, String minimum, String maximum) {
    return '最近 $count 笔可比较交易的综合加价为 $minimum%～$maximum%；请复核后再手动调整规则。';
  }

  @override
  String get categoryFood => '餐饮';

  @override
  String get categoryTransport => '交通';

  @override
  String get categoryShopping => '购物';

  @override
  String get categoryHotel => '住宿';

  @override
  String get categoryTickets => '门票';

  @override
  String get categoryOther => '其他';

  @override
  String get syncTitle => 'iCloud 同步';

  @override
  String get syncEnable => '通过 iCloud 同步结构化数据';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncStatusDisabled => '同步已关闭，本地数据保持不变。';

  @override
  String get syncStatusIdle => '可以开始同步';

  @override
  String get syncStatusWorking => '正在同步…';

  @override
  String get syncStatusSucceeded => '已是最新';

  @override
  String get syncCompletedNotice => 'iCloud 同步完成，最新数据已更新到界面。';

  @override
  String get syncStatusWaiting => '等待重试';

  @override
  String get syncStatusFailed => '同步失败，本地数据仍可正常使用。';

  @override
  String get syncStatusNoAccount => '请登录 iCloud 后再同步。';

  @override
  String get syncStatusRestricted => '此设备上的 iCloud 受到限制。';

  @override
  String syncLastSuccess(String value) {
    return '最近成功同步：$value';
  }

  @override
  String syncFailureReason(String value) {
    return '失败原因：$value';
  }

  @override
  String get syncActualConflict => '检测到两个实际入账金额，请选择保留值。';

  @override
  String syncConflictValues(String local, String remote) {
    return '本机：$local · iCloud：$remote';
  }

  @override
  String get syncKeepLocal => '保留本机值';

  @override
  String get syncUseCloud => '使用 iCloud 值';

  @override
  String get commonContinue => '继续';

  @override
  String get settingsLoadFailed => '无法载入设置，本地数据保持不变。';

  @override
  String get settingsSectionCommon => '常用';

  @override
  String get settingsSectionDataDevices => '数据与设备';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsPaymentMethodsSummary => '管理银行卡、现金与手续费';

  @override
  String get settingsDataSummary => '导出、备份与清理';

  @override
  String get settingsPrivacySummary => '政策、权限与免责声明';

  @override
  String get kifxMiniTitle => 'KIFX小程序';

  @override
  String get kifxMiniSubtitle => '点击打开 KIFX 小程序';

  @override
  String get kifxMiniUnavailable => 'KIFX 小程序仅支持 iOS 设备。';

  @override
  String get kifxMiniOpenFailed => 'KIFX 小程序暂时无法打开，请稍后重试。';

  @override
  String get syncStatusEnabledShort => '已开启';

  @override
  String get syncStatusDisabledShort => '已关闭';

  @override
  String get rateSettingsTitle => '货币与汇率';

  @override
  String get defaultCurrency => '默认本位币';

  @override
  String get refreshInterval => '自动刷新';

  @override
  String refreshEveryHours(int count) {
    return '每 $count 小时';
  }

  @override
  String get wifiOnlyRefresh => '仅在 Wi-Fi 下刷新汇率';

  @override
  String get decimalDisplayRule => '小数显示';

  @override
  String get decimalDisplayCurrencyDefault => '按各币种标准位数显示';

  @override
  String get dataTitle => '数据、备份与导出';

  @override
  String get exportCsv => '将消费导出为 CSV';

  @override
  String get exportPdf => '将消费导出为 PDF';

  @override
  String get tripSummaryImageExport => '保存行程摘要图片';

  @override
  String get tripSummaryImageTitle => '行程摘要';

  @override
  String get tripSummaryImageSaveToPhotos => '保存到相册';

  @override
  String get tripSummaryImageSaved => '行程摘要已保存到相册。';

  @override
  String get tripSummaryImagePermissionDenied =>
      '相册权限未开启。请在系统设置中允许 RoamSum 添加照片后重试。';

  @override
  String get tripSummaryImageSaveFailed => '无法将行程摘要保存到相册。';

  @override
  String tripSummaryImageGeneratedAt(String date) {
    return '生成于 $date';
  }

  @override
  String get tripSummaryImageDisclaimer => '仅供个人参考，不包含票据图片和消费明细。';

  @override
  String get exportEmpty => '暂无可导出的消费记录。';

  @override
  String get exportTooLarge => '导出记录超过 20,000 条，请缩小数据范围后重试。';

  @override
  String get exportFailed => '无法生成或分享导出文件。';

  @override
  String get backupCreate => '创建本地备份';

  @override
  String get backupRestore => '从备份恢复';

  @override
  String get backupFailed => '无法创建或分享备份。';

  @override
  String get backupRestoreTitle => '恢复这个备份？';

  @override
  String get backupRestoreMessage => '有效备份会替换当前本地数据库；验证失败时不会覆盖当前数据库。';

  @override
  String get backupRestored => '备份已恢复。';

  @override
  String get backupRestoreFailed => '备份无效、不受支持或恢复失败，当前数据未被替换。';

  @override
  String get clearReceiptImages => '清除票据图片';

  @override
  String get clearReceiptImagesTitle => '清除全部票据图片？';

  @override
  String get clearReceiptImagesMessage => '消费记录会保留，但本地图片引用将被移除，且无法撤销。';

  @override
  String get clearReceiptImagesDone => '票据图片及其本地引用已清除。';

  @override
  String get clearAllData => '清除全部数据';

  @override
  String get clearAllDataTitle => '清除全部本地数据？';

  @override
  String get clearAllDataMessage =>
      '这会删除行程、消费、汇率、支付方式、设置、票据图片、同步状态和 Widget 快照。';

  @override
  String get clearAllDataAgainTitle => '确认永久删除';

  @override
  String get clearAllDataAgainMessage => '此操作无法撤销。请确认已经导出需要保留的数据后再继续。';

  @override
  String get clearDataFailed => '未能完整清除数据，操作没有记录为成功。';

  @override
  String get privacyTitle => '隐私与关于';

  @override
  String get privacyPolicyTitle => '隐私政策';

  @override
  String get privacyPolicyLoadFailed => '无法加载隐私政策，请检查网络后重试。';

  @override
  String get privacyPolicyBody =>
      'RoamSum 无需注册账户，也不保存完整卡号、CVV、身份证件或银行登录信息。行程、消费、设置和票据图片保存在本机；OCR 在本机执行，票据原图不会上传。启用 iCloud 同步后，结构化应用数据会发送到你的 CloudKit 私有数据库，票据原图不在同步范围内。市场参考汇率请求会发送到 Frankfurter。Frankfurter 声明其 API 本身不收集个人数据，但公共服务使用 Cloudflare，可能收集基础分析信息。导出和备份均在本机生成，只有你在系统分享面板中选择目标后才会离开应用。行程摘要图片只会在你点击“保存到相册”后添加到系统照片图库；是否通过 iCloud 照片同步取决于你的系统设置。';

  @override
  String get disclaimerTitle => '汇率与成本免责声明';

  @override
  String get disclaimerBody =>
      '汇率和费用估算仅供参考，不构成金融或投资建议。汇率为每日参考数据，可能来自缓存或存在延迟。银行、卡组织、支付机构和商户政策可能变化，授权日与清算日也可能不同。实际入账以发卡行、卡组织、支付机构和商户最终处理结果为准。DCC 比较不保证具体交易结果，也不保证绝对最低成本。';

  @override
  String get permissionsTitle => '权限与数据流';

  @override
  String get permissionsBody =>
      '只有你点击对应扫描操作后，应用才会请求相机或相册读取权限；只有你在行程摘要预览页点击“保存到相册”后，才会请求相册仅添加权限。拍摄和选择的图片使用 Apple Vision 在本机处理。通知和定位不是必要权限。只有开启结构化数据同步后才会访问 iCloud。票据原图保留在本机且不进入 CloudKit。CSV、PDF、备份和行程摘要图片均在本机生成。';
}
