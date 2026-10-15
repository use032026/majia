import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_locale_service.dart';
import '../services/ios_language_bundle.dart';
import '../services/user_preference_prefs.dart';

final iosLanguageBundleProvider = Provider<IosLanguageBundle>(
  (ref) => IosLanguageBundle(),
);

final stLocalizationsProvider = Provider<STLocalizations>((ref) {
  final locale = ref.watch(appLocaleProvider);
  final bundle = ref.watch(iosLanguageBundleProvider);
  return STLocalizations(
    bundle: bundle,
    languageCode: languageCodeFromLocale(locale),
  );
});

String stLanguageCodeOfContext(BuildContext context) {
  return languageCodeFromLocale(Localizations.localeOf(context));
}

STLocalizations stLocalizationsOfContext(BuildContext context, WidgetRef ref) {
  final contextLanguageCode = stLanguageCodeOfContext(context);
  final provided = ref.read(stLocalizationsProvider);
  if (provided.languageCode == contextLanguageCode) return provided;
  return STLocalizations.ofContext(
    context,
    bundle: ref.read(iosLanguageBundleProvider),
  );
}

Future<Map<String, String>> loadStLocalizedTextMap(
  BuildContext context,
  WidgetRef ref,
  Map<String, String> fallbacks,
) {
  return stLocalizationsOfContext(context, ref).textMap(fallbacks);
}

/// Unified Flutter entry for iOS-style JSON localization.
///
/// This wraps [IosLanguageBundle] so feature pages do not depend on generated
/// ARB localizations. It mirrors iOS `STBundle` fallback semantics through the
/// bundle layer: current language -> English -> original key/text, then applies
/// the page's existing Simplified Chinese fallback when a key is missing.
class STLocalizations {
  const STLocalizations({
    required IosLanguageBundle bundle,
    required this.languageCode,
  }) : _bundle = bundle;

  factory STLocalizations.ofContext(
    BuildContext context, {
    IosLanguageBundle? bundle,
  }) {
    return STLocalizations(
      bundle: bundle ?? IosLanguageBundle(),
      languageCode: languageCodeFromLocale(Localizations.localeOf(context)),
    );
  }

  final IosLanguageBundle _bundle;
  final String languageCode;

  Future<String> text(String key, {String? fallback}) async {
    final value = await _bundle.textOrNull(key, languageCode: languageCode);
    return value ?? fallback ?? key;
  }

  Future<String> textFromZhHans(String zhHans, {String? fallback}) async {
    final value = await _bundle.textFromZhHansOrNull(
      zhHans,
      languageCode: languageCode,
    );
    return value ?? fallback ?? zhHans;
  }

  Future<String> cardText(
    String cardName,
    String key, {
    String? fallback,
  }) async {
    final value = await _bundle.cardTextOrNull(
      cardName,
      key,
      languageCode: languageCode,
    );
    return value ?? fallback ?? key;
  }

  Future<String> cardTextFromZhHans(
    String cardName,
    String zhHans, {
    String? fallback,
  }) async {
    final value = await _bundle.cardTextFromZhHansOrNull(
      cardName,
      zhHans,
      languageCode: languageCode,
    );
    return value ?? fallback ?? zhHans;
  }

  Future<Map<String, String>> textMap(Map<String, String> fallbacks) async {
    final entries = await Future.wait(
      fallbacks.entries.map((entry) async {
        final value = await text(entry.key, fallback: entry.value);
        return MapEntry(entry.key, value);
      }),
    );
    return Map<String, String>.fromEntries(entries);
  }
}
