import 'dart:convert';

import 'package:almanac/src/app_controller.dart';
import 'package:almanac/src/domain/almanac_content.dart';
import 'package:almanac/src/domain/almanac_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  const seed = 'history-compatibility-seed';
  final today = DateTime(2026, 11, 7, 9);

  String historySnapshot() {
    const generator = AlmanacGenerator();
    final leaves = <String, DailyLeaf>{};
    for (var daysAgo = 364; daysAgo >= 0; daysAgo--) {
      final date = today.subtract(Duration(days: daysAgo));
      final leaf = generator.generate(date: date, installationSeed: seed);
      leaves[leaf.dateKey] = leaf.copyWith(
        selectedSuitableId: leaf.suitablePromptIds.first,
        selectedAvoidId: leaf.avoidPromptIds.first,
        intention: daysAgo.isEven ? '留一点空白。' : 'Leave a little space.',
        sealedAt: date,
        outcome: ReflectionOutcome.practiced,
        reflectedAt: date.add(const Duration(hours: 8)),
      );
    }
    return jsonEncode(
      AlmanacData.initial(seed)
          .copyWith(
            onboardingSeen: true,
            localeMode: AppLocaleMode.en,
            themeMode: AppThemeMode.dark,
            leaves: leaves,
          )
          .toJson(),
    );
  }

  AppController controllerFor(MemoryStateStore store) => AppController(
    store: store,
    seedFactory: () => 'unused',
    clock: () => today,
  );

  test(
    'fake schema-one history loads 365 bilingual leaves without rewriting',
    () async {
      final snapshot = historySnapshot();
      final store = MemoryStateStore(value: snapshot);
      final controller = controllerFor(store);
      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.hasLoadFailure, isFalse);
      expect(controller.data!.schemaVersion, 1);
      expect(controller.data!.localeMode, AppLocaleMode.en);
      expect(controller.data!.themeMode, AppThemeMode.dark);
      expect(controller.archivedLeaves, hasLength(365));
      expect(controller.archivedLeaves.first.dateKey, formatDateKey(today));
      expect(jsonEncode(controller.data!.toJson()), snapshot);
      expect(controller.exportMarkdown(useChinese: true), contains('留一点空白。'));
      expect(
        controller.exportMarkdown(useChinese: false),
        contains(r'Leave a little space\.'),
      );
      expect(store.value, snapshot);
      expect(store.writeCount, 0);
    },
  );

  for (final corruptId in ['removed-prompt', 'a-open-many']) {
    test(
      'fake history with suitable ID $corruptId fails without overwriting',
      () async {
        final data = jsonDecode(historySnapshot()) as Map<String, dynamic>;
        final leaves = data['leaves'] as Map<String, dynamic>;
        final older = leaves.values.first as Map<String, dynamic>;
        final ids = older['suitablePromptIds'] as List<dynamic>;
        ids[0] = corruptId;
        final corruptSnapshot = jsonEncode(data);
        final store = MemoryStateStore(value: corruptSnapshot);
        final controller = controllerFor(store);
        await controller.load();

        expect(controller.hasLoadFailure, isTrue);
        expect(controller.isLoaded, isFalse);
        expect(store.value, corruptSnapshot);
        expect(store.writeCount, 0);
      },
    );
  }

  test(
    'fake history save failure preserves records and retry succeeds',
    () async {
      final snapshot = historySnapshot();
      final store = MemoryStateStore(value: snapshot);
      final controller = controllerFor(store);
      await controller.load();
      final before = jsonEncode(controller.data!.toJson());
      store.failWrite = true;

      expect(await controller.setLocaleMode(AppLocaleMode.zhHans), isFalse);
      expect(controller.hasSaveFailure, isTrue);
      expect(jsonEncode(controller.data!.toJson()), before);
      expect(store.value, snapshot);

      store.failWrite = false;
      expect(await controller.setLocaleMode(AppLocaleMode.zhHans), isTrue);
      expect(controller.hasSaveFailure, isFalse);
      final relaunched = controllerFor(store);
      await relaunched.load();
      expect(relaunched.data!.localeMode, AppLocaleMode.zhHans);
      expect(relaunched.archivedLeaves, hasLength(365));
      expect(relaunched.todayLeaf.toJson(), controller.todayLeaf.toJson());
    },
  );
}
