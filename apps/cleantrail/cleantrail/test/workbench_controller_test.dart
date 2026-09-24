import 'dart:io';

import 'package:cleantrail/data/csv_gateway.dart';
import 'package:cleantrail/data/project_store.dart';
import 'package:cleantrail/domain/data_project.dart';
import 'package:cleantrail/domain/quality_engine.dart';
import 'package:cleantrail/state/workbench_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_csv_gateway.dart';

void main() {
  test('undo restores the prior working copy and persists it', () async {
    final store = MemoryProjectStore();
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: store,
      gateway: FakeCsvGateway(),
    );
    await controller.loadSample();
    final issue = controller.project!.issues.firstWhere(
      (item) => item.suggestion != null,
    );
    final before = controller.project;

    await controller.resolveIssue(issue.id);
    expect(controller.canUndo, isTrue);
    expect(controller.project, isNot(same(before)));

    await controller.undo();
    expect(controller.project, same(before));
    expect(store.value, same(before));
  });

  test('export gateway receives both deliverables', () async {
    final gateway = FakeCsvGateway();
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: MemoryProjectStore(),
      gateway: gateway,
    );
    await controller.loadSample();

    final outcome = await controller.export(chinese: true);

    expect(outcome, ExportOutcome.completed);
    expect(gateway.exportedBaseName, 'quality_sample');
    expect(gateway.exportedCsv, contains('date,value,region'));
    expect(gateway.exportedReport, contains('数据质量报告'));
    expect(gateway.exportedComplete, isFalse);
  });

  test(
    'export reports gateway failures without changing the project',
    () async {
      final gateway = FakeCsvGateway(exportError: StateError('share failed'));
      final controller = WorkbenchController(
        engine: const QualityEngine(),
        store: MemoryProjectStore(),
        gateway: gateway,
      );
      await controller.loadSample();
      final before = controller.project;

      final outcome = await controller.export(chinese: false);

      expect(outcome, ExportOutcome.failed);
      expect(controller.project, same(before));
      expect(controller.busy, isFalse);
    },
  );

  test('Excel source names export as clean CSV base names', () async {
    final gateway = FakeCsvGateway();
    final store = MemoryProjectStore()
      ..value = const QualityEngine().importCsv(
        fileName: 'quarterly.xlsx',
        source: 'region,amount\nNorth,12\nSouth,14\n',
      );
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: store,
      gateway: gateway,
    );
    await controller.load();

    await controller.export(chinese: false);

    expect(gateway.exportedBaseName, 'quarterly');
  });

  test('failed save keeps the current project and undo state', () async {
    final store = _ControllableStore();
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: store,
      gateway: FakeCsvGateway(),
    );
    await controller.loadSample();
    final before = controller.project;
    final issue = before!.openIssues.firstWhere(
      (item) => item.suggestion != null,
    );
    store.failSave = true;

    await controller.resolveIssue(issue.id);

    expect(controller.project, same(before));
    expect(controller.canUndo, isFalse);
    expect(controller.errorCode, 'saveFailed');
  });

  test('failed clear keeps the project visible', () async {
    final store = _ControllableStore();
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: store,
      gateway: FakeCsvGateway(),
    );
    await controller.loadSample();
    final before = controller.project;
    store.failClear = true;

    await controller.clear();

    expect(controller.project, same(before));
    expect(controller.errorCode, 'clearFailed');
  });

  test('failed restore always releases busy state', () async {
    final store = _ControllableStore()..failLoad = true;
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: store,
      gateway: FakeCsvGateway(),
    );

    await controller.load();

    expect(controller.busy, isFalse);
    expect(controller.errorCode, 'restoreFailed');
  });
}

class _ControllableStore implements ProjectStore {
  DataProject? value;
  bool failLoad = false;
  bool failSave = false;
  bool failClear = false;

  @override
  Future<void> clear() async {
    if (failClear) throw const FileSystemException('clear failed');
    value = null;
  }

  @override
  Future<DataProject?> load() async {
    if (failLoad) throw const FileSystemException('load failed');
    return value;
  }

  @override
  Future<void> save(DataProject project) async {
    if (failSave) throw const FileSystemException('save failed');
    value = project;
  }
}
