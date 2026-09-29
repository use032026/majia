import 'dart:math' as math;

import 'models.dart';
import 'money.dart';

enum PaceStatus { ahead, onTrack, needsRecovery, expired, completed }

enum RecoveryStrategy { keepDate, keepWeekly, customWeekly }

class PaceSnapshot {
  const PaceSnapshot({
    required this.status,
    required this.savedCents,
    required this.expectedCents,
    required this.shortfallCents,
    required this.remainingCents,
    required this.requiredWeeklyCents,
    required this.weeksRemaining,
  });

  final PaceStatus status;
  final int savedCents;
  final int expectedCents;
  final int shortfallCents;
  final int remainingCents;
  final int requiredWeeklyCents;
  final int weeksRemaining;
}

class PlanPreview {
  const PlanPreview({
    required this.strategy,
    required this.weeklyCents,
    required this.targetDate,
  });

  final RecoveryStrategy strategy;
  final int weeklyCents;
  final DateTime targetDate;
}

class PaceCalculator {
  const PaceCalculator();

  PaceSnapshot evaluate(SavingsGoal goal, DateTime now) {
    final plan = goal.currentPlan;
    final today = _dateOnly(now);
    final effective = _dateOnly(plan.effectiveAt);
    final elapsedDays = math.max(0, today.difference(effective).inDays);
    final elapsedWeeks = elapsedDays ~/ 7;
    final expected = math.min(
      goal.targetCents,
      plan.baselineCents + elapsedWeeks * plan.weeklyCents,
    );
    final saved = math.max(0, goal.savedCents);
    final remaining = math.max(0, goal.targetCents - saved);
    final daysRemaining = _dateOnly(plan.targetDate).difference(today).inDays;
    final weeksRemaining = math.max(1, (math.max(0, daysRemaining) / 7).ceil());
    final requiredWeekly = remaining == 0
        ? 0
        : (remaining / weeksRemaining).ceil();
    final shortfall = math.max(0, expected - saved);
    final currentPlanEvents =
        goal.events
            .where((event) => !event.occurredAt.isBefore(plan.effectiveAt))
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final latestEventIsSkip =
        currentPlanEvents.isNotEmpty &&
        currentPlanEvents.last.type == SavingsEventType.skipped;

    late final PaceStatus status;
    if (remaining == 0) {
      status = PaceStatus.completed;
    } else if (daysRemaining < 0) {
      status = PaceStatus.expired;
    } else if (shortfall > 0 ||
        requiredWeekly > plan.weeklyCents ||
        latestEventIsSkip) {
      status = PaceStatus.needsRecovery;
    } else if (saved >= expected + math.max(1, plan.weeklyCents ~/ 2)) {
      status = PaceStatus.ahead;
    } else {
      status = PaceStatus.onTrack;
    }

    return PaceSnapshot(
      status: status,
      savedCents: saved,
      expectedCents: expected,
      shortfallCents: shortfall,
      remainingCents: remaining,
      requiredWeeklyCents: requiredWeekly,
      weeksRemaining: weeksRemaining,
    );
  }

  PlanPreview preview(
    SavingsGoal goal,
    DateTime now,
    RecoveryStrategy strategy, {
    int? customWeeklyCents,
  }) {
    final snapshot = evaluate(goal, now);
    final plan = goal.currentPlan;
    switch (strategy) {
      case RecoveryStrategy.keepDate:
        if (_dateOnly(plan.targetDate).isBefore(_dateOnly(now))) {
          throw const FormatException('Cannot keep an expired target date');
        }
        return PlanPreview(
          strategy: strategy,
          weeklyCents: math.max(1, snapshot.requiredWeeklyCents),
          targetDate: _dateOnly(plan.targetDate),
        );
      case RecoveryStrategy.keepWeekly:
        return PlanPreview(
          strategy: strategy,
          weeklyCents: plan.weeklyCents,
          targetDate: _targetForWeekly(
            now,
            snapshot.remainingCents,
            plan.weeklyCents,
          ),
        );
      case RecoveryStrategy.customWeekly:
        if (customWeeklyCents == null ||
            customWeeklyCents <= 0 ||
            customWeeklyCents > maxMoneyCents) {
          throw const FormatException('Custom weekly amount is required');
        }
        return PlanPreview(
          strategy: strategy,
          weeklyCents: customWeeklyCents,
          targetDate: _targetForWeekly(
            now,
            snapshot.remainingCents,
            customWeeklyCents,
          ),
        );
    }
  }

  DateTime _targetForWeekly(DateTime now, int remaining, int weekly) {
    final weeks = math.max(1, (remaining / weekly).ceil());
    return _dateOnly(now).add(Duration(days: weeks * 7));
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
