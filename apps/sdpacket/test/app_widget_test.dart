import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moving_box/app.dart';
import 'package:moving_box/data/app_repository.dart';
import 'package:moving_box/data/app_store.dart';
import 'package:moving_box/models/box_record.dart';
import 'package:moving_box/models/entry_batch.dart';
import 'package:moving_box/screens/batch_editor_screen.dart';
import 'package:moving_box/screens/project_detail_screen.dart';
import 'package:moving_box/screens/settings_screen.dart';
import 'package:moving_box/widgets/adaptive_action_layout.dart';
import 'package:moving_box/widgets/ios_modal.dart';

void main() {
  testWidgets(
    'first launch follows the system language and completes onboarding',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final repository = InMemoryAppRepository();
      final store = AppStore(repository: repository, initialLanguageCode: 'zh');
      await store.initialize(
        const SampleSeed(
          projectName: '示例搬家',
          origin: '旧家',
          destination: '新家',
          memo: '咖啡机',
        ),
      );

      await tester.pumpWidget(MovingBoxApp(store: store));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
      expect(find.text('十几秒登记一只箱子'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();

      expect(store.hasCompletedOnboarding, isTrue);
      expect(repository.hasCompletedOnboarding, isTrue);
      expect(find.text('搬家项目'), findsOneWidget);
    },
  );

  testWidgets('saved app language controls onboarding copy', (tester) async {
    final repository = InMemoryAppRepository(null, 'zh');
    final store = AppStore(repository: repository, initialLanguageCode: 'en');
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();

    expect(store.languageCode, 'zh');
    expect(find.text('十几秒登记一只箱子'), findsOneWidget);
    expect(find.text('Register each box in seconds'), findsNothing);
  });

  testWidgets('shows the seeded project and core entry points', (tester) async {
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Sample move'), findsOneWidget);
    expect(find.text('Moving projects'), findsOneWidget);

    await tester.tap(find.text('Sample move'));
    await tester.pumpAndSettle();
    expect(find.text('Quick entry'), findsOneWidget);
    expect(find.text('Manual entry'), findsOneWidget);
    expect(find.text('Voice entry'), findsOneWidget);
  });

  testWidgets('redesigned home keeps its primary actions working', (
    tester,
  ) async {
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.byKey(const Key('home-create-project')), findsOneWidget);

    await tester.tap(find.byTooltip('Global search'));
    await tester.pumpAndSettle();
    expect(find.text('Global search'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-more-sheet')), findsOneWidget);
    expect(find.text('Archived projects'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-more-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-more-sheet')), findsNothing);

    await tester.tap(find.byKey(const Key('home-create-project')));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home more sheet fits a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-more-sheet')), findsOneWidget);
    expect(find.byKey(const Key('home-more-archived')), findsOneWidget);
    expect(find.byKey(const Key('home-more-settings')), findsOneWidget);
    expect(find.byKey(const Key('home-more-cancel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches between English and Chinese at runtime', (
    tester,
  ) async {
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Moving projects'), findsOneWidget);

    await store.setLanguageCode('zh');
    await tester.pumpAndSettle();
    expect(find.text('搬家项目'), findsOneWidget);

    await store.setLanguageCode('en');
    await tester.pumpAndSettle();
    expect(find.text('Moving projects'), findsOneWidget);
  });

  testWidgets('changes language from settings on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('https://kifxpro.com/index.html?lang=en'), findsOneWidget);
    expect(find.text('15211857631@163.com'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simplified Chinese'));
    await tester.pumpAndSettle();

    expect(store.languageCode, 'zh');
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(
      find.text('https://kifxpro.com/privacy.html?lang=zh'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('English quick actions fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ProjectDetailScreen(projectId: store.activeProjects.single.id),
          ),
        );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Continuous camera'), findsOneWidget);
    expect(find.text('Choose photos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch actions stack on a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );
    final project = store.activeProjects.single;
    final batch = await store.createEntryBatch(
      projectId: project.id,
      source: EntryBatchSource.gallery,
    );
    await store.createBox(projectId: project.id, entryBatchId: batch.id);

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => BatchEditorScreen(batchId: batch.id),
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Save and finish'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AdaptiveActionLayout),
        matching: find.byType(Column),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage card filters the visible box list', (tester) async {
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );
    final project = store.activeProjects.single;
    final arrived = await store.createBox(projectId: project.id);
    await store.updateBox(arrived.copyWith(moveStatus: MoveStatus.arrived));

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample move'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Waiting to load 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('C-001'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('C-001'), findsOneWidget);
    expect(find.text('C-002'), findsNothing);
  });

  testWidgets('unfinished batch is exposed as a resume action', (tester) async {
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );
    final project = store.activeProjects.single;
    final batch = await store.createEntryBatch(
      projectId: project.id,
      source: EntryBatchSource.gallery,
    );
    await store.createBox(projectId: project.id, entryBatchId: batch.id);

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample move'));
    await tester.pumpAndSettle();

    expect(find.text('Resume unfinished batch'), findsOneWidget);
    await tester.tap(find.text('Resume unfinished batch'));
    await tester.pumpAndSettle();
    expect(find.text('Box 1 / 1'), findsOneWidget);
    expect(find.text('Save and finish'), findsOneWidget);
  });

  testWidgets('edits structured item details and unpacked state', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    final store = AppStore(repository: InMemoryAppRepository.onboarded());
    await store.initialize(
      const SampleSeed(
        projectName: 'Sample move',
        origin: 'Old home',
        destination: 'New home',
        memo: 'Coffee maker',
      ),
    );
    final boxId = store
        .boxesForProject(store.activeProjects.single.id)
        .single
        .id;

    await tester.pumpWidget(MovingBoxApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample move'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('C-001'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('project-detail-scroll')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('C-001'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add item'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(IosFormSheet), findsOneWidget);
    expect(find.byType(IosFormDialog), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);

    final nameField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('item-name-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(nameField.decoration!.enabledBorder, isA<OutlineInputBorder>());

    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    await tester.pump();
    await tester.tap(find.byKey(const Key('item-note-field')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 360);
    await tester.pumpAndSettle();

    final keyboardTop = tester.view.physicalSize.height - 360;
    final sheet = tester.getRect(
      find.byKey(const Key('ios-form-sheet-surface')),
    );
    final actions = tester.getRect(
      find.byKey(const Key('ios-form-sheet-actions')),
    );
    final focusedField = tester.getRect(
      find.byKey(const Key('item-note-field')),
    );
    expect(sheet.bottom, closeTo(keyboardTop, 0.1));
    expect(focusedField.bottom, lessThanOrEqualTo(actions.top));
    expect(tester.takeException(), isNull);

    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('item-name-field')),
      'Coffee cup',
    );
    await tester.enterText(find.byKey(const Key('item-quantity-field')), '2');
    await tester.enterText(
      find.byKey(const Key('item-note-field')),
      'Blue cups',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(IosFormSheet),
        matching: find.widgetWithText(CupertinoButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coffee cup'), findsOneWidget);
    expect(find.text('Quantity 2 · Blue cups'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final item = store.boxById(boxId)!.items.single;
    expect(item.quantity, 2);
    expect(item.note, 'Blue cups');
    expect(item.isUnpacked, isTrue);
  });
}
