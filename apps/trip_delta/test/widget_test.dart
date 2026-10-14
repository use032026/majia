import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/backup.dart';
import 'package:trip_delta/domain.dart';
import 'package:trip_delta/ios_overlays.dart';
import 'package:trip_delta/main.dart';
import 'package:trip_delta/onboarding.dart';
import 'package:trip_delta/review_share.dart';
import 'package:trip_delta/screens.dart';
import 'package:trip_delta/store.dart';
import 'package:trip_delta/strings.dart';

Future<void> tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new installation shows and completes three-page introduction', (
    tester,
  ) async {
    final store = MemoryStore()
      ..value = const AppData(language: 'en', onboardingComplete: false);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Give every trip a plan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Record as you go'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('See the difference'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(store.value.onboardingComplete, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('skip persists onboarding completion', (tester) async {
    final store = MemoryStore()
      ..value = const AppData(language: 'zh', onboardingComplete: false);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(store.value.onboardingComplete, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('failed onboarding save keeps introduction available', (
    tester,
  ) async {
    final store = FailingOnboardingStore();
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(store.value.onboardingComplete, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
      find.text('Save failed; existing records are unchanged. Please retry.'),
      findsOneWidget,
    );
  });

  testWidgets('compact trip card keeps overage and estimate warnings visible', (
    tester,
  ) async {
    final expense = Expense(
      id: 'estimate',
      title: 'Hotel',
      category: BudgetCategory.stay,
      amountMinor: 15000,
      currency: 'CNY',
      rate: 1,
      bookedMinor: 15000,
      recordedAt: DateTime.utc(2026, 9, 2),
    );
    final store = MemoryStore()
      ..value = AppData(
        language: 'en',
        trips: [
          sampleTrip().copyWith(expenses: [expense]),
        ],
      );
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Over plan'), findsOneWidget);
    expect(find.text('CNY 50.00'), findsOneWidget);
    expect(find.text('Estimated entries: 1'), findsOneWidget);
    expect(
      find.textContaining('Largest over-plan category: Stay'),
      findsOneWidget,
    );
  });

  testWidgets('current and history tabs separate trips and search history', (
    tester,
  ) async {
    Trip trip(
      String id,
      String title,
      TripStage stage, {
      String destination = '',
      DateTime? completedAt,
    }) {
      final base = sampleTrip(stage: stage);
      return Trip(
        id: id,
        title: title,
        destination: destination,
        baseCurrency: base.baseCurrency,
        budgets: base.budgets,
        stage: stage,
        createdAt: base.createdAt,
        completedAt: completedAt,
        expenses: const [],
      );
    }

    final active = trip('active', 'Kyoto', TripStage.active);
    final draft = trip('draft', 'Osaka', TripStage.draft);
    final older = trip(
      'older',
      'Paris',
      TripStage.completed,
      destination: 'France',
      completedAt: DateTime.utc(2026, 8, 1),
    );
    final newer = trip(
      'newer',
      'Rome',
      TripStage.completed,
      destination: 'Italy',
      completedAt: DateTime.utc(2026, 9, 1),
    );
    final store = MemoryStore()
      ..value = AppData(language: 'en', trips: [older, draft, newer, active]);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byKey(const Key('focus_trip')), findsOneWidget);
    expect(find.byKey(const Key('trip_draft')), findsOneWidget);
    expect(find.byKey(const Key('trip_older')), findsNothing);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus_trip')), findsNothing);
    expect(find.byKey(const Key('trip_active')), findsNothing);
    expect(find.byKey(const Key('trip_older')), findsOneWidget);
    expect(find.byKey(const Key('trip_newer')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('trip_newer'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('trip_older'))).dy),
    );

    await tester.enterText(find.byKey(const Key('history_search')), 'france');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_older')), findsOneWidget);
    expect(find.byKey(const Key('trip_newer')), findsNothing);
    await tester.tap(find.byKey(const Key('history_clear_search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_newer')), findsOneWidget);
    await tester.tap(find.text('Current'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus_trip')), findsOneWidget);
    expect(find.byKey(const Key('trip_older')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan choices and travel dates use Cupertino sheets', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('new_trip'));

    await tapVisible(tester, const Key('base_currency'));
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IosChoiceField<String>>(
            find.byKey(const Key('base_currency')),
          )
          .value,
      'USD',
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('trip_dates')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip_dates')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsOneWidget);
    final later = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 10)),
    );
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(later);
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(
      find.textContaining(
        '${later.year}-${later.month}-${later.day} — '
        '${later.year}-${later.month}-${later.day}',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expense date uses a Cupertino picker and cancel keeps its value',
    (tester) async {
      final store = MemoryStore()
        ..value = AppData(language: 'en', trips: [sampleTrip()]);
      await tester.pumpWidget(TripDeltaApp(store: store));
      await tester.pumpAndSettle();
      await tapVisible(tester, const Key('home_quick_expense'));
      await tapVisible(tester, const Key('expense_details_toggle'));
      final dateButton = find.byKey(const Key('expense_date'));
      await tester.scrollUntilVisible(
        dateButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final labelFinder = find.descendant(
        of: dateButton,
        matching: find.byType(Text),
      );
      final originalLabel = tester.widget<Text>(labelFinder.first).data;
      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(labelFinder.first).data, originalLabel);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expense details keep full help and a visible save action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(353, 759);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = MemoryStore()
      ..value = AppData(
        language: 'zh',
        trips: [sampleTrip(localCurrency: 'USD')],
      );
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('home_quick_expense'));
    await tapVisible(tester, const Key('expense_details_toggle'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense_note')),
      180,
      scrollable: find.byType(Scrollable).first,
    );

    final help = find.text(const L(true)('postedHelp'));
    expect(help, findsOneWidget);
    expect(tester.widget<Text>(help).maxLines, isNull);
    expect(find.byKey(const Key('save_expense')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping expense form blank space dismisses the keyboard', (
    tester,
  ) async {
    final store = MemoryStore()
      ..value = AppData(language: 'en', trips: [sampleTrip()]);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('home_quick_expense'));

    final amount = find.byKey(const Key('expense_amount'));
    await tester.tap(amount);
    await tester.enterText(amount, '12.34');
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tapAt(const Offset(8, 180));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.widget<TextFormField>(amount).controller!.text, '12.34');

    await tapVisible(tester, const Key('expense_details_toggle'));
    await tapVisible(tester, const Key('expense_note'));
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tapAt(const Offset(8, 180));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byType(ExpensePage), findsOneWidget);
  });

  testWidgets('first quick expense locks plan and home records the next one', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('new_trip'));
    await tester.enterText(find.byKey(const Key('trip_name')), 'Kyoto');
    await tester.enterText(
      find.byKey(const Key('trip_destination')),
      'Kyoto, Japan',
    );
    await tester.enterText(find.byKey(const Key('budget_stay')), '300.00');
    await tapVisible(tester, const Key('save_plan'));
    expect(find.byType(TripDetailPage), findsOneWidget);
    expect(store.value.trips.single.stage, TripStage.draft);
    await tapVisible(tester, const Key('add_expense'));
    await tester.enterText(find.byKey(const Key('expense_amount')), '350.00');
    await tapVisible(tester, const Key('category_stay'));
    await tapVisible(tester, const Key('save_expense'));
    final trip = store.value.trips.single;
    expect(trip.stage, TripStage.active);
    expect(trip.plannedMinor, 30000);
    expect(trip.spentMinor, 35000);
    expect(trip.expenses.single.title, isEmpty);
    expect(trip.expenses.single.settledMinor, 35000);
    expect(find.text('Edit plan'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('home_quick_expense'));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('category_stay')))
          .selected,
      isTrue,
    );
    await tester.enterText(find.byKey(const Key('expense_amount')), '10');
    await tapVisible(tester, const Key('save_expense'));
    expect(store.value.trips.single.expenses.length, 2);
    expect(store.value.trips.single.spentMinor, 36000);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'local currency and manual rate are reused, then posted amount replaces estimate',
    (tester) async {
      final store = MemoryStore()
        ..value = AppData(
          language: 'en',
          trips: [sampleTrip(localCurrency: 'JPY', stage: TripStage.draft)],
        );
      await tester.pumpWidget(TripDeltaApp(store: store));
      await tester.pumpAndSettle();
      await tapVisible(tester, const Key('home_quick_expense'));
      expect(
        tester
            .widget<IosChoiceField<String>>(
              find.byKey(const Key('expense_currency')),
            )
            .value,
        'JPY',
      );
      await tester.enterText(find.byKey(const Key('expense_amount')), '1000');
      await tester.enterText(find.byKey(const Key('expense_rate')), '0.05');
      await tapVisible(tester, const Key('save_expense'));
      expect(store.value.trips.single.estimatedCount, 1);
      expect(store.value.trips.single.spentMinor, 5000);
      await tapVisible(tester, const Key('home_quick_expense'));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('expense_rate')))
            .controller!
            .text,
        '0.05',
      );
      await tester.enterText(find.byKey(const Key('expense_amount')), '1200');
      await tapVisible(tester, const Key('save_expense'));
      expect(store.value.trips.single.estimatedCount, 2);
      expect(store.value.trips.single.spentMinor, 11000);
      final secondId = store.value.trips.single.expenses.last.id;
      await tapVisible(tester, const Key('focus_trip'));
      await tapVisible(tester, Key('expense_$secondId'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('expense_settled')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('expense_settled')), '55.00');
      await tapVisible(tester, const Key('save_expense'));
      expect(store.value.trips.single.expenses.last.bookedMinor, 6000);
      expect(store.value.trips.single.expenses.last.settledMinor, 5500);
      expect(store.value.trips.single.spentMinor, 10500);
      expect(store.value.trips.single.estimatedCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting first expense unlocks mistaken budget', (tester) async {
    final store = MemoryStore()
      ..value = AppData(
        language: 'en',
        trips: [sampleTrip(stage: TripStage.draft)],
      );
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('focus_trip'));
    await tapVisible(tester, const Key('add_expense'));
    await tester.enterText(find.byKey(const Key('expense_amount')), '20');
    await tapVisible(tester, const Key('save_expense'));
    final id = store.value.trips.single.expenses.single.id;
    await tapVisible(tester, Key('expense_$id'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense_title')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('expense_title')), 'Train');
    await tapVisible(tester, const Key('save_expense'));
    await tapVisible(tester, Key('expense_$id'));
    await tapVisible(tester, const Key('delete_expense'));
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(store.value.trips.single.stage, TripStage.draft);
    expect(store.value.trips.single.startedAt, isNull);
    expect(store.value.trips.single.expenses, isEmpty);
    await tester.scrollUntilVisible(
      find.text('Edit plan'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Edit plan'), findsOneWidget);
  });

  testWidgets('estimated expense must be confirmed before review', (
    tester,
  ) async {
    final store = MemoryStore()
      ..value = AppData(
        language: 'en',
        trips: [sampleTrip(localCurrency: 'JPY', stage: TripStage.draft)],
      );
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('home_quick_expense'));
    await tester.enterText(find.byKey(const Key('expense_amount')), '1000');
    await tester.enterText(find.byKey(const Key('expense_rate')), '0.05');
    await tapVisible(tester, const Key('save_expense'));
    final id = store.value.trips.single.expenses.single.id;
    await tapVisible(tester, const Key('focus_trip'));
    expect(store.value.trips.single.canComplete, isFalse);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('finish_trip')))
          .onPressed,
      isNull,
    );
    await tapVisible(tester, Key('settle_$id'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense_settled')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('expense_settled')), findsOneWidget);
    await tapVisible(tester, const Key('confirm_estimate'));
    await tapVisible(tester, const Key('save_expense'));
    expect(store.value.trips.single.canComplete, isTrue);
    final finish = find.byKey(const Key('finish_trip'));
    await tester.scrollUntilVisible(
      finish,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(finish);
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('save_review'));
    expect(store.value.trips.single.stage, TripStage.completed);
    expect(store.value.trips.single.estimatedCount, 0);
  });

  testWidgets('review shows drivers and can reuse the plan', (tester) async {
    final expense = Expense(
      id: 'e1',
      title: 'Hotel',
      category: BudgetCategory.stay,
      amountMinor: 12000,
      currency: 'CNY',
      rate: 1,
      bookedMinor: 12000,
      settledMinor: 12000,
      recordedAt: DateTime.utc(2026, 9, 1),
    );
    final trip = sampleTrip(
      stage: TripStage.active,
    ).copyWith(expenses: [expense]);
    final store = MemoryStore()..value = AppData(language: 'en', trips: [trip]);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('focus_trip'));
    await tapVisible(tester, const Key('finish_trip'));
    expect(find.text('A little over, a clearer picture'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hotel · CNY 120.00 · Posted amount'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hotel · CNY 120.00 · Posted amount'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('reflection')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('reflection')), 'Book earlier');
    await tapVisible(tester, const Key('save_review'));
    expect(store.value.trips.single.stage, TripStage.completed);
    expect(find.text('A little over, a clearer picture'), findsOneWidget);
    await tapVisible(tester, const Key('open_review_card'));
    expect(find.byType(ReviewCardSheet), findsOneWidget);
    expect(find.byKey(const Key('review_card_preview')), findsOneWidget);
    expect(find.text('Book earlier'), findsWidgets);
    expect(find.byKey(const Key('share_review_card')), findsOneWidget);
    expect(find.byKey(const Key('save_review_card')), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('repeat_plan'));
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.value.trips.length, 1);
    await tapVisible(tester, const Key('repeat_plan'));
    await tester.tap(find.byKey(const Key('reuse_actual')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanPage), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('budget_stay')))
          .controller!
          .text,
      '120.00',
    );
    expect(store.value.trips.length, 1);
    await tapVisible(tester, const Key('save_plan'));
    expect(store.value.trips.length, 2);
    expect(store.value.trips.first.stage, TripStage.draft);
    expect(store.value.trips.first.plannedMinor, trip.spentMinor);
    expect(store.value.trips.first.expenses, isEmpty);
  });

  testWidgets('review card renders a PNG for saving and sharing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final trip = sampleTrip(stage: TripStage.completed).copyWith(
      completedAt: DateTime.utc(2026, 10, 14),
      reflection: 'Book earlier next time',
    );
    Uint8List? saved;
    Uint8List? shared;
    Rect? shareOrigin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewCardSheet(
            trip: trip,
            l: const L(false),
            saveImage: (bytes) async {
              saved = bytes;
            },
            shareImage: (bytes, origin) async {
              shared = bytes;
              shareOrigin = origin;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_review_card')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(find.text('Saved to Photos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share_review_card')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    expect(shared, isNotNull);
    expect(shared!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(shareOrigin, isNotNull);
    expect(shareOrigin!.size.isEmpty, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid backup leaves data intact and valid merge adds new trip',
    (tester) async {
      final store = MemoryStore()
        ..value = AppData(language: 'en', trips: [sampleTrip()]);
      final gateway = FakeBackupGateway()..picked = Uint8List.fromList([1, 2]);
      await tester.pumpWidget(
        TripDeltaApp(store: store, backupGateway: gateway),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup_open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup_import')));
      await tester.pumpAndSettle();
      expect(store.value.trips.single.id, 'trip1');
      expect(find.textContaining('Import failed'), findsOneWidget);

      final newTrip = sampleTrip().copyWith(title: 'Osaka');
      gateway.picked = TripBackupCodec.encode(
        AppData(
          language: 'zh',
          trips: [
            Trip(
              id: 'trip2',
              title: newTrip.title,
              baseCurrency: newTrip.baseCurrency,
              budgets: newTrip.budgets,
              stage: newTrip.stage,
              createdAt: newTrip.createdAt,
              expenses: const [],
            ),
          ],
        ),
      );
      await tester.tap(find.byKey(const Key('backup_import')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('backup_merge')));
      await tester.pumpAndSettle();
      expect(store.value.trips.length, 2);
      expect(store.value.language, 'en');
      await tester.tap(find.byKey(const Key('backup_export')));
      await tester.pumpAndSettle();
      expect(TripBackupCodec.decode(gateway.saved!).trips.length, 2);

      gateway.picked = TripBackupCodec.encode(const AppData(language: 'zh'));
      await tester.tap(find.byKey(const Key('backup_import')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup_replace')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(store.value.trips.length, 2);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.value.trips.length, 2);
      await tester.tap(find.byKey(const Key('backup_import')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup_replace')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup_confirm_replace')));
      await tester.pumpAndSettle();
      expect(store.value.trips, isEmpty);
      expect(store.value.language, 'zh');
    },
  );

  testWidgets('ledger category filter narrows entries and can be cleared', (
    tester,
  ) async {
    Expense entry(String id, BudgetCategory category) => Expense(
      id: id,
      title: id,
      category: category,
      amountMinor: 1000,
      currency: 'CNY',
      rate: 1,
      bookedMinor: 1000,
      settledMinor: 1000,
      recordedAt: DateTime.utc(2026, 9, 2),
    );
    final trip = sampleTrip().copyWith(
      expenses: [
        entry('stay-entry', BudgetCategory.stay),
        entry('food-entry', BudgetCategory.food),
      ],
    );
    final store = MemoryStore()..value = AppData(language: 'en', trips: [trip]);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('focus_trip'));
    await tapVisible(tester, const Key('open_expenses'));
    final allFilter = find.byKey(const Key('ledger_category_all'));
    await tester.tap(allFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense_food-entry')), findsOneWidget);
    expect(find.byKey(const Key('expense_stay-entry')), findsNothing);
    await tester.tap(find.byKey(const Key('ledger_clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense_stay-entry')), findsOneWidget);
  });

  testWidgets('detail keeps three recent entries and links to full records', (
    tester,
  ) async {
    final expenses = List.generate(
      6,
      (index) => Expense(
        id: 'entry-$index',
        title: 'Entry $index',
        category: index.isEven ? BudgetCategory.food : BudgetCategory.stay,
        amountMinor: 1000,
        currency: 'CNY',
        rate: 1,
        bookedMinor: 1000,
        settledMinor: 1000,
        recordedAt: DateTime.utc(2026, 9, index + 1),
      ),
    );
    final trip = sampleTrip().copyWith(expenses: expenses);
    final store = MemoryStore()..value = AppData(language: 'en', trips: [trip]);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('focus_trip'));

    expect(find.byKey(const Key('expense_entry-5')), findsOneWidget);
    expect(find.byKey(const Key('ledger_category_all')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense_entry-3')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('expense_entry-2')), findsNothing);
    expect(find.byKey(const Key('expense_entry-0')), findsNothing);

    await tapVisible(tester, const Key('open_budget_breakdown'));
    expect(find.byType(ComparisonSection), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, const Key('open_expenses'));
    expect(find.byType(ExpenseListPage), findsOneWidget);
    expect(find.byKey(const Key('ledger_category_all')), findsOneWidget);
    expect(find.text('Expenses recorded: 6 / 6'), findsOneWidget);
    final list = find.byType(ListView).last;
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense_entry-0')),
      200,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(find.byKey(const Key('expense_entry-0')), findsOneWidget);
  });

  testWidgets('pending shortcut opens the ledger with estimates filtered', (
    tester,
  ) async {
    Expense entry(String id, {required bool settled}) => Expense(
      id: id,
      title: id,
      category: BudgetCategory.food,
      amountMinor: 1000,
      currency: 'CNY',
      rate: 1,
      bookedMinor: 1000,
      settledMinor: settled ? 1000 : null,
      recordedAt: DateTime.utc(2026, 9, 2),
    );
    final trip = sampleTrip().copyWith(
      expenses: [
        entry('pending-1', settled: false),
        entry('posted', settled: true),
        entry('pending-2', settled: false),
      ],
    );
    final store = MemoryStore()..value = AppData(language: 'en', trips: [trip]);
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('focus_trip'));
    await tapVisible(tester, const Key('view_pending_expenses'));

    expect(find.byType(ExpenseListPage), findsOneWidget);
    expect(find.text('Expenses recorded: 2 / 3'), findsOneWidget);
    expect(find.byKey(const Key('expense_pending-2')), findsOneWidget);
    expect(find.byKey(const Key('expense_posted')), findsNothing);
    await tester.tap(find.byKey(const Key('ledger_clear')));
    await tester.pumpAndSettle();
    expect(find.text('Expenses recorded: 3 / 3'), findsOneWidget);
    expect(find.byKey(const Key('expense_posted')), findsOneWidget);
  });

  testWidgets('cancelled plan discards input', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('new_trip'));
    await tester.enterText(find.byKey(const Key('trip_name')), 'Discard me');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.value.trips, isEmpty);
    await tapVisible(tester, const Key('new_trip'));
    expect(find.text('Discard me'), findsNothing);
  });

  testWidgets('failed save retains plan for retry', (tester) async {
    final store = DelayedFailStore();
    await tester.pumpWidget(TripDeltaApp(store: store));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('new_trip'));
    await tester.enterText(
      find.byKey(const Key('trip_name')),
      'Keep this input',
    );
    await tester.enterText(find.byKey(const Key('budget_stay')), '100');
    final save = find.byKey(const Key('save_plan'));
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    store.pending.completeError(StateError('disk failed'));
    await tester.pumpAndSettle();
    expect(store.value.trips, isEmpty);
    await tester.scrollUntilVisible(
      find.byKey(const Key('trip_name')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('trip_name')))
          .controller!
          .text,
      'Keep this input',
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('save_plan'));
    expect(store.value.trips.single.title, 'Keep this input');
  });
}

Trip sampleTrip({String? localCurrency, TripStage stage = TripStage.active}) =>
    Trip(
      id: 'trip1',
      title: 'Kyoto',
      destination: 'Kyoto, Japan',
      baseCurrency: 'CNY',
      localCurrency: localCurrency,
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 5),
      budgets: {
        BudgetCategory.stay: 10000,
        BudgetCategory.transport: 0,
        BudgetCategory.food: 0,
        BudgetCategory.experiences: 0,
        BudgetCategory.other: 0,
      },
      stage: stage,
      createdAt: DateTime.utc(2026, 9, 1),
      expenses: const [],
    );

class MemoryStore implements TripStore {
  AppData value = const AppData(language: 'en');
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData data) async {
    value = data;
  }
}

class DelayedFailStore extends MemoryStore {
  final Completer<void> pending = Completer<void>();
  bool first = true;
  @override
  Future<void> save(AppData data) async {
    if (first) {
      first = false;
      await pending.future;
    }
    await super.save(data);
  }
}

class FailingOnboardingStore extends MemoryStore {
  FailingOnboardingStore() {
    value = const AppData(language: 'en', onboardingComplete: false);
  }

  @override
  Future<void> save(AppData data) async => throw StateError('disk full');
}

class FakeBackupGateway implements BackupGateway {
  Uint8List? picked;
  Uint8List? saved;

  @override
  Future<Uint8List?> pick() async => picked;

  @override
  Future<bool> save(String name, Uint8List bytes) async {
    saved = bytes;
    return true;
  }
}
