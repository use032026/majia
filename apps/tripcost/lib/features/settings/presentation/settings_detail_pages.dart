import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_cost/app/router/app_routes.dart';
import 'package:trip_cost/app/theme/app_theme.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/export/expense_export_service.dart';
import 'package:trip_cost/core/infrastructure/app_providers.dart';
import 'package:trip_cost/core/sync/domain/sync_models.dart';
import 'package:trip_cost/features/converter/application/converter_controller.dart';
import 'package:trip_cost/features/expense/application/expenses_controller.dart';
import 'package:trip_cost/features/payment_method/application/payment_methods_controller.dart';
import 'package:trip_cost/features/settings/application/general_settings_controller.dart';
import 'package:trip_cost/features/settings/application/settings_data_service.dart';
import 'package:trip_cost/features/settings/application/sync_settings_controller.dart';
import 'package:trip_cost/features/settings/presentation/privacy_policy_launcher.dart';
import 'package:trip_cost/features/trip/application/trips_controller.dart';
import 'package:trip_cost/l10n/app_localizations.dart';
import 'package:trip_cost/shared/widgets/currency_picker_page.dart';

class CurrencyAndRatesSettingsPage extends ConsumerWidget {
  const CurrencyAndRatesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final settingsState = ref.watch(generalSettingsControllerProvider);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(localizations.rateSettingsTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: settingsState.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) =>
              Center(child: Text(localizations.settingsLoadFailed)),
          data: (settings) => ListView(
            key: const Key('currency-rates-settings-list'),
            padding: AppInsets.secondaryPageScrollPadding(context),
            children: <Widget>[
              _DetailGroup(
                children: <Widget>[
                  _DetailNavigationRow(
                    key: const Key('default-currency-setting'),
                    icon: CupertinoIcons.money_dollar_circle,
                    title: localizations.defaultCurrency,
                    value: settings.defaultCurrency.code,
                    onPressed: () =>
                        _chooseDefaultCurrency(context, ref, settings),
                  ),
                  _DetailNavigationRow(
                    key: const Key('refresh-interval-setting'),
                    icon: CupertinoIcons.refresh,
                    title: localizations.refreshInterval,
                    value: localizations.refreshEveryHours(
                      settings.refreshInterval.inHours,
                    ),
                    onPressed: () =>
                        _chooseRefreshInterval(context, ref, settings),
                  ),
                  _DetailSwitchRow(
                    icon: CupertinoIcons.wifi,
                    title: localizations.wifiOnlyRefresh,
                    value: settings.wifiOnlyRefresh,
                    onChanged: (value) => _setWifiOnlyRefresh(ref, value),
                  ),
                  _DetailValueRow(
                    icon: CupertinoIcons.number,
                    title: localizations.decimalDisplayRule,
                    value: localizations.decimalDisplayCurrencyDefault,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseDefaultCurrency(
    BuildContext context,
    WidgetRef ref,
    UserSettingsModel settings,
  ) async {
    final result = await showCurrencyPickerPage(
      context: context,
      title: AppLocalizations.of(context).defaultCurrency,
      selected: settings.defaultCurrency,
    );
    if (result?.currency case final selected?) {
      if (!context.mounted) return;
      await ref
          .read(generalSettingsControllerProvider.notifier)
          .setDefaultCurrency(selected);
      ref.invalidate(converterControllerProvider);
    }
  }

  Future<void> _chooseRefreshInterval(
    BuildContext context,
    WidgetRef ref,
    UserSettingsModel settings,
  ) async {
    const values = <Duration>[
      Duration(hours: 1),
      Duration(hours: 6),
      Duration(hours: 24),
    ];
    final selected = await showCupertinoModalPopup<Duration>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return CupertinoActionSheet(
          title: Text(localizations.refreshInterval),
          actions: <Widget>[
            for (final value in values)
              CupertinoActionSheetAction(
                isDefaultAction: settings.refreshInterval == value,
                onPressed: () => Navigator.of(context).pop(value),
                child: Text(localizations.refreshEveryHours(value.inHours)),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.commonCancel),
          ),
        );
      },
    );
    if (selected == null) return;
    await ref
        .read(generalSettingsControllerProvider.notifier)
        .setRefreshInterval(selected);
    ref.invalidate(converterControllerProvider);
  }

  Future<void> _setWifiOnlyRefresh(WidgetRef ref, bool value) async {
    await ref
        .read(generalSettingsControllerProvider.notifier)
        .setWifiOnlyRefresh(value);
    ref.invalidate(converterControllerProvider);
  }
}

class CloudSyncSettingsPage extends ConsumerWidget {
  const CloudSyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final syncState = ref.watch(syncSettingsControllerProvider);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(localizations.syncTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: syncState.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) => Center(child: Text(localizations.syncStatusFailed)),
          data: (value) => ListView(
            key: const Key('icloud-sync-settings-list'),
            padding: AppInsets.secondaryPageScrollPadding(context),
            children: <Widget>[
              _SyncSettingsContent(
                value: value,
                onToggle: ref
                    .read(syncSettingsControllerProvider.notifier)
                    .setEnabled,
                onSyncNow: ref
                    .read(syncSettingsControllerProvider.notifier)
                    .synchronizeNow,
                onResolve: (conflict, useRemote) => ref
                    .read(syncSettingsControllerProvider.notifier)
                    .resolveConflict(conflict, useRemoteValue: useRemote),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final settingsState = ref.watch(generalSettingsControllerProvider);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(localizations.languageTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: settingsState.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) =>
              Center(child: Text(localizations.settingsLoadFailed)),
          data: (settings) => ListView(
            key: const Key('language-settings-list'),
            padding: AppInsets.secondaryPageScrollPadding(context),
            children: <Widget>[
              _DetailGroup(
                children: <Widget>[
                  _SelectionRow(
                    title: localizations.systemLanguage,
                    selected: settings.languageMode == AppLanguageMode.system,
                    onPressed: () => _setLanguage(ref, AppLanguageMode.system),
                  ),
                  _SelectionRow(
                    title: localizations.simplifiedChinese,
                    selected:
                        settings.languageMode ==
                        AppLanguageMode.simplifiedChinese,
                    onPressed: () =>
                        _setLanguage(ref, AppLanguageMode.simplifiedChinese),
                  ),
                  _SelectionRow(
                    title: localizations.english,
                    selected: settings.languageMode == AppLanguageMode.english,
                    onPressed: () => _setLanguage(ref, AppLanguageMode.english),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setLanguage(WidgetRef ref, AppLanguageMode mode) {
    return ref
        .read(generalSettingsControllerProvider.notifier)
        .setLanguage(mode);
  }
}

class DataSettingsPage extends ConsumerStatefulWidget {
  const DataSettingsPage({super.key});

  @override
  ConsumerState<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends ConsumerState<DataSettingsPage> {
  bool _operationInProgress = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(localizations.dataTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: const Key('data-settings-list'),
          padding: AppInsets.secondaryPageScrollPadding(context),
          children: <Widget>[
            _DetailGroup(
              children: <Widget>[
                _DetailNavigationRow(
                  icon: CupertinoIcons.table,
                  title: localizations.exportCsv,
                  onPressed: _operationInProgress
                      ? null
                      : () => _export(ExpenseExportFormat.csv),
                ),
                _DetailNavigationRow(
                  icon: CupertinoIcons.doc_richtext,
                  title: localizations.exportPdf,
                  onPressed: _operationInProgress
                      ? null
                      : () => _export(ExpenseExportFormat.pdf),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            _DetailGroup(
              children: <Widget>[
                _DetailNavigationRow(
                  icon: CupertinoIcons.archivebox,
                  title: localizations.backupCreate,
                  onPressed: _operationInProgress ? null : _createBackup,
                ),
                _DetailNavigationRow(
                  icon: CupertinoIcons.arrow_down_doc,
                  title: localizations.backupRestore,
                  onPressed: _operationInProgress ? null : _restoreBackup,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            _DetailGroup(
              children: <Widget>[
                _DetailNavigationRow(
                  icon: CupertinoIcons.photo_on_rectangle,
                  title: localizations.clearReceiptImages,
                  onPressed: _operationInProgress ? null : _clearReceiptImages,
                ),
                _DetailNavigationRow(
                  icon: CupertinoIcons.delete,
                  title: localizations.clearAllData,
                  destructive: true,
                  onPressed: _operationInProgress ? null : _clearAllData,
                ),
              ],
            ),
            if (_operationInProgress)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.medium),
                child: Center(child: CupertinoActivityIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(ExpenseExportFormat format) async {
    final localizations = AppLocalizations.of(context);
    await _runOperation(() async {
      final service = ref.read(expenseExportServiceProvider);
      final locale = Localizations.localeOf(context).toLanguageTag();
      final file = format == ExpenseExportFormat.csv
          ? await service.createCsv(locale: locale)
          : await service.createPdf(locale: locale);
      await service.share(file);
    }, failure: localizations.exportFailed);
  }

  Future<void> _createBackup() async {
    final localizations = AppLocalizations.of(context);
    await _runOperation(() async {
      final service = ref.read(settingsDataServiceProvider);
      final backup = await service.createBackup();
      await service.shareBackup(backup);
    }, failure: localizations.backupFailed);
  }

  Future<void> _restoreBackup() async {
    final localizations = AppLocalizations.of(context);
    if (!await _confirm(
      localizations.backupRestoreTitle,
      localizations.backupRestoreMessage,
    )) {
      return;
    }
    await _runOperation(() async {
      final restored = await ref
          .read(settingsDataServiceProvider)
          .pickAndRestoreBackup();
      if (!restored || !mounted) return;
      _invalidateDataControllers();
      try {
        await ref.read(widgetSnapshotServiceProvider).refresh();
      } on Object {
        // Restored local data remains valid when Widget sharing is unavailable.
      }
      await _showNotice(localizations.backupRestored);
    }, failure: localizations.backupRestoreFailed);
  }

  Future<void> _clearReceiptImages() async {
    final localizations = AppLocalizations.of(context);
    if (!await _confirm(
      localizations.clearReceiptImagesTitle,
      localizations.clearReceiptImagesMessage,
      destructive: true,
    )) {
      return;
    }
    await _runOperation(() async {
      final report = await ref
          .read(settingsDataServiceProvider)
          .clearReceiptImages();
      if (!report.succeeded) throw StateError('receipt-clear-failed');
      if (mounted) {
        await _showNotice(localizations.clearReceiptImagesDone);
      }
    }, failure: localizations.clearDataFailed);
  }

  Future<void> _clearAllData() async {
    final localizations = AppLocalizations.of(context);
    if (!await _confirm(
      localizations.clearAllDataTitle,
      localizations.clearAllDataMessage,
      destructive: true,
    )) {
      return;
    }
    final service = ref.read(settingsDataServiceProvider);
    final confirmation = service.requestFullReset();
    if (!await _confirm(
      localizations.clearAllDataAgainTitle,
      localizations.clearAllDataAgainMessage,
      destructive: true,
    )) {
      return;
    }
    await _runOperation(() async {
      await service.clearAllData(confirmation);
      if (!mounted) return;
      context.go(AppRoutes.onboarding);
      await Future<void>.delayed(Duration.zero);
      _invalidateDataControllers();
    }, failure: localizations.clearDataFailed);
  }

  void _invalidateDataControllers() {
    ref.invalidate(generalSettingsControllerProvider);
    ref.invalidate(syncSettingsControllerProvider);
    ref.invalidate(converterControllerProvider);
    ref.invalidate(paymentMethodsControllerProvider);
    ref.invalidate(tripsControllerProvider);
    ref.invalidate(expensesControllerProvider);
  }

  Future<void> _runOperation(
    Future<void> Function() operation, {
    required String failure,
  }) async {
    setState(() => _operationInProgress = true);
    try {
      await operation();
    } on ExpenseExportException catch (error) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      await _showNotice(switch (error.code) {
        ExpenseExportException.empty => localizations.exportEmpty,
        ExpenseExportException.tooLarge => localizations.exportTooLarge,
        _ => failure,
      });
    } on Object {
      if (mounted) await _showNotice(failure);
    } finally {
      if (mounted) setState(() => _operationInProgress = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    bool destructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).commonContinue),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showNotice(String message) => showCupertinoDialog<void>(
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

class PrivacySettingsPage extends ConsumerWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final languageMode = ref.watch(
      generalSettingsControllerProvider.select(
        (state) => state.value?.languageMode,
      ),
    );
    final privacyPolicyUri = privacyPolicyUriFor(
      languageMode: languageMode,
      systemLocale: Localizations.localeOf(context),
    );
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(localizations.privacyTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: const Key('privacy-settings-list'),
          padding: AppInsets.secondaryPageScrollPadding(context),
          children: <Widget>[
            _DetailGroup(
              children: <Widget>[
                _DetailNavigationRow(
                  icon: CupertinoIcons.hand_raised,
                  title: localizations.privacyPolicyTitle,
                  onPressed: () => _openPrivacyPolicy(
                    context,
                    privacyPolicyUri,
                    localizations.privacyPolicyTitle,
                  ),
                ),
                _DetailNavigationRow(
                  icon: CupertinoIcons.info_circle,
                  title: localizations.disclaimerTitle,
                  onPressed: () => _showLongText(
                    context,
                    localizations.disclaimerTitle,
                    localizations.disclaimerBody,
                  ),
                ),
                _DetailNavigationRow(
                  icon: CupertinoIcons.lock_shield,
                  title: localizations.permissionsTitle,
                  onPressed: () => _showLongText(
                    context,
                    localizations.permissionsTitle,
                    localizations.permissionsBody,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(
    BuildContext context,
    Uri uri,
    String title,
  ) async {
    try {
      await openPrivacyPolicy(uri, title: title);
      return;
    } on Object {
      // The user receives the same localized failure message for launch errors.
    }
    if (!context.mounted) return;
    final localizations = AppLocalizations.of(context);
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(localizations.privacyPolicyLoadFailed),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.commonDone),
          ),
        ],
      ),
    );
  }

  Future<void> _showLongText(BuildContext context, String title, String body) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoPopupSurface(
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: CupertinoTheme.of(
                            context,
                          ).textTheme.navTitleTextStyle,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(AppLocalizations.of(context).commonDone),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      0,
                      AppSpacing.medium,
                      AppSpacing.large,
                    ),
                    child: Text(body),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncSettingsContent extends StatelessWidget {
  const _SyncSettingsContent({
    required this.value,
    required this.onToggle,
    required this.onSyncNow,
    required this.onResolve,
  });

  final SyncSettingsState value;
  final ValueChanged<bool> onToggle;
  final Future<void> Function() onSyncNow;
  final Future<void> Function(SyncConflictModel, bool) onResolve;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final runtime = value.runtime;
    final secondaryStyle = TextStyle(
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
      fontSize: 14,
      height: 1.35,
    );
    return _DetailGroup(
      children: <Widget>[
        _DetailSwitchRow(
          icon: CupertinoIcons.cloud,
          title: localizations.syncEnable,
          value: value.enabled,
          onChanged: onToggle,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_statusLabel(localizations, runtime), style: secondaryStyle),
              if (runtime.lastSuccessAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  localizations.syncLastSuccess(
                    runtime.lastSuccessAt!.toLocal().toString().substring(
                      0,
                      16,
                    ),
                  ),
                  style: secondaryStyle,
                ),
              ],
              if (runtime.lastErrorCode != null) ...[
                const SizedBox(height: 4),
                Text(
                  localizations.syncFailureReason(runtime.lastErrorCode!),
                  style: secondaryStyle,
                ),
              ],
            ],
          ),
        ),
        if (value.enabled)
          _DetailNavigationRow(
            icon: CupertinoIcons.refresh,
            title: localizations.syncNow,
            showChevron: false,
            onPressed: () => onSyncNow(),
          ),
        for (final conflict in value.conflicts)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.systemOrange
                    .resolveFrom(context)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(localizations.syncActualConflict),
                    const SizedBox(height: 4),
                    Text(
                      localizations.syncConflictValues(
                        conflict.localValue ?? '—',
                        conflict.remoteValue ?? '—',
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        CupertinoButton(
                          padding: const EdgeInsets.only(right: 12),
                          onPressed: () => onResolve(conflict, false),
                          child: Text(localizations.syncKeepLocal),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => onResolve(conflict, true),
                          child: Text(localizations.syncUseCloud),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _statusLabel(
    AppLocalizations localizations,
    SyncRuntimeStatus runtime,
  ) {
    if (!value.enabled) return localizations.syncStatusDisabled;
    if (runtime.accountState == SyncAccountState.noAccount) {
      return localizations.syncStatusNoAccount;
    }
    if (runtime.accountState == SyncAccountState.restricted) {
      return localizations.syncStatusRestricted;
    }
    return switch (runtime.phase) {
      SyncPhase.pushing || SyncPhase.pulling => localizations.syncStatusWorking,
      SyncPhase.succeeded => localizations.syncStatusSucceeded,
      SyncPhase.waitingRetry => localizations.syncStatusWaiting,
      SyncPhase.failed => localizations.syncStatusFailed,
      _ => localizations.syncStatusIdle,
    };
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separator = CupertinoColors.separator.resolveFrom(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        child: Column(
          children: <Widget>[
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: SizedBox(
                    height: 0.5,
                    child: ColoredBox(color: separator),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailNavigationRow extends StatelessWidget {
  const _DetailNavigationRow({
    required this.icon,
    required this.title,
    required this.onPressed,
    this.value,
    this.destructive = false,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : AppColors.primary;
    final label = value == null ? title : '$title, $value';
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: CupertinoButton(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onPressed: onPressed,
          child: Row(
            children: <Widget>[
              SizedBox(width: 28, child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: destructive
                        ? color
                        : CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    value!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: AppSpacing.small),
                Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSwitchRow extends StatelessWidget {
  const _DetailSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: title,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 28,
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
              CupertinoSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailValueRow extends StatelessWidget {
  const _DetailValueRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.title,
    required this.selected,
    required this.onPressed,
  });

  final String title;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: ExcludeSemantics(
        child: CupertinoButton(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onPressed: onPressed,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              if (selected)
                const Icon(CupertinoIcons.check_mark, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
