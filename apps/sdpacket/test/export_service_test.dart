import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moving_box/models/box_record.dart';
import 'package:moving_box/models/moving_project.dart';
import 'package:moving_box/services/export_service.dart';

void main() {
  testWidgets('builds localized Chinese box labels', (tester) async {
    final now = DateTime(2026, 8, 27, 12);
    final project = MovingProject(
      id: 'project-label',
      name: '跨城搬家',
      boxPrefix: 'C',
      nextSequence: 2,
      createdAt: now,
      updatedAt: now,
    );
    final box = BoxRecord(
      id: 'box-label',
      projectId: project.id,
      shortCode: 'C-001',
      createdAt: now,
      updatedAt: now,
    );

    final bytes = await tester.runAsync(
      () => const ExportService().buildLabelPdf(
        project,
        [box],
        const BoxLabelPdfLabels(
          documentTitle: 'KIFXPRO 标签',
          brand: 'KIFXPRO',
          scanOrSearchCode: '扫码或搜索箱号',
        ),
      ),
    );

    expect(bytes, isNotNull);
    expect(utf8.decode(bytes!.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  testWidgets('builds closeout statistics and an offline PDF', (tester) async {
    final now = DateTime(2026, 8, 27, 12);
    final project = MovingProject(
      id: 'project-report',
      name: '跨城搬家',
      boxPrefix: 'C',
      nextSequence: 4,
      createdAt: now,
      updatedAt: now,
    );
    final boxes = [
      BoxRecord(
        id: 'box-1',
        projectId: project.id,
        shortCode: 'C-001',
        destinationRoom: '厨房',
        moveStatus: MoveStatus.arrived,
        issues: const {BoxIssue.suspectedMissing},
        createdAt: now,
        updatedAt: now,
      ),
      BoxRecord(
        id: 'box-2',
        projectId: project.id,
        shortCode: 'C-002',
        destinationRoom: '厨房',
        moveStatus: MoveStatus.unpacked,
        issues: const {BoxIssue.damagedBox},
        createdAt: now,
        updatedAt: now,
      ),
      BoxRecord(
        id: 'box-3',
        projectId: project.id,
        shortCode: 'C-003',
        moveStatus: MoveStatus.packed,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final report = ProjectReportData.fromBoxes(boxes);

    expect(report.total, 3);
    expect(report.suspectedMissingCodes, ['C-001']);
    expect(report.damagedCodes, ['C-002']);
    expect(report.notUnpackedCodes, ['C-001', 'C-003']);
    expect(report.roomDistribution, [('厨房', 2), ('', 1)]);

    final bytes = await tester.runAsync(
      () => const ExportService().buildProjectReportPdf(
        project: project,
        boxes: boxes,
        labels: const ProjectReportLabels(
          title: '项目收尾报告',
          generatedAt: '生成时间：2026-08-27',
          total: '总数',
          suspectedMissing: '疑似遗漏',
          damaged: '损坏箱',
          notUnpacked: '未拆箱',
          roomDistribution: '房间分布',
          none: '无',
          unassignedRoom: '未指定房间',
          moreRooms: '其他房间',
        ),
      ),
    );

    expect(bytes, isNotNull);
    expect(utf8.decode(bytes!.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
