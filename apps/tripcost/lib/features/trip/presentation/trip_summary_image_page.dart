import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:trip_cost/app/theme/app_theme.dart';
import 'package:trip_cost/core/destinations/country_directory.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/money/money.dart';
import 'package:trip_cost/core/money/money_formatter.dart';
import 'package:trip_cost/core/platform/photo_library_gateway.dart';
import 'package:trip_cost/core/trips/domain/trip_budget.dart';
import 'package:trip_cost/features/trip/application/trip_summary_image_service.dart';
import 'package:trip_cost/features/trip/presentation/widgets/trip_summary_card.dart';
import 'package:trip_cost/l10n/app_localizations.dart';
import 'package:trip_cost/shared/widgets/app_toast.dart';

class TripSummaryImagePage extends StatefulWidget {
  const TripSummaryImagePage({
    required this.trip,
    required this.summary,
    required this.generatedAt,
    this.photoLibraryGateway = const MethodChannelPhotoLibraryGateway(),
    this.imageSaving,
    super.key,
  });

  final TripModel trip;
  final TripBudgetSummary summary;
  final DateTime generatedAt;
  final PhotoLibraryGateway photoLibraryGateway;
  final TripSummaryImageSaving? imageSaving;

  @override
  State<TripSummaryImagePage> createState() => _TripSummaryImagePageState();
}

class _TripSummaryImagePageState extends State<TripSummaryImagePage> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await (widget.imageSaving ??
              TripSummaryImageService(photoLibrary: widget.photoLibraryGateway))
          .captureAndSave(_repaintBoundaryKey);
      if (!mounted) return;
      AppToast.show(
        context,
        l10n.tripSummaryImageSaved,
        style: AppToastStyle.success,
      );
    } on PhotoLibrarySaveException catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.code == PhotoLibrarySaveException.permissionDenied
            ? l10n.tripSummaryImagePermissionDenied
            : l10n.tripSummaryImageSaveFailed,
        style: AppToastStyle.error,
      );
    } on Object {
      if (!mounted) return;
      AppToast.show(
        context,
        l10n.tripSummaryImageSaveFailed,
        style: AppToastStyle.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.tripSummaryImageTitle),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      decoration: const BoxDecoration(
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: TripSummaryCard(data: _cardData(context)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.small,
                AppSpacing.medium,
                AppSpacing.medium,
              ),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: const Key('trip-summary-save-button'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : Text(l10n.tripSummaryImageSaveToPhotos),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TripSummaryCardData _cardData(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final language = Localizations.localeOf(context).languageCode;
    final formatter = const MoneyFormatter();
    String money(Money? value) => value == null
        ? l10n.tripNoBudget
        : formatter.format(value, locale: locale, includeCode: true);
    final destinations = widget.trip.destinationCodes
        .map((code) => CountryDirectory().displayNameForCode(code, language))
        .join(' · ');
    final categories = widget.summary.categoryTotals.entries.toList()
      ..sort((left, right) => right.value.amount.compareTo(left.value.amount));
    return TripSummaryCardData(
      brand: 'ROAMSUM',
      summaryLabel: l10n.tripSummaryImageTitle,
      tripName: widget.trip.name,
      destinations: destinations,
      dateRange:
          '${DateFormat.yMMMd(locale).format(widget.trip.startDate)}'
          ' – '
          '${DateFormat.yMMMd(locale).format(widget.trip.endDate)}',
      budgetLabel: l10n.tripBudget,
      budget: money(widget.summary.totalBudget),
      spentLabel: l10n.tripSpent,
      spent: money(widget.summary.spent),
      remainingLabel: l10n.tripRemaining,
      remaining: money(widget.summary.remaining),
      dailyRemainingLabel: l10n.tripDailyRemaining,
      dailyRemaining: money(widget.summary.remainingPerDay),
      dayProgressLabel: l10n.tripDayProgress,
      dayProgress: '${widget.summary.elapsedDays}/${widget.summary.totalDays}',
      categoriesLabel: l10n.ledgerCategories,
      categories: <TripSummaryCategoryRow>[
        for (final entry in categories.take(5))
          TripSummaryCategoryRow(
            label: _categoryLabel(l10n, entry.key),
            amount: money(entry.value),
          ),
      ],
      generatedAt: l10n.tripSummaryImageGeneratedAt(
        DateFormat.yMMMd(locale).add_Hm().format(widget.generatedAt.toLocal()),
      ),
      disclaimer: l10n.tripSummaryImageDisclaimer,
    );
  }
}

String _categoryLabel(AppLocalizations l10n, String value) => switch (value) {
  'food' => l10n.categoryFood,
  'transport' => l10n.categoryTransport,
  'shopping' => l10n.categoryShopping,
  'hotel' => l10n.categoryHotel,
  'tickets' => l10n.categoryTickets,
  _ => l10n.categoryOther,
};
