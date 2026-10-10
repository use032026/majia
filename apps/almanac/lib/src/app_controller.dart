import 'dart:convert';

import 'package:flutter/material.dart';

import 'data/local_store.dart';
import 'domain/almanac_content.dart';
import 'domain/almanac_models.dart';

class AppController extends ChangeNotifier {
  AppController({
    required StateStore store,
    required String Function() seedFactory,
    DateTime Function()? clock,
    AlmanacGenerator generator = const AlmanacGenerator(),
  }) : _store = store,
       _seedFactory = seedFactory,
       _clock = clock ?? DateTime.now,
       _generator = generator;

  final StateStore _store;
  final String Function() _seedFactory;
  final DateTime Function() _clock;
  final AlmanacGenerator _generator;

  AlmanacData? _data;
  Object? _loadFailure;
  Object? _saveFailure;
  bool _isBusy = false;
  bool _dayChangedNotice = false;

  AlmanacData? get data => _data;
  bool get isLoaded => _data != null;
  bool get hasLoadFailure => _loadFailure != null;
  bool get hasSaveFailure => _saveFailure != null;
  bool get hasDayChangedNotice => _dayChangedNotice;
  bool get isBusy => _isBusy;
  String get todayKey => formatDateKey(_clock());

  bool get hasCurrentDateLeaf => _data!.leaves.containsKey(todayKey);

  DailyLeaf get todayLeaf {
    final today = _data!.leaves[todayKey];
    if (today != null) return today;
    final ordered = _data!.leaves.values.toList()
      ..sort((left, right) => right.dateKey.compareTo(left.dateKey));
    return ordered.first;
  }

  List<DailyLeaf> get archivedLeaves {
    final result = _data!.leaves.values.where((leaf) => leaf.isSealed).toList();
    result.sort((left, right) => right.dateKey.compareTo(left.dateKey));
    return result;
  }

  Locale resolveLocale(Locale systemLocale) {
    switch (_data?.localeMode ?? AppLocaleMode.system) {
      case AppLocaleMode.system:
        return systemLocale.languageCode == 'zh'
            ? const Locale('zh', 'CN')
            : const Locale('en');
      case AppLocaleMode.zhHans:
        return const Locale('zh', 'CN');
      case AppLocaleMode.en:
        return const Locale('en');
    }
  }

  ThemeMode get flutterThemeMode {
    switch (_data?.themeMode ?? AppThemeMode.system) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Future<void> load() async {
    _loadFailure = null;
    _saveFailure = null;
    _dayChangedNotice = false;
    _isBusy = true;
    notifyListeners();
    try {
      final raw = await _store.read();
      AlmanacData next;
      var needsWrite = false;
      if (raw == null) {
        next = AlmanacData.initial(_seedFactory());
        needsWrite = true;
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException('Invalid root value');
        next = AlmanacData.fromJson(Map<String, Object?>.from(decoded));
        for (final entry in next.leaves.entries) {
          if (entry.key != entry.value.dateKey) {
            throw const FormatException(
              'Daily leaf key does not match its date',
            );
          }
          validateLeafContent(entry.value);
        }
      }
      final now = _clock();
      final today = formatDateKey(now);
      if (!next.leaves.containsKey(today)) {
        final leaves = Map<String, DailyLeaf>.from(next.leaves);
        leaves[today] = _generator.generate(
          date: now,
          installationSeed: next.installationSeed,
        );
        next = next.copyWith(leaves: leaves);
        needsWrite = true;
      }
      if (needsWrite && !await _write(next)) {
        throw StateError('Could not initialize local storage');
      }
      _data = next;
    } catch (error) {
      _data = null;
      _loadFailure = error;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> recoverWithReset() async {
    _isBusy = true;
    notifyListeners();
    try {
      if (!await _store.clear()) throw StateError('Could not clear data');
      _data = null;
      _loadFailure = null;
      _saveFailure = null;
    } catch (error) {
      _loadFailure = error;
      _isBusy = false;
      notifyListeners();
      return false;
    }
    _isBusy = false;
    await load();
    return isLoaded;
  }

  Future<bool> completeOnboarding() =>
      _commit(_data!.copyWith(onboardingSeen: true));

  Future<bool> setLocaleMode(AppLocaleMode mode) =>
      _commit(_data!.copyWith(localeMode: mode));

  Future<bool> setThemeMode(AppThemeMode mode) =>
      _commit(_data!.copyWith(themeMode: mode));

  Future<bool> refreshForCurrentDate() async {
    final now = _clock();
    final key = formatDateKey(now);
    if (_data!.leaves.containsKey(key)) return true;
    final leaves = Map<String, DailyLeaf>.from(_data!.leaves);
    leaves[key] = _generator.generate(
      date: now,
      installationSeed: _data!.installationSeed,
    );
    final saved = await _commit(_data!.copyWith(leaves: leaves));
    if (saved) {
      _dayChangedNotice = true;
      notifyListeners();
    }
    return saved;
  }

  Future<bool> sealToday({
    required String suitableId,
    required String avoidId,
    required String intention,
  }) async {
    if (!hasCurrentDateLeaf) {
      await refreshForCurrentDate();
      return false;
    }
    final leaf = todayLeaf;
    if (!leaf.suitablePromptIds.contains(suitableId) ||
        !leaf.avoidPromptIds.contains(avoidId)) {
      throw ArgumentError('Selections must come from today’s prompts');
    }
    final normalized = intention.trim();
    if (normalized.characters.length > 140) {
      throw ArgumentError('Intention is longer than 140 characters');
    }
    final leaves = Map<String, DailyLeaf>.from(_data!.leaves);
    leaves[todayKey] = leaf.copyWith(
      selectedSuitableId: suitableId,
      selectedAvoidId: avoidId,
      intention: normalized,
      sealedAt: _clock(),
    );
    final saved = await _commit(_data!.copyWith(leaves: leaves));
    if (saved && _dayChangedNotice) {
      _dayChangedNotice = false;
      notifyListeners();
    }
    return saved;
  }

  Future<bool> reflectToday(ReflectionOutcome outcome) async {
    if (!hasCurrentDateLeaf && !await refreshForCurrentDate()) return false;
    final leaf = todayLeaf;
    if (!leaf.isSealed) return false;
    final leaves = Map<String, DailyLeaf>.from(_data!.leaves);
    leaves[todayKey] = leaf.copyWith(outcome: outcome, reflectedAt: _clock());
    return _commit(_data!.copyWith(leaves: leaves));
  }

  Future<bool> clearRecords() {
    final freshToday = _generator.generate(
      date: _clock(),
      installationSeed: _data!.installationSeed,
    );
    return _commit(
      _data!.copyWith(leaves: <String, DailyLeaf>{todayKey: freshToday}),
    );
  }

  String exportMarkdown({required bool useChinese}) {
    final buffer = StringBuffer()
      ..writeln(useChinese ? '# Almanac 岁时册' : '# Almanac folio')
      ..writeln()
      ..writeln(
        useChinese
            ? '> 本文件由用户主动从本机记录复制；内容是反思提示，不是吉凶预测。'
            : '> Copied by the user from local records; prompts are for reflection, not prediction.',
      );
    for (final leaf in archivedLeaves) {
      final suitable = promptById(
        leaf.selectedSuitableId!,
      ).text(useChinese: useChinese);
      final avoid = promptById(
        leaf.selectedAvoidId!,
      ).text(useChinese: useChinese);
      buffer
        ..writeln()
        ..writeln('## ${leaf.dateKey}')
        ..writeln('- ${useChinese ? '宜' : 'Try'}: $suitable')
        ..writeln('- ${useChinese ? '忌' : 'Skip'}: $avoid');
      if ((leaf.intention ?? '').isNotEmpty) {
        buffer.writeln(
          '- ${useChinese ? '今日意图' : 'Intention'}: ${_markdownInline(leaf.intention!)}',
        );
      }
      if (leaf.outcome != null) {
        buffer.writeln(
          '- ${useChinese ? '回看' : 'Reflection'}: ${_outcomeLabel(leaf.outcome!, useChinese)}',
        );
      }
      buffer
        ..writeln()
        ..writeln((useChinese ? leaf.verseZh : leaf.verseEn).join('  \n'));
    }
    return buffer.toString();
  }

  String _outcomeLabel(ReflectionOutcome outcome, bool useChinese) {
    switch (outcome) {
      case ReflectionOutcome.practiced:
        return useChinese ? '践行' : 'Practiced';
      case ReflectionOutcome.reframed:
        return useChinese ? '调整' : 'Reframed';
      case ReflectionOutcome.released:
        return useChinese ? '放下' : 'Released';
    }
  }

  String _markdownInline(String value) {
    final singleLine = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return singleLine.replaceAllMapped(
      RegExp(r'([\\`*_{}\[\]()#+\-.!|>])'),
      (match) => '\\${match.group(1)}',
    );
  }

  Future<bool> _commit(AlmanacData next) async {
    if (_isBusy) return false;
    _isBusy = true;
    _saveFailure = null;
    notifyListeners();
    try {
      if (!await _write(next)) throw StateError('Local save failed');
      _data = next;
      return true;
    } catch (error) {
      _saveFailure = error;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> _write(AlmanacData value) =>
      _store.write(jsonEncode(value.toJson()));
}
