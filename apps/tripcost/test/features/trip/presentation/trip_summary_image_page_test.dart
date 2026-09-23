import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/core/trips/domain/trip_budget.dart';
import 'package:trip_cost/features/trip/application/trip_summary_image_service.dart';
import 'package:trip_cost/features/trip/presentation/trip_summary_image_page.dart';
import 'package:trip_cost/l10n/app_localizations.dart';

import '../../../helpers/m5_fixtures.dart';

void main() {
  testWidgets('saves only after the user taps the visible Photos button', (
    tester,
  ) async {
    final imageSaving = _RecordingImageSaving();
    final trip = fixtureTrip();
    final generatedAt = DateTime.utc(2026, 8, 17, 2);
    final summary = const TripBudgetCalculator().calculate(
      trip: trip,
      expenses: const [],
      now: generatedAt,
    );

    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripSummaryImagePage(
          trip: trip,
          summary: summary,
          generatedAt: generatedAt,
          imageSaving: imageSaving,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(imageSaving.calls, 0);
    expect(find.text('Save to Photos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trip-summary-save-button')));
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (imageSaving.calls > 0) break;
    }

    expect(imageSaving.calls, 1);
  });
}

final class _RecordingImageSaving implements TripSummaryImageSaving {
  int calls = 0;

  @override
  Future<void> captureAndSave(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = 3,
  }) async {
    calls += 1;
  }
}
