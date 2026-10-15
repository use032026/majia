import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/services/ios_language_bundle.dart';
import 'st_toast.dart';

String stLocalizedTextFromZhHans(Object contextOrZhHans, [String? zhHans]) {
  return _normalizedZhHansFallback(zhHans ?? contextOrZhHans.toString());
}

String stLocalizedText(Object contextOrKey, [String? key, String? fallback]) {
  return fallback ?? key ?? contextOrKey.toString();
}

Future<String> _resolveLocalizedTextFromZhHans(
  BuildContext context,
  String zhHans, {
  Map<String, String> replacements = const {},
}) async {
  final customMin = RegExp(r'^自定义金额需不低于(.+)$').firstMatch(zhHans);
  if (customMin != null) {
    return _resolveLocalizedTextFromZhHans(
      context,
      '自定义金额需不低于{min}',
      replacements: {'min': customMin.group(1)!},
    );
  }

  final customGreaterThanMin = RegExp(r'^自定义金额需大于最小金额(.+)$').firstMatch(zhHans);
  if (customGreaterThanMin != null) {
    return _resolveLocalizedTextFromZhHans(
      context,
      '自定义金额需大于最小金额{min}',
      replacements: {'min': customGreaterThanMin.group(1)!},
    );
  }

  final customStep = RegExp(r'^自定义金额需以(.+)为起点，按(.+)递增$').firstMatch(zhHans);
  if (customStep != null) {
    return _resolveLocalizedTextFromZhHans(
      context,
      '自定义金额需以{min}为起点，按{step}递增',
      replacements: {'min': customStep.group(1)!, 'step': customStep.group(2)!},
    );
  }

  var text = await STLocalizations.ofContext(context).textFromZhHans(zhHans);
  for (final entry in replacements.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}

Future<String> _resolveLocalizedText(
  BuildContext context,
  String key, {
  String? fallback,
  Map<String, String> replacements = const {},
}) async {
  var text = await STLocalizations.ofContext(
    context,
  ).text(key, fallback: fallback);
  for (final entry in replacements.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}

String _normalizedZhHansFallback(String zhHans) {
  final customMin = RegExp(r'^自定义金额需不低于(.+)$').firstMatch(zhHans);
  if (customMin != null) {
    return '自定义金额需不低于${customMin.group(1)!}';
  }

  final customGreaterThanMin = RegExp(r'^自定义金额需大于最小金额(.+)$').firstMatch(zhHans);
  if (customGreaterThanMin != null) {
    return '自定义金额需大于最小金额${customGreaterThanMin.group(1)!}';
  }

  final customStep = RegExp(r'^自定义金额需以(.+)为起点，按(.+)递增$').firstMatch(zhHans);
  if (customStep != null) {
    return '自定义金额需以${customStep.group(1)!}为起点，按${customStep.group(2)!}递增';
  }

  return zhHans;
}

void showStLocalizedToastByKey(
  BuildContext context,
  String key, {
  String? fallback,
  Map<String, String> replacements = const {},
  Duration? duration,
}) {
  _resolveLocalizedText(
    context,
    key,
    fallback: fallback,
    replacements: replacements,
  ).then((text) {
    if (!context.mounted) return;
    STToast.show(
      context,
      text,
      duration: duration ?? const Duration(seconds: 2),
    );
  });
}

void showStLocalizedToast(
  BuildContext context,
  String zhHans, {
  Map<String, String> replacements = const {},
  Duration? duration,
}) {
  _resolveLocalizedTextFromZhHans(
    context,
    zhHans,
    replacements: replacements,
  ).then((text) {
    if (!context.mounted) return;
    STToast.show(
      context,
      text,
      duration: duration ?? const Duration(seconds: 2),
    );
  });
}

void showStLocalizedErrorToast(
  BuildContext context,
  String titleZhHans,
  Object error, {
  String separator = ': ',
  Duration? duration,
}) {
  _resolveLocalizedTextFromZhHans(context, titleZhHans).then((title) {
    if (!context.mounted) return;
    _resolveLocalizedTextFromZhHans(
      context,
      stUserVisibleErrorMessage(error),
    ).then((detail) {
      if (!context.mounted) return;
      STToast.show(
        context,
        '$title$separator$detail',
        duration: duration ?? const Duration(seconds: 2),
      );
    });
  });
}

void showStLocalizedPrompt(
  BuildContext context,
  String zhHans, {
  Object? error,
  String separator = ': ',
}) {
  _resolveLocalizedTextFromZhHans(context, zhHans).then((text) {
    if (!context.mounted) return;
    if (error == null) {
      STToast.show(context, text);
      return;
    }
    _resolveLocalizedTextFromZhHans(
      context,
      stUserVisibleErrorMessage(error),
    ).then((detail) {
      if (!context.mounted) return;
      STToast.show(context, '$text$separator$detail');
    });
  });
}

class STLocalizedText extends StatelessWidget {
  final String zhHans;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const STLocalizedText(
    this.zhHans, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: STLocalizations.ofContext(context).textFromZhHans(zhHans),
      initialData: zhHans,
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? zhHans,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

class STLocalizedTextByKey extends StatefulWidget {
  final String localizationKey;
  final String fallback;
  final String? languageCode;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const STLocalizedTextByKey(
    this.localizationKey, {
    super.key,
    required this.fallback,
    this.languageCode,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  State<STLocalizedTextByKey> createState() => _STLocalizedTextByKeyState();
}

class _STLocalizedTextByKeyState extends State<STLocalizedTextByKey> {
  Future<String>? _future;
  String? _languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    final resolvedLanguageCode = widget.languageCode ?? languageCode;
    if (_future == null || _languageCode != resolvedLanguageCode) {
      _languageCode = resolvedLanguageCode;
      _future = _localizations(
        context,
      ).text(widget.localizationKey, fallback: widget.fallback);
    }
  }

  @override
  void didUpdateWidget(covariant STLocalizedTextByKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localizationKey != widget.localizationKey ||
        oldWidget.fallback != widget.fallback ||
        oldWidget.languageCode != widget.languageCode) {
      _languageCode = widget.languageCode ?? stLanguageCodeOfContext(context);
      _future = _localizations(
        context,
      ).text(widget.localizationKey, fallback: widget.fallback);
    }
  }

  STLocalizations _localizations(BuildContext context) {
    final languageCode = widget.languageCode;
    if (languageCode == null || languageCode.isEmpty) {
      return STLocalizations.ofContext(context);
    }
    return STLocalizations(
      bundle: IosLanguageBundle(),
      languageCode: languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      initialData: widget.fallback,
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? widget.fallback,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }
}
