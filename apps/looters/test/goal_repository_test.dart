import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_jar/data/goal_repository.dart';
import 'package:pace_jar/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 single-goal data migrates into the v2 goal library', () async {
    final legacyGoal = sampleGoal(name: 'Legacy goal');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pace_jar.goal.v1': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'goal': legacyGoal.toJson(),
      }),
    });
    final repository = SharedPreferencesGoalRepository();

    final migrated = await repository.loadLibrary();
    expect(migrated.activeGoal!.name, 'Legacy goal');
    expect(migrated.completedGoals, isEmpty);

    await repository.saveLibrary(migrated);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('pace_jar.library.v2'), isTrue);
    expect(preferences.containsKey('pace_jar.goal.v1'), isFalse);

    final reloaded = await repository.loadLibrary();
    expect(reloaded.activeGoal!.name, 'Legacy goal');
  });

  test('v2 storage preserves completed goals without an active goal', () async {
    final completed = sampleGoal(
      targetCents: 20000,
      events: <SavingsEvent>[
        SavingsEvent(
          id: 'finish',
          type: SavingsEventType.deposit,
          amountCents: 10000,
          occurredAt: DateTime(2026, 9, 10),
        ),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = SharedPreferencesGoalRepository();

    await repository.saveLibrary(
      GoalLibrary(completedGoals: <SavingsGoal>[completed]),
    );
    final reloaded = await repository.loadLibrary();

    expect(reloaded.activeGoal, isNull);
    expect(reloaded.completedGoals.single.id, completed.id);
  });
}
