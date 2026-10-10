import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_cost/app/app.dart';
import 'package:trip_cost/app/locale_controller.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/infrastructure/app_providers.dart';
import 'package:trip_cost/core/money/currency.dart';
import 'package:trip_cost/core/money/decimal_value.dart';
import 'package:trip_cost/core/money/money.dart';
import 'package:trip_cost/core/storage/database/app_database.dart'
    hide Currency;
import 'package:trip_cost/features/startup/application/startup_controller.dart';
import 'package:trip_cost/features/startup/data/startup_state_store.dart';

import '../test/helpers/m4_fakes.dart';

/// Android-runtime preview entrypoint used only to capture Google Play assets.
///
/// It renders the shipping app UI with deterministic, fictional sample data and
/// keeps all repositories in memory. Run it with:
///
///   flutter run -d android-device -t tool/google_play_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase.inMemory();
  final preview = _PreviewData.create();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        startupStateStoreProvider.overrideWithValue(
          const _CompletedStartupStateStore(),
        ),
        initialAppLanguageModeProvider.overrideWithValue(
          AppLanguageMode.english,
        ),
        systemLocaleProvider.overrideWithValue(const Locale('en', 'US')),
        rateRepositoryProvider.overrideWithValue(
          createFakeRateRepository(
            now: DateTime.utc(2026, 10, 10, 8),
            rate: '0.047840625',
          ),
        ),
        settingsRepositoryProvider.overrideWithValue(
          MemorySettingsRepository(preview.settings),
        ),
        paymentMethodRepositoryProvider.overrideWithValue(
          MemoryPaymentMethodRepository(preview.paymentMethods),
        ),
        tripRepositoryProvider.overrideWithValue(
          MemoryTripRepository(<TripModel>[preview.trip]),
        ),
        expenseRepositoryProvider.overrideWithValue(
          MemoryExpenseRepository(preview.expenses),
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
}

final class _PreviewData {
  const _PreviewData({
    required this.settings,
    required this.paymentMethods,
    required this.trip,
    required this.expenses,
  });

  factory _PreviewData.create() {
    final catalog = CurrencyCatalog();
    final cny = catalog.resolve('CNY');
    final jpy = catalog.resolve('JPY');
    final krw = catalog.resolve('KRW');
    final today = DateTime.utc(2026, 10, 10);
    final tripStart = today.subtract(const Duration(days: 3));
    final tripEnd = today.add(const Duration(days: 4));
    final travelRewards = _paymentMethod(
      id: 'travel-rewards',
      name: 'Travel Rewards',
      currency: cny,
      foreignFee: '0',
      rateMarkup: '0.2',
      cashback: '1.5',
      createdAt: today.subtract(const Duration(days: 60)),
    );
    final everydayCard = _paymentMethod(
      id: 'everyday-card',
      name: 'Everyday Card',
      currency: cny,
      foreignFee: '3',
      rateMarkup: '0.5',
      cashback: '0.5',
      createdAt: today.subtract(const Duration(days: 40)),
    );
    final trip = TripModel(
      metadata: _metadata('tokyo-seoul', today),
      name: 'Tokyo & Seoul',
      destinationCodes: const <String>['JP', 'KR'],
      startDate: tripStart,
      endDate: tripEnd,
      stops: <TripStopModel>[
        TripStopModel(
          countryCode: 'JP',
          startDate: tripStart,
          endDate: today,
          localCurrency: jpy,
        ),
        TripStopModel(
          countryCode: 'KR',
          startDate: today.add(const Duration(days: 1)),
          endDate: tripEnd,
          localCurrency: krw,
        ),
      ],
      homeCurrency: cny,
      localCurrencies: <Currency>[jpy, krw],
      totalBudget: Money.parse('3200', cny),
      participantCount: 2,
      defaultPaymentMethodId: travelRewards.metadata.recordId,
      offlinePackUpdatedAt: today.subtract(const Duration(days: 2)),
      status: TripStatus.active,
      createdAt: today.subtract(const Duration(days: 90)),
    );
    final expenses = <ExpenseModel>[
      _expense(
        id: 'hotel',
        title: 'Shinjuku hotel',
        category: 'hotel',
        localAmount: '94000',
        referenceAmount: '640.00',
        occurredAt: today.subtract(const Duration(days: 3)),
        cny: cny,
        jpy: jpy,
        method: travelRewards,
      ),
      _expense(
        id: 'sushi',
        title: 'Sushi dinner',
        category: 'food',
        localAmount: '12800',
        referenceAmount: '86.40',
        occurredAt: today.subtract(const Duration(days: 2)),
        cny: cny,
        jpy: jpy,
        method: travelRewards,
      ),
      _expense(
        id: 'train',
        title: 'Shinkansen tickets',
        category: 'transport',
        localAmount: '31800',
        referenceAmount: '214.20',
        occurredAt: today.subtract(const Duration(days: 1)),
        cny: cny,
        jpy: jpy,
        method: everydayCard,
      ),
      _expense(
        id: 'museum',
        title: 'Museum passes',
        category: 'tickets',
        localAmount: '7800',
        referenceAmount: '52.65',
        occurredAt: today.subtract(const Duration(hours: 6)),
        cny: cny,
        jpy: jpy,
        method: travelRewards,
      ),
      _expense(
        id: 'gifts',
        title: 'Gifts',
        category: 'shopping',
        localAmount: '17500',
        referenceAmount: '118.10',
        occurredAt: today.subtract(const Duration(hours: 1)),
        cny: cny,
        jpy: jpy,
        method: everydayCard,
      ),
    ];

    return _PreviewData(
      settings: UserSettingsModel(
        metadata: _metadata('settings', today),
        defaultCurrency: cny,
        lastTransactionCurrency: jpy,
        favoriteCurrencies: <Currency>[cny, jpy],
        languageMode: AppLanguageMode.english,
        refreshInterval: const Duration(hours: 12),
        wifiOnlyRefresh: false,
        syncEnabled: false,
      ),
      paymentMethods: <PaymentMethodModel>[travelRewards, everydayCard],
      trip: trip,
      expenses: expenses,
    );
  }

  final UserSettingsModel settings;
  final List<PaymentMethodModel> paymentMethods;
  final TripModel trip;
  final List<ExpenseModel> expenses;
}

PaymentMethodModel _paymentMethod({
  required String id,
  required String name,
  required Currency currency,
  required String foreignFee,
  required String rateMarkup,
  required String cashback,
  required DateTime createdAt,
}) => PaymentMethodModel(
  metadata: _metadata(id, createdAt),
  name: name,
  type: PaymentMethodType.creditCard,
  network: PaymentNetwork.visa,
  billingCurrency: currency,
  foreignFeePercent: DecimalValue.parse(foreignFee),
  crossBorderFeePercent: DecimalValue.zero,
  rateMarkupPercent: DecimalValue.parse(rateMarkup),
  fixedFee: DecimalValue.zero,
  cashbackPercent: DecimalValue.parse(cashback),
  minimumFee: null,
  maximumFee: null,
  supportedTransactionTypes: const <TransactionType>{TransactionType.purchase},
  createdAt: createdAt,
);

ExpenseModel _expense({
  required String id,
  required String title,
  required String category,
  required String localAmount,
  required String referenceAmount,
  required DateTime occurredAt,
  required Currency cny,
  required Currency jpy,
  required PaymentMethodModel method,
}) {
  final reference = Money.parse(referenceAmount, cny);
  final rate = RateSnapshotModel(
    metadata: _metadata('rate-$id', occurredAt),
    baseCurrency: jpy,
    quoteCurrency: cny,
    rate: DecimalValue.parse('0.047840625'),
    sourceType: RateSourceType.market,
    sourceName: 'Daily reference rate',
    sourceTimestamp: occurredAt,
    fetchedAt: occurredAt,
    isCached: false,
  );
  return ExpenseModel(
    metadata: _metadata(id, occurredAt),
    tripId: 'tokyo-seoul',
    title: title,
    category: category,
    transactionAmount: Money.parse(localAmount, jpy),
    referenceAmount: reference,
    estimatedFinalAmount: reference,
    actualFinalAmount: reference,
    paymentMethodId: method.metadata.recordId,
    paymentRuleSnapshot: method.freezeRules(),
    rateSnapshot: rate,
    taxAmount: Money(amount: DecimalValue.zero, currency: cny),
    tipAmount: Money(amount: DecimalValue.zero, currency: cny),
    discountAmount: Money(amount: DecimalValue.zero, currency: cny),
    participantCount: 2,
    occurredAt: occurredAt,
    receiptLocalPath: null,
    notes: null,
    budgetIncluded: true,
    status: ExpenseStatus.confirmed,
    entryType: ExpenseEntryType.purchase,
    relatedExpenseId: null,
    createdAt: occurredAt,
  );
}

SyncRecordMetadata _metadata(String id, DateTime updatedAt) =>
    SyncRecordMetadata(recordId: id, syncVersion: 1, updatedAt: updatedAt);

final class _CompletedStartupStateStore implements StartupStateStore {
  const _CompletedStartupStateStore();

  @override
  Future<bool> isOnboardingComplete() async => true;

  @override
  Future<void> markOnboardingComplete() async {}

  @override
  Future<void> resetOnboarding() async {}
}
