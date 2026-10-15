import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/bank_card_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/services/wallet_deposit_withdraw_contract.dart';
import '../../shared/auth/fund_password_verify_dialog.dart';
import '../../shared/widgets/st_action_refreshing_hud.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import 'wallet_deposit_native_layout.dart';

/// 出金页：对齐 iOS `STWalletDepositViewController(type: Draw)` 布局。
class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key, this.depositTarget = 0});

  final int depositTarget;

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawText {
  const _WithdrawText._();

  static final fallbackText = {
    'withdrawal': stLocalizedTextFromZhHans('出金'),
    'withdrawal_account': stLocalizedTextFromZhHans('出金账户'),
    'withdrawal_method': stLocalizedTextFromZhHans('出金方式'),
    'withdrawal_input_tip': stLocalizedTextFromZhHans('请输入出金金额'),
    'withdraw_custom_amount': stLocalizedTextFromZhHans('自定义金额'),
    'withdraw_custom_amount_integer': stLocalizedTextFromZhHans('自定义金额[整数]'),
    'withdraw_can_withdraw_short': stLocalizedTextFromZhHans('可提现'),
    'withdraw_confirm_details': stLocalizedTextFromZhHans('确认明细'),
    'withdraw_received_cny': stLocalizedTextFromZhHans('本次到账'),
    'withdraw_converted_usd': stLocalizedTextFromZhHans('折合金额'),
    'server_fee': stLocalizedTextFromZhHans('手续费'),
    'withdraw_actual_withdraw_amount': stLocalizedTextFromZhHans('实际取款金额'),
    'withdraw_confirm_and_submit': stLocalizedTextFromZhHans('确认并出金'),
    'withdraw_estimated_summary_prefix': stLocalizedTextFromZhHans('账户提款 '),
    'withdraw_estimated_summary_mid': stLocalizedTextFromZhHans('，预计到账 '),
    'withdraw_dual_unconfirmed_hint': stLocalizedTextFromZhHans('请确认金额后提交'),
    'withdraw_bottom_tip_content': stLocalizedTextFromZhHans(
      '· 平台使用安全资金通道，资金将在 24–48 小时内到账，最快 2 小时完成。',
    ),
    'bank_card': stLocalizedTextFromZhHans('银行卡'),
    'wallet': stLocalizedTextFromZhHans('钱包'),
    'available': stLocalizedTextFromZhHans('可用余额'),
    'my_wallet': stLocalizedTextFromZhHans('我的钱包'),
    'real_account': stLocalizedTextFromZhHans('真实账户'),
    'simulation_account': stLocalizedTextFromZhHans('模拟账户'),
    'withdraw_exchange_rate': '汇率',
    'receiving_bank': '收款银行',
    'flutter_wallet_no_available_accounts': '暂无可用的钱包或交易账户',
    'flutter_withdraw_no_bound_bank_card': '暂未绑定银行卡',
    'flutter_withdraw_no_bound_ewallet': '暂未绑定电子钱包',
    'flutter_withdraw_estimated_arrival': '预计到账',
    'flutter_withdraw_actual_arrival': '实际到账',
    'flutter_prompt_select_source_account': '请选择出金资金来源账户',
    'flutter_prompt_select_bank_card': '请选择银行卡',
    'flutter_prompt_select_ewallet': '请选择电子钱包',
    'flutter_prompt_withdraw_source_id_invalid': '资金来源账户 ID 无效',
  };
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final _amountCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  String _destinationKind = 'bank';
  List<WalletFundingAccount> _sourceAccounts = [];
  WalletFundingAccount? _selectedSource;
  BankCardModel? _selectedCard;
  List<BankCardModel> _cards = [];
  Map<String, dynamic>? _selectedEWallet;
  List<Map<String, dynamic>> _eWallets = [];
  List<Map<String, dynamic>> _withdrawTypes = [];
  List<Map<String, dynamic>> _withdrawTemplates = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _feeInfo;
  Map<String, dynamic>? _rateData;
  Timer? _quoteTimer;
  int _quoteRequestToken = 0;
  String? _selectedPresetAmount;
  bool _arrivalConfirmed = false;
  bool _arrivalConfirmAttempted = false;
  String? _localizedLanguageCode;
  Map<String, String> _localized = _WithdrawText.fallbackText;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  String _withdrawPayloadErrorFallback(Object error) {
    final message = stUserVisibleErrorMessage(error);
    switch (message) {
      case 'withdraw_source_required':
        return _t('flutter_prompt_select_source_account');
      case 'withdraw_bank_required':
        return _t('flutter_prompt_select_bank_card');
      case 'withdraw_ewallet_required':
        return _t('flutter_prompt_select_ewallet');
      case 'withdraw_source_id_invalid':
        return _t('flutter_prompt_withdraw_source_id_invalid');
      default:
        return message;
    }
  }

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_WithdrawText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _WithdrawText.fallbackText[key] ?? key;

  void _resetArrivalConfirmation() {
    _arrivalConfirmed = false;
    _arrivalConfirmAttempted = false;
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final service = ref.read(stServiceProvider);

    try {
      final walletInfo = await service.getWalletInfo();
      ref.read(userStateProvider.notifier).updateWalletInfo(walletInfo);
    } catch (_) {}

    var withdrawTypes = <Map<String, dynamic>>[];
    var withdrawTemplates = <Map<String, dynamic>>[];
    try {
      final typeResponse = await service.getWithdrawalTypes();
      final rawTypes = typeResponse['types'];
      if (rawTypes is List) {
        withdrawTypes = rawTypes
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      final rawTemplates = typeResponse['templates'];
      if (rawTemplates is List) {
        withdrawTemplates = rawTemplates
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    if (withdrawTypes.isEmpty) {
      withdrawTypes = const [
        {'type': 'BankCard', 'pay_type': 'PAY_TYPE_BANK'},
        {'type': 'Wallet', 'pay_type': 'PAY_TYPE_CRYPTO'},
      ];
    }

    var cards = <BankCardModel>[];
    try {
      final raw = await service.getBankCards();
      cards = raw
          .whereType<Map<String, dynamic>>()
          .map(BankCardModel.fromJson)
          .where((card) => card.isCertified)
          .toList();
    } catch (_) {}

    final ewallets = <Map<String, dynamic>>[];
    try {
      final rawEw = await service.getEWalletList();
      for (final e in rawEw) {
        if (e is Map) {
          final json = Map<String, dynamic>.from(e);
          final status = int.tryParse('${json['status'] ?? 1}') ?? 1;
          if (status == 1) {
            ewallets.add(json);
          }
        }
      }
    } catch (_) {}

    if (!mounted) {
      return;
    }
    final user = ref.read(userStateProvider);
    final accounts = WalletDepositWithdrawContract.fundingAccounts(
      tradeAccounts: user.accountAry.map(
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
      wallets: user.walletAry.map(
        (w) => {
          'id': w.walletId,
          'currency': w.currency,
          'balance': '${w.balance}',
          'can_draw': w.canDraw,
        },
      ),
    );
    final nextKind = _withdrawTypesContain(withdrawTypes, wallet: false)
        ? 'bank'
        : 'ewallet';
    setState(() {
      _withdrawTypes = withdrawTypes;
      _sourceAccounts = accounts;
      _selectedSource = WalletDepositWithdrawContract.defaultWithdrawSource(
        accounts,
        depositTarget: widget.depositTarget,
      );
      _cards = cards;
      if (_cards.isNotEmpty && _selectedCard == null) {
        _selectedCard = _cards.firstWhere(
          (c) => c.isDefault,
          orElse: () => _cards.first,
        );
      }
      _eWallets = ewallets;
      if (_eWallets.isNotEmpty && _selectedEWallet == null) {
        Map<String, dynamic>? def;
        for (final w in _eWallets) {
          if (w['is_default'] == true || w['is_default'] == 1) {
            def = w;
            break;
          }
        }
        _selectedEWallet = def ?? _eWallets.first;
      }
      if (!_withdrawTypesContain(
        _withdrawTypes,
        wallet: _destinationKind == 'ewallet',
      )) {
        _destinationKind = nextKind;
      }
      _isLoading = false;
      _withdrawTemplates = withdrawTemplates;
    });
    _scheduleQuoteRefresh(immediate: true);
  }

  bool _withdrawTypesContain(
    List<Map<String, dynamic>> types, {
    required bool wallet,
  }) {
    for (final cfg in types) {
      final type = (cfg['type'] ?? '').toString().toLowerCase();
      final isWallet = type.contains('wallet') || type.contains('crypto');
      if (isWallet == wallet) {
        return true;
      }
    }
    return false;
  }

  String _sourceLabel(WalletFundingAccount account) {
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

  String _formatAmount(num value) {
    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _sourceIconAsset(WalletFundingAccount account) {
    return walletNativeAccountIconAsset(account);
  }

  String _eWalletLabel(Map<String, dynamic> w) {
    final cur = w['currency']?.toString() ?? '';
    final addr = (w['payment_address'] ?? w['address'] ?? '').toString();
    if (addr.length > 14) {
      return '$cur · ${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
    }
    return cur.isNotEmpty ? '$cur · $addr' : addr;
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
    final source = _selectedSource;
    final destination = _selectedDestinationJson;
    if (source == null || destination == null) {
      if (mounted) {
        setState(() {
          _feeInfo = null;
          _rateData = null;
        });
      }
      return;
    }
    final amount = _amountCtrl.text.trim();
    final service = ref.read(stServiceProvider);
    Map<String, dynamic>? nextRate;
    Map<String, dynamic>? nextFee = _feeInfo;
    try {
      final params = WalletDepositWithdrawContract.buildWithdrawRateParams(
        destinationKind: _destinationKind == 'bank'
            ? WalletWithdrawDestinationKind.bank
            : WalletWithdrawDestinationKind.eWallet,
        destination: destination,
        source: source,
      );
      if (params.isNotEmpty) {
        nextRate = await service.getExchangeRate(params);
      }
    } catch (_) {}
    if (amount.isNotEmpty && double.tryParse(amount) != null) {
      try {
        nextFee = await service.getWithdrawFee(
          WalletDepositWithdrawContract.buildWithdrawFeePayload(
            destinationKind: _destinationKind == 'bank'
                ? WalletWithdrawDestinationKind.bank
                : WalletWithdrawDestinationKind.eWallet,
            amount: amount,
            destination: destination,
          ),
        );
      } catch (_) {}
    } else {
      nextFee = null;
    }
    if (!mounted || token != _quoteRequestToken) {
      return;
    }
    setState(() {
      _rateData = nextRate;
      _feeInfo = nextFee;
    });
  }

  String? _feeTargetCurrencyAmount() {
    if (_isCnyWithdrawInputMode) {
      final input = double.tryParse(_amountCtrl.text.trim());
      if (input == null || input <= 0) {
        return null;
      }
      return input.floor().toString();
    }
    final source = _selectedSource;
    final targetCurrency = _destinationCurrency;
    if (source == null || targetCurrency.isEmpty) {
      return null;
    }
    return WalletDepositWithdrawContract.withdrawTargetCurrencyAmount(
      amount: _amountCtrl.text,
      fee: WalletDepositWithdrawContract.feeAmount(_feeInfo),
      targetCurrency: targetCurrency,
      destinationIsBank: _destinationKind == 'bank',
      rateData: _rateData ?? const {'rate': '1', 'to_amount': '1'},
    );
  }

  double? get _sourceAmountBeforeFee {
    final input = double.tryParse(_amountCtrl.text.trim());
    if (input == null || input <= 0) return null;
    if (!_isCnyWithdrawInputMode) return input;
    final rate = _cnyPerSourceRate;
    if (rate == null || rate <= 0) return null;
    return input / rate;
  }

  double? get _withdrawActualDeductSourceAmount {
    final sourceAmount = _sourceAmountBeforeFee;
    if (sourceAmount == null) return null;
    final fee =
        double.tryParse(WalletDepositWithdrawContract.feeAmount(_feeInfo)) ?? 0;
    return sourceAmount + fee;
  }

  String get _withdrawSubmitAmount {
    if (!_isCnyWithdrawInputMode) {
      return _amountCtrl.text.trim();
    }
    final actual = _withdrawActualDeductSourceAmount;
    return actual == null ? _amountCtrl.text.trim() : _formatAmount(actual);
  }

  Map<String, dynamic>? get _selectedDestinationJson {
    if (_destinationKind == 'bank') {
      return _selectedCard?.toJson();
    }
    return _selectedEWallet;
  }

  String get _destinationCurrency {
    final dest = _selectedDestinationJson;
    if (dest == null) return '';
    return (dest['currency'] ?? dest['wallet_currency'] ?? '').toString();
  }

  String get _sourceAvailableRaw {
    final source = _selectedSource;
    if (source == null) return '';
    return source.canDraw.isNotEmpty ? source.canDraw : source.balance;
  }

  bool get _isCnyWithdrawInputMode =>
      _destinationCurrency.toUpperCase().contains('CNY') ||
      _destinationCurrency.toUpperCase().contains('CNH');

  double? get _cnyPerSourceRate {
    final rate = WalletDepositWithdrawContract.withdrawCnyPerAccountRate(
      _rateData,
      accountCurrency: _sourceCurrencyCode,
    );
    return double.tryParse(rate ?? '');
  }

  String get _withdrawAvailableDisplayText {
    final sourceUnit = _selectedSource?.currency.trim();
    final unit = _isCnyWithdrawInputMode ? 'CNY' : (sourceUnit ?? _sourceUnit);
    final available = double.tryParse(_sourceAvailableRaw);
    if (available == null) {
      return '-- $unit';
    }
    if (_isCnyWithdrawInputMode) {
      final rate = _cnyPerSourceRate;
      if (rate == null || rate <= 0) {
        return '0.00 CNY';
      }
      return '${_formatAmount(available * rate)} CNY';
    }
    return '${_formatAmount(available)} $unit';
  }

  String get _withdrawAvailableForValidation {
    final available = double.tryParse(_sourceAvailableRaw);
    if (available == null) return '';
    if (_isCnyWithdrawInputMode) {
      final rate = _cnyPerSourceRate;
      if (rate == null || rate <= 0) return '0';
      return _formatAmount(available * rate);
    }
    return _sourceAvailableRaw;
  }

  Map<String, dynamic>? get _currentWithdrawTemplate {
    final kind = _destinationKind == 'bank'
        ? WalletWithdrawDestinationKind.bank
        : WalletWithdrawDestinationKind.eWallet;
    return WalletDepositWithdrawContract.withdrawTemplateForTypeConfig(
      typeConfig: WalletDepositWithdrawContract.withdrawTypeConfigForKind(
        _withdrawTypes,
        kind,
      ),
      channelCurrency: _destinationCurrency,
      accountCurrency: _selectedSource?.currency ?? '',
      templates: _withdrawTemplates,
    );
  }

  List<String> get _withdrawPresetAmounts {
    final template = _currentWithdrawTemplate;
    if (template == null || template.isEmpty) return const [];
    return WalletDepositWithdrawContract.withdrawPresetAmountsFromTemplate(
      template,
      cnyInputMode: _isCnyWithdrawInputMode,
    );
  }

  String? get _amountValidationError {
    final amount = _amountCtrl.text.trim();
    final integerError = WalletDepositWithdrawContract.withdrawValidationError(
      amount: amount,
      available: '',
      destinationCurrency: _isCnyWithdrawInputMode
          ? 'CNY'
          : (_selectedSource?.currency ?? _destinationCurrency),
    );
    if (integerError != null) {
      return integerError;
    }
    final customizedError =
        WalletDepositWithdrawContract.withdrawCustomizedAmountValidationError(
          template: _currentWithdrawTemplate,
          amount: amount,
          isManualInput: _selectedPresetAmount == null && amount.isNotEmpty,
          isRealAccount:
              _selectedSource?.role == WalletFundingAccountRole.trade,
        );
    if (customizedError != null) {
      return customizedError;
    }
    return WalletDepositWithdrawContract.withdrawValidationError(
      amount: amount,
      available: _withdrawAvailableForValidation,
      destinationCurrency: _isCnyWithdrawInputMode
          ? 'CNY'
          : (_selectedSource?.currency ?? _destinationCurrency),
      fee: _isCnyWithdrawInputMode
          ? ''
          : WalletDepositWithdrawContract.feeAmount(_feeInfo),
      feeLoaded: !_isCnyWithdrawInputMode && _feeInfo != null,
      actualDeductAmount: _isCnyWithdrawInputMode
          ? _withdrawActualDeductSourceAmount?.toString()
          : null,
      availableForActualDeduct: _isCnyWithdrawInputMode
          ? _sourceAvailableRaw
          : null,
    );
  }

  Map<String, dynamic> _buildWithdrawPayload(String fundPassword) {
    final src = _selectedSource;
    if (src == null) {
      throw Exception('withdraw_source_required');
    }
    if (_destinationKind == 'bank') {
      final c = _selectedCard;
      if (c == null) {
        throw Exception('withdraw_bank_required');
      }
      return WalletDepositWithdrawContract.buildWithdrawPayload(
        destinationKind: WalletWithdrawDestinationKind.bank,
        source: src,
        destination: c.toJson(),
        amount: _withdrawSubmitAmount,
        fundPassword: fundPassword,
        targetCurrencyAmount: _feeTargetCurrencyAmount(),
      );
    }
    final w = _selectedEWallet;
    if (w == null) {
      throw Exception('withdraw_ewallet_required');
    }
    return WalletDepositWithdrawContract.buildWithdrawPayload(
      destinationKind: WalletWithdrawDestinationKind.eWallet,
      source: src,
      destination: w,
      amount: _withdrawSubmitAmount,
      fundPassword: fundPassword,
      targetCurrencyAmount: _feeTargetCurrencyAmount(),
    );
  }

  Future<void> _submitWithdraw() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      showStLocalizedToast(context, '请输入有效金额');
      return;
    }
    final error = _amountValidationError;
    if (error != null && error.isNotEmpty) {
      showStLocalizedToast(context, error);
      return;
    }
    if (_selectedSource == null) {
      showStLocalizedToast(context, '请选择出金资金来源');
      return;
    }
    if (_destinationKind == 'bank' && _selectedCard == null) {
      showStLocalizedToast(context, '请选择到账银行卡');
      return;
    }
    if (_destinationKind == 'ewallet' && _selectedEWallet == null) {
      showStLocalizedToast(context, '请选择到账电子钱包');
      return;
    }
    if (_feeInfo == null) {
      await _refreshQuote();
      if (!mounted) {
        return;
      }
    }
    if (_withdrawExpectedArrivalBannerParts != null && !_arrivalConfirmed) {
      setState(() => _arrivalConfirmAttempted = true);
      return;
    }

    final fundPassword = await showFundPasswordVerifyDialog(context);
    if (!mounted) {
      return;
    }
    if (fundPassword == null || fundPassword.isEmpty) {
      return;
    }

    Map<String, dynamic> payload;
    try {
      payload = _buildWithdrawPayload(fundPassword);
    } catch (e) {
      showStLocalizedToast(context, _withdrawPayloadErrorFallback(e));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(stServiceProvider).withdraw(payload);
      if (!mounted) {
        return;
      }
      context.push('/mine/commit_success', extra: const {'kind': 'draw'});
    } catch (e) {
      if (mounted) {
        showStLocalizedErrorToast(context, '出金失败', e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _baseCanSubmit {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final feeReady = amount == null || amount <= 0 || _feeInfo != null;
    return !_isSubmitting &&
        amount != null &&
        amount > 0 &&
        feeReady &&
        _amountValidationError == null &&
        _selectedSource != null &&
        (_destinationKind == 'bank'
            ? _selectedCard != null
            : _selectedEWallet != null);
  }

  String get _sourceUnit {
    final unit = _selectedSource?.currency.trim();
    return unit == null || unit.isEmpty ? r'$' : unit;
  }

  String get _withdrawInputUnit {
    if (_destinationKind == 'bank' &&
        _destinationCurrency.toUpperCase() == 'CNY') {
      return '¥';
    }
    return _sourceUnit;
  }

  String get _sourceCurrencyCode {
    final unit = _selectedSource?.currency.trim();
    if (unit == null || unit.isEmpty || unit == r'$') {
      return 'USD';
    }
    return unit;
  }

  String? get _withdrawRateLineText {
    if (!_isCnyWithdrawInputMode) {
      return null;
    }
    final value = WalletDepositWithdrawContract.withdrawCnyInputRateLineText(
      rateData: _rateData,
      accountCurrency: _sourceCurrencyCode,
    );
    return value == null ? null : '${_t('withdraw_exchange_rate')}:$value';
  }

  Map<String, String>? get _withdrawConfirmDetailRows {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0 || !_isCnyWithdrawInputMode) {
      return null;
    }
    final sourceBeforeFee = _sourceAmountBeforeFee;
    final actualDeduct = _withdrawActualDeductSourceAmount;
    if (sourceBeforeFee == null || actualDeduct == null) {
      return null;
    }
    final fee =
        double.tryParse(WalletDepositWithdrawContract.feeAmount(_feeInfo)) ?? 0;
    return {
      'received': '${amount.floor()} CNY',
      'converted': '${_formatAmount(sourceBeforeFee)} $_sourceCurrencyCode',
      'fee': '${_formatAmount(fee)} $_sourceCurrencyCode',
      'deduct': '${_formatAmount(actualDeduct)} $_sourceCurrencyCode',
    };
  }

  Map<String, String>? get _withdrawExpectedArrivalBannerParts {
    if (!_baseCanSubmit) return null;
    final rows = _withdrawConfirmDetailRows;
    final actualDeduct = _withdrawActualDeductSourceAmount;
    if (rows == null || actualDeduct == null) return null;
    return {
      'received': rows['received']!,
      'deduct': '${_formatAmount(actualDeduct)}$_sourceCurrencyCode',
    };
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final pageBackground = WalletDepositNativeColors.pageGrayOf(context);
    final sectionBackground = WalletDepositNativeColors.depositPageBackgroundOf(
      context,
    );
    return STKeyboardActions(
      focusNodes: [_amountFocus],
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: sectionBackground,
          foregroundColor: WalletDepositNativeColors.textPrimaryOf(context),
          title: Text(
            _t('withdrawal'),
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
                              title: _t('withdrawal_account'),
                              backgroundColor: sectionBackground,
                              child: _selectedSource == null
                                  ? Text(
                                      _t(
                                        'flutter_wallet_no_available_accounts',
                                      ),
                                    )
                                  : WalletNativeAccountTile(
                                      title: _sourceLabel(_selectedSource!),
                                      subtitle:
                                          '${_t('available')}：${_selectedSource!.canDraw.isNotEmpty ? _selectedSource!.canDraw : _selectedSource!.balance}',
                                      iconAsset: _sourceIconAsset(
                                        _selectedSource!,
                                      ),
                                      onTap: _showSourceSheet,
                                    ),
                            ),
                            const WalletNativeSectionGap(),
                            WalletNativeSection(
                              title: _t('withdrawal_method'),
                              backgroundColor: sectionBackground,
                              child: Column(
                                children: [
                                  WalletNativeChoiceGrid(
                                    spacing: 18,
                                    children: [
                                      if (_withdrawTypesContain(
                                        _withdrawTypes,
                                        wallet: false,
                                      ))
                                        WalletWithdrawMethodTile(
                                          title: _t('bank_card'),
                                          iconAsset:
                                              'assets/images/st_mine_bank_card.png',
                                          selected: _destinationKind == 'bank',
                                          onTap: () {
                                            setState(() {
                                              _destinationKind = 'bank';
                                              _feeInfo = null;
                                              _rateData = null;
                                              _selectedPresetAmount = null;
                                              _resetArrivalConfirmation();
                                            });
                                            _scheduleQuoteRefresh(
                                              immediate: true,
                                            );
                                          },
                                        ),
                                      if (_withdrawTypesContain(
                                        _withdrawTypes,
                                        wallet: true,
                                      ))
                                        WalletWithdrawMethodTile(
                                          title: _t('wallet'),
                                          iconAsset:
                                              'assets/images/st_mine_wallet_sec.png',
                                          selected:
                                              _destinationKind == 'ewallet',
                                          onTap: () {
                                            setState(() {
                                              _destinationKind = 'ewallet';
                                              _feeInfo = null;
                                              _rateData = null;
                                              _selectedPresetAmount = null;
                                              _resetArrivalConfirmation();
                                            });
                                            _scheduleQuoteRefresh(
                                              immediate: true,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 13),
                                  WalletWithdrawChannelBlock(
                                    title: _destinationKind == 'bank'
                                        ? _t('receiving_bank')
                                        : '',
                                    child: _destinationKind == 'bank'
                                        ? _bankChannel()
                                        : _eWalletChannel(),
                                  ),
                                ],
                              ),
                            ),
                            const WalletNativeSectionGap(),
                            WalletNativeSection(
                              title: '',
                              topPadding: 12,
                              backgroundColor: sectionBackground,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_withdrawPresetAmounts.isNotEmpty) ...[
                                    Text(
                                      _t('withdraw_custom_amount'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.2,
                                        color: WalletDepositNativeColors
                                            .textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    WalletWithdrawPresetAmountGrid(
                                      amounts: _withdrawPresetAmounts,
                                      currency: _isCnyWithdrawInputMode
                                          ? 'CNY'
                                          : _sourceCurrencyCode,
                                      selectedAmount: _selectedPresetAmount,
                                      onSelected: (amount) {
                                        setState(() {
                                          _selectedPresetAmount = amount;
                                          _amountCtrl.text = amount;
                                          _feeInfo = null;
                                          _resetArrivalConfirmation();
                                        });
                                        _scheduleQuoteRefresh();
                                      },
                                    ),
                                    const SizedBox(height: 22),
                                  ],
                                  WalletWithdrawAmountHeader(
                                    availableText:
                                        _withdrawAvailableDisplayText,
                                    title: _t('withdraw_custom_amount'),
                                    availableLabel: _t(
                                      'withdraw_can_withdraw_short',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  WalletNativeAmountField(
                                    controller: _amountCtrl,
                                    focusNode: _amountFocus,
                                    unit: _withdrawInputUnit,
                                    hintText: _withdrawInputUnit == '¥'
                                        ? _t('withdraw_custom_amount_integer')
                                        : _t('withdrawal_input_tip'),
                                    errorText: _amountValidationError,
                                    style: WalletNativeAmountFieldStyle
                                        .withdrawFramed,
                                    onChanged: (_) {
                                      setState(() {
                                        _selectedPresetAmount = null;
                                        _feeInfo = null;
                                        _resetArrivalConfirmation();
                                      });
                                      _scheduleQuoteRefresh();
                                    },
                                  ),
                                  if (_withdrawRateLineText != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _withdrawRateLineText!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.2,
                                        color:
                                            WalletDepositNativeColors.textPrimaryOf(
                                              context,
                                            ),
                                      ),
                                    ),
                                  ],
                                  if (_withdrawConfirmDetailRows != null) ...[
                                    const SizedBox(height: 20),
                                    WalletWithdrawConfirmDetails(
                                      receivedAmount:
                                          _withdrawConfirmDetailRows!['received']!,
                                      convertedAmount:
                                          _withdrawConfirmDetailRows!['converted']!,
                                      feeAmount:
                                          _withdrawConfirmDetailRows!['fee']!,
                                      deductAmount:
                                          _withdrawConfirmDetailRows!['deduct']!,
                                      title: _t('withdraw_confirm_details'),
                                      receivedLabel: _t(
                                        'withdraw_received_cny',
                                      ),
                                      convertedLabel: _t(
                                        'withdraw_converted_usd',
                                      ),
                                      feeLabel: _t('server_fee'),
                                      deductLabel: _t(
                                        'withdraw_actual_withdraw_amount',
                                      ),
                                      onReceivedInfoTap: () =>
                                          showWithdrawDetailHintSheet(
                                            context,
                                            WithdrawDetailHintType.received,
                                          ),
                                      onConvertedInfoTap: () =>
                                          showWithdrawDetailHintSheet(
                                            context,
                                            WithdrawDetailHintType.converted,
                                          ),
                                    ),
                                  ] else if (_feeInfo != null) ...[
                                    const SizedBox(height: 12),
                                    _feeSummary(),
                                  ],
                                ],
                              ),
                            ),
                            const WalletNativeSectionGap(height: 16),
                            WalletNativeTip(
                              text: _t('withdraw_bottom_tip_content'),
                            ),
                            const SizedBox(height: 96),
                          ],
                        ),
                      ),
                      if (_withdrawExpectedArrivalBannerParts != null)
                        _withdrawExpectedArrivalBanner(
                          _withdrawExpectedArrivalBannerParts!,
                        ),
                      WalletNativeBottomBar(
                        mode: WalletNativeBottomBarMode.withdraw,
                        primaryText: _t('withdraw_confirm_and_submit'),
                        enabled: _baseCanSubmit,
                        loading: _isSubmitting,
                        onPressed: _submitWithdraw,
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

  Widget _bankChannel() {
    if (_cards.isEmpty) {
      return _emptyChannel(_t('flutter_withdraw_no_bound_bank_card'));
    }
    final card = _selectedCard ?? _cards.first;
    return WalletWithdrawDestinationTile(
      title: '${card.bankName} ${card.maskedCardNumber}',
      subtitle: card.currency,
      selected: true,
      onTap: _showBankSheet,
    );
  }

  Widget _eWalletChannel() {
    if (_eWallets.isEmpty) {
      return _emptyChannel(_t('flutter_withdraw_no_bound_ewallet'));
    }
    final wallet = _selectedEWallet ?? _eWallets.first;
    return WalletWithdrawDestinationTile(
      title: _eWalletLabel(wallet),
      subtitle: wallet['network']?.toString(),
      iconAsset: 'assets/images/st_mine_wallet_sec.png',
      selected: true,
      onTap: _showEWalletSheet,
    );
  }

  Widget _emptyChannel(String text) {
    final isBank = _destinationKind == 'bank';
    return InkWell(
      onTap: () => context.push(isBank ? '/mine/bankcard' : '/mine/ewallet'),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: double.infinity,
        height: 147,
        decoration: BoxDecoration(
          color: WalletDepositNativeColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: WalletDepositNativeColors.borderOf(context),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBank
                  ? Icons.add_card_rounded
                  : Icons.account_balance_wallet_rounded,
              size: 56,
              color: WalletDepositNativeColors.textTertiaryOf(
                context,
              ).withValues(alpha: 0.45),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: WalletDepositNativeColors.textTertiaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_t('server_fee')}: ${WalletDepositWithdrawContract.feeAmount(_feeInfo)}',
          ),
          if (_feeTargetCurrencyAmount() != null)
            Text(
              '${_t('flutter_withdraw_estimated_arrival')}: ${_feeTargetCurrencyAmount()} $_destinationCurrency',
            ),
          if (_feeInfo!['estimated_arrival'] != null)
            Text(
              '${_t('flutter_withdraw_estimated_arrival')}: ${_feeInfo!['estimated_arrival']}',
            ),
          if (_feeInfo!['net_amount'] != null)
            Text(
              '${_t('flutter_withdraw_actual_arrival')}: ${_feeInfo!['net_amount']}',
            ),
        ],
      ),
    );
  }

  Widget _withdrawExpectedArrivalBanner(Map<String, String> parts) {
    final warning = _arrivalConfirmAttempted && !_arrivalConfirmed;
    return InkWell(
      key: ValueKey(
        _arrivalConfirmed
            ? 'wallet_withdraw_expected_banner_checked'
            : 'wallet_withdraw_expected_banner_unchecked',
      ),
      onTap: () {
        setState(() {
          _arrivalConfirmed = !_arrivalConfirmed;
          _arrivalConfirmAttempted = false;
        });
      },
      child: Container(
        width: double.infinity,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF222B3E)
            : const Color(0xFFF5F8FF),
        padding: EdgeInsets.fromLTRB(25, 9, 25, _arrivalConfirmed ? 9 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _arrivalConfirmed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: WalletDepositNativeColors.blue,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: RichText(
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textScaler: TextScaler.noScaling,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: WalletDepositNativeColors.textSecondaryOf(
                          context,
                        ),
                      ),
                      children: [
                        TextSpan(text: _t('withdraw_estimated_summary_prefix')),
                        TextSpan(
                          text: parts['received'],
                          style: TextStyle(
                            color: WalletDepositNativeColors.textPrimaryOf(
                              context,
                            ),
                          ),
                        ),
                        TextSpan(text: _t('withdraw_estimated_summary_mid')),
                        TextSpan(
                          text: parts['deduct'],
                          style: TextStyle(
                            color: WalletDepositNativeColors.textPrimaryOf(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!_arrivalConfirmed) ...[
              const SizedBox(height: 7),
              Text(
                _t('withdraw_dual_unconfirmed_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: warning
                      ? const Color(0xFFFFB30F)
                      : WalletDepositNativeColors.blue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSourceSheet() async {
    final selected = await showModalBottomSheet<WalletFundingAccount>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (ctx) => WalletNativeAccountPickerSheet(
        accounts: _sourceAccounts,
        selectedKey: _selectedSource?.key,
        onSelected: (account) => Navigator.of(ctx).pop(account),
      ),
    );
    if (selected != null && mounted && selected.key != _selectedSource?.key) {
      setState(() {
        _selectedSource = selected;
        _feeInfo = null;
        _rateData = null;
        _selectedPresetAmount = null;
        _resetArrivalConfirmation();
      });
      _scheduleQuoteRefresh(immediate: true);
    }
  }

  Future<void> _showBankSheet() async {
    final selected = await showModalBottomSheet<BankCardModel>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (ctx) => WalletNativeBankPickerSheet(
        cards: _cards,
        selectedId: _selectedCard?.id,
        onSelected: (card) => Navigator.of(ctx).pop(card),
        onAddBank: () {
          Navigator.of(ctx).pop();
          context.push('/mine/bankcard/add');
        },
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCard = selected;
        _feeInfo = null;
        _rateData = null;
        _selectedPresetAmount = null;
        _resetArrivalConfirmation();
      });
      _scheduleQuoteRefresh(immediate: true);
    }
  }

  Future<void> _showEWalletSheet() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (ctx) => WalletNativeEWalletPickerSheet(
        wallets: _eWallets,
        selectedId: '${_selectedEWallet?['id'] ?? ''}',
        labelBuilder: _eWalletLabel,
        onSelected: (wallet) => Navigator.of(ctx).pop(wallet),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedEWallet = selected;
        _feeInfo = null;
        _rateData = null;
        _selectedPresetAmount = null;
        _resetArrivalConfirmation();
      });
      _scheduleQuoteRefresh(immediate: true);
    }
  }
}
