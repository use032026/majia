import 'package:pace_jar/data/goal_repository.dart';
import 'package:pace_jar/domain/models.dart';

class FakeGoalRepository implements GoalRepository {
  SavingsGoal? goal;
  String? localeCode;
  bool? darkMode;
  bool failSave = false;
  bool failClear = false;
  bool failLoad = false;
  bool corrupt = false;
  int saveCalls = 0;

  @override
  Future<void> clearGoal() async {
    if (failClear) throw StateError('clear failed');
    goal = null;
    corrupt = false;
  }

  @override
  Future<bool?> loadDarkMode() async => darkMode;

  @override
  Future<SavingsGoal?> loadGoal() async {
    if (failLoad) throw StateError('load failed');
    if (corrupt) throw const FormatException('corrupt');
    return goal;
  }

  @override
  Future<String?> loadLocaleCode() async => localeCode;

  @override
  Future<void> saveDarkMode(bool enabled) async {
    if (failSave) throw StateError('save failed');
    darkMode = enabled;
  }

  @override
  Future<void> saveGoal(SavingsGoal value) async {
    saveCalls++;
    if (failSave) throw StateError('save failed');
    goal = value;
  }

  @override
  Future<void> saveLocaleCode(String value) async {
    if (failSave) throw StateError('save failed');
    localeCode = value;
  }
}

SavingsGoal sampleGoal({
  DateTime? createdAt,
  int targetCents = 100000,
  int startingCents = 10000,
  int weeklyCents = 10000,
  DateTime? targetDate,
  List<SavingsEvent> events = const <SavingsEvent>[],
  List<PlanVersion>? plans,
  String name = 'Laptop buffer',
}) {
  final created = createdAt ?? DateTime(2026, 9, 1, 9);
  return SavingsGoal(
    id: 'goal-1',
    name: name,
    currency: r'$',
    targetCents: targetCents,
    startingCents: startingCents,
    createdAt: created,
    events: events,
    plans:
        plans ??
        <PlanVersion>[
          PlanVersion(
            id: 'plan-1',
            effectiveAt: created,
            weeklyCents: weeklyCents,
            targetDate: targetDate ?? created.add(const Duration(days: 70)),
            baselineCents: startingCents,
            reason: PlanReason.initial,
          ),
        ],
  );
}
