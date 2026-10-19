import 'package:almanac/src/almanac_app.dart';
import 'package:almanac/src/app_controller.dart';
import 'package:almanac/src/domain/almanac_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'test_support.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final urls = <String>[];
  final modes = <PreferredLaunchMode>[];
  bool result = false;
  PlatformException? error;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    modes.add(options.mode);
    if (error != null) throw error!;
    return result;
  }
}

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
  late UrlLauncherPlatform originalLauncher;
  late _FakeUrlLauncher launcher;

  setUp(() {
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() => UrlLauncherPlatform.instance = originalLauncher);

  testWidgets('system defaults follow language and appearance changes', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final controller = AppController(
      store: MemoryStateStore(),
      seedFactory: () => 'system-default-seed',
      clock: () => DateTime(2026, 10, 10, 9),
    );
    await controller.load();
    await controller.completeOnboarding();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(controller.data!.localeMode, AppLocaleMode.system);
    expect(controller.data!.themeMode, AppThemeMode.system);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
      Brightness.light,
    );

    tester.platformDispatcher.localesTestValue = const <Locale>[
      Locale('zh', 'CN'),
    ];
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const Key('locale_en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme_light')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
      Brightness.light,
    );
    expect(controller.data!.localeMode, AppLocaleMode.en);
    expect(controller.data!.themeMode, AppThemeMode.light);
  });

  testWidgets('onboarding states the boundary and opens today', (tester) async {
    final controller = await _controller(onboarded: false);
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('不是择日或吉凶预测'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open_today_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);
  });

  testWidgets(
    'onboarding stays usable above the gesture area on a compact screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);

      final controller = await _controller(onboarded: false);
      await tester.pumpWidget(AlmanacApp(controller: controller));
      await tester.pumpAndSettle();

      final scroll = find.byKey(const Key('onboarding_page_0'));
      final next = find.byKey(const Key('onboarding_next_button'));
      expect(
        tester.getBottomRight(scroll).dy,
        lessThan(tester.getTopLeft(next).dy),
      );

      await tester.drag(scroll, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(next).dy,
        lessThanOrEqualTo(640 - 34 - 20 + 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('three-page onboarding persists completion after relaunch', (
    tester,
  ) async {
    final store = MemoryStateStore();
    final controller = await _controller(onboarded: false, store: store);
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('不是择日或吉凶预测'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('选一项宜，留一项忌'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('只属于你的笺册'), findsOneWidget);
    expect(find.text('你的选择与文字只写在本机；系统备份或主动复制除外。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open_today_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);

    final relaunched = await _controller(onboarded: false, store: store);
    await tester.pumpWidget(AlmanacApp(controller: relaunched));
    await tester.pumpAndSettle();
    expect(relaunched.data!.onboardingSeen, isTrue);
    expect(find.byKey(const Key('daily_leaf_scroll')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_page_0')), findsNothing);
  });

  testWidgets('onboarding pages remain scrollable with large text', (
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

    final controller = await _controller(onboarded: false);
    await controller.setLocaleMode(AppLocaleMode.en);
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    for (var page = 0; page < 3; page++) {
      expect(find.byKey(Key('onboarding_page_$page')), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (page < 2) {
        await tester.tap(find.byKey(const Key('onboarding_next_button')));
        await tester.pumpAndSettle();
      }
    }
    expect(find.byKey(const Key('open_today_button')), findsOneWidget);
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

    await tester.ensureVisible(find.byKey(const Key('theme_dark')));
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

  testWidgets(
    'unavailable online policy falls back to local guidance in each language',
    (tester) async {
      final controller = await _controller();
      await tester.pumpWidget(AlmanacApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();

      final privacyButton = find.byKey(const Key('privacy_button'));
      await tester.ensureVisible(privacyButton);
      await tester.tap(privacyButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy_screen')), findsOneWidget);
      expect(find.text('本地记录'), findsOneWidget);
      expect(find.text('备份与主动复制'), findsOneWidget);
      expect(find.byKey(const Key('privacy_retry_button')), findsOneWidget);
      expect(launcher.urls, <String>[
        'https://www.almanac1.com/privacy.html?lang=zh',
      ]);

      Navigator.of(
        tester.element(find.byKey(const Key('privacy_screen'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacy_screen')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('locale_en')));
      await tester.tap(find.byKey(const Key('locale_en')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(privacyButton);
      await tester.tap(privacyButton);
      await tester.pumpAndSettle();
      expect(find.text('Local records'), findsOneWidget);
      expect(find.text('Backups and copies'), findsOneWidget);
      expect(
        launcher.urls.last,
        'https://www.almanac1.com/privacy.html?lang=en',
      );
    },
  );

  testWidgets('privacy entry opens the published policy for the app language', (
    tester,
  ) async {
    launcher.result = true;
    final controller = await _controller();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();

    final privacyButton = find.byKey(const Key('privacy_button'));
    await tester.ensureVisible(privacyButton);
    await tester.tap(privacyButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy_screen')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('locale_en')));
    await tester.tap(find.byKey(const Key('locale_en')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(privacyButton);
    await tester.tap(privacyButton);
    await tester.pumpAndSettle();

    expect(launcher.urls, <String>[
      'https://www.almanac1.com/privacy.html?lang=zh',
      'https://www.almanac1.com/privacy.html?lang=en',
    ]);
    expect(launcher.modes, everyElement(PreferredLaunchMode.inAppBrowserView));
    expect(find.byKey(const Key('privacy_screen')), findsNothing);
  });

  testWidgets('privacy launch error preserves local guidance and can retry', (
    tester,
  ) async {
    launcher.error = PlatformException(code: 'launch_failed');
    final controller = await _controller();
    await tester.pumpWidget(AlmanacApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();
    final privacyButton = find.byKey(const Key('privacy_button'));
    await tester.ensureVisible(privacyButton);
    await tester.tap(privacyButton);
    await tester.pumpAndSettle();
    expect(find.text('本地记录'), findsOneWidget);
    expect(tester.takeException(), isNull);

    launcher.error = null;
    launcher.result = true;
    await tester.tap(find.byKey(const Key('privacy_retry_button')));
    await tester.pumpAndSettle();
    expect(launcher.urls, <String>[
      'https://www.almanac1.com/privacy.html?lang=zh',
      'https://www.almanac1.com/privacy.html?lang=zh',
    ]);
    expect(find.byKey(const Key('privacy_screen')), findsNothing);
    expect(find.byKey(const Key('settings_button')), findsNothing);
    expect(find.text('数据与隐私'), findsOneWidget);
  });

  testWidgets('settings and privacy stay reachable with large text', (
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
    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();
    final privacyButton = find.byKey(const Key('privacy_button'));
    await tester.ensureVisible(privacyButton);
    await tester.tap(privacyButton);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('清除与保留'));

    expect(find.byKey(const Key('privacy_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('2026年10月11日'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
    expect(controller.todayLeaf.isSealed, isFalse);
  });
}
