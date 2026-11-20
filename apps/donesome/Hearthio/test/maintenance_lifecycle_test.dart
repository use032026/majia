import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hearthio/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingHistoryRepository extends CareRepository {
  _FailingHistoryRepository(super.preferences);

  @override
  Future<void> writeEncodedSnapshot(String snapshot) async {
    throw StateError('disk full');
  }
}

MaintenancePlan _plan({
  required String id,
  required String title,
  required int intervalDays,
  DateTime? lastCompletedAt,
  DateTime? dueDate,
}) => MaintenancePlan(
  id: id,
  title: title,
  intervalDays: intervalDays,
  lastCompletedAt: lastCompletedAt,
  dueDate: dueDate,
);

CareItem _item({
  required List<MaintenancePlan> plans,
  List<MaintenanceRecord> records = const [],
  DateTime? purchaseDate,
}) => CareItem(
  id: 'air-conditioner',
  name: '客厅空调',
  category: '家电',
  location: '客厅',
  brand: '',
  model: '',
  notes: '',
  photos: const [],
  plans: plans,
  records: records,
  purchaseDate: purchaseDate,
);

void main() {
  test('equal instants keep ID tie order across UTC and local civil dates', () {
    final instant = DateTime.utc(2026, 2, 28, 18);
    final records = [
      MaintenanceRecord(
        id: 'z',
        planId: 'filter',
        completedAt: instant.toLocal(),
        cost: 0,
        note: '',
      ),
      MaintenanceRecord(
        id: 'a',
        planId: 'filter',
        completedAt: instant,
        cost: 0,
        note: '',
      ),
    ];
    final plan = _plan(id: 'filter', title: 'Filter', intervalDays: 10);
    for (final order in [records, records.reversed.toList()]) {
      final result = recalculateMaintenancePlanFromRecords(
        _item(plans: [plan], records: order),
        'filter',
      );
      expect(result.plans.single.lastCompletedAt, DateTime(2026, 2, 28));
      expect(result.plans.single.dueDate, DateTime(2026, 3, 10));
    }
  });

  test('plan recalculation scans unsorted history without changing it', () {
    final plan = _plan(id: 'filter', title: 'Filter', intervalDays: 10);
    final records = [
      MaintenanceRecord(
        id: 'old',
        planId: 'filter',
        completedAt: DateTime(2026, 2, 1),
        cost: 0,
        note: '',
      ),
      MaintenanceRecord(
        id: 'other',
        planId: 'other',
        completedAt: DateTime(2027, 1, 1),
        cost: 0,
        note: '',
      ),
      MaintenanceRecord(
        id: 'z',
        planId: 'filter',
        completedAt: DateTime(2026, 2, 28, 23),
        cost: 0,
        note: '',
      ),
      MaintenanceRecord(
        id: 'a',
        planId: 'filter',
        completedAt: DateTime(2026, 2, 28, 23),
        cost: 0,
        note: '',
      ),
      MaintenanceRecord(
        id: 'middle',
        planId: 'filter',
        completedAt: DateTime(2026, 2, 20),
        cost: 0,
        note: '',
      ),
    ];
    final item = _item(plans: [plan], records: records);
    final original = [...records];
    final result = recalculateMaintenancePlanFromRecords(item, 'filter');
    expect(result.plans.single.lastCompletedAt, DateTime(2026, 2, 28));
    expect(result.plans.single.dueDate, DateTime(2026, 3, 10));
    expect(item.records, original);
    expect(
      identical(recalculateMaintenancePlanFromRecords(item, null), item),
      isTrue,
    );
    expect(
      identical(recalculateMaintenancePlanFromRecords(item, 'missing'), item),
      isTrue,
    );
  });

  test('lifecycle summary uses only traceable dates, records and plans', () {
    final item = _item(
      purchaseDate: DateTime(2025, 8, 19),
      plans: [
        _plan(
          id: 'filter',
          title: '清洗滤网',
          intervalDays: 90,
          dueDate: DateTime(2026, 8, 1),
        ),
        _plan(
          id: 'deep-clean',
          title: '深度清洗',
          intervalDays: 365,
          dueDate: DateTime(2027, 1, 1),
        ),
      ],
      records: [
        MaintenanceRecord(
          id: 'record-1',
          planId: 'filter',
          completedAt: DateTime(2026, 2, 1),
          cost: 20.5,
          note: '',
        ),
        MaintenanceRecord(
          id: 'record-2',
          planId: 'deep-clean',
          completedAt: DateTime(2026, 3, 1),
          cost: 79.5,
          note: '',
        ),
      ],
    );

    final summary = MaintenanceLifecycleSnapshot.fromItem(
      item,
      now: DateTime(2026, 8, 19),
    );

    expect(summary.usageDays, 365);
    expect(summary.completionCount, 2);
    expect(summary.totalCost, 100);
    expect(summary.overdueCount, 1);
    expect(summary.nextTask!.plan.id, 'filter');
  });

  test('timeline includes a user purchase origin and sorts all records', () {
    final item = _item(
      purchaseDate: DateTime(2025, 1, 1),
      plans: const [],
      records: [
        MaintenanceRecord(
          id: 'older',
          completedAt: DateTime(2026, 1, 2),
          cost: 0,
          note: '',
        ),
        MaintenanceRecord(
          id: 'newer',
          completedAt: DateTime(2026, 3, 2),
          cost: 0,
          note: '',
        ),
      ],
    );

    final timeline = maintenanceTimelineForItem(item);

    expect(timeline, hasLength(3));
    expect(timeline[0].record!.id, 'newer');
    expect(timeline[1].record!.id, 'older');
    expect(timeline[2].type, MaintenanceTimelineEntryType.purchase);
    expect(timeline[2].date, DateTime(2025, 1, 1));
  });

  test('recalculation uses the latest remaining record for one plan only', () {
    final filter = _plan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      lastCompletedAt: DateTime(2026, 6, 1),
      dueDate: DateTime(2026, 8, 30),
    );
    final deepClean = _plan(
      id: 'deep-clean',
      title: '深度清洗',
      intervalDays: 365,
      lastCompletedAt: DateTime(2026, 4, 1),
      dueDate: DateTime(2027, 4, 1),
    );
    final item = _item(
      plans: [filter, deepClean],
      records: [
        MaintenanceRecord(
          id: 'filter-old',
          planId: 'filter',
          completedAt: DateTime(2026, 3, 1),
          cost: 0,
          note: '',
        ),
        MaintenanceRecord(
          id: 'filter-latest',
          planId: 'filter',
          completedAt: DateTime(2026, 6, 1),
          cost: 0,
          note: '',
        ),
      ],
    );
    final withoutLatest = item.copyWith(records: [item.records.first]);

    final recalculated = recalculateMaintenancePlanFromRecords(
      withoutLatest,
      'filter',
    );

    final savedFilter = recalculated.plans.firstWhere(
      (plan) => plan.id == 'filter',
    );
    final savedDeepClean = recalculated.plans.firstWhere(
      (plan) => plan.id == 'deep-clean',
    );
    expect(savedFilter.lastCompletedAt, DateTime(2026, 3, 1));
    expect(savedFilter.dueDate, DateTime(2026, 5, 30));
    expect(savedDeepClean.lastCompletedAt, deepClean.lastCompletedAt);
    expect(savedDeepClean.dueDate, deepClean.dueDate);
  });

  test('deleting the only record restores its original planned due date', () {
    final plan = _plan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      lastCompletedAt: DateTime(2026, 6, 1),
      dueDate: DateTime(2026, 8, 30),
    );
    final record = MaintenanceRecord(
      id: 'only',
      planId: 'filter',
      completedAt: DateTime(2026, 6, 1),
      plannedDueDate: DateTime(2026, 5, 20),
      cost: 0,
      note: '',
    );

    final recalculated = recalculateMaintenancePlanFromRecords(
      _item(plans: [plan]),
      'filter',
      fallbackDueDate: record.plannedDueDate,
    );

    expect(recalculated.plans.single.lastCompletedAt, isNull);
    expect(recalculated.plans.single.dueDate, DateTime(2026, 5, 20));
  });

  test('history snapshots stop later plan edits from rewriting step facts', () {
    final originalPlan = MaintenancePlan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      checklist: const [
        MaintenanceStep(id: 'power', title: '关闭电源', sortOrder: 0),
        MaintenanceStep(id: 'wash', title: '清洗滤网', sortOrder: 1),
      ],
    );
    final frozen = freezeMaintenanceHistorySnapshots(
      _item(
        plans: [originalPlan],
        records: [
          MaintenanceRecord(
            id: 'record',
            planId: 'filter',
            completedAt: DateTime(2026, 6, 1),
            kind: '原任务标题',
            cost: 0,
            note: '',
            completedStepIds: const ['power'],
          ),
        ],
      ),
    );
    final edited = frozen.copyWith(
      plans: [
        originalPlan.copyWith(
          title: '新任务标题',
          checklist: const [
            MaintenanceStep(id: 'wash', title: '已改名步骤', sortOrder: 0),
          ],
        ),
      ],
    );

    final record = edited.records.single;
    expect(record.kind, '原任务标题');
    expect(record.stepSnapshots?.map((step) => step.title), ['关闭电源', '清洗滤网']);
    expect(record.stepSnapshots?.map((step) => step.completed), [true, false]);
  });

  test('deleting latest record persists fallback plan dates', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var notificationMutations = 0;
    final plan = _plan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      lastCompletedAt: DateTime(2026, 6, 1),
      dueDate: DateTime(2026, 8, 30),
    );
    final item = _item(
      plans: [plan],
      records: [
        MaintenanceRecord(
          id: 'latest',
          planId: 'filter',
          completedAt: DateTime(2026, 6, 1),
          cost: 60,
          note: '',
        ),
        MaintenanceRecord(
          id: 'older',
          planId: 'filter',
          completedAt: DateTime(2026, 3, 1),
          cost: 30,
          note: '',
        ),
      ],
    );
    final store = CareStore(
      repository: CareRepository(preferences),
      notificationScheduler: (_, __) async => notificationMutations++,
    )..items = [item];

    final saved = await store.deleteMaintenanceRecord(item.id, 'latest');

    expect(saved.records.map((record) => record.id), ['older']);
    expect(saved.plans.single.lastCompletedAt, DateTime(2026, 3, 1));
    expect(saved.plans.single.dueDate, DateTime(2026, 5, 30));
    expect(notificationMutations, 1);
    final persisted = CareDataEnvelope.decode(
      preferences.getString(CareRepository.storageKey)!,
    ).items.single;
    expect(persisted.records.single.id, 'older');
    expect(persisted.plans.single.dueDate, DateTime(2026, 5, 30));
  });

  test(
    'deleting the only record persists its original plan baseline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final plan = _plan(
        id: 'filter',
        title: '清洗滤网',
        intervalDays: 90,
        lastCompletedAt: DateTime(2026, 6, 1),
        dueDate: DateTime(2026, 8, 30),
      );
      final item = _item(
        plans: [plan],
        records: [
          MaintenanceRecord(
            id: 'only',
            planId: 'filter',
            completedAt: DateTime(2026, 6, 1),
            plannedDueDate: DateTime(2026, 5, 20),
            cost: 60,
            note: '',
          ),
        ],
      );
      final store = CareStore(
        repository: CareRepository(preferences),
        notificationScheduler: (_, __) async {},
      )..items = [item];

      final saved = await store.deleteMaintenanceRecord(item.id, 'only');

      expect(saved.records, isEmpty);
      expect(saved.plans.single.lastCompletedAt, isNull);
      expect(saved.plans.single.dueDate, DateTime(2026, 5, 20));
      final persisted = CareDataEnvelope.decode(
        preferences.getString(CareRepository.storageKey)!,
      ).items.single;
      expect(persisted.plans.single.dueDate, DateTime(2026, 5, 20));
    },
  );

  test('editing a linked record recalculates date and actual cost', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final plan = _plan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      lastCompletedAt: DateTime(2026, 6, 1),
      dueDate: DateTime(2026, 8, 30),
    );
    final record = MaintenanceRecord(
      id: 'record',
      planId: 'filter',
      completedAt: DateTime(2026, 6, 1),
      cost: 60,
      note: '旧备注',
    );
    final item = _item(plans: [plan], records: [record]);
    final store = CareStore(
      repository: CareRepository(preferences),
      notificationScheduler: (_, __) async {},
    )..items = [item];

    final saved = await store.updateMaintenanceRecord(
      item.id,
      record.copyWith(
        completedAt: DateTime(2026, 5, 1),
        cost: 45.5,
        note: '修正后',
      ),
    );

    expect(saved.records.single.completedAt, DateTime(2026, 5, 1));
    expect(saved.records.single.cost, 45.5);
    expect(saved.records.single.note, '修正后');
    expect(saved.plans.single.lastCompletedAt, DateTime(2026, 5, 1));
    expect(saved.plans.single.dueDate, DateTime(2026, 7, 30));
    expect(MaintenanceLifecycleSnapshot.fromItem(saved).totalCost, 45.5);
  });

  test('history write failure keeps records and plans unchanged', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final plan = _plan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      lastCompletedAt: DateTime(2026, 6, 1),
      dueDate: DateTime(2026, 8, 30),
    );
    final record = MaintenanceRecord(
      id: 'record',
      planId: 'filter',
      completedAt: DateTime(2026, 6, 1),
      cost: 60,
      note: '',
    );
    final item = _item(plans: [plan], records: [record]);
    final store = CareStore(
      repository: _FailingHistoryRepository(preferences),
      notificationScheduler: (_, __) async {},
    )..items = [item];

    await expectLater(
      store.deleteMaintenanceRecord(item.id, record.id),
      throwsA(isA<MaintenanceHistoryException>()),
    );

    expect(store.items.single.records.single.id, 'record');
    expect(
      store.items.single.plans.single.lastCompletedAt,
      DateTime(2026, 6, 1),
    );
    expect(preferences.getString(CareRepository.storageKey), isNull);
  });

  test('deleting a record retains a photo still referenced elsewhere', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final photo = File(
      '${Directory.systemTemp.path}/hearthio-shared-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await photo.writeAsBytes([1, 2, 3]);
    final item = _item(
      plans: const [],
      records: [
        MaintenanceRecord(
          id: 'first',
          completedAt: DateTime(2026, 3, 1),
          cost: 0,
          note: '',
          afterPhotos: [photo.path],
        ),
        MaintenanceRecord(
          id: 'second',
          completedAt: DateTime(2026, 2, 1),
          cost: 0,
          note: '',
          afterPhotos: [photo.path],
        ),
      ],
    );
    final store = CareStore(
      repository: CareRepository(preferences),
      notificationScheduler: (_, __) async {},
    )..items = [item];

    await store.deleteMaintenanceRecord(item.id, 'first');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(await photo.exists(), isTrue);
    await photo.delete();
  });
}
