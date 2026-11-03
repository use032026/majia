import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/money/currency.dart';
import 'package:trip_cost/core/money/decimal_value.dart';
import 'package:trip_cost/core/money/money.dart';

final fixtureCatalog = CurrencyCatalog();
final fixtureCny = fixtureCatalog.resolve('CNY');
final fixtureJpy = fixtureCatalog.resolve('JPY');

SyncRecordMetadata fixtureMetadata(String id, [int version = 1]) {
  return SyncRecordMetadata(
    recordId: id,
    syncVersion: version,
    updatedAt: DateTime.utc(2026, 8, 17, 8),
  );
}

RateSnapshotModel fixtureRate() => RateSnapshotModel(
  metadata: fixtureMetadata('rate-1'),
  baseCurrency: fixtureJpy,
  quoteCurrency: fixtureCny,
  rate: DecimalValue.parse('0.05'),
  sourceType: RateSourceType.market,
  sourceName: 'Fixture market',
  sourceTimestamp: DateTime.utc(2026, 8, 17),
  fetchedAt: DateTime.utc(2026, 8, 17, 8),
  isCached: false,
);

PaymentMethodModel fixturePaymentMethod() => PaymentMethodModel(
  metadata: fixtureMetadata('payment-1'),
  name: 'Travel card',
  type: PaymentMethodType.creditCard,
  network: PaymentNetwork.visa,
  billingCurrency: fixtureCny,
  foreignFeePercent: DecimalValue.parse('1'),
  crossBorderFeePercent: DecimalValue.zero,
  rateMarkupPercent: DecimalValue.zero,
  fixedFee: DecimalValue.zero,
  cashbackPercent: DecimalValue.zero,
  minimumFee: null,
  maximumFee: null,
  supportedTransactionTypes: const <TransactionType>{TransactionType.purchase},
  createdAt: DateTime.utc(2026, 8, 17, 8),
);

TripModel fixtureTrip({
  Money? budget,
  TripStatus status = TripStatus.active,
  DateTime? startDate,
  DateTime? endDate,
}) {
  return TripModel(
    metadata: fixtureMetadata('trip-1'),
    name: 'Tokyo week',
    destinationCodes: const <String>['JP'],
    startDate: startDate ?? DateTime.utc(2026, 8, 15),
    endDate: endDate ?? DateTime.utc(2026, 8, 21),
    homeCurrency: fixtureCny,
    localCurrencies: <Currency>[fixtureJpy],
    totalBudget: budget ?? Money.parse('1000', fixtureCny),
    participantCount: 2,
    defaultPaymentMethodId: 'payment-1',
    status: status,
    createdAt: DateTime.utc(2026, 8, 1),
  );
}

ExpenseModel fixtureExpense({
  String id = 'expense-1',
  String? tripId = 'trip-1',
  String title = 'Lunch',
  String category = 'food',
  String estimate = '100',
  String? actual,
  bool budgetIncluded = true,
  ExpenseStatus status = ExpenseStatus.estimated,
  ExpenseEntryType entryType = ExpenseEntryType.purchase,
  String? relatedExpenseId,
  DateTime? occurredAt,
  String? receiptLocalPath,
}) {
  final amount = DecimalValue.parse(estimate);
  return ExpenseModel(
    metadata: fixtureMetadata(id),
    tripId: tripId,
    title: title,
    category: category,
    transactionAmount: Money(
      amount:
          (entryType == ExpenseEntryType.refund ||
              entryType == ExpenseEntryType.partialRefund)
          ? -(amount.abs() * DecimalValue.parse('20'))
          : amount * DecimalValue.parse('20'),
      currency: fixtureJpy,
    ),
    referenceAmount: Money(amount: amount, currency: fixtureCny),
    estimatedFinalAmount: Money(amount: amount, currency: fixtureCny),
    actualFinalAmount: actual == null ? null : Money.parse(actual, fixtureCny),
    paymentMethodId: 'payment-1',
    paymentRuleSnapshot: fixturePaymentMethod().freezeRules(),
    rateSnapshot: fixtureRate(),
    taxAmount: Money(amount: DecimalValue.zero, currency: fixtureCny),
    tipAmount: Money(amount: DecimalValue.zero, currency: fixtureCny),
    discountAmount: Money(amount: DecimalValue.zero, currency: fixtureCny),
    participantCount: 2,
    occurredAt: occurredAt ?? DateTime.utc(2026, 8, 17, 8),
    receiptLocalPath: receiptLocalPath,
    notes: null,
    budgetIncluded: budgetIncluded,
    status: status,
    entryType: entryType,
    relatedExpenseId: relatedExpenseId,
    createdAt: DateTime.utc(2026, 8, 17, 8),
  );
}
