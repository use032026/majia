import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/domain.dart';

void main() {
  test('money input and conversion preserve currency precision', () {
    expect(parseMinor('12.34', 'CNY'), 1234);
    expect(parseMinor('12.345', 'CNY'), isNull);
    expect(parseMinor('1200', 'JPY'), 1200);
    expect(parseMinor('1200.5', 'JPY'), isNull);
    expect(parseMinor('1000000', 'JPY'), 1000000);
    expect(parseMinor('1000001', 'JPY'), isNull);
    expect(parseRate('0.052345'), closeTo(0.052345, 0.0000001));
    expect(parseRate('0'), isNull);
    expect(
      convertMinor(
        sourceMinor: 1200,
        sourceCurrency: 'JPY',
        baseCurrency: 'CNY',
        rate: 0.05,
      ),
      6000,
    );
    expect(
      convertMinor(
        sourceMinor: 29,
        sourceCurrency: 'CNY',
        baseCurrency: 'USD',
        rate: 0.5,
      ),
      15,
    );
    expect(
      convertMinor(
        sourceMinor: 70,
        sourceCurrency: 'CNY',
        baseCurrency: 'USD',
        rate: 0.05,
      ),
      4,
    );
    expect(
      convertMinor(
        sourceMinor: 75,
        sourceCurrency: 'USD',
        baseCurrency: 'CNY',
        rate: 7.1,
      ),
      533,
    );
  });

  test('category variance and serialization survive reload', () {
    final trip = Trip(
      id: 't1',
      title: 'Kyoto',
      baseCurrency: 'CNY',
      budgets: {
        BudgetCategory.stay: 30000,
        BudgetCategory.transport: 20000,
        BudgetCategory.food: 10000,
        BudgetCategory.experiences: 0,
        BudgetCategory.other: 0,
      },
      stage: TripStage.completed,
      createdAt: DateTime.utc(2026, 9, 1),
      expenses: [
        Expense(
          id: 'e1',
          title: 'Hotel',
          category: BudgetCategory.stay,
          amountMinor: 10000,
          currency: 'JPY',
          rate: 0.05,
          bookedMinor: 50000,
          recordedAt: DateTime.utc(2026, 9, 2),
        ),
      ],
      reflection: 'Book earlier',
    );
    final reloaded = AppData.fromJson(
      jsonDecode(jsonEncode(AppData(trips: [trip]).toJson())),
    );
    final restored = reloaded.trips.single;
    expect(restored.plannedMinor, 60000);
    expect(restored.spentMinor, 50000);
    expect(restored.deltaMinor, -10000);
    expect(restored.deltaFor(BudgetCategory.stay), 20000);
    expect(restored.reflection, 'Book earlier');
    expect(restored.expenses.single.rate, 0.05);
  });

  test('unknown schema is rejected rather than reset', () {
    expect(
      () => AppData.fromJson({'schemaVersion': 3, 'trips': []}),
      throwsFormatException,
    );
  });

  test('version one trip survives migration with original spending intact', () {
    final old = {
      'schemaVersion': 1,
      'language': 'zh',
      'trips': [
        {
          'id': 'old',
          'title': 'Tokyo',
          'baseCurrency': 'CNY',
          'budgets': {
            for (final category in BudgetCategory.values) category.name: 10000,
          },
          'stage': 'active',
          'createdAt': '2026-09-01T00:00:00.000Z',
          'startedAt': '2026-09-02T00:00:00.000Z',
          'completedAt': null,
          'expenses': [
            {
              'id': 'local',
              'title': 'Meal',
              'category': 'food',
              'amountMinor': 2000,
              'currency': 'CNY',
              'rate': 1,
              'bookedMinor': 2000,
              'recordedAt': '2026-09-02T00:00:00.000Z',
              'note': '',
            },
            {
              'id': 'foreign',
              'title': 'Train',
              'category': 'transport',
              'amountMinor': 1000,
              'currency': 'JPY',
              'rate': 0.05,
              'bookedMinor': 5000,
              'recordedAt': '2026-09-02T00:00:00.000Z',
              'note': '',
            },
          ],
          'reflection': '',
        },
      ],
    };
    final migrated = AppData.fromJson(old);
    final trip = migrated.trips.single;
    expect(trip.spentMinor, 7000);
    expect(trip.entryCurrency, 'CNY');
    expect(trip.expenses.first.isEstimate, isFalse);
    expect(trip.expenses.last.isEstimate, isTrue);
    expect(
      AppData.fromJson(
        jsonDecode(jsonEncode(migrated.toJson())),
      ).trips.single.spentMinor,
      7000,
    );
    expect(migrated.toJson()['schemaVersion'], 2);
  });

  test('remaining days and posted amount drive practical budget pace', () {
    final trip = Trip(
      id: 't',
      title: 'Trip',
      baseCurrency: 'CNY',
      localCurrency: 'JPY',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 5),
      budgets: {
        for (final category in BudgetCategory.values)
          category: category == BudgetCategory.food ? 10000 : 0,
      },
      stage: TripStage.active,
      createdAt: DateTime.utc(2026, 8, 1),
      expenses: [
        Expense(
          id: 'e',
          title: '',
          category: BudgetCategory.food,
          amountMinor: 1000,
          currency: 'JPY',
          rate: 0.05,
          bookedMinor: 5000,
          settledMinor: 4500,
          recordedAt: DateTime.utc(2026, 9, 2),
        ),
      ],
    );
    expect(trip.spentMinor, 4500);
    expect(trip.estimatedCount, 0);
    expect(trip.daysRemaining(DateTime(2026, 9, 3)), 3);
    expect(trip.dailyAvailableMinor(DateTime(2026, 9, 3)), 1833);
    expect(trip.dailyAvailableMinor(DateTime(2026, 9, 6)), isNull);
  });

  test('ledger filters by category and inclusive travel dates', () {
    Expense expense(String id, BudgetCategory category, int day) => Expense(
      id: id,
      title: id,
      category: category,
      amountMinor: 1000,
      currency: 'CNY',
      rate: 1,
      bookedMinor: 1000,
      settledMinor: 1000,
      recordedAt: DateTime.utc(2026, 9, day),
    );
    final trip = Trip(
      id: 't',
      title: 'Trip',
      baseCurrency: 'CNY',
      budgets: {for (final item in BudgetCategory.values) item: 1000},
      stage: TripStage.active,
      createdAt: DateTime.utc(2026, 9, 1),
      expenses: [
        expense('stay', BudgetCategory.stay, 1),
        expense('food', BudgetCategory.food, 2),
        expense('food-later', BudgetCategory.food, 4),
      ],
    );
    expect(
      filterTripExpenses(
        trip,
        category: BudgetCategory.food,
        startDate: DateTime(2026, 9, 2),
        endDate: DateTime(2026, 9, 2),
      ).map((item) => item.id),
      ['food'],
    );
    expect(filterTripExpenses(trip).map((item) => item.id), [
      'food-later',
      'food',
      'stay',
    ]);
  });

  test('review bands use settled spending and exact budget boundaries', () {
    Trip tripFor(int? spent, {int planned = 10000, bool settled = true}) =>
        Trip(
          id: 't',
          title: 'Trip',
          baseCurrency: 'CNY',
          budgets: {BudgetCategory.food: planned},
          stage: TripStage.active,
          createdAt: DateTime.utc(2026, 9, 1),
          expenses: spent == null
              ? const []
              : [
                  Expense(
                    id: 'e',
                    title: 'Meal',
                    category: BudgetCategory.food,
                    amountMinor: spent,
                    currency: 'CNY',
                    rate: 1,
                    bookedMinor: spent,
                    settledMinor: settled ? spent : null,
                    recordedAt: DateTime.utc(2026, 9, 2),
                  ),
                ],
        );

    expect(reviewBandFor(tripFor(null)), isNull);
    expect(reviewBandFor(tripFor(3000, settled: false)), isNull);
    expect(reviewBandFor(tripFor(1000, planned: 0)), isNull);
    final cases = <int, ReviewBand>{
      3000: ReviewBand.atMost30,
      3001: ReviewBand.atMost60,
      6000: ReviewBand.atMost60,
      6001: ReviewBand.atMost90,
      9000: ReviewBand.atMost90,
      9001: ReviewBand.atMost100,
      10000: ReviewBand.atMost100,
      10001: ReviewBand.overAtMost50,
      15000: ReviewBand.overAtMost50,
      15001: ReviewBand.overAtMost100,
      20000: ReviewBand.overAtMost100,
      20001: ReviewBand.overMoreThan100,
    };
    for (final entry in cases.entries) {
      expect(reviewBandFor(tripFor(entry.key)), entry.value);
    }
  });
}
