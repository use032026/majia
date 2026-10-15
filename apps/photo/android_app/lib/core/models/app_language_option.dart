import '../constants/ios_language_catalog.dart';

/// 语言设置单列一项（对齐 iOS：数据来自 violet/api/account/languages/available）
final class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.label,
    this.sortOrder,
  });

  /// 已 canonical 的 code（用于存储、请求头 X-Language）
  final String code;

  /// 展示名（接口下发当前环境下的文案）
  final String label;

  /// 可选：接口提供的排序序号（iOS 页面保留服务端返回顺序，本字段仅保留兜底/日志用途）
  final int? sortOrder;

  static List<AppLanguageOption> fallbackFromIosCatalog() {
    return IosLanguageCatalog.orderedRows
        .map((e) => AppLanguageOption(code: e.$1, label: e.$2))
        .toList();
  }

  /// 解析 `/api/account/languages/available` → `data.languages`。
  /// 字段名兼容多版本后端 / 与原生端模型差异。
  static List<AppLanguageOption> fromAvailableLanguagesPayload(
    List<dynamic> raw,
  ) {
    final parsed = <_RawLangOpt>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final code = _pickStr(m, const [
        'code',
        'language',
        'lang',
        'languageCode',
        'language_code',
        'locale',
        'localeId',
        'locale_id',
      ]);
      if (code == null || code.trim().isEmpty) continue;

      parsed.add(_RawLangOpt(
        rawCode: code.trim(),
        name: _pickStr(m, const [
          'name',
          'title',
          'display_name',
          'displayName',
          'label',
          'text',
          'language_name',
          'languageName',
        ]),
        order: _pickInt(m, const [
          'sort',
          'sort_order',
          'sortOrder',
          'order',
          'weight',
          'index',
          'seq',
          'priority',
          'rank',
        ]),
      ));
    }

    final seen = <String>{};
    final out = <AppLanguageOption>[];
    for (final p in parsed) {
      final canon = IosLanguageCatalog.canonicalize(p.rawCode);
      if (canon.isEmpty || seen.contains(canon)) continue;
      seen.add(canon);
      final label = (p.name != null && p.name!.trim().isNotEmpty)
          ? p.name!.trim()
          : IosLanguageCatalog.displayLabelZh(canon);
      out.add(AppLanguageOption(
        code: canon,
        label: label,
        sortOrder: p.order,
      ));
    }

    // iOS `STLanguageSetViewController` 直接遍历 `languageList`，保持服务端顺序。
    return out;
  }
}

String? _pickStr(Map<String, dynamic> map, List<String> keys) {
  for (final k in keys) {
    final v = map[k];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  return null;
}

int? _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final k in keys) {
    final v = map[k];
    if (v == null) continue;
    if (v is num) return v.toInt();
    final n = int.tryParse(v.toString().trim());
    if (n != null) return n;
  }
  return null;
}

class _RawLangOpt {
  _RawLangOpt({
    required this.rawCode,
    this.name,
    this.order,
  });

  final String rawCode;
  final String? name;
  final int? order;
}
