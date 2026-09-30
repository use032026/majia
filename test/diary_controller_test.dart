import 'package:diary/domain/diary_entry.dart';
import 'package:diary/state/diary_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repository.dart';

class MutableClock {
  MutableClock(this.value);

  DateTime value;

  DateTime call() => value;
}

void main() {
  late MutableClock clock;
  late FakeDiaryRepository repository;
  late DiaryController controller;

  setUp(() {
    clock = MutableClock(DateTime(2026, 9, 30, 9));
    repository = FakeDiaryRepository();
    controller = DiaryController(repository, clock: clock.call);
  });

  test(
    'load failure locks writes instead of exposing an empty editable diary',
    () async {
      repository.failLoad = true;

      await controller.initialize();

      expect(controller.storageLocked, isTrue);
      expect(controller.error, contains('load failed'));
      expect(
        await controller.createEntry(
          title: '',
          body: 'Must not overwrite',
          mood: EntryMood.calm,
          futureQuestion: '',
        ),
        isNull,
      );
      expect(
        await controller.createEntry(
          title: 'Missing schedule',
          body: 'A question cannot become an unreachable open thread.',
          mood: EntryMood.calm,
          futureQuestion: 'When should this return?',
        ),
        isNull,
      );
      expect(repository.saveCount, 0);
    },
  );

  test('backup recovery is visible until the user dismisses it', () async {
    repository.recoveredFromBackup = true;
    await controller.initialize();

    expect(controller.recoveredFromBackup, isTrue);
    controller.dismissRecoveryNotice();
    expect(controller.recoveredFromBackup, isFalse);
  });

  test('failed save leaves the in-memory diary unchanged', () async {
    await controller.initialize();
    repository.failSave = true;

    final created = await controller.createEntry(
      title: 'Unsafe write',
      body: 'This should not appear after the repository fails.',
      mood: EntryMood.heavy,
      futureQuestion: '',
    );

    expect(created, isNull);
    expect(controller.activeEntries, isEmpty);
    expect(controller.error, contains('save failed'));
  });

  test(
    'empty original page and empty echo are rejected at domain boundary',
    () async {
      await controller.initialize();
      expect(
        await controller.createEntry(
          title: '',
          body: '   ',
          mood: EntryMood.calm,
          futureQuestion: '',
        ),
        isNull,
      );

      final entry = await controller.createEntry(
        title: 'Valid',
        body: 'A complete page.',
        mood: EntryMood.calm,
        futureQuestion: 'What comes next?',
        revisitAt: clock.value,
      );
      expect(entry, isNotNull);
      expect(
        await controller.addEcho(
          entryId: entry!.id,
          body: ' ',
          shift: EchoShift.same,
          closeThread: true,
        ),
        isFalse,
      );
      expect(
        await controller.addEcho(
          entryId: entry.id,
          body: 'Keep this thread open.',
          shift: EchoShift.same,
          closeThread: false,
        ),
        isFalse,
      );
    },
  );

  test('create, revisit, close, and search form a complete thread', () async {
    await controller.initialize();
    final entry = await controller.createEntry(
      title: 'The first page',
      body: 'I wrote down the moment before judging it.',
      mood: EntryMood.uncertain,
      futureQuestion: 'What will become clearer?',
      revisitAt: clock.value,
    );
    expect(controller.dueEntries(), hasLength(1));

    clock.value = clock.value.add(const Duration(days: 3));
    final saved = await controller.addEcho(
      entryId: entry!.id,
      body: 'Waiting made the important part easier to name.',
      shift: EchoShift.clearer,
      closeThread: true,
    );

    expect(saved, isTrue);
    expect(controller.dueEntries(), isEmpty);
    expect(controller.entryById(entry.id)!.echoes, hasLength(1));
    expect(controller.entryById(entry.id)!.isClosed, isTrue);
    expect(controller.entryById(entry.id)!.matches('easier to name'), isTrue);
  });

  test('open echo reschedules the same stable entry', () async {
    await controller.initialize();
    final entry = await controller.createEntry(
      title: 'Continue',
      body: 'This needs more time.',
      mood: EntryMood.calm,
      futureQuestion: 'Has the situation changed?',
      revisitAt: clock.value,
    );
    final nextDate = clock.value.add(const Duration(days: 7));

    expect(
      await controller.addEcho(
        entryId: entry!.id,
        body: 'Not enough information yet.',
        shift: EchoShift.same,
        closeThread: false,
        nextRevisitAt: nextDate,
      ),
      isTrue,
    );

    final updated = controller.entryById(entry.id)!;
    expect(updated.id, entry.id);
    expect(updated.isClosed, isFalse);
    expect(updated.revisitAt, nextDate);
    expect(updated.echoes, hasLength(1));
  });

  test('trash supports restore and permanent deletion', () async {
    await controller.initialize();
    final entry = await controller.createEntry(
      title: 'Recoverable',
      body: 'Do not erase this immediately.',
      mood: EntryMood.calm,
      futureQuestion: '',
    );

    expect(await controller.moveToTrash(entry!.id), isTrue);
    expect(controller.activeEntries, isEmpty);
    expect(controller.trashEntries.single.id, entry.id);

    expect(await controller.restore(entry.id), isTrue);
    expect(controller.activeEntries.single.id, entry.id);

    expect(await controller.moveToTrash(entry.id), isTrue);
    expect(await controller.deleteForever(entry.id), isTrue);
    expect(controller.entryById(entry.id), isNull);
    expect(repository.lastDiscardHistory, isTrue);
  });

  test(
    'normal edit preserves due date and closed state unless explicitly reopened',
    () async {
      final dueDate = clock.value.subtract(const Duration(days: 2));
      final closedAt = clock.value.subtract(const Duration(days: 1));
      final echo = DiaryEcho(
        id: 'echo-old',
        createdAt: closedAt,
        body: 'This thread was closed.',
        shift: EchoShift.resolved,
      );
      repository.stored = DiarySnapshot(
        entries: <DiaryEntry>[
          sampleEntry(id: 'due', revisitAt: dueDate),
          sampleEntry(
            id: 'closed',
            echoes: <DiaryEcho>[echo],
            closedAt: closedAt,
          ).copyWith(clearRevisitAt: true),
        ],
      );
      await controller.initialize();

      final due = controller.entryById('due')!;
      expect(
        await controller.updateEntry(
          id: due.id,
          title: 'Edited title',
          body: due.body,
          mood: due.mood,
          futureQuestion: due.futureQuestion,
          revisitAt: due.revisitAt,
        ),
        isTrue,
      );
      expect(controller.entryById('due')!.revisitAt, dueDate);
      expect(controller.entryById('due')!.isDue(clock.value), isTrue);

      final closed = controller.entryById('closed')!;
      expect(
        await controller.updateEntry(
          id: closed.id,
          title: 'Edited but closed',
          body: closed.body,
          mood: closed.mood,
          futureQuestion: closed.futureQuestion,
        ),
        isTrue,
      );
      expect(controller.entryById('closed')!.isClosed, isTrue);
      expect(controller.entryById('closed')!.revisitAt, isNull);

      final reopenDate = clock.value.add(const Duration(days: 7));
      expect(
        await controller.updateEntry(
          id: closed.id,
          title: 'Explicitly reopened',
          body: closed.body,
          mood: closed.mood,
          futureQuestion: closed.futureQuestion,
          revisitAt: reopenDate,
        ),
        isTrue,
      );
      expect(controller.entryById('closed')!.isClosed, isFalse);
      expect(controller.entryById('closed')!.revisitAt, reopenDate);
    },
  );

  test('locale and theme changes use the same persisted snapshot', () async {
    await controller.initialize();

    expect(await controller.setLocale('zh'), isTrue);
    expect(await controller.setTheme('dark'), isTrue);

    expect(repository.stored.localeCode, 'zh');
    expect(repository.stored.themeMode, 'dark');
    expect(repository.saveCount, 2);
  });
}
