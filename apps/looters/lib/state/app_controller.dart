import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/goal_repository.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import '../domain/pace_calculator.dart';

typedef NowProvider = DateTime Function();
typedef ClipboardWriter = Future<void> Function(String text);

class CreateGoalInput {
  const CreateGoalInput({
    required this.name,
    required this.currency,
    required this.targetCents,
    required this.startingCents,
    required this.weeklyCents,
    required this.targetDate,
  });

  final String name;
  final String currency;
  final int targetCents;
  final int startingCents;
  final int weeklyCents;
  final DateTime targetDate;
}

class AppController extends ChangeNotifier {
  AppController({
    required GoalRepository repository,
    NowProvider? now,
    ClipboardWriter? clipboardWriter,
    String defaultLocaleCode = 'zh',
  }) : _repository = repository,
       _now = now ?? DateTime.now,
       _clipboardWriter = clipboardWriter ?? _writeSystemClipboard,
       _localeCode = defaultLocaleCode;

  final GoalRepository _repository;
  final NowProvider _now;
  final ClipboardWriter _clipboardWriter;
  static const calculator = PaceCalculator();

  SavingsGoal? _goal;
  bool _loading = true;
  bool _corruptRecord = false;
  bool _loadFailure = false;
  bool _darkMode = false;
  String _localeCode;
  String? _errorCode;

  SavingsGoal? get goal => _goal;
  bool get loading => _loading;
  bool get corruptRecord => _corruptRecord;
  bool get loadFailure => _loadFailure;
  bool get darkMode => _darkMode;
  String get localeCode => _localeCode;
  String? get errorCode => _errorCode;
  DateTime get now => _now();

  PaceSnapshot? get snapshot =>
      _goal == null ? null : calculator.evaluate(_goal!, _now());

  Future<void> initialize() async {
    _loading = true;
    _loadFailure = false;
    _errorCode = null;
    notifyListeners();
    try {
      final locale = await _repository.loadLocaleCode();
      if (locale == 'zh' || locale == 'en') _localeCode = locale!;
      _darkMode = await _repository.loadDarkMode() ?? false;
      try {
        _goal = await _repository.loadGoal();
        _corruptRecord = false;
      } on FormatException {
        _goal = null;
        _corruptRecord = true;
      }
    } catch (_) {
      _goal = null;
      _corruptRecord = false;
      _loadFailure = true;
      _errorCode = 'loadFailed';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createGoal(CreateGoalInput input) async {
    if (_loadFailure) return false;
    _errorCode = null;
    final createdAt = _now();
    final goal = SavingsGoal(
      id: 'goal-${createdAt.microsecondsSinceEpoch}',
      name: input.name.trim(),
      currency: input.currency.trim(),
      targetCents: input.targetCents,
      startingCents: input.startingCents,
      createdAt: createdAt,
      events: const <SavingsEvent>[],
      plans: <PlanVersion>[
        PlanVersion(
          id: 'plan-${createdAt.microsecondsSinceEpoch}',
          effectiveAt: createdAt,
          weeklyCents: input.weeklyCents,
          targetDate: input.targetDate,
          baselineCents: input.startingCents,
          reason: PlanReason.initial,
        ),
      ],
    );
    return _persistThenCommit(goal);
  }

  Future<bool> recordEvent({
    required SavingsEventType type,
    required int amountCents,
    String note = '',
  }) async {
    if (_loadFailure) return false;
    final current = _goal;
    if (current == null) return false;
    _errorCode = null;
    final trimmedNote = note.trim();
    if (trimmedNote.runes.length > 120 || amountCents < 0) {
      _errorCode = 'invalidInput';
      notifyListeners();
      return false;
    }
    if (type != SavingsEventType.skipped && amountCents == 0) {
      _errorCode = 'invalidAmount';
      notifyListeners();
      return false;
    }
    if (amountCents > maxMoneyCents ||
        (type == SavingsEventType.deposit &&
            current.savedCents + amountCents > maxMoneyCents) ||
        (type == SavingsEventType.withdrawal &&
            amountCents > current.savedCents)) {
      _errorCode = type == SavingsEventType.withdrawal
          ? 'withdrawalTooLarge'
          : 'invalidAmount';
      notifyListeners();
      return false;
    }
    final occurredAt = _now();
    final event = SavingsEvent(
      id: 'event-${occurredAt.microsecondsSinceEpoch}',
      type: type,
      amountCents: type == SavingsEventType.skipped ? 0 : amountCents,
      occurredAt: occurredAt,
      note: trimmedNote,
    );
    return _persistThenCommit(
      current.copyWith(events: <SavingsEvent>[...current.events, event]),
    );
  }

  PlanPreview previewPlan(
    RecoveryStrategy strategy, {
    int? customWeeklyCents,
  }) => calculator.preview(
    _goal!,
    _now(),
    strategy,
    customWeeklyCents: customWeeklyCents,
  );

  Future<bool> applyPlan(
    RecoveryStrategy strategy, {
    int? customWeeklyCents,
  }) async {
    if (_loadFailure) return false;
    final current = _goal;
    if (current == null) return false;
    _errorCode = null;
    late final PlanPreview preview;
    try {
      preview = calculator.preview(
        current,
        _now(),
        strategy,
        customWeeklyCents: customWeeklyCents,
      );
    } on FormatException {
      _errorCode = 'invalidAmount';
      notifyListeners();
      return false;
    }
    final changedAt = _now();
    final plan = PlanVersion(
      id: 'plan-${changedAt.microsecondsSinceEpoch}',
      effectiveAt: changedAt,
      weeklyCents: preview.weeklyCents,
      targetDate: preview.targetDate,
      baselineCents: current.savedCents,
      reason: switch (strategy) {
        RecoveryStrategy.keepDate => PlanReason.keepDate,
        RecoveryStrategy.keepWeekly => PlanReason.keepWeekly,
        RecoveryStrategy.customWeekly => PlanReason.customWeekly,
      },
    );
    return _persistThenCommit(
      current.copyWith(plans: <PlanVersion>[...current.plans, plan]),
    );
  }

  Future<bool> deleteGoal() async {
    if (_loadFailure) return false;
    _errorCode = null;
    try {
      await _repository.clearGoal();
      _goal = null;
      _corruptRecord = false;
      notifyListeners();
      return true;
    } catch (_) {
      _errorCode = 'saveFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearCorruptRecord() async => deleteGoal();

  Future<void> setLocaleCode(String value) async {
    if (value != 'zh' && value != 'en') return;
    try {
      await _repository.saveLocaleCode(value);
      _localeCode = value;
      _errorCode = null;
    } catch (_) {
      _errorCode = 'saveFailed';
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    try {
      await _repository.saveDarkMode(enabled);
      _darkMode = enabled;
      _errorCode = null;
    } catch (_) {
      _errorCode = 'saveFailed';
    }
    notifyListeners();
  }

  void clearError() {
    _errorCode = null;
    notifyListeners();
  }

  String buildSummary() {
    final current = _goal;
    if (current == null) return '';
    final pace = calculator.evaluate(current, _now());
    final zh = _localeCode == 'zh';
    final plan = current.currentPlan;
    final buffer = StringBuffer()
      ..writeln(zh ? 'PaceJar · 节奏复盘' : 'PaceJar · Pace review')
      ..writeln('${zh ? '目标' : 'Goal'}: ${current.name}')
      ..writeln(
        '${zh ? '已记录' : 'Recorded'}: '
        '${formatMoney(pace.savedCents, current.currency)} / '
        '${formatMoney(current.targetCents, current.currency)}',
      )
      ..writeln(
        '${zh ? '当前周额' : 'Current weekly pace'}: '
        '${formatMoney(plan.weeklyCents, current.currency)}',
      )
      ..writeln('${zh ? '事件数' : 'Events'}: ${current.events.length}')
      ..writeln('${zh ? '计划版本' : 'Plan versions'}: ${current.plans.length}')
      ..writeln()
      ..writeln(
        zh
            ? '仅为手动本地记录，不代表银行余额，也不构成财务建议。'
            : 'Manual local record only. Not a bank balance or financial advice.',
      );
    return buffer.toString();
  }

  Future<bool> copySummary() async {
    final summary = buildSummary();
    if (summary.isEmpty) return false;
    try {
      await _clipboardWriter(summary);
      _errorCode = null;
      notifyListeners();
      return true;
    } catch (_) {
      _errorCode = 'copyFailed';
      notifyListeners();
      return false;
    }
  }

  void refreshForCurrentDate() => notifyListeners();

  Future<bool> _persistThenCommit(SavingsGoal next) async {
    try {
      await _repository.saveGoal(next);
      _goal = next;
      _corruptRecord = false;
      _errorCode = null;
      notifyListeners();
      return true;
    } catch (_) {
      _errorCode = 'saveFailed';
      notifyListeners();
      return false;
    }
  }

  static Future<void> _writeSystemClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
