import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/domain/models.dart';
import 'package:pace_jar/domain/money.dart';

import 'test_support.dart';

void main() {
  group('money parsing', () {
    test('stores exact cents and formats grouped values', () {
      expect(parseMoneyToCents('1,234.5'), 123450);
      expect(parseMoneyToCents('0', allowZero: true), 0);
      expect(formatMoney(-123450, r'$'), r'−$1,234.50');
    });

    test('rejects excess precision and upper bound', () {
      expect(parseMoneyToCents('1.001'), isNull);
      expect(parseMoneyToCents('10000000000.00'), isNull);
      expect(parseMoneyToCents('0'), isNull);
    });
  });

  test('goal JSON round-trip keeps immutable events and plan versions', () {
    final goal = sampleGoal(
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'event-1',
          type: SavingsEventType.deposit,
          amountCents: 2500,
          occurredAt: DateTime(2026, 9, 8),
          note: 'Project payment',
        ),
      ],
    );
    final restored = SavingsGoal.fromJson(goal.toJson());
    expect(restored.savedCents, 12500);
    expect(restored.events.single.note, 'Project payment');
    expect(
      () => restored.events.add(restored.events.single),
      throwsUnsupportedError,
    );
    final encodedPlan =
        (goal.toJson()['plans']! as List<Object?>).single
            as Map<String, Object?>;
    expect(encodedPlan['targetDate'], '2026-11-10');
    expect(restored.currentPlan.targetDate, DateTime(2026, 11, 10));
  });

  test('invalid serialized records fail loudly', () {
    expect(
      () => SavingsGoal.fromJson(<String, Object?>{'name': 'missing'}),
      throwsFormatException,
    );
  });

  test('semantic corruption is rejected without relying on assertions', () {
    final zeroWeekly = sampleGoal().toJson();
    final zeroWeeklyPlans = zeroWeekly['plans']! as List<Object?>;
    (zeroWeeklyPlans.single as Map<String, Object?>)['weeklyCents'] = 0;
    expect(() => SavingsGoal.fromJson(zeroWeekly), throwsFormatException);

    final negativeEvent = sampleGoal().toJson();
    negativeEvent['events'] = <Object?>[
      <String, Object?>{
        'id': 'bad-event',
        'type': 'deposit',
        'amountCents': -1,
        'occurredAt': '2026-09-02T00:00:00.000Z',
        'note': '',
      },
    ];
    expect(() => SavingsGoal.fromJson(negativeEvent), throwsFormatException);

    final impossibleWithdrawal = sampleGoal().toJson();
    impossibleWithdrawal['events'] = <Object?>[
      <String, Object?>{
        'id': 'bad-withdrawal',
        'type': 'withdrawal',
        'amountCents': 10001,
        'occurredAt': '2026-09-02T00:00:00.000Z',
        'note': '',
      },
    ];
    expect(
      () => SavingsGoal.fromJson(impossibleWithdrawal),
      throwsFormatException,
    );
  });

  test('completion date follows the latest upward target crossing', () {
    final goal = sampleGoal(
      targetCents: 20000,
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'reach-1',
          type: SavingsEventType.deposit,
          amountCents: 10000,
          occurredAt: DateTime(2026, 9, 8),
        ),
        SavingsEvent(
          id: 'dip',
          type: SavingsEventType.withdrawal,
          amountCents: 5000,
          occurredAt: DateTime(2026, 9, 9),
        ),
        SavingsEvent(
          id: 'reach-2',
          type: SavingsEventType.deposit,
          amountCents: 5000,
          occurredAt: DateTime(2026, 9, 10),
        ),
      ],
    );
    expect(goal.completedAt, DateTime(2026, 9, 10));
  });
}
