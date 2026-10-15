Map<String, dynamic> _accountPayload(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return const {};
  final inner = data['data'];
  if (inner is Map && !_hasAccountMarginKeys(data)) {
    return Map<String, dynamic>.from(inner);
  }
  return data;
}

bool _hasAccountMarginKeys(Map<String, dynamic> data) {
  return data.containsKey('margin_free') ||
      data.containsKey('free_margin') ||
      data.containsKey('equity') ||
      data.containsKey('margin_used') ||
      data.containsKey('used_margin') ||
      data.containsKey('margin');
}

String tradeFreeMarginDisplayFromAccountData(Map<String, dynamic>? data) {
  final payload = _accountPayload(data);
  final explicitFree = _firstNumber(payload, const [
    'margin_free',
    'free_margin',
  ]);
  if (explicitFree != null) {
    return explicitFree.toStringAsFixed(2);
  }

  final equity = _numberValue(payload['equity']);
  final used = _firstNumber(payload, const ['margin_used', 'used_margin']);
  if (equity != null || used != null) {
    return ((equity ?? 0) - (used ?? 0)).toStringAsFixed(2);
  }

  return '0.00';
}

double? _firstNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _numberValue(data[key]);
    if (value != null) return value;
  }
  return null;
}

double? _numberValue(Object? value) {
  if (value == null || value == '--') return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty || text == '--') return null;
  return double.tryParse(text.replaceAll(',', ''));
}
