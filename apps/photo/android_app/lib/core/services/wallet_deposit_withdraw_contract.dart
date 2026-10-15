import '../crypto/st_hmac_sha256.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

enum WalletFundingAccountRole { trade, wallet }

enum WalletWithdrawDestinationKind { bank, eWallet }

class WalletFundingAccount {
  const WalletFundingAccount({
    required this.role,
    required this.id,
    required this.platform,
    required this.label,
    this.currency = '',
    this.balance = '',
    this.canDraw = '',
    this.raw = const <String, dynamic>{},
  });

  final WalletFundingAccountRole role;
  final String id;
  final String platform;
  final String label;
  final String currency;
  final String balance;
  final String canDraw;
  final Map<String, dynamic> raw;

  String get key => '${role.name}|$id';
  String get effectivePlatform => role == WalletFundingAccountRole.wallet
      ? 'WALLET'
      : _nonEmpty(platform, 'MT5');
}

class WalletDepositWithdrawContract {
  const WalletDepositWithdrawContract._();

  static List<Map<String, dynamic>> depositChannelsFromResponse(dynamic root) {
    final data = root is Map ? root['data'] : root;
    final candidate = data is Map ? data['pay_channels'] : data;
    if (candidate is! List) return const [];
    return candidate
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static String channelId(Map<String, dynamic> channel) {
    return _firstString(channel, const ['id', 'pay_channel_id', 'channel_id']);
  }

  static List<String> presetAmounts(Map<String, dynamic> channel) {
    final raw = channel['pay_channel_amount'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e['amount']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String defaultDepositAmount(Map<String, dynamic>? channel) {
    if (channel == null) return '';
    final presets = presetAmounts(channel);
    return presets.isEmpty ? '' : presets.first;
  }

  static List<String> depositChannelAuthMethods(Map<String, dynamic>? channel) {
    if (channel == null) return const [];
    final result = <String>[];
    if (_apiBool(channel['need_phone'])) {
      result.add('bind_tel');
    }
    if (_apiBool(channel['need_name'])) {
      result.add('document_verify');
    }
    if (_apiBool(channel['need_email'])) {
      result.add('bind_email');
    }
    return result;
  }

  static List<String> depositChannelMissingAuthMethods({
    required Map<String, dynamic>? channel,
    required bool isAuthed,
    required bool isBindPhone,
    required bool isBindEmail,
  }) {
    final missing = <String>[];
    for (final method in depositChannelAuthMethods(channel)) {
      switch (method) {
        case 'bind_tel':
          if (!isBindPhone) missing.add(method);
        case 'document_verify':
          if (!isAuthed) missing.add(method);
        case 'bind_email':
          if (!isBindEmail) missing.add(method);
      }
    }
    return missing;
  }

  static String? depositValidationError({
    required Map<String, dynamic>? channel,
    required String amount,
  }) {
    if (channel == null) return stLocalizedTextFromZhHans('请选择支付渠道');
    final value = double.tryParse(amount.trim());
    if (value == null || value <= 0) {
      return stLocalizedTextFromZhHans('请输入有效金额');
    }
    final min = double.tryParse(_firstString(channel, const ['min_amount']));
    final max = double.tryParse(_firstString(channel, const ['max_amount']));
    if (min != null && value < min) return 'max_charge_amount';
    if (max != null && value > max) return 'max_charge_amount';
    return null;
  }

  static String? depositCustomizedAmountValidationError({
    required Map<String, dynamic>? channel,
    required String amount,
    required bool isManualInput,
    required bool isRealAccount,
  }) {
    if (!isManualInput || !isRealAccount || channel == null) return null;
    if (!_apiBool(channel['customized_status'])) return null;

    final type = int.tryParse(channel['identification']?.toString() ?? '');
    if (type != 1 && type != 2) return null;

    final input = _cleanNumericString(amount);
    final min = _cleanNumericString(channel['min_customized_amount']);
    final step = _cleanNumericString(channel['step_amount']);
    if (!_isDecimalText(input) || !_isDecimalText(min)) return null;

    final thresholdCompare = _compareDecimalText(input, min);
    final minText = _normalizedDecimalText(min);
    final stepText = _normalizedDecimalText(step);
    if (type == 1 && thresholdCompare < 0) {
      return '自定义金额需不低于$minText';
    }
    if (type == 1 && thresholdCompare == 0) {
      return null;
    }
    if (type == 2 && thresholdCompare <= 0) {
      return '自定义金额需大于最小金额$minText';
    }

    if (!_isDecimalText(step) || _compareDecimalText(step, '0') <= 0) {
      return null;
    }

    final scale = [
      _fractionDigits(input),
      _fractionDigits(min),
      _fractionDigits(step),
    ].reduce((a, b) => a > b ? a : b);
    final inputUnits = _scaledDecimalInt(input, scale);
    final minUnits = _scaledDecimalInt(min, scale);
    final stepUnits = _scaledDecimalInt(step, scale);
    if (inputUnits == null || minUnits == null || stepUnits == null) {
      return null;
    }
    final diffUnits = inputUnits - minUnits;
    if (diffUnits > BigInt.zero && diffUnits % stepUnits != BigInt.zero) {
      return '自定义金额需以$minText为起点，按$stepText递增';
    }
    return null;
  }

  static Map<String, dynamic> buildDepositPayload({
    required Map<String, dynamic> channel,
    required String amount,
    required WalletFundingAccount account,
  }) {
    return {
      'pay_channel_id': channelId(channel),
      'amount': amount.trim(),
      'account': account.id,
      'account_platform': account.effectivePlatform,
    };
  }

  static Map<String, dynamic> buildDepositFeePayload({
    required Map<String, dynamic> channel,
    required String amount,
  }) {
    return {'amount': amount.trim(), 'id': channelId(channel)};
  }

  static bool needsDepositExchangeRate({
    required Map<String, dynamic> channel,
    required WalletFundingAccount account,
  }) {
    final sourceCurrency = account.currency.toUpperCase();
    final channelCurrency = _firstString(channel, const [
      'currency',
      'pay_currency',
      'account_currency',
    ]).toUpperCase();
    return sourceCurrency.isNotEmpty &&
        channelCurrency.isNotEmpty &&
        sourceCurrency != channelCurrency;
  }

  static Map<String, dynamic> buildDepositExchangeRateParams({
    required Map<String, dynamic> channel,
    required WalletFundingAccount account,
    String formAmount = '1',
  }) {
    final fromCurrency = _firstString(channel, const [
      'currency',
      'pay_currency',
    ]);
    final toCurrency = account.currency.isNotEmpty ? account.currency : 'USD';
    if (fromCurrency.isEmpty ||
        toCurrency.isEmpty ||
        fromCurrency == toCurrency) {
      return {};
    }
    return {
      'from_currency': fromCurrency,
      'form_amount': formAmount,
      'to_currency': toCurrency,
      'type': '0',
    };
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static double? _positiveDouble(Object? value) {
    final parsed = _toDouble(value);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static bool _apiBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  static String _cleanNumericString(Object? value) {
    if (value == null) return '';
    return value.toString().trim().replaceAll(',', '');
  }

  static bool _isDecimalText(String value) {
    if (value.isEmpty || value == '.') return false;
    return RegExp(r'^-?(?:\d+|\d*\.\d+)$').hasMatch(value);
  }

  static int _fractionDigits(String value) {
    final dot = value.indexOf('.');
    if (dot < 0) return 0;
    return value.length - dot - 1;
  }

  static int _compareDecimalText(String left, String right) {
    final scale = _fractionDigits(left) > _fractionDigits(right)
        ? _fractionDigits(left)
        : _fractionDigits(right);
    final leftUnits = _scaledDecimalInt(left, scale);
    final rightUnits = _scaledDecimalInt(right, scale);
    if (leftUnits == null || rightUnits == null) return 0;
    return leftUnits.compareTo(rightUnits);
  }

  static BigInt? _scaledDecimalInt(String value, int scale) {
    if (!_isDecimalText(value)) return null;
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final integer = parts.first.isEmpty ? '0' : parts.first;
    final fraction = parts.length > 1 ? parts[1] : '';
    final paddedFraction = fraction.padRight(scale, '0');
    final units = BigInt.tryParse('$integer$paddedFraction');
    if (units == null) return null;
    return negative ? -units : units;
  }

  static String _normalizedDecimalText(String value) {
    if (!_isDecimalText(value)) return value;
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final integer = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (parts.length == 1) return '${negative ? '-' : ''}$integer';
    final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
    final prefix = '${negative ? '-' : ''}${integer.isEmpty ? '0' : integer}';
    return fraction.isEmpty ? prefix : '$prefix.$fraction';
  }

  static String? depositExchangeRate(Map<String, dynamic> rateData) {
    final data = apiDataMap(rateData);
    final toAmount = _toDouble(data['to_amount']);
    final normal = _toDouble(data['rate']);
    final derivative = _toDouble(data['rate_derivative']);
    if (toAmount != null && toAmount > 0 && derivative == null) {
      return _formatRate(toAmount);
    }
    if (toAmount != null && toAmount > 1) {
      return normal == null ? _formatRate(toAmount) : _formatRate(normal);
    }
    if (derivative != null) {
      return _formatRate(derivative);
    }
    return normal == null ? null : _formatRate(normal);
  }

  static String? withdrawCnyPerAccountRate(
    Map<String, dynamic>? rateData, {
    String accountCurrency = '',
  }) {
    if (rateData == null) return null;
    final data = apiDataMap(rateData);
    if (data.isEmpty) return null;
    final from = _firstString(data, const ['from_currency']);
    final to = _firstString(data, const ['to_currency']);
    final fromCny = _withdrawCurrencyIsCny(from);
    final toCny = _withdrawCurrencyIsCny(to);
    final formAmount = _positiveDouble(data['form_amount']) ?? 1;
    final toAmount = _positiveDouble(data['to_amount']);
    final rate = _positiveDouble(data['rate']);
    final derivative = _positiveDouble(data['rate_derivative']);

    if (fromCny && to.isNotEmpty && !toCny) {
      if (toAmount != null && toAmount > 1) return _formatFixedRate(toAmount);
      if (derivative != null && derivative > 1) {
        return _formatFixedRate(derivative);
      }
      if (rate != null) return _formatFixedRate(rate);
      if (toAmount != null) return _formatFixedRate(formAmount / toAmount);
      if (derivative != null) {
        return _formatFixedRate(derivative <= 1 ? 1 / derivative : derivative);
      }
    }

    if (toCny && from.isNotEmpty && !fromCny) {
      if (toAmount != null && toAmount > formAmount) {
        return _formatFixedRate(toAmount);
      }
      if (rate != null) return _formatFixedRate(rate);
      if (toAmount != null) return _formatFixedRate(formAmount / toAmount);
    }

    final effective = _withdrawEffectiveRate(data);
    return effective == null ? null : _formatFixedRate(effective);
  }

  static String? withdrawCnyInputRateLineText({
    required Map<String, dynamic>? rateData,
    required String accountCurrency,
  }) {
    final rate = withdrawCnyPerAccountRate(
      rateData,
      accountCurrency: accountCurrency,
    );
    if (rate == null) return null;
    final unit = accountCurrency.trim().isEmpty
        ? 'USD'
        : accountCurrency.trim();
    return '$rate CNY = 1.00 $unit';
  }

  static String depositReferenceRateText({
    required String channelCurrency,
    required String accountCurrency,
    required Map<String, dynamic> rateData,
  }) {
    final channel = channelCurrency.trim();
    final account = accountCurrency.trim();
    if (channel.isEmpty || account.isEmpty) return '';
    final rateText = depositExchangeRate(rateData);
    final rate = _toDouble(rateText);
    if (rate == null || rate <= 0) return '';
    if (rate > 1) {
      return '1$channel ≈ ${_formatRate(rate)}$account';
    }
    final data = apiDataMap(rateData);
    var positive = _toDouble(data['rate']);
    if (positive == null || positive <= 1) {
      positive = 1 / rate;
    }
    return '1$account ≈ ${_formatRate(positive)}$channel';
  }

  static String convertAmountText({
    required String sourceAmount,
    required String targetCurrency,
    Map<String, dynamic>? rateData,
    int precision = 2,
  }) {
    final src = double.tryParse(sourceAmount.trim());
    if (src == null || src <= 0) return '';
    final rateText = rateData == null ? null : depositExchangeRate(rateData);
    final rate = _toDouble(rateText);
    if (rate == null) return '';
    final value = src * rate;
    return '${_formatAmount(value, precision: precision)}($targetCurrency)';
  }

  static String _formatAmount(num value, {int precision = 2}) {
    final fixed = value.toStringAsFixed(precision);
    if (precision == 0) return fixed;
    return fixed
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  static String _formatRate(num value) {
    return _formatAmount(value, precision: 10);
  }

  static String _formatFixedRate(num value) {
    return value.toStringAsFixed(2);
  }

  static double? _withdrawEffectiveRate(Map<String, dynamic> data) {
    final toAmount = _positiveDouble(data['to_amount']);
    if (toAmount != null && toAmount > 1) return toAmount;
    final derivative = _positiveDouble(data['rate_derivative']);
    if (derivative != null && derivative > 1) return derivative;
    final rate = _positiveDouble(data['rate']);
    if (rate != null && rate > 1) return rate;
    if (derivative != null) return derivative;
    return toAmount;
  }

  static String buildWithdrawFeeRequestKey({
    required String destinationKind,
    required String destinationId,
    required String amount,
  }) {
    return '$destinationKind|$destinationId|$amount';
  }

  static Map<String, dynamic> buildWithdrawFeePayload({
    required WalletWithdrawDestinationKind destinationKind,
    required String amount,
    required Map<String, dynamic> destination,
  }) {
    final payload = <String, dynamic>{'amount': amount.trim()};
    final destinationId = _firstString(destination, const [
      'id',
      'card_id',
      'cardId',
    ]);
    if (destinationId.isNotEmpty) {
      payload['pay_channel_id'] = destinationId;
    }
    payload['type'] = destinationKind == WalletWithdrawDestinationKind.bank
        ? 'BankCard'
        : 'Wallet';
    return payload;
  }

  static Map<String, dynamic> buildWithdrawRateParams({
    required WalletWithdrawDestinationKind destinationKind,
    required Map<String, dynamic> destination,
    required WalletFundingAccount source,
  }) {
    final rawFromCurrency = _firstString(destination, const [
      'currency',
      'wallet_currency',
    ]);
    final fromCurrency =
        destinationKind == WalletWithdrawDestinationKind.bank &&
            _withdrawCurrencyIsCny(rawFromCurrency)
        ? 'CNY'
        : rawFromCurrency.trim();
    final rawToCurrency = source.currency.isNotEmpty ? source.currency : 'USD';
    final toCurrency = _withdrawCurrencyIsCny(rawToCurrency)
        ? 'CNY'
        : rawToCurrency.trim();
    if (fromCurrency.isEmpty ||
        toCurrency.isEmpty ||
        fromCurrency == toCurrency) {
      return {};
    }
    return {
      'from_currency': fromCurrency,
      'to_currency': toCurrency,
      'type': '1',
      'form_amount': '1',
    };
  }

  static bool withdrawDrawMethodIsWalletType(Object? apiType) {
    final text = apiType?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return false;
    return text.contains('wallet') ||
        text.contains('crypto') ||
        text.contains('ewallet');
  }

  static List<Map<String, dynamic>> withdrawEffectiveTypeConfigs(
    List<Map<String, dynamic>> storedTypes,
  ) {
    if (storedTypes.isNotEmpty) return storedTypes;
    return const [
      {'type': 'BankCard', 'pay_type': 'PAY_TYPE_BANK'},
      {'type': 'Wallet', 'pay_type': 'PAY_TYPE_CRYPTO'},
    ];
  }

  static Map<String, dynamic>? withdrawTypeConfigForKind(
    List<Map<String, dynamic>> storedTypes,
    WalletWithdrawDestinationKind kind,
  ) {
    final isWallet = kind == WalletWithdrawDestinationKind.eWallet;
    for (final cfg in withdrawEffectiveTypeConfigs(storedTypes)) {
      if (withdrawDrawMethodIsWalletType(cfg['type']) == isWallet) {
        return cfg;
      }
    }
    return null;
  }

  static Map<String, dynamic>? withdrawTemplateForTypeConfig({
    required Map<String, dynamic>? typeConfig,
    required String channelCurrency,
    required String accountCurrency,
    required List<Map<String, dynamic>> templates,
  }) {
    if (templates.isEmpty) return null;
    final cfg = typeConfig ?? const <String, dynamic>{};
    Map<String, dynamic>? best;
    var bestScore = -1 << 30;
    for (final template in templates) {
      if (!_withdrawTemplateMatchesContext(
        template: template,
        channelCurrency: channelCurrency,
        accountCurrency: accountCurrency,
        typeConfig: cfg,
      )) {
        continue;
      }
      final score = _withdrawTemplateMatchScore(
        template: template,
        typeConfig: cfg,
        channelCurrency: channelCurrency,
      );
      if (score > bestScore) {
        bestScore = score;
        best = template;
      }
    }
    if (best != null) return best;

    final cfgWallet = withdrawDrawMethodIsWalletType(cfg['type']);
    for (final template in templates) {
      final tplCrypto = _withdrawTemplateIsCryptoStyle(template);
      if (cfgWallet && !tplCrypto) continue;
      if (!cfgWallet && tplCrypto) continue;
      final score = _withdrawTemplateMatchScore(
        template: template,
        typeConfig: cfg,
        channelCurrency: channelCurrency,
      );
      if (score > bestScore) {
        bestScore = score;
        best = template;
      }
    }
    return best;
  }

  static String? withdrawTargetCurrencyAmount({
    required String amount,
    String fee = '',
    required String targetCurrency,
    required bool destinationIsBank,
    required Map<String, dynamic>? rateData,
  }) {
    if (targetCurrency.isEmpty) return null;
    final src = _toDouble(amount);
    if (src == null || src <= 0) return null;
    final feeValue = _toDouble(fee) ?? 0;
    final rateText = destinationIsBank && _withdrawCurrencyIsCny(targetCurrency)
        ? withdrawCnyPerAccountRate(rateData, accountCurrency: '')
        : (rateData == null ? null : depositExchangeRate(rateData));
    final rate = _toDouble(rateText);
    if (rate == null) return null;
    final net = src - feeValue;
    if (net <= 0) return null;
    final target = net * rate;
    if (destinationIsBank && targetCurrency.toUpperCase() == 'CNY') {
      return target.floor().toString();
    }
    return _formatAmount(target, precision: 2);
  }

  static List<String> withdrawPresetAmountsFromTemplate(
    Map<String, dynamic>? template, {
    required bool cnyInputMode,
  }) {
    if (template == null) return const [];
    final details = template['amount_details'];
    if (details is! List) return const [];
    final result = <String>[];
    for (final rawItem in details) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final raw = cnyInputMode
          ? _firstString(item, const ['target_currency_amount'])
          : _firstString(item, const ['withdraw_amount']);
      final amount = _toDouble(raw);
      if (amount == null) continue;
      result.add(
        cnyInputMode
            ? amount.floor().toString()
            : _formatAmount(amount, precision: 2),
      );
    }
    return result;
  }

  static String? withdrawValidationError({
    required String amount,
    required String available,
    required String destinationCurrency,
    String fee = '',
    bool feeLoaded = false,
    String? actualDeductAmount,
    String? availableForActualDeduct,
  }) {
    final input = _cleanNumericString(amount);
    if (input.isEmpty || input == '.') return null;
    if (!_isDecimalText(input)) return null;

    final upperCurrency = destinationCurrency.toUpperCase();
    if ((upperCurrency.contains('CNY') || upperCurrency.contains('CNH')) &&
        input.contains('.')) {
      return stLocalizedTextFromZhHans('出金金额需为整数');
    }

    final actualDeductText = _cleanNumericString(actualDeductAmount);
    final actualAvailableText = _cleanNumericString(availableForActualDeduct);
    if (_isDecimalText(actualDeductText) &&
        _isDecimalText(actualAvailableText) &&
        _compareDecimalText(actualDeductText, actualAvailableText) > 0) {
      return stLocalizedTextFromZhHans('金额超过可用余额');
    }

    final availableText = _cleanNumericString(available);
    if (_isDecimalText(availableText) &&
        _compareDecimalText(input, availableText) > 0) {
      return stLocalizedTextFromZhHans('金额超过可用余额');
    }

    final feeText = _cleanNumericString(fee);
    if (feeLoaded &&
        _isDecimalText(feeText) &&
        _compareDecimalText(input, feeText) <= 0) {
      return stLocalizedTextFromZhHans('出金金额需大于手续费');
    }
    return null;
  }

  static bool _withdrawTemplateIsCryptoStyle(Map<String, dynamic> template) {
    final draw = _firstString(template, const ['draw_currency']).toUpperCase();
    final name = _firstString(template, const ['name']).toUpperCase();
    return draw.contains('USDT') ||
        draw.contains('BTC') ||
        draw.contains('ETH') ||
        name.contains('USDT') ||
        name.contains('CRYPTO');
  }

  static bool _withdrawPayTypeMatches(Object? left, Object? right) {
    final l = left?.toString().trim().toUpperCase() ?? '';
    final r = right?.toString().trim().toUpperCase() ?? '';
    return l.isNotEmpty && r.isNotEmpty && l == r;
  }

  static bool _withdrawCurrencyIsCny(Object? value) {
    final upper = value?.toString().trim().toUpperCase() ?? '';
    return upper.contains('CNY') || upper.contains('CNH');
  }

  static bool _withdrawCurrencyMatches(Object? left, Object? right) {
    final l = left?.toString().trim().toUpperCase() ?? '';
    final r = right?.toString().trim().toUpperCase() ?? '';
    if (l.isEmpty || r.isEmpty) return false;
    if (l == r) return true;
    if (_withdrawCurrencyIsCny(l) && _withdrawCurrencyIsCny(r)) return true;
    if (l.contains(r) || r.contains(l)) return true;
    return false;
  }

  static bool _withdrawTemplateDrawMatchesChannelExactly({
    required Map<String, dynamic> template,
    required String channelCurrency,
  }) {
    final draw = _firstString(template, const ['draw_currency']).toUpperCase();
    final channel = channelCurrency.trim().toUpperCase();
    return draw.isNotEmpty && channel.isNotEmpty && draw == channel;
  }

  static int _withdrawTemplateMatchScore({
    required Map<String, dynamic> template,
    required Map<String, dynamic> typeConfig,
    required String channelCurrency,
  }) {
    final cfgType = _firstString(typeConfig, const ['type']);
    final cfgPayType = _firstString(typeConfig, const ['pay_type']);
    final tplType = _firstString(template, const ['type']);
    final tplPayType = _firstString(template, const ['pay_type']);
    final cfgWallet = withdrawDrawMethodIsWalletType(cfgType);
    final tplCrypto = _withdrawTemplateIsCryptoStyle(template);
    var score = 0;
    if (_withdrawTemplateDrawMatchesChannelExactly(
      template: template,
      channelCurrency: channelCurrency,
    )) {
      score += 120;
    } else if (_withdrawCurrencyMatches(
      template['draw_currency'],
      channelCurrency,
    )) {
      score += 80;
    }
    if (_withdrawPayTypeMatches(cfgPayType, tplPayType)) score += 40;
    if (cfgType.isNotEmpty &&
        tplType.isNotEmpty &&
        cfgType.toLowerCase() == tplType.toLowerCase()) {
      score += 20;
    } else if (cfgType.isNotEmpty && tplType.isNotEmpty) {
      score -= 30;
    }
    if (tplType.isEmpty && tplPayType.isEmpty) {
      if (cfgWallet && tplCrypto) {
        score += 25;
      } else if (!cfgWallet && !tplCrypto) {
        score += 25;
      }
      if (_withdrawPayTypeMatches(cfgPayType, 'PAY_TYPE_CRYPTO') && tplCrypto) {
        score += 15;
      }
      if (_withdrawPayTypeMatches(cfgPayType, 'PAY_TYPE_BANK') && !tplCrypto) {
        score += 15;
      }
    }
    if (!cfgWallet && _withdrawCurrencyIsCny(template['draw_currency'])) {
      score += 10;
    }
    return score;
  }

  static bool _withdrawTemplateMatchesContext({
    required Map<String, dynamic> template,
    required String channelCurrency,
    required String accountCurrency,
    required Map<String, dynamic> typeConfig,
  }) {
    final drawCurrency = _firstString(template, const ['draw_currency']);
    final tplAccount = _firstString(template, const ['account_currency']);
    final cfgWallet = withdrawDrawMethodIsWalletType(typeConfig['type']);
    final tplCrypto = _withdrawTemplateIsCryptoStyle(template);
    final channel = channelCurrency.trim();
    final channelIsCny = _withdrawCurrencyIsCny(channel);
    final drawIsCny = _withdrawCurrencyIsCny(drawCurrency);

    if (_withdrawCurrencyMatches(drawCurrency, channel)) return true;

    if (cfgWallet) {
      if (channel.isEmpty) return tplCrypto;
      if (tplCrypto &&
          accountCurrency.trim().isNotEmpty &&
          _withdrawCurrencyMatches(tplAccount, accountCurrency)) {
        return true;
      }
      return false;
    }

    if (channel.isEmpty || channelIsCny) {
      return drawIsCny && !tplCrypto;
    }
    if (tplCrypto) return false;
    if (accountCurrency.trim().isNotEmpty &&
        _withdrawCurrencyMatches(tplAccount, accountCurrency) &&
        _withdrawCurrencyMatches(drawCurrency, accountCurrency)) {
      return true;
    }
    return false;
  }

  static String? withdrawCustomizedAmountValidationError({
    required Map<String, dynamic>? template,
    required String amount,
    required bool isManualInput,
    required bool isRealAccount,
  }) {
    if (!isManualInput || !isRealAccount || template == null) return null;
    if (!_apiBool(template['customized_status'])) return null;
    return _customizedAmountValidationError(config: template, amount: amount);
  }

  static String? _customizedAmountValidationError({
    required Map<String, dynamic> config,
    required String amount,
  }) {
    final type = int.tryParse(config['identification']?.toString() ?? '');
    if (type != 1 && type != 2) return null;

    final input = _cleanNumericString(amount);
    final min = _cleanNumericString(config['min_customized_amount']);
    final step = _cleanNumericString(config['step_amount']);
    if (!_isDecimalText(input) || !_isDecimalText(min)) return null;

    final thresholdCompare = _compareDecimalText(input, min);
    final minText = _normalizedDecimalText(min);
    final stepText = _normalizedDecimalText(step);
    if (type == 1 && thresholdCompare < 0) {
      return '自定义金额需不低于$minText';
    }
    if (type == 1 && thresholdCompare == 0) {
      return null;
    }
    if (type == 2 && thresholdCompare <= 0) {
      return '自定义金额需大于最小金额$minText';
    }

    if (!_isDecimalText(step) || _compareDecimalText(step, '0') <= 0) {
      return null;
    }

    final scale = [
      _fractionDigits(input),
      _fractionDigits(min),
      _fractionDigits(step),
    ].reduce((a, b) => a > b ? a : b);
    final inputUnits = _scaledDecimalInt(input, scale);
    final minUnits = _scaledDecimalInt(min, scale);
    final stepUnits = _scaledDecimalInt(step, scale);
    if (inputUnits == null || minUnits == null || stepUnits == null) {
      return null;
    }
    final diffUnits = inputUnits - minUnits;
    if (diffUnits > BigInt.zero && diffUnits % stepUnits != BigInt.zero) {
      return '自定义金额需以$minText为起点，按$stepText递增';
    }
    return null;
  }

  static Map<String, dynamic> apiDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return response;
  }

  static String feeAmount(Map<String, dynamic>? feeData) {
    if (feeData == null) return '';
    final data = apiDataMap(feeData);
    return _firstString(data, const [
      'fee_amount',
      'fee',
      'handing_fee',
      'handling_fee',
      'pay_handing_fee',
    ]);
  }

  static String buildWithdrawRateRequestKey({
    required String destinationKind,
    required String destinationId,
    required String sourceCurrency,
    required String amount,
  }) {
    return '$destinationKind|$destinationId|$sourceCurrency|$amount';
  }

  static List<WalletFundingAccount> fundingAccounts({
    required Iterable<dynamic> tradeAccounts,
    required Iterable<dynamic> wallets,
  }) {
    final result = <WalletFundingAccount>[];
    for (final raw in tradeAccounts) {
      if (raw is! Map) continue;
      final json = Map<String, dynamic>.from(raw);
      final id = _firstString(json, const ['account_id', 'id']);
      if (id.isEmpty) continue;
      final typeRaw =
          int.tryParse(
            _firstString(json, const ['type', 'account_type_num']),
          ) ??
          0;
      if (typeRaw != 0 && typeRaw != 4) {
        continue;
      }
      final label = _firstString(json, const ['account_type', 'account_name']);
      result.add(
        WalletFundingAccount(
          role: WalletFundingAccountRole.trade,
          id: id,
          platform: _firstString(json, const ['platform', 'type_name']),
          label: label.isNotEmpty ? label : _tradeTypeLabel(typeRaw),
          currency: _firstString(json, const ['currency']),
          balance: _firstString(json, const ['balance']),
          canDraw: _firstString(json, const [
            'can_draw',
            'canDraw',
            'margin_free',
          ]),
          raw: json,
        ),
      );
    }
    for (final raw in wallets) {
      if (raw is! Map) continue;
      final json = Map<String, dynamic>.from(raw);
      final id = _firstString(json, const ['wallet_id', 'id']);
      if (id.isEmpty) continue;
      result.add(
        WalletFundingAccount(
          role: WalletFundingAccountRole.wallet,
          id: id,
          platform: 'WALLET',
          label: stLocalizedTextFromZhHans('我的钱包'),
          currency: _firstString(json, const ['currency']),
          balance: _firstString(json, const ['balance']),
          canDraw: _firstString(json, const ['can_draw', 'canDraw', 'balance']),
          raw: json,
        ),
      );
    }
    return result;
  }

  static WalletFundingAccount? defaultDepositSource(
    List<WalletFundingAccount> accounts, {
    int depositTarget = 0,
  }) {
    if (depositTarget == 1) {
      return _firstRole(accounts, WalletFundingAccountRole.wallet);
    }
    return _firstRole(accounts, WalletFundingAccountRole.trade) ??
        _firstRole(accounts, WalletFundingAccountRole.wallet);
  }

  static WalletFundingAccount? defaultWithdrawSource(
    List<WalletFundingAccount> accounts, {
    int depositTarget = 0,
  }) {
    if (depositTarget == 1) {
      return _firstRole(accounts, WalletFundingAccountRole.wallet) ??
          _firstRole(accounts, WalletFundingAccountRole.trade);
    }
    return _firstRole(accounts, WalletFundingAccountRole.trade) ??
        _firstRole(accounts, WalletFundingAccountRole.wallet);
  }

  static Map<String, dynamic> buildWithdrawPayload({
    required WalletWithdrawDestinationKind destinationKind,
    required WalletFundingAccount source,
    required Map<String, dynamic> destination,
    required String amount,
    required String fundPassword,
    String? targetCurrencyAmount,
  }) {
    final destinationId = int.tryParse(
      _firstString(destination, const ['id', 'card_id']),
    );
    if (destinationId == null || destinationId <= 0) {
      throw Exception(
        destinationKind == WalletWithdrawDestinationKind.bank
            ? stLocalizedTextFromZhHans('银行卡 ID 无效')
            : stLocalizedTextFromZhHans('钱包 ID 无效'),
      );
    }
    final sourceId = int.tryParse(source.id);
    if (sourceId == null || sourceId <= 0) {
      throw Exception('withdraw_source_id_invalid');
    }
    final account = destinationKind == WalletWithdrawDestinationKind.bank
        ? _firstString(destination, const ['card_number', 'account'])
        : _firstString(destination, const [
            'payment_address',
            'wallet_address',
            'address',
            'account',
          ]);
    if (account.isEmpty) {
      throw Exception(
        destinationKind == WalletWithdrawDestinationKind.bank
            ? stLocalizedTextFromZhHans('银行卡号为空')
            : stLocalizedTextFromZhHans('钱包地址为空'),
      );
    }

    final payload = <String, dynamic>{
      'type': destinationKind == WalletWithdrawDestinationKind.bank
          ? 'BankCard'
          : 'Wallet',
      'id': destinationId,
      'account': account,
      'amount': amount.trim(),
      'funds_password': stHmacSha256Hex(fundPassword),
      'with_account': sourceId,
      'with_account_platform': source.effectivePlatform,
    };
    final target = targetCurrencyAmount?.trim();
    if (target != null && target.isNotEmpty) {
      payload['target_currency_amount'] = target;
    }
    return payload;
  }

  static String _tradeTypeLabel(int typeRaw) {
    switch (typeRaw) {
      case 0:
      case 4:
        return stLocalizedTextFromZhHans('真实账户');
      case 1:
        return stLocalizedTextFromZhHans('模拟账户');
      case 2:
        return stLocalizedTextFromZhHans('二元期权账户');
      case 3:
        return stLocalizedTextFromZhHans('交易员账户');
      default:
        return stLocalizedTextFromZhHans('交易账户');
    }
  }

  static WalletFundingAccount? _firstRole(
    List<WalletFundingAccount> accounts,
    WalletFundingAccountRole role,
  ) {
    for (final account in accounts) {
      if (account.role == role) return account;
    }
    return null;
  }
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

String _nonEmpty(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}
