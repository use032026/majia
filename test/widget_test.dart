import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:filepeek/main.dart';
import 'package:filepeek/src/data/file_gateway.dart';
import 'package:filepeek/src/domain/filepeek_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements FileGateway {
  ImportedFile? nextPick;
  Completer<ImportedFile?>? pendingPick;
  Completer<ImportedFile?>? pendingInitial;
  final incoming = StreamController<ImportedFile>.broadcast();
  int sharedCount = 0;
  String? exportedName;
  Uint8List? exportedBytes;

  @override
  Stream<ImportedFile> get sharedFiles => incoming.stream;

  @override
  Future<void> clearOldExports() async {}

  @override
  Future<ImportedFile?> initialSharedFile() =>
      pendingInitial?.future ?? Future.value(null);

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

FilePeekDocument file(String name, String text) => FilePeekDocument.inspect(
  fileName: name,
  bytes: Uint8List.fromList(utf8.encode(text)),
);

void main() {
  testWidgets('JSON format, undo and export keep source intact', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final document = file('payload.json', '{"a":1}');
    await tester.pumpWidget(
      FilePeekApp(gateway: gateway, initialDocument: document),
    );
    await tester.pumpAndSettle();
    expect(find.text('payload.json'), findsOneWidget);
    expect(document.isModified, isFalse);

    await tester.tap(find.text('Format JSON'));
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
      FilePeekApp(gateway: FakeGateway(), initialDocument: document),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(document.isModified, isFalse);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Carol');
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
      FilePeekApp(gateway: gateway, initialDocument: file('ok.json', '{}')),
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
      FilePeekApp(
        gateway: gateway,
        initialDocument: file('ok.log', 'INFO ready'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch language'));
    await tester.pumpAndSettle();
    expect(find.text('导出副本'), findsOneWidget);
    await tester.tap(find.text('检查报告'));
    await tester.pumpAndSettle();
    expect(utf8.decode(gateway.exportedBytes!), contains('检查报告'));
  });

  testWidgets('modified copy needs confirmation before close or replacement', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final original = file('first.csv', 'key,value\na,1');
    original.editCsvCell(0, 1, '2');
    await tester.pumpWidget(
      FilePeekApp(gateway: gateway, initialDocument: original),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close file'));
    await tester.pumpAndSettle();
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

  testWidgets('incoming share cannot attach a stale JSON comparison', (
    tester,
  ) async {
    final gateway = FakeGateway()..pendingPick = Completer<ImportedFile?>();
    await tester.pumpWidget(
      FilePeekApp(
        gateway: gateway,
        initialDocument: file('old.json', '{"a":1}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare JSON'));
    await tester.pump();
    gateway.incoming.add(
      ImportedFile('new.json', Uint8List.fromList(utf8.encode('{"b":2}'))),
    );
    await tester.pumpAndSettle();
    gateway.pendingPick!.complete(
      ImportedFile('other.json', Uint8List.fromList(utf8.encode('{"a":3}'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('new.json'), findsOneWidget);
    expect(find.textContaining('Compared with:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incoming share cannot redirect a pending CSV cell edit', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final newBytes = Uint8List.fromList(utf8.encode('name,value\nNew,9'));
    await tester.pumpWidget(
      FilePeekApp(
        gateway: gateway,
        initialDocument: file('old.csv', 'name,value\nAlice,1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    gateway.incoming.add(ImportedFile('new.csv', newBytes));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Stale');
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    expect(find.text('new.csv'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Stale'), findsNothing);
  });

  testWidgets('late initial share cannot replace a user-selected file', (
    tester,
  ) async {
    final gateway = FakeGateway()
      ..pendingInitial = Completer<ImportedFile?>()
      ..nextPick = ImportedFile(
        'chosen.txt',
        Uint8List.fromList(utf8.encode('chosen')),
      );
    await tester.pumpWidget(FilePeekApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open file'));
    await tester.pumpAndSettle();
    gateway.pendingInitial!.complete(
      ImportedFile('stale.txt', Uint8List.fromList(utf8.encode('stale'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('chosen.txt'), findsOneWidget);
    expect(find.text('stale.txt'), findsNothing);
  });

  testWidgets('raw repair revalidates invalid JSON', (tester) async {
    final original = file('broken.json', '{"a":}');
    await tester.pumpWidget(
      FilePeekApp(gateway: FakeGateway(), initialDocument: original),
    );
    await tester.pumpAndSettle();
    expect(find.text('Format issue found'), findsOneWidget);
    await tester.tap(find.text('Edit raw copy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '{"a":1}');
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    expect(original.isValid, isTrue);
    expect(find.text('Inspection passed'), findsOneWidget);
    expect(original.sourceText, '{"a":}');
  });

  testWidgets('incoming share preserves an unapplied raw editing draft', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final original = file('first.json', '{"a":1}');
    await tester.pumpWidget(
      FilePeekApp(gateway: gateway, initialDocument: original),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit raw copy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '{"a":2}');
    gateway.incoming.add(
      ImportedFile('second.json', Uint8List.fromList(utf8.encode('{"b":3}'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discard working-copy changes?'), findsOneWidget);
    await tester.tap(find.text('Keep file'));
    await tester.pumpAndSettle();
    expect(find.text('Edit raw copy'), findsOneWidget);
    expect(find.text('{"a":2}'), findsOneWidget);
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    expect(original.workingText, '{"a":2}');
    expect(find.text('first.json'), findsOneWidget);
  });

  testWidgets('confirmed incoming share closes an unapplied raw draft', (
    tester,
  ) async {
    final gateway = FakeGateway();
    await tester.pumpWidget(
      FilePeekApp(
        gateway: gateway,
        initialDocument: file('first.json', '{"a":1}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit raw copy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '{"a":2}');
    gateway.incoming.add(
      ImportedFile('second.json', Uint8List.fromList(utf8.encode('{"b":3}'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('second.json'), findsOneWidget);
    expect(find.text('Edit raw copy'), findsOneWidget);
    expect(find.text('Apply edit'), findsNothing);
  });

  testWidgets('raw draft cancellation needs confirmation', (tester) async {
    final original = file('draft.json', '{"a":1}');
    await tester.pumpWidget(
      FilePeekApp(gateway: FakeGateway(), initialDocument: original),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit raw copy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '{"a":2}');
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
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
      FilePeekApp(gateway: FakeGateway(), initialDocument: original),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit raw copy'));
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
    await tester.pumpWidget(
      FilePeekApp(gateway: gateway, initialDocument: log),
    );
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
    await tester.enterText(find.byType(TextFormField), 'last edited');
    await tester.tap(find.text('Apply edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export copy'));
    await tester.pumpAndSettle();
    expect(utf8.decode(gateway.exportedBytes!), contains('101,last edited'));
  });
}
