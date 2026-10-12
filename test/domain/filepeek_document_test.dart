import 'dart:convert';
import 'dart:typed_data';

import 'package:filepeek/src/domain/filepeek_document.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

FilePeekDocument inspect(String name, String text) =>
    FilePeekDocument.inspect(fileName: name, bytes: bytes(text));

void main() {
  group('import boundaries', () {
    test(
      'detects supported types and accepts UTF-8 BOM without losing content',
      () {
        expect(inspect('a.JSON', '{}').kind, FileKind.json);
        expect(inspect('a.csv', 'a\n1').kind, FileKind.csv);
        expect(inspect('a.txt', 'note').kind, FileKind.txt);
        expect(inspect('a.log', 'INFO ready').kind, FileKind.log);
        final document = FilePeekDocument.inspect(
          fileName: 'a.txt',
          bytes: Uint8List.fromList([
            0xef,
            0xbb,
            0xbf,
            ...utf8.encode('hello'),
          ]),
        );
        expect(document.sourceText, 'hello');
        expect(document.hasUtf8Bom, isTrue);
        expect(document.exportBytes(), [
          0xef,
          0xbb,
          0xbf,
          ...utf8.encode('hello'),
        ]);
      },
    );

    test(
      'rejects oversized, malformed UTF-8, binary and unsupported files',
      () {
        expect(
          () => FilePeekDocument.inspect(
            fileName: 'a.txt',
            bytes: Uint8List(FilePeekDocument.maxBytes + 1),
          ),
          throwsA(
            isA<FilePeekException>().having(
              (error) => error.code,
              'code',
              FilePeekErrorCode.tooLarge,
            ),
          ),
        );
        expect(
          () => FilePeekDocument.inspect(
            fileName: 'a.txt',
            bytes: Uint8List.fromList([0xc3, 0x28]),
          ),
          throwsA(
            isA<FilePeekException>().having(
              (error) => error.code,
              'code',
              FilePeekErrorCode.invalidUtf8,
            ),
          ),
        );
        expect(
          () => inspect('a.txt', 'hello\u0000world'),
          throwsA(
            isA<FilePeekException>().having(
              (error) => error.code,
              'code',
              FilePeekErrorCode.binaryContent,
            ),
          ),
        );
        expect(
          () => inspect('a.bin', 'hello'),
          throwsA(
            isA<FilePeekException>().having(
              (error) => error.code,
              'code',
              FilePeekErrorCode.unsupportedType,
            ),
          ),
        );
      },
    );

    test('accepts 10,000 physical lines with and without final newline', () {
      final lines = List.filled(FilePeekDocument.maxLines, 'x').join('\n');
      expect(inspect('a.txt', lines).lines.length, FilePeekDocument.maxLines);
      expect(
        inspect('a.txt', '$lines\n').lines.length,
        FilePeekDocument.maxLines,
      );
      expect(
        inspect('a.txt', 'x\r' * FilePeekDocument.maxLines).lines.length,
        FilePeekDocument.maxLines,
      );
    });

    test('rejects more than 10,000 physical lines', () {
      expect(
        () => inspect('a.txt', List.filled(10001, 'x').join('\n')),
        throwsA(
          isA<FilePeekException>().having(
            (error) => error.code,
            'code',
            FilePeekErrorCode.tooManyLines,
          ),
        ),
      );
    });
  });

  group('JSON inspection and working copy', () {
    test('shows invalid JSON position and refuses formatting it', () {
      final document = inspect('a.json', '{\n  "a": 1,\n  }');
      expect(document.isValid, isFalse);
      expect(document.diagnostics.single.severity, DiagnosticSeverity.error);
      expect(document.diagnostics.single.code, DiagnosticCode.invalidJson);
      expect(document.diagnostics.single.line, 3);
      expect(() => document.formatJson(), throwsA(isA<FilePeekException>()));
      expect(document.workingText, document.sourceText);
    });

    test('formats the working copy, undoes and resets to source', () {
      final document = inspect('a.json', '{"b":2,"a":1}');
      document.formatJson();
      expect(document.workingText, contains('\n'));
      expect(document.sourceText, '{"b":2,"a":1}');
      expect(document.isModified, isTrue);
      expect(document.canUndo, isTrue);
      expect(document.undo(), isTrue);
      expect(document.workingText, document.sourceText);
      expect(document.undo(), isFalse);
      document.formatJson();
      document.reset();
      expect(document.workingText, document.sourceText);
      expect(document.canUndo, isFalse);
    });

    test(
      'repairs invalid JSON in the working copy and revalidates immediately',
      () {
        final document = inspect('broken.json', '{"a":}');
        expect(document.isValid, isFalse);
        document.replaceWorkingText('{"a":1}');
        expect(document.isValid, isTrue);
        expect(document.diagnostics, isEmpty);
        expect(document.sourceText, '{"a":}');
        expect(document.isModified, isTrue);
        expect(document.undo(), isTrue);
        expect(document.workingText, '{"a":}');
        expect(document.isValid, isFalse);
      },
    );

    test('reports added, removed and changed structural paths', () {
      final document = inspect('a.json', '{"old":1,"same":{"x":1},"arr":[4]}');
      final differences = document.compareJson(
        bytes('{"new":2,"same":{"x":3},"arr":[4,5]}'),
      );
      expect(differences.map((item) => '${item.path}:${item.kind.name}'), [
        '/arr/1:added',
        '/new:added',
        '/old:removed',
        '/same/x:changed',
      ]);
      expect(document.workingText, document.sourceText);
      expect(
        document.buildReport(differences: differences),
        contains('JSON differences: 4'),
      );
      final report = document.buildReport(differences: differences);
      expect(report, contains('- changed: /same/x'));
      expect(report, isNot(contains('1 -> 3')));
      expect(report, isNot(contains('"x":1')));
    });

    test('distinguishes a missing property from a JSON null value', () {
      final document = inspect('a.json', '{"removed":null}');
      final differences = document.compareJson(bytes('{"added":null}'));
      expect(differences.first.path, '/added');
      expect(differences.first.before, isNull);
      expect(differences.first.after, 'null');
      expect(differences.last.path, '/removed');
      expect(differences.last.before, 'null');
      expect(differences.last.after, isNull);
    });

    test('comparison failure leaves current document intact', () {
      final document = inspect('a.json', '{"ok":true}');
      expect(
        () => document.compareJson(bytes('{invalid')),
        throwsA(
          isA<FilePeekException>().having(
            (error) => error.code,
            'code',
            FilePeekErrorCode.invalidComparison,
          ),
        ),
      );
      expect(document.workingText, '{"ok":true}');
      expect(document.isValid, isTrue);
    });

    test(
      'comparison fails explicitly instead of silently truncating output',
      () {
        final document = inspect('a.json', '{}');
        final other = {
          for (var i = 0; i <= FilePeekDocument.maxDifferences; i++) 'k$i': i,
        };
        expect(
          () => document.compareJson(bytes(jsonEncode(other))),
          throwsA(
            isA<FilePeekException>().having(
              (error) => error.code,
              'code',
              FilePeekErrorCode.diffLimit,
            ),
          ),
        );
      },
    );

    test('rejects excessive JSON nesting with a positioned diagnostic', () {
      final document = inspect('deep.json', '${'[' * 65}0${']' * 65}');
      expect(document.isValid, isFalse);
      expect(document.diagnostics.single.code, DiagnosticCode.invalidJson);
      expect(document.diagnostics.single.message, contains('depth limit'));
    });
  });

  group('CSV table', () {
    test('parses RFC4180 quotes, commas and embedded line breaks', () {
      final document = inspect(
        'a.csv',
        'name,note\r\n"Ada, A","hello\r\n""world"""\r\nBob,ok\r\n',
      );
      expect(document.isValid, isTrue);
      expect(document.csvTable!.headers, ['name', 'note']);
      expect(document.csvTable!.rows.first.cells, ['Ada, A', 'hello\n"world"']);
      expect(document.csvTable!.rows.last.sourceLine, 4);
      expect(document.filterCsv('HELLO').single.cells.first, 'Ada, A');
      expect(document.filterCsv('ok').single.dataIndex, 1);
      expect(document.filterCsv('missing'), isEmpty);
    });

    test(
      'edits a cell in a copy, serializes it and restores source with undo',
      () {
        final document = inspect('a.csv', 'name,note\nAda,old\n');
        document.editCsvCell(0, 1, 'new, "quoted"');
        expect(document.workingText, contains('"new, ""quoted"""'));
        expect(document.csvTable!.rows.single.cells.last, 'new, "quoted"');
        expect(document.sourceText, 'name,note\nAda,old\n');
        expect(document.isModified, isTrue);
        expect(document.undo(), isTrue);
        expect(document.workingText, document.sourceText);
        expect(document.csvTable!.rows.single.cells.last, 'old');
      },
    );

    test('filtered row index targets its original data row for editing', () {
      final document = inspect('a.csv', 'name,value\nAda,one\nBob,two');
      final filtered = document.filterCsv('Bob');
      document.editCsvCell(filtered.single.dataIndex, 1, 'changed');
      expect(document.csvTable!.rows.first.cells.last, 'one');
      expect(document.csvTable!.rows.last.cells.last, 'changed');
    });

    test('reports malformed quotes and ragged rows; blocks edits', () {
      final badQuote = inspect('a.csv', 'a,b\n"unterminated,x');
      expect(badQuote.isValid, isFalse);
      expect(badQuote.diagnostics.single.line, 2);
      expect(badQuote.csvTable, isNull);
      expect(
        () => badQuote.editCsvCell(0, 0, 'x'),
        throwsA(isA<FilePeekException>()),
      );
      final ragged = inspect('a.csv', 'a,b\n1\n');
      expect(ragged.isValid, isFalse);
      expect(ragged.diagnostics.single.line, 2);
      expect(ragged.diagnostics.single.code, DiagnosticCode.csvColumnMismatch);
      expect(ragged.diagnostics.single.expectedColumns, 2);
      expect(ragged.diagnostics.single.actualColumns, 1);
      expect(ragged.buildReport(languageCode: 'zh'), contains('列数不匹配'));
    });

    test('repairs invalid CSV then permits table editing', () {
      final document = inspect('broken.csv', 'a,b\n1');
      expect(document.isValid, isFalse);
      expect(document.csvTable, isNull);
      document.replaceWorkingText('a,b\n1,2');
      expect(document.isValid, isTrue);
      expect(document.csvTable!.rows.single.cells, ['1', '2']);
      document.editCsvCell(0, 1, '3');
      expect(document.csvTable!.rows.single.cells, ['1', '3']);
      expect(document.sourceText, 'a,b\n1');
    });

    test(
      'failed replacement preserves working copy, validity and undo history',
      () {
        final document = inspect('a.csv', 'a,b\n1,2');
        document.replaceWorkingText('a,b\n3,4');
        final prior = document.workingText;
        final priorUndoDepth = document.undoDepth;
        expect(
          () => document.replaceWorkingText(
            'x' * (FilePeekDocument.maxBytes + 1),
          ),
          throwsA(
            isA<FilePeekException>().having(
              (error) => error.code,
              'code',
              FilePeekErrorCode.tooLarge,
            ),
          ),
        );
        expect(
          () => document.replaceWorkingText(
            List.generate(
              FilePeekDocument.maxColumns + 1,
              (i) => 'c$i',
            ).join(','),
          ),
          throwsA(
            isA<FilePeekException>().having(
              (error) => error.code,
              'code',
              FilePeekErrorCode.tooManyColumns,
            ),
          ),
        );
        expect(document.workingText, prior);
        expect(document.undoDepth, priorUndoDepth);
        expect(document.isValid, isTrue);
        expect(document.csvTable!.rows.single.cells, ['3', '4']);
      },
    );

    test(
      'keeps valid RFC4180 tables usable with repeated or empty headers',
      () {
        final document = inspect('a.csv', 'name,name,\nAda,Bob,ok');
        expect(document.isValid, isTrue);
        expect(document.csvTable!.rows.single.cells, ['Ada', 'Bob', 'ok']);
        expect(document.diagnostics.map((item) => item.code), [
          DiagnosticCode.csvEmptyHeader,
          DiagnosticCode.csvDuplicateHeader,
        ]);
        document.editCsvCell(0, 1, 'Charlie');
        expect(document.csvTable!.rows.single.cells[1], 'Charlie');
      },
    );

    test('enforces 200-column limit', () {
      final headers = List.generate(
        FilePeekDocument.maxColumns + 1,
        (i) => 'c$i',
      );
      expect(
        () => inspect('a.csv', headers.join(',')),
        throwsA(
          isA<FilePeekException>().having(
            (error) => error.code,
            'code',
            FilePeekErrorCode.tooManyColumns,
          ),
        ),
      );
    });
  });

  group('line search and report', () {
    test('matches case-insensitive lines and marks LOG severity', () {
      final document = inspect(
        'a.log',
        'INFO start\nwarning slow\nERROR failed',
      );
      expect(document.search('ERR').map((hit) => hit.line), [3]);
      expect(document.search(' ').map((hit) => hit.line), [1, 2, 3]);
      expect(document.search('absent'), isEmpty);
      expect(document.lines.map((line) => line.severity), [
        LogSeverity.info,
        LogSeverity.warning,
        LogSeverity.error,
      ]);
      expect(document.buildReport(filter: 'ERROR'), contains('Filter: ERROR'));
    });
  });
}
