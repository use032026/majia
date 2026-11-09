import 'dart:convert';
import 'dart:typed_data';

import 'package:filerecheck/src/domain/filerecheck_document.dart';
import 'package:flutter_test/flutter_test.dart';

FileRecheckDocument _inspect(String text) => FileRecheckDocument.inspect(
  fileName: 'fixture.log',
  bytes: Uint8List.fromList(utf8.encode(text)),
);

List<(int, String, LogSeverity)> _lines(FileRecheckDocument document) => [
  for (final line in document.lines) (line.number, line.text, line.severity),
];

void main() {
  test(
    'import keeps literal severity, boundaries, priority and physical lines',
    () {
      const golden = <(String, LogSeverity)>[
        ('fatal stopped', LogSeverity.error),
        ('ERROR broken', LogSeverity.error),
        ('eRr failed', LogSeverity.error),
        ('[warning] check', LogSeverity.warning),
        ('WARN check', LogSeverity.warning),
        ('Notice ready', LogSeverity.info),
        ('INFO ready', LogSeverity.info),
        ('trace detail', LogSeverity.debug),
        ('DEBUG detail', LogSeverity.debug),
        ('terror ERROR_code errant', LogSeverity.none),
        ('warned INFO2 nodebug', LogSeverity.none),
        ('_ERROR_ WARN_no INFO42', LogSeverity.none),
        ('ERROR-WARN', LogSeverity.error),
        ('DEBUG INFO WARN ERROR', LogSeverity.error),
        ('TRACE NOTICE WARNING', LogSeverity.warning),
        ('TRACE INFO', LogSeverity.info),
        ('', LogSeverity.none),
        ('中文ERROR结束🪷', LogSeverity.error),
        ('éWARNé', LogSeverity.warning),
        ('ＥＲＲＯＲ ℹ️', LogSeverity.none),
        ('INFO\tready', LogSeverity.info),
        ('normal 👩🏽‍💻', LogSeverity.none),
      ];
      final text = golden.map((entry) => entry.$1).join('\r\n');
      final document = _inspect(text);
      expect(_lines(document), [
        for (var i = 0; i < golden.length; i++)
          (i + 1, golden[i].$1, golden[i].$2),
      ]);
      expect(document.sourceText, text);
      expect(document.workingText, text);
      expect(document.exportBytes(), utf8.encode(text));
    },
  );

  test(
    'repeated edits, undo, reset and independent imports do not leak matches',
    () {
      const original = 'ERROR original\nTRACE detail';
      const edited = 'warn edited\n\nINFO second\nordinary';
      final document = _inspect(original);
      for (var iteration = 0; iteration < 3; iteration++) {
        document.replaceWorkingText(edited);
        expect(_lines(document), const [
          (1, 'warn edited', LogSeverity.warning),
          (2, '', LogSeverity.none),
          (3, 'INFO second', LogSeverity.info),
          (4, 'ordinary', LogSeverity.none),
        ]);
        expect(
          document
              .search('SECOND')
              .map((hit) => (hit.line, hit.column, hit.text))
              .toList(),
          [(3, 6, 'INFO second')],
        );
        expect(document.exportBytes(), utf8.encode(edited));
        expect(_lines(_inspect('DEBUG independent')), const [
          (1, 'DEBUG independent', LogSeverity.debug),
        ]);
        expect(document.undo(), isTrue);
        expect(_lines(document), const [
          (1, 'ERROR original', LogSeverity.error),
          (2, 'TRACE detail', LogSeverity.debug),
        ]);
      }
      document.replaceWorkingText('NOTICE changed');
      document.reset();
      expect(document.workingText, original);
      expect(document.sourceText, original);
      expect(document.isModified, isFalse);
      expect(document.canUndo, isFalse);
    },
  );

  test('empty log remains a single unclassified displayed line', () {
    final document = _inspect('');
    expect(_lines(document), const [(1, '', LogSeverity.none)]);
    document.replaceWorkingText('INFO ready\n');
    expect(_lines(document), const [(1, 'INFO ready', LogSeverity.info)]);
    document.replaceWorkingText('');
    expect(_lines(document), const [(1, '', LogSeverity.none)]);
  });

  test(
    '10000-line imports and refresh keep the last line and fail atomically above the limit',
    () {
      final original = List.filled(
        9999,
        'INFO ready',
      ).followedBy(['ERROR final']).join('\n');
      final document = _inspect('$original\n');
      expect(document.lines, hasLength(10000));
      expect(document.lines.first.severity, LogSeverity.info);
      expect(document.lines.last.number, 10000);
      expect(document.lines.last.text, 'ERROR final');
      expect(document.lines.last.severity, LogSeverity.error);
      final edited = List.filled(
        9999,
        'ordinary',
      ).followedBy(['warn retry']).join('\n');
      document.replaceWorkingText(edited);
      expect(document.lines.first.severity, LogSeverity.none);
      expect(document.lines.last.severity, LogSeverity.warning);
      final undoDepth = document.undoDepth;
      expect(
        () => document.replaceWorkingText('$edited\nINFO extra'),
        throwsA(
          isA<FileRecheckException>().having(
            (error) => error.code,
            'code',
            FileRecheckErrorCode.tooManyLines,
          ),
        ),
      );
      expect(document.workingText, edited);
      expect(document.undoDepth, undoDepth);
      expect(document.sourceText, '$original\n');
      expect(document.exportBytes(), utf8.encode(edited));
      expect(
        () => _inspect('$edited\nINFO extra'),
        throwsA(isA<FileRecheckException>()),
      );
    },
  );
}
