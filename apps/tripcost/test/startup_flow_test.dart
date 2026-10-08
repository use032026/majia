import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/app/app.dart';
import 'package:trip_cost/app/locale_controller.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/domain/repositories.dart';
import 'package:trip_cost/core/infrastructure/app_providers.dart';
import 'package:trip_cost/core/money/currency.dart';
import 'package:trip_cost/features/startup/application/startup_controller.dart';
import 'package:trip_cost/features/startup/data/startup_state_store.dart';

import 'helpers/isolated_test_database.dart';
import 'helpers/m4_fakes.dart';

void main() {
  testWidgets('first launch opens onboarding and completion enters home', (
    tester,
  ) async {
    final store = _FakeStartupStateStore();
    final settings = MemorySettingsRepository();

    await tester.pumpWidget(_testApp(store, settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Understand prices instantly'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(store.isComplete, isTrue);
    expect(settings.value?.defaultCurrency.code, 'USD');
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Understand the real cost'), findsWidgets);
  });

  testWidgets('returning user goes directly to home', (tester) async {
    final store = _FakeStartupStateStore(isComplete: true);

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('local preference read failure falls back to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(_ThrowingStartupStateStore()));
    await tester.pumpAndSettle();

    expect(find.text('Understand prices instantly'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('three onboarding pages continue to quick setup before home', (
    tester,
  ) async {
    final store = _FakeStartupStateStore();

    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);
    expect(find.text('Quick setup'), findsOneWidget);
    expect(find.text('Home currency'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Payment methods'), findsOneWidget);
    expect(store.isComplete, isFalse);

    await tester.tap(find.text('Enter home'));
    await tester.pumpAndSettle();
    expect(store.isComplete, isTrue);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Continue setup'), findsOneWidget);
  });

  testWidgets('quick setup header stays below the navigation bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp(_FakeStartupStateStore()));
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);

    final navigationBarBottom = tester
        .getBottomLeft(find.byType(CupertinoNavigationBar))
        .dy;
    final subtitleTop = tester
        .getTopLeft(
          find.text(
            'Takes about a minute. You can add a trip and payment methods later.',
          ),
        )
        .dy;

    expect(subtitleTop, greaterThanOrEqualTo(navigationBarBottom));
  });

  testWidgets('trip creation can be cancelled back to quick setup', (
    tester,
  ) async {
    final store = _FakeStartupStateStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);
    await tester.tap(find.byKey(const Key('quick-setup-trip')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('trip-editor-redesigned-list')),
      findsOneWidget,
    );
    expect(find.text('New trip'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Quick setup'), findsOneWidget);
    expect(find.byKey(const Key('trip-editor-redesigned-list')), findsNothing);
    expect(store.isComplete, isFalse);
  });

  testWidgets('payment setup can be cancelled back to quick setup', (
    tester,
  ) async {
    final store = _FakeStartupStateStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);
    await tester.tap(find.byKey(const Key('quick-setup-payment')));
    await tester.pumpAndSettle();

    expect(find.text('Add payment method'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Quick setup'), findsOneWidget);
    expect(store.isComplete, isFalse);
  });

  testWidgets('saved payment method returns to quick setup with progress', (
    tester,
  ) async {
    final store = _FakeStartupStateStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);
    await tester.tap(find.byKey(const Key('quick-setup-payment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Travel Visa',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Quick setup'), findsOneWidget);
    expect(find.text('1 methods added'), findsOneWidget);
    expect(find.text('2 of 3 complete'), findsOneWidget);
    expect(store.isComplete, isFalse);
  });

  testWidgets('home setup prompt reopens setup and can be dismissed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp(_FakeStartupStateStore()));
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);
    await tester.tap(find.byKey(const Key('quick-setup-finish')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick-setup-prompt-continue')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('quick-setup-prompt-continue')),
    );
    await tester.tap(find.byKey(const Key('quick-setup-prompt-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Quick setup'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('quick-setup-prompt-dismiss')),
    );
    await tester.tap(find.byKey(const Key('quick-setup-prompt-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-setup-prompt-continue')), findsNothing);
  });

  testWidgets('rapid save taps create only one onboarding trip', (
    tester,
  ) async {
    final trips = MemoryTripRepository();
    await tester.pumpWidget(
      _testApp(_FakeStartupStateStore(), tripRepository: trips),
    );
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);
    await tester.tap(find.byKey(const Key('quick-setup-trip')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField).first, '001');
    await _selectJapanDestination(tester);
    final saveButton = tester.widget<CupertinoButton>(
      find.byKey(const Key('trip-editor-submit-button')),
    );
    saveButton.onPressed!();
    saveButton.onPressed!();
    await tester.pumpAndSettle();

    expect(trips.values, hasLength(1));
    expect(trips.values.single.name, '001');
    expect(trips.values.single.homeCurrency.code, 'USD');
    expect(find.byKey(const Key('trip-editor-redesigned-list')), findsNothing);
    expect(find.text('Quick setup'), findsOneWidget);
    expect(find.text('001'), findsOneWidget);
  });

  testWidgets('retry after a partial save reuses the same trip record', (
    tester,
  ) async {
    final trips = _SaveThenThrowOnceTripRepository();
    await tester.pumpWidget(
      _testApp(_FakeStartupStateStore(), tripRepository: trips),
    );
    await tester.pumpAndSettle();

    await _openQuickSetup(tester);
    await tester.tap(find.byKey(const Key('quick-setup-trip')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField).first, '001');
    await _selectJapanDestination(tester);
    tester
        .widget<CupertinoButton>(
          find.byKey(const Key('trip-editor-submit-button')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('trip-editor-redesigned-list')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('trip-editor-submit-button')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('trip-editor-redesigned-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    tester
        .widget<CupertinoButton>(
          find.byKey(const Key('trip-editor-submit-button')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(trips.values, hasLength(1));
    expect(trips.values.single.name, '001');
    expect(find.byKey(const Key('trip-editor-redesigned-list')), findsNothing);
    expect(find.text('Quick setup'), findsOneWidget);
    expect(find.text('001'), findsOneWidget);
  });

  testWidgets('first launch follows a Chinese device locale', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(_testApp(_FakeStartupStateStore()));
    await tester.pumpAndSettle();

    expect(find.text('快速看懂当地价格'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('比较不同支付成本'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('持续掌握旅行预算'), findsOneWidget);
    expect(find.text('开始设置'), findsOneWidget);
    expect(find.text('建议本位币'), findsNothing);
    expect(find.text('创建行程'), findsNothing);
    expect(find.text('添加支付方式'), findsNothing);

    await tester.tap(find.text('开始设置'));
    await tester.pumpAndSettle();
    expect(find.text('快速设置'), findsOneWidget);
    expect(find.text('本位币'), findsOneWidget);
    expect(find.text('建议本位币'), findsNothing);
    expect(find.text('行程'), findsOneWidget);
    expect(find.text('支付方式'), findsOneWidget);
    expect(find.text('进入首页'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-setup-currency')));
    await tester.pumpAndSettle();
    for (final currency in CurrencyCatalog.knownCurrencies) {
      expect(find.textContaining(currency.name), findsNothing);
    }
  });

  testWidgets('persisted Chinese ignores an English device locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('en', 'US'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      _testApp(
        _FakeStartupStateStore(),
        initialLanguageMode: AppLanguageMode.simplifiedChinese,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('快速看懂当地价格'), findsOneWidget);
    expect(find.text('Understand prices instantly'), findsNothing);
  });

  testWidgets('persisted English ignores a Chinese device locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      _testApp(
        _FakeStartupStateStore(),
        initialLanguageMode: AppLanguageMode.english,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Understand prices instantly'), findsOneWidget);
    expect(find.text('快速看懂当地价格'), findsNothing);
  });
}

Future<void> _openQuickSetup(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  expect(find.text('Compare the cost to pay'), findsOneWidget);

  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  expect(find.text('Keep every trip on budget'), findsOneWidget);
  expect(find.text('Start setup'), findsOneWidget);

  await tester.tap(find.text('Start setup'));
  await tester.pumpAndSettle();
  expect(find.text('Quick setup'), findsOneWidget);
}

Future<void> _selectJapanDestination(WidgetTester tester) async {
  await tester.tap(find.text('Add next stop'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('country-search-field')),
    'Japan',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('country-option-JP')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CupertinoButton, 'Done'));
  await tester.pumpAndSettle();
}

Widget _testApp(
  StartupStateStore store, {
  MemorySettingsRepository? settings,
  TripRepository? tripRepository,
  AppLanguageMode initialLanguageMode = AppLanguageMode.system,
}) {
  final database = createIsolatedTestDatabase();
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      initialAppLanguageModeProvider.overrideWithValue(initialLanguageMode),
      startupStateStoreProvider.overrideWithValue(store),
      rateRepositoryProvider.overrideWithValue(createFakeRateRepository()),
      settingsRepositoryProvider.overrideWithValue(
        settings ?? MemorySettingsRepository(),
      ),
      tripRepositoryProvider.overrideWithValue(
        tripRepository ?? MemoryTripRepository(),
      ),
      expenseRepositoryProvider.overrideWithValue(MemoryExpenseRepository()),
      feeCalibrationRepositoryProvider.overrideWithValue(
        MemoryFeeCalibrationRepository(),
      ),
      networkStatusProvider.overrideWithValue(
        const FakeNetworkStatusProvider(),
      ),
    ],
    child: const TripCostApp(),
  );
}

class _FakeStartupStateStore implements StartupStateStore {
  _FakeStartupStateStore({this.isComplete = false});

  bool isComplete;

  @override
  Future<bool> isOnboardingComplete() async => isComplete;

  @override
  Future<void> markOnboardingComplete() async {
    isComplete = true;
  }

  @override
  Future<void> resetOnboarding() async {
    isComplete = false;
  }
}

class _ThrowingStartupStateStore implements StartupStateStore {
  @override
  Future<bool> isOnboardingComplete() {
    throw StateError('preference store unavailable');
  }

  @override
  Future<void> markOnboardingComplete() async {}

  @override
  Future<void> resetOnboarding() async {}
}

final class _SaveThenThrowOnceTripRepository implements TripRepository {
  final _delegate = MemoryTripRepository();
  bool _shouldThrow = true;

  List<TripModel> get values => _delegate.values;

  @override
  Future<TripModel?> findById(String id) => _delegate.findById(id);

  @override
  Future<List<TripModel>> listActive() => _delegate.listActive();

  @override
  Future<void> save(TripModel trip) async {
    await _delegate.save(trip);
    if (_shouldThrow) {
      _shouldThrow = false;
      throw StateError('simulated post-write failure');
    }
  }

  @override
  Future<void> softDelete(String id, DateTime deletedAtUtc) =>
      _delegate.softDelete(id, deletedAtUtc);
}
