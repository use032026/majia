import 'dart:io';

import 'package:cleantrail/data/csv_gateway.dart';
import 'package:cleantrail/data/native_csv_gateway.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('cleantrail-export-');
  });

  tearDown(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test(
    'import supplies every supported tabular type required by iOS',
    () async {
      List<XTypeGroup>? requestedTypes;
      final gateway = NativeCsvGateway(
        openFile: ({required acceptedTypeGroups}) async {
          requestedTypes = acceptedTypeGroups;
          return null;
        },
      );

      expect(await gateway.pickDataFile(), isNull);
      expect(requestedTypes, hasLength(1));
      expect(requestedTypes!.single.extensions, ['csv', 'tsv', 'txt', 'xlsx']);
      expect(requestedTypes!.single.mimeTypes, [
        'text/csv',
        'text/tab-separated-values',
        'text/plain',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ]);
      expect(requestedTypes!.single.uniformTypeIdentifiers, [
        'public.comma-separated-values-text',
        'public.tab-separated-values-text',
        'public.plain-text',
        'org.openxmlformats.spreadsheetml.sheet',
      ]);
    },
  );

  test('export shares draft names and removes both staged files', () async {
    final gateway = NativeCsvGateway(
      temporaryDirectoryProvider: () async => temporary,
      share: (params) async {
        expect(params.fileNameOverrides!.first, 'private_draft.csv');
        expect(params.files, hasLength(2));
        for (final file in params.files!) {
          expect(await File(file.path).exists(), isTrue);
        }
        return const ShareResult(
          'com.apple.UIKit.activity.CopyToPasteboard',
          ShareResultStatus.success,
        );
      },
    );

    final outcome = await gateway.export(
      baseName: 'private',
      csv: 'name\nsecret',
      report: '# report',
      shareText: 'share',
      complete: false,
    );

    expect(outcome, ExportOutcome.completed);
    final exportDirectory = Directory('${temporary.path}/cleantrail-exports');
    expect(await exportDirectory.list().toList(), isEmpty);
  });

  test('both staged files are removed when sharing throws', () async {
    final gateway = NativeCsvGateway(
      temporaryDirectoryProvider: () async => temporary,
      share: (_) async => throw const FileSystemException('share failed'),
    );

    await expectLater(
      gateway.export(
        baseName: 'private',
        csv: 'name\nsecret',
        report: '# report',
        shareText: 'share',
        complete: true,
      ),
      throwsA(isA<FileSystemException>()),
    );
    final exportDirectory = Directory('${temporary.path}/cleantrail-exports');
    expect(await exportDirectory.list().toList(), isEmpty);
  });

  test('export maps incomplete and unavailable share results', () async {
    final results = [
      const ShareResult('', ShareResultStatus.dismissed),
      ShareResult.unavailable,
    ];
    final gateway = NativeCsvGateway(
      temporaryDirectoryProvider: () async => temporary,
      share: (_) async => results.removeAt(0),
    );

    expect(
      await gateway.export(
        baseName: 'private',
        csv: 'name\nsecret',
        report: '# report',
        shareText: 'share',
        complete: true,
      ),
      ExportOutcome.incomplete,
    );
    expect(
      await gateway.export(
        baseName: 'private',
        csv: 'name\nsecret',
        report: '# report',
        shareText: 'share',
        complete: true,
      ),
      ExportOutcome.unconfirmed,
    );
  });

  test('startup cleanup removes stale dedicated export directory', () async {
    final directory = Directory('${temporary.path}/cleantrail-exports');
    await directory.create();
    await File('${directory.path}/stale.csv').writeAsString('private');
    final gateway = NativeCsvGateway(
      temporaryDirectoryProvider: () async => temporary,
      share: (_) async => ShareResult.unavailable,
    );

    await gateway.cleanupTemporaryFiles();

    expect(await directory.exists(), isFalse);
  });
}
