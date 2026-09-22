import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/box_record.dart';
import '../models/moving_project.dart';
import 'qr_payload.dart';

class ProjectReportData {
  const ProjectReportData({
    required this.total,
    required this.suspectedMissing,
    required this.damaged,
    required this.notUnpacked,
    required this.suspectedMissingCodes,
    required this.damagedCodes,
    required this.notUnpackedCodes,
    required this.roomDistribution,
  });

  final int total;
  final int suspectedMissing;
  final int damaged;
  final int notUnpacked;
  final List<String> suspectedMissingCodes;
  final List<String> damagedCodes;
  final List<String> notUnpackedCodes;
  final List<(String, int)> roomDistribution;

  factory ProjectReportData.fromBoxes(List<BoxRecord> boxes) {
    final missing = boxes
        .where((box) => box.issues.contains(BoxIssue.suspectedMissing))
        .toList();
    final damaged = boxes
        .where(
          (box) =>
              box.issues.contains(BoxIssue.damagedBox) ||
              box.issues.contains(BoxIssue.damagedContents),
        )
        .toList();
    final notUnpacked = boxes
        .where((box) => box.moveStatus != MoveStatus.unpacked)
        .toList();
    final roomCounts = <String, int>{};
    for (final box in boxes) {
      final room = box.destinationRoom.trim();
      roomCounts[room] = (roomCounts[room] ?? 0) + 1;
    }
    final distribution =
        roomCounts.entries.map((entry) => (entry.key, entry.value)).toList()
          ..sort((a, b) {
            final count = b.$2.compareTo(a.$2);
            return count == 0 ? a.$1.compareTo(b.$1) : count;
          });
    return ProjectReportData(
      total: boxes.length,
      suspectedMissing: missing.length,
      damaged: damaged.length,
      notUnpacked: notUnpacked.length,
      suspectedMissingCodes: missing.map((box) => box.shortCode).toList(),
      damagedCodes: damaged.map((box) => box.shortCode).toList(),
      notUnpackedCodes: notUnpacked.map((box) => box.shortCode).toList(),
      roomDistribution: distribution,
    );
  }
}

class ProjectReportLabels {
  const ProjectReportLabels({
    required this.title,
    required this.generatedAt,
    required this.total,
    required this.suspectedMissing,
    required this.damaged,
    required this.notUnpacked,
    required this.roomDistribution,
    required this.none,
    required this.unassignedRoom,
    required this.moreRooms,
  });

  final String title;
  final String generatedAt;
  final String total;
  final String suspectedMissing;
  final String damaged;
  final String notUnpacked;
  final String roomDistribution;
  final String none;
  final String unassignedRoom;
  final String moreRooms;
}

class BoxLabelPdfLabels {
  const BoxLabelPdfLabels({
    required this.documentTitle,
    required this.brand,
    required this.scanOrSearchCode,
  });

  final String documentTitle;
  final String brand;
  final String scanOrSearchCode;
}

class ExportService {
  const ExportService();

  Uint8List buildCsv(MovingProject project, List<BoxRecord> boxes) {
    final rows = <List<String>>[
      const [
        'code',
        'title',
        'destination_room',
        'current_location',
        'memo',
        'tags',
        'items',
        'priority',
        'move_status',
        'physical_mark_status',
        'physical_mark_method',
        'issues',
        'created_at',
        'updated_at',
      ],
      ...boxes.map(
        (box) => [
          box.shortCode,
          box.title,
          box.destinationRoom,
          box.currentLocation,
          box.memo,
          box.tags.join('|'),
          box.items.map((item) => item.name).join('|'),
          box.isPriority.toString(),
          box.moveStatus.name,
          box.physicalMarkStatus.name,
          box.physicalMarkMethod?.name ?? '',
          box.issues.map((issue) => issue.name).join('|'),
          box.createdAt.toIso8601String(),
          box.updatedAt.toIso8601String(),
        ],
      ),
    ];
    final content = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(content)]);
  }

  Future<Uint8List> buildLabelPdf(
    MovingProject project,
    List<BoxRecord> boxes,
    BoxLabelPdfLabels labels,
  ) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansSC-VF.ttf');
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(
      title: labels.documentTitle,
      author: labels.brand,
    );
    final chunks = <List<BoxRecord>>[];
    for (var index = 0; index < boxes.length; index += 10) {
      chunks.add(boxes.sublist(index, (index + 10).clamp(0, boxes.length)));
    }
    for (final chunk in chunks) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: font, bold: font),
          build: (_) => pw.GridView(
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            children: chunk
                .map(
                  (box) => _label(project: project, box: box, labels: labels),
                )
                .toList(),
          ),
        ),
      );
    }
    return document.save();
  }

  Future<Uint8List> buildProjectReportPdf({
    required MovingProject project,
    required List<BoxRecord> boxes,
    required ProjectReportLabels labels,
  }) async {
    final data = ProjectReportData.fromBoxes(boxes);
    final fontData = await rootBundle.load('assets/fonts/NotoSansSC-VF.ttf');
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(title: labels.title, author: 'KIFXPRO');
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              labels.title,
              style: pw.TextStyle(
                fontSize: 25,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#183A31'),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              project.name,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              labels.generatedAt,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('#5E6965'),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              children: [
                _reportMetric(
                  labels.total,
                  data.total,
                  PdfColor.fromHex('#E1EFE9'),
                ),
                pw.SizedBox(width: 7),
                _reportMetric(
                  labels.suspectedMissing,
                  data.suspectedMissing,
                  PdfColor.fromHex('#FFE5D2'),
                ),
                pw.SizedBox(width: 7),
                _reportMetric(
                  labels.damaged,
                  data.damaged,
                  PdfColor.fromHex('#F8DCDC'),
                ),
                pw.SizedBox(width: 7),
                _reportMetric(
                  labels.notUnpacked,
                  data.notUnpacked,
                  PdfColor.fromHex('#E5E7F5'),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            _reportCodeSection(
              labels.suspectedMissing,
              data.suspectedMissingCodes,
              labels.none,
            ),
            _reportCodeSection(labels.damaged, data.damagedCodes, labels.none),
            _reportCodeSection(
              labels.notUnpacked,
              data.notUnpackedCodes,
              labels.none,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              labels.roomDistribution,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 9),
            ..._reportRoomRows(data, labels),
          ],
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _reportMetric(String label, int value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        height: 72,
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$value',
              style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  pw.Widget _reportCodeSection(String title, List<String> codes, String none) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 13),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            codes.isEmpty ? none : codes.join(' · '),
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#4A5753'),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _reportRoomRows(
    ProjectReportData data,
    ProjectReportLabels labels,
  ) {
    final rooms = data.roomDistribution.take(10).toList();
    final remainingRoomCount = data.roomDistribution
        .skip(10)
        .fold<int>(0, (sum, room) => sum + room.$2);
    if (remainingRoomCount > 0) {
      rooms.add((labels.moreRooms, remainingRoomCount));
    }
    if (rooms.isEmpty) {
      return [pw.Text(labels.none, style: const pw.TextStyle(fontSize: 10))];
    }
    final maxCount = rooms
        .map((room) => room.$2)
        .reduce((a, b) => a > b ? a : b);
    return rooms.map((room) {
      final name = room.$1.isEmpty ? labels.unassignedRoom : room.$1;
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 112,
              child: pw.Text(
                name,
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 330,
              child: pw.Container(
                height: 10,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E4EAE7'),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    width: 330 * room.$2 / maxCount,
                    height: 10,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#5D8B7C'),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 30,
              child: pw.Text(
                '${room.$2}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  pw.Widget _label({
    required MovingProject project,
    required BoxRecord box,
    required BoxLabelPdfLabels labels,
  }) {
    final payload = BoxQrPayload(
      projectId: project.id,
      boxId: box.id,
      code: box.shortCode,
    ).encode();
    return pw.Container(
      margin: const pw.EdgeInsets.all(5),
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.black, width: 1.2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  labels.brand,
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  box.shortCode,
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  labels.scanOrSearchCode,
                  maxLines: 2,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ],
            ),
          ),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: payload,
            width: 88,
            height: 88,
            drawText: false,
          ),
        ],
      ),
    );
  }
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
