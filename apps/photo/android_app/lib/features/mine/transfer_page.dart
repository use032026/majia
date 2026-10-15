import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/crypto/st_hmac_sha256.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/services/wallet_action_handler.dart';
import '../../core/services/wallet_deposit_withdraw_contract.dart';
import '../../shared/auth/fund_password_verify_dialog.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_toast.dart';
import '../activity/activity_popups.dart';
import 'wallet_deposit_native_layout.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferText {
  const _TransferText._();

  static final Map<String, String> fallbackText = Map.unmodifiable({
    'transfer': stLocalizedTextFromZhHans('资金划转'),
    'transfer_from': stLocalizedTextFromZhHans('从'),
    'transfer_to': stLocalizedTextFromZhHans('到'),
    'transfer_sum': stLocalizedTextFromZhHans('划转金额'),
    'transfer_input_tip': stLocalizedTextFromZhHans('请输入划转金额'),
    'transfer_success': stLocalizedTextFromZhHans('划转成功'),
    'transfer_time': stLocalizedTextFromZhHans('划转时间'),
    'available': stLocalizedTextFromZhHans('可用余额'),
    'all': stLocalizedTextFromZhHans('全部'),
    'reference_exchange_rate': stLocalizedTextFromZhHans('参考汇率：'),
    'single_amount_range': stLocalizedTextFromZhHans('单笔金额范围：'),
    'my_wallet': stLocalizedTextFromZhHans('我的钱包'),
    'real_account': stLocalizedTextFromZhHans('真实账户'),
    'simulation_account': stLocalizedTextFromZhHans('模拟账户'),
    'binary_options_account': stLocalizedTextFromZhHans('期权账户'),
    'trader_account': stLocalizedTextFromZhHans('交易员账户'),
    'account': stLocalizedTextFromZhHans('账号'),
    'flutter_prompt_load_accounts_failed': stLocalizedTextFromZhHans('加载账户失败'),
    'flutter_prompt_transfer_select_accounts': stLocalizedTextFromZhHans(
      '请选择转出与转入账户',
    ),
    'flutter_prompt_transfer_amount_too_high': stLocalizedTextFromZhHans(
      '请不要输入大于可用余额的金额',
    ),
    'flutter_prompt_transfer_margin_exceeded': stLocalizedTextFromZhHans(
      '出金金额已超出可用保证金的90%，无法出金。如有疑问请联系客服。',
    ),
    'flutter_prompt_transfer_simulation_forbidden': stLocalizedTextFromZhHans(
      '模拟账号不能划转',
    ),
    'flutter_prompt_transfer_same_account': stLocalizedTextFromZhHans('账号不能相同'),
    'flutter_prompt_transfer_amount_empty': stLocalizedTextFromZhHans(
      '请输入划转金额',
    ),
    'flutter_prompt_transfer_settle_success': stLocalizedTextFromZhHans('结算成功'),
    'system_busy': stLocalizedTextFromZhHans('系统繁忙，请稍后再试'),
    'tranfer_success_from': stLocalizedTextFromZhHans('转出账户'),
    'tranfer_success_to': stLocalizedTextFromZhHans('转入账户'),
    'flow_no': stLocalizedTextFromZhHans('流水号'),
    'top_up_time': stLocalizedTextFromZhHans('入金时间'),
    'flutter_transfer_rate_tip': stLocalizedTextFromZhHans(
      '温馨提示：资金划转会按提交时的参考汇率折算，实际到账以系统处理结果为准。',
    ),
  });
}

class _TransferPageState extends ConsumerState<TransferPage> {
  static const String _depositRoute = '/mine/deposit';

  final _amountCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  List<_TransferAccount> _accounts = const [];
  _TransferAccount? _from;
  _TransferAccount? _to;
  _TransferRate _rate = const _TransferRate.sameCurrency();
  bool _loading = false;
  bool _submitting = false;
  String? _localizedLanguageCode;
  Map<String, String> _localized = _TransferText.fallbackText;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountCtrl.text) ?? 0;
  bool get _canSubmit =>
      !_submitting && _amount > 0 && _from != null && _to != null;

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_TransferText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _TransferText.fallbackText[key] ?? key;

  String _accountTitle(_TransferAccount? account) {
    final current = account;
    if (current == null) return '';
    if (current.isWallet) return _t('my_wallet');
    switch (current.type) {
      case 0:
      case 4:
        return _t('real_account');
      case 1:
        return _t('simulation_account');
      case 2:
        return _t('binary_options_account');
      case 3:
        return _t('trader_account');
      default:
        return current.title.isNotEmpty ? current.title : _t('account');
    }
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    final service = ref.read(stServiceProvider);
    final merged = <_TransferAccount>[];
    Object? error;

    try {
      final wallets = await service.getWalletList();
      for (final raw in wallets) {
        if (raw is Map) {
          merged.add(_TransferAccount.wallet(Map<String, dynamic>.from(raw)));
        }
      }
    } catch (e) {
      error = e;
    }

    try {
      final trades = await service.getTradeAccounts();
      for (final raw in trades) {
        if (raw is Map) {
          final account = _TransferAccount.trade(
            Map<String, dynamic>.from(raw),
          );
          if (account.isIosTransferTradeCandidate) {
            merged.add(account);
          }
        }
      }
    } catch (e) {
      error ??= e;
    }

    if (!mounted) return;
    final wallet = merged
        .where((e) => e.isWallet)
        .cast<_TransferAccount?>()
        .firstOrNull;
    final trade = merged
        .where((e) => !e.isWallet)
        .cast<_TransferAccount?>()
        .firstOrNull;
    setState(() {
      _accounts = merged;
      if (wallet != null && trade != null) {
        _from = wallet;
        _to = trade;
      } else if (merged.length >= 2) {
        _from = merged[0];
        _to = merged[1];
      } else if (merged.isNotEmpty) {
        _from = merged.first;
      }
      _loading = false;
    });
    if (merged.isEmpty && error != null) {
      showStLocalizedToastByKey(
        context,
        'flutter_prompt_load_accounts_failed',
        fallback: _t('flutter_prompt_load_accounts_failed'),
      );
    }
    await _queryRate();
  }

  Future<void> _queryRate() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    if (from.currency.isEmpty ||
        to.currency.isEmpty ||
        from.currency == to.currency) {
      if (mounted) setState(() => _rate = const _TransferRate.sameCurrency());
      return;
    }
    try {
      final response = await ref.read(stServiceProvider).getExchangeRate({
        'from_currency': from.currency,
        'form_amount': '1',
        'to_currency': to.currency,
        'type': 2,
      });
      if (!mounted) return;
      setState(() => _rate = _TransferRate.fromApi(response));
    } catch (e) {
      if (mounted) {
        setState(() => _rate = const _TransferRate.sameCurrency());
        _toast(stUserVisibleErrorMessage(e));
      }
    }
  }

  void _swapAccounts() {
    if (_from == null || _to == null) return;
    setState(() {
      final oldFrom = _from;
      _from = _to;
      _to = oldFrom;
    });
    _queryRate();
  }

  Future<void> _selectAccount(bool isFrom) async {
    if (_accounts.isEmpty) return;
    final current = isFrom ? _from : _to;
    final selected = await showModalBottomSheet<WalletFundingAccount>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (ctx) => WalletNativeAccountPickerSheet(
        accounts: _accounts
            .map(
              (account) =>
                  account.toFundingAccount(label: _accountTitle(account)),
            )
            .toList(),
        selectedKey: current?.fundingKey,
        onSelected: (account) => Navigator.of(ctx).pop(account),
      ),
    );
    if (selected == null || !mounted) return;
    final selectedAccount = _accounts.firstWhere(
      (account) => account.fundingKey == selected.key,
      orElse: () => current ?? _accounts.first,
    );
    if (selectedAccount.sameIdentity(current)) return;
    setState(() {
      if (isFrom) {
        _from = selectedAccount;
      } else {
        _to = selectedAccount;
      }
    });
    await _queryRate();
  }

  Future<void> _submitTransfer() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      _toast(_t('flutter_prompt_transfer_select_accounts'));
      return;
    }
    if (_amount > from.available) {
      _toast(_t('flutter_prompt_transfer_amount_too_high'));
      return;
    }
    if (!from.isWallet &&
        from.type == 0 &&
        _amount > from.canDraw &&
        from.marginUsed > 0) {
      _toast(_t('flutter_prompt_transfer_margin_exceeded'));
      return;
    }
    if ((!from.isWallet && from.type == 1) || (!to.isWallet && to.type == 1)) {
      _toast(_t('flutter_prompt_transfer_simulation_forbidden'));
      return;
    }
    if (!from.isWallet && from.type == 4) {
      final confirmed = await showTrialBonusTopUpDialog(
        context: context,
        mode: TrialBonusTopUpMode.recharge,
      );
      if (confirmed == true && mounted) {
        await _openDepositWithPreflight();
      }
      return;
    }
    if (!to.isWallet && to.type == 4) {
      final confirmed = await showTrialBonusTopUpDialog(
        context: context,
        mode: TrialBonusTopUpMode.transfer,
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    if (from.sameIdentity(to)) {
      _toast(_t('flutter_prompt_transfer_same_account'));
      return;
    }
    if (_amount < 0.01) {
      _toast(_t('flutter_prompt_transfer_amount_empty'));
      return;
    }

    await ref
        .read(walletActionHandlerProvider)
        .handleWalletAction(
          context: context,
          action: 'internal_transfer',
          onPassed: () {
            _continueAfterPermission(from, to);
          },
        );
  }

  Future<void> _continueAfterPermission(
    _TransferAccount from,
    _TransferAccount to,
  ) async {
    if (!from.isWallet && from.type == 0) {
      final passed = await _handleBonusSettlementIfNeeded();
      if (!passed || !mounted) return;
    }
    final fundPassword = await showFundPasswordVerifyDialog(context);
    if (fundPassword == null || fundPassword.isEmpty || !mounted) return;
    await _requestTransfer(from: from, to: to, fundPassword: fundPassword);
  }

  Future<bool> _handleBonusSettlementIfNeeded() async {
    try {
      final service = ref.read(stServiceProvider);
      final data = _responseDataMap(await service.getBonusBrief());
      final participated =
          data['is_participated'] == true ||
          data['is_participated']?.toString() == '1';
      if (!participated) return true;
      if (!mounted) return false;
      final activityId = int.tryParse('${data['activity_id'] ?? 0}') ?? 0;
      final detailAndProgress = await Future.wait([
        service.getBonusDetail(activityId),
        service.getBonusProgress(activityId),
      ]);
      if (!mounted) return false;
      final popInfo = ActivitySettlementPopInfo.fromDetailAndProgress(
        detail: _responseDataMap(detailAndProgress[0]),
        progress: _responseDataMap(detailAndProgress[1]),
      );
      if (popInfo != null) {
        final retainAction = await showActivitySettlementRetainDialog(
          context: context,
          info: popInfo,
        );
        if (!mounted) return false;
        if (retainAction == ActivitySettlementRetainAction.primary) {
          if (popInfo.isTierDesignated) {
            await _openDepositWithPreflight();
          } else {
            context.go('/trade');
          }
          return false;
        }
        if (retainAction != ActivitySettlementRetainAction.confirm) {
          return false;
        }
      }
      final confirmed = await showActivitySettlementDialog(
        context: context,
        giftedAmount: '${data['rewarded_amount'] ?? ''}',
        receiveAmount: '${data['unlocked_amount'] ?? ''}',
      );
      if (confirmed != true) return false;
      await service.settleBonus(activityId);
      if (mounted) _toast(_t('flutter_prompt_transfer_settle_success'));
      return true;
    } catch (_) {
      if (mounted) _toast(_t('system_busy'));
      return false;
    }
  }

  Future<void> _openDepositWithPreflight() async {
    await ref
        .read(walletActionHandlerProvider)
        .handleWalletAction(
          context: context,
          action: 'deposit',
          onPassed: () {
            if (mounted) context.push(_depositRoute);
          },
        );
  }

  Map<String, dynamic> _responseDataMap(Map<String, dynamic> response) {
    if (response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    return response;
  }

  Future<void> _requestTransfer({
    required _TransferAccount from,
    required _TransferAccount to,
    required String fundPassword,
  }) async {
    setState(() => _submitting = true);
    try {
      final response = await ref.read(stServiceProvider).walletTransfer({
        'from_account': int.tryParse(from.id) ?? from.id,
        'from_account_platform': from.platform,
        'to_account': int.tryParse(to.id) ?? to.id,
        'to_account_platform': to.platform,
        'amount': _amountCtrl.text,
        'funds_password': stHmacSha256Hex(fundPassword),
      });
      if (!mounted) return;
      context.push(
        '/mine/wallet/finish',
        extra: {
          'kind': 'transfer',
          'drawHeader': {
            'action': stLocalizedTextFromZhHans(''),
            'title': stLocalizedTextFromZhHans(''),
            'drawCurrency': from.currency,
            'drawNum': _fmtAmount2f(response['amount']),
            'bankStyleIcon': true,
          },
          'rows': {
            _t('tranfer_success_from'): from.maskedNameIdWithTitle(
              _accountTitle(from),
            ),
            _t('tranfer_success_to'): to.maskedNameIdWithTitle(
              _accountTitle(to),
            ),
            _t('flow_no'): '${response['order_id'] ?? ''}',
            _t('top_up_time'): _fmtOrderTime(response['order_time']),
          },
        },
      );
    } catch (e) {
      if (mounted) _toast(stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fmtAmount2f(dynamic value) {
    final number = double.tryParse('$value');
    if (number == null) return '';
    return number.toStringAsFixed(2);
  }

  String _fmtOrderTime(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed.toLocal());
      }
      final number = int.tryParse(value);
      if (number != null) return _fmtOrderTime(number);
      return value;
    }
    if (value is! num) return '$value';
    final intValue = value.toInt();
    final seconds = intValue > 2000000000 ? intValue ~/ 1000 : intValue;
    if (seconds <= 0) return '';
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal());
  }

  void _toast(String message) {
    if (mounted) STToast.show(context, stSanitizeUserVisibleText(message));
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final from = _from;
    final to = _to;
    return STKeyboardActions(
      focusNodes: [_amountFocus],
      child: Scaffold(
        backgroundColor: WalletDepositNativeColors.depositPageBackgroundOf(
          context,
        ),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: WalletDepositNativeColors.depositPageBackgroundOf(
            context,
          ),
          foregroundColor: WalletDepositNativeColors.textPrimaryOf(context),
          centerTitle: true,
          title: Text(
            _t('transfer'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 92),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 204,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: _TransferAccountCard(
                            key: const ValueKey('transfer_from_account_card'),
                            title: _t('transfer_from'),
                            account: from,
                            accountTitle: _accountTitle(from),
                            availableLabel: _t('available'),
                            onTap: () => _selectAccount(true),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 102,
                          child: _TransferAccountCard(
                            key: const ValueKey('transfer_to_account_card'),
                            title: _t('transfer_to'),
                            account: to,
                            accountTitle: _accountTitle(to),
                            availableLabel: _t('available'),
                            onTap: () => _selectAccount(false),
                          ),
                        ),
                        Positioned(
                          top: 79,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              key: const ValueKey('transfer_swap_button'),
                              onTap: _swapAccounts,
                              child: Image.asset(
                                'assets/images/st_mine_transfer_sec.png',
                                width: 46,
                                height: 46,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      _t('transfer_sum'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: WalletDepositNativeColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _TransferAmountInput(
                    controller: _amountCtrl,
                    focusNode: _amountFocus,
                    unit: from?.currency ?? '',
                    conversion: to?.currency ?? '',
                    total: from?.balance ?? '',
                    rate: _rate,
                    hintText: _t('transfer_input_tip'),
                    allText: _t('all'),
                    referenceRateText: _t('reference_exchange_rate'),
                    rangeText: _t('single_amount_range'),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: _TransferTipCard(
                      text: _t('flutter_transfer_rate_tip'),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x22FFFFFF),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(15, 0, 15, 22),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const ValueKey('transfer_submit_button'),
                    onPressed: _canSubmit ? _submitTransfer : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      disabledBackgroundColor: const Color(0x3300B57A),
                      backgroundColor: const Color(0xFF00B57A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _t('transfer'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
}

class _TransferAccountCard extends StatelessWidget {
  final String title;
  final _TransferAccount? account;
  final String accountTitle;
  final String availableLabel;
  final VoidCallback onTap;

  const _TransferAccountCard({
    super.key,
    required this.title,
    required this.account,
    required this.accountTitle,
    required this.availableLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = account;
    final tertiaryTextColor = WalletDepositNativeColors.textTertiaryOf(context);
    final secondaryTextColor = WalletDepositNativeColors.textSecondaryOf(
      context,
    );
    final primaryTextColor = WalletDepositNativeColors.textPrimaryOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Material(
        color: WalletDepositNativeColors.tileGrayOf(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 90,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 12, color: tertiaryTextColor),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AccountIcon(account: current, size: 32),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    accountTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Image.asset(
                                  'assets/images/st_mine_drop.png',
                                  width: 20,
                                  height: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              current?.maskedId ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: tertiaryTextColor,
                                fontFamily: 'Gilroy',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            availableLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            current?.balance ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryTextColor,
                              fontFamily: 'Gilroy',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferAmountInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String unit;
  final String conversion;
  final String total;
  final _TransferRate rate;
  final String hintText;
  final String allText;
  final String referenceRateText;
  final String rangeText;

  const _TransferAmountInput({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.conversion,
    required this.total,
    required this.rate,
    required this.hintText,
    required this.allText,
    required this.referenceRateText,
    required this.rangeText,
  });

  @override
  Widget build(BuildContext context) {
    final totalNumber = double.tryParse(total) ?? 0;
    final primaryTextColor = WalletDepositNativeColors.textPrimaryOf(context);
    final secondaryTextColor = WalletDepositNativeColors.textSecondaryOf(
      context,
    );
    final tertiaryTextColor = WalletDepositNativeColors.textTertiaryOf(context);
    final hintTextColor = WalletDepositNativeColors.hintOf(context);
    final dividerColor = WalletDepositNativeColors.borderOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('transfer_amount_field'),
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: hintText,
                    hintStyle: TextStyle(fontSize: 14, color: hintTextColor),
                  ),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: primaryTextColor,
                  ),
                ),
              ),
              Text(
                unit,
                style: TextStyle(fontSize: 14, color: primaryTextColor),
              ),
              TextButton(
                onPressed: totalNumber > 0
                    ? () {
                        controller.text = totalNumber.toStringAsFixed(2);
                        controller.selection = TextSelection.collapsed(
                          offset: controller.text.length,
                        );
                      }
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF00B57A),
                ),
                child: Text(allText, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            _conversionText,
            style: TextStyle(fontSize: 10, color: tertiaryTextColor),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 9),
          Row(
            children: [
              if (!rate.isSameCurrency)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        referenceRateText,
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          rate.display(unit: unit, conversion: conversion),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Text(
                  '${rangeText}0.01 - ${totalNumber.toStringAsFixed(2)}($unit)',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: secondaryTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  String get _conversionText {
    final amount = double.tryParse(controller.text) ?? 0;
    if (amount <= 0 || rate.isSameCurrency || conversion.isEmpty) return '';
    final converted = amount * rate.amountMultiplier;
    return '≈ ${converted.toStringAsFixed(2)} $conversion';
  }
}

class _TransferTipCard extends StatelessWidget {
  final String text;

  const _TransferTipCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('transfer_tip_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.tileGrayOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: WalletDepositNativeColors.textSecondaryOf(context),
          height: 1.4,
        ),
      ),
    );
  }
}

class _AccountIcon extends StatelessWidget {
  final _TransferAccount? account;
  final double size;

  const _AccountIcon({required this.account, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = account == null || account!.isWallet
        ? 'assets/images/st_mine_wallet_sec.png'
        : account!.type == 1
        ? 'assets/images/st_mine_simulate.png'
        : account!.type == 2
        ? 'assets/images/st_mine_trans.png'
        : 'assets/images/st_mine_firm.png';
    return Image.asset(asset, width: size, height: size);
  }
}

class _TransferAccount {
  final bool isWallet;
  final String id;
  final String title;
  final String platform;
  final String currency;
  final String balance;
  final int type;
  final double canDraw;
  final double marginUsed;

  const _TransferAccount({
    required this.isWallet,
    required this.id,
    required this.title,
    required this.platform,
    required this.currency,
    required this.balance,
    required this.type,
    required this.canDraw,
    required this.marginUsed,
  });

  factory _TransferAccount.wallet(Map<String, dynamic> raw) {
    final id = _firstText(raw, const ['wallet_id', 'walletId', 'id']);
    return _TransferAccount(
      isWallet: true,
      id: id,
      title: _firstText(raw, const [
        'wallet_name',
        'walletName',
        'name',
      ], fallback: stLocalizedTextFromZhHans('')),
      platform: 'WALLET',
      currency: _firstText(raw, const ['currency']),
      balance: _firstText(raw, const ['balance']),
      type: -1,
      canDraw: _numText(raw, const ['balance']),
      marginUsed: 0,
    );
  }

  factory _TransferAccount.trade(Map<String, dynamic> raw) {
    final type =
        int.tryParse(
          _firstText(raw, const [
            'type',
            'account_type_code',
            'account_type_num',
          ]),
        ) ??
        0;
    return _TransferAccount(
      isWallet: false,
      id: _firstText(raw, const ['account_id', 'accountId', 'id']),
      title: _accountTypeTitle(raw, type),
      platform: _firstText(raw, const ['platform'], fallback: 'MT5'),
      currency: _firstText(raw, const ['currency']),
      balance: _firstText(raw, const ['margin_free', 'marginFree', 'balance']),
      type: type,
      canDraw: _numText(raw, const [
        'can_draw',
        'canDraw',
        'margin_free',
        'marginFree',
      ]),
      marginUsed: _numText(raw, const ['margin_used', 'marginUsed']),
    );
  }

  double get available => double.tryParse(balance) ?? 0;

  bool get isIosTransferTradeCandidate => isWallet || type == 0 || type == 4;

  String get maskedId {
    final tail = id.length >= 2 ? id.substring(id.length - 2) : id;
    return '**$tail';
  }

  String get maskedNameId => '$title($maskedId)';

  String get fundingKey =>
      '${isWallet ? WalletFundingAccountRole.wallet.name : WalletFundingAccountRole.trade.name}|$id';

  String maskedNameIdWithTitle(String title) => '$title($maskedId)';

  WalletFundingAccount toFundingAccount({required String label}) {
    return WalletFundingAccount(
      role: isWallet
          ? WalletFundingAccountRole.wallet
          : WalletFundingAccountRole.trade,
      id: id,
      platform: platform,
      label: label,
      currency: currency,
      balance: balance,
      canDraw: balance,
      raw: <String, dynamic>{'type': type},
    );
  }

  bool sameIdentity(_TransferAccount? other) {
    return other != null && isWallet == other.isWallet && id == other.id;
  }

  static String _accountTypeTitle(Map<String, dynamic> raw, int type) {
    final explicit = _firstText(raw, const [
      'accountType',
      'account_type_name',
    ]);
    if (explicit.isNotEmpty && int.tryParse(explicit) == null) return explicit;
    switch (type) {
      case 0:
      case 4:
        return 'real_account';
      case 1:
        return 'simulation_account';
      case 2:
        return 'binary_options_account';
      case 3:
        return 'trader_account';
      default:
        return 'account';
    }
  }

  static String _firstText(
    Map<String, dynamic> raw,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = raw[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return fallback;
  }

  static double _numText(Map<String, dynamic> raw, List<String> keys) {
    return double.tryParse(_firstText(raw, keys)) ?? 0;
  }
}

class _TransferRate {
  final bool isSameCurrency;
  final double amountMultiplier;
  final String displayRate;

  const _TransferRate({
    required this.isSameCurrency,
    required this.amountMultiplier,
    required this.displayRate,
  });

  const _TransferRate.sameCurrency()
    : isSameCurrency = true,
      amountMultiplier = 1,
      displayRate = '1.00';

  factory _TransferRate.fromApi(Map<String, dynamic> raw) {
    final toAmount = double.tryParse('${raw['to_amount'] ?? ''}') ?? 1;
    final rate = double.tryParse('${raw['rate'] ?? ''}') ?? 1;
    final derivative = double.tryParse('${raw['rate_derivative'] ?? ''}') ?? 1;
    return _TransferRate(
      isSameCurrency: false,
      amountMultiplier: toAmount,
      displayRate: toAmount > 1 ? _trimRate(rate) : _trimRate(derivative),
    );
  }

  String display({required String unit, required String conversion}) {
    if (isSameCurrency) return '';
    return '1$unit ≈ $displayRate$conversion';
  }

  static String _trimRate(double value) {
    return value.toStringAsFixed(2);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
