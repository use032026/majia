import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/backup.dart';
import 'package:trip_delta/domain.dart';

void main() {
  final trip = Trip(
    id: 'trip-1',
    title: 'Kyoto',
    baseCurrency: 'CNY',
    budgets: {for (final item in BudgetCategory.values) item: 10000},
    stage: TripStage.completed,
    createdAt: DateTime.utc(2026, 9, 1),
    expenses: [
      Expense(
        id: 'expense-1',
        title: 'Dinner',
        category: BudgetCategory.food,
        amountMinor: 5000,
        currency: 'CNY',
        rate: 1,
        bookedMinor: 5000,
        settledMinor: 5000,
        recordedAt: DateTime.utc(2026, 9, 2),
      ),
    ],
    reflection: 'Plan dinner earlier',
  );

  test('backup round trip restores trips, expenses, and language', () {
    final restored = TripBackupCodec.decode(
      TripBackupCodec.encode(AppData(trips: [trip], language: 'zh')),
    );
    expect(restored.language, 'zh');
    expect(restored.trips.single.title, 'Kyoto');
    expect(restored.trips.single.expenses.single.title, 'Dinner');
    expect(restored.trips.single.reflection, 'Plan dinner earlier');
  });

  test('bad, duplicate, and oversized backups are rejected', () {
    final valid =
        jsonDecode(utf8.decode(TripBackupCodec.encode(AppData(trips: [trip]))))
            as Map<String, dynamic>;
    final invalidVersion = Map<String, dynamic>.of(valid)
      ..['backupVersion'] = 2;
    expect(
      () => TripBackupCodec.decode(
        Uint8List.fromList(utf8.encode(jsonEncode(invalidVersion))),
      ),
      throwsFormatException,
    );
    final duplicate = Map<String, dynamic>.of(valid)
      ..['data'] = {
        ...valid['data'] as Map<String, dynamic>,
        'trips': [trip.toJson(), trip.toJson()],
      };
    expect(
      () => TripBackupCodec.decode(
        Uint8List.fromList(utf8.encode(jsonEncode(duplicate))),
      ),
      throwsFormatException,
    );
    expect(
      () => TripBackupCodec.decode(Uint8List(maxBackupBytes + 1)),
      throwsFormatException,
    );
  });
}
