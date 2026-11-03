import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:trip_cost/app/locale_controller.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/export/expense_export_service.dart';
import 'package:trip_cost/core/infrastructure/app_providers.dart';
import 'package:trip_cost/core/storage/backup/backup_service.dart';
import 'package:trip_cost/core/storage/data_reset_coordinator.dart';
import 'package:trip_cost/core/storage/files/receipt_storage.dart';
import 'package:trip_cost/features/startup/application/startup_controller.dart';
import 'package:trip_cost/features/startup/data/startup_state_store.dart';

final documentPlatformGatewayProvider = Provider<DocumentPlatformGateway>(
  (ref) => const MethodChannelDocumentPlatformGateway(),
);

final expenseExportServiceProvider = Provider<ExpenseExportService>((ref) {
  return ExpenseExportService(
    expenseRepository: ref.watch(expenseRepositoryProvider),
    platformGateway: ref.watch(documentPlatformGatewayProvider),
  );
});

final settingsDataServiceProvider = Provider<SettingsDataService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final gateway = ref.watch(documentPlatformGatewayProvider);
  return SettingsDataService(
    backupService: BackupService(database),
    resetCoordinator: DataResetCoordinator(
      database: database,
      receiptStorage: ref.watch(receiptStorageProvider),
      sharedSnapshotStore: ref.watch(widgetSnapshotServiceProvider),
    ),
    platformGateway: gateway,
    startupStateStore: ref.watch(startupStateStoreProvider),
    onDataReplaced: () async {
      final mode =
          (await ref.read(settingsRepositoryProvider).load())?.languageMode ??
          AppLanguageMode.system;
      ref.invalidate(localeControllerProvider);
      ref.read(localeControllerProvider.notifier).setMode(mode);
    },
  );
});

final class SettingsDataService {
  SettingsDataService({
    required BackupService backupService,
    required DataResetCoordinator resetCoordinator,
    required DocumentPlatformGateway platformGateway,
    required StartupStateStore startupStateStore,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
    Future<void> Function()? onDataReplaced,
  }) : _backupService = backupService,
       _resetCoordinator = resetCoordinator,
       _platformGateway = platformGateway,
       _startupStateStore = startupStateStore,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _onDataReplaced = onDataReplaced ?? _noop;

  final BackupService _backupService;
  final DataResetCoordinator _resetCoordinator;
  final DocumentPlatformGateway _platformGateway;
  final StartupStateStore _startupStateStore;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _clock;
  final Future<void> Function() _onDataReplaced;

  Future<File> createBackup() async {
    final directory = await _temporaryDirectory();
    final stamp = _clock().toLocal().toIso8601String().replaceAll(':', '-');
    final file = File(path.join(directory.path, 'rhinosmart-backup-$stamp.json'));
    await _backupService.exportTo(file);
    return file;
  }

  Future<void> shareBackup(File backup) =>
      _platformGateway.shareFiles(<String>[backup.path]);

  Future<bool> pickAndRestoreBackup() async {
    final selected = await _platformGateway.pickBackupFile();
    if (selected == null) return false;
    await _backupService.restoreFrom(File(selected));
    await _onDataReplaced();
    return true;
  }

  Future<ReceiptClearReport> clearReceiptImages() =>
      _resetCoordinator.clearReceiptImages();

  DataResetConfirmation requestFullReset() =>
      _resetCoordinator.requestConfirmation();

  Future<void> clearAllData(DataResetConfirmation confirmation) async {
    await _resetCoordinator.clearAllData(confirmationToken: confirmation.token);
    await _startupStateStore.resetOnboarding();
    await _onDataReplaced();
  }
}

Future<void> _noop() => Future<void>.value();
