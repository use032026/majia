import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:filerecheck/main.dart';
import 'package:filerecheck/src/data/file_gateway.dart';
import 'package:filerecheck/src/domain/filerecheck_document.dart';
import 'package:filerecheck/src/presentation/intro.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements FileGateway {
  ImportedFile? nextPick;
  Completer<ImportedFile?>? pendingPick;
  int sharedCount = 0;
  String? exportedName;
  Uint8List? exportedBytes;

  @override
  Future<void> clearOldExports() async {}

  @override
  Future<ImportedFile?> pickFile() async {
    if (pendingPick != null) return pendingPick!.future;
    final result = nextPick;
    nextPick = null;
    return result;
  }

  @override
  Future<void> shareFile(String fileName, Uint8List bytes, Rect anchor) async {
    sharedCount++;
    exportedName = fileName;
    exportedBytes = bytes;
  }
}

FileRecheckDocument file(String name, String text) =>
    FileRecheckDocument.inspect(
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(text)),
    );

class MemoryIntroStore implements IntroStore {
  MemoryIntroStore({this.completed = false});

  bool completed;
  bool failOnComplete = false;

  @override
  Future<bool> isComplete() async => completed;

  @override
  Future<void> complete() async {
    if (failOnComplete) throw StateError('Could not save');
    completed = true;
  }
}

Widget readyApp({FileGateway? gateway, FileRecheckDocument? initialDocument}) =>
    FileRecheckApp(
      gateway: gateway,
      initialDocument: initialDocument,
      introStore: MemoryIntroStore(completed: true),
    );

void main() {
  testWidgets('first launch shows guide and saves completion', (tester) async {
    final store = MemoryIntroStore();
    await tester.pumpWidget(
      FileRecheckApp(gateway: FakeGateway(), introStore: store),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open from Files'), findsOneWidget);
    expect(find.text('Inspect a file'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Inspect on your device'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Preview before exporting'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
    expect(find.text('Inspect a file'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      FileRecheckApp(gateway: FakeGateway(), introStore: store),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inspect a file'), findsOneWidget);
    expect(find.text('Open from Files'), findsNothing);
  });

  testWidgets('guide supports Chinese, skip and save retry on narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryIntroStore()..failOnComplete = true;
    await tester.pumpWidget(
      FileRecheckApp(gateway: FakeGateway(), introStore: store),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();
    expect(find.text('选择本机文件'), findsOneWidget);
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(find.text('无法保存引导进度，请重试。'), findsOneWidget);
    expect(find.text('文件快检'), findsNothing);
    expect(tester.takeException(), isNull);

    store.failOnComplete = false;
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
    expect(find.text('文件快检'), findsOneWidget);
  });

  testWidgets('JSON format, undo and export keep source intact', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final document = file('payload.json', '{"a":1}');
    await tester.pumpWidget(
      readyApp(gateway: gateway, initialDocument: document),
    );
    await tester.pumpAndSettle();
    expect(find.text('payload.json'), findsOneWidget);
    expect(document.isModified, isFalse);

    await tester.tap(find.text('Format'));
    await tester.pumpAndSettle();
    expect(document.isModified, isTrue);
    expect(document.workingText, contains('\n'));

    await tester.tap(find.text('Export copy'));
    await tester.pumpAndSettle();
    expect(gateway.exportedName, 'payload_checked.json');
    expect(utf8.decode(gateway.exportedBytes!), contains('\n'));
    expect(document.sourceText, '{"a":1}');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(document.workingText, '{"a":1}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('CSV cell cancel and reopen edits only the copy', (tester) async {
    final document = file('rows.csv', 'name,value\nAlice,1\nBob,2');
    await tester.pumpWidget(
      readyApp(gateway: FakeGateway(), initialDocument: document),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(document.isModified, isFalse);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Carol');
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    expect(document.workingText, contains('Carol'));
    expect(document.sourceText, contains('Alice'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid replacement leaves current file and displays error', (
    tester,
  ) async {
    final gateway = FakeGateway()
      ..nextPick = ImportedFile('broken.txt', Uint8List.fromList([0xff]));
    await tester.pumpWidget(
      readyApp(gateway: gateway, initialDocument: file('ok.json', '{}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open another file'));
    await tester.pumpAndSettle();
    expect(find.text('ok.json'), findsOneWidget);
    expect(find.text('The file is not valid UTF-8 text.'), findsOneWidget);
  });

  testWidgets('language switch shows Chinese actions and report is Chinese', (
    tester,
  ) async {
    final gateway = FakeGateway();
    await tester.pumpWidget(
      readyApp(gateway: gateway, initialDocument: file('ok.log', 'INFO ready')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings and privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch to Chinese'));
    await tester.pumpAndSettle();
    expect(find.text('导出副本'), findsOneWidget);
    await tester.tap(find.text('检查报告'));
    await tester.pumpAndSettle();
    expect(find.text('报告预览'), findsOneWidget);
    expect(find.text('FileRecheck 文件检查报告'), findsOneWidget);
    expect(gateway.sharedCount, 0);
    await tester.tap(find.text('导出报告'));
    await tester.pumpAndSettle();
    expect(gateway.sharedCount, 1);
    expect(gateway.exportedName, 'filerecheck_report.txt');
    expect(find.text('报告预览'), findsOneWidget);
    expect(utf8.decode(gateway.exportedBytes!), contains('检查报告'));
  });

  testWidgets('report preview returns without exporting', (tester) async {
    final gateway = FakeGateway();
    await tester.pumpWidget(
      readyApp(
        gateway: gateway,
        initialDocument: file('sample.json', '{"ready":true}'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report preview'), findsOneWidget);
    expect(find.text('FileRecheck inspection report'), findsOneWidget);
    expect(find.text('File: sample.json'), findsOneWidget);
    expect(gateway.sharedCount, 0);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('sample.json'), findsOneWidget);
    expect(gateway.sharedCount, 0);
    expect(gateway.exportedBytes, isNull);
  });

  testWidgets('settings stay fixed while file actions follow the document', (
    tester,
  ) async {
    await tester.pumpWidget(readyApp(gateway: FakeGateway()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Restore original'), findsNothing);
    expect(find.byTooltip('Close file'), findsNothing);
    await tester.tap(find.byTooltip('Settings and privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to Chinese'), findsOneWidget);
    expect(find.text('Switch appearance'), findsOneWidget);
    expect(find.text('Privacy note'), findsOneWidget);
    expect(find.text('Restore original'), findsNothing);
    expect(find.text('Close file'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      readyApp(
        gateway: FakeGateway(),
        initialDocument: file('ready.json', '{"ok":true}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Restore original'), findsOneWidget);
    expect(find.byTooltip('Close file'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings and privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to Chinese'), findsOneWidget);
    expect(find.text('Switch appearance'), findsOneWidget);
    expect(find.text('Privacy note'), findsOneWidget);
    expect(find.text('Restore original'), findsNothing);
    expect(find.text('Close file'), findsNothing);
  });

  testWidgets('phone-width workspace fits both languages', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final document = file('long-file-name.json', '{"ready":true}');
    document.formatJson();
    await tester.pumpWidget(
      readyApp(gateway: FakeGateway(), initialDocument: document),
    );
    await tester.pumpAndSettle();
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Export copy'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Settings and privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch to Chinese'));
    await tester.pumpAndSettle();
    expect(find.text('格式化'), findsOneWidget);
    expect(find.text('导出副本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modified copy needs confirmation before close or replacement', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final original = file('first.csv', 'key,value\na,1');
    original.editCsvCell(0, 1, '2');
    await tester.pumpWidget(
      readyApp(gateway: gateway, initialDocument: original),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close file'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Discard working-copy changes?'), findsOneWidget);
    await tester.tap(find.text('Keep file'));
    await tester.pumpAndSettle();
    expect(find.text('first.csv'), findsOneWidget);

    gateway.nextPick = ImportedFile(
      'second.csv',
      Uint8List.fromList(utf8.encode('key,value\nb,3')),
    );
    await tester.tap(find.byTooltip('Open another file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep file'));
    await tester.pumpAndSettle();
    expect(find.text('first.csv'), findsOneWidget);
    expect(original.workingText, contains('a,2'));
  });

  testWidgets('more sheet opens privacy and restores a working copy', (
    tester,
  ) async {
    final original = file('settings.json', '{"a":1}');
    original.formatJson();
    await tester.pumpWidget(
      readyApp(gateway: FakeGateway(), initialDocument: original),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings and privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy note'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Restore original'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(original.isModified, isFalse);
  });

  testWidgets('diagnostics and page jump use iOS dialogs', (tester) async {
    await tester.pumpWidget(
      readyApp(
        gateway: FakeGateway(),
        initialDocument: file('bad.csv', 'a,b\n1\n2\n3\n4'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('View all'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      readyApp(
        gateway: FakeGateway(),
        initialDocument: file(
          'many.log',
          List.generate(401, (i) => 'INFO line${i + 1}').join('\n'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jump'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField), '3');
    await tester.tap(find.text('Jump').last);
    await tester.pumpAndSettle();
    expect(find.text('401–401 of 401'), findsOneWidget);
  });

  testWidgets('raw repair revalidates invalid JSON', (tester) async {
    final original = file('broken.json', '{"a":}');
    await tester.pumpWidget(
      readyApp(gateway: FakeGateway(), initialDocument: original),
    );
    await tester.pumpAndSettle();
    expect(find.text('Format issue found'), findsOneWidget);
    await tester.tap(find.text('Edit text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '{"a":1}');
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    expect(original.isValid, isTrue);
    expect(find.text('Inspection passed'), findsOneWidget);
    expect(original.sourceText, '{"a":}');
  });

  testWidgets('raw draft cancellation needs confirmation', (tester) async {
    final original = file('draft.json', '{"a":1}');
    await tester.pumpWidget(
      readyApp(gateway: FakeGateway(), initialDocument: original),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '{"a":2}');
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Discard unapplied edits?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Edit raw copy'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(find.text('draft.json'), findsOneWidget);
    expect(original.workingText, '{"a":1}');
  });

  testWidgets('raw editor rejects UTF-8 content over 128 KiB', (tester) async {
    final original = file('draft.json', '{"a":1}');
    await tester.pumpWidget(
      readyApp(gateway: FakeGateway(), initialDocument: original),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '中' * 43691);
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    expect(find.text('Raw editing is limited to 128 KiB.'), findsOneWidget);
    expect(find.text('Edit raw copy'), findsOneWidget);
    expect(original.workingText, '{"a":1}');
  });

  testWidgets('last supported text and CSV rows are reachable', (tester) async {
    final gateway = FakeGateway();
    final log = file(
      'many.log',
      List.generate(501, (i) => 'INFO line${i + 1}').join('\n'),
    );
    await tester.pumpWidget(readyApp(gateway: gateway, initialDocument: log));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('401–501 of 501'), findsOneWidget);

    gateway.nextPick = ImportedFile(
      'many.csv',
      Uint8List.fromList(
        utf8.encode(
          'id,value\n${List.generate(101, (i) => '${i + 1},row${i + 1}').join('\n')}',
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open another file'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('row101'), findsOneWidget);
    await tester.ensureVisible(find.text('row101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('row101'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'last edited');
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export copy'));
    await tester.pumpAndSettle();
    expect(utf8.decode(gateway.exportedBytes!), contains('101,last edited'));
  });
}
