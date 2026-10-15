import 'dart:convert';

import 'package:flutter/services.dart';

import '../constants/ios_language_catalog.dart';

/// Flutter equivalent of iOS `STBundle` and `CardBundle` JSON lookups.
///
/// It intentionally mirrors the native fallback contract:
/// current language pack -> English language pack -> original key/text.
class IosLanguageBundle {
  IosLanguageBundle({
    AssetBundle? assetBundle,
    this.globalRoot = 'assets/ios_language/resources',
    this.cardRoot = 'assets/ios_language/cards',
  }) : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final String globalRoot;
  final String cardRoot;
  static final Map<String, Future<Map<String, String>>> _sharedCache = {};

  void clearCache() {
    _sharedCache.clear();
  }

  Future<String> text(String key, {required String languageCode}) {
    return textOrNull(
      key,
      languageCode: languageCode,
    ).then((value) => value ?? key);
  }

  Future<String?> textOrNull(String key, {required String languageCode}) {
    return _lookupValue(root: globalRoot, key: key, languageCode: languageCode);
  }

  Future<String> textFromZhHans(
    String zhHans, {
    required String languageCode,
  }) async {
    final value = await textFromZhHansOrNull(
      zhHans,
      languageCode: languageCode,
    );
    return value ?? zhHans;
  }

  Future<String?> textFromZhHansOrNull(
    String zhHans, {
    required String languageCode,
  }) async {
    final reverse = await _reverseZhHans(root: globalRoot);
    final key = reverse[zhHans];
    if (key == null || key.isEmpty) return null;
    return _lookupValue(root: globalRoot, key: key, languageCode: languageCode);
  }

  Future<String> cardText(
    String cardName,
    String key, {
    required String languageCode,
  }) {
    return cardTextOrNull(
      cardName,
      key,
      languageCode: languageCode,
    ).then((value) => value ?? key);
  }

  Future<String?> cardTextOrNull(
    String cardName,
    String key, {
    required String languageCode,
  }) {
    return _lookupValue(
      root: _cardRoot(cardName),
      key: key,
      languageCode: languageCode,
    );
  }

  Future<String> cardTextFromZhHans(
    String cardName,
    String zhHans, {
    required String languageCode,
  }) async {
    final value = await cardTextFromZhHansOrNull(
      cardName,
      zhHans,
      languageCode: languageCode,
    );
    return value ?? zhHans;
  }

  Future<String?> cardTextFromZhHansOrNull(
    String cardName,
    String zhHans, {
    required String languageCode,
  }) async {
    final root = _cardRoot(cardName);
    final reverse = await _reverseZhHans(root: root);
    final key = reverse[zhHans];
    if (key == null || key.isEmpty) return null;
    return _lookupValue(root: root, key: key, languageCode: languageCode);
  }

  Future<String?> _lookupValue({
    required String root,
    required String key,
    required String languageCode,
  }) async {
    if (key.isEmpty) return '';

    final code = _resourceCode(languageCode);
    if (code == 'zh-Hans' || code == 'zh') {
      final zhHans = await _load(root, 'zh-Hans');
      final value = zhHans[key];
      return (value == null || value.isEmpty) ? null : value;
    }

    final current = await _load(root, code);
    final currentValue = current[key];
    if (currentValue != null && currentValue.isNotEmpty) {
      return currentValue;
    }

    final en = await _load(root, 'en');
    final enValue = en[key];
    return (enValue == null || enValue.isEmpty) ? null : enValue;
  }

  Future<Map<String, String>> _reverseZhHans({required String root}) async {
    final zhHans = await _load(root, 'zh-Hans');
    return <String, String>{
      for (final entry in zhHans.entries) entry.value: entry.key,
    };
  }

  Future<Map<String, String>> _load(String root, String code) {
    final assetPath = '$root/Language-$code.json';
    final cacheKey = '${identityHashCode(_assetBundle)}::$assetPath';
    return _sharedCache.putIfAbsent(cacheKey, () async {
      try {
        final raw = await _assetBundle.loadString(assetPath);
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return const <String, String>{};
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      } catch (_) {
        return const <String, String>{};
      }
    });
  }

  String _cardRoot(String cardName) {
    final clean = cardName.trim();
    return clean.isEmpty ? cardRoot : '$cardRoot/$clean';
  }

  /// iOS `resourceString`: `en-US` -> `en`, `zh-Hans` uses zh-Hans pack,
  /// `zh-Hant` and Portuguese variants keep their full resource names.
  static String _resourceCode(String rawCode) {
    final code = IosLanguageCatalog.canonicalize(rawCode.trim());
    if (code.isEmpty) return 'zh-Hans';
    if (code == 'zh-Hans' || code == 'zh') return 'zh-Hans';
    if (code == 'zh-TW' || code == 'zh-Hant') return 'zh-Hant';
    if (code == 'pt-PT' || code == 'pt-BR') return code;
    if (code == 'pt') return 'pt-BR';
    return code.split('-').first;
  }
}
