import 'package:almanac/src/almanac_app.dart';
import 'package:almanac/src/app_controller.dart';
import 'package:almanac/src/domain/almanac_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Future<AppController> _controller({
  bool onboarded = true,
  MemoryStateStore? store,
}) async {
  final controller = AppController(
    store: store ?? MemoryStateStore(),
    seedFactory: () => 'widget-seed',
    clock: () => DateTime(2026, 10, 10, 9),
  );
  await controller.load();
  await controller.setLocaleMode(AppLocaleMode.zhHans);
  if (onboarded) await controller.completeOnboarding();
  return controller;
}

void main() {
  testWidgets('onboarding states the boundary and opens today', (tester) async {
    final controller = await _controller(onboarded: false);
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('不是择日或吉凶预测'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open_today_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);
  });

  testWidgets('core path seals, reflects, and appears in the folio', (
    tester,
  ) async {
    final controller = await _controller();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    final leaf = controller.todayLeaf;

    await tester.ensureVisible(
      find.byKey(Key('prompt_${leaf.suitablePromptIds.first}')),
    );
    await tester.tap(find.byKey(Key('prompt_${leaf.suitablePromptIds.first}')));
    await tester.ensureVisible(
      find.byKey(Key('prompt_${leaf.avoidPromptIds.first}')),
    );
    await tester.tap(find.byKey(Key('prompt_${leaf.avoidPromptIds.first}')));
    await tester.ensureVisible(find.byKey(const Key('intention_field')));
    await tester.enterText(find.byKey(const Key('intention_field')), '把桌面清出一角');
    await tester.ensureVisible(find.byKey(const Key('seal_leaf_button')));
    await tester.tap(find.byKey(const Key('seal_leaf_button')));
    await tester.pumpAndSettle();

    expect(find.text('今日已收笺'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('reflect_button')));
    await tester.ensureVisible(find.byKey(const Key('reflect_button')));
    await tester.tap(find.byKey(const Key('reflect_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outcome_practiced')));
    await tester.pumpAndSettle();
    expect(find.text('践行'), findsOneWidget);

    await tester.tap(find.byKey(const Key('folio_tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folio_leaf_2026-10-10')), findsOneWidget);
  });

  testWidgets('reflection sheet can dismiss and reopen without mutation', (
    tester,
  ) async {
    final controller = await _controller();
    final leaf = controller.todayLeaf;
    await controller.sealToday(
      suitableId: leaf.suitablePromptIds.first,
      avoidId: leaf.avoidPromptIds.first,
      intention: '',
    );
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('reflect_button')));
    await tester.tap(find.byKey(const Key('reflect_button')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(controller.todayLeaf.outcome, isNull);

    await tester.tap(find.byKey(const Key('reflect_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outcome_reframed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language switch preserves content and shows English UI', (
    tester,
  ) async {
    final controller = await _controller();
    final contentBefore = controller.todayLeaf.toJson();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('locale_en')));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(controller.todayLeaf.toJson(), contentBefore);
  });

  testWidgets('compact large-text layout remains scrollable without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final controller = await _controller();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();

    final leaf = controller.todayLeaf;
    await tester.ensureVisible(
      find.byKey(Key('prompt_${leaf.suitablePromptIds.first}')),
    );
    await tester.tap(find.byKey(Key('prompt_${leaf.suitablePromptIds.first}')));
    await tester.ensureVisible(
      find.byKey(Key('prompt_${leaf.avoidPromptIds.first}')),
    );
    await tester.tap(find.byKey(Key('prompt_${leaf.avoidPromptIds.first}')));
    await tester.ensureVisible(find.byKey(const Key('intention_field')));
    await tester.enterText(
      find.byKey(const Key('intention_field')),
      List<String>.filled(140, '🪷').join(),
    );
    await tester.ensureVisible(find.byKey(const Key('seal_leaf_button')));
    await tester.tap(find.byKey(const Key('seal_leaf_button')));
    await tester.pumpAndSettle();

    expect(find.text('今日已收笺'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('reflect_button')));
    await tester.tap(find.byKey(const Key('reflect_button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('outcome_released')));
    await tester.tap(find.byKey(const Key('outcome_released')));
    await tester.pumpAndSettle();
    expect(controller.todayLeaf.outcome, ReflectionOutcome.released);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reflection write failure is visible and retryable', (
    tester,
  ) async {
    final store = MemoryStateStore();
    final controller = await _controller(store: store);
    final leaf = controller.todayLeaf;
    await controller.sealToday(
      suitableId: leaf.suitablePromptIds.first,
      avoidId: leaf.avoidPromptIds.first,
      intention: '',
    );
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();

    store.failWrite = true;
    await tester.ensureVisible(find.byKey(const Key('reflect_button')));
    await tester.tap(find.byKey(const Key('reflect_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outcome_practiced')));
    await tester.pumpAndSettle();
    expect(controller.todayLeaf.outcome, isNull);
    expect(find.text('未能保存。原有本地记录没有被替换，请重试。'), findsOneWidget);

    store.failWrite = false;
    await tester.tap(find.byKey(const Key('reflect_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outcome_practiced')));
    await tester.pumpAndSettle();
    expect(controller.todayLeaf.outcome, ReflectionOutcome.practiced);
    expect(controller.hasSaveFailure, isFalse);
  });

  testWidgets('text field blocks a 141st emoji before sealing', (tester) async {
    final controller = await _controller();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    final leaf = controller.todayLeaf;

    await tester.ensureVisible(
      find.byKey(Key('prompt_${leaf.suitablePromptIds.first}')),
    );
    await tester.tap(find.byKey(Key('prompt_${leaf.suitablePromptIds.first}')));
    await tester.ensureVisible(
      find.byKey(Key('prompt_${leaf.avoidPromptIds.first}')),
    );
    await tester.tap(find.byKey(Key('prompt_${leaf.avoidPromptIds.first}')));
    await tester.ensureVisible(find.byKey(const Key('intention_field')));
    await tester.enterText(
      find.byKey(const Key('intention_field')),
      List<String>.filled(141, '🪷').join(),
    );
    await tester.pump();
    expect(find.text('140/140'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('seal_leaf_button')));
    await tester.tap(find.byKey(const Key('seal_leaf_button')));
    await tester.pumpAndSettle();

    expect(
      controller.todayLeaf.intention,
      List<String>.filled(140, '🪷').join(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings write failure stays visible and can be retried', (
    tester,
  ) async {
    final store = MemoryStateStore();
    final controller = await _controller(store: store);
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();

    store.failWrite = true;
    await tester.tap(find.byKey(const Key('locale_en')));
    await tester.pumpAndSettle();
    expect(controller.data!.localeMode, AppLocaleMode.zhHans);
    expect(find.text('未能保存。原有本地记录没有被替换，请重试。'), findsOneWidget);

    store.failWrite = false;
    await tester.tap(find.byKey(const Key('locale_en')));
    await tester.pumpAndSettle();
    expect(controller.data!.localeMode, AppLocaleMode.en);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('theme selection updates its visible selected semantics', (
    tester,
  ) async {
    final controller = await _controller();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('theme_dark')));
    await tester.pumpAndSettle();
    expect(controller.data!.themeMode, AppThemeMode.dark);
    expect(
      find.descendant(
        of: find.byKey(const Key('theme_dark')),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
  });

  testWidgets('midnight race shows a localized reselection notice', (
    tester,
  ) async {
    var current = DateTime(2026, 10, 10, 23, 59);
    final controller = AppController(
      store: MemoryStateStore(),
      seedFactory: () => 'widget-midnight-seed',
      clock: () => current,
    );
    await controller.load();
    await controller.setLocaleMode(AppLocaleMode.zhHans);
    await controller.completeOnboarding();
    final yesterday = controller.todayLeaf;
    current = DateTime(2026, 10, 11, 0, 0, 1);
    await controller.sealToday(
      suitableId: yesterday.suitablePromptIds.first,
      avoidId: yesterday.avoidPromptIds.first,
      intention: '',
    );

    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('日期已经更新。请重新选择今天的宜与忌。'), findsOneWidget);
    expect(find.text('2026年10月11日 · 周日'), findsOneWidget);
    expect(controller.todayLeaf.isSealed, isFalse);
  });
}
