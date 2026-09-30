import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/domain/novel.dart';

void main() {
  group('novel import planning', () {
    test('splits Chinese and Markdown chapter headings', () {
      final plan = planNovelImport(
        fileName: '/imports/雾站来信.txt',
        content: '''序言内容

第1章 雾站
第一章正文。

## 第二封信
第二章正文。''',
      );

      expect(plan.title, '雾站来信');
      expect(plan.chapters.map((chapter) => chapter.title), [
        '前言 / Preface',
        '第1章 雾站',
        '第二封信',
      ]);
      expect(plan.chapters.last.content, '第二章正文。');
    });

    test('keeps a heading-free manuscript as one editable chapter', () {
      final plan = planNovelImport(
        fileName: 'notes.markdown',
        content: '\uFEFFFirst paragraph.\r\n\r\nSecond paragraph.',
      );

      expect(plan.title, 'notes');
      expect(plan.chapters, hasLength(1));
      expect(plan.chapters.single.title, '正文 / Main text');
      expect(plan.chapters.single.content, contains('Second paragraph.'));
    });

    test('rejects an empty text file', () {
      expect(
        () => planNovelImport(fileName: 'empty.txt', content: '  \n'),
        throwsFormatException,
      );
    });
  });
}
