import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/card_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/st_service.dart';
import '../services/user_preference_prefs.dart';
import '../utils/timezone_util.dart';
import 'h5_address_payload.dart';
import 'wallet_model.dart';
import 'auth_status_model.dart';

/// 用户状态模型
/// 对齐 iOS STUserInfoManger 所有核心属性
class UserState {
  // ==================== 登录态 ====================
  bool isLogin;
  String userId;

  /// 昵称（展示在「我的」头部；来自登录 data 或 /api/user/info）
  String nickname;
  String avatarUrl;
  String token;
  String refreshToken;
  double tokenExpiresAt;
  bool isAuthed; // 是否实名
  bool isBindBankCard; // 是否绑定银行卡
  bool isBindEWallet; // 是否绑定电子钱包
  bool isBindFundPassword; // 是否设置资金密码
  bool isBindPassword; // 是否设置登录密码
  bool isBindPhone; // 是否绑定手机号
  bool isBindEmail; // 是否绑定邮箱
  String phone; // 绑定手机号，对齐 iOS userInfoModel.tel
  String phoneAreaCode; // 绑定手机号区号，对齐 iOS userInfoModel.telAreaCode
  String email; // 绑定邮箱，对齐 iOS userInfoModel.email

  /// 对齐 iOS `STAnonymousUserId`：匿名 userId 含 `anonymous` 子串
  bool get isAnonymous => userId.toLowerCase().contains('anonymous');

  /// 真实用户登录（对齐 iOS `[STLoginManager isLogin]`，不含匿名 token 会话）
  bool get isExplicitlyLoggedIn => isLogin && !isAnonymous;

  /// 有效登录会话（真实登录且 token 非空），用于 Header / 设置页退出等展示/交互
  bool get hasActiveSession => isExplicitlyLoggedIn && token.trim().isNotEmpty;

  /// 可用于 API 鉴权的 token（含匿名），对齐 iOS `requestAuthTokenCallback`
  bool get hasAuthToken => token.trim().isNotEmpty;

  // ==================== A/B 面（版本更新接口下发） ====================
  bool isB; // 是否 B 面用户
  bool andC; // 辅助标记
  String bLan; // B 面默认语言（cn/en/...）

  // ==================== 交易账户 ====================
  String transactionAccount;
  String transactionAccountType;
  String transactionAccountIsActive;
  List<STAccountModel> accountAry;
  String appendMarginLevel; // 追加保证金比例（margin_call_ratio）
  String closeMarginLevel; // 强制平仓比例（margin_stop_out_ratio）

  // ==================== 钱包 ====================
  List<WalletModel> walletAry;
  String totalAmountUSD;
  String totalAmountLocalCurrency;
  String rateUSDToLocalCurrency;
  String localCurrency;

  // ==================== 跟单 ====================
  bool isSignalProvider; // 是否是带单员
  bool isTakeExam; // 是否参加考试

  // ==================== 偏好设置 ====================
  /// 0=绿涨红跌（`riseGreen`），1=红涨绿跌（`riseRed`），见 [CardTool.priceColor]
  int riseAndFallType;
  String selectedTimeZone; // 用户所选时区（UTC-12 ~ UTC+12）
  bool oneKeyClose; // 一键平仓开关
  bool profitOn; // 止盈开关
  bool stopLossOn; // 止损开关
  String currentTradeSymbol; // 交易页当前货币对
  String currentTradeSetLot; // 当前手数

  // ==================== H5 地址 ====================
  STH5AddressModel? h5AddressModel;

  // ==================== 返佣 ====================
  String totalRevenue;
  String canWithdraw;
  String withdrawnFunds;

  // ==================== 版本 ====================
  bool hasNewVersion;
  String version;
  String updateDesc;
  String downloadUrl;

  // ==================== KYC 权限配置 ====================
  List<STVerificationModel> verificationConfig;
  AuthStatusModel authStatus;

  // ==================== 特殊标记 ====================
  bool isNeedJumpToTrade; // 从我的页 jump 到交易页

  /// 对齐 iOS `need_update_password`：登录后需强制修改登录密码
  bool needUpdatePassword;

  /// 等级升降级待展示状态（对齐 iOS `STUserInfoManger` changeLevelID / changeLevelDirection）
  /// 来源：`violet/api/user/level/change_status` 的 `data`
  int pendingChangeLevelId;
  String pendingChangeLevelDirection;

  /// 「我的」VIP 卡片：对齐 iOS `requestGetLevel` → `STVipCardView.updateCardInfo:`（`data` Map）
  Map<String, dynamic> vipLevelPayload;

  UserState({
    this.isLogin = false,
    this.userId = '',
    this.nickname = '',
    this.avatarUrl = '',
    this.token = '',
    this.refreshToken = '',
    this.tokenExpiresAt = 0,
    this.isAuthed = false,
    this.isBindBankCard = false,
    this.isBindEWallet = false,
    this.isBindFundPassword = false,
    this.isBindPassword = false,
    this.isBindPhone = false,
    this.isBindEmail = false,
    this.phone = '',
    this.phoneAreaCode = '',
    this.email = '',
    this.isB = false,
    this.andC = false,
    this.bLan = '',
    this.transactionAccount = '',
    this.transactionAccountType = '',
    this.transactionAccountIsActive = '',
    this.accountAry = const [],
    this.appendMarginLevel = '',
    this.closeMarginLevel = '',
    this.walletAry = const [],
    this.totalAmountUSD = '',
    this.totalAmountLocalCurrency = '',
    this.rateUSDToLocalCurrency = '',
    this.localCurrency = '',
    this.isSignalProvider = false,
    this.isTakeExam = false,
    this.riseAndFallType = 0,
    String? selectedTimeZone,
    this.oneKeyClose = true,
    this.profitOn = false,
    this.stopLossOn = false,
    this.currentTradeSymbol = '',
    this.currentTradeSetLot = '',
    this.h5AddressModel,
    this.totalRevenue = '',
    this.canWithdraw = '',
    this.withdrawnFunds = '',
    this.hasNewVersion = false,
    this.version = '',
    this.updateDesc = '',
    this.downloadUrl = '',
    this.verificationConfig = const [],
    this.authStatus = const AuthStatusModel(status: 'none'),
    this.isNeedJumpToTrade = false,
    this.needUpdatePassword = false,
    this.pendingChangeLevelId = 0,
    this.pendingChangeLevelDirection = '',
    Map<String, dynamic>? vipLevelPayload,
  }) : selectedTimeZone =
           selectedTimeZone ?? TimezoneUtil.currentSystemIosUtcOffsetLabel(),
       vipLevelPayload = vipLevelPayload != null
           ? Map<String, dynamic>.from(vipLevelPayload)
           : <String, dynamic>{};

  /// 从 Map 中取首个非空的字符串（兼容 snake_case / camelCase）。
  static String? pickString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (!m.containsKey(k)) continue;
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// 对齐 iOS `STUserInfoModel` 里 BOOL / 0-1 字段的网络序列化。
  static bool parseApiBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static bool? parseApiBoolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return null;
  }

  static Map<String, dynamic> normalizeABTestPayload(
    Map<String, dynamic> data,
  ) {
    final normalized = <String, dynamic>{};

    if (data.containsKey('isB') || data.containsKey('is_b')) {
      normalized['isB'] = parseApiBool(data['isB'] ?? data['is_b']);
    } else if (data.containsKey('current_version_test_b_enable')) {
      normalized['isB'] = parseApiBool(data['current_version_test_b_enable']);
    }

    if (data.containsKey('andC') || data.containsKey('and_c')) {
      normalized['andC'] = parseApiBool(data['andC'] ?? data['and_c']);
    } else if (data.containsKey('current_version_test_c_enable')) {
      normalized['andC'] =
          (data['current_version_test_c_enable']?.toString() ?? '') == 'c';
    }

    if (data.containsKey('bLan') || data.containsKey('b_lan')) {
      normalized['bLan'] = pickString(data, ['bLan', 'b_lan']) ?? '';
    } else if (data.containsKey('b_side_language')) {
      final raw = data['b_side_language'];
      final trimmed = raw == null ? '' : raw.toString().trim();
      normalized['bLan'] = trimmed;
    }

    return normalized;
  }

  UserState copyWith({
    bool? isLogin,
    String? userId,
    String? nickname,
    String? avatarUrl,
    String? token,
    String? refreshToken,
    double? tokenExpiresAt,
    bool? isAuthed,
    bool? isBindBankCard,
    bool? isBindEWallet,
    bool? isBindFundPassword,
    bool? isBindPassword,
    bool? isBindPhone,
    bool? isBindEmail,
    String? phone,
    String? phoneAreaCode,
    String? email,
    bool? isB,
    bool? andC,
    String? bLan,
    String? transactionAccount,
    String? transactionAccountType,
    String? transactionAccountIsActive,
    List<STAccountModel>? accountAry,
    String? appendMarginLevel,
    String? closeMarginLevel,
    List<WalletModel>? walletAry,
    String? totalAmountUSD,
    String? totalAmountLocalCurrency,
    String? rateUSDToLocalCurrency,
    String? localCurrency,
    bool? isSignalProvider,
    bool? isTakeExam,
    int? riseAndFallType,
    String? selectedTimeZone,
    bool? oneKeyClose,
    bool? profitOn,
    bool? stopLossOn,
    String? currentTradeSymbol,
    String? currentTradeSetLot,
    STH5AddressModel? h5AddressModel,
    String? totalRevenue,
    String? canWithdraw,
    String? withdrawnFunds,
    bool? hasNewVersion,
    String? version,
    String? updateDesc,
    String? downloadUrl,
    List<STVerificationModel>? verificationConfig,
    AuthStatusModel? authStatus,
    bool? isNeedJumpToTrade,
    bool? needUpdatePassword,
    int? pendingChangeLevelId,
    String? pendingChangeLevelDirection,
    Map<String, dynamic>? vipLevelPayload,
  }) {
    return UserState(
      isLogin: isLogin ?? this.isLogin,
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      isAuthed: isAuthed ?? this.isAuthed,
      isBindBankCard: isBindBankCard ?? this.isBindBankCard,
      isBindEWallet: isBindEWallet ?? this.isBindEWallet,
      isBindFundPassword: isBindFundPassword ?? this.isBindFundPassword,
      isBindPassword: isBindPassword ?? this.isBindPassword,
      isBindPhone: isBindPhone ?? this.isBindPhone,
      isBindEmail: isBindEmail ?? this.isBindEmail,
      phone: phone ?? this.phone,
      phoneAreaCode: phoneAreaCode ?? this.phoneAreaCode,
      email: email ?? this.email,
      isB: isB ?? this.isB,
      andC: andC ?? this.andC,
      bLan: bLan ?? this.bLan,
      transactionAccount: transactionAccount ?? this.transactionAccount,
      transactionAccountType:
          transactionAccountType ?? this.transactionAccountType,
      transactionAccountIsActive:
          transactionAccountIsActive ?? this.transactionAccountIsActive,
      accountAry: accountAry ?? this.accountAry,
      appendMarginLevel: appendMarginLevel ?? this.appendMarginLevel,
      closeMarginLevel: closeMarginLevel ?? this.closeMarginLevel,
      walletAry: walletAry ?? this.walletAry,
      totalAmountUSD: totalAmountUSD ?? this.totalAmountUSD,
      totalAmountLocalCurrency:
          totalAmountLocalCurrency ?? this.totalAmountLocalCurrency,
      rateUSDToLocalCurrency:
          rateUSDToLocalCurrency ?? this.rateUSDToLocalCurrency,
      localCurrency: localCurrency ?? this.localCurrency,
      isSignalProvider: isSignalProvider ?? this.isSignalProvider,
      isTakeExam: isTakeExam ?? this.isTakeExam,
      riseAndFallType: riseAndFallType ?? this.riseAndFallType,
      selectedTimeZone: selectedTimeZone ?? this.selectedTimeZone,
      oneKeyClose: oneKeyClose ?? this.oneKeyClose,
      profitOn: profitOn ?? this.profitOn,
      stopLossOn: stopLossOn ?? this.stopLossOn,
      currentTradeSymbol: currentTradeSymbol ?? this.currentTradeSymbol,
      currentTradeSetLot: currentTradeSetLot ?? this.currentTradeSetLot,
      h5AddressModel: h5AddressModel ?? this.h5AddressModel,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      canWithdraw: canWithdraw ?? this.canWithdraw,
      withdrawnFunds: withdrawnFunds ?? this.withdrawnFunds,
      hasNewVersion: hasNewVersion ?? this.hasNewVersion,
      version: version ?? this.version,
      updateDesc: updateDesc ?? this.updateDesc,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      verificationConfig: verificationConfig ?? this.verificationConfig,
      authStatus: authStatus ?? this.authStatus,
      isNeedJumpToTrade: isNeedJumpToTrade ?? this.isNeedJumpToTrade,
      needUpdatePassword: needUpdatePassword ?? this.needUpdatePassword,
      pendingChangeLevelId: pendingChangeLevelId ?? this.pendingChangeLevelId,
      pendingChangeLevelDirection:
          pendingChangeLevelDirection ?? this.pendingChangeLevelDirection,
      vipLevelPayload: vipLevelPayload != null
          ? Map<String, dynamic>.from(vipLevelPayload)
          : this.vipLevelPayload,
    );
  }

  /// 登出时清除用户数据
  void clear() {
    isLogin = false;
    userId = '';
    nickname = '';
    avatarUrl = '';
    token = '';
    refreshToken = '';
    tokenExpiresAt = 0;
    isAuthed = false;
    isBindBankCard = false;
    isBindEWallet = false;
    isBindFundPassword = false;
    isBindPassword = false;
    isBindPhone = false;
    isBindEmail = false;
    phone = '';
    phoneAreaCode = '';
    email = '';
    isB = false;
    andC = false;
    bLan = '';
    transactionAccount = '';
    transactionAccountType = '';
    transactionAccountIsActive = '';
    accountAry = [];
    walletAry = [];
    totalAmountUSD = '';
    totalAmountLocalCurrency = '';
    rateUSDToLocalCurrency = '';
    localCurrency = '';
    appendMarginLevel = '';
    closeMarginLevel = '';
    isSignalProvider = false;
    isTakeExam = false;
    totalRevenue = '';
    canWithdraw = '';
    withdrawnFunds = '';
    hasNewVersion = false;
    version = '';
    updateDesc = '';
    downloadUrl = '';
    verificationConfig = [];
    authStatus = const AuthStatusModel(status: 'none');
    h5AddressModel = null;
    isNeedJumpToTrade = false;
    needUpdatePassword = false;
    pendingChangeLevelId = 0;
    pendingChangeLevelDirection = '';
    vipLevelPayload.clear();
  }

  /// 从 API 响应更新 A/B 面信息
  void updateABTest(Map<String, dynamic> data) {
    final normalized = normalizeABTestPayload(data);
    isB = normalized['isB'] as bool? ?? false;
    andC = normalized['andC'] as bool? ?? false;
    bLan = normalized['bLan'] as String? ?? '';
  }

  /// 从 API 响应更新交易账户信息
  void updateTransactionAccounts(Map<String, dynamic> data) {
    transactionAccount =
        UserState.pickString(data, [
          'transaction_account',
          'transactionAccount',
          'id',
        ]) ??
        transactionAccount;
    transactionAccountType =
        UserState.pickString(data, [
          'transaction_account_type',
          'transactionAccountType',
          'type',
        ]) ??
        transactionAccountType;
    if (data.containsKey('is_active') && data['is_active'] != null) {
      transactionAccountIsActive = data['is_active'].toString();
    }
    final mcr = UserState.pickString(data, [
      'margin_call_ratio',
      'marginCallRatio',
    ]);
    if (mcr != null && mcr.isNotEmpty) appendMarginLevel = mcr;
    final msr = UserState.pickString(data, [
      'margin_stop_out_ratio',
      'marginStopOutRatio',
    ]);
    if (msr != null && msr.isNotEmpty) closeMarginLevel = msr;
  }
}

/// 交易账户模型
/// 对齐 iOS STAccountModel
class STAccountModel {
  final String accountId;
  final String type;
  final String platform;
  final String currency;
  final String isActive;
  final String balance;
  final String equity;
  final String marginFree;
  final String canDraw;
  final String profit; // 浮动盈亏
  final String marginLevel; // 保证金水平
  final String accountType; // 账户类型文案
  final String status;
  final String transStatus;
  final String transStatusStr;
  final String transExamLevelStr;
  final String transTipReason;
  final String transExamId;

  STAccountModel({
    required this.accountId,
    this.type = '',
    this.platform = '',
    this.currency = '',
    this.isActive = '',
    this.balance = '',
    this.equity = '',
    this.marginFree = '',
    this.canDraw = '',
    this.profit = '',
    this.marginLevel = '',
    this.accountType = '',
    this.status = '',
    this.transStatus = '',
    this.transStatusStr = '',
    this.transExamLevelStr = '',
    this.transTipReason = '',
    this.transExamId = '',
  });

  factory STAccountModel.fromJson(Map<String, dynamic> json) {
    return STAccountModel(
      accountId:
          UserState.pickString(json, ['account_id', 'accountId', 'id']) ?? '',
      type: json['type']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      isActive: json['is_active']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '',
      equity: json['equity']?.toString() ?? '',
      marginFree:
          UserState.pickString(json, ['margin_free', 'marginFree']) ?? '',
      canDraw:
          UserState.pickString(json, ['can_draw', 'canDraw', 'margin_free']) ??
          '',
      profit: json['profit']?.toString() ?? '',
      marginLevel: json['margin_level']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      accountType:
          UserState.pickString(json, [
            'account_type',
            'accountType',
            'name',
            'account_name',
            'accountName',
            'login',
            'remark',
          ]) ??
          _accountTypeTitle(json['type'] ?? json['account_type']),
      transStatus:
          (json['trader_info'] is Map
                  ? (json['trader_info']['status'] ?? json['trans_status'])
                  : json['trans_status'])
              ?.toString() ??
          '',
      transStatusStr:
          UserState.pickString(
            json['trader_info'] is Map
                ? Map<String, dynamic>.from(json['trader_info'] as Map)
                : json,
            ['trans_status_name', 'trader_status_name', 'traderStatusStr'],
          ) ??
          UserState.pickString(json, [
            'trans_status_str',
            'transStatusStr',
            'trans_exam_status',
          ]) ??
          '',
      transExamLevelStr:
          UserState.pickString(
            json['trader_info'] is Map
                ? Map<String, dynamic>.from(json['trader_info'] as Map)
                : json,
            [
              'level_alias',
              'levelAlias',
              'trader_exam_level_name',
              'trader_exam_level',
            ],
          ) ??
          '',
      transTipReason:
          UserState.pickString(
            json['trader_info'] is Map
                ? Map<String, dynamic>.from(json['trader_info'] as Map)
                : json,
            ['reasons', 'reason', 'trans_tip_reason'],
          ) ??
          '',
      transExamId:
          UserState.pickString(
            json['trader_info'] is Map
                ? Map<String, dynamic>.from(json['trader_info'] as Map)
                : json,
            ['exam_id', 'examId', 'trader_exam_id'],
          ) ??
          '',
    );
  }

  static String _accountTypeTitle(dynamic value) {
    switch (value?.toString()) {
      case '0':
      case '4':
        return '真实账户';
      case '1':
        return '模拟账户';
      case '2':
        return '期权账户';
      case '3':
        return '交易员账户';
      default:
        return 'unKnow';
    }
  }
}

/// H5 地址模型（20 个 URL 字段）
class STH5AddressModel {
  final String partnerUrl;
  final String taskcenterUrl;
  final String vipCenterUrl;
  final String traderExamUrl;
  final String customerSupportUrl;
  final String traderExamMiddlePageUrl;
  final String tradingExplanationUrl;
  final String traderCenterUrl;
  final String officialWebsiteAUrl;
  final String officialWebsiteBUrl;
  final String traderProfitUrl;
  final String traderProfitOrderUrl;
  final String myFollowOrderUrl;
  final String traderOrderDetailsUrl;
  final String tradingCopyUrl;
  final String codeVerifyUrl;
  final String userAgreementUrl;
  final String privacyPolicyUrl;
  final String tradeUnlockActivityUrl;
  final String captchaApiKey;

  const STH5AddressModel({
    this.partnerUrl = '',
    this.taskcenterUrl = '',
    this.vipCenterUrl = '',
    this.traderExamUrl = '',
    this.customerSupportUrl = '',
    this.traderExamMiddlePageUrl = '',
    this.tradingExplanationUrl = '',
    this.traderCenterUrl = '',
    this.officialWebsiteAUrl = '',
    this.officialWebsiteBUrl = '',
    this.traderProfitUrl = '',
    this.traderProfitOrderUrl = '',
    this.myFollowOrderUrl = '',
    this.traderOrderDetailsUrl = '',
    this.tradingCopyUrl = '',
    this.codeVerifyUrl = '',
    this.userAgreementUrl = '',
    this.privacyPolicyUrl = '',
    this.tradeUnlockActivityUrl = '',
    this.captchaApiKey = '',
  });

  factory STH5AddressModel.fromJson(Map<String, dynamic> json) {
    final data = normalizeH5AddressPayload(json);
    final codeVerify = (data['code_verify_url'] as String? ?? '').trim();
    return STH5AddressModel(
      partnerUrl: data['partner_url'] as String? ?? '',
      taskcenterUrl: data['taskcenter_url'] as String? ?? '',
      vipCenterUrl: data['vip_center_url'] as String? ?? '',
      traderExamUrl: data['trader_exam_url'] as String? ?? '',
      customerSupportUrl: data['customer_support_url'] as String? ?? '',
      traderExamMiddlePageUrl:
          data['trader_exam_middle_page_url'] as String? ?? '',
      tradingExplanationUrl: data['trading_explanation_url'] as String? ?? '',
      traderCenterUrl: data['trader_center_url'] as String? ?? '',
      officialWebsiteAUrl: data['official_website_a_url'] as String? ?? '',
      officialWebsiteBUrl: data['official_website_b_url'] as String? ?? '',
      traderProfitUrl: data['trader_profit_url'] as String? ?? '',
      traderProfitOrderUrl: data['trader_profit_order_url'] as String? ?? '',
      myFollowOrderUrl: data['my_follow_order_url'] as String? ?? '',
      traderOrderDetailsUrl: data['trader_order_details_url'] as String? ?? '',
      tradingCopyUrl: data['trading_copy_url'] as String? ?? '',
      // iOS `STH5AddressModel` 固定兜底为本地 mini：localMini://codeverify。
      codeVerifyUrl: codeVerify.isEmpty ? 'localMini://codeverify' : codeVerify,
      userAgreementUrl:
          (data['user_agreement_url'] ?? data['agreement_url']) as String? ??
          '',
      privacyPolicyUrl:
          (data['privacy_policy_url'] ?? data['privacy_url']) as String? ?? '',
      tradeUnlockActivityUrl:
          data['trade_unlock_activity_url'] as String? ?? '',
      captchaApiKey: data['captcha_api_key'] as String? ?? '',
    );
  }
}

/// KYC 权限配置模型
/// 对齐 iOS STVerificationModel
class STVerificationModel {
  final String
  permission; // deposit / withdraw / internal_transfer / claim_bonus
  final String permissionAlias; // 权限别名
  final bool allowed; // 是否允许 true:允许 false:不允许
  final List<String> kycVerificationConfigAry; // KYC验证配置
  final int level;
  final List<String>
  authMethods; // document_verify / bankcard_verify / ewallet_verify / bind_tel / set_funds_pwd / bind_email
  final bool isVerified;
  final Map<String, dynamic> originalDic; // 原始数据

  const STVerificationModel({
    this.permission = '',
    this.permissionAlias = '',
    this.allowed = false,
    this.kycVerificationConfigAry = const [],
    this.level = 0,
    this.authMethods = const [],
    this.isVerified = false,
    this.originalDic = const {},
  });

  factory STVerificationModel.fromJson(Map<String, dynamic> json) {
    final kycList =
        (json['kyc_verification_config'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return STVerificationModel(
      permission: json['permission'] as String? ?? '',
      permissionAlias: json['permission_alias'] as String? ?? '',
      allowed: UserState.parseApiBool(json['allowed']),
      kycVerificationConfigAry: kycList,
      level: (json['level'] as num?)?.toInt() ?? 0,
      authMethods:
          (json['auth_methods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isVerified: UserState.parseApiBool(json['is_verified']),
      originalDic: json,
    );
  }
}

/// 涨跌类型
class RiseAndFallType {
  static const int riseGreen = 0; // 绿涨红跌
  static const int riseRed = 1; // 红涨绿跌

  static int fromString(String value) {
    switch (value.toLowerCase()) {
      case 'risegreen':
      case 'green':
        return 0;
      case 'risered':
      case 'red':
        return 1;
      default:
        return 0;
    }
  }
}

/// 用户认证状态枚举
class STUserAuthStatus {
  static const String notCommit = 'not_commit';
  static const String wait = 'wait';
  static const String success = 'success';
  static const String failed = 'failed';
}

// ==================== Riverpod Provider ====================

/// UserState 全局单例
final userStateProvider = StateNotifierProvider<UserStateNotifier, UserState>((
  ref,
) {
  return UserStateNotifier();
});

class UserStateNotifier extends StateNotifier<UserState> {
  UserStateNotifier() : super(UserState());

  /// 匿名登录成功（对齐 iOS `anonymousloginSuccessWithDic:`：有 token 但 `isLogin == NO`）
  Future<void> establishAnonymousSession(Map<String, dynamic> userData) async {
    final h5AddressModel = state.h5AddressModel;
    final isB = state.isB;
    final andC = state.andC;
    final bLan = state.bLan;
    final token = UserState.pickString(userData, ['token']) ?? '';
    final userId =
        UserState.pickString(userData, ['user_id', 'userId', 'id']) ?? '';
    state.clear();
    state = state.copyWith(
      isLogin: false,
      userId: userId,
      token: token,
      h5AddressModel: h5AddressModel,
      isB: isB,
      andC: andC,
      bLan: bLan,
    );
    await restoreLocalPreferences(includeTransactionAccount: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (userId.isNotEmpty) {
      await prefs.setString('user_id', userId);
    } else {
      await prefs.remove('user_id');
    }
    if (token.isNotEmpty) {
      await prefs.setString('token', token);
    } else {
      await prefs.remove('token');
    }
  }

  /// 登录成功（对齐 iOS `STLoginInfoModel` / login `data`：`user_id`、`transaction_account` 等）
  Future<void> login(Map<String, dynamic> userData) async {
    final h5AddressModel = state.h5AddressModel;
    final token = UserState.pickString(userData, ['token']) ?? '';
    final userId =
        UserState.pickString(userData, ['user_id', 'userId', 'id']) ?? '';
    final nickname =
        UserState.pickString(userData, [
          'nickname',
          'nickName',
          'name',
          'user_name',
          'userName',
        ]) ??
        '';
    final avatar =
        UserState.pickString(userData, [
          'avatar',
          'avatar_url',
          'head_img',
          'headImg',
          'head_url',
          'portrait',
          'photo',
        ]) ??
        '';
    final ta =
        UserState.pickString(userData, [
          'transaction_account',
          'transactionAccount',
        ]) ??
        '';
    final tat =
        UserState.pickString(userData, [
          'transaction_account_type',
          'transactionAccountType',
        ]) ??
        '';

    String taActive = '';
    if (userData.containsKey('is_active') && userData['is_active'] != null) {
      taActive = userData['is_active'].toString();
    } else if (ta.isNotEmpty || tat.isNotEmpty) {
      taActive = '-1';
    }

    final tz =
        UserState.pickString(userData, [
          'timezone',
          'time_zone',
          'selected_timezone',
          'user_timezone',
        ]) ??
        (await UserPreferencePrefs.readTimezone(userId: userId)) ??
        TimezoneUtil.currentSystemIosUtcOffsetLabel();
    final riseRaw = UserState.pickString(userData, [
      'rise_and_fall_type',
      'riseAndFallType',
    ]);
    final rise = riseRaw != null && riseRaw.isNotEmpty
        ? RiseAndFallApi.fromApiValue(riseRaw)
        : (await UserPreferencePrefs.readRiseAndFallType(userId: userId) ??
              RiseAndFallType.riseGreen);

    final oneKey =
        userData.containsKey('one_key_close') ||
            userData.containsKey('oneKeyClose')
        ? UserState.parseApiBool(
            userData['one_key_close'] ?? userData['oneKeyClose'],
          )
        : (await UserPreferencePrefs.readOneKeyClose(userId: userId) ?? true);

    final needPwd = UserState.parseApiBool(userData['need_update_password']);

    final abTest = UserState.normalizeABTestPayload(userData);
    final isB = abTest['isB'] as bool? ?? state.isB;
    final andC = abTest['andC'] as bool? ?? state.andC;
    final bLan = abTest['bLan'] as String? ?? state.bLan;
    final phone = UserState.pickString(userData, [
      'tel',
      'tel_phone',
      'mobile',
      'phone',
      'telphone',
    ]);
    final phoneAreaCode = UserState.pickString(userData, [
      'tel_area_code',
      'telAreaCode',
      'area_code',
      'areaCode',
    ]);
    final email = UserState.pickString(userData, ['email', 'mail']);
    final refreshToken =
        UserState.pickString(userData, ['refresh_token', 'refreshToken']) ?? '';
    final tokenExpiresAt = _parseExpAt(userData['exp_at'] ?? userData['expAt']);

    Map<String, dynamic>? authMap;
    final araw = userData['auth_status'] ?? userData['authStatus'];
    if (araw is Map<String, dynamic>) authMap = araw;

    state = UserState(
      isLogin: true,
      userId: userId,
      nickname: nickname,
      avatarUrl: avatar,
      token: token,
      refreshToken: refreshToken,
      tokenExpiresAt: tokenExpiresAt,
      isB: isB,
      andC: andC,
      bLan: bLan,
      isAuthed:
          userData['is_authed'] as bool? ??
          userData['isAuthed'] as bool? ??
          false,
      isBindBankCard:
          userData['is_bind_bank_card'] as bool? ??
          userData['isBindBankCard'] as bool? ??
          false,
      isBindEWallet:
          userData['is_bind_e_wallet'] as bool? ??
          userData['isBindEWallet'] as bool? ??
          false,
      isBindFundPassword:
          userData['is_bind_fund_password'] as bool? ??
          userData['isBindFundPassword'] as bool? ??
          false,
      isBindPassword:
          userData['is_bind_password'] as bool? ??
          userData['isBindPassword'] as bool? ??
          false,
      isBindPhone:
          userData['is_bind_phone'] as bool? ??
          userData['isBindPhone'] as bool? ??
          false,
      isBindEmail:
          userData['is_bind_email'] as bool? ??
          userData['isBindEmail'] as bool? ??
          false,
      phone: phone ?? '',
      phoneAreaCode: phoneAreaCode ?? '',
      email: email ?? '',
      selectedTimeZone: tz,
      riseAndFallType: rise,
      oneKeyClose: oneKey,
      authStatus: authMap != null
          ? AuthStatusModel.fromJson(authMap)
          : const AuthStatusModel(status: 'none'),
      transactionAccount: ta,
      transactionAccountType: tat,
      transactionAccountIsActive: taActive,
      h5AddressModel: h5AddressModel,
      needUpdatePassword: needPwd,
      pendingChangeLevelId: 0,
      pendingChangeLevelDirection: '',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', state.userId);
    await prefs.setString('token', state.token);
    if (state.refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', state.refreshToken);
    } else {
      await prefs.remove('refresh_token');
    }
    if (state.tokenExpiresAt > 0) {
      await prefs.setDouble('exp_at', state.tokenExpiresAt);
    } else {
      await prefs.remove('exp_at');
    }
    await prefs.setBool('is_logged_in', true);
    await UserPreferencePrefs.mergeFromLoginPayload(userData);
    CardTool.setRiseAndFallType(state.riseAndFallType);
  }

  /// 对齐 iOS `STLoginManager changeAccountSuccessWithDic:`：
  /// `/transaction/accounts/switch` 成功后，先把 response.data 应用为新的
  /// `STLoginInfoModel`/Authorization 上下文，再继续 `requestGetUserInfo`。
  Future<void> applyChangeAccountSuccessPayload(
    STService service,
    Map<String, dynamic> response,
  ) async {
    final data = _changeAccountLoginData(response);
    if (data == null || data.isEmpty) return;

    final token = UserState.pickString(data, ['token']) ?? '';
    final userId =
        UserState.pickString(data, ['user_id', 'userId', 'id']) ?? '';
    final ta =
        UserState.pickString(data, [
          'transaction_account',
          'transactionAccount',
        ]) ??
        '';
    final tat =
        UserState.pickString(data, [
          'transaction_account_type',
          'transactionAccountType',
        ]) ??
        '';
    String? taActive;
    if (data.containsKey('is_active') && data['is_active'] != null) {
      taActive = data['is_active'].toString();
    } else if (ta.isNotEmpty || tat.isNotEmpty) {
      taActive = '-1';
    }
    final needPwd = data.containsKey('need_update_password')
        ? UserState.parseApiBool(data['need_update_password'])
        : null;
    final refreshToken =
        UserState.pickString(data, ['refresh_token', 'refreshToken']) ??
        state.refreshToken;
    final expAt = _parseExpAt(data['exp_at'] ?? data['expAt']);

    if (token.isNotEmpty) {
      service.dio.setAuthToken(token);
    }

    state = state.copyWith(
      isLogin: true,
      userId: userId.isNotEmpty ? userId : state.userId,
      token: token.isNotEmpty ? token : state.token,
      refreshToken: refreshToken,
      tokenExpiresAt: expAt > 0 ? expAt : state.tokenExpiresAt,
      transactionAccount: ta.isNotEmpty ? ta : state.transactionAccount,
      transactionAccountType: tat.isNotEmpty
          ? tat
          : state.transactionAccountType,
      transactionAccountIsActive: taActive != null && taActive.isNotEmpty
          ? taActive
          : state.transactionAccountIsActive,
      needUpdatePassword: needPwd ?? state.needUpdatePassword,
    );

    final prefs = await SharedPreferences.getInstance();
    if (state.userId.isNotEmpty) {
      await prefs.setString('user_id', state.userId);
    }
    if (state.token.isNotEmpty) {
      await prefs.setString('token', state.token);
    }
    if (state.refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', state.refreshToken);
    }
    if (state.tokenExpiresAt > 0) {
      await prefs.setDouble('exp_at', state.tokenExpiresAt);
    }
    await prefs.setBool('is_logged_in', true);
    await UserPreferencePrefs.mergeFromLoginPayload(data);
  }

  /// 对齐 iOS `STLoginManager checkResponse` 的 401 分支：
  /// 响应里带 `data.token` 时只刷新登录模型和本地缓存，不登出、不弹窗。
  Future<void> applyRefreshedAuthTokenPayload(Map<String, dynamic> data) async {
    final token = UserState.pickString(data, ['token']) ?? '';
    if (token.isEmpty) return;
    final userId =
        UserState.pickString(data, ['user_id', 'userId', 'id']) ?? state.userId;
    final refreshToken =
        UserState.pickString(data, ['refresh_token', 'refreshToken']) ??
        state.refreshToken;
    final expAt = _parseExpAt(data['exp_at'] ?? data['expAt']);

    state = state.copyWith(
      userId: userId.isNotEmpty ? userId : state.userId,
      token: token,
      refreshToken: refreshToken,
      tokenExpiresAt: expAt > 0 ? expAt : state.tokenExpiresAt,
    );

    final prefs = await SharedPreferences.getInstance();
    if (state.userId.isNotEmpty) {
      await prefs.setString('user_id', state.userId);
    }
    await prefs.setString('token', state.token);
    if (state.refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', state.refreshToken);
    }
    if (state.tokenExpiresAt > 0) {
      await prefs.setDouble('exp_at', state.tokenExpiresAt);
    }
  }

  static double _parseExpAt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic>? _changeAccountLoginData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    final hasLoginFields =
        response.containsKey('token') ||
        response.containsKey('transaction_account') ||
        response.containsKey('transactionAccount');
    return hasLoginFields ? response : null;
  }

  /// 从本地磁盘恢复偏好（主题除外；涨跌色 / 一键平仓 / 时区 / 已选交易账户）
  Future<void> restoreLocalPreferences({
    bool includeTransactionAccount = true,
  }) async {
    final prefUserId = state.userId.isNotEmpty ? state.userId : null;
    final rise = await UserPreferencePrefs.readRiseAndFallType(
      userId: prefUserId,
    );
    final okc = await UserPreferencePrefs.readOneKeyClose(userId: prefUserId);
    final tz = await UserPreferencePrefs.readTimezone(userId: prefUserId);
    final tx = includeTransactionAccount
        ? await UserPreferencePrefs.readTransactionAccountSelection()
        : null;
    state = state.copyWith(
      riseAndFallType: rise ?? state.riseAndFallType,
      oneKeyClose: okc ?? state.oneKeyClose,
      selectedTimeZone: (tz != null && tz.isNotEmpty)
          ? tz
          : state.selectedTimeZone,
      transactionAccount: (tx != null && tx.account.isNotEmpty)
          ? tx.account
          : state.transactionAccount,
      transactionAccountType: (tx != null && tx.accountType.isNotEmpty)
          ? tx.accountType
          : state.transactionAccountType,
      transactionAccountIsActive: (tx != null && tx.isActive.isNotEmpty)
          ? tx.isActive
          : state.transactionAccountIsActive,
    );
    CardTool.setRiseAndFallType(state.riseAndFallType);
  }

  /// 登出
  Future<void> logout() async {
    final h5AddressModel = state.h5AddressModel;
    final isB = state.isB;
    final andC = state.andC;
    final bLan = state.bLan;
    // 必须整体替换 state，否则 Riverpod 不通知监听方，设置页等仍会误认为已登录（对齐 iOS 登出后 UI）
    state = UserState(
      h5AddressModel: h5AddressModel,
      isB: isB,
      andC: andC,
      bLan: bLan,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_id');
    await prefs.remove('token');
    await prefs.remove('refresh_token');
    await prefs.remove('exp_at');
    await UserPreferencePrefs.clearTransactionAccountSelection();
    await restoreLocalPreferences(includeTransactionAccount: false);
  }

  /// 更新 A/B 面信息
  void updateABTest(Map<String, dynamic> data) {
    final normalized = UserState.normalizeABTestPayload(data);
    state = state.copyWith(
      isB: normalized['isB'] as bool? ?? state.isB,
      andC: normalized['andC'] as bool? ?? state.andC,
      bLan: normalized['bLan'] as String? ?? state.bLan,
    );
  }

  /// 更新版本更新信息（对齐 iOS `app_update_info`）
  void updateVersionUpdateInfo(Map<String, dynamic> data) {
    final payload = data['app_update_info'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['app_update_info'])
        : (data['app_update_info'] is Map
                  ? Map<String, dynamic>.from(data['app_update_info'])
                  : null) ??
              data;
    final hasUpdate = UserState.parseApiBool(payload['has_update']);
    state.hasNewVersion = hasUpdate;
    state.version = UserState.pickString(payload, ['version']) ?? '';
    state.updateDesc =
        UserState.pickString(payload, ['update_desc', 'description']) ?? '';
    state.downloadUrl =
        UserState.pickString(payload, ['download_url', 'downloadUrl']) ?? '';
  }

  /// 更新 H5 地址（对齐 iOS STH5AddressModel）
  void updateH5Address(Map<String, dynamic> data) {
    final next = STH5AddressModel.fromJson(data);
    final current = state.h5AddressModel;
    state = state.copyWith(
      h5AddressModel: current == null
          ? next
          : _mergeH5AddressModel(current: current, next: next),
    );
  }

  static STH5AddressModel _mergeH5AddressModel({
    required STH5AddressModel current,
    required STH5AddressModel next,
  }) {
    String keepStatic(String cached, String incoming) {
      final currentValue = cached.trim();
      if (currentValue.isNotEmpty) return cached;
      return incoming;
    }

    String fillEmpty(String cached, String incoming) {
      final nextValue = incoming.trim();
      if (nextValue.isNotEmpty) return incoming;
      return cached;
    }

    return STH5AddressModel(
      partnerUrl: fillEmpty(current.partnerUrl, next.partnerUrl),
      taskcenterUrl: fillEmpty(current.taskcenterUrl, next.taskcenterUrl),
      vipCenterUrl: fillEmpty(current.vipCenterUrl, next.vipCenterUrl),
      traderExamUrl: fillEmpty(current.traderExamUrl, next.traderExamUrl),
      customerSupportUrl: keepStatic(
        current.customerSupportUrl,
        next.customerSupportUrl,
      ),
      traderExamMiddlePageUrl: fillEmpty(
        current.traderExamMiddlePageUrl,
        next.traderExamMiddlePageUrl,
      ),
      tradingExplanationUrl: fillEmpty(
        current.tradingExplanationUrl,
        next.tradingExplanationUrl,
      ),
      traderCenterUrl: fillEmpty(current.traderCenterUrl, next.traderCenterUrl),
      officialWebsiteAUrl: keepStatic(
        current.officialWebsiteAUrl,
        next.officialWebsiteAUrl,
      ),
      officialWebsiteBUrl: keepStatic(
        current.officialWebsiteBUrl,
        next.officialWebsiteBUrl,
      ),
      traderProfitUrl: fillEmpty(current.traderProfitUrl, next.traderProfitUrl),
      traderProfitOrderUrl: fillEmpty(
        current.traderProfitOrderUrl,
        next.traderProfitOrderUrl,
      ),
      myFollowOrderUrl: fillEmpty(
        current.myFollowOrderUrl,
        next.myFollowOrderUrl,
      ),
      traderOrderDetailsUrl: fillEmpty(
        current.traderOrderDetailsUrl,
        next.traderOrderDetailsUrl,
      ),
      tradingCopyUrl: fillEmpty(current.tradingCopyUrl, next.tradingCopyUrl),
      codeVerifyUrl: fillEmpty(current.codeVerifyUrl, next.codeVerifyUrl),
      userAgreementUrl: keepStatic(
        current.userAgreementUrl,
        next.userAgreementUrl,
      ),
      privacyPolicyUrl: keepStatic(
        current.privacyPolicyUrl,
        next.privacyPolicyUrl,
      ),
      tradeUnlockActivityUrl: fillEmpty(
        current.tradeUnlockActivityUrl,
        next.tradeUnlockActivityUrl,
      ),
      captchaApiKey: fillEmpty(current.captchaApiKey, next.captchaApiKey),
    );
  }

  /// 绑定邮箱成功后同步本地状态（对齐 iOS 直接更新 `STUserInfoManger.userInfoModel`）。
  void markEmailBound() {
    state = state.copyWith(isBindEmail: true);
  }

  /// 绑定手机号成功后同步本地状态（对齐 iOS 直接更新 `STUserInfoManger.userInfoModel`）。
  void markPhoneBound() {
    state = state.copyWith(isBindPhone: true);
  }

  /// 更新认证状态
  void updateAuthStatus(AuthStatusModel status) {
    state = state.copyWith(
      authStatus: status,
      isAuthed: status.isApproved,
      isBindBankCard: status.bankCardStatus,
      isBindEWallet: status.eWalletStatus,
      isBindFundPassword: status.fundPasswordStatus,
      isBindPhone: status.telBindStatus,
      isBindEmail: status.emailBindStatus,
    );
  }

  /// 下单/绑卡等高风险动作前即时刷新认证状态，避免沿用旧缓存误拦截。
  Future<bool> refreshAuthStatus(STService service) async {
    try {
      final raw = await service.getAuthStatus();
      final source = _authStatusSourceFromResponse(raw);
      if (source == null) return state.isAuthed;
      final status = AuthStatusModel.fromJson(source);
      updateAuthStatus(status);
      return status.isApproved;
    } catch (_) {
      return state.isAuthed;
    }
  }

  /// 更新钱包列表
  void updateWallets(List<WalletModel> wallets) {
    state = state.copyWith(walletAry: wallets);
  }

  /// 更新钱包资产汇总（对齐 iOS `requestWalletListWithCompletion` 的 data 汇总字段）。
  void updateWalletAssetTotals({
    String? totalAmountUSD,
    String? totalAmountLocalCurrency,
    String? rateUSDToLocalCurrency,
    String? localCurrency,
  }) {
    String nonEmpty(String? next, String current) {
      final text = next?.trim() ?? '';
      return text.isEmpty ? current : text;
    }

    state = state.copyWith(
      totalAmountUSD: nonEmpty(totalAmountUSD, state.totalAmountUSD),
      totalAmountLocalCurrency: nonEmpty(
        totalAmountLocalCurrency,
        state.totalAmountLocalCurrency,
      ),
      rateUSDToLocalCurrency: nonEmpty(
        rateUSDToLocalCurrency,
        state.rateUSDToLocalCurrency,
      ),
      localCurrency: nonEmpty(localCurrency, state.localCurrency),
    );
  }

  /// 更新钱包资产页数据（对齐 iOS `STUserInfoManger getWalletListComplete`）。
  void updateWalletInfo(Map<String, dynamic> data) {
    final wallets = STService.walletListFromInfo(data)
        .whereType<Map>()
        .map((e) => WalletModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final accounts = STService.transAccountsFromWalletInfo(data)
        .whereType<Map>()
        .map((e) => STAccountModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    state = state.copyWith(
      walletAry: wallets,
      accountAry: accounts,
      totalAmountUSD:
          UserState.pickString(data, [
            'total_amount_usd',
            'totalAmountUSD',
            'totalAmountUsd',
          ]) ??
          state.totalAmountUSD,
      totalAmountLocalCurrency:
          UserState.pickString(data, [
            'total_local_amount',
            'totalAmountLocalCurrency',
            'totalLocalAmount',
          ]) ??
          state.totalAmountLocalCurrency,
      rateUSDToLocalCurrency:
          UserState.pickString(data, [
            'local_currency_rate',
            'rateUSDToLocalCurrency',
          ]) ??
          state.rateUSDToLocalCurrency,
      localCurrency:
          UserState.pickString(data, ['local_currency', 'localCurrency']) ??
          state.localCurrency,
    );
  }

  /// 更新交易账户列表
  void updateAccounts(List<STAccountModel> accounts) {
    state = state.copyWith(accountAry: accounts);
  }

  /// 更新交易账户信息（追加保证金、强制平仓比例等）
  Future<void> updateTransactionAccounts(Map<String, dynamic> data) async {
    state.updateTransactionAccounts(data);
    state = state.copyWith(
      transactionAccount: state.transactionAccount,
      transactionAccountType: state.transactionAccountType,
      transactionAccountIsActive: state.transactionAccountIsActive,
      appendMarginLevel: state.appendMarginLevel,
      closeMarginLevel: state.closeMarginLevel,
    );
    await UserPreferencePrefs.saveTransactionAccountSelection(
      account: state.transactionAccount,
      accountType: state.transactionAccountType,
      isActive: state.transactionAccountIsActive,
    );
  }

  /// 更新 KYC 配置
  void updateVerificationConfig(List<STVerificationModel> config) {
    state.verificationConfig = config;
  }

  /// 更新 isNeedJumpToTrade 标记
  void updateNeedJumpToTrade(bool value) {
    state = state.copyWith(isNeedJumpToTrade: value);
  }

  /// 对齐 iOS `updateCurrentTradeSymbol` / `updateCurrentTradeSetLot`
  void rememberTradeSelection({required String symbol, required String lot}) {
    state = state.copyWith(currentTradeSymbol: symbol, currentTradeSetLot: lot);
  }

  /// 同步昵称（个人资料保存或 /api/user/info）
  void updateNickname(String value) {
    state = state.copyWith(nickname: value);
  }

  /// 同步头像（个人资料保存或 /api/user/info）
  void updateAvatar(String value) {
    state = state.copyWith(avatarUrl: value);
  }

  /// 对齐 iOS `requestGetLevel`：`STNewMineViewController.getLevel` → `STVipCardView.updateCardInfo:`
  void updateVipLevelPayload(Map<String, dynamic> payload) {
    state = state.copyWith(vipLevelPayload: payload);
  }

  /// 更新返佣数据
  void updateCommissionData({
    required String totalRevenue,
    required String canWithdraw,
    required String withdrawnFunds,
  }) {
    state = state.copyWith(
      totalRevenue: totalRevenue,
      canWithdraw: canWithdraw,
      withdrawnFunds: withdrawnFunds,
    );
  }

  /// 更新偏好设置
  void updatePreferences(Map<String, dynamic> prefs) {
    if (prefs.containsKey('riseAndFallType')) {
      state.riseAndFallType = prefs['riseAndFallType'] as int;
    }
    if (prefs.containsKey('timezone')) {
      state.selectedTimeZone = prefs['timezone'] as String;
    }
    if (prefs.containsKey('oneKeyClose')) {
      state.oneKeyClose = prefs['oneKeyClose'] as bool;
    }
  }

  void updateRiseAndFallType(int type) {
    state = state.copyWith(riseAndFallType: type);
  }

  void updateOneKeyClose(bool value) {
    state = state.copyWith(oneKeyClose: value);
  }

  void updateProfitOn(bool value) {
    state = state.copyWith(profitOn: value);
  }

  void updateStopLossOn(bool value) {
    state = state.copyWith(stopLossOn: value);
  }

  void updateSelectedTimeZone(String tz) {
    state = state.copyWith(selectedTimeZone: tz);
  }

  /// 恢复登录态（冷启动）
  Future<bool> restoreLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final token = prefs.getString('token');
    final refreshToken = prefs.getString('refresh_token') ?? '';
    final expAt = prefs.getDouble('exp_at') ?? 0;
    final wasLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (userId != null &&
        token != null &&
        userId.isNotEmpty &&
        token.isNotEmpty) {
      if (userId.toLowerCase().contains('anonymous')) {
        await establishAnonymousSession({'user_id': userId, 'token': token});
        return false;
      }
      if (wasLoggedIn) {
        state = state.copyWith(
          isLogin: true,
          userId: userId,
          token: token,
          refreshToken: refreshToken,
          tokenExpiresAt: expAt,
        );
        await restoreLocalPreferences();
        return true;
      }
      await establishAnonymousSession({'user_id': userId, 'token': token});
      return false;
    }
    await restoreLocalPreferences(includeTransactionAccount: false);
    return false;
  }

  /// 合并用户等级变更状态（对齐 iOS `requestGetLevelChangeStatus` → data）
  void mergeLevelChangeStatus(Map<String, dynamic> data) {
    final idRaw = data['pending_change_level_id'];
    final dir = data['pending_change_level_direction']?.toString() ?? '';
    var lid = 0;
    if (idRaw is num) {
      lid = idRaw.toInt();
    } else if (idRaw != null) {
      lid = int.tryParse(idRaw.toString()) ?? 0;
    }
    state = state.copyWith(
      pendingChangeLevelId: lid,
      pendingChangeLevelDirection: dir,
    );
  }

  /// 合并 `/api/copytrading/is_signal_provider` 等与跟单身份相关的布尔（对齐账户管理交易员招募判定）
  ///
  /// [isTakeExam] 语义：**已进入考试/报名流程或已通过考试** 时为 true → 账户管理不再弹交易员招募下层。
  void mergeSignalProviderExamFlags(Map<String, dynamic> raw) {
    dynamic d = raw['data'];
    if (d is! Map<String, dynamic>) {
      if (raw['is_signal_provider'] != null ||
          raw['is_take_exam'] != null ||
          raw['take_exam'] != null ||
          raw['need_trader_exam'] != null ||
          raw['need_trader_recruit_pop'] != null) {
        d = raw;
      } else {
        return;
      }
    }
    final m = Map<String, dynamic>.from(d);

    final hasSpKey =
        m.containsKey('is_signal_provider') ||
        m.containsKey('signal_provider') ||
        m.containsKey('isSignalProvider');
    final sp = hasSpKey
        ? UserState.parseApiBool(
            m['is_signal_provider'] ??
                m['signal_provider'] ??
                m['isSignalProvider'],
          )
        : state.isSignalProvider;

    final hasTakeKey =
        m.containsKey('is_take_exam') ||
        m.containsKey('take_exam') ||
        m.containsKey('has_take_exam') ||
        m.containsKey('isTakeExam');
    final hasDoneKey =
        m.containsKey('trader_exam_passed') ||
        m.containsKey('exam_finished') ||
        m.containsKey('exam_passed') ||
        m.containsKey('examPass');
    final hasNeedKey =
        m.containsKey('need_trader_recruit_pop') ||
        m.containsKey('need_trader_exam') ||
        m.containsKey('need_take_exam');

    final enrolled = hasTakeKey
        ? UserState.parseApiBool(
            m['is_take_exam'] ??
                m['take_exam'] ??
                m['has_take_exam'] ??
                m['isTakeExam'],
          )
        : false;
    final done = hasDoneKey
        ? UserState.parseApiBool(
            m['trader_exam_passed'] ??
                m['exam_finished'] ??
                m['exam_passed'] ??
                m['examPass'],
          )
        : false;
    final needExam = hasNeedKey
        ? UserState.parseApiBool(
            m['need_trader_recruit_pop'] ??
                m['need_trader_exam'] ??
                m['need_take_exam'],
          )
        : false;

    bool nextTake = state.isTakeExam;
    if (enrolled || done) {
      nextTake = true;
    } else if (needExam) {
      nextTake = false;
    }

    state = state.copyWith(isSignalProvider: sp, isTakeExam: nextTake);
  }

  /// 合并 `violet/api/user/info` 的 data（字段见 iOS `STUserInfoModel`）
  void mergeUserInfoApi(Map<String, dynamic> data) {
    final idStr = UserState.pickString(data, ['id']);
    int? idStat;
    final rawId = data['identity_status'];
    if (rawId is num) {
      idStat = rawId.toInt();
    } else if (rawId != null) {
      idStat = int.tryParse(rawId.toString());
    }

    final needPwd = data.containsKey('need_update_password')
        ? UserState.parseApiBool(data['need_update_password'])
        : null;
    final nickname = UserState.pickString(data, [
      'nickName',
      'nickname',
      'name',
      'user_name',
      'userName',
    ]);
    final avatar = UserState.pickString(data, [
      'avatar',
      'avatar_url',
      'head_img',
      'headImg',
      'head_url',
      'portrait',
      'photo',
    ]);

    final riseRaw = UserState.pickString(data, [
      'rise_and_fall_type',
      'riseAndFallType',
    ]);
    final tz = UserState.pickString(data, [
      'timezone',
      'time_zone',
      'selected_timezone',
      'user_timezone',
    ]);
    final phone = UserState.pickString(data, [
      'tel',
      'tel_phone',
      'mobile',
      'phone',
      'telphone',
    ]);
    final phoneAreaCode = UserState.pickString(data, [
      'tel_area_code',
      'telAreaCode',
      'area_code',
      'areaCode',
    ]);
    final email = UserState.pickString(data, ['email', 'mail']);
    final hasOk =
        data.containsKey('one_key_close') || data.containsKey('oneKeyClose');
    final userFundsPassword = data.containsKey('funds_password_status')
        ? UserState.parseApiBoolOrNull(data['funds_password_status'])
        : null;
    final userBankCard = data.containsKey('bank_card_status')
        ? UserState.parseApiBoolOrNull(data['bank_card_status'])
        : null;
    final userEWallet = data.containsKey('wallet_binding_status')
        ? UserState.parseApiBoolOrNull(data['wallet_binding_status'])
        : null;
    final userPhone = data.containsKey('tel_bind_status')
        ? UserState.parseApiBoolOrNull(data['tel_bind_status'])
        : null;
    final userEmail = data.containsKey('email_bind_status')
        ? UserState.parseApiBoolOrNull(data['email_bind_status'])
        : null;

    state = state.copyWith(
      userId: (idStr != null && idStr.isNotEmpty) ? idStr : state.userId,
      nickname: (nickname != null && nickname.isNotEmpty)
          ? nickname
          : state.nickname,
      avatarUrl: (avatar != null && avatar.isNotEmpty)
          ? avatar
          : state.avatarUrl,
      phone: (phone != null && phone.isNotEmpty) ? phone : state.phone,
      phoneAreaCode: (phoneAreaCode != null && phoneAreaCode.isNotEmpty)
          ? phoneAreaCode
          : state.phoneAreaCode,
      email: (email != null && email.isNotEmpty) ? email : state.email,
      riseAndFallType: riseRaw != null && riseRaw.isNotEmpty
          ? RiseAndFallApi.fromApiValue(riseRaw)
          : state.riseAndFallType,
      selectedTimeZone: (tz != null && tz.isNotEmpty)
          ? tz
          : state.selectedTimeZone,
      oneKeyClose: hasOk
          ? UserState.parseApiBool(data['one_key_close'] ?? data['oneKeyClose'])
          : state.oneKeyClose,
      isBindFundPassword: userFundsPassword ?? state.isBindFundPassword,
      isBindBankCard: userBankCard ?? state.isBindBankCard,
      isBindEWallet: userEWallet ?? state.isBindEWallet,
      isBindPhone: userPhone ?? state.isBindPhone,
      isBindEmail: userEmail ?? state.isBindEmail,
      isAuthed: idStat != null ? (idStat == 2) : state.isAuthed,
      needUpdatePassword: needPwd ?? state.needUpdatePassword,
    );
  }

  /// 对齐 iOS `requestGetUserInfoWithCompletion`：登录后拉取 user/info。
  Future<void> refreshProfileAfterLogin(STService service) async {
    try {
      final raw = await service.getUserProfile();
      final code = raw['code'];
      if (code is num && code != 0) return;
      final d = raw['data'];
      if (d is Map<String, dynamic>) {
        mergeUserInfoApi(d);
        CardTool.setRiseAndFallType(state.riseAndFallType);
        await UserPreferencePrefs.mergeFromLoginPayload(d);
      }
    } catch (_) {}
  }

  /// 修改登录密码成功后清除「需强制改密」标记（对齐 iOS 改密完成）。
  void clearNeedUpdatePasswordFlag() {
    state = state.copyWith(needUpdatePassword: false);
  }

  /// 对齐 iOS `STRootViewController.loginPreSuccess`：
  /// auth → verification_config → level/change_status → wallet_list
  /// 弱网下串行会叠加多次超时，改为并行以缩短停留在启动页的时间。
  Future<void> bootstrapLoggedInSession(STService st) async {
    void logPreloadFailure(String name) {
      debugPrint('⚠️ $name failed');
    }

    Future<void> auth() async {
      try {
        final authRaw = await st.getAuthStatus();
        final source = _authStatusSourceFromResponse(authRaw);
        if (source != null) {
          updateAuthStatus(AuthStatusModel.fromJson(source));
        }
      } catch (e) {
        logPreloadFailure('getAuthStatus');
      }
    }

    Future<void> verification() async {
      try {
        final rawList = await st.getVerificationConfig();
        final config = rawList
            .whereType<Map<String, dynamic>>()
            .map(STVerificationModel.fromJson)
            .toList();
        updateVerificationConfig(config);
      } catch (e) {
        logPreloadFailure('getVerificationConfig');
      }
    }

    Future<void> level() async {
      try {
        final raw = await st.getLevelChangeStatus();
        final code = raw['code'];
        if (code is num && code == 0) {
          final data = raw['data'];
          if (data is Map<String, dynamic>) {
            mergeLevelChangeStatus(data);
          }
        }
      } catch (e) {
        logPreloadFailure('getLevelChangeStatus');
      }
    }

    Future<void> wallet() async {
      try {
        updateWalletInfo(await st.getWalletInfo());
      } catch (e) {
        logPreloadFailure('getWalletList');
      }
    }

    await Future.wait([auth(), verification(), level(), wallet()]);
  }

  Map<String, dynamic>? _authStatusSourceFromResponse(
    Map<String, dynamic> raw,
  ) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    if (data is Map) return Map<String, dynamic>.from(data);
    if (raw.containsKey('identity_status') ||
        raw.containsKey('identityStatus') ||
        raw.containsKey('status')) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }
}
