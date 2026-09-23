import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/features/trip/presentation/widgets/trip_summary_card.dart';

void main() {
  testWidgets('renders only aggregate trip summary data', (tester) async {
    const data = TripSummaryCardData(
      brand: 'ROAMSUM',
      summaryLabel: 'Trip summary',
      tripName: 'Tokyo week',
      destinations: 'Japan',
      dateRange: 'Aug 16 – Aug 21, 2026',
      budgetLabel: 'Total budget',
      budget: r'¥ 1,000.00 CNY',
      spentLabel: 'Spent',
      spent: r'¥ 155.00 CNY',
      remainingLabel: 'Remaining',
      remaining: r'¥ 845.00 CNY',
      dailyRemainingLabel: 'Remaining per day',
      dailyRemaining: r'¥ 169.00 CNY',
      dayProgressLabel: 'Trip day',
      dayProgress: '2/6',
      categoriesLabel: 'Categories',
      categories: <TripSummaryCategoryRow>[
        TripSummaryCategoryRow(label: 'Food', amount: r'¥ 100.00 CNY'),
      ],
      generatedAt: 'Generated Aug 17, 2026 10:00',
      disclaimer:
          'For personal reference. Receipt images and expense details are not included.',
    );

    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(child: TripSummaryCard(data: data)),
        ),
      ),
    );

    expect(find.byKey(const Key('trip-summary-card')), findsOneWidget);
    expect(find.text('Tokyo week'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text(r'¥ 100.00 CNY'), findsOneWidget);
    expect(find.textContaining('Receipt images'), findsOneWidget);
    expect(find.textContaining('receiptLocalPath'), findsNothing);
  });
}
