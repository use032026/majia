import 'package:cleantrail/data/csv_gateway.dart';
import 'package:cleantrail/data/project_store.dart';
import 'package:cleantrail/domain/quality_engine.dart';
import 'package:cleantrail/main.dart';
import 'package:cleantrail/state/workbench_controller.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_csv_gateway.dart';

void main() {
  testWidgets('text import confirms detected format before inspection', (
    tester,
  ) async {
    final gateway = FakeCsvGateway(
      nextFile: PickedDataFile(
        fileName: 'regional.tsv',
        bytes: 'region\tamount\nNorth\t12\nSouth\t14\n'.codeUnits,
      ),
    );
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: MemoryProjectStore(),
      gateway: gateway,
    );

    await tester.pumpWidget(CleanTrailApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import data'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm import'), findsOneWidget);
    expect(find.byKey(const Key('import-format-choice')), findsOneWidget);
    expect(find.byKey(const Key('import-encoding-choice')), findsOneWidget);
    expect(find.text('TSV · tab separated'), findsOneWidget);
    expect(find.text('UTF-8'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-dashboard')), findsOneWidget);
    expect(find.text('regional.tsv'), findsOneWidget);
    expect(controller.project!.headers, ['region', 'amount']);
  });

  testWidgets('Excel import offers worksheet selection', (tester) async {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'North');
    workbook['North'].appendRow([
      TextCellValue('region'),
      TextCellValue('amount'),
    ]);
    workbook['North'].appendRow([TextCellValue('North'), IntCellValue(12)]);
    workbook['South'].appendRow([
      TextCellValue('region'),
      TextCellValue('amount'),
    ]);
    workbook['South'].appendRow([TextCellValue('South'), IntCellValue(14)]);
    final gateway = FakeCsvGateway(
      nextFile: PickedDataFile(
        fileName: 'regional.xlsx',
        bytes: workbook.encode()!,
      ),
    );
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: MemoryProjectStore(),
      gateway: gateway,
    );

    await tester.pumpWidget(CleanTrailApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import data'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-sheet-choice')), findsOneWidget);
    expect(find.text('Excel · XLSX'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-sheet-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('South').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-dashboard')), findsOneWidget);
    expect(controller.project!.records.single.values, ['South', '14']);
  });

  testWidgets('sample opens the complete repair workspace in both languages', (
    tester,
  ) async {
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: MemoryProjectStore(),
      gateway: FakeCsvGateway(),
    );

    await tester.pumpWidget(CleanTrailApp(controller: controller));
    await tester.pumpAndSettle();

    final brandMark = tester.widget<Image>(
      find.byKey(const Key('cleantrail-brand-mark')),
    );
    expect(
      (brandMark.image as AssetImage).assetName,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
      'Icon-App-1024x1024@1x.png',
    );
    expect(find.text('A calm checkpoint before analysis'), findsOneWidget);
    expect(find.text('Try built-in sample'), findsOneWidget);

    await tester.ensureVisible(find.text('Try built-in sample'));
    await tester.tap(find.text('Try built-in sample'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-dashboard')), findsOneWidget);
    expect(find.text('quality_sample.csv'), findsOneWidget);
    expect(find.text('Repair queue'), findsOneWidget);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();

    expect(find.text('修复队列'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('数据预览'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.ios_share_outlined));
    await tester.pumpAndSettle();
    expect(find.text('导出文件包'), findsWidgets);
  });

  testWidgets('privacy is reachable and scrollable in the empty workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: MemoryProjectStore(),
      gateway: FakeCsvGateway(),
    );
    await tester.pumpWidget(CleanTrailApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy & data'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & data'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing a repair item by tapping the backdrop is safe', (
    tester,
  ) async {
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: MemoryProjectStore(),
      gateway: FakeCsvGateway(),
    );
    await tester.pumpWidget(CleanTrailApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try built-in sample'));
    await tester.tap(find.text('Try built-in sample'));
    await tester.pumpAndSettle();
    final project = controller.project;

    for (final title in ['Duplicate row', 'Missing value']) {
      final issue = find.text(title).first;
      await tester.ensureVisible(issue);
      await tester.tap(issue);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
      expect(controller.project, same(project));
    }
  });

  testWidgets('bottom safe area stays inside scroll tails and repair sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.view.resetViewInsets();
    });

    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: MemoryProjectStore(),
      gateway: FakeCsvGateway(),
    );
    await tester.pumpWidget(CleanTrailApp(controller: controller));
    await tester.pumpAndSettle();

    final emptyScroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect((emptyScroll.padding! as EdgeInsets).bottom, 70);

    await tester.ensureVisible(find.text('Try built-in sample'));
    await tester.tap(find.text('Try built-in sample'));
    await tester.pumpAndSettle();

    final dashboard = find.byKey(const Key('project-dashboard'));
    expect(tester.getBottomLeft(dashboard).dy, lessThan(844));
    expect(
      tester.getBottomLeft(find.byType(NavigationBar)).dy,
      moreOrLessEquals(844),
    );
    final scroll = tester.widget<CustomScrollView>(dashboard);
    expect(
      ((scroll.slivers.first as SliverPadding).padding as EdgeInsets).bottom,
      greaterThanOrEqualTo(42),
    );

    final issue = find.text('Duplicate row').first;
    await tester.ensureVisible(issue);
    await tester.tap(issue);
    await tester.pumpAndSettle();
    final sheetInsets = find.byKey(const Key('issue-sheet-insets'));
    expect(
      (tester.widget<Padding>(sheetInsets).padding as EdgeInsets).bottom,
      56,
    );

    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Padding>(sheetInsets).padding as EdgeInsets).bottom,
      322,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long project and column names remain readable on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      const fileName = 'quarterly_customer_quality_report_with_full_name.csv';
      const header = 'customer_region_full_descriptive_column_name';
      final store = MemoryProjectStore()
        ..value = const QualityEngine().importCsv(
          fileName: fileName,
          source: '$header,amount\n,12\nNorth,14\n',
        );
      final controller = WorkbenchController(
        engine: const QualityEngine(),
        store: store,
        gateway: FakeCsvGateway(),
      );
      await tester.pumpWidget(CleanTrailApp(controller: controller));
      await tester.pumpAndSettle();

      final fileTitle = tester.widget<Text>(find.text(fileName));
      expect(fileTitle.overflow, isNull);
      expect(fileTitle.maxLines, isNull);
      await tester.scrollUntilVisible(find.text(header), 150);
      expect(find.text(header), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Missing value'));
      await tester.tap(find.text('Missing value'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(find.byIcon(Icons.table_chart_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNWidgets(2));
      expect(find.text(header), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.ios_share_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Export bundle'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the last repair stays reachable in a long queue', (
    tester,
  ) async {
    final rows = List.generate(30, (index) => ',${index + 1}').join('\n');
    final store = MemoryProjectStore()
      ..value = const QualityEngine().importCsv(
        fileName: 'many_rows.csv',
        source: 'name,amount\n$rows\n',
      );
    final controller = WorkbenchController(
      engine: const QualityEngine(),
      store: store,
      gateway: FakeCsvGateway(),
    );
    await tester.pumpWidget(CleanTrailApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Row 30'), 250);
    await tester.ensureVisible(find.text('Row 30'));
    expect(find.text('Row 30'), findsOneWidget);
    await tester.tap(find.text('Row 30'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
