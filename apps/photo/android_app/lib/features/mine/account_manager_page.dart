import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/event_bus.dart';
import '../../core/router/route_observer.dart';
import '../../core/services/wallet_action_handler.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/network/st_error_messages.dart';
import '../../shared/widgets/mine_finance_theme.dart';
import '../../shared/widgets/st_toast.dart';
import 'deposit_guide_dialog.dart' as deposit_guide;

/// 账户管理
/// UI 对齐 Figma：实盘（当前/激活）/ 模拟（重置）/ 交易员（切换、初级徽章）及若干确认弹窗
class AccountManagerPage extends ConsumerStatefulWidget {
  const AccountManagerPage({super.key});

  @override
  ConsumerState<AccountManagerPage> createState() => _AccountManagerPageState();
}

enum _AcctKind { real, trial, demo, trader, option }

class _AccountManagerText {
  const _AccountManagerText([this.localized = const {}]);

  static const Map<String, String> fallbackText = {
    'account_manage': '账户管理',
    'account': '账号',
    'balance': '余额',
    'account_equity': '净值',
    'currency_type': '货币类型',
    'status': '状态',
    'current_account': '当前账户',
    'switch_account': '切换',
    'deposit': '入金',
    'active_account': '激活账户',
    'reset_account': '重置模拟账户',
    'go_to_the_exam': '去考试',
    'promotion_level': '提升等级',
    'to_trade': '去交易',
    'retest': '再次挑战',
    'replicating_success': '已复制',
    'load_failed': '加载失败',
    'switch_success': '切换账户成功',
    'switch_failed': '切换失败',
    'reset_account_success': '重置模拟账户成功',
    'reset_account_failed': '重置模拟账户失败',
    'real_account_title': '真实账户',
    'simulation_account': '模拟账户',
    'binary_options_account': '二元期权账户',
    'trader_account': '交易员',
    'normal': '正常',
    'disable': '禁用',
    'deregistered': '已注销',
    'blacklist': '黑名单',
    'unknown_status': '未知',
    'to_be_activated': '待激活',
    'not_started': '未开始',
    'in_progress': '进行中',
    'passed': '通过',
    'failed': '未通过',
    'fail_the_exam': '未通过考试',
    'fail_the_exam_sec': '失败原因',
    'reason': '原因',
    'i_know': '知道了',
    'restart_exam': '重新考试',
    'alarm': '警告',
    'reset_account_tip': '重置账户功能将对账户恢复到初始状态，清空交易记录并重置账户初始资金，确定继续吗？',
    'operation_switch_trader': '当前操作需要切换至交易员账号，是否继续',
    'switch_now': '立即切换',
    'not_switch_now': '暂不切换',
    'cancel': '取消',
    'certain': '确定',
  };

  final Map<String, String> localized;

  String _t(String key) => localized[key] ?? fallbackText[key] ?? key;

  String get accountManage => _t('account_manage');
  String get account => _t('account');
  String get balance => _t('balance');
  String get accountEquity => _t('account_equity');
  String get currencyType => _t('currency_type');
  String get status => _t('status');
  String get currentAccount => _t('current_account');
  String get switchAccount => _t('switch_account');
  String get deposit => _t('deposit');
  String get activeAccount => _t('active_account');
  String get resetAccount => _t('reset_account');
  String get goToTheExam => _t('go_to_the_exam');
  String get promotionLevel => _t('promotion_level');
  String get toTrade => _t('to_trade');
  String get retest => _t('retest');
  String get replicatingSuccess => _t('replicating_success');
  String get loadFailed => _t('load_failed');
  String get switchSuccess => _t('switch_success');
  String get switchFailed => _t('switch_failed');
  String get resetAccountSuccess => _t('reset_account_success');
  String get resetAccountFailed => _t('reset_account_failed');
  String get realAccount => _t('real_account_title');
  String get trialAccount => realAccount;
  String get demoAccount => _t('simulation_account');
  String get traderAccount => _t('trader_account');
  String get optionAccount => _t('binary_options_account');
  String get normalStatus => _t('normal');
  String get disabledStatus => _t('disable');
  String get cancelledStatus => _t('deregistered');
  String get blacklistStatus => _t('blacklist');
  String get unknownStatus => _t('unknown_status');
  String get toBeActivated => _t('to_be_activated');
  String get notStarted => _t('not_started');
  String get inProgress => _t('in_progress');
  String get passed => _t('passed');
  String get failed => _t('failed');
  String get failTheExam => _t('fail_the_exam');
  String get failTheExamSec => _t('fail_the_exam_sec');
  String get reason => _t('reason');
  String get iKnow => _t('i_know');
  String get restartExam => _t('restart_exam');
  String get warning => _t('alarm');
  String get resetAccountWarning => _t('reset_account_tip');
  String get operationSwitchTrader => _t('operation_switch_trader');
  String get switchNow => _t('switch_now');
  String get notSwitchNow => _t('not_switch_now');
  String get cancel => _t('cancel');
  String get confirm => _t('certain');
}

/// 与 iOS `STAccountType` 行为一致：`0` 实盘、`4` 体验金、`1` 模拟、`3` 交易员。
_AcctKind _accountKindFromApi(String type, String accountTypeName) {
  final lower = accountTypeName.toLowerCase();
  if (type == '1' || lower.contains('模拟') || lower.contains('demo')) {
    return _AcctKind.demo;
  }
  if (type == '2' || lower.contains('二元') || lower.contains('binary')) {
    return _AcctKind.option;
  }
  if (type == '0') {
    return _AcctKind.real;
  }
  if (type == '4') {
    return _AcctKind.trial;
  }
  if (type == '3' || lower.contains('交易员') || lower.contains('trader')) {
    return _AcctKind.trader;
  }
  return _AcctKind.option;
}

class _ParsedAcct {
  _ParsedAcct({
    required this.model,
    required this.accountId,
    required this.kind,
    required this.currency,
    required this.displayBalance,
    required this.equityLine,
    required this.transStatus,
    required this.transTipReason,
    required this.isActive,
    required this.isInactive,
    required this.status,
    required this.platform,
    required this.traderBadge,
    required this.rawBalance,
    required this.rawEquity,
  });

  final STAccountModel model;
  final String accountId;
  final _AcctKind kind;
  final String currency;
  final String displayBalance;
  final String equityLine;
  final int transStatus;
  final String transTipReason;
  final bool isActive;
  final bool isInactive;
  final int status;
  final String platform;
  final String? traderBadge;
  final String rawBalance;
  final String rawEquity;

  String get apiType => model.type;
  bool get showDemoReset => kind == _AcctKind.demo;
  bool get hasTransHelp => transTipReason.isNotEmpty;

  String title(_AccountManagerText text) => switch (kind) {
    _AcctKind.demo => text.demoAccount,
    _AcctKind.trader => text.traderAccount,
    _AcctKind.real => text.realAccount,
    _AcctKind.trial => text.trialAccount,
    _AcctKind.option => text.optionAccount,
  };

  String statusLabel(_AccountManagerText text) {
    if (kind == _AcctKind.trader) {
      return _traderStatusFromModel(transStatus, text);
    }
    if (isInactive) return text.toBeActivated;
    return _accountStatusFromModel(status, text);
  }

  String traderActionLabel(_AccountManagerText text) =>
      _traderActionFromModel(status, text);

  String? bottomActionLabel({
    required bool isCurrent,
    required _AccountManagerText text,
  }) => switch (kind) {
    _AcctKind.demo => text.resetAccount,
    _AcctKind.trader => traderActionLabel(text),
    _AcctKind.real => text.deposit,
    _AcctKind.trial when isCurrent && needsActivationCTA => text.activeAccount,
    _ => null,
  };

  static String _fmtMoneyField(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '--';
    return CardTool.formatBalanceAmount(t.replaceAll(',', ''));
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _traderStatusFromModel(int status, _AccountManagerText text) {
    switch (status) {
      case 0:
        return text.notStarted;
      case 1:
        return text.inProgress;
      case 2:
        return text.passed;
      case 3:
        return text.failed;
      default:
        return text.unknownStatus;
    }
  }

  static String _accountStatusFromModel(int status, _AccountManagerText text) {
    switch (status) {
      case 0:
        return text.normalStatus;
      case 1:
        return text.disabledStatus;
      case 2:
        return text.cancelledStatus;
      case 3:
        return text.blacklistStatus;
      default:
        return text.unknownStatus;
    }
  }

  static String _traderActionFromModel(int status, _AccountManagerText text) {
    switch (status) {
      case 0:
        return text.goToTheExam;
      case 1:
        return text.promotionLevel;
      case 2:
        return text.toTrade;
      case 3:
        return text.retest;
      default:
        return '';
    }
  }

  factory _ParsedAcct.fromRaw(Map<String, dynamic> json) {
    final m = STAccountModel.fromJson(json);
    final parsedAccountId =
        UserState.pickString(json, ['account_id', 'accountId', 'id']) ??
        m.accountId;
    final kind = _accountKindFromApi(m.type, m.accountType);
    final transStatus = _toInt(m.transStatus);
    final isActive = UserState.parseApiBool(m.isActive);
    final status = _toInt(m.status);
    final isActiveTag =
        UserState.pickString(json, [
          'is_active',
          'isActive',
          'is_active_status',
        ]) ??
        m.isActive;

    final cur =
        UserState.pickString(json, [
          'currency',
          'wallet_currency',
          'walletCurrency',
        ]) ??
        'USD';

    final bal = _fmtMoneyField(m.balance);
    final eqRaw = m.equity.trim();
    final eqLine = _fmtMoneyField(eqRaw);

    final plat = json['platform']?.toString().trim() ?? '';

    final activeText = isActiveTag.trim().toLowerCase();
    final isInactive =
        activeText == '0' ||
        activeText == 'false' ||
        activeText == 'inactive' ||
        activeText == 'pending';

    final badgeRaw = UserState.pickString(json, [
      'trader_level_name',
      'traderLevelName',
      'level_name',
      'grade_name',
    ]);

    return _ParsedAcct(
      model: m,
      accountId: parsedAccountId,
      kind: kind,
      currency: cur,
      displayBalance: bal,
      equityLine: eqLine,
      transStatus: transStatus,
      transTipReason:
          UserState.pickString(json, ['trans_tip_reason', 'transTipReason']) ??
          m.transTipReason,
      isActive: isActive,
      isInactive: isInactive,
      status: status,
      platform: plat,
      rawBalance: m.balance,
      rawEquity: m.equity,
      traderBadge: (kind == _AcctKind.trader && (badgeRaw?.isNotEmpty ?? false))
          ? badgeRaw
          : null,
    );
  }

  bool get needsActivationCTA =>
      kind == _AcctKind.trial && (isInactive || !isActive);
}

class _AccountManagerPageState extends ConsumerState<AccountManagerPage>
    with RouteAware {
  static const String _depositRoute = '/mine/deposit';

  List<_ParsedAcct> _items = [];
  bool _busy = false;
  bool _routeSubscribed = false;
  String? _languageCode;
  int _languageLoadToken = 0;
  _AccountManagerText _text = const _AccountManagerText();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  void _loadLocalizedTextsIfNeeded() {
    final localizations = ref.read(stLocalizationsProvider);
    if (_languageCode == localizations.languageCode) return;
    _languageCode = localizations.languageCode;

    final token = ++_languageLoadToken;
    localizations.textMap(_AccountManagerText.fallbackText).then((value) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _text = _AccountManagerText(value));
    });
  }

  @override
  void didPopNext() {
    _load();
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _openDeposit() async {
    await ref
        .read(walletActionHandlerProvider)
        .handleWalletAction(
          context: context,
          action: 'deposit',
          onPassed: () => context.push(_depositRoute),
        );
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final list = await ref.read(stServiceProvider).getTradeAccounts();
      final next = list
          .map((e) {
            if (e is Map<String, dynamic>) {
              return _ParsedAcct.fromRaw(e);
            }
            if (e is Map) {
              return _ParsedAcct.fromRaw(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<_ParsedAcct>()
          .toList();

      if (mounted) setState(() => _items = next);
    } catch (e) {
      if (mounted) {
        STToast.show(
          context,
          '${_text.loadFailed}: ${stUserVisibleErrorMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchTo(_ParsedAcct acct) async {
    if (acct.kind == _AcctKind.trader && acct.transStatus == 0) {
      final go = await _showTraderConfirmDialog(context, _text);
      if (go != true) return;
      _openTraderMiddlePage();
      return;
    }
    await _postSwitch(acct);
  }

  bool _currentUserIsInactiveReal(UserState user) {
    final active = user.transactionAccountIsActive.trim().toLowerCase();
    return user.transactionAccountType == '0' &&
        (active == '0' || active == 'false');
  }

  Future<void> _postSwitch(_ParsedAcct acct) async {
    if (acct.accountId.isEmpty) return;
    try {
      final status = _ParsedAcct._toInt(acct.status);
      final payload = {
        'account': {
          'id': _ParsedAcct._toInt(acct.accountId),
          'platform': acct.platform,
          'balance': acct.rawBalance,
          'equity': acct.rawEquity,
          'currency': acct.currency,
          'status': status,
          'type': _ParsedAcct._toInt(acct.apiType),
        },
        'app_id': 1,
        'platform': 'mobile',
        'login_type': 0,
      };
      final service = ref.read(stServiceProvider);
      final res = await service.switchTradeAccount(payload);
      final userNotifier = ref.read(userStateProvider.notifier);
      await userNotifier.applyChangeAccountSuccessPayload(service, res);
      await userNotifier.refreshProfileAfterLogin(service);
      EventBus().emit(EventBus.accountChanged);
      final shouldShowDepositGuide = _currentUserIsInactiveReal(
        ref.read(userStateProvider),
      );
      if (mounted) {
        STToast.show(context, _text.switchSuccess);
      }
      await _load();
      if (mounted && shouldShowDepositGuide) {
        await _showDepositGuideDialog(context);
      }
    } catch (e) {
      if (mounted) {
        STToast.show(
          context,
          '${_text.switchFailed}: ${stUserVisibleErrorMessage(e)}',
        );
      }
    }
  }

  Future<void> _openTraderMiddlePage() async {
    if (!mounted) return;
    final user = ref.read(userStateProvider);
    var examMid = user.h5AddressModel?.traderExamMiddlePageUrl ?? '';
    if (examMid.isEmpty) {
      examMid = ref
          .read(configDataManagerProvider)
          .h5Url('trader_exam_middle_page_url');
    }
    if (examMid.trim().isEmpty) return;

    final uri = Uri(path: '/mini', queryParameters: {'link': examMid});
    await context.push(uri.toString());
  }

  Future<void> _copy(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      STToast.show(context, _text.replicatingSuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(userStateProvider).transactionAccount;
    final text = _text;

    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: MineFinanceTheme.textPrimary(context),
        elevation: 0,
        title: Text(
          text.accountManage,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: MineFinanceTheme.textPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: _busy && _items.isEmpty
          ? const Center(child: STLoadAnimationView())
          : ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 32),
              itemCount: _items.length + 1,
              itemBuilder: (context, i) {
                if (i == _items.length) {
                  return const SizedBox(height: 12);
                }
                final item = _items[i];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == _items.length - 1 ? 0 : 12,
                  ),
                  child: _AccountCardFig(
                    data: item,
                    text: text,
                    isCurrent:
                        item.accountId.isNotEmpty &&
                        item.accountId == currentId,
                    onCopy: () => _copy(item.accountId),
                    onSwitch: () => _switchTo(item),
                    onActivate: () => unawaited(_openDeposit()),
                    onTraderAction: () => _openTraderMiddlePage(),
                    onTraderHelp: item.hasTransHelp
                        ? () => unawaited(
                            _showTraderFailDialog(
                              context,
                              text,
                              item.transTipReason,
                              () => unawaited(_openTraderMiddlePage()),
                            ),
                          )
                        : null,
                    onResetDemo: () => unawaited(
                      _showResetDemoConfirmDialog(context, text, () async {
                        try {
                          await ref.read(stServiceProvider).resetTradeAccount();
                          if (context.mounted) {
                            STToast.show(context, text.resetAccountSuccess);
                            await _load();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            STToast.show(
                              context,
                              '${text.resetAccountFailed}: ${stUserVisibleErrorMessage(e)}',
                            );
                          }
                        }
                      }),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _AccountCardFig extends StatelessWidget {
  const _AccountCardFig({
    required this.data,
    required this.text,
    required this.isCurrent,
    required this.onCopy,
    required this.onSwitch,
    required this.onActivate,
    required this.onTraderAction,
    required this.onTraderHelp,
    required this.onResetDemo,
  });

  final _ParsedAcct data;
  final _AccountManagerText text;
  final bool isCurrent;
  final VoidCallback onCopy;
  final VoidCallback onSwitch;
  final VoidCallback onActivate;
  final VoidCallback onTraderAction;
  final VoidCallback? onTraderHelp;
  final VoidCallback onResetDemo;

  @override
  Widget build(BuildContext context) {
    final titleColor = context.adaptiveTextPrimary;
    final labelColor = context.adaptiveTextTertiary;
    final dividerColor = context.adaptiveDivider;

    Widget trailing;
    if (isCurrent) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text.currentAccount,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF4DCB73),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.check_circle, size: 20, color: Color(0xFF4DCB73)),
        ],
      );
    } else {
      trailing = GestureDetector(
        onTap: onSwitch,
        behavior: HitTestBehavior.opaque,
        child: _BlackPill(
          label: text.switchAccount,
          icon: Icons.swap_vert_rounded,
        ),
      );
    }

    // Figma 2175:74934 / 75307：半透白头区 + 白底内容上移叠压；实盘当前账户加 #707070 描边
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: isCurrent
            ? Border.all(color: const Color(0xFF707070), width: 1)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: context.adaptiveCard.withValues(alpha: 0.50),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 12, 12),
                child: Row(
                  children: [
                    _LeadingIcon(kind: data.kind, apiType: data.apiType),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              data.title(text),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: titleColor,
                              ),
                            ),
                          ),
                          if (data.kind == _AcctKind.trader &&
                              data.traderBadge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              height: 14,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 0,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: labelColor),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                data.traderBadge!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                  color: labelColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing,
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.adaptiveCard,
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kv(
                          context,
                          text.account,
                          data.accountId,
                          onCopy,
                          topPad: 0,
                        ),
                        _kv(context, text.balance, data.displayBalance, null),
                        _kv(context, text.accountEquity, data.equityLine, null),
                        _kv(context, text.currencyType, data.currency, null),
                        _kvRow(
                          context,
                          text.status,
                          data.statusLabel(text),
                          showHelp:
                              data.kind == _AcctKind.trader &&
                              data.hasTransHelp,
                          onHelp: onTraderHelp,
                        ),
                        if (data.kind == _AcctKind.trader &&
                            data.traderActionLabel(text).isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: onTraderAction,
                              child: Text(
                                data.traderActionLabel(text),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF00B57A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                        if (data.bottomActionLabel(
                                  isCurrent: isCurrent,
                                  text: text,
                                ) !=
                                null &&
                            (data.kind == _AcctKind.real ||
                                data.kind == _AcctKind.trial)) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: onActivate,
                              child: Text(
                                data.bottomActionLabel(
                                  isCurrent: isCurrent,
                                  text: text,
                                )!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF00B57A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                        if (data.kind == _AcctKind.demo)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: GestureDetector(
                              onTap: onResetDemo,
                              child: Text(
                                text.resetAccount,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4DCB73),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(
    BuildContext context,
    String k,
    String v,
    VoidCallback? onCopy, {
    double topPad = 6,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Row(
        children: [
          Text(
            k,
            style: TextStyle(fontSize: 14, color: context.adaptiveTextTertiary),
          ),
          const Spacer(),
          Text(
            v,
            style: TextStyle(fontSize: 14, color: context.adaptiveTextPrimary),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: context.adaptiveTextTertiary,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _kvRow(
    BuildContext context,
    String k,
    String v, {
    required bool showHelp,
    VoidCallback? onHelp,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Text(
            k,
            style: TextStyle(fontSize: 14, color: context.adaptiveTextTertiary),
          ),
          if (showHelp) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onHelp,
              child: Icon(
                Icons.help_outline,
                size: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
          const Spacer(),
          Text(
            v,
            style: TextStyle(fontSize: 14, color: context.adaptiveTextPrimary),
          ),
        ],
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.kind, required this.apiType});

  final _AcctKind kind;
  final String apiType;

  @override
  Widget build(BuildContext context) {
    if (apiType == '2') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_outline_rounded,
          color: Colors.white,
          size: 18,
        ),
      );
    }
    Color bg;
    IconData ic;
    switch (kind) {
      case _AcctKind.real:
      case _AcctKind.trial:
        bg = const Color(0xFF00B57A);
        ic = Icons.account_balance_wallet_rounded;
      case _AcctKind.demo:
        bg = const Color(0xFFFF9500);
        ic = Icons.show_chart_rounded;
      case _AcctKind.option:
        bg = const Color(0xFFB0B0B8);
        ic = Icons.candlestick_chart_rounded;
      case _AcctKind.trader:
        bg = const Color(0xFF4DCB73);
        ic = Icons.person_rounded;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(ic, color: Colors.white, size: 18),
        ),
        if (kind == _AcctKind.real)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade500,
              ),
              child: Icon(Icons.check, size: 8, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _BlackPill extends StatelessWidget {
  const _BlackPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(width: 2),
          Icon(icon, size: 13, color: Colors.white),
        ],
      ),
    );
  }
}

Future<void> _showTraderFailDialog(
  BuildContext ctx,
  _AccountManagerText text,
  String reason,
  VoidCallback onRetry,
) {
  return showDialog<void>(
    context: ctx,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogCtx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 298,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text.failTheExam,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${text.failTheExamSec}：$reason',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.43,
                color: Color(0xFF60656D),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 115,
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B57A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(text.restartExam),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                text.iKnow,
                style: const TextStyle(fontSize: 14, color: Color(0xFF9A9DA2)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> _showTraderConfirmDialog(
  BuildContext ctx,
  _AccountManagerText text,
) {
  return showDialog<bool>(
    context: ctx,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogCtx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 298,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFB8D9FF),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  Positioned(
                    right: 58,
                    top: 8,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Positioned(
                    right: 62,
                    bottom: 26,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4DCB73),
                      ),
                      child: const Icon(
                        Icons.swap_vert,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              text.operationSwitchTrader,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.43,
                color: Color(0xFF60656D),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 115,
              height: 36,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B57A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(text.switchNow),
              ),
            ),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9A9DA2),
                ),
                child: Text(
                  text.notSwitchNow,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showResetDemoConfirmDialog(
  BuildContext ctx,
  _AccountManagerText text,
  Future<void> Function() onConfirm,
) async {
  final ok = await showDialog<bool>(
    context: ctx,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (d) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 273,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                children: [
                  Text(
                    text.warning,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2E3330),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text.resetAccountWarning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: Text(
                        text.cancel,
                        style: const TextStyle(
                          color: Color(0xFF949494),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFFE5E5E5),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: Text(
                        text.confirm,
                        style: const TextStyle(
                          color: Color(0xFF00B57A),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (ok == true && ctx.mounted) {
    await onConfirm();
  }
}

Future<void> _showDepositGuideDialog(BuildContext ctx) async {
  final result = await deposit_guide.showDepositGuideDialog(context: ctx);
  if (result == true && ctx.mounted) {
    final container = ProviderScope.containerOf(ctx, listen: false);
    final rootContext = STToast.navigatorKey.currentContext ?? ctx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        container
            .read(walletActionHandlerProvider)
            .handleWalletAction(
              context: rootContext,
              action: 'deposit',
              onPassed: () {
                if (rootContext.mounted) {
                  rootContext.push('/mine/deposit');
                }
              },
            ),
      );
    });
  }
}
