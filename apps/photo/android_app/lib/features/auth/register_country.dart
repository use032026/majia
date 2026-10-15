import 'package:flutter/material.dart';

import '../../core/models/country_model.dart';
import 'select_country_page.dart';

export '../../core/models/country_model.dart';
export 'select_country_page.dart';

/// 兼容旧命名（注册流程沿用 `RegisterCountry`）
typedef RegisterCountry = CountryModel;

extension RegisterCountryCompat on CountryModel {
  String get name => value;
  String get dialCode => code.startsWith('+') ? code : '+$code';
  String get flag => flagEmoji;
}

/// 打开居住国家/地区选择页（替代旧 bottom sheet）
Future<CountryModel?> showRegisterCountryPicker(
  BuildContext context, {
  required CountryModel current,
}) {
  return openSelectCountryPage(
    context,
    selectedCountryKey: current.key,
  );
}

CountryModel? registerCountryByKey(String? key) {
  return CountryModel.fromKey(key, CountryModel.fallbackDefaults);
}

CountryModel? registerCountryByDialCode(String dial) {
  return CountryModel.fromDialCode(dial, CountryModel.fallbackDefaults);
}
