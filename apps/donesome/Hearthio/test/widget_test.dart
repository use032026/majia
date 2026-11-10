import 'dart:convert';
import 'dart:async';

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearthio/app/locale_controller.dart';
import 'package:hearthio/feature_intro_page.dart';
import 'package:hearthio/l10n/app_localizations.dart';
import 'package:hearthio/l10n/catalog_l10n.dart';
import 'package:hearthio/main.dart';
import 'package:hearthio/privacy_policy_page.dart';
import 'package:hearthio/widgets/three_finger_long_press_region.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeExecutionController implements MaintenanceExecutionController {
  _FakeExecutionController({
    required this.task,
    this.notificationScheduled = false,
    this.completionError,
    this.completionGate,
    this.importResult,
    List<String> importedPaths = const [],
  }) : importedPaths = [...importedPaths];

  final MaintenanceTask task;
  final bool notificationScheduled;
  final Object? completionError;
  final Completer<void>? completionGate;
  final Completer<PhotoImportResult>? importResult;
  final List<String> importedPaths;
  final List<String> discardedPaths = [];
  MaintenanceCompletionDraft? lastDraft;
  int completeCalls = 0;

  @override
  Future<MaintenanceCompletionResult> completeMaintenance(
    MaintenanceCompletionDraft draft,
  ) async {
    completeCalls++;
    lastDraft = draft;
    if (completionGate != null) await completionGate!.future;
    if (completionError != null) throw completionError!;
    final completedPlan = task.plan.completedAt(draft.completedAt);
    final record = MaintenanceRecord(
      id: draft.recordId,
      planId: task.plan.id,
      completedAt: draft.completedAt,
      kind: task.plan.title,
      cost: draft.cost,
      materialName: draft.materialName,
      note: draft.note,
      completedStepIds: draft.completedStepIds,
      beforePhotos: draft.beforePhotos,
      afterPhotos: draft.afterPhotos,
    );
    final completedItem = task.item.copyWith(
      plans: [
        for (final plan in task.item.plans)
          if (plan.id == completedPlan.id) completedPlan else plan,
      ],
      records: [...task.item.records, record],
    );
    return MaintenanceCompletionResult(
      item: completedItem,
      plan: completedPlan,
      record: record,
      notificationScheduled: notificationScheduled,
    );
  }

  @override
  Future<void> discardImportedPhoto(String path) async {
    discardedPaths.add(path);
  }

  @override
  Future<PhotoImportResult> importPhoto(ImageSource source) async {
    final pending = importResult;
    if (pending != null) return pending.future;
    return importedPaths.isEmpty
        ? const PhotoImportResult.cancelled()
        : PhotoImportResult.success(importedPaths.removeAt(0));
  }
}

class _ReminderEnabledCareStore extends CareStore {
  @override
  Future<NotificationAccess> notificationAccess() async =>
      NotificationAccess.enabled;
}

MaintenanceTask _executionTask() {
  final today = maintenanceDateOnly(DateTime.now());
  final item = CareItem(
    id: 'purifier',
    name: '厨房净水器',
    category: '家电',
    location: '厨房',
    brand: '',
    model: '',
    notes: '',
    photos: const [],
    plans: [
      MaintenancePlan(
        id: 'filter',
        title: '更换滤芯',
        intervalDays: 180,
        reminderLeadDays: 3,
        dueDate: addMaintenanceDays(today, -2),
        checklist: const [
          MaintenanceStep(
            id: 'water-off',
            title: '关闭水源',
            description: '关闭进水阀，确保停止进水',
            sortOrder: 0,
          ),
          MaintenanceStep(
            id: 'flush',
            title: '冲洗',
            description: '打开水源，冲洗滤芯至出水清澈',
            sortOrder: 1,
          ),
        ],
      ),
    ],
  );
  final plan = item.plans.single;
  return MaintenanceTask(
    item: item,
    plan: plan,
    status: MaintenancePlanStatus.evaluate(plan),
  );
}

Future<List<TestGesture>> _startSettingsLongPress(WidgetTester tester) async {
  final region = tester.getRect(find.byType(ThreeFingerLongPressRegion));
  return [
    for (final fraction in [.2, .4, .6])
      await tester.startGesture(
        Offset(region.left + region.width * fraction, region.center.dy),
      ),
  ];
}

Future<void> _triggerSettingsLongPress(WidgetTester tester) async {
  final gestures = await _startSettingsLongPress(tester);
  await tester.pump(const Duration(seconds: 5));
  for (final gesture in gestures) {
    await gesture.up();
  }
  await tester.pump();
}

void main() {
  test('item archive round-trip preserves maintenance records and photos', () {
    final item = CareItem(
      id: 'item-1',
      name: 'Air purifier',
      category: '家电',
      location: 'Living room',
      brand: 'Test',
      model: 'A1',
      notes: 'Filter checked',
      photos: ['/local/photo.jpg'],
      lastCareDate: DateTime(2026, 1, 1),
      intervalDays: 90,
      records: [
        MaintenanceRecord(
          date: DateTime(2026, 1, 1),
          kind: 'Cleaning',
          cost: 20,
          note: 'Done',
        ),
      ],
    );
    final restored = CareItem.fromJson(item.toJson());
    expect(restored.nextCareDate, DateTime(2026, 4, 1));
    expect(restored.photos.single, '/local/photo.jpg');
    expect(restored.records.single.cost, 20);
    expect(restored.records.single.kind, 'Cleaning');
  });

  test('missing maintenance interval does not produce a reminder date', () {
    final item = CareItem(
      id: 'item-2',
      name: 'Kettle',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: [],
      lastCareDate: DateTime(2026, 1, 1),
    );
    expect(item.nextCareDate, isNull);
  });

  test('editing can clear optional asset values', () {
    final item = CareItem(
      id: 'item-3',
      name: 'Washer',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: [],
      purchasePrice: 3000,
      currentValue: 1800,
    );

    final cleared = item.copyWith(
      clearPurchasePrice: true,
      clearCurrentValue: true,
    );
    expect(cleared.purchasePrice, isNull);
    expect(cleared.currentValue, isNull);
  });

  test('notification status distinguishes first request from denial', () {
    expect(
      notificationAccessFrom(
        notificationsEnabled: false,
        permissionPrompted: false,
      ),
      NotificationAccess.notDetermined,
    );
    expect(
      notificationAccessFrom(
        notificationsEnabled: false,
        permissionPrompted: true,
      ),
      NotificationAccess.denied,
    );
    expect(
      notificationAccessFrom(
        notificationsEnabled: true,
        permissionPrompted: true,
      ),
      NotificationAccess.enabled,
    );
  });

  test('first load seeds one explicitly marked purifier example', () async {
    SharedPreferences.setMockInitialValues({
      AppLocaleController.preferenceKey: AppLanguageMode.simplifiedChinese.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));

    await store.load();

    final today = maintenanceDateOnly(DateTime.now());
    final plan = store.items.single.plans.single;
    expect(store.items, hasLength(1));
    expect(store.items.single.isSample, isTrue);
    expect(store.items.single.name, '示例 · 厨房净水器');
    expect(plan.id, 'sample-filter-plan');
    expect(plan.title, '更换滤芯');
    expect(plan.dueDate, today);
    expect(plan.checklist.map((step) => step.title), [
      '核对型号',
      '关闭水源',
      '更换',
      '冲洗',
    ]);
    expect(CareItem.fromJson(store.items.single.toJson()).isSample, isTrue);
  });

  testWidgets('first load generates every sample field in system English', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));

    await store.load();

    final sample = store.items.single;
    final plan = sample.plans.single;
    expect(sample.name, 'Sample · Kitchen water purifier');
    expect(sample.category, '滤芯与耗材');
    expect(sample.location, 'Kitchen');
    expect(
      sample.notes,
      'This is sample data. After replacing the filter, record the date, model, and actual cost.',
    );
    expect(plan.title, 'Replace filter');
    expect(plan.checklist.map((step) => step.title), [
      'Verify model',
      'Shut off water',
      'Replace',
      'Flush',
    ]);
    expect(plan.checklist.map((step) => step.description), [
      'Confirm the water purifier model and compatible filter',
      'Close the inlet valve and make sure the water has stopped',
      'Remove the old filter and install the new one',
      'Open the water supply and flush until the water runs clear',
    ]);
    expect(store.spaces.single.name, 'Kitchen');
    expect(store.spaces.single.type, '厨房');
  });

  test(
    'unused marked legacy sample upgrades without touching user items',
    () async {
      final oldSample = CareItem(
        id: 'sample-filter',
        name: '示例 · 厨房净水器',
        category: '滤芯与耗材',
        location: '厨房',
        brand: '',
        model: '',
        notes: '',
        photos: const [],
        lastCareDate: addMaintenanceDays(DateTime.now(), -150),
        intervalDays: 180,
        isSample: true,
      );
      final userItem = CareItem(
        id: 'user-item',
        name: '我的洗衣机',
        category: '家电',
        location: '',
        brand: '',
        model: '',
        notes: '',
        photos: const [],
      );
      SharedPreferences.setMockInitialValues({
        AppLocaleController.preferenceKey:
            AppLanguageMode.simplifiedChinese.name,
        CareRepository.storageKey: CareDataEnvelope(
          items: [oldSample, userItem],
        ).encode(),
      });
      final preferences = await SharedPreferences.getInstance();
      final store = CareStore(repository: CareRepository(preferences));

      await store.load();

      final sample = store.items.firstWhere((item) => item.isSample);
      expect(sample.plans.single.id, 'sample-filter-plan');
      expect(sample.plans.single.title, '更换滤芯');
      expect(store.items.map((item) => item.id), contains('user-item'));
    },
  );

  test('sample history is preserved instead of being silently reset', () async {
    final completedSample = CareItem(
      id: 'sample-filter',
      name: '示例 · 厨房净水器',
      category: '滤芯与耗材',
      location: '厨房',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      lastCareDate: DateTime(2026, 1, 1),
      intervalDays: 180,
      records: [
        MaintenanceRecord(
          id: 'kept-record',
          planId: 'legacy-plan-sample-filter',
          completedAt: DateTime(2026, 1, 1),
          cost: 20,
          note: '',
        ),
      ],
      isSample: true,
    );
    SharedPreferences.setMockInitialValues({
      CareRepository.storageKey: CareDataEnvelope(
        items: [completedSample],
      ).encode(),
    });
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));

    await store.load();

    expect(store.items.single.records.single.id, 'kept-record');
    expect(store.items.single.plans.single.id, 'legacy-plan-sample-filter');
  });

  test('legacy two-example data migrates to one marked purifier', () async {
    Map<String, Object> item(String id, String name) => {
      'id': id,
      'name': name,
      'category': '家电',
      'location': '',
      'brand': '',
      'model': '',
      'notes': '',
      'photos': <String>[],
    };
    SharedPreferences.setMockInitialValues({
      'care_items': jsonEncode([
        item('sample-filter', '厨房净水器'),
        item('sample-ac', '客厅空调'),
        item('user-item', '我的洗衣机'),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));

    await store.load();

    expect(store.items.where((entry) => entry.isSample), hasLength(1));
    expect(store.items.map((entry) => entry.id), isNot(contains('sample-ac')));
    expect(store.items.map((entry) => entry.id), contains('user-item'));
  });

  test('resetting example data preserves user-created items', () async {
    SharedPreferences.setMockInitialValues({
      AppLocaleController.preferenceKey: AppLanguageMode.simplifiedChinese.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));
    await store.load();
    store.items.add(
      CareItem(
        id: 'user-item',
        name: '我的洗衣机',
        category: '家电',
        location: '',
        brand: '',
        model: '',
        notes: '',
        photos: [],
      ),
    );

    store.updateLocalizations(lookupAppLocalizations(const Locale('en')));
    await store.resetExampleData();

    final sample = store.items.firstWhere((item) => item.isSample);
    expect(sample.name, 'Sample · Kitchen water purifier');
    expect(sample.category, '滤芯与耗材');
    expect(
      lookupAppLocalizations(
        const Locale('en'),
      ).itemCategoryLabel(sample.category),
      'Filters & consumables',
    );
    expect(sample.location, 'Kitchen');
    expect(sample.plans.single.title, 'Replace filter');
    expect(sample.plans.single.checklist.first.title, 'Verify model');

    await store.deleteExampleData();

    expect(store.items.map((item) => item.id), contains('user-item'));
    expect(store.items.where((item) => item.isSample), isEmpty);
  });

  testWidgets(
    'built-in sample category and default space follow the current locale',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AppLocaleController.preferenceKey: AppLanguageMode.english.name,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = CareStore(repository: CareRepository(preferences));
      await store.load();
      final sample = store.items.single;

      expect(sample.name, 'Sample · Kitchen water purifier');
      expect(store.spaces.single.name, 'Kitchen');

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: EditorPage(store: store, item: sample),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sample · Kitchen water purifier'), findsOneWidget);
      expect(find.byKey(const Key('edit-item-category-value')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('edit-item-category-value')))
            .data,
        '滤芯与耗材',
      );
      expect(find.text('厨房'), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit-item-category-field')));
      await tester.pumpAndSettle();

      expect(find.text('Filters & consumables'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('edit-item-category-picker')),
          matching: find.text('滤芯与耗材'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'reviewer demo completes the sample and opens its lifecycle without photos',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AppLocaleController.preferenceKey:
            AppLanguageMode.simplifiedChinese.name,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = CareStore(
        repository: CareRepository(preferences),
        notificationScheduler: (_, __) async {},
      );
      await store.load();
      await tester.binding.setSurfaceSize(const Size(430, 1000));

      await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
      await tester.pumpAndSettle();

      const taskId = 'sample-filter:sample-filter-plan';
      final start = find.byKey(
        const ValueKey('start-maintenance-task-$taskId'),
      );
      await tester.scrollUntilVisible(
        start,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('示例 · 厨房净水器'), findsOneWidget);
      expect(find.text('更换滤芯'), findsOneWidget);
      await tester.tap(start);
      await tester.pumpAndSettle();

      for (var index = 0; index < 4; index++) {
        final step = find.byKey(
          ValueKey('execution-step-sample-filter-plan-step-$index'),
        );
        await tester.scrollUntilVisible(
          step,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(step);
      }
      await tester.tap(find.byKey(const Key('execution-record-cost')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('execution-cost')), '129');
      await tester.tap(find.byKey(const Key('record-field-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('execution-record-material')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('execution-material')),
        'PP 棉滤芯 A1',
      );
      await tester.tap(find.byKey(const Key('record-field-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complete-maintenance')));
      await tester.pumpAndSettle();

      expect(find.text('本次保养已归档'), findsOneWidget);
      expect(find.text('¥129'), findsOneWidget);
      expect(find.text('查看生命周期'), findsOneWidget);
      await tester.tap(find.byKey(const Key('finish-maintenance-result')));
      await tester.pumpAndSettle();

      final saved = store.items.single;
      final record = saved.records.single;
      expect(record.cost, 129);
      expect(record.materialName, 'PP 棉滤芯 A1');
      expect(record.completedStepIds, hasLength(4));
      expect(
        saved.plans.single.dueDate,
        addMaintenanceDays(DateTime.now(), 180),
      );
      expect(
        find.byKey(const Key('maintenance-lifecycle-overview')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('maintenance-record-${record.id}')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('步骤：已完成 4 / 4'), findsOneWidget);
      expect(find.text('PP 棉滤芯 A1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('lifecycle renders frozen task and step facts after plan edits', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final record = MaintenanceRecord(
      id: 'record',
      planId: 'filter',
      completedAt: DateTime(2026, 8, 1),
      kind: '原任务标题',
      cost: 0,
      note: '',
      stepSnapshots: const [
        MaintenanceStepSnapshot(
          id: 'power',
          title: '原步骤标题',
          sortOrder: 0,
          completed: true,
        ),
      ],
    );
    final item = CareItem(
      id: 'item',
      name: '空调',
      category: '家电',
      location: '客厅',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [
        MaintenancePlan(
          id: 'filter',
          title: '新任务标题',
          intervalDays: 90,
          checklist: const [
            MaintenanceStep(id: 'power', title: '新步骤标题', sortOrder: 0),
          ],
        ),
      ],
      records: [record],
    );
    final store = CareStore(
      repository: CareRepository(preferences),
      notificationScheduler: (_, __) async {},
    )..items = [item];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MaintenanceLifecycleTimeline(item: item, controller: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('原任务标题'), findsOneWidget);
    expect(find.text('原步骤标题'), findsOneWidget);
    expect(find.text('新任务标题'), findsNothing);
    expect(find.text('新步骤标题'), findsNothing);
  });

  testWidgets('primary pages and the add-item flow render without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));
    await store.load();
    await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('LAURUS'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-add-item')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('物品档案'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inventory-add-item')));
    await tester.pumpAndSettle();
    expect(find.text('选择物品'), findsWidgets);
    expect(find.text('常用物品'), findsOneWidget);
    expect(find.text('全部分类'), findsOneWidget);

    await tester.drag(
      find.byKey(const PageStorageKey('item-selection-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('item-category-厨房用品')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item-category-厨房用品')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('catalog-item-厨房用品-炒锅')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-item-厨房用品-炒锅')));
    await tester.pumpAndSettle();
    expect(find.text('补充信息'), findsWidgets);
    expect(find.text('备注或自定义名称'), findsOneWidget);

    await tester.drag(
      find.byKey(const PageStorageKey('item-supplement-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-advanced-item-details')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byIcon(Icons.add_a_photo_outlined),
      280,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('item-supplement-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supplement rows align their trailing chevrons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: EditorPage(store: CareStore())));

    await tester.tap(find.byKey(const ValueKey('common-item-冰箱')));
    await tester.pumpAndSettle();

    final spaceChevron = find.descendant(
      of: find.byKey(const Key('item-space-selector')),
      matching: find.byType(Icon),
    );
    final brandChevron = find.descendant(
      of: find.byKey(const Key('toggle-brand-model')),
      matching: find.byType(Icon),
    );
    expect(spaceChevron, findsOneWidget);
    expect(brandChevron, findsOneWidget);
    expect(
      tester.getTopRight(spaceChevron).dx,
      closeTo(tester.getTopRight(brandChevron).dx, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrollable pages keep the bottom safe area inside their scroll padding',
    (tester) async {
      final task = _executionTask();
      final controller = _FakeExecutionController(task: task);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
            child: child!,
          ),
          home: MaintenanceExecutionPage(controller: controller, task: task),
        ),
      );

      final executionScroll = find.byKey(
        const PageStorageKey('maintenance-execution-scroll'),
      );
      final list = tester.widget<ListView>(executionScroll);
      expect(list.padding, const EdgeInsets.fromLTRB(20, 14, 20, 74));
      expect(
        find.ancestor(of: executionScroll, matching: find.byType(SafeArea)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'redesigned execution timeline advances and fits an iPhone viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      final plan = maintenanceTemplates
          .firstWhere((template) => template.id == 'water-purifier-filter')
          .createPlan(
            planId: 'filter',
            referenceDate: addMaintenanceDays(DateTime.now(), -180),
          );
      final item = CareItem(
        id: 'purifier',
        name: '厨房净水器',
        category: '滤芯与耗材',
        location: '厨房',
        brand: '',
        model: '',
        notes: '',
        photos: const [],
        plans: [plan],
      );
      final task = MaintenanceTask(
        item: item,
        plan: plan,
        status: MaintenancePlanStatus.evaluate(plan),
      );
      final controller = _FakeExecutionController(task: task);

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceExecutionPage(controller: controller, task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('执行步骤'), findsOneWidget);
      expect(find.text('请确认净水器型号与适配滤芯'), findsOneWidget);
      expect(find.text('关闭进水阀，确保停止进水'), findsOneWidget);
      expect(find.text('保养前留照（可选）'), findsOneWidget);
      final stepIndicator = find.descendant(
        of: find.byKey(const ValueKey('execution-step-filter-step-0')),
        matching: find.byType(AnimatedContainer),
      );
      final backControl = find.descendant(
        of: find.byType(AppBackButton),
        matching: find.byType(IconButton),
      );
      expect(
        tester.getSize(stepIndicator),
        const Size.square(AppBackButton.dimension),
      );
      expect(tester.getSize(stepIndicator), tester.getSize(backControl));
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('execution-before-photo-entry')),
            )
            .onTap,
        isNotNull,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('execution-after-photo-entry')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('本次记录（可选）'), findsOneWidget);
      expect(find.text('保养后留照（可选）'), findsOneWidget);
      expect(find.byKey(const Key('execution-record-date')), findsOneWidget);
      expect(find.byKey(const Key('execution-record-cost')), findsOneWidget);
      expect(
        find.byKey(const Key('execution-record-material')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('execution-record-note')), findsOneWidget);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('execution-after-photo-entry')),
            )
            .onTap,
        isNull,
      );
      expect(find.text('完成全部步骤后可添加保养后照片'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('complete-maintenance')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('execution-record-date')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-date-picker-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('app-date-picker-cancel')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('execution-step-filter-step-0')),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'步骤 1.*当前步骤')), findsOneWidget);

      for (var index = 0; index < plan.checklist.length; index++) {
        final step = find.byKey(ValueKey('execution-step-filter-step-$index'));
        await tester.scrollUntilVisible(
          step,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(step);
        await tester.pump();
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(index + 1));
        if (index + 1 < plan.checklist.length) {
          expect(
            find.bySemanticsLabel(RegExp('步骤 ${index + 2}.*当前步骤')),
            findsOneWidget,
          );
        }
      }

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('complete-maintenance')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('execution-after-photo-entry')),
            )
            .onTap,
        isNotNull,
      );
      expect(find.text('步骤已完成，记录最终状态以便对比'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('English execution steps fit an iPhone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final plan = maintenanceTemplates
        .firstWhere((template) => template.id == 'water-purifier-filter')
        .createPlan(
          planId: 'filter',
          referenceDate: addMaintenanceDays(DateTime.now(), -180),
        );
    final item = CareItem(
      id: 'purifier',
      name: 'Kitchen water purifier',
      category: '滤芯与耗材',
      location: 'Kitchen',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [plan],
    );
    final task = MaintenanceTask(
      item: item,
      plan: plan,
      status: MaintenancePlanStatus.evaluate(plan),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MaintenanceExecutionPage(
          controller: _FakeExecutionController(task: task),
          task: task,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final step in plan.checklist) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('execution-step-${step.id}')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(
      find.text('Open the water supply and flush until the water runs clear'),
      findsOneWidget,
    );
  });

  testWidgets('fixed action area includes the system bottom inset', (
    tester,
  ) async {
    final store = CareStore();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
          child: child!,
        ),
        home: EditorPage(store: store),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('common-item-冰箱')));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    final actionArea = scaffold.bottomNavigationBar! as Padding;
    expect(actionArea.padding, const EdgeInsets.fromLTRB(20, 10, 20, 46));
    expect(find.byKey(const Key('full-item-actions')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('save-care-item')),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );

    await tester.drag(
      find.byKey(const PageStorageKey('item-supplement-scroll')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('toggle-advanced-item-details')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-advanced-item-details')));
    await tester.pumpAndSettle();

    final expandedScaffold = tester.widget<Scaffold>(
      find.byType(Scaffold).last,
    );
    final compactActionArea = expandedScaffold.bottomNavigationBar! as Padding;
    expect(compactActionArea.padding, const EdgeInsets.fromLTRB(20, 6, 20, 42));
    expect(find.byKey(const Key('compact-item-actions')), findsOneWidget);
    expect(find.byKey(const Key('save-care-item')), findsOneWidget);
    expect(find.byKey(const Key('save-care-item-later')), findsOneWidget);
  });

  testWidgets('home content does not reserve the bottom inset twice', (
    tester,
  ) async {
    final store = CareStore()..loaded = true;
    await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
    await tester.pumpAndSettle();

    final homeSafeArea = tester.widget<SafeArea>(
      find
          .ancestor(of: find.byType(Dashboard), matching: find.byType(SafeArea))
          .first,
    );
    expect(homeSafeArea.bottom, isFalse);
  });

  testWidgets('item search auto-fills category and keeps naming optional', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));
    await tester.pumpWidget(MaterialApp(home: EditorPage(store: store)));

    await tester.enterText(find.byKey(const Key('item-search')), '体温计');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-item-医疗保健-体温计')));
    await tester.pumpAndSettle();

    expect(find.text('补充信息'), findsWidgets);
    expect(find.text('体温计'), findsOneWidget);
    expect(find.text('医疗保健'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('custom-item-name')), '儿童房体温计');
    await tester.enterText(find.byKey(const Key('item-location')), '儿童房');
    await tester.tap(find.byKey(const Key('save-care-item')));
    await tester.pumpAndSettle();

    expect(store.items.single.name, '儿童房体温计');
    expect(store.items.single.category, '医疗保健');
    expect(store.items.single.location, '儿童房');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a new item returns from the two-step editor route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-item-editor'),
              onPressed: () {
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => EditorPage(store: store)),
                  ),
                );
              },
              child: const Text('打开新增物品'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-item-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('common-item-冰箱')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-care-item')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-item-editor')), findsOneWidget);
    expect(find.text('补充信息'), findsNothing);
    expect(store.items.single.name, '冰箱');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing item category uses an iOS bottom picker', (
    tester,
  ) async {
    final item = CareItem(
      id: 'washer',
      name: '洗衣机',
      category: '家用电器',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(store: CareStore(), item: item),
      ),
    );
    await tester.tap(find.byKey(const Key('edit-item-category-field')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-item-category-sheet')), findsOneWidget);
    expect(find.byKey(const Key('edit-item-category-picker')), findsOneWidget);
    expect(find.text('选择类别'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);

    final picker = tester.widget<CupertinoPicker>(
      find.byKey(const Key('edit-item-category-picker')),
    );
    picker.onSelectedItemChanged!(0);
    await tester.tap(find.byKey(const Key('confirm-edit-item-category')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-item-category-sheet')), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('edit-item-category-value')))
          .data,
      '家具',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy category aliases do not create duplicate picker rows', (
    tester,
  ) async {
    const aliases = <String, String>{'家具与家居': '家具', '家电': '家用电器', '其他': '其他物品'};

    for (final entry in aliases.entries) {
      final item = CareItem(
        id: entry.key,
        name: '旧物品',
        category: entry.key,
        location: '',
        brand: '',
        model: '',
        notes: '',
        photos: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EditorPage(
            key: ValueKey(entry.key),
            store: CareStore(),
            item: item,
          ),
        ),
      );

      expect(
        tester
            .widget<Text>(find.byKey(const Key('edit-item-category-value')))
            .data,
        entry.value,
      );

      await tester.tap(find.byKey(const Key('edit-item-category-field')));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoPicker>(
        find.byKey(const Key('edit-item-category-picker')),
      );
      final delegate = picker.childDelegate as ListWheelChildListDelegate;
      final labels = [
        for (final child in delegate.children)
          (((child as Center).child as Text).data!),
      ];

      expect(labels.where((label) => label == entry.value), hasLength(1));
      expect(labels, isNot(contains(entry.key)));
      expect(labels.toSet(), hasLength(labels.length));

      await tester.tap(find.byKey(const Key('cancel-edit-item-category')));
      await tester.pumpAndSettle();
    }

    const customCategory = '收藏品';
    final customItem = CareItem(
      id: 'custom',
      name: '收藏',
      category: customCategory,
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          key: const ValueKey(customCategory),
          store: CareStore(),
          item: customItem,
        ),
      ),
    );

    expect(
      tester
          .widget<Text>(find.byKey(const Key('edit-item-category-value')))
          .data,
      customCategory,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('first restore explains the file-selection flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(store: CareStore())),
    );
    await tester.ensureVisible(find.text('恢复备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复备份'));
    await tester.pumpAndSettle();

    expect(find.text('如何恢复完整备份？'), findsOneWidget);
    expect(find.text('选择备份文件'), findsOneWidget);
    expect(find.textContaining('LAURUS-backup.zip'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings replaces sample-data management with the feature guide',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsPage(store: CareStore())),
      );

      expect(find.text('管理示例数据'), findsNothing);
      expect(find.text('功能介绍'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-feature-intro')));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureIntroPage), findsOneWidget);
      expect(find.text('建立物品档案'), findsOneWidget);
      expect(find.text('建立保养计划'), findsOneWidget);
      expect(find.text('完成保养并留档'), findsOneWidget);
      expect(find.text('回看记录与成本'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('feature-intro-list')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(find.text('先从示例看看'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings recognizes a five-second three-finger long press', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('stmini_flutter/methods');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: SettingsPage(store: CareStore()),
      ),
    );

    final gestures = await _startSettingsLongPress(tester);

    await tester.pump(const Duration(milliseconds: 4999));
    expect(calls, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(calls.map((call) => call.method), ['initialize', 'openMini']);

    await tester.pump(const Duration(seconds: 5));
    expect(calls.map((call) => call.method), ['initialize', 'openMini']);

    for (final gesture in gestures) {
      await gesture.up();
    }
    await tester.pump();
    expect(calls.map((call) => call.method), ['initialize', 'openMini']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings opens the KIFX Mini Program with its release link', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('stmini_flutter/methods');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: SettingsPage(store: CareStore()),
      ),
    );
    await _triggerSettingsLongPress(tester);

    expect(calls.map((call) => call.method), ['initialize', 'openMini']);
    expect(calls.first.arguments, {
      'bridgeContext': {'packageName': 'com.Hearthio.lite'},
    });
    final openArguments = calls.last.arguments as Map<Object?, Object?>;
    final link = Uri.parse(openArguments['link']! as String);
    expect(link.scheme, 'mini');
    expect(link.host, 'kifx');
    expect(
      link.queryParameters,
      containsPair(
        'downloadUrl',
        'https://site.761242.com/maple/v1/static/'
            '20260908_018ee521a82c8c4edb72c8d9f2a2b18157.zip',
      ),
    );
    expect(link.queryParameters['currentVersion'], '2.0.0');
    expect(link.queryParameters['minSupportVersion'], '2.0.0');
    expect(link.queryParameters['miniName'], 'KIFX');
    expect(link.queryParameters['miniNameEn'], 'KIFX');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('kifx_mini_auto_open'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app automatically opens KIFX after the user enables it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_seen': true,
      'kifx_mini_auto_open': true,
    });
    const channel = MethodChannel('stmini_flutter/methods');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const AppEntry(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(calls.map((call) => call.method), ['initialize', 'openMini']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed KIFX launch does not enable automatic opening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('stmini_flutter/methods');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'openMini') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: SettingsPage(store: CareStore()),
      ),
    );
    await _triggerSettingsLongPress(tester);

    expect(calls, ['initialize', 'openMini']);
    expect(find.text('KIFX 小程序暂时无法打开，请稍后重试'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('kifx_mini_auto_open'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reminder tools use the full bottom-sheet content width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(store: _ReminderEnabledCareStore())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('提醒与测试'));
    await tester.pumpAndSettle();

    final testButton = find.byKey(const Key('reminder-tools-test'));
    final settingsButton = find.byKey(const Key('reminder-tools-settings'));
    expect(testButton, findsOneWidget);
    expect(settingsButton, findsOneWidget);
    expect(tester.getSize(testButton).width, closeTo(362, 1));
    expect(
      tester.getSize(settingsButton).width,
      closeTo(tester.getSize(testButton).width, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy page has a local fallback before URL configuration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyPolicyPage(remoteUrl: '')),
    );

    expect(find.text('隐私政策页面正在准备中'), findsOneWidget);
    expect(find.textContaining('物品信息、照片、维护记录和计划默认保存在本机'), findsOneWidget);
  });

  test('privacy policy URL follows the effective app locale', () {
    expect(
      privacyPolicyUrlForLocale(const Locale('zh')),
      'https://hearthio.app/privacy.html?lang=zh',
    );
    expect(
      privacyPolicyUrlForLocale(const Locale('en')),
      'https://hearthio.app/privacy.html?lang=en',
    );
    expect(
      privacyPolicyUrlForLocale(const Locale('fr')),
      'https://hearthio.app/privacy.html?lang=en',
    );
  });

  testWidgets(
    'opening home does not mark notification permission as prompted',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final store = CareStore()..loaded = true;
      await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notification_permission_prompted'), isNull);
    },
  );

  testWidgets('first launch presents all three onboarding steps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      HearthioApp(
        localeController: AppLocaleController(
          initialMode: AppLanguageMode.simplifiedChinese,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('先给家里的物品建档'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('拍下凭证，留住细节'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('日历提醒，按时照料'), findsOneWidget);
    expect(find.text('开始整理'), findsOneWidget);
  });

  testWidgets('purifier template can be added and remains fully editable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));
    await tester.pumpWidget(MaterialApp(home: EditorPage(store: store)));
    await tester.ensureVisible(find.byKey(const ValueKey('common-item-净水器')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('common-item-净水器')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom-item-name')), '厨房净水器');

    await tester.drag(
      find.byKey(const PageStorageKey('item-supplement-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-advanced-item-details')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('add-maintenance-plan')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('add-maintenance-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-maintenance-plan')));
    await tester.pumpAndSettle();
    expect(find.text('选择保养模板'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('template-water-purifier-filter')),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑保养计划'), findsOneWidget);
    expect(find.text('更换滤芯'), findsOneWidget);
    expect(find.text('核对型号'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('maintenance-plan-title')),
      '更换复合滤芯',
    );
    await tester.enterText(
      find.byKey(const Key('maintenance-plan-interval')),
      '150',
    );
    await tester.enterText(
      find.byKey(const Key('maintenance-plan-reminder-lead')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('maintenance-step-0')),
      '确认滤芯型号',
    );
    await tester.ensureVisible(
      find.byKey(const Key('maintenance-plan-enabled')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('maintenance-plan-enabled')));
    await tester.tap(find.byKey(const Key('save-maintenance-plan')));
    await tester.pumpAndSettle();

    expect(find.text('更换复合滤芯'), findsOneWidget);
    expect(find.textContaining('每 150 天'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-care-item')));
    await tester.pumpAndSettle();
    expect(store.items.single.plans.single.title, '更换复合滤芯');
    expect(store.items.single.plans.single.intervalDays, 150);
    expect(store.items.single.plans.single.reminderLeadDays, 5);
    expect(store.items.single.plans.single.checklist.first.title, '确认滤芯型号');
    expect(store.items.single.plans.single.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan without history is deleted instead of archived', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final plan = MaintenancePlan(
      id: 'filter',
      title: '更换滤芯',
      intervalDays: 180,
      dueDate: DateTime(2026, 9, 1),
    );
    final item = CareItem(
      id: 'purifier',
      name: '净水器',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [plan],
    );
    final preferences = await SharedPreferences.getInstance();
    final store = CareStore(repository: CareRepository(preferences));
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(store: store, item: item),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('remove-plan-filter')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('remove-plan-filter')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('remove-plan-filter')));
    await tester.pumpAndSettle();
    expect(find.text('删除这个计划？'), findsOneWidget);
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.text('还没有保养计划'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-care-item')));
    await tester.pumpAndSettle();
    expect(store.items.single.plans, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked plan is archived while its history stays intact', (
    tester,
  ) async {
    final plan = MaintenancePlan(
      id: 'filter',
      title: '更换滤芯',
      intervalDays: 180,
      dueDate: DateTime(2026, 9, 1),
    );
    final item = CareItem(
      id: 'purifier',
      name: '净水器',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [plan],
      records: [
        MaintenanceRecord(
          id: 'record-1',
          planId: 'filter',
          completedAt: DateTime(2026, 3, 1),
          cost: 0,
          note: '',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(store: CareStore(), item: item),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('remove-plan-filter')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('remove-plan-filter')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('remove-plan-filter')));
    await tester.pumpAndSettle();
    expect(find.text('归档这个计划？'), findsOneWidget);
    await tester.tap(find.text('确认归档'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const PageStorageKey<String>('archived-maintenance-plans')),
      findsOneWidget,
    );
    expect(find.text('已归档计划（1）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('item detail displays multiple plans without overwriting', (
    tester,
  ) async {
    final item = CareItem(
      id: 'air-conditioner',
      name: '空调',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [
        MaintenancePlan(
          id: 'filter',
          title: '清洗滤网',
          intervalDays: 90,
          dueDate: DateTime(2026, 9, 1),
        ),
        MaintenancePlan(
          id: 'deep-clean',
          title: '深度清洗',
          intervalDays: 365,
          dueDate: DateTime(2027, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(store: CareStore(), item: item),
      ),
    );

    expect(find.byKey(const Key('detail-maintenance-plans')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-plan-filter')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-plan-deep-clean')),
      findsOneWidget,
    );
    expect(find.text('清洗滤网'), findsWidgets);
    expect(find.text('深度清洗'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('item detail wraps long notes instead of truncating them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longNote = '这是用于验证详情卡片自适应换行的长备注，完整内容不应被省略，并且需要始终保留在卡片边界以内。';
    final item = CareItem(
      id: 'long-note-item',
      name: '厨房净水器',
      category: '滤芯与耗材',
      location: '厨房',
      brand: '',
      model: '',
      notes: longNote,
      photos: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(store: CareStore(), item: item),
      ),
    );
    await tester.scrollUntilVisible(
      find.text(longNote),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.text(longNote)).height, greaterThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard highlights the most urgent maintenance task', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    final today = maintenanceDateOnly(DateTime.now());
    final item = CareItem(
      id: 'device',
      name: '设备',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [
        MaintenancePlan(
          id: 'planned',
          title: '已计划任务',
          intervalDays: 30,
          reminderLeadDays: 3,
          dueDate: today.add(const Duration(days: 30)),
        ),
        MaintenancePlan(
          id: 'soon',
          title: '即将到期任务',
          intervalDays: 30,
          reminderLeadDays: 3,
          dueDate: today.add(const Duration(days: 2)),
        ),
        MaintenancePlan(
          id: 'today',
          title: '今日任务',
          intervalDays: 30,
          dueDate: today,
        ),
        MaintenancePlan(
          id: 'overdue',
          title: '逾期任务',
          intervalDays: 30,
          dueDate: today.subtract(const Duration(days: 1)),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: Dashboard(store: CareStore()..items = [item])),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('maintenance-task-device-overdue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('maintenance-task-device-today')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('maintenance-task-device-soon')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('maintenance-task-device-planned')),
      findsNothing,
    );
    expect(find.text('已逾期 1 天'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('dashboard header add action opens the item flow', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Dashboard(store: CareStore())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard-add-item')));
    await tester.pumpAndSettle();

    expect(find.text('选择物品'), findsWidgets);
    expect(find.text('常用物品'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard schedule action selects the schedule tab', (
    tester,
  ) async {
    final store = CareStore()..loaded = true;
    await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard-open-schedule')));
    await tester.pumpAndSettle();

    expect(find.text('保养日程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redesigned dashboard is stable on an iPhone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final item = CareItem(
      id: 'sample-purifier',
      name: '示例 · 厨房净水器',
      category: '滤芯与耗材',
      location: '厨房',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [
        MaintenancePlan(
          id: 'sample-filter-plan',
          title: '更换滤芯',
          intervalDays: 180,
          dueDate: DateTime(2027, 2, 17),
        ),
      ],
      currentValue: 0,
      isSample: true,
    );
    final store = CareStore()
      ..loaded = true
      ..items = [item];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Dashboard(store: store, now: DateTime(2026, 8, 22)),
          ),
          bottomNavigationBar: AppBottomDock(selected: 0, onSelect: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有到期任务'), findsOneWidget);
    expect(find.text('179 天后'), findsOneWidget);
    expect(find.text('示例 · 厨房净水器'), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-household-overview')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('dashboard-household-overview')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('empty task center opens the first-plan item flow', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Dashboard(store: CareStore())));
    await tester.pumpAndSettle();

    expect(find.text('从第一个计划开始'), findsOneWidget);
    expect(find.text('添加物品并设置保养周期，到期前会提醒你。'), findsOneWidget);
    final emptyState = find.byKey(
      const Key('dashboard-empty-maintenance-state'),
    );
    expect(emptyState, findsOneWidget);
    expect(tester.getSize(emptyState).width, greaterThan(700));
    await tester.ensureVisible(
      find.byKey(const Key('create-first-maintenance-plan')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-first-maintenance-plan')));
    await tester.pumpAndSettle();

    expect(find.text('选择物品'), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('common-item-净水器')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('common-item-净水器')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('item-supplement-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-advanced-item-details')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-maintenance-plan')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('add-maintenance-plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'snoozing preserves original overdue date and creates no record',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final today = maintenanceDateOnly(DateTime.now());
      final dueDate = today.subtract(const Duration(days: 2));
      final item = CareItem(
        id: 'purifier',
        name: '净水器',
        category: '家电',
        location: '',
        brand: '',
        model: '',
        notes: '',
        photos: const [],
        plans: [
          MaintenancePlan(
            id: 'filter',
            title: '更换滤芯',
            intervalDays: 180,
            dueDate: dueDate,
          ),
        ],
      );
      final preferences = await SharedPreferences.getInstance();
      final store = CareStore(repository: CareRepository(preferences))
        ..items = [item];
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: store,
            builder: (_, __) => Dashboard(store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('defer-maintenance-task-purifier:filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('defer-maintenance-task-purifier:filter')),
      );
      await tester.pumpAndSettle();
      expect(find.text('稍后提醒'), findsWidgets);
      expect(find.textContaining('原到期日'), findsWidgets);
      await tester.tap(find.byKey(const Key('defer-until-tomorrow')));
      await tester.pumpAndSettle();

      final saved = store.items.single;
      expect(saved.plans.single.dueDate, dueDate);
      expect(
        saved.plans.single.deferredUntil,
        today.add(const Duration(days: 1)),
      );
      expect(saved.records, isEmpty);
      expect(find.text('已稍后提醒'), findsOneWidget);
      expect(find.textContaining('原状态 已逾期'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('start-maintenance-task-purifier:filter')),
      );
      await tester.tap(
        find.byKey(const ValueKey('start-maintenance-task-purifier:filter')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaintenanceExecutionPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inventory archive exposes add, search, status filters, and sorting',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var addCalls = 0;
      final store = CareStore()
        ..items = [
          CareItem(
            id: 'washer',
            name: '洗衣机',
            category: '家用电器',
            location: '',
            brand: '',
            model: '',
            notes: '',
            photos: const [],
          ),
          CareItem(
            id: '003',
            name: '003',
            category: '家用电器',
            location: '卫生间',
            brand: '',
            model: '',
            notes: '',
            photos: const [],
            plans: [
              MaintenancePlan(
                id: 'washer-care',
                title: '清洁',
                intervalDays: 90,
                dueDate: DateTime(2026, 11, 20),
              ),
            ],
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryPage(store: store, onAdd: () => addCalls++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('管理物品与保养计划'), findsOneWidget);
      expect(find.text('全部 2'), findsOneWidget);
      expect(find.text('已计划 1'), findsOneWidget);
      expect(find.text('待设置 1'), findsOneWidget);
      expect(find.text('设置计划'), findsOneWidget);
      expect(find.text('下次 2026年11月20日'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('inventory-item-washer')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('inventory-item-003')))
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('inventory-filter-planned')));
      await tester.pumpAndSettle();
      expect(find.text('已计划物品'), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-item-003')), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-item-washer')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('inventory-filter-needsSetup')),
      );
      await tester.pumpAndSettle();
      expect(find.text('待设置物品'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inventory-item-washer')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('inventory-item-003')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('inventory-filter-all')));
      await tester.enterText(find.byKey(const Key('inventory-search')), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的物品'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inventory-clear-search')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-item-003')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inventory-sort')));
      await tester.pumpAndSettle();
      expect(find.text('物品排序'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inventory-sort-date')));
      await tester.pumpAndSettle();
      expect(find.text('按时间'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('inventory-item-003'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('inventory-item-washer')))
              .dy,
        ),
      );

      await tester.tap(find.byKey(const Key('inventory-add-item')));
      expect(addCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar shows concrete task and matches detail status', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    final today = maintenanceDateOnly(DateTime.now());
    final otherDay = addMaintenanceDays(today, today.day == 1 ? 1 : -1);
    final item = CareItem(
      id: 'washer',
      name: '洗衣机',
      category: '家电',
      location: '',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [
        MaintenancePlan(
          id: 'drum',
          title: '内筒清洁',
          intervalDays: 30,
          dueDate: today,
        ),
        MaintenancePlan(
          id: 'drain-filter',
          title: '排水过滤器清洁',
          intervalDays: 30,
          dueDate: otherDay,
        ),
      ],
    );
    final store = CareStore()..items = [item];

    await tester.pumpWidget(MaterialApp(home: SchedulePage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('洗衣机'), findsOneWidget);
    expect(find.text('内筒清洁'), findsOneWidget);
    expect(find.text('今日到期'), findsOneWidget);

    await tester.tap(
      find.byKey(
        ValueKey(
          'calendar-day-${otherDay.year}-${otherDay.month}-${otherDay.day}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('排水过滤器清洁'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(store: store, item: item),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('detail-plan-status-drum')),
      findsOneWidget,
    );
    expect(find.textContaining('今日到期'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('schedule empty-day copy wraps at iPhone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = maintenanceDateOnly(DateTime.now());
    final plan = MaintenancePlan(
      id: 'future-plan',
      title: 'Filter replacement',
      intervalDays: 180,
      dueDate: addMaintenanceDays(today, 1),
    );
    final item = CareItem(
      id: 'future-item',
      name: 'Water purifier',
      category: '滤芯与耗材',
      location: 'Kitchen',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [plan],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SchedulePage(store: CareStore()..items = [item]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nothing is scheduled for this day. Enjoy the time.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'execution requires all steps and records inputs plus before-after photos',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      final task = _executionTask();
      final controller = _FakeExecutionController(
        task: task,
        importedPaths: const ['/tmp/before.jpg', '/tmp/after.jpg'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceExecutionPage(controller: controller, task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('厨房净水器'), findsOneWidget);
      expect(find.text('更换滤芯'), findsOneWidget);
      expect(find.textContaining('原计划日期'), findsOneWidget);
      expect(find.text('关闭进水阀，确保停止进水'), findsOneWidget);
      final completionButton = tester.widget<FilledButton>(
        find.byKey(const Key('complete-maintenance')),
      );
      expect(completionButton.onPressed, isNull);

      await tester.tap(find.byKey(const Key('execution-before-photo-entry')));
      await tester.pumpAndSettle();
      expect(find.text('保养前留照'), findsOneWidget);
      expect(find.text('保养后照片'), findsNothing);
      await tester.tap(find.byKey(const Key('add-before-maintenance-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('execution-photo-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('execution-step-water-off')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('complete-maintenance')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('execution-before-photo-entry')),
            )
            .onTap,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('execution-before-photo-entry')));
      await tester.pumpAndSettle();
      expect(find.text('执行已经开始，保养前照片已锁定。'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('add-before-maintenance-photo')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('execution-record-cost')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('execution-cost')), '129');
      await tester.tap(find.byKey(const Key('record-field-done')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('execution-record-material')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('execution-material')),
        'PP 棉滤芯 A1',
      );
      await tester.tap(find.byKey(const Key('record-field-done')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('execution-record-note')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('execution-note')), '已冲洗');
      await tester.tap(find.byKey(const Key('record-field-done')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('execution-after-photo-entry')),
            )
            .onTap,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('execution-step-flush')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('complete-maintenance')))
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(
        find.byKey(const Key('execution-after-photo-entry')),
      );
      await tester.tap(find.byKey(const Key('execution-after-photo-entry')));
      await tester.pumpAndSettle();
      expect(find.text('保养后留照'), findsOneWidget);
      expect(find.text('保养前照片'), findsNothing);
      await tester.tap(find.byKey(const Key('add-after-maintenance-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('execution-photo-gallery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('complete-maintenance')));
      await tester.pumpAndSettle();

      final draft = controller.lastDraft!;
      expect(draft.cost, 129);
      expect(draft.materialName, 'PP 棉滤芯 A1');
      expect(draft.note, '已冲洗');
      expect(draft.completedStepIds, ['water-off', 'flush']);
      expect(draft.beforePhotos, ['/tmp/before.jpg']);
      expect(draft.afterPhotos, ['/tmp/after.jpg']);
      expect(find.text('本次保养已归档'), findsOneWidget);
      expect(
        find.byKey(const Key('completion-notification-warning')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('execution failure stays editable and exposes retry state', (
    tester,
  ) async {
    final task = _executionTask();
    final controller = _FakeExecutionController(
      task: task,
      completionError: const MaintenanceCompletionException(
        '本次保养保存失败，数据未更新。请重试。',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceExecutionPage(controller: controller, task: task),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('execution-step-water-off')));
    await tester.tap(find.byKey(const ValueKey('execution-step-flush')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('complete-maintenance')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('complete-maintenance')));
    await tester.pumpAndSettle();

    expect(controller.completeCalls, 1);
    expect(
      find.byKey(const Key('maintenance-completion-error')),
      findsOneWidget,
    );
    expect(find.textContaining('数据未更新'), findsOneWidget);
    expect(find.text('完成本次保养'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo returned after execution page closes is discarded', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    final task = _executionTask();
    final importResult = Completer<PhotoImportResult>();
    final controller = _FakeExecutionController(
      task: task,
      importResult: importResult,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceExecutionPage(controller: controller, task: task),
      ),
    );
    await tester.tap(find.byKey(const Key('execution-before-photo-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-before-maintenance-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('execution-photo-gallery')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    importResult.complete(
      const PhotoImportResult.success('/tmp/late-import.jpg'),
    );
    await tester.pump();
    await tester.pump();

    expect(controller.discardedPaths, ['/tmp/late-import.jpg']);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('execution submit lock ignores consecutive taps', (tester) async {
    final task = _executionTask();
    final gate = Completer<void>();
    final controller = _FakeExecutionController(
      task: task,
      completionGate: gate,
      notificationScheduled: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceExecutionPage(controller: controller, task: task),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('execution-step-water-off')));
    await tester.tap(find.byKey(const ValueKey('execution-step-flush')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('complete-maintenance')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('complete-maintenance')));
    await tester.tap(find.byKey(const Key('complete-maintenance')));
    expect(controller.completeCalls, 1);
    gate.complete();
    await tester.pumpAndSettle();

    expect(controller.completeCalls, 1);
    expect(find.text('本次保养已归档'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification tap opens the exact maintenance execution page', (
    tester,
  ) async {
    final task = _executionTask();
    final sibling = MaintenancePlan(
      id: 'deep-clean',
      title: '深度清洗',
      intervalDays: 365,
      dueDate: addMaintenanceDays(DateTime.now(), 30),
    );
    final item = task.item.copyWith(plans: [task.plan, sibling]);
    final store = CareStore()
      ..loaded = true
      ..items = [item];
    await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
    await tester.pump();

    store.handleNotificationPayload(
      MaintenanceNotificationPayload(
        itemId: item.id,
        planId: task.plan.id,
      ).encode(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceExecutionPage), findsOneWidget);
    expect(find.text('厨房净水器'), findsOneWidget);
    expect(find.text('更换滤芯'), findsOneWidget);
    expect(find.text('深度清洗'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleted notification target returns to schedule with a reason', (
    tester,
  ) async {
    final store = CareStore()
      ..loaded = true
      ..items = [];
    await tester.pumpWidget(MaterialApp(home: HomePage(store: store)));
    await tester.pump();

    store.handleNotificationPayload(
      const MaintenanceNotificationPayload(
        itemId: 'deleted-item',
        planId: 'deleted-plan',
      ).encode(),
    );
    await tester.pumpAndSettle();

    expect(find.text('保养日程'), findsOneWidget);
    expect(find.textContaining('物品已删除'), findsOneWidget);
    expect(find.byType(MaintenanceExecutionPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifecycle detail explains an empty traceable timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    final item = CareItem(
      id: 'empty-lifecycle',
      name: '书房加湿器',
      category: '家电',
      location: '书房',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: const [],
    );
    final store = CareStore()
      ..loaded = true
      ..items = [item];

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(store: store, item: item),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('maintenance-lifecycle-overview')),
      findsOneWidget,
    );
    expect(find.text('未填写购买日期'), findsOneWidget);
    expect(find.text('0 次'), findsOneWidget);
    expect(
      find.byKey(const Key('detail-set-maintenance-plan')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('detail-set-maintenance-plan')));
    await tester.pumpAndSettle();
    expect(find.byType(EditorPage), findsOneWidget);
    expect(find.byKey(const Key('add-maintenance-plan')), findsOneWidget);
    Navigator.of(tester.element(find.byType(EditorPage))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('maintenance-timeline-empty')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('还没有生命周期事件'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('timeline shows plan, long facts, steps and multiple photos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    final filter = MaintenancePlan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      dueDate: DateTime(2026, 9, 1),
      checklist: const [
        MaintenanceStep(id: 'power', title: '断开设备电源', sortOrder: 0),
        MaintenanceStep(id: 'wash', title: '使用清水完整冲洗并等待滤网彻底晾干', sortOrder: 1),
      ],
    );
    final deepClean = MaintenancePlan(
      id: 'deep-clean',
      title: '深度清洁',
      intervalDays: 365,
      dueDate: DateTime(2027, 1, 1),
    );
    final longNote = '已检查出风口、风轮和排水状态；这是一段用于验证时间线长文本能够完整换行且不会被省略的真实备注。';
    final item = CareItem(
      id: 'rich-lifecycle',
      name: '客厅空调',
      category: '家电',
      location: '客厅',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [filter, deepClean],
      records: [
        MaintenanceRecord(
          id: 'filter-record',
          planId: 'filter',
          completedAt: DateTime(2026, 6, 1),
          kind: '清洗滤网',
          cost: 128.5,
          materialName: '环保型空调滤网清洁剂 500ml 加长型号',
          note: longNote,
          completedStepIds: const ['power'],
          beforePhotos: const ['/tmp/before-1.jpg', '/tmp/before-2.jpg'],
          afterPhotos: const ['/tmp/after-1.jpg', '/tmp/after-2.jpg'],
        ),
        MaintenanceRecord(
          id: 'deep-record',
          planId: 'deep-clean',
          completedAt: DateTime(2026, 2, 1),
          kind: '深度清洁',
          cost: 300,
          note: '',
        ),
      ],
      purchaseDate: DateTime(2025, 1, 1),
    );
    final store = CareStore()
      ..loaded = true
      ..items = [item];

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(store: store, item: item),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('maintenance-record-filter-record')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('清洗滤网'), findsWidgets);
    expect(find.text(longNote), findsOneWidget);
    expect(find.text('步骤：已完成 1 / 2'), findsOneWidget);
    expect(find.text('保养前照片 · 2 张'), findsOneWidget);
    expect(find.text('保养后照片 · 2 张'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('maintenance-record-deep-record')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('深度清洁'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('maintenance-purchase-timeline-entry')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('购买起点'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('record edit refreshes facts and delete rolls plan back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    final plan = MaintenancePlan(
      id: 'filter',
      title: '清洗滤网',
      intervalDays: 90,
      lastCompletedAt: DateTime(2026, 6, 1),
      dueDate: DateTime(2026, 8, 30),
      checklist: const [
        MaintenanceStep(id: 'power', title: '断电', sortOrder: 0),
      ],
    );
    final item = CareItem(
      id: 'editable-lifecycle',
      name: '卧室空调',
      category: '家电',
      location: '卧室',
      brand: '',
      model: '',
      notes: '',
      photos: const [],
      plans: [plan],
      records: [
        MaintenanceRecord(
          id: 'latest-record',
          planId: 'filter',
          completedAt: DateTime(2026, 6, 1),
          cost: 60,
          note: '原备注',
          completedStepIds: const ['power'],
        ),
        MaintenanceRecord(
          id: 'older-record',
          planId: 'filter',
          completedAt: DateTime(2026, 3, 1),
          cost: 30,
          note: '上一次记录',
          completedStepIds: const ['power'],
        ),
      ],
    );
    final store =
        CareStore(
            repository: CareRepository(preferences),
            notificationScheduler: (_, __) async {},
          )
          ..loaded = true
          ..items = [item];
    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(store: store, item: item),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-maintenance-record-latest-record')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('edit-maintenance-record-latest-record')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('record-editor-cost')), '75.5');
    await tester.enterText(
      find.byKey(const Key('record-editor-note')),
      '修正后的详细备注',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-maintenance-record')),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('save-maintenance-record')));
    await tester.pumpAndSettle();

    expect(store.items.single.records.first.cost, 75.5);
    expect(store.items.single.records.first.note, '修正后的详细备注');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delete-maintenance-record-latest-record')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('delete-maintenance-record-latest-record')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-delete-maintenance-record')),
    );
    await tester.pumpAndSettle();

    final saved = store.items.single;
    expect(saved.records.map((record) => record.id), ['older-record']);
    expect(saved.plans.single.lastCompletedAt, DateTime(2026, 3, 1));
    expect(saved.plans.single.dueDate, DateTime(2026, 5, 30));
    expect(
      find.byKey(const ValueKey('maintenance-record-latest-record')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('plan editor has no overflow on small iPhone and iPad sizes', (
    tester,
  ) async {
    final template = maintenanceTemplates.first;
    final plan = template.createPlan(
      planId: 'layout-plan',
      referenceDate: DateTime(2026, 1, 1),
    );
    for (final size in [const Size(320, 568), const Size(1024, 1366)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(home: MaintenancePlanEditorPage(initialPlan: plan)),
      );
      await tester.pumpAndSettle();
      expect(find.text('编辑保养计划'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('secondary-page back button stays square in tall app bars', (
    tester,
  ) async {
    for (final toolbarHeight in [56.0, 72.0, 76.0, 96.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              toolbarHeight: toolbarHeight,
              leading: const AppBackButton(),
              title: const Text('二级页面'),
            ),
          ),
        ),
      );

      final button = find.descendant(
        of: find.byType(AppBackButton),
        matching: find.byType(IconButton),
      );
      expect(button, findsOneWidget);
      expect(
        tester.getSize(button),
        const Size.square(AppBackButton.dimension),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
