import 'dart:convert';

const _h5AddressKeys = <String>{
  'partner_url',
  'taskcenter_url',
  'vip_center_url',
  'trader_exam_url',
  'customer_support_url',
  'trader_exam_middle_page_url',
  'trading_explanation_url',
  'trader_center_url',
  'official_website_a_url',
  'official_website_b_url',
  'trader_profit_url',
  'trader_profit_order_url',
  'my_follow_order_url',
  'trader_order_details_url',
  'trading_copy_url',
  'code_verify_url',
  'user_agreement_url',
  'privacy_policy_url',
  'trade_unlock_activity_url',
  'captcha_api_key',
};

Map<String, dynamic> normalizeH5AddressPayload(dynamic raw) {
  final normalized = _normalizeH5AddressPayload(raw);
  return normalized == null
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(normalized);
}

Map<String, dynamic>? _normalizeH5AddressPayload(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      return _normalizeH5AddressPayload(jsonDecode(value));
    } catch (_) {
      return null;
    }
  }
  if (raw is! Map) return null;

  final map = Map<String, dynamic>.from(raw);
  if (_containsH5AddressKey(map)) return map;

  final h5Config = _normalizeH5AddressPayload(map['h5_config']);
  if (h5Config != null && h5Config.isNotEmpty) return h5Config;

  final data = _normalizeH5AddressPayload(map['data']);
  if (data != null && data.isNotEmpty) return data;

  if (map.containsKey('code') || map.containsKey('message')) return null;
  return map;
}

bool _containsH5AddressKey(Map<String, dynamic> map) {
  for (final key in _h5AddressKeys) {
    if (map.containsKey(key)) return true;
  }
  return false;
}
