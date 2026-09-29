import 'dart:collection';

import 'money.dart';

enum SavingsEventType { deposit, withdrawal, skipped }

enum PlanReason { initial, keepDate, keepWeekly, customWeekly }

class SavingsEvent {
  SavingsEvent({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.occurredAt,
    this.note = '',
  }) {
    if (id.isEmpty ||
        amountCents < 0 ||
        amountCents > maxMoneyCents ||
        note.runes.length > 120 ||
        (type == SavingsEventType.skipped && amountCents != 0) ||
        (type != SavingsEventType.skipped && amountCents == 0)) {
      throw const FormatException('Invalid savings event');
    }
  }

  final String id;
  final SavingsEventType type;
  final int amountCents;
  final DateTime occurredAt;
  final String note;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'amountCents': amountCents,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'note': note,
  };

  factory SavingsEvent.fromJson(Map<String, Object?> json) {
    final typeName = _requiredString(json, 'type');
    return SavingsEvent(
      id: _requiredString(json, 'id'),
      type: SavingsEventType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => throw const FormatException('Unknown event type'),
      ),
      amountCents: _requiredInt(json, 'amountCents'),
      occurredAt: _requiredDate(json, 'occurredAt'),
      note: json['note'] is String ? json['note']! as String : '',
    );
  }
}

class PlanVersion {
  PlanVersion({
    required this.id,
    required this.effectiveAt,
    required this.weeklyCents,
    required this.targetDate,
    required this.baselineCents,
    required this.reason,
  }) {
    if (id.isEmpty ||
        weeklyCents <= 0 ||
        weeklyCents > maxMoneyCents ||
        baselineCents < 0 ||
        baselineCents > maxMoneyCents ||
        _dateOnly(targetDate).isBefore(_dateOnly(effectiveAt))) {
      throw const FormatException('Invalid plan version');
    }
  }

  final String id;
  final DateTime effectiveAt;
  final int weeklyCents;
  final DateTime targetDate;
  final int baselineCents;
  final PlanReason reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'effectiveAt': effectiveAt.toUtc().toIso8601String(),
    'weeklyCents': weeklyCents,
    'targetDate': _encodeDateOnly(targetDate),
    'baselineCents': baselineCents,
    'reason': reason.name,
  };

  factory PlanVersion.fromJson(Map<String, Object?> json) {
    final reasonName = _requiredString(json, 'reason');
    return PlanVersion(
      id: _requiredString(json, 'id'),
      effectiveAt: _requiredDate(json, 'effectiveAt'),
      weeklyCents: _requiredInt(json, 'weeklyCents'),
      targetDate: _requiredDateOnly(json, 'targetDate'),
      baselineCents: _requiredInt(json, 'baselineCents'),
      reason: PlanReason.values.firstWhere(
        (value) => value.name == reasonName,
        orElse: () => throw const FormatException('Unknown plan reason'),
      ),
    );
  }
}

class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.name,
    required this.currency,
    required this.targetCents,
    required this.startingCents,
    required this.createdAt,
    required List<SavingsEvent> events,
    required List<PlanVersion> plans,
  }) : events = UnmodifiableListView(events),
       plans = UnmodifiableListView(plans) {
    if (name.trim().isEmpty || name.runes.length > 40) {
      throw const FormatException('Invalid goal name');
    }
    if (currency.trim().isEmpty || currency.runes.length > 4) {
      throw const FormatException('Invalid currency');
    }
    if (id.isEmpty ||
        targetCents <= 0 ||
        targetCents > maxMoneyCents ||
        startingCents < 0 ||
        startingCents >= targetCents) {
      throw const FormatException('Invalid goal amounts');
    }
    if (plans.isEmpty) {
      throw const FormatException('A goal needs a plan');
    }
    var runningCents = startingCents;
    for (final event in events) {
      switch (event.type) {
        case SavingsEventType.deposit:
          runningCents += event.amountCents;
        case SavingsEventType.withdrawal:
          runningCents -= event.amountCents;
        case SavingsEventType.skipped:
          break;
      }
      if (runningCents < 0 || runningCents > maxMoneyCents) {
        throw const FormatException('Invalid event history');
      }
    }
    if (plans.any((plan) => plan.baselineCents > targetCents)) {
      throw const FormatException('Invalid plan baseline');
    }
  }

  final String id;
  final String name;
  final String currency;
  final int targetCents;
  final int startingCents;
  final DateTime createdAt;
  final List<SavingsEvent> events;
  final List<PlanVersion> plans;

  int get savedCents {
    var total = startingCents;
    for (final event in events) {
      switch (event.type) {
        case SavingsEventType.deposit:
          total += event.amountCents;
        case SavingsEventType.withdrawal:
          total -= event.amountCents;
        case SavingsEventType.skipped:
          break;
      }
    }
    return total;
  }

  DateTime? get completedAt {
    var runningCents = startingCents;
    DateTime? lastCrossing;
    final ordered = events.toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    for (final event in ordered) {
      final wasBelow = runningCents < targetCents;
      switch (event.type) {
        case SavingsEventType.deposit:
          runningCents += event.amountCents;
        case SavingsEventType.withdrawal:
          runningCents -= event.amountCents;
        case SavingsEventType.skipped:
          break;
      }
      if (wasBelow && runningCents >= targetCents) {
        lastCrossing = event.occurredAt;
      }
    }
    return runningCents >= targetCents ? lastCrossing : null;
  }

  PlanVersion get currentPlan {
    final sorted = plans.toList()
      ..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));
    return sorted.last;
  }

  SavingsGoal copyWith({
    List<SavingsEvent>? events,
    List<PlanVersion>? plans,
  }) => SavingsGoal(
    id: id,
    name: name,
    currency: currency,
    targetCents: targetCents,
    startingCents: startingCents,
    createdAt: createdAt,
    events: events ?? this.events,
    plans: plans ?? this.plans,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'currency': currency,
    'targetCents': targetCents,
    'startingCents': startingCents,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'events': events.map((event) => event.toJson()).toList(),
    'plans': plans.map((plan) => plan.toJson()).toList(),
  };

  factory SavingsGoal.fromJson(Map<String, Object?> json) {
    final rawEvents = json['events'];
    final rawPlans = json['plans'];
    if (rawEvents is! List<Object?> || rawPlans is! List<Object?>) {
      throw const FormatException('Invalid goal collections');
    }
    return SavingsGoal(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      currency: _requiredString(json, 'currency'),
      targetCents: _requiredInt(json, 'targetCents'),
      startingCents: _requiredInt(json, 'startingCents'),
      createdAt: _requiredDate(json, 'createdAt'),
      events: rawEvents.map((value) {
        if (value is! Map<Object?, Object?>) {
          throw const FormatException('Invalid event');
        }
        return SavingsEvent.fromJson(value.cast<String, Object?>());
      }).toList(),
      plans: rawPlans.map((value) {
        if (value is! Map<Object?, Object?>) {
          throw const FormatException('Invalid plan');
        }
        return PlanVersion.fromJson(value.cast<String, Object?>());
      }).toList(),
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing $key');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Missing $key');
  }
  return value;
}

DateTime _requiredDate(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  return DateTime.tryParse(value)?.toLocal() ??
      (throw FormatException('Invalid $key'));
}

DateTime _requiredDateOnly(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year == year && parsed.month == month && parsed.day == day) {
      return parsed;
    }
    throw FormatException('Invalid $key');
  }
  final legacy = DateTime.tryParse(value)?.toLocal();
  if (legacy == null) throw FormatException('Invalid $key');
  return _dateOnly(legacy);
}

String _encodeDateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
