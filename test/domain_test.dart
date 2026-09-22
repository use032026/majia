import 'package:flutter_test/flutter_test.dart';
import 'package:steady21/domain.dart';

Experiment _experiment({
  List<DailyEntry> entries = const [],
  List<MilestoneReview> reviews = const [],
}) => Experiment(
  id: 'e1',
  title: 'Read',
  cue: 'After dinner',
  fullAction: 'Read 10 pages',
  minimumAction: 'Read 1 page',
  targetDays: 21,
  startedAt: DateTime(2026, 9, 1),
  entries: entries,
  reviews: reviews,
);

void main() {
  test('title boundaries are exhaustive and non-overlapping', () {
    final expected = {
      0: '起念时刻',
      1: '小试牛刀',
      6: '小试牛刀',
      7: '渐入佳境',
      14: '渐入佳境',
      15: '稳步推进',
      20: '稳步推进',
      21: '廿一新章',
      22: '稳步成章',
      30: '稳步成章',
      31: '长期同行',
      365: '长期同行',
    };
    for (final item in expected.entries) {
      expect(tierForDays(item.key).zh, item.value);
      expect(
        progressTiers.where((tier) => tier.contains(item.key)),
        hasLength(1),
      );
    }
  });

  test('stats distinguish practice, skips, streaks, and common obstacle', () {
    final experiment = _experiment(
      entries: const [
        DailyEntry(date: '2026-09-18', kind: EntryKind.full),
        DailyEntry(date: '2026-09-19', kind: EntryKind.minimum),
        DailyEntry(
          date: '2026-09-20',
          kind: EntryKind.skipped,
          obstacle: Obstacle.energy,
          recoveryPlan: RecoveryPlan.makeSmaller,
        ),
        DailyEntry(
          date: '2026-09-21',
          kind: EntryKind.full,
          recoveryPlan: RecoveryPlan.makeSmaller,
        ),
      ],
    );
    final stats = ExperimentStats(experiment, DateTime(2026, 9, 22));
    expect(stats.practiceDays, 3);
    expect(stats.fullDays, 2);
    expect(stats.minimumDays, 1);
    expect(stats.skippedDays, 1);
    expect(stats.currentStreak, 1);
    expect(stats.bestStreak, 2);
    expect(stats.recoveryCount, 1);
    expect(stats.commonObstacle, Obstacle.energy);
    expect(stats.elapsedDays, 22);
  });

  test('milestone becomes due once and disappears after review', () {
    final entries = List.generate(
      7,
      (index) => DailyEntry(
        date: '2026-09-${(index + 1).toString().padLeft(2, '0')}',
        kind: EntryKind.full,
      ),
    );
    final due = ExperimentStats(
      _experiment(entries: entries),
      DateTime(2026, 9, 7),
    );
    expect(due.dueMilestones, [7]);

    final reviewed = ExperimentStats(
      _experiment(
        entries: entries,
        reviews: [
          MilestoneReview(
            milestone: 7,
            decision: ReviewDecision.keep,
            recordedAt: DateTime(2026, 9, 7),
          ),
        ],
      ),
      DateTime(2026, 9, 7),
    );
    expect(reviewed.dueMilestones, isEmpty);
  });

  test('snapshot JSON round-trips and rejects multiple active experiments', () {
    final snapshot = AppSnapshot(
      localeCode: 'en',
      experiments: [_experiment()],
    );
    final restored = AppSnapshot.fromJson(snapshot.toJson());
    expect(restored.localeCode, 'en');
    expect(restored.active?.minimumAction, 'Read 1 page');

    final duplicate = snapshot.toJson();
    duplicate['experiments'] = [_experiment().toJson(), _experiment().toJson()];
    expect(() => AppSnapshot.fromJson(duplicate), throwsFormatException);
  });

  test('invalid calendar dates are rejected', () {
    expect(() => dateFromKey('2026-02-30'), throwsFormatException);
    expect(localDateKey(DateTime(2026, 9, 2)), '2026-09-02');
  });

  test('civil-day math is stable across daylight-saving calendar dates', () {
    expect(civilDayNumber('2026-03-09') - civilDayNumber('2026-03-08'), 1);
    expect(civilDayNumber('2026-11-02') - civilDayNumber('2026-11-01'), 1);
  });

  test('an explicit pause today resets current streak', () {
    final experiment = _experiment(
      entries: const [
        DailyEntry(date: '2026-09-20', kind: EntryKind.full),
        DailyEntry(date: '2026-09-21', kind: EntryKind.minimum),
        DailyEntry(
          date: '2026-09-22',
          kind: EntryKind.skipped,
          obstacle: Obstacle.time,
          recoveryPlan: RecoveryPlan.changeTime,
        ),
      ],
    );
    expect(ExperimentStats(experiment, DateTime(2026, 9, 22)).currentStreak, 0);
  });
}
