import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trip_cost/app/router/app_routes.dart';
import 'package:trip_cost/app/theme/app_theme.dart';
import 'package:trip_cost/core/destinations/country_directory.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/export/expense_export_service.dart';
import 'package:trip_cost/core/infrastructure/app_providers.dart';
import 'package:trip_cost/core/money/currency.dart';
import 'package:trip_cost/core/money/decimal_value.dart';
import 'package:trip_cost/core/money/money.dart';
import 'package:trip_cost/core/money/money_formatter.dart';
import 'package:trip_cost/core/trips/domain/trip_budget.dart';
import 'package:trip_cost/features/expense/application/expenses_controller.dart';
import 'package:trip_cost/features/payment_method/application/payment_methods_controller.dart';
import 'package:trip_cost/features/scanner/application/scan_flow.dart';
import 'package:trip_cost/features/settings/application/settings_data_service.dart';
import 'package:trip_cost/features/trip/application/trips_controller.dart';
import 'package:trip_cost/features/trip/presentation/trip_date_range_picker_page.dart';
import 'package:trip_cost/features/trip/presentation/trip_summary_image_page.dart';
import 'package:trip_cost/l10n/app_localizations.dart';
import 'package:trip_cost/shared/widgets/country_picker_page.dart';
import 'package:trip_cost/shared/widgets/currency_picker_page.dart';
import 'package:uuid/uuid.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final trips = ref.watch(tripsControllerProvider);
    final expenses = ref.watch(expensesControllerProvider).value ?? const [];
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(localizations.tripsTitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.push(AppRoutes.tripCreate),
          child: Icon(
            CupertinoIcons.add,
            semanticLabel: localizations.tripCreate,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: trips.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stack) => Center(
            child: CupertinoButton(
              onPressed: () => ref.invalidate(tripsControllerProvider),
              child: Text(localizations.converterRefresh),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _EmptyTrips(
                onCreate: () => context.push(AppRoutes.tripCreate),
              );
            }
            final now = DateTime.now().toUtc();
            final current = items
                .where(
                  (trip) =>
                      tripListSection(trip, now) == TripListSection.active,
                )
                .toList(growable: false);
            final upcoming = items
                .where(
                  (trip) =>
                      tripListSection(trip, now) == TripListSection.upcoming,
                )
                .toList(growable: false);
            final history = items
                .where(
                  (trip) =>
                      tripListSection(trip, now) == TripListSection.history,
                )
                .toList(growable: false);
            return ListView(
              key: const Key('trips-redesigned-list'),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.small,
                AppSpacing.medium,
                AppInsets.scrollableBottomPadding(context),
              ),
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<bool>(
                    key: const Key('trip-section-segmented-control'),
                    groupValue: _showHistory,
                    children: <bool, Widget>{
                      false: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(localizations.tripCurrentAndUpcoming),
                      ),
                      true: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(localizations.tripHistoryTab),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) setState(() => _showHistory = value);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                if (_showHistory) ...<Widget>[
                  if (history.isEmpty)
                    _Surface(child: Text(localizations.tripHistory))
                  else
                    for (final trip in history) ...<Widget>[
                      _CompactTripRow(
                        trip: trip,
                        onTap: () => context.push(
                          AppRoutes.tripDetail(trip.metadata.recordId),
                          extra: trip,
                        ),
                        onMore: () => _showActions(context, ref, trip),
                      ),
                      const SizedBox(height: AppSpacing.small),
                    ],
                ] else ...<Widget>[
                  for (final trip in current) ...<Widget>[
                    _TripCard(
                      trip: trip,
                      summary: const TripBudgetCalculator().calculate(
                        trip: trip,
                        expenses: expenses,
                        now: now,
                      ),
                      now: now,
                      onTap: () => context.push(
                        AppRoutes.tripDetail(trip.metadata.recordId),
                        extra: trip,
                      ),
                      onRecord: () =>
                          context.push(AppRoutes.expenseCreate, extra: trip),
                      onMore: () => _showActions(context, ref, trip),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                  ],
                  if (upcoming.isNotEmpty) ...<Widget>[
                    _SectionLabel(label: localizations.tripUpcoming),
                    for (final trip in upcoming) ...<Widget>[
                      _CompactTripRow(
                        trip: trip,
                        onTap: () => context.push(
                          AppRoutes.tripDetail(trip.metadata.recordId),
                          extra: trip,
                        ),
                        onMore: () => _showActions(context, ref, trip),
                      ),
                      const SizedBox(height: AppSpacing.small),
                    ],
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    final l10n = AppLocalizations.of(context);
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('edit'),
            child: Text(l10n.commonEdit),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('copy'),
            child: Text(l10n.tripCopy),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('export'),
            child: Text(l10n.tripExport),
          ),
          if (trip.status != TripStatus.archived)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('archive'),
              child: Text(l10n.tripArchive),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('delete'),
            child: Text(l10n.commonDelete),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'edit':
        await context.push(
          AppRoutes.tripEdit(trip.metadata.recordId),
          extra: trip,
        );
      case 'copy':
        await ref.read(tripsControllerProvider.notifier).duplicate(trip);
      case 'export':
        await _exportTrip(context, ref, trip);
      case 'archive':
        await ref.read(tripsControllerProvider.notifier).archive(trip);
      case 'delete':
        final choice = await showCupertinoDialog<String>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.tripDeleteTitle),
            content: Text(l10n.tripDeleteMessage),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop('keep'),
                child: Text(l10n.tripDeleteKeepReceipts),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop('receipts'),
                child: Text(l10n.tripDeleteWithReceipts),
              ),
            ],
          ),
        );
        if (choice != null) {
          var receiptFailures = const <String>[];
          if (choice == 'receipts') {
            receiptFailures = await ref
                .read(expensesControllerProvider.notifier)
                .clearReceiptImagesForTrip(trip.metadata.recordId);
          }
          await ref
              .read(tripsControllerProvider.notifier)
              .delete(trip.metadata.recordId);
          if (receiptFailures.isNotEmpty && context.mounted) {
            await _showMessage(context, l10n.tripReceiptDeletePartial);
          }
        }
    }
  }

  Future<void> _exportTrip(
    BuildContext context,
    WidgetRef ref,
    TripModel trip,
  ) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showCupertinoModalPopup<_TripExportChoice>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_TripExportChoice.csv),
            child: Text(l10n.exportCsv),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_TripExportChoice.pdf),
            child: Text(l10n.exportPdf),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(context).pop(_TripExportChoice.summaryImage),
            child: Text(l10n.tripSummaryImageExport),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _TripExportChoice.summaryImage) {
      final now = DateTime.now().toUtc();
      final expenses =
          ref.read(expensesControllerProvider).value ?? const <ExpenseModel>[];
      await Navigator.of(context).push<void>(
        CupertinoPageRoute<void>(
          builder: (context) => TripSummaryImagePage(
            trip: trip,
            summary: const TripBudgetCalculator().calculate(
              trip: trip,
              expenses: expenses,
              now: now,
            ),
            generatedAt: now,
          ),
        ),
      );
      return;
    }
    try {
      final service = ref.read(expenseExportServiceProvider);
      final locale = Localizations.localeOf(context).toLanguageTag();
      final file = choice == _TripExportChoice.csv
          ? await service.createCsv(
              locale: locale,
              tripId: trip.metadata.recordId,
            )
          : await service.createPdf(
              locale: locale,
              tripId: trip.metadata.recordId,
            );
      await service.share(file);
    } on ExpenseExportException catch (error) {
      if (!context.mounted) return;
      final message = switch (error.code) {
        ExpenseExportException.empty => l10n.exportEmpty,
        ExpenseExportException.tooLarge => l10n.exportTooLarge,
        _ => l10n.exportFailed,
      };
      await _showMessage(context, message);
    } on Object {
      if (context.mounted) await _showMessage(context, l10n.exportFailed);
    }
  }

  Future<void> _showMessage(BuildContext context, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).commonDone),
          ),
        ],
      ),
    );
  }
}

enum _TripExportChoice { csv, pdf, summaryImage }

class TripEditorPage extends ConsumerStatefulWidget {
  const TripEditorPage({this.initial, this.defaultHomeCurrency, super.key});

  final TripModel? initial;
  final Currency? defaultHomeCurrency;

  @override
  ConsumerState<TripEditorPage> createState() => _TripEditorPageState();
}

class TripEditorLoaderPage extends ConsumerWidget {
  const TripEditorLoaderPage({required this.tripId, this.initial, super.key});

  final String tripId;
  final TripModel? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initial != null) return TripEditorPage(initial: initial);
    final trips = ref.watch(tripsControllerProvider);
    return trips.when(
      loading: () => const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, stack) => CupertinoPageScaffold(
        child: Center(child: Text(AppLocalizations.of(context).tripMissing)),
      ),
      data: (items) {
        final trip = items
            .where((item) => item.metadata.recordId == tripId)
            .firstOrNull;
        return trip == null
            ? CupertinoPageScaffold(
                child: Center(
                  child: Text(AppLocalizations.of(context).tripMissing),
                ),
              )
            : TripEditorPage(initial: trip);
      },
    );
  }
}

class _TripEditorPageState extends ConsumerState<TripEditorPage> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  final _participants = TextEditingController(text: '1');
  final CountryDirectory _countryDirectory = CountryDirectory();
  final List<TripStopModel> _stops = <TripStopModel>[];
  late final String _recordId;
  late DateTime _startDate;
  late DateTime _endDate;
  late Currency _homeCurrency;
  String? _defaultPaymentMethodId;
  bool _offlinePack = false;
  bool _showMoreSettings = false;
  bool _invalid = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _recordId = initial?.metadata.recordId ?? const Uuid().v4();
    _homeCurrency =
        initial?.homeCurrency ??
        widget.defaultHomeCurrency ??
        CurrencyCatalog().resolve('CNY');
    final today = localCalendarDate(DateTime.now());
    _startDate = initial?.startDate ?? today;
    _endDate = initial?.endDate ?? _startDate.add(const Duration(days: 6));
    if (initial != null) {
      _name.text = initial.name;
      _stops.addAll(initial.stops);
      _budget.text = initial.totalBudget?.amount.toString() ?? '';
      _participants.text = initial.participantCount.toString();
      _defaultPaymentMethodId = initial.defaultPaymentMethodId;
      _offlinePack = initial.offlinePackUpdatedAt != null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    _participants.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final methods =
        ref.watch(paymentMethodsControllerProvider).value ?? const [];
    final locale = Localizations.localeOf(context).toLanguageTag();
    final totalDays = _tripDays;
    final budgetValue = _tryParseDecimal(_budget.text.trim());
    final dailyBudget = budgetValue == null
        ? null
        : Money(
            amount: budgetValue.divide(DecimalValue.parse('$totalDays')),
            currency: _homeCurrency,
          );
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _close,
          child: Text(l10n.commonCancel),
        ),
        middle: Text(widget.initial == null ? l10n.tripCreate : l10n.tripEdit),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: const Key('trip-editor-redesigned-list'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.medium,
            AppSpacing.medium,
            AppSpacing.medium,
            AppInsets.scrollableBottomPadding(context),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: <Widget>[
            Text(
              l10n.tripRoutePlannerTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tripRoutePlannerSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            _GroupedSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Text(
                      l10n.tripStopsTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_stops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                      child: Text(
                        l10n.tripRouteRequired,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    )
                  else
                    ReorderableList(
                      key: const Key('trip-stop-list'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _stops.length,
                      onReorder: _reorderStop,
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        return _TripStopEditorRow(
                          key: ValueKey(
                            '${stop.countryCode}-${stop.startDate.toIso8601String()}',
                          ),
                          index: index,
                          stop: stop,
                          destination: _countryName(stop.countryCode, context),
                          onPressed: () => _editStop(index),
                        );
                      },
                    ),
                  const _EditorDivider(),
                  CupertinoButton(
                    key: const Key('trip-add-stop-button'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onPressed: _addStop,
                    child: Row(
                      children: <Widget>[
                        const Icon(CupertinoIcons.add_circled, size: 25),
                        const SizedBox(width: 10),
                        Text(l10n.tripAddNextStop),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            _GroupedSurface(
              child: _EditorValueRow(
                label: l10n.tripWholeRange,
                value:
                    '${_formatShortDate(_startDate, context)} – ${_formatShortDate(_endDate, context)} · ${l10n.tripDayCount(totalDays)}',
                onPressed: _pickWholeTripRange,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            _GroupedSurface(
              child: _EditorInputRow(
                label: l10n.tripName,
                controller: _name,
                placeholder: _automaticTripName(context),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            _GroupedSurface(
              child: Column(
                children: <Widget>[
                  _EditorInputRow(
                    icon: CupertinoIcons.money_dollar_circle,
                    label: l10n.tripWholeBudget,
                    controller: _budget,
                    numeric: true,
                    placeholder: '${_homeCurrency.code} 0',
                    onChanged: (_) => setState(() {}),
                  ),
                  const _EditorDivider(indent: 48),
                  _EditorInputRow(
                    icon: CupertinoIcons.person,
                    label: l10n.tripParticipants,
                    controller: _participants,
                    numeric: true,
                  ),
                  const _EditorDivider(indent: 48),
                  _EditorActionRow(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    label: dailyBudget == null
                        ? l10n.tripDailyBudgetHint
                        : l10n.tripDailyBudgetApprox(
                            const MoneyFormatter().format(
                              dailyBudget,
                              locale: locale,
                              includeCode: false,
                            ),
                          ),
                    subtitle: dailyBudget == null
                        ? null
                        : l10n.tripDailyBudgetHint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            _GroupedSurface(
              child: Column(
                children: <Widget>[
                  _EditorValueRow(
                    icon: CupertinoIcons.slider_horizontal_3,
                    label: l10n.tripMoreSettings,
                    value: _settingsSummary(methods, l10n),
                    expanded: _showMoreSettings,
                    onPressed: () =>
                        setState(() => _showMoreSettings = !_showMoreSettings),
                  ),
                  if (_showMoreSettings) ...<Widget>[
                    const _EditorDivider(indent: 48),
                    _EditorValueRow(
                      label: l10n.currencyHome,
                      value: _homeCurrency.code,
                      onPressed: _pickHomeCurrency,
                    ),
                    const _EditorDivider(indent: 16),
                    _EditorValueRow(
                      label: l10n.tripDefaultPayment,
                      value: _paymentMethodName(methods, l10n),
                      onPressed: () => _pickPaymentMethod(methods),
                    ),
                    const _EditorDivider(indent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(l10n.tripOfflinePack),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.tripOfflineMultiHint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: _offlinePack,
                            onChanged: (value) =>
                                setState(() => _offlinePack = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                child: Text(
                  _stops.isEmpty ? l10n.tripRouteRequired : l10n.tripInvalid,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            const SizedBox(height: AppSpacing.medium),
            CupertinoButton.filled(
              key: const Key('trip-editor-submit-button'),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CupertinoActivityIndicator(radius: 8)
                  : Text(
                      widget.initial == null
                          ? l10n.tripCreate
                          : l10n.commonSave,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int get _tripDays => _endDate.difference(_startDate).inDays + 1;

  List<Currency> get _routeCurrencies {
    final byCode = <String, Currency>{};
    for (final stop in _stops) {
      byCode.putIfAbsent(stop.localCurrency.code, () => stop.localCurrency);
    }
    return byCode.values.toList(growable: false);
  }

  String _countryName(String code, BuildContext context) => _countryDirectory
      .displayNameForCode(code, Localizations.localeOf(context).languageCode);

  String _automaticTripName(BuildContext context) {
    if (_stops.isEmpty) return AppLocalizations.of(context).tripName;
    final route = _stops
        .map((stop) => _countryName(stop.countryCode, context))
        .join(' · ');
    return '$route${AppLocalizations.of(context).tripDayCount(_tripDays)}';
  }

  Future<void> _addStop() async {
    final selected = await showCountryMultiPickerPage(
      context: context,
      title: AppLocalizations.of(context).tripAddNextStop,
      doneLabel: AppLocalizations.of(context).commonDone,
      selectedCodes: const <String>[],
      minimumSelection: 1,
      maximumSelection: 1,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final code = selected.single;
    final recommended = _countryDirectory.recommendedCurrencies(<String>[code]);
    setState(() {
      _stops.add(
        TripStopModel(
          countryCode: code,
          startDate: _startDate,
          endDate: _endDate,
          localCurrency: recommended.firstOrNull ?? _homeCurrency,
        ),
      );
      if (_stops.length > _tripDays) {
        _endDate = _startDate.add(Duration(days: _stops.length - 1));
      }
      _rebalanceStops();
      _invalid = false;
    });
  }

  void _reorderStop(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);
      _rebalanceStops();
    });
  }

  void _rebalanceStops() {
    if (_stops.isEmpty) return;
    final totalDays = _tripDays;
    final countries = <TripStopModel>[..._stops];
    _stops
      ..clear()
      ..addAll(<TripStopModel>[
        for (var index = 0; index < countries.length; index += 1)
          TripStopModel(
            countryCode: countries[index].countryCode,
            startDate: _startDate.add(
              Duration(days: totalDays * index ~/ countries.length),
            ),
            endDate: _startDate.add(
              Duration(days: (totalDays * (index + 1) ~/ countries.length) - 1),
            ),
            localCurrency: countries[index].localCurrency,
          ),
      ]);
  }

  Future<void> _editStop(int index) async {
    final l10n = AppLocalizations.of(context);
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(_countryName(_stops[index].countryCode, context)),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('destination'),
            child: Text(l10n.tripChangeDestination),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('currency'),
            child: Text(l10n.tripChangeStopCurrency),
          ),
          if (index < _stops.length - 1)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('date'),
              child: Text(l10n.tripAdjustStopEnd),
            ),
          if (_stops.length > 1)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop('remove'),
              child: Text(l10n.tripRemoveStop),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'destination':
        await _changeStopDestination(index);
      case 'currency':
        await _changeStopCurrency(index);
      case 'date':
        await _changeStopBoundary(index);
      case 'remove':
        setState(() {
          _stops.removeAt(index);
          _rebalanceStops();
        });
    }
  }

  Future<void> _changeStopDestination(int index) async {
    final selected = await showCountryMultiPickerPage(
      context: context,
      title: AppLocalizations.of(context).tripChangeDestination,
      doneLabel: AppLocalizations.of(context).commonDone,
      selectedCodes: <String>[_stops[index].countryCode],
      minimumSelection: 1,
      maximumSelection: 1,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final previous = _stops[index];
    final recommended = _countryDirectory.recommendedCurrencies(selected);
    setState(() {
      _stops[index] = TripStopModel(
        countryCode: selected.single,
        startDate: previous.startDate,
        endDate: previous.endDate,
        localCurrency: recommended.firstOrNull ?? previous.localCurrency,
      );
    });
  }

  Future<void> _changeStopCurrency(int index) async {
    final previous = _stops[index];
    final result = await showCurrencyPickerPage(
      context: context,
      title: AppLocalizations.of(context).tripChangeStopCurrency,
      selected: previous.localCurrency,
    );
    if (result?.currency case final selected?) {
      if (!mounted) return;
      setState(() {
        _stops[index] = TripStopModel(
          countryCode: previous.countryCode,
          startDate: previous.startDate,
          endDate: previous.endDate,
          localCurrency: selected,
        );
      });
    }
  }

  Future<void> _changeStopBoundary(int index) async {
    final stop = _stops[index];
    final next = _stops[index + 1];
    final selected = await _pickDateValue(
      initial: stop.endDate,
      minimum: stop.startDate,
      maximum: next.endDate.subtract(const Duration(days: 1)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _stops[index] = TripStopModel(
        countryCode: stop.countryCode,
        startDate: stop.startDate,
        endDate: selected,
        localCurrency: stop.localCurrency,
      );
      _stops[index + 1] = TripStopModel(
        countryCode: next.countryCode,
        startDate: selected.add(const Duration(days: 1)),
        endDate: next.endDate,
        localCurrency: next.localCurrency,
      );
    });
  }

  Future<void> _pickWholeTripRange() async {
    final range = await showTripDateRangePickerPage(
      context: context,
      initialStart: _startDate,
      initialEnd: _endDate,
    );
    if (range == null || !mounted) return;
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
      if (_stops.length > _tripDays) {
        _endDate = _startDate.add(Duration(days: _stops.length - 1));
      }
      _rebalanceStops();
    });
  }

  Future<DateTime?> _pickDateValue({
    required DateTime initial,
    DateTime? minimum,
    DateTime? maximum,
  }) async {
    var selected = initial;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 330,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(AppLocalizations.of(context).commonDone),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: minimum,
                  maximumDate: maximum,
                  onDateTimeChanged: (value) => selected = DateTime.utc(
                    value.year,
                    value.month,
                    value.day,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true ? selected : null;
  }

  Future<void> _pickHomeCurrency() async {
    final result = await showCurrencyPickerPage(
      context: context,
      title: AppLocalizations.of(context).currencyHome,
      selected: _homeCurrency,
    );
    if (result?.currency case final selected?) {
      if (!mounted) return;
      setState(() => _homeCurrency = selected);
    }
  }

  Future<void> _pickPaymentMethod(List<PaymentMethodModel> methods) async {
    final selected = await _choose<String?>(<String?, String>{
      null: AppLocalizations.of(context).commonNone,
      for (final item in methods) item.metadata.recordId: item.name,
    });
    if (mounted) setState(() => _defaultPaymentMethodId = selected);
  }

  String _paymentMethodName(
    List<PaymentMethodModel> methods,
    AppLocalizations l10n,
  ) =>
      methods
          .where((item) => item.metadata.recordId == _defaultPaymentMethodId)
          .firstOrNull
          ?.name ??
      l10n.commonNone;

  String _settingsSummary(
    List<PaymentMethodModel> methods,
    AppLocalizations l10n,
  ) {
    final currencies = _routeCurrencies.isEmpty
        ? l10n.tripLocalCurrenciesPending
        : _routeCurrencies.map((currency) => currency.code).join(' + ');
    final payment = _paymentMethodName(methods, l10n);
    final offline = _offlinePack
        ? l10n.tripOfflineReady
        : l10n.tripOfflineMissing;
    return '$currencies · $payment · $offline';
  }

  Future<T?> _choose<T>(Map<T, String> options) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: <Widget>[
          for (final option in options.entries)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(option.key),
              child: Text(option.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _invalid = false;
    });
    try {
      if (_stops.isEmpty) {
        throw const FormatException('Trip route is required.');
      }
      final now = DateTime.now().toUtc();
      final budgetText = _budget.text.trim();
      final initial = widget.initial;
      final participantCount = int.parse(_participants.text.trim());
      final trip = TripModel(
        metadata: SyncRecordMetadata(
          recordId: _recordId,
          syncVersion: (initial?.metadata.syncVersion ?? 0) + 1,
          updatedAt: now,
        ),
        name: _name.text.trim().isEmpty
            ? _automaticTripName(context)
            : _name.text.trim(),
        destinationCodes: <String>[for (final stop in _stops) stop.countryCode],
        startDate: _startDate,
        endDate: _endDate,
        stops: _stops,
        homeCurrency: _homeCurrency,
        localCurrencies: _routeCurrencies,
        totalBudget: budgetText.isEmpty
            ? null
            : Money.parse(budgetText, _homeCurrency),
        participantCount: participantCount,
        defaultPaymentMethodId: _defaultPaymentMethodId,
        offlinePackUpdatedAt: _offlinePack
            ? initial?.offlinePackUpdatedAt
            : null,
        status: tripStatusForDates(
          startDate: _startDate,
          endDate: _endDate,
          now: now,
          archived: initial?.status == TripStatus.archived,
        ),
        createdAt: initial?.createdAt ?? now,
      );
      await ref.read(tripsControllerProvider.notifier).save(trip);
      if (_offlinePack) {
        try {
          final settings = await ref.read(settingsRepositoryProvider).load();
          await ref
              .read(offlineRatePackServiceProvider)
              .download(
                tripId: trip.metadata.recordId,
                homeCurrency: trip.homeCurrency,
                localCurrencies: trip.localCurrencies,
                wifiOnly: settings?.wifiOnlyRefresh ?? false,
              );
          ref.invalidate(tripsControllerProvider);
        } on Object {
          // A failed optional download must not roll back the local trip.
        }
      }
      if (mounted) _close();
    } on Object {
      if (mounted) {
        setState(() {
          _invalid = true;
          _isSaving = false;
        });
      }
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.trips);
    }
  }
}

class TripDashboardPage extends ConsumerWidget {
  const TripDashboardPage({required this.tripId, this.initial, super.key});

  final String tripId;
  final TripModel? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final trips = ref.watch(tripsControllerProvider).value ?? const [];
    final trip =
        trips.where((item) => item.metadata.recordId == tripId).firstOrNull ??
        initial;
    final expenses = ref.watch(expensesControllerProvider).value ?? const [];
    final paymentMethods =
        ref.watch(paymentMethodsControllerProvider).value ?? const [];
    if (trip == null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(l10n.tripsTitle)),
        child: Center(child: Text(l10n.tripMissing)),
      );
    }
    final summary = const TripBudgetCalculator().calculate(
      trip: trip,
      expenses: expenses,
      now: DateTime.now().toUtc(),
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = const MoneyFormatter();
    String money(Money? value) => value == null
        ? l10n.tripNoBudget
        : formatter.format(value, locale: locale, includeCode: true);
    final tripExpenses = expenses
        .where((item) => item.tripId == tripId)
        .take(5)
        .toList(growable: false);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(trip.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () =>
              context.push(AppRoutes.tripEdit(tripId), extra: trip),
          child: Text(l10n.commonEdit),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: AppInsets.secondaryPageScrollPadding(context),
          children: <Widget>[
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.tripBudget,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _Metric(label: l10n.tripSpent, value: money(summary.spent)),
                  _Metric(
                    label: l10n.tripRemaining,
                    value: money(summary.remaining),
                  ),
                  _Metric(
                    label: l10n.tripDailyRemaining,
                    value: money(summary.remainingPerDay),
                  ),
                  _Metric(
                    label: l10n.tripDailyAverage,
                    value: money(summary.currentDailyAverage),
                  ),
                  _Metric(
                    label: l10n.tripDayProgress,
                    value: '${summary.elapsedDays}/${summary.totalDays}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            Row(
              children: <Widget>[
                Expanded(
                  child: CupertinoButton.filled(
                    onPressed: () =>
                        context.push(AppRoutes.expenseCreate, extra: trip),
                    child: Text(l10n.expenseManualAdd),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  onPressed: () => context.push(
                    AppRoutes.scan,
                    extra: ScanPageArguments(
                      initialPurpose: ScanPurpose.record,
                      trip: trip,
                    ),
                  ),
                  child: Text(l10n.scanAction),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.large),
            if (summary.categoryTotals.isNotEmpty) ...<Widget>[
              Text(
                l10n.ledgerCategories,
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
              for (final entry in summary.categoryTotals.entries)
                _Metric(
                  label: _tripCategoryLabel(l10n, entry.key),
                  value:
                      '${money(entry.value)} · '
                      '${_share(entry.value, summary.spent)}%',
                ),
              const SizedBox(height: AppSpacing.medium),
            ],
            if (summary.paymentMethodTotals.isNotEmpty) ...<Widget>[
              Text(
                l10n.tripPaymentBreakdown,
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
              for (final entry in summary.paymentMethodTotals.entries)
                _Metric(
                  label:
                      paymentMethods
                          .where((item) => item.metadata.recordId == entry.key)
                          .firstOrNull
                          ?.name ??
                      l10n.commonNone,
                  value:
                      '${money(entry.value)} · '
                      '${_share(entry.value, summary.spent)}%',
                ),
              const SizedBox(height: AppSpacing.medium),
            ],
            Text(
              l10n.expenseRecent,
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
            const SizedBox(height: 8),
            if (tripExpenses.isEmpty)
              _Surface(child: Text(l10n.ledgerEmpty))
            else
              for (final expense in tripExpenses)
                CupertinoListTile(
                  padding: EdgeInsets.zero,
                  title: Text(expense.title),
                  subtitle: Text(
                    '${_tripCategoryLabel(l10n, expense.category)} · '
                    '${money(expense.transactionAmount)}',
                  ),
                  trailing: Text(
                    money(
                      expense.actualFinalAmount ?? expense.estimatedFinalAmount,
                    ),
                  ),
                  onTap: () => context.push(
                    AppRoutes.expenseDetail(expense.metadata.recordId),
                    extra: expense,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.summary,
    required this.now,
    required this.onTap,
    required this.onRecord,
    required this.onMore,
  });

  final TripModel trip;
  final TripBudgetSummary summary;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onRecord;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appLocale = Localizations.localeOf(context);
    final locale = appLocale.toLanguageTag();
    final stopLabelSeparator = appLocale.languageCode == 'zh' ? '：' : ': ';
    final formatter = const MoneyFormatter();
    String money(Money? value) => value == null
        ? l10n.tripNoBudget
        : formatter.format(value, locale: locale, includeCode: false);
    final usedPercent =
        double.tryParse(summary.usedPercent?.toString() ?? '0') ?? 0;
    final progress = (usedPercent / 100).clamp(0.0, 1.0);
    final today = localCalendarDate(now);
    final currentIndex = trip.stops.indexWhere(
      (stop) => !today.isBefore(stop.startDate) && !today.isAfter(stop.endDate),
    );
    final current = currentIndex >= 0 ? trip.stops[currentIndex] : null;
    final next = currentIndex >= 0 && currentIndex + 1 < trip.stops.length
        ? trip.stops[currentIndex + 1]
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue
                        .resolveFrom(context)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.briefcase, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        trip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatShortDate(trip.startDate, context)} – ${_formatShortDate(trip.endDate, context)} · ${l10n.tripDayCount(summary.totalDays)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen
                        .resolveFrom(context)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    l10n.tripActive,
                    style: const TextStyle(
                      color: CupertinoColors.systemGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  minimumSize: const Size.square(28),
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  onPressed: onMore,
                  child: const Icon(CupertinoIcons.ellipsis, size: 18),
                ),
              ],
            ),
            if (trip.stops.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _TripRouteOverview(stops: trip.stops, activeIndex: currentIndex),
            ],
            if (current != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue
                      .resolveFrom(context)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(CupertinoIcons.location_solid, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${l10n.tripCurrentStop}$stopLabelSeparator${_countryNameForTrip(current.countryCode, context)} · ${l10n.tripStopDayProgress(today.difference(current.startDate).inDays + 1, current.endDate.difference(current.startDate).inDays + 1)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (next != null) ...<Widget>[
                      Container(
                        width: 0.5,
                        height: 18,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                      const SizedBox(width: 10),
                      const Icon(CupertinoIcons.clock, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${l10n.tripNextStop}$stopLabelSeparator${_countryNameForTrip(next.countryCode, context)} · ${l10n.tripDaysLater(next.startDate.difference(today).inDays)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemBlue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _BudgetMetric(
                  label: l10n.tripBudget,
                  value: money(summary.totalBudget),
                ),
                _BudgetMetric(
                  label: l10n.tripSpent,
                  value: money(summary.spent),
                ),
                _BudgetMetric(
                  label: l10n.tripRemaining,
                  value: money(summary.remaining),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ColoredBox(
                      color: CupertinoColors.systemGrey4.resolveFrom(context),
                    ),
                    FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: progress,
                      child: const ColoredBox(
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  l10n.tripBudgetUsed(usedPercent.toStringAsFixed(1)),
                  style: const TextStyle(
                    color: CupertinoColors.systemBlue,
                    fontSize: 12,
                  ),
                ),
                Text(
                  l10n.tripBudgetRemainingPercent(
                    (100 - usedPercent).clamp(0, 100).toStringAsFixed(1),
                  ),
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (summary.remainingPerDay != null) ...<Widget>[
              const SizedBox(height: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue
                        .resolveFrom(context)
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(CupertinoIcons.chart_bar_alt_fill, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.tripDailyBudgetApprox(
                                money(summary.remainingPerDay),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              l10n.tripDailyBudgetHint,
                              style: TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_forward, size: 14),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    onPressed: onTap,
                    child: Text(l10n.tripViewAction),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemBlue),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onPressed: onRecord,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(CupertinoIcons.pencil, size: 17),
                          const SizedBox(width: 6),
                          Text(l10n.tripRecordAction),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRouteOverview extends StatelessWidget {
  const _TripRouteOverview({required this.stops, required this.activeIndex});

  final List<TripStopModel> stops;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    Widget stopView(int index) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 19,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index == activeIndex
                ? CupertinoColors.systemBlue
                : CupertinoColors.systemBackground.resolveFrom(context),
            border: Border.all(
              color: index <= activeIndex
                  ? CupertinoColors.systemBlue
                  : CupertinoColors.systemGrey3.resolveFrom(context),
            ),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: index == activeIndex
                  ? CupertinoColors.white
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _countryNameForTrip(stops[index].countryCode, context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          '${_formatShortDate(stops[index].startDate, context)} – ${_formatShortDate(stops[index].endDate, context)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        Text(
          stops[index].localCurrency.code,
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemBlue,
          ),
        ),
      ],
    );

    Widget connector({double? width}) => SizedBox(
      width: width,
      child: Container(
        margin: const EdgeInsets.only(top: 9),
        height: 1,
        color: CupertinoColors.systemGrey3.resolveFrom(context),
      ),
    );

    if (stops.length > 3) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < stops.length; index += 1) ...<Widget>[
              if (index > 0) connector(width: 32),
              SizedBox(width: 108, child: stopView(index)),
            ],
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < stops.length; index += 1) ...<Widget>[
          if (index > 0) Expanded(child: connector()),
          Flexible(flex: 2, child: stopView(index)),
        ],
      ],
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  const _BudgetMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsetsDirectional.only(start: 10),
      decoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

class _CompactTripRow extends StatelessWidget {
  const _CompactTripRow({
    required this.trip,
    required this.onTap,
    required this.onMore,
  });
  final TripModel trip;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => _Surface(
    child: Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBlue
                .resolveFrom(context)
                .withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(CupertinoIcons.briefcase, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            alignment: AlignmentDirectional.centerStart,
            onPressed: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  trip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_formatShortDate(trip.startDate, context)} – ${_formatShortDate(trip.endDate, context)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        CupertinoButton(
          minimumSize: const Size.square(30),
          padding: EdgeInsets.zero,
          onPressed: onMore,
          child: const Icon(CupertinoIcons.ellipsis, size: 18),
        ),
        const Icon(CupertinoIcons.chevron_forward, size: 14),
      ],
    ),
  );
}

class _GroupedSurface extends StatelessWidget {
  const _GroupedSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
        context,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: CupertinoColors.separator.resolveFrom(context),
        width: 0.35,
      ),
    ),
    child: child,
  );
}

class _TripStopEditorRow extends StatelessWidget {
  const _TripStopEditorRow({
    required this.index,
    required this.stop,
    required this.destination,
    required this.onPressed,
    super.key,
  });

  final int index;
  final TripStopModel stop;
  final String destination;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      CupertinoButton(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        onPressed: onPressed,
        child: Row(
          children: <Widget>[
            Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == 0
                    ? CupertinoColors.systemBlue
                    : CupertinoColors.systemGrey,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    destination,
                    style: const TextStyle(
                      color: CupertinoColors.label,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatShortDate(stop.startDate, context)} – ${_formatShortDate(stop.endDate, context)} · ${stop.localCurrency.code}',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  CupertinoIcons.circle_grid_3x3_fill,
                  size: 18,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward, size: 14),
          ],
        ),
      ),
      const _EditorDivider(indent: 53),
    ],
  );
}

class _EditorValueRow extends StatelessWidget {
  const _EditorValueRow({
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  });

  final IconData? icon;
  final String label;
  final String value;
  final VoidCallback onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    onPressed: onPressed,
    child: Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          expanded
              ? CupertinoIcons.chevron_down
              : CupertinoIcons.chevron_forward,
          size: 14,
          color: CupertinoColors.systemGrey.resolveFrom(context),
        ),
      ],
    ),
  );
}

class _EditorInputRow extends StatelessWidget {
  const _EditorInputRow({
    required this.label,
    required this.controller,
    this.icon,
    this.numeric = false,
    this.placeholder,
    this.onChanged,
  });

  final IconData? icon;
  final String label;
  final TextEditingController controller;
  final bool numeric;
  final String? placeholder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    child: Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 20, color: CupertinoColors.systemBlue),
          const SizedBox(width: 10),
        ],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoTextField.borderless(
            controller: controller,
            placeholder: placeholder,
            textAlign: TextAlign.end,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _EditorActionRow extends StatelessWidget {
  const _EditorActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 20, color: CupertinoColors.systemBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: CupertinoColors.systemBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ),
        const Icon(CupertinoIcons.chevron_forward, size: 14),
      ],
    ),
  );
}

class _EditorDivider extends StatelessWidget {
  const _EditorDivider({this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsetsDirectional.only(start: indent),
    height: 0.5,
    color: CupertinoColors.separator.resolveFrom(context),
  );
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(CupertinoIcons.airplane, size: 44),
            const SizedBox(height: AppSpacing.medium),
            Text(l10n.tripsSubtitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.medium),
            CupertinoButton.filled(
              onPressed: onCreate,
              child: Text(l10n.tripCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: child,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

String _formatShortDate(DateTime date, BuildContext context) {
  return DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(date);
}

DecimalValue? _tryParseDecimal(String value) {
  if (value.isEmpty) return null;
  try {
    return DecimalValue.parse(value);
  } on FormatException {
    return null;
  }
}

String _countryNameForTrip(String code, BuildContext context) {
  return CountryDirectory().displayNameForCode(
    code,
    Localizations.localeOf(context).languageCode,
  );
}

String _share(Money value, Money total) {
  if (total.amount.isZero) return '0.0';
  return (value.amount.divide(total.amount) * DecimalValue.parse('100'))
      .toFixed(1);
}

String _tripCategoryLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'food' => l10n.categoryFood,
      'transport' => l10n.categoryTransport,
      'shopping' => l10n.categoryShopping,
      'hotel' => l10n.categoryHotel,
      'tickets' => l10n.categoryTickets,
      _ => l10n.categoryOther,
    };
