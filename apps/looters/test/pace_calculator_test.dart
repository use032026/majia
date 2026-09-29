import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/domain/models.dart';
import 'package:pace_jar/domain/pace_calculator.dart';

import 'test_support.dart';

void main() {
  const calculator = PaceCalculator();

  test('detects shortfall without rewriting actual balance', () {
    final goal = sampleGoal(
      createdAt: DateTime(2026, 9, 1),
      weeklyCents: 10000,
    );
    final result = calculator.evaluate(goal, DateTime(2026, 9, 15));
    expect(result.expectedCents, 30000);
    expect(result.savedCents, 10000);
    expect(result.shortfallCents, 20000);
    expect(result.status, PaceStatus.needsRecovery);
  });

  test('new plan baseline resets future expectation but preserves history', () {
    final created = DateTime(2026, 9, 1);
    final goal = sampleGoal(
      createdAt: created,
      plans: <PlanVersion>[
        PlanVersion(
          id: 'old',
          effectiveAt: created,
          weeklyCents: 10000,
          targetDate: DateTime(2026, 12, 1),
          baselineCents: 10000,
          reason: PlanReason.initial,
        ),
        PlanVersion(
          id: 'new',
          effectiveAt: DateTime(2026, 9, 15),
          weeklyCents: 5000,
          targetDate: DateTime(2027, 1, 20),
          baselineCents: 10000,
          reason: PlanReason.keepWeekly,
        ),
      ],
    );
    final result = calculator.evaluate(goal, DateTime(2026, 9, 22));
    expect(result.expectedCents, 15000);
    expect(goal.plans, hasLength(2));
  });

  test('recovery options are transparent and deterministic', () {
    final goal = sampleGoal(
      createdAt: DateTime(2026, 9, 1),
      weeklyCents: 10000,
      targetDate: DateTime(2026, 11, 10),
    );
    final now = DateTime(2026, 9, 15);
    final keepDate = calculator.preview(goal, now, RecoveryStrategy.keepDate);
    final keepWeekly = calculator.preview(
      goal,
      now,
      RecoveryStrategy.keepWeekly,
    );
    final custom = calculator.preview(
      goal,
      now,
      RecoveryStrategy.customWeekly,
      customWeeklyCents: 20000,
    );
    expect(keepDate.targetDate, DateTime(2026, 11, 10));
    expect(keepWeekly.weeklyCents, 10000);
    expect(custom.weeklyCents, 20000);
    expect(custom.targetDate.isBefore(keepWeekly.targetDate), isTrue);
  });

  test('expired target cannot append a keep-date no-op plan', () {
    final goal = sampleGoal(targetDate: DateTime(2026, 9, 1));
    final now = DateTime(2026, 9, 29);

    expect(
      () => calculator.preview(goal, now, RecoveryStrategy.keepDate),
      throwsFormatException,
    );
    final viable = calculator.preview(goal, now, RecoveryStrategy.keepWeekly);
    expect(viable.targetDate.isAfter(now), isTrue);
  });

  test('a current-plan skipped week requests recovery immediately', () {
    final now = DateTime(2026, 9, 29);
    final goal = sampleGoal(
      createdAt: now,
      targetDate: DateTime(2026, 12, 1),
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'skip-now',
          type: SavingsEventType.skipped,
          amountCents: 0,
          occurredAt: now,
        ),
      ],
    );

    expect(calculator.evaluate(goal, now).status, PaceStatus.needsRecovery);
  });
}
