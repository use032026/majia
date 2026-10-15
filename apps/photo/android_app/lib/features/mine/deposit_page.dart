import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/services/activity_popup_service.dart';
import '../../core/services/wallet_deposit_withdraw_contract.dart';
import '../../shared/widgets/st_action_refreshing_hud.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_toast.dart';
import '../../shared/widgets/st_webview.dart';
import '../../shared/widgets/auth_popups.dart';
import '../activity/activity_popups.dart';
import 'wallet_deposit_native_layout.dart';

/// 入金页：对齐 iOS `STWalletDepositViewController(type: Deposit)` 布局。
class DepositPage extends ConsumerStatefulWidget {
  const DepositPage({super.key, this.depositTarget = 0});

  final int depositTarget;

  @override
  ConsumerState<DepositPage> createState() => _DepositPageState();
}

class _DepositText {
  const _DepositText._();

  static final Map<String, String> fallbackText = {
    'charge': stLocalizedTextFromZhHans('入金'),
    'charge_to': stLocalizedTextFromZhHans('入金到'),
    'charge_method': stLocalizedTextFromZhHans('入金方式'),
    'charge_sum': stLocalizedTextFromZhHans('入金金额'),
    'charge_allow': stLocalizedTextFromZhHans('入金须知'),
    'charge_bottom_tip_content': stLocalizedTextFromZhHans(
      '1.需依存款提案金额进行转账, 【多汇】或 【少汇】 的资金都无法到账。\n'
      '2.转账完成后, 如10分钟没有到账, 请联络客服协助。\n'
      '3.请勿对 【过往账户】 存款, 资金无法找回。\n'
      '4.仅接受本人账户存款, 不接受第三方存款。',
    ),
    'charge_input_tip': stLocalizedTextFromZhHans('请输入入金金额'),
    'server_fee': stLocalizedTextFromZhHans('手续费'),
    'reference_exchange_rate': stLocalizedTextFromZhHans('参考汇率：'),
    'single_amount_range': stLocalizedTextFromZhHans('单笔金额范围：'),
    'next_step': stLocalizedTextFromZhHans('下一步'),
    'my_wallet': stLocalizedTextFromZhHans('我的钱包'),
    'real_account': stLocalizedTextFromZhHans('真实账户'),
    'simulation_account': stLocalizedTextFromZhHans('模拟账户'),
    'more_pay_channel': '更多支付通道',
    'flutter_wallet_no_available_accounts': '暂无可用的钱包或交易账户',
    'flutter_deposit_no_available_channels': '暂无可用的支付渠道',
    'flutter_deposit_unknown_channel': '未知渠道',
  };
}

class _DepositPageState extends ConsumerState<DepositPage> {
  final _amountCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  Map<String, dynamic>? _selectedChannel;
  String? _selectedPresetAmount;
  List<Map<String, dynamic>> _channels = [];
  List<WalletFundingAccount> _accounts = [];
  WalletFundingAccount? _selectedAccount;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _rateData;
  Map<String, dynamic>? _feeData;
  Timer? _quoteTimer;
  int _quoteRequestToken = 0;
  bool _showAllChannels = false;
  bool _isShowingChannelKyc = false;
  String? _lastKycPromptChannelId;
  bool _hasDepositOperation = false;
  late final ActivityPopupService _activityPopupService;
  String? _localizedLanguageCode;
  Map<String, String> _localized = _DepositText.fallbackText;

  @override
  void initState() {
    super.initState();
    _activityPopupService = ref.read(activityPopupServiceProvider);
    unawaited(_loadPageData());
  }

  @override
  void dispose() {
    if (!_hasDepositOperation) {
      _scheduleDepositReturnPrompt();
    }
    _quoteTimer?.cancel();
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _scheduleDepositReturnPrompt() {
    unawaited(
      _activityPopupService.showDepositReturnTradeUnlockPrompt(
        _openDepositReturnRoute,
      ),
    );
  }

  void _openDepositReturnRoute(String path, Map<String, dynamic> params) {
    if (path != '/action/tradeUnlockTaskUnCompleted') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = STToast.navigatorKey.currentState;
      if (navigator == null || !navigator.mounted) return;
      navigator.push(
        PageRouteBuilder<void>(
          fullscreenDialog: true,
          pageBuilder: (_, _, _) => TradeUnlockUnCompletedPage(
            taskInfo: params['taskInfo'] as Map<String, dynamic>?,
            isFromDeposit: activityPopupIsFromDepositParam(params),
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_DepositText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _DepositText.fallbackText[key] ?? key;

  List<WalletFundingAccount> _accountsFromUser(UserState us) {
    return WalletDepositWithdrawContract.fundingAccounts(
      tradeAccounts: us.accountAry.map(
        (a) => {
          'account_id': a.accountId,
          'type': a.type,
          'platform': a.platform,
          'account_type': a.accountType,
          'balance': a.balance,
          'currency': a.currency.isNotEmpty ? a.currency : 'USD',
          'can_draw': a.canDraw,
        },
      ),
      wallets: us.walletAry.map(
        (w) => {
          'id': w.walletId,
          'currency': w.currency,
          'balance': '${w.balance}',
          'can_draw': w.canDraw,
        },
      ),
    );
  }

  Future<void> _loadPageData() async {
    try {
      final service = ref.read(stServiceProvider);
      try {
        final walletInfo = await service.getWalletInfo();
        ref.read(userStateProvider.notifier).updateWalletInfo(walletInfo);
      } catch (_) {}

      final channels = (await service.getDepositChannels())
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final accounts = _accountsFromUser(ref.read(userStateProvider));
      final firstChannel = channels.isNotEmpty ? channels.first : null;
      if (!mounted) {
        return;
      }
      setState(() {
        _accounts = accounts;
        _selectedAccount =
            WalletDepositWithdrawContract.defaultDepositSource(
              accounts,
              depositTarget: widget.depositTarget,
            ) ??
            (accounts.isNotEmpty ? accounts.first : null);
        _channels = channels;
        _selectedChannel = firstChannel;
        _applyPresetAmount(
          WalletDepositWithdrawContract.defaultDepositAmount(firstChannel),
        );
        _isLoading = false;
      });
      _scheduleQuoteRefresh(immediate: true);
      _scheduleSelectedChannelKycCheck();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      showStLocalizedErrorToast(context, '加载入金渠道失败', e);
    }
  }

  Future<void> _submitDeposit() async {
    final amountStr = _selectedPresetAmount ?? _amountCtrl.text;
    final customizedAmountError = _depositAmountError;
    if (customizedAmountError != null) {
      showStLocalizedToast(context, customizedAmountError);
      return;
    }
    final amountError = WalletDepositWithdrawContract.depositValidationError(
      channel: _selectedChannel,
      amount: amountStr,
    );
    if (amountError != null) {
      if (amountError == 'max_charge_amount') {
        showStLocalizedToastByKey(
          context,
          'flutter_prompt_deposit_range_exceeded',
        );
      } else {
        showStLocalizedToast(context, amountError);
      }
      return;
    }

    final account = _selectedAccount;
    if (account == null || account.id.isEmpty) {
      showStLocalizedToast(context, '未找到入账账户，请先登录并同步账户');
      return;
    }

    if (_isTrialAccount(account)) {
      final confirmed = await showTrialBonusTopUpDialog(
        context: context,
        mode: TrialBonusTopUpMode.recharge,
      );
      if (confirmed != true) {
        return;
      }
    }

    if (!await _ensureSelectedChannelKyc()) {
      return;
    }

    _hasDepositOperation = true;
    setState(() => _isSubmitting = true);
    try {
      final result = await ref
          .read(stServiceProvider)
          .getPaymentAddress(
            WalletDepositWithdrawContract.buildDepositPayload(
              channel: _selectedChannel!,
              amount: amountStr,
              account: account,
            ),
          );

      final paymentUrl =
          result['pay_url']?.toString() ??
          result['url']?.toString() ??
          result['payment_url']?.toString();
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => STWebView(url: paymentUrl, title: _t('charge')),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        showStLocalizedErrorToast(context, '入金失败', e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _hasValidAmount {
    final preset = _selectedPresetAmount;
    if (preset != null && double.tryParse(preset) != null) {
      return true;
    }
    final manual = double.tryParse(_amountCtrl.text.trim());
    return manual != null && manual > 0;
  }

  String? get _depositAmountError {
    return WalletDepositWithdrawContract.depositCustomizedAmountValidationError(
      channel: _selectedChannel,
      amount: _amountCtrl.text,
      isManualInput: _selectedPresetAmount == null,
      isRealAccount: _selectedAccount?.role == WalletFundingAccountRole.trade,
    );
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      _selectedChannel != null &&
      _selectedAccount != null &&
      _hasValidAmount &&
      _channels.isNotEmpty &&
      _depositAmountError == null;

  List<String> get _currentPresetAmounts =>
      WalletDepositWithdrawContract.presetAmounts(_selectedChannel ?? {});

  List<Map<String, dynamic>> get _visibleChannels =>
      !_showAllChannels && _channels.length > 4
      ? _channels.take(4).toList()
      : _channels;

  bool get _showMoreChannels => !_showAllChannels && _channels.length > 4;

  String get _channelCurrency =>
      _selectedChannel?['currency']?.toString() ?? 'USD';

  String _accountLabel(WalletFundingAccount account) {
    final label = _localizedFundingAccountLabel(account);
    final maskedId = walletNativeMaskedAccountId(account.id);
    return maskedId.isEmpty ? label : '$label($maskedId)';
  }

  String _localizedFundingAccountLabel(WalletFundingAccount account) {
    if (account.role == WalletFundingAccountRole.wallet) return _t('my_wallet');
    final type =
        (account.raw['type'] ??
                account.raw['account_type_code'] ??
                account.raw['account_type_num'] ??
                '')
            .toString();
    switch (type) {
      case '0':
      case '4':
        return _t('real_account');
      case '1':
        return _t('simulation_account');
      default:
        return account.label;
    }
  }

  String get _amountText {
    if (!_hasValidAmount) {
      return '--($_channelCurrency)';
    }
    final value = _selectedPresetAmount ?? _amountCtrl.text.trim();
    return '$value($_channelCurrency)';
  }

  String get _conversionText {
    final currency = _selectedAccount?.currency.isNotEmpty == true
        ? _selectedAccount!.currency
        : 'USD';
    if (!_hasValidAmount) {
      return '≈--($currency)';
    }
    final value = _selectedPresetAmount ?? _amountCtrl.text.trim();
    if (_selectedChannel == null || _selectedAccount == null) {
      return '≈$value($currency)';
    }
    if (!WalletDepositWithdrawContract.needsDepositExchangeRate(
      channel: _selectedChannel!,
      account: _selectedAccount!,
    )) {
      return '≈$value($currency)';
    }
    final converted = WalletDepositWithdrawContract.convertAmountText(
      sourceAmount: value,
      targetCurrency: currency,
      rateData: _rateData,
    );
    return converted.isEmpty ? '≈--($currency)' : '≈$converted';
  }

  String get _depositFeeText {
    final fee = WalletDepositWithdrawContract.feeAmount(_feeData);
    return fee.isEmpty ? '--' : '$fee $_channelCurrency';
  }

  String get _depositRateText {
    if (_selectedChannel == null || _selectedAccount == null) {
      return '';
    }
    if (!WalletDepositWithdrawContract.needsDepositExchangeRate(
      channel: _selectedChannel!,
      account: _selectedAccount!,
    )) {
      return '';
    }
    return WalletDepositWithdrawContract.depositReferenceRateText(
      channelCurrency: _channelCurrency,
      accountCurrency: _selectedAccount!.currency,
      rateData: _rateData ?? const {},
    );
  }

  String get _depositRangeText {
    final channel = _selectedChannel;
    if (channel == null) {
      return '';
    }
    final min = channel['min_amount']?.toString().trim() ?? '';
    final max = channel['max_amount']?.toString().trim() ?? '';
    if (min.isEmpty && max.isEmpty) {
      return '';
    }
    return '$min - $max $_channelCurrency';
  }

  void _scheduleQuoteRefresh({bool immediate = false}) {
    _quoteTimer?.cancel();
    if (immediate) {
      unawaited(_refreshQuote());
      return;
    }
    _quoteTimer = Timer(const Duration(milliseconds: 350), _refreshQuote);
  }

  Future<void> _refreshQuote() async {
    final token = ++_quoteRequestToken;
    final channel = _selectedChannel;
    final account = _selectedAccount;
    final amount = _selectedPresetAmount ?? _amountCtrl.text.trim();
    if (channel == null || account == null) {
      if (mounted) {
        setState(() {
          _rateData = null;
          _feeData = null;
        });
      }
      return;
    }
    final service = ref.read(stServiceProvider);
    Map<String, dynamic>? nextRate;
    Map<String, dynamic>? nextFee;
    try {
      if (WalletDepositWithdrawContract.needsDepositExchangeRate(
        channel: channel,
        account: account,
      )) {
        nextRate = await service.getExchangeRate(
          WalletDepositWithdrawContract.buildDepositExchangeRateParams(
            channel: channel,
            account: account,
          ),
        );
      }
    } catch (_) {}
    if (amount.isNotEmpty) {
      try {
        nextFee = await service.getDepositFee(
          WalletDepositWithdrawContract.buildDepositFeePayload(
            channel: channel,
            amount: amount,
          ),
        );
      } catch (_) {}
    }
    if (!mounted || token != _quoteRequestToken) {
      return;
    }
    setState(() {
      _rateData = nextRate;
      _feeData = nextFee;
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final pageBackground = WalletDepositNativeColors.depositPageBackgroundOf(
      context,
    );
    return STKeyboardActions(
      focusNodes: [_amountFocus],
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: pageBackground,
          foregroundColor: WalletDepositNativeColors.textPrimaryOf(context),
          title: Text(
            _t('charge'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          ),
        ),
        body: _isLoading
            ? const Center(child: STLoadAnimationView())
            : Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            WalletNativeSection(
                              containerKey: const ValueKey(
                                'wallet_native_deposit_target_section',
                              ),
                              title: _t('charge_to'),
                              titleColor: WalletDepositNativeColors.textPrimary,
                              horizontalPadding: 15,
                              backgroundColor: pageBackground,
                              child: _selectedAccount == null
                                  ? Text(
                                      _t(
                                        'flutter_wallet_no_available_accounts',
                                      ),
                                    )
                                  : WalletNativeAccountTile(
                                      title: _accountLabel(_selectedAccount!),
                                      iconAsset: walletNativeAccountIconAsset(
                                        _selectedAccount!,
                                      ),
                                      onTap: _showDepositAccountSheet,
                                    ),
                            ),
                            WalletNativeSection(
                              containerKey: const ValueKey(
                                'wallet_native_deposit_method_section',
                              ),
                              title: _t('charge_method'),
                              titleColor: WalletDepositNativeColors.textPrimary,
                              horizontalPadding: 15,
                              backgroundColor: pageBackground,
                              child: _channels.isEmpty
                                  ? Text(
                                      _t(
                                        'flutter_deposit_no_available_channels',
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        WalletNativeChoiceGrid(
                                          children: _visibleChannels.map((
                                            channel,
                                          ) {
                                            return WalletNativePayMethodTile(
                                              title:
                                                  channel['name']?.toString() ??
                                                  _t(
                                                    'flutter_deposit_unknown_channel',
                                                  ),
                                              iconUrl: channel['icon']
                                                  ?.toString(),
                                              selected:
                                                  _selectedChannel == channel,
                                              onTap: () =>
                                                  _selectDepositChannel(
                                                    channel,
                                                  ),
                                            );
                                          }).toList(),
                                        ),
                                        if (_showMoreChannels)
                                          TextButton(
                                            key: const ValueKey(
                                              'wallet_native_more_pay_channel',
                                            ),
                                            onPressed: () => setState(
                                              () => _showAllChannels = true,
                                            ),
                                            child: Text(_t('more_pay_channel')),
                                          ),
                                      ],
                                    ),
                            ),
                            WalletNativeSection(
                              containerKey: const ValueKey(
                                'wallet_native_deposit_amount_section',
                              ),
                              title: _t('charge_sum'),
                              titleColor: WalletDepositNativeColors.textPrimary,
                              horizontalPadding: 15,
                              backgroundColor: pageBackground,
                              child: Column(
                                children: [
                                  if (_currentPresetAmounts.isNotEmpty) ...[
                                    WalletNativeChoiceGrid(
                                      columns: 3,
                                      spacing: 5,
                                      children: _currentPresetAmounts.map((
                                        amount,
                                      ) {
                                        return WalletNativePresetAmountTile(
                                          amount: amount,
                                          currency: _channelCurrency,
                                          selected:
                                              _selectedPresetAmount == amount,
                                          onTap: () {
                                            setState(() {
                                              _applyPresetAmount(amount);
                                            });
                                            _scheduleQuoteRefresh(
                                              immediate: true,
                                            );
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  WalletNativeAmountField(
                                    controller: _amountCtrl,
                                    focusNode: _amountFocus,
                                    unit: _channelCurrency,
                                    hintText: _t('charge_input_tip'),
                                    conversionText: _hasValidAmount
                                        ? _conversionText
                                        : '',
                                    errorText: _depositAmountError,
                                    onChanged: (_) {
                                      setState(
                                        () => _selectedPresetAmount = null,
                                      );
                                      _scheduleQuoteRefresh();
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  WalletNativeInfoRows(
                                    style: WalletNativeInfoRowsStyle.plain,
                                    primaryValueKeys: {
                                      _t('reference_exchange_rate'),
                                    },
                                    rows: {
                                      _t('server_fee'): _depositFeeText,
                                      if (_depositRateText.isNotEmpty)
                                        _t('reference_exchange_rate'):
                                            _depositRateText,
                                      if (_depositRangeText.isNotEmpty)
                                        _t('single_amount_range'):
                                            _depositRangeText,
                                    },
                                  ),
                                ],
                              ),
                            ),
                            WalletNativeDepositNoticeCard(
                              title: _t('charge_allow'),
                              text: _t('charge_bottom_tip_content'),
                            ),
                            const SizedBox(height: 88),
                          ],
                        ),
                      ),
                      WalletNativeBottomBar(
                        mode: WalletNativeBottomBarMode.deposit,
                        primaryText: _t('next_step'),
                        enabled: _canSubmit,
                        loading: _isSubmitting,
                        amountText: _hasValidAmount ? _amountText : null,
                        conversionText: _conversionText,
                        backgroundColor: pageBackground,
                        onPressed: _submitDeposit,
                      ),
                    ],
                  ),
                  if (_isSubmitting)
                    const STActionRefreshingHud(
                      key: ValueKey('wallet-action-refreshing-hud'),
                    ),
                ],
              ),
      ),
    );
  }

  void _selectDepositChannel(Map<String, dynamic> channel) {
    setState(() {
      _selectedChannel = channel;
      _applyPresetAmount('');
      _rateData = null;
      _feeData = null;
    });
    _scheduleQuoteRefresh(immediate: true);
    _scheduleSelectedChannelKycCheck();
  }

  void _applyPresetAmount(String? amount) {
    final value = amount?.trim() ?? '';
    _selectedPresetAmount = value.isEmpty ? null : value;
    _amountCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _showDepositAccountSheet() async {
    final selected = await showModalBottomSheet<WalletFundingAccount>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (ctx) => WalletNativeAccountPickerSheet(
        accounts: _accounts,
        selectedKey: _selectedAccount?.key,
        onSelected: (account) => Navigator.of(ctx).pop(account),
      ),
    );
    if (selected != null && mounted && selected.key != _selectedAccount?.key) {
      setState(() {
        _selectedAccount = selected;
        _rateData = null;
        _feeData = null;
      });
      _scheduleQuoteRefresh(immediate: true);
    }
  }

  void _scheduleSelectedChannelKycCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureSelectedChannelKyc(skipIfAlreadyPrompted: true));
    });
  }

  Future<bool> _ensureSelectedChannelKyc({
    bool skipIfAlreadyPrompted = false,
  }) async {
    final channel = _selectedChannel;
    if (channel == null || _isShowingChannelKyc) {
      return false;
    }
    final user = ref.read(userStateProvider);
    if (!user.isLogin) {
      return true;
    }
    final missing =
        WalletDepositWithdrawContract.depositChannelMissingAuthMethods(
          channel: channel,
          isAuthed: user.isAuthed,
          isBindPhone: user.isBindPhone,
          isBindEmail: user.isBindEmail,
        );
    if (missing.isEmpty) {
      return true;
    }

    final channelId = WalletDepositWithdrawContract.channelId(channel);
    if (skipIfAlreadyPrompted && _lastKycPromptChannelId == channelId) {
      return false;
    }
    _lastKycPromptChannelId = channelId;
    _isShowingChannelKyc = true;
    final shouldNavigate = await showAuthGuideSheet(context: context);
    _isShowingChannelKyc = false;
    if (shouldNavigate == true && mounted) {
      _navigateToAuth(missing);
    }
    return false;
  }

  void _navigateToAuth(List<String> missing) {
    if (missing.contains('bind_tel')) {
      context.push('/mine/bind_phone');
      return;
    }
    if (missing.contains('bind_email')) {
      context.push('/mine/bind_email');
      return;
    }
    context.push('/mine/auth');
  }

  bool _isTrialAccount(WalletFundingAccount account) {
    if (account.role != WalletFundingAccountRole.trade) {
      return false;
    }
    final rawType =
        account.raw['type'] ??
        account.raw['account_type_code'] ??
        account.raw['account_type_num'];
    return rawType?.toString() == '4';
  }
}
