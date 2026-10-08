import 'package:diary/domain/diary_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repository.dart';

void main() {
  test('snapshot JSON round trip preserves reflection thread', () {
    final now = DateTime(2026, 9, 30, 9);
    final echo = DiaryEcho(
      id: 'echo-1',
      createdAt: now.add(const Duration(days: 7)),
      body: 'The answer became clearer after I waited.',
      shift: EchoShift.clearer,
    );
    final original = DiarySnapshot(
      localeCode: 'en',
      themeMode: 'dark',
      hasCompletedOnboarding: true,
      entries: <DiaryEntry>[
        sampleEntry(
          now: now,
          echoes: <DiaryEcho>[echo],
          closedAt: echo.createdAt,
        ),
      ],
    );

    final restored = DiarySnapshot.fromJson(original.toJson());

    expect(restored.localeCode, 'en');
    expect(restored.themeMode, 'dark');
    expect(restored.hasCompletedOnboarding, isTrue);
    expect(restored.entries.single.title, original.entries.single.title);
    expect(restored.entries.single.echoes.single.shift, EchoShift.clearer);
    expect(restored.entries.single.createdAt.isAtSameMomentAs(now), isTrue);
  });

  test('older snapshot without onboarding state remains readable', () {
    final json = const DiarySnapshot.empty().toJson()
      ..remove('onboardingCompletedV1');

    final restored = DiarySnapshot.fromJson(json);

    expect(restored.hasCompletedOnboarding, isFalse);
  });

  test('search includes original page, question, and later echoes', () {
    final entry = sampleEntry(
      echoes: <DiaryEcho>[
        DiaryEcho(
          id: 'echo-1',
          createdAt: DateTime(2026, 10, 7),
          body: 'A quiet answer appeared.',
          shift: EchoShift.changed,
        ),
      ],
    );

    expect(entry.matches('turning'), isTrue);
    expect(entry.matches('avoiding'), isTrue);
    expect(entry.matches('next week'), isTrue);
    expect(entry.matches('quiet answer'), isTrue);
    expect(entry.matches('not present'), isFalse);
  });

  test('due state excludes closed and deleted threads', () {
    final now = DateTime(2026, 10, 10);
    final due = sampleEntry(revisitAt: now.subtract(const Duration(days: 1)));
    final closed = due.copyWith(closedAt: now);
    final deleted = due.copyWith(deletedAt: now);

    expect(due.isDue(now), isTrue);
    expect(closed.isDue(now), isFalse);
    expect(deleted.isDue(now), isFalse);
  });

  test('snapshot loading rejects contradictory and duplicate states', () {
    final snapshot = DiarySnapshot(
      entries: <DiaryEntry>[sampleEntry()],
    ).toJson();
    final invalidOpen = Map<String, Object?>.from(
      (snapshot['entries']! as List<Object?>).single! as Map,
    );
    invalidOpen['revisitAt'] = null;
    expect(
      () => DiarySnapshot.fromJson(<String, Object?>{
        ...snapshot,
        'entries': <Object?>[invalidOpen],
      }),
      throwsFormatException,
    );

    final duplicate = sampleEntry().toJson();
    expect(
      () => DiarySnapshot.fromJson(<String, Object?>{
        ...snapshot,
        'entries': <Object?>[duplicate, duplicate],
      }),
      throwsFormatException,
    );

    final whitespaceQuestion = Map<String, Object?>.from(duplicate)
      ..['futureQuestion'] = '   '
      ..['revisitAt'] = null;
    expect(
      () => DiarySnapshot.fromJson(<String, Object?>{
        ...snapshot,
        'entries': <Object?>[whitespaceQuestion],
      }),
      throwsFormatException,
    );
  });
}
