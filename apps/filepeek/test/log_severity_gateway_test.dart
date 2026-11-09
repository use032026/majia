import 'dart:convert';
import 'dart:typed_data';

import 'package:filerecheck/src/data/file_gateway.dart';
import 'package:filerecheck/src/domain/filerecheck_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show FakeGateway, readyApp;

class _FailingGateway extends FakeGateway {
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<ImportedFile?> pickFile() {
    if (failRead) throw StateError('Synthetic file-read failure');
    return super.pickFile();
  }

  @override
  Future<void> shareFile(String fileName, Uint8List bytes, Rect anchor) {
    if (failWrite) throw StateError('Synthetic export-write failure');
    return super.shareFile(fileName, bytes, anchor);
  }
}

void main() {
  const source = 'INFO original\nWARN source';
  const edited = 'ERROR edited\nDEBUG retry';
  const failureText = 'The action failed. Retry or choose another file.';

  testWidgets(
    'fake read failure preserves edited log and source bytes, then replacement recovers',
    (tester) async {
      final sourceBytes = Uint8List.fromList(utf8.encode(source));
      final document = FileRecheckDocument.inspect(
        fileName: 'original.log',
        bytes: sourceBytes,
      )..replaceWorkingText(edited);
      final gateway = _FailingGateway()..failRead = true;
      await tester.pumpWidget(
        readyApp(gateway: gateway, initialDocument: document),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open another file'));
      await tester.pumpAndSettle();
      expect(find.text(failureText), findsOneWidget);
      expect(find.text('original.log'), findsOneWidget);
      expect(document.workingText, edited);
      expect(document.sourceText, source);
      expect(sourceBytes, utf8.encode(source));
      expect(document.lines.map((line) => line.severity).toList(), [
        LogSeverity.error,
        LogSeverity.debug,
      ]);

      gateway.failRead = false;
      gateway.nextPick = ImportedFile(
        'retry.log',
        Uint8List.fromList(sourceBytes),
      );
      await tester.tap(find.byTooltip('Open another file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('retry.log'), findsOneWidget);
      expect(find.text(failureText), findsNothing);
      await tester.tap(find.text('Export copy'));
      await tester.pumpAndSettle();
      expect(gateway.exportedBytes, sourceBytes);
      expect(gateway.exportedName, 'retry_checked.log');
      expect(document.sourceText, source);
      expect(sourceBytes, utf8.encode(source));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fake export failure preserves source and working severity, then retry exports exact copy',
    (tester) async {
      final sourceBytes = Uint8List.fromList(utf8.encode(source));
      final document = FileRecheckDocument.inspect(
        fileName: 'original.log',
        bytes: sourceBytes,
      )..replaceWorkingText(edited);
      final gateway = _FailingGateway()..failWrite = true;
      await tester.pumpWidget(
        readyApp(gateway: gateway, initialDocument: document),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export copy'));
      await tester.pumpAndSettle();
      expect(find.text(failureText), findsOneWidget);
      expect(gateway.exportedBytes, isNull);
      expect(document.workingText, edited);
      expect(document.sourceText, source);
      expect(sourceBytes, utf8.encode(source));

      gateway.failWrite = false;
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Export copy'));
        await tester.pumpAndSettle();
        expect(gateway.exportedBytes, utf8.encode(edited));
        expect(gateway.exportedName, 'original_checked.log');
        expect(document.lines.map((line) => line.severity).toList(), [
          LogSeverity.error,
          LogSeverity.debug,
        ]);
        expect(document.sourceText, source);
        expect(sourceBytes, utf8.encode(source));
      }
      expect(gateway.sharedCount, 2);
      expect(find.text(failureText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
