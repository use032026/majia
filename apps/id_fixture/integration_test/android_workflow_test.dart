import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:id_fixture/domain/fixture_engine.dart';
import 'package:id_fixture/services/app_settings.dart';
import 'package:id_fixture/services/platform_services.dart';
import 'package:id_fixture/ui/app.dart';

late final IntegrationTestWidgetsFlutterBinding _binding;
final _completedChecks = <String>{};
final _ownedSettings = <AppSettings>[];

void _record(String check) {
  _completedChecks.add(check);
  _binding.reportData = <String, dynamic>{
    'suite': 'android_workflow_test',
    'platform': Platform.operatingSystem,
    'native_preference_store': true,
    'native_platform_services': true,
    'completed_checks': _completedChecks.toList(),
    'native_share_sheet_automated': false,
    'native_file_chooser_automated': false,
    'native_file_import_replay_automated': false,
    'note':
        'System share/file chooser and their replay path require the separate manual run. No fixture numbers are included in this report.',
  };
}

Future<void> _resetOnlyAppPreferences() async {
  final store = NativePreferenceStore();
  await store.remove(AppSettings.languageKey);
  await store.remove(AppSettings.themeKey);
  await store.remove(AppSettings.onboardingKey);
}

Future<AppSettings> _launchNative(
  WidgetTester tester, {
  bool completedOnboarding = true,
  String? language = 'zh',
  bool resetPreferences = true,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester);
  if (resetPreferences) await _resetOnlyAppPreferences();
  final settings = await AppSettings.load(store: NativePreferenceStore());
  _ownedSettings.add(settings);
  if (language != null) await settings.setLanguage(language);
  if (completedOnboarding) await settings.completeOnboarding();
  await tester.pumpWidget(
    IdFixtureApp(settings: settings, services: const NativePlatformServices()),
  );
  await _settle(tester);
  return settings;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    final scope = find.byKey(const ValueKey('address.results'));
    final scrollable = scope.evaluate().isNotEmpty
        ? find.descendant(of: scope, matching: find.byType(Scrollable)).first
        : find.byType(Scrollable).last;
    await tester.drag(scrollable, const Offset(0, 20000));
    await _settle(tester);
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: scrollable,
      maxScrolls: 150,
    );
    await _settle(tester);
  }
  await tester.ensureVisible(finder);
  await _settle(tester);
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
  await _settle(tester);
}

Future<void> _chooseText(WidgetTester tester, String label) async {
  final sheet = find.byType(CupertinoActionSheet);
  expect(sheet, findsOneWidget);
  final option = find.descendant(of: sheet, matching: find.text(label)).last;
  await tester.ensureVisible(option);
  await _settle(tester);
  expect(option.hitTestable(), findsOneWidget);
  await tester.tap(option);
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await _settle(tester);
  expect(finder.hitTestable(), findsOneWidget);
  // Let the real Android IME establish this client's connection before the
  // framework input injection. Commit through the field's configured action
  // before another input or sheet is opened; do not write its controller.
  await tester.tap(finder);
  await _settle(tester);
  await tester.enterText(finder, text);
  final field = tester.widget<TextField>(finder);
  await tester.testTextInput.receiveAction(
    field.textInputAction ?? TextInputAction.done,
  );
  await _settle(tester);
  _assertField(tester, key, text, 'after-enter');
}

void _assertField(
  WidgetTester tester,
  String key,
  String expected,
  String phase,
) {
  final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
  final actual = field.controller!.text;
  final diagnostic = key == 'count.input' ? actual : 'length:${actual.length}';
  debugPrint(
    'ANDROID_INPUT_DIAGNOSTIC $key $phase actual=$diagnostic matches=${actual == expected}',
  );
  expect(
    actual == expected,
    isTrue,
    reason: '$key did not retain entered text at $phase',
  );
}

String _value(WidgetTester tester, int index) => tester
    .widget<SelectableText>(find.byKey(ValueKey('case.value.$index')))
    .data!;

String _selectionValue(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? '')
    .join();

Future<void> _back(WidgetTester tester) async {
  final button = find.byType(BackButton).last;
  expect(button, findsOneWidget);
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await _settle(tester);
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    if (!Platform.isAndroid) {
      throw StateError(
        'This suite requires a real Android emulator/device target. '
        'Do not treat a host widget run as Android runtime evidence.',
      );
    }
  });

  tearDown(() async {
    await _binding.runAsync(() async {
      // Do not leave native text input focused when the next test starts.
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
    for (final settings in _ownedSettings) {
      settings.dispose();
    }
    _ownedSettings.clear();
  });

  tearDownAll(() async {
    // Leave only this QA app in a neutral returning-user state.
    final settings = await AppSettings.load(store: NativePreferenceStore());
    await settings.setLanguage(null);
    await settings.setThemeMode(ThemeMode.system);
    await settings.completeOnboarding();
    settings.dispose();
  });

  testWidgets(
    'native first run completes both introduction pages and reloads',
    (tester) async {
      final settings = await _launchNative(
        tester,
        completedOnboarding: false,
        language: null,
      );
      expect(settings.languageCode, isNull);
      expect(settings.themeMode, ThemeMode.system);
      expect(find.byKey(const ValueKey('onboarding.next')), findsOneWidget);
      final actualLocale = Localizations.localeOf(
        tester.element(find.byKey(const ValueKey('onboarding.next'))),
      );
      expect(
        actualLocale == resolveAppLocale(_binding.platformDispatcher.locale),
        isTrue,
      );
      await _tapKey(tester, 'onboarding.next');
      expect(find.byKey(const ValueKey('onboarding.complete')), findsOneWidget);
      await _tapKey(tester, 'onboarding.complete');
      expect(find.byKey(const ValueKey('settings.open')), findsOneWidget);
      final disk = NativePreferenceStore();
      expect(await disk.getBool(AppSettings.onboardingKey), isTrue);
      expect(await disk.getString(AppSettings.languageKey), isNull);
      expect(await disk.getString(AppSettings.themeKey), isNull);

      final reloaded = await _launchNative(
        tester,
        completedOnboarding: false,
        language: null,
        resetPreferences: false,
      );
      expect(reloaded.onboardingComplete, isTrue);
      expect(find.byKey(const ValueKey('onboarding.next')), findsNothing);
      expect(find.byKey(const ValueKey('settings.open')), findsOneWidget);
      expect(tester.takeException(), isNull);
      _record('onboarding_complete_and_native_preference_reload');
      _record(
        'initial_language_and_theme_follow_system_without_stored_override',
      );
    },
  );

  testWidgets('native first-run skip and settings replay preserve completion', (
    tester,
  ) async {
    final settings = await _launchNative(
      tester,
      completedOnboarding: false,
      language: null,
    );
    await _tapKey(tester, 'onboarding.skip');
    expect(settings.onboardingComplete, isTrue);
    expect(
      await NativePreferenceStore().getBool(AppSettings.onboardingKey),
      isTrue,
    );
    await _tapKey(tester, 'settings.open');
    await _tapKey(tester, 'settings.replay');
    await _tapKey(tester, 'onboarding.next');
    await _tapKey(tester, 'onboarding.complete');
    expect(find.byKey(const ValueKey('settings.replay')), findsOneWidget);
    expect(settings.onboardingComplete, isTrue);
    expect(
      await NativePreferenceStore().getBool(AppSettings.onboardingKey),
      isTrue,
    );
    await _tapKey(tester, 'settings.replay');
    await _tapKey(tester, 'onboarding.skip');
    expect(find.byKey(const ValueKey('settings.replay')), findsOneWidget);
    expect(tester.takeException(), isNull);
    _record('onboarding_skip_and_replay_do_not_reset_native_completion');
  });

  testWidgets(
    'native China workflow generates batches, failures and clipboard',
    (tester) async {
      await _launchNative(tester);
      await _tapKey(tester, 'address.select');
      await _enter(tester, 'address.search', '110105');
      await _tapKey(tester, 'address.code.110105');
      await _tapKey(tester, 'address.confirm');
      await _tapKey(tester, 'sex.select');
      await _chooseText(tester, '女');

      final originalDate = _selectionValue(tester, 'birthday.select');
      await _tapKey(tester, 'birthday.select');
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text('取消').last);
      await _settle(tester);
      expect(
        _selectionValue(tester, 'birthday.select') == originalDate,
        isTrue,
      );
      await _tapKey(tester, 'birthday.select');
      await tester.tap(find.text('完成').last);
      await _settle(tester);
      final date = _selectionValue(tester, 'birthday.select');

      const seed = ' Android-回归😀 ';
      await _enter(tester, 'count.input', '100');
      await _enter(tester, 'seed.input', seed);
      await _tapKey(tester, 'generate.button');
      final expected = FixtureEngine.generate({
        'profileId': 'cn-id',
        'count': 100,
        'seed': seed,
        'mode': 'positive',
        'birthDate': date,
        'sex': 'female',
        'addressCode': '110105',
      });
      expect(_value(tester, 0) == expected.cases.first.value, isTrue);
      expect(find.byType(SelectableText), findsNWidgets(5));
      await _tapKey(tester, 'cases.more');
      expect(find.byType(SelectableText), findsNWidgets(10));
      await _tapKey(tester, 'case.expand.0');
      expect(find.text('未知'), findsOneWidget);

      final beforeClipboard = await Clipboard.getData(Clipboard.kTextPlain);
      try {
        await _tapKey(tester, 'copy.all');
        final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        final expectedText = expected.cases
            .map((entry) => entry.value)
            .join('\n');
        expect(clipboard?.text == expectedText, isTrue);
        _record('native_clipboard_roundtrip_for_all_100_cases');
      } finally {
        await Clipboard.setData(
          ClipboardData(text: beforeClipboard?.text ?? ''),
        );
      }

      final previous = _value(tester, 0);
      await _tapKey(tester, 'generate.button');
      expect(_value(tester, 0) == previous, isTrue);
      final seedField = tester.widget<TextField>(
        find.byKey(const ValueKey('seed.input')),
      );
      expect(seedField.controller!.text == seed, isTrue);

      await _enter(tester, 'count.input', '0');
      await _tapKey(tester, 'generate.button');
      expect(find.byKey(const ValueKey('form.error')), findsOneWidget);
      await _enter(tester, 'count.input', '3');
      await _tapKey(tester, 'scenario.negative');
      _assertField(tester, 'count.input', '3', 'after-negative-selection');
      await _tapKey(tester, 'mutation.select');
      await _chooseText(tester, '校验位错误');
      _assertField(tester, 'count.input', '3', 'before-generate');
      await _tapKey(tester, 'generate.button');
      _assertField(tester, 'count.input', '3', 'after-generate');
      expect(find.byKey(const ValueKey('form.error')), findsNothing);
      expect(find.textContaining('预期不通过: 公开规则校验字符'), findsNWidgets(3));
      await _tapKey(tester, 'case.expand.0');
      expect(find.text('未通过'), findsOneWidget);
      expect(find.text('未知'), findsOneWidget);
      expect(find.byKey(const ValueKey('export.package')), findsOneWidget);
      expect(find.byKey(const ValueKey('package.open')), findsOneWidget);
      expect(tester.takeException(), isNull);
      _record('china_parameters_date_picker_cancel_and_reopen');
      _record('china_100_case_generation_and_incremental_results');
      _record('verbatim_unicode_seed_regeneration');
      _record('count_error_recovery_and_targeted_checksum_failure');
      _record('share_and_open_controls_present_not_native_sheet_acceptance');
    },
  );

  testWidgets('native US, Vietnam and rule navigation keep their scope clear', (
    tester,
  ) async {
    await _launchNative(tester);
    await _tapKey(tester, 'generate.button');
    expect(find.byKey(const ValueKey('case.value.0')), findsOneWidget);
    await _tapKey(tester, 'country.US');
    expect(find.byKey(const ValueKey('case.value.0')), findsNothing);
    await _tapKey(tester, 'generate.button');
    expect(find.byKey(const ValueKey('form.error')), findsOneWidget);
    await _tapKey(tester, 'state.select');
    await _chooseText(tester, '纽约州 · New York');
    await _tapKey(tester, 'generate.button');
    expect(RegExp(r'^\d{9}$').hasMatch(_value(tester, 0)), isTrue);
    expect(find.byKey(const ValueKey('form.error')), findsNothing);

    await _tapKey(tester, 'document.select');
    await _chooseText(tester, FixtureEngine.profile('us-passport-ng').nameZh);
    expect(find.byKey(const ValueKey('state.select')), findsNothing);
    await _tapKey(tester, 'generate.button');
    expect(RegExp(r'^[A-Z]\d{8}$').hasMatch(_value(tester, 0)), isTrue);
    await _tapKey(tester, 'case.expand.0');
    expect(find.text('未知'), findsOneWidget);

    await _tapKey(tester, 'country.VN');
    expect(find.byKey(const ValueKey('case.value.0')), findsNothing);
    await _tapKey(tester, 'address.select');
    await _enter(tester, 'address.search', 'Bắc Ninh');
    await _tapKey(tester, 'address.group.24');
    expect(find.byKey(const ValueKey('address.code.024')), findsOneWidget);
    expect(find.byKey(const ValueKey('address.code.027')), findsOneWidget);
    expect(find.byKey(const ValueKey('address.code.001')), findsNothing);
    await _tapKey(tester, 'address.code.027');
    await _tapKey(tester, 'address.confirm');
    await _tapKey(tester, 'generate.button');
    expect(RegExp(r'^027[0-9]{9}$').hasMatch(_value(tester, 0)), isTrue);
    await _tapKey(tester, 'rule.current');
    final vietnamLimits = find.text(
      FixtureEngine.profile('vn-id').limitationsZh,
    );
    await tester.ensureVisible(vietnamLimits);
    await _settle(tester);
    expect(vietnamLimits.hitTestable(), findsOneWidget);
    await _back(tester);
    await _tapKey(tester, 'rules.open');
    await _tapKey(tester, 'rule.cn-id');
    expect(find.text(FixtureEngine.profile('cn-id').version), findsOneWidget);
    expect(
      find.text(FixtureEngine.profile('cn-id').coverageZh),
      findsOneWidget,
    );
    await _back(tester);
    await _back(tester);
    expect(find.byKey(const ValueKey('settings.open')), findsOneWidget);
    expect(tester.takeException(), isNull);
    _record('new_york_state_required_and_error_recovered');
    _record('passport_format_and_upstream_result_invalidation');
    _record('vietnam_current_group_historical_code_and_limitations_visible');
    _record('rule_catalog_detail_and_back_navigation');
  });

  testWidgets(
    'native China region and address picker coverage expands without stale parameters',
    (tester) async {
      await _launchNative(tester);
      await _tapKey(tester, 'address.select');
      await _enter(tester, 'address.search', '133100');
      await _tapKey(tester, 'address.code.133100');
      await _tapKey(tester, 'address.cancel');
      expect(_selectionValue(tester, 'address.select'), contains('110101'));
      await _tapKey(tester, 'address.select');
      await _enter(tester, 'address.search', '441900');
      await _tapKey(tester, 'address.code.441900');
      await _tapKey(tester, 'address.confirm');
      await _tapKey(tester, 'generate.button');
      expect(_value(tester, 0).startsWith('441900'), isTrue);
      await _tapKey(tester, 'region.HK');
      expect(find.byKey(const ValueKey('case.value.0')), findsNothing);
      expect(find.byKey(const ValueKey('birthday.select')), findsNothing);
      expect(find.byKey(const ValueKey('sex.select')), findsNothing);
      await _enter(tester, 'prefix.input', 'AB');
      await _tapKey(tester, 'generate.button');
      expect(RegExp(r'^AB[0-9]{6}[0-9A]$').hasMatch(_value(tester, 0)), isTrue);
      await _tapKey(tester, 'region.MO');
      expect(find.byKey(const ValueKey('prefix.input')), findsNothing);
      expect(find.byKey(const ValueKey('address.select')), findsNothing);
      await _tapKey(tester, 'generate.button');
      expect(find.byKey(const ValueKey('form.error')), findsNothing);
      await _tapKey(tester, 'region.TW');
      expect(find.byKey(const ValueKey('birthday.select')), findsNothing);
      await _tapKey(tester, 'address.select');
      final oldPrefix = FixtureEngine.profile(
        'tw-id',
      ).addressCodes.firstWhere((entry) => !entry.current);
      expect(
        find.byKey(ValueKey('address.code.${oldPrefix.code}')),
        findsNothing,
      );
      await _tapKey(tester, 'address.history');
      await _tapKey(tester, 'address.code.${oldPrefix.code}');
      await _tapKey(tester, 'address.confirm');
      await _tapKey(tester, 'generate.button');
      expect(_value(tester, 0).startsWith(oldPrefix.code), isTrue);
      expect(_selectionValue(tester, 'address.select'), contains('历史'));
      await _tapKey(tester, 'region.mainland');
      expect(_selectionValue(tester, 'address.select'), contains('110101'));
      expect(tester.takeException(), isNull);
      _record('mainland_search_draft_cancel_and_city_reference_generation');
      _record(
        'china_four_regions_profile_parameters_and_historical_taiwan_prefix',
      );
    },
  );

  testWidgets('native preferences survive reload and return to system mode', (
    tester,
  ) async {
    final settings = await _launchNative(tester);
    await _tapKey(tester, 'settings.open');
    await _tapKey(tester, 'settings.language');
    await _chooseText(tester, '取消');
    await _tapKey(tester, 'settings.language');
    await _chooseText(tester, 'English');
    expect(find.text('Preferences'), findsOneWidget);
    expect(settings.languageCode, 'en');
    expect(
      await NativePreferenceStore().getString(AppSettings.languageKey),
      'en',
    );

    await _tapKey(tester, 'settings.theme');
    await _chooseText(tester, 'Dark');
    expect(settings.themeMode, ThemeMode.dark);
    expect(
      await NativePreferenceStore().getString(AppSettings.themeKey),
      'dark',
    );
    final reloaded = await _launchNative(
      tester,
      completedOnboarding: false,
      language: null,
      resetPreferences: false,
    );
    expect(reloaded.languageCode, 'en');
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.onboardingComplete, isTrue);
    await _tapKey(tester, 'settings.open');
    expect(find.text('Preferences'), findsOneWidget);
    await _tapKey(tester, 'settings.theme');
    await _chooseText(tester, 'Light');
    expect(reloaded.themeMode, ThemeMode.light);
    await _tapKey(tester, 'settings.theme');
    await _chooseText(tester, 'Follow system');
    expect(reloaded.themeMode, ThemeMode.system);
    expect(
      await NativePreferenceStore().getString(AppSettings.themeKey),
      isNull,
    );
    await _tapKey(tester, 'settings.language');
    await _chooseText(tester, 'Follow system');
    expect(reloaded.languageCode, isNull);
    expect(
      await NativePreferenceStore().getString(AppSettings.languageKey),
      isNull,
    );
    expect(tester.takeException(), isNull);
    _record('language_action_sheet_cancel_and_reopen');
    _record('english_dark_preferences_read_back_from_native_store');
    _record('app_widget_recreation_retains_native_preferences');
    _record('explicit_light_then_system_clears_theme_override');
    _record('system_language_clears_language_override');
  });
}
