import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/domain.dart';
import 'package:trip_delta/store.dart';

void main() {
  test('file store persists atomically and refuses corrupt input', () async {
    final directory = await Directory.systemTemp.createTemp('trip_delta_test_');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileTripStore(directory: directory);
    expect((await store.load()).trips, isEmpty);
    await store.save(const AppData(language: 'zh'));
    expect((await store.load()).language, 'zh');
    final file = File('${directory.path}/trip_delta_v1.json');
    await file.writeAsString('{broken');
    await expectLater(store.load(), throwsFormatException);
    expect(await file.readAsString(), '{broken');
  });

  test('controller commits state only after store succeeds', () async {
    final store = FailingStore();
    final controller = AppController(store);
    addTearDown(controller.dispose);
    await controller.load();
    store.fail = true;
    await expectLater(controller.setLanguage('zh'), throwsStateError);
    expect(controller.data.language, 'auto');
    store.fail = false;
    await controller.setLanguage('en');
    expect(controller.data.language, 'en');
  });

  test(
    'merge keeps local conflicts, replace restores backup after bad load',
    () async {
      final current = sampleTrip('same', 'Local');
      final incoming = sampleTrip('same', 'Backup');
      final newTrip = sampleTrip('new', 'New trip');
      final store = FailingStore()
        ..value = AppData(trips: [current], language: 'en');
      final controller = AppController(store);
      addTearDown(controller.dispose);
      await controller.load();
      final outcome = await controller.importBackup(
        AppData(trips: [incoming, newTrip], language: 'zh'),
        replace: false,
      );
      expect(outcome.added, 1);
      expect(outcome.skipped, 1);
      expect(controller.trips.length, 2);
      expect(controller.tripById('same')!.title, 'Local');
      expect(controller.data.language, 'en');

      store.fail = true;
      await expectLater(
        controller.importBackup(
          AppData(trips: [incoming], language: 'zh'),
          replace: true,
        ),
        throwsStateError,
      );
      expect(controller.trips.length, 2);
      store.fail = false;
      store.corrupt = true;
      await controller.load();
      expect(controller.loadError, isNotNull);
      await controller.importBackup(
        AppData(trips: [incoming], language: 'zh'),
        replace: true,
      );
      expect(controller.loadError, isNull);
      expect(controller.trips.single.title, 'Backup');
      expect(controller.data.language, 'zh');
    },
  );
}

Trip sampleTrip(String id, String title) => Trip(
  id: id,
  title: title,
  baseCurrency: 'CNY',
  budgets: {for (final item in BudgetCategory.values) item: 10000},
  stage: TripStage.draft,
  createdAt: DateTime.utc(2026, 9, 1),
  expenses: const [],
);

class FailingStore implements TripStore {
  AppData value = const AppData();
  bool fail = false;
  bool corrupt = false;

  @override
  Future<AppData> load() async {
    if (corrupt) throw const FormatException('bad file');
    return value;
  }

  @override
  Future<void> save(AppData data) async {
    if (fail) throw StateError('disk failed');
    value = data;
  }
}
