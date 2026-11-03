import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/app/app.dart';
import 'package:trip_cost/core/infrastructure/app_providers.dart';
import 'package:trip_cost/features/converter/presentation/home_page.dart';
import 'package:trip_cost/features/expense/presentation/ledger_page.dart';
import 'package:trip_cost/features/settings/presentation/settings_page.dart';
import 'package:trip_cost/features/startup/application/startup_controller.dart';
import 'package:trip_cost/features/startup/data/startup_state_store.dart';
import 'package:trip_cost/features/trip/presentation/trips_page.dart';

import 'helpers/isolated_test_database.dart';
import 'helpers/m4_fakes.dart';
import 'helpers/m5_fixtures.dart';

void main() {
  testWidgets('shows four destinations and a separate scan action', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.padding = const FakeViewPadding(bottom: 102);
    final database = createIsolatedTestDatabase();
    final rateRequests = FakeRateRequestCounter();
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          startupStateStoreProvider.overrideWithValue(
            _CompletedStartupStateStore(),
          ),
          rateRepositoryProvider.overrideWithValue(
            createFakeRateRepository(requestCounter: rateRequests),
          ),
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
          tripRepositoryProvider.overrideWithValue(
            MemoryTripRepository([
              fixtureTrip(
                startDate: now.subtract(const Duration(days: 1)),
                endDate: now.add(const Duration(days: 5)),
              ),
            ]),
          ),
          expenseRepositoryProvider.overrideWithValue(
            MemoryExpenseRepository(),
          ),
          feeCalibrationRepositoryProvider.overrideWithValue(
            MemoryFeeCalibrationRepository(),
          ),
          networkStatusProvider.overrideWithValue(
            const FakeNetworkStatusProvider(),
          ),
        ],
        child: const TripCostApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.viewfinder), findsOneWidget);
    expect(
      MediaQuery.paddingOf(tester.element(find.byType(HomePage))).bottom,
      0,
    );
    final navigationSafeArea = find.byWidgetPredicate(
      (widget) => widget is SafeArea && !widget.top,
    );
    expect(MediaQuery.paddingOf(tester.element(navigationSafeArea)).bottom, 34);
    expect(
      tester.widget<SafeArea>(navigationSafeArea).maintainBottomViewPadding,
      isTrue,
    );
    final navigationRect = tester.getRect(navigationSafeArea);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    expect(tester.getRect(navigationSafeArea), navigationRect);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pump();

    expect(find.byKey(const Key('converter-active-rate')), findsOneWidget);
    final inputLabelRect = tester.getRect(
      find.byKey(const Key('converter-input-label')),
    );
    final inputRect = tester.getRect(
      find.byKey(const Key('converter-expression')),
    );
    expect(inputRect.top - inputLabelRect.bottom, greaterThanOrEqualTo(8));

    final compareButtonRect = tester.getRect(
      find.byKey(const Key('compare-payment-button')),
    );
    final dccButtonRect = tester.getRect(find.byKey(const Key('dcc-button')));
    expect(compareButtonRect.height, dccButtonRect.height);

    final refreshButton = find.byKey(const Key('refresh-market-rate'));
    expect(refreshButton, findsOneWidget);
    final requestsBeforeRefresh = rateRequests.count;
    await tester.tap(refreshButton);
    await tester.pump();
    expect(rateRequests.count, requestsBeforeRefresh + 1);
    expect(tester.widget<CupertinoButton>(refreshButton).onPressed, isNull);
    await tester.tap(refreshButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 999));
    expect(rateRequests.count, requestsBeforeRefresh + 1);
    expect(tester.widget<CupertinoButton>(refreshButton).onPressed, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.widget<CupertinoButton>(refreshButton).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('adjust-rate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rate-selection-sheet')), findsOneWidget);
    expect(find.text('API reference rate'), findsWidgets);
    expect(find.text('Manual rate'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('manual-rate-field')), '0.05');
    await tester.pump();
    expect(find.byKey(const Key('manual-rate-comparison')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-manual-rate')));
    await tester.pumpAndSettle();
    expect(find.text('Manual rate'), findsOneWidget);

    await tester.tap(find.byKey(const Key('adjust-rate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('use-market-rate')));
    await tester.pumpAndSettle();
    expect(find.text('API reference rate'), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(
      MediaQuery.paddingOf(tester.element(find.byType(TripsPage))).bottom,
      0,
    );
    final tripList = find.ancestor(
      of: find.text('Tokyo week'),
      matching: find.byType(ListView),
    );
    final tripListSafeArea = tester.widget<SafeArea>(
      find.ancestor(of: tripList, matching: find.byType(SafeArea)),
    );
    expect(tripListSafeArea.bottom, isFalse);

    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
    expect(
      MediaQuery.paddingOf(tester.element(find.byType(LedgerPage))).bottom,
      0,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      MediaQuery.paddingOf(tester.element(find.byType(SettingsPage))).bottom,
      0,
    );

    await tester.tap(find.byIcon(CupertinoIcons.viewfinder));
    await tester.pumpAndSettle();
    expect(find.text('Scan'), findsWidgets);
  });
}

class _CompletedStartupStateStore implements StartupStateStore {
  @override
  Future<bool> isOnboardingComplete() async => true;

  @override
  Future<void> markOnboardingComplete() async {}

  @override
  Future<void> resetOnboarding() async {}
}
