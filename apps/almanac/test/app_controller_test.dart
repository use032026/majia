import 'dart:convert';

import 'package:almanac/src/app_controller.dart';
import 'package:almanac/src/domain/almanac_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  final now = DateTime(2026, 10, 10, 9, 30);

  test('first load creates and persists a stable daily leaf', () async {
    final store = MemoryStateStore();
    final controller = AppController(
      store: store,
      seedFactory: () => 'fixed-seed',
      clock: () => now,
    );
    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(controller.todayLeaf.dateKey, '2026-10-10');
    expect(store.value, isNotNull);

    final second = AppController(
      store: store,
      seedFactory: () => 'different-seed',
      clock: () => now,
    );
    await second.load();
    expect(
      second.todayLeaf.seedFingerprint,
      controller.todayLeaf.seedFingerprint,
    );
  });

  test(
    'save failure preserves both prior memory and prior disk value',
    () async {
      final store = MemoryStateStore();
      final controller = AppController(
        store: store,
        seedFactory: () => 'fixed-seed',
        clock: () => now,
      );
      await controller.load();
      final diskBefore = store.value;
      final leaf = controller.todayLeaf;
      store.failWrite = true;

      final saved = await controller.sealToday(
        suitableId: leaf.suitablePromptIds.first,
        avoidId: leaf.avoidPromptIds.first,
        intention: 'Keep the old value safe.',
      );

      expect(saved, isFalse);
      expect(controller.hasSaveFailure, isTrue);
      expect(controller.todayLeaf.isSealed, isFalse);
      expect(store.value, diskBefore);
    },
  );

  test('sealed leaf survives relaunch and can be reflected', () async {
    final store = MemoryStateStore();
    final controller = AppController(
      store: store,
      seedFactory: () => 'fixed-seed',
      clock: () => now,
    );
    await controller.load();
    final leaf = controller.todayLeaf;
    expect(
      await controller.sealToday(
        suitableId: leaf.suitablePromptIds.first,
        avoidId: leaf.avoidPromptIds.first,
        intention: 'Do the small thing.',
      ),
      isTrue,
    );
    expect(await controller.reflectToday(ReflectionOutcome.practiced), isTrue);

    final reloaded = AppController(
      store: store,
      seedFactory: () => 'unused',
      clock: () => now,
    );
    await reloaded.load();
    expect(reloaded.todayLeaf.isSealed, isTrue);
    expect(reloaded.todayLeaf.outcome, ReflectionOutcome.practiced);
    expect(reloaded.archivedLeaves, hasLength(1));
  });

  test('corrupt local data locks writes until explicit recovery', () async {
    final store = MemoryStateStore(value: '{broken-json');
    final controller = AppController(
      store: store,
      seedFactory: () => 'recovery-seed',
      clock: () => now,
    );
    await controller.load();

    expect(controller.hasLoadFailure, isTrue);
    expect(controller.isLoaded, isFalse);
    expect(await controller.recoverWithReset(), isTrue);
    expect(controller.isLoaded, isTrue);
    expect(controller.todayLeaf.isSealed, isFalse);
  });

  test('language preference does not regenerate daily content', () async {
    final controller = AppController(
      store: MemoryStateStore(),
      seedFactory: () => 'fixed-seed',
      clock: () => now,
    );
    await controller.load();
    final before = controller.todayLeaf.toJson();
    await controller.setLocaleMode(AppLocaleMode.en);
    expect(controller.todayLeaf.toJson(), before);
  });

  test('crossing midnight creates exactly one deterministic leaf', () async {
    final store = MemoryStateStore();
    var current = DateTime(2026, 10, 10, 23, 59);
    final controller = AppController(
      store: store,
      seedFactory: () => 'midnight-seed',
      clock: () => current,
    );
    await controller.load();
    final firstFingerprint = controller.todayLeaf.seedFingerprint;
    final writesBeforeRollover = store.writeCount;

    current = DateTime(2026, 10, 11, 0, 1);
    expect(await controller.refreshForCurrentDate(), isTrue);
    expect(controller.todayLeaf.dateKey, '2026-10-11');
    expect(controller.data!.leaves, hasLength(2));
    expect(store.writeCount, writesBeforeRollover + 1);
    final secondFingerprint = controller.todayLeaf.seedFingerprint;
    expect(secondFingerprint, isNot(firstFingerprint));

    expect(await controller.refreshForCurrentDate(), isTrue);
    expect(store.writeCount, writesBeforeRollover + 1);
    expect(controller.todayLeaf.seedFingerprint, secondFingerprint);

    final leaf = controller.todayLeaf;
    expect(
      await controller.sealToday(
        suitableId: leaf.suitablePromptIds.first,
        avoidId: leaf.avoidPromptIds.first,
        intention: 'Begin the new day safely.',
      ),
      isTrue,
    );
  });

  test('stale pre-midnight selections are rejected without throwing', () async {
    final store = MemoryStateStore();
    var current = DateTime(2026, 10, 10, 23, 59);
    final controller = AppController(
      store: store,
      seedFactory: () => 'rollover-race-seed',
      clock: () => current,
    );
    await controller.load();
    final yesterday = controller.todayLeaf;
    final writesBefore = store.writeCount;

    current = DateTime(2026, 10, 11, 0, 0, 1);
    expect(
      await controller.sealToday(
        suitableId: yesterday.suitablePromptIds.first,
        avoidId: yesterday.avoidPromptIds.first,
        intention: 'This belongs to yesterday.',
      ),
      isFalse,
    );
    expect(controller.todayLeaf.dateKey, '2026-10-11');
    expect(controller.todayLeaf.isSealed, isFalse);
    expect(controller.hasDayChangedNotice, isTrue);
    expect(store.writeCount, writesBefore + 1);

    final today = controller.todayLeaf;
    expect(
      await controller.sealToday(
        suitableId: today.suitablePromptIds.first,
        avoidId: today.avoidPromptIds.first,
        intention: 'This belongs to today.',
      ),
      isTrue,
    );
    expect(controller.hasDayChangedNotice, isFalse);
  });

  test(
    'unknown stored prompt ID fails closed without replacing raw data',
    () async {
      final store = MemoryStateStore();
      final original = AppController(
        store: store,
        seedFactory: () => 'fixed-seed',
        clock: () => now,
      );
      await original.load();
      final decoded = jsonDecode(store.value!) as Map<String, dynamic>;
      final leaves = decoded['leaves'] as Map<String, dynamic>;
      final leaf = leaves['2026-10-10'] as Map<String, dynamic>;
      leaf['suitablePromptIds'] = <String>[
        'removed-prompt',
        ...((leaf['suitablePromptIds'] as List).cast<String>().skip(1)),
      ];
      store.value = jsonEncode(decoded);
      final rawBefore = store.value;

      final reloaded = AppController(
        store: store,
        seedFactory: () => 'unused',
        clock: () => now,
      );
      await reloaded.load();

      expect(reloaded.hasLoadFailure, isTrue);
      expect(reloaded.isLoaded, isFalse);
      expect(store.value, rawBefore);
    },
  );

  test('intention length uses user-perceived characters', () async {
    final controller = AppController(
      store: MemoryStateStore(),
      seedFactory: () => 'emoji-seed',
      clock: () => now,
    );
    await controller.load();
    var leaf = controller.todayLeaf;
    expect(
      await controller.sealToday(
        suitableId: leaf.suitablePromptIds.first,
        avoidId: leaf.avoidPromptIds.first,
        intention: List<String>.filled(140, '🪷').join(),
      ),
      isTrue,
    );

    final second = AppController(
      store: MemoryStateStore(),
      seedFactory: () => 'emoji-seed-two',
      clock: () => now,
    );
    await second.load();
    leaf = second.todayLeaf;
    expect(
      () => second.sealToday(
        suitableId: leaf.suitablePromptIds.first,
        avoidId: leaf.avoidPromptIds.first,
        intention: List<String>.filled(141, '🪷').join(),
      ),
      throwsArgumentError,
    );
    expect(second.todayLeaf.isSealed, isFalse);
  });

  test('Markdown export localizes outcomes and escapes user text', () async {
    final controller = AppController(
      store: MemoryStateStore(),
      seedFactory: () => 'export-seed',
      clock: () => now,
    );
    await controller.load();
    final leaf = controller.todayLeaf;
    await controller.sealToday(
      suitableId: leaf.suitablePromptIds.first,
      avoidId: leaf.avoidPromptIds.first,
      intention: '**先做**\n再看 [链接](x)',
    );
    await controller.reflectToday(ReflectionOutcome.practiced);

    final zh = controller.exportMarkdown(useChinese: true);
    final en = controller.exportMarkdown(useChinese: false);
    expect(zh, contains('- 回看: 践行'));
    expect(en, contains('- Reflection: Practiced'));
    expect(zh, contains(r'\*\*先做\*\* 再看 \[链接\]\(x\)'));
    expect(zh, isNot(contains('practiced')));
  });
}
