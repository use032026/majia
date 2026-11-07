import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_fixture/domain/fixture_engine.dart';
import 'package:id_fixture/services/app_settings.dart';
import 'package:id_fixture/services/platform_services.dart';
import 'package:id_fixture/ui/app.dart';

class FakeServices implements PlatformServices {
  OpenedPackage? nextPackage;
  String? copied;
  String? shared;
  Rect? origin;
  int opens = 0;

  @override
  Future<void> copyText(String text) async => copied = text;

  @override
  Future<OpenedPackage?> openPackage() async {
    opens++;
    return nextPackage;
  }

  @override
  Future<void> openSource(String url) async {}

  @override
  Future<ShareOutcome> sharePackage(
    String json, {
    required String filename,
    required Rect origin,
  }) async {
    shared = json;
    this.origin = origin;
    return ShareOutcome.dismissed;
  }
}

class FailingOnboardingStore extends MemoryPreferenceStore {
  @override
  Future<void> setBool(String key, bool value) async {
    throw StateError('Storage unavailable');
  }
}

Future<AppSettings> settingsForTest({bool complete = true}) async {
  final settings = await AppSettings.load(store: MemoryPreferenceStore());
  await settings.setLanguage('zh');
  if (complete) await settings.completeOnboarding();
  return settings;
}

Future<void> launch(
  WidgetTester tester, {
  required AppSettings settings,
  required FakeServices services,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(IdFixtureApp(settings: settings, services: services));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    final scope = find.byKey(const ValueKey('address.results'));
    final scrollable = scope.evaluate().isNotEmpty
        ? find.descendant(of: scope, matching: find.byType(Scrollable)).first
        : find.byType(Scrollable).last;
    await tester.drag(scrollable, const Offset(0, 20000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: scrollable,
      maxScrolls: 150,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final alignment =
      [
        Alignment.center,
        const Alignment(-.5, -.8),
        const Alignment(-.5, .8),
      ].firstWhere(
        (candidate) => finder.hitTestable(at: candidate).evaluate().isNotEmpty,
        orElse: () => throw TestFailure('No visible tappable part of $key'),
      );
  final point =
      tester.getTopLeft(finder) + alignment.alongSize(tester.getSize(finder));
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

OpenedPackage packageFor({
  String profileId = 'cn-id',
  String seed = 'sample-01',
  String mode = 'positive',
}) {
  final package = FixtureEngine.createPackage(
    FixtureEngine.generate({
      'profileId': profileId,
      'count': 1,
      'seed': seed,
      'mode': mode,
    }),
  );
  return OpenedPackage(text: jsonEncode(package), name: 'test-package.json');
}

String caseValue(WidgetTester tester) => tester
    .widget<SelectableText>(find.byKey(const ValueKey('case.value.0')))
    .data!;

String selectionValue(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
      ),
    )
    .map((entry) => entry.data ?? '')
    .join();

Future<void> searchAddress(WidgetTester tester, String code) async {
  final search = find.byKey(const ValueKey('address.search'));
  await tester.ensureVisible(search);
  await tester.enterText(search, code);
  await tester.pumpAndSettle();
  await tapKey(tester, 'address.code.$code');
  await tapKey(tester, 'address.confirm');
}

Future<Map<String, dynamic>> exportedPackage(
  WidgetTester tester,
  FakeServices services,
) async {
  await tapKey(tester, 'export.package');
  return jsonDecode(services.shared!) as Map<String, dynamic>;
}

void main() {
  testWidgets(
    'first-run skip is retained and replay does not reset completion',
    (tester) async {
      final settings = await settingsForTest(complete: false);
      final services = FakeServices();
      await launch(tester, settings: settings, services: services);
      expect(find.byKey(const ValueKey('onboarding.next')), findsOneWidget);
      await tapKey(tester, 'onboarding.skip');
      expect(settings.onboardingComplete, isTrue);
      expect(find.byKey(const ValueKey('settings.open')), findsOneWidget);
      await tapKey(tester, 'settings.open');
      await tapKey(tester, 'settings.replay');
      await tapKey(tester, 'onboarding.next');
      await tapKey(tester, 'onboarding.complete');
      expect(settings.onboardingComplete, isTrue);
      expect(find.byKey(const ValueKey('settings.replay')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('first-run completion reaches the workbench', (tester) async {
    final settings = await settingsForTest(complete: false);
    await launch(tester, settings: settings, services: FakeServices());
    await tapKey(tester, 'onboarding.next');
    await tapKey(tester, 'onboarding.complete');
    expect(settings.onboardingComplete, isTrue);
    expect(find.byKey(const ValueKey('generate.button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed onboarding persistence does not trap the first session', (
    tester,
  ) async {
    final settings = await AppSettings.load(store: FailingOnboardingStore());
    await settings.setLanguage('zh');
    await launch(tester, settings: settings, services: FakeServices());
    await tapKey(tester, 'onboarding.skip');
    expect(settings.onboardingComplete, isTrue);
    expect(find.byKey(const ValueKey('storage.warning')), findsOneWidget);
    expect(find.byKey(const ValueKey('generate.button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'country changes clear results and Vietnam generates published structure',
    (tester) async {
      final settings = await settingsForTest();
      await launch(tester, settings: settings, services: FakeServices());
      await tapKey(tester, 'generate.button');
      expect(find.byKey(const ValueKey('case.value.0')), findsOneWidget);
      await tapKey(tester, 'country.US');
      expect(find.byKey(const ValueKey('case.value.0')), findsNothing);
      await tapKey(tester, 'generate.button');
      expect(find.byKey(const ValueKey('form.error')), findsOneWidget);
      await tapKey(tester, 'country.VN');
      await tapKey(tester, 'generate.button');
      expect(RegExp(r'^\d{12}$').hasMatch(caseValue(tester)), isTrue);
      expect(find.byKey(const ValueKey('form.error')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('negative checksum case exposes its expected failure', (
    tester,
  ) async {
    await launch(
      tester,
      settings: await settingsForTest(),
      services: FakeServices(),
    );
    await tapKey(tester, 'scenario.negative');
    await tapKey(tester, 'mutation.select');
    await tester.tap(find.text('校验位错误').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'generate.button');
    expect(find.textContaining('预期不通过: 公开规则校验字符'), findsOneWidget);
    await tapKey(tester, 'case.expand.0');
    expect(find.text('未通过'), findsOneWidget);
    expect(find.text('未知'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled open and preview preserve the existing result', (
    tester,
  ) async {
    final services = FakeServices();
    await launch(tester, settings: await settingsForTest(), services: services);
    await tapKey(tester, 'generate.button');
    final previous = tester
        .widget<SelectableText>(find.byKey(const ValueKey('case.value.0')))
        .data;
    await tapKey(tester, 'package.open');
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    services.nextPackage = packageFor(profileId: 'us-ny-dmv');
    await tapKey(tester, 'package.open');
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    final current = tester
        .widget<SelectableText>(find.byKey(const ValueKey('case.value.0')))
        .data;
    expect(current == previous, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful replay clears an unrelated previous state error', (
    tester,
  ) async {
    final services = FakeServices()..nextPackage = packageFor();
    await launch(tester, settings: await settingsForTest(), services: services);
    await tapKey(tester, 'country.US');
    await tapKey(tester, 'generate.button');
    expect(find.byKey(const ValueKey('form.error')), findsOneWidget);
    await tapKey(tester, 'package.open');
    await tapKey(tester, 'package.confirm');
    expect(find.byKey(const ValueKey('form.error')), findsNothing);
    expect(find.byKey(const ValueKey('case.value.0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unavailable package version shows a recoverable dialog', (
    tester,
  ) async {
    final services = FakeServices();
    await launch(tester, settings: await settingsForTest(), services: services);
    await tapKey(tester, 'generate.button');
    final previous = tester
        .widget<SelectableText>(find.byKey(const ValueKey('case.value.0')))
        .data;
    final package = jsonDecode(packageFor().text) as Map<String, dynamic>;
    package['engineVersion'] = 'not-installed';
    services.nextPackage = OpenedPackage(
      text: jsonEncode(package),
      name: 'unavailable.json',
    );
    await tapKey(tester, 'package.open');
    expect(find.text('无法打开用例包'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    final current = tester
        .widget<SelectableText>(find.byKey(const ValueKey('case.value.0')))
        .data;
    expect(current == previous, isTrue);
    services.nextPackage = null;
    await tapKey(tester, 'package.open');
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replay preserves a seed verbatim through regeneration', (
    tester,
  ) async {
    final services = FakeServices()
      ..nextPackage = packageFor(profileId: 'us-ny-dmv', seed: ' sample-01 ');
    await launch(tester, settings: await settingsForTest(), services: services);
    await tapKey(tester, 'package.open');
    await tapKey(tester, 'package.confirm');
    final previous = tester
        .widget<SelectableText>(find.byKey(const ValueKey('case.value.0')))
        .data;
    final seed = tester.widget<TextField>(
      find.byKey(const ValueKey('seed.input')),
    );
    expect(seed.controller!.text == ' sample-01 ', isTrue);
    await tapKey(tester, 'generate.button');
    final regenerated = tester
        .widget<SelectableText>(find.byKey(const ValueKey('case.value.0')))
        .data;
    expect(regenerated == previous, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share passes a real anchor and dismissed sharing keeps cases', (
    tester,
  ) async {
    final services = FakeServices();
    await launch(tester, settings: await settingsForTest(), services: services);
    await tapKey(tester, 'generate.button');
    await tapKey(tester, 'export.package');
    expect(services.origin?.isEmpty, isFalse);
    expect(services.shared != null, isTrue);
    final replay = FixtureEngine.replayPackage(
      FixtureEngine.inspectPackage(services.shared!),
    );
    expect(replay.matches, isTrue);
    expect(find.byKey(const ValueKey('case.value.0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings sheets dismiss, reopen and clear explicit overrides', (
    tester,
  ) async {
    final settings = await settingsForTest();
    await launch(tester, settings: settings, services: FakeServices());
    await tapKey(tester, 'settings.open');
    await tapKey(tester, 'settings.language');
    await tester.tapAt(const Offset(5, 100));
    await tester.pumpAndSettle();
    await tapKey(tester, 'settings.language');
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'settings.language');
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(settings.languageCode, 'en');
    expect(find.text('Preferences'), findsOneWidget);
    await tapKey(tester, 'settings.language');
    await tester.tap(find.text('Follow system').last);
    await tester.pumpAndSettle();
    expect(settings.languageCode, isNull);
    await tapKey(tester, 'settings.theme');
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    await tapKey(tester, 'settings.theme');
    await tester.tap(find.text('Follow system').last);
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.system);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320 width and 200 percent text keep the final controls reachable',
    (tester) async {
      await launch(
        tester,
        settings: await settingsForTest(),
        services: FakeServices(),
        size: const Size(320, 740),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'generate.button');
      await tester.ensureVisible(find.byKey(const ValueKey('export.package')));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const ValueKey('export.package')));
      expect(rect.bottom <= 740, isTrue);
      expect(rect.top >= 0, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mainland search reaches east south west north and special city references',
    (tester) async {
      final services = FakeServices();
      await launch(
        tester,
        settings: await settingsForTest(),
        services: services,
      );
      for (final code in [
        '310101',
        '440106',
        '650102',
        '230102',
        '441900',
        '442000',
        '460400',
        '620200',
        '133100',
      ]) {
        await tapKey(tester, 'address.select');
        await searchAddress(tester, code);
        expect(selectionValue(tester, 'address.select'), contains(code));
        await tapKey(tester, 'generate.button');
        expect(caseValue(tester).startsWith(code), isTrue);
      }
      final package = await exportedPackage(tester, services);
      expect(package['profileId'], 'cn-id');
      expect((package['config'] as Map)['addressCode'], '133100');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mainland navigation commits only a confirmed leaf and overlays reopen',
    (tester) async {
      await launch(
        tester,
        settings: await settingsForTest(),
        services: FakeServices(),
      );
      await tapKey(tester, 'generate.button');
      final previous = caseValue(tester);
      await tapKey(tester, 'address.select');
      await tapKey(tester, 'address.group.130000');
      expect(find.byKey(const ValueKey('address.parent.130000')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('address.confirm')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'address.code.133100');
      await tapKey(tester, 'address.cancel');
      expect(selectionValue(tester, 'address.select'), contains('110101'));
      expect(caseValue(tester), previous);
      await tapKey(tester, 'address.select');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('address.picker')), findsNothing);
      await tapKey(tester, 'address.select');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('address.picker')), findsNothing);
      await tapKey(tester, 'address.select');
      await tapKey(tester, 'address.group.440000');
      await tapKey(tester, 'address.parent.440100');
      await tapKey(tester, 'address.code.440106');
      await tapKey(tester, 'address.back');
      await tapKey(tester, 'address.back');
      await tapKey(tester, 'address.group.110000');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('address.confirm')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'address.code.110105');
      await tapKey(tester, 'address.confirm');
      expect(find.byKey(const ValueKey('case.value.0')), findsNothing);
      expect(selectionValue(tester, 'address.select'), contains('110105'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'China regions expose only encoded parameters and reset stale results',
    (tester) async {
      final services = FakeServices();
      await launch(
        tester,
        settings: await settingsForTest(),
        services: services,
      );
      await tapKey(tester, 'generate.button');
      await tapKey(tester, 'region.HK');
      expect(find.byKey(const ValueKey('case.value.0')), findsNothing);
      expect(find.byKey(const ValueKey('birthday.select')), findsNothing);
      expect(find.byKey(const ValueKey('sex.select')), findsNothing);
      expect(find.byKey(const ValueKey('address.select')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('prefix.input')), 'ab');
      await tapKey(tester, 'generate.button');
      expect(find.byKey(const ValueKey('form.error')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('prefix.input')), 'AB');
      await tapKey(tester, 'generate.button');
      expect(RegExp(r'^AB[0-9]{6}[0-9A]$').hasMatch(caseValue(tester)), isTrue);
      var package = await exportedPackage(tester, services);
      expect((package['config'] as Map)['prefix'], 'AB');
      expect((package['config'] as Map).containsKey('birthDate'), isFalse);
      await tapKey(tester, 'region.MO');
      expect(find.byKey(const ValueKey('prefix.input')), findsNothing);
      expect(find.byKey(const ValueKey('sex.select')), findsNothing);
      await tapKey(tester, 'generate.button');
      package = await exportedPackage(tester, services);
      expect(package['profileId'], 'mo-id');
      expect((package['config'] as Map).containsKey('birthDate'), isFalse);
      await tapKey(tester, 'region.TW');
      expect(find.byKey(const ValueKey('birthday.select')), findsNothing);
      expect(find.byKey(const ValueKey('sex.select')), findsOneWidget);
      await tapKey(tester, 'generate.button');
      expect(
        RegExp(r'^[A-Z][12][0-9]{8}$').hasMatch(caseValue(tester)),
        isTrue,
      );
      package = await exportedPackage(tester, services);
      expect((package['config'] as Map)['allowHistorical'], isFalse);
      expect((package['config'] as Map).containsKey('birthDate'), isFalse);
      await tapKey(tester, 'region.mainland');
      expect(selectionValue(tester, 'address.select'), contains('110101'));
      expect(find.byKey(const ValueKey('birthday.select')), findsOneWidget);
      expect(find.byKey(const ValueKey('case.value.0')), findsNothing);
      await tapKey(tester, 'birthday.select');
      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .maximumDate,
        DateTime(2026, 11, 5),
      );
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Taiwan historical prefixes require an explicit selection and remain labeled',
    (tester) async {
      final services = FakeServices();
      await launch(
        tester,
        settings: await settingsForTest(),
        services: services,
      );
      await tapKey(tester, 'region.TW');
      final historical = FixtureEngine.profile(
        'tw-id',
      ).addressCodes.where((entry) => !entry.current).toList();
      expect(historical.length, 4);
      await tapKey(tester, 'address.select');
      for (final entry in historical) {
        expect(
          find.byKey(ValueKey('address.code.${entry.code}')),
          findsNothing,
        );
      }
      await tapKey(tester, 'address.history');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('address.confirm')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'address.code.${historical.first.code}');
      await tapKey(tester, 'address.current');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('address.confirm')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'address.history');
      await tapKey(tester, 'address.code.${historical.first.code}');
      await tapKey(tester, 'address.confirm');
      expect(selectionValue(tester, 'address.select'), contains('历史'));
      await tapKey(tester, 'generate.button');
      final package = await exportedPackage(tester, services);
      expect((package['config'] as Map)['allowHistorical'], isTrue);
      expect(caseValue(tester).startsWith(historical.first.code), isTrue);
      await tapKey(tester, 'address.select');
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('address.history')))
            .selected,
        isTrue,
      );
      await tapKey(tester, 'address.cancel');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Vietnam current province filters historical codes without fabricating a prefix',
    (tester) async {
      final services = FakeServices();
      await launch(
        tester,
        settings: await settingsForTest(),
        services: services,
      );
      await tapKey(tester, 'country.VN');
      await tapKey(tester, 'address.select');
      await tester.enterText(
        find.byKey(const ValueKey('address.search')),
        'Bắc Ninh',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'address.group.24');
      expect(find.byKey(const ValueKey('address.code.024')), findsOneWidget);
      expect(find.byKey(const ValueKey('address.code.027')), findsOneWidget);
      expect(find.byKey(const ValueKey('address.code.001')), findsNothing);
      await tapKey(tester, 'address.code.024');
      await tapKey(tester, 'address.confirm');
      await tapKey(tester, 'generate.button');
      expect(caseValue(tester).startsWith('024'), isTrue);
      final package = await exportedPackage(tester, services);
      expect((package['config'] as Map)['currentProvinceAdminCode'], '24');
      expect((package['config'] as Map)['addressCode'], '024');
      await tapKey(tester, 'address.select');
      await tapKey(tester, 'address.group.01');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('address.confirm')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'address.cancel');
      expect(caseValue(tester).startsWith('024'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new and archived packages restore their own rule versions without upgrade',
    (tester) async {
      final services = FakeServices()
        ..nextPackage = packageFor(profileId: 'cn-id-demo');
      await launch(
        tester,
        settings: await settingsForTest(),
        services: services,
      );
      await tapKey(tester, 'package.open');
      await tapKey(tester, 'package.confirm');
      expect(find.byKey(const ValueKey('profile.archived')), findsOneWidget);
      final old = caseValue(tester);
      await tapKey(tester, 'generate.button');
      expect(caseValue(tester), old);
      var package = await exportedPackage(tester, services);
      expect(package['profileId'], 'cn-id-demo');
      expect(package['engineVersion'], '1.0.0');
      await tapKey(tester, 'address.select');
      expect(find.byKey(const ValueKey('address.group.110000')), findsNothing);
      await tapKey(tester, 'address.code.110105');
      await tapKey(tester, 'address.confirm');
      await tapKey(tester, 'generate.button');
      expect(caseValue(tester).startsWith('110105'), isTrue);
      await tapKey(tester, 'region.HK');
      expect(find.byKey(const ValueKey('profile.archived')), findsNothing);
      services.nextPackage = packageFor(profileId: 'cn-id');
      await tapKey(tester, 'package.open');
      await tapKey(tester, 'package.confirm');
      package = await exportedPackage(tester, services);
      expect(package['profileId'], 'cn-id');
      expect(find.byKey(const ValueKey('profile.archived')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded profile packages restore exact parameters and regenerate consistently',
    (tester) async {
      final services = FakeServices();
      await launch(
        tester,
        settings: await settingsForTest(),
        services: services,
      );
      final historical = FixtureEngine.profile(
        'tw-id',
      ).addressCodes.firstWhere((entry) => !entry.current);
      final configurations = [
        {
          'profileId': 'vn-id',
          'birthDate': '2026-11-05',
          'sex': 'female',
          'addressCode': '024',
          'currentProvinceAdminCode': '24',
        },
        {
          'profileId': 'tw-id',
          'sex': 'female',
          'addressCode': historical.code,
          'allowHistorical': true,
        },
        {'profileId': 'hk-id', 'prefix': 'AB'},
        {'profileId': 'mo-id'},
        {
          'profileId': 'cn-id',
          'birthDate': '2026-11-05',
          'sex': 'male',
          'addressCode': '133100',
        },
      ];
      for (final configuration in configurations) {
        final original = FixtureEngine.createPackage(
          FixtureEngine.generate({
            ...configuration,
            'count': 2,
            'seed': ' replay-原字符 ',
            'mode': 'positive',
          }),
        );
        services.nextPackage = OpenedPackage(
          text: jsonEncode(original),
          name: 'expanded.json',
        );
        await tapKey(tester, 'package.open');
        await tapKey(tester, 'package.confirm');
        final before = caseValue(tester);
        await tapKey(tester, 'generate.button');
        expect(find.byKey(const ValueKey('form.error')), findsNothing);
        expect(caseValue(tester), before);
        final exported = await exportedPackage(tester, services);
        expect(exported['profileId'], original['profileId']);
        expect(exported['config'], original['config']);
        expect(exported['cases'], original['cases']);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Taiwan current prefix retains imported historical permission until area changes',
    (tester) async {
      final original = FixtureEngine.createPackage(
        FixtureEngine.generate({
          'profileId': 'tw-id',
          'addressCode': 'A',
          'allowHistorical': true,
          'sex': 'female',
          'count': 2,
          'seed': ' current-with-history ',
          'mode': 'positive',
        }),
      );
      final services = FakeServices()
        ..nextPackage = OpenedPackage(
          text: jsonEncode(original),
          name: 'current-with-history.json',
        );
      await launch(
        tester,
        settings: await settingsForTest(),
        services: services,
      );
      await tapKey(tester, 'package.open');
      await tapKey(tester, 'package.confirm');
      final imported = caseValue(tester);
      await tapKey(tester, 'address.select');
      await tapKey(tester, 'address.history');
      await tapKey(tester, 'address.cancel');
      expect(caseValue(tester), imported);
      await tapKey(tester, 'address.select');
      await tapKey(tester, 'address.confirm');
      await tapKey(tester, 'generate.button');
      var exported = await exportedPackage(tester, services);
      expect(exported['config'], original['config']);
      expect(exported['cases'], original['cases']);
      await tapKey(tester, 'address.select');
      await searchAddress(tester, 'B');
      await tapKey(tester, 'generate.button');
      exported = await exportedPackage(tester, services);
      expect((exported['config'] as Map)['addressCode'], 'B');
      expect((exported['config'] as Map)['allowHistorical'], isFalse);
      await tapKey(tester, 'region.HK');
      await tapKey(tester, 'region.TW');
      await tapKey(tester, 'generate.button');
      exported = await exportedPackage(tester, services);
      expect((exported['config'] as Map)['addressCode'], 'A');
      expect((exported['config'] as Map)['allowHistorical'], isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker handles dark English 320 width large text and a visible keyboard inset',
    (tester) async {
      final settings = await settingsForTest();
      await settings.setLanguage('en');
      await settings.setThemeMode(ThemeMode.dark);
      await launch(
        tester,
        settings: settings,
        services: FakeServices(),
        size: const Size(320, 740),
        textScale: 2,
      );
      await tapKey(tester, 'address.select');
      tester.view.viewInsets = const FakeViewPadding(bottom: 270);
      await tester.pumpAndSettle();
      addTearDown(tester.view.resetViewInsets);
      await tapKey(tester, 'address.search');
      await tester.enterText(
        find.byKey(const ValueKey('address.search')),
        '441900',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'address.code.441900');
      final confirm = find.byKey(const ValueKey('address.confirm'));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(470));
      await tapKey(tester, 'address.confirm');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(selectionValue(tester, 'address.select'), contains('441900'));
      await tapKey(tester, 'country.VN');
      await tapKey(tester, 'address.select');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'address.cancel');
      await tapKey(tester, 'country.CN');
      await tapKey(tester, 'region.TW');
      await tapKey(tester, 'address.select');
      await tapKey(tester, 'address.history');
      await tapKey(tester, 'address.cancel');
      expect(tester.takeException(), isNull);
    },
  );
}
