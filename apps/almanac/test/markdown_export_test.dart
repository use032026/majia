import 'dart:convert';

import 'package:almanac/src/app_controller.dart';
import 'package:almanac/src/domain/almanac_content.dart';
import 'package:almanac/src/domain/almanac_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

final _today = DateTime(2026, 11, 9, 9);

DailyLeaf _leaf(DateTime date, String? intention) => DailyLeaf(
  dateKey: formatDateKey(date),
  createdAt: date,
  generatorVersion: 1,
  seedFingerprint: '12345678',
  suitablePromptIds: const ['s-clear-one', 's-three-lines', 's-mend-small'],
  avoidPromptIds: const [
    'a-open-many',
    'a-rushed-promise',
    'a-endless-compare',
  ],
  selectedSuitableId: 's-clear-one',
  selectedAvoidId: 'a-open-many',
  intention: intention,
  outcome: ReflectionOutcome.practiced,
  sealedAt: date,
  reflectedAt: date.add(const Duration(hours: 8)),
  verseZh: const ['窗光落在纸上。', '今日留一行空白。'],
  verseEn: const ['A steady page.', 'A quiet day.'],
);

String _snapshot(Iterable<DailyLeaf> leaves) => jsonEncode(
  AlmanacData.initial('export-fixture')
      .copyWith(
        onboardingSeen: true,
        leaves: {for (final leaf in leaves) leaf.dateKey: leaf},
      )
      .toJson(),
);

AppController _controller(MemoryStateStore store) => AppController(
  store: store,
  seedFactory: () => 'unused',
  clock: () => _today,
);

String _expectedEnglish(String? inline) =>
    '# Deynu folio\n'
    '\n'
    '> Copied by the user from local records; prompts are for reflection, not prediction.\n'
    '\n'
    '## 2026-11-09\n'
    '- Try: Clarify one thing\n'
    '- Skip: Starting too many things\n'
    '${inline == null ? '' : '- Intention: $inline\n'}'
    '- Reflection: Practiced\n'
    '\n'
    'A steady page.  \n'
    'A quiet day.\n';

String _expectedChinese(String? inline) =>
    '# Deynu 岁时册\n'
    '\n'
    '> 本文件由用户主动从本机记录复制；内容是反思提示，不是吉凶预测。\n'
    '\n'
    '## 2026-11-09\n'
    '- 宜: 理清一件事\n'
    '- 忌: 同时开太多头\n'
    '${inline == null ? '' : '- 今日意图: $inline\n'}'
    '- 回看: 践行\n'
    '\n'
    '窗光落在纸上。  \n'
    '今日留一行空白。\n';

void main() {
  final cases = <({String name, String? intention, String? inline})>[
    (
      name: 'every escaped Markdown character',
      intention: r'\ ` * _ { } [ ] ( ) # + - . ! | >',
      inline: r'\\ \` \* \_ \{ \} \[ \] \( \) \# \+ \- \. \! \| \>',
    ),
    (
      name: 'CR LF CRLF and adjacent line separators',
      intention: '\t first\rsecond\nthird\r\nfourth\n\r\nlast \t',
      inline: 'first second third fourth last',
    ),
    (
      name: 'combining characters and joined emoji',
      intention: '👩🏽‍💻 e\u0301 家庭👨‍👩‍👧‍👦\r\n🪷',
      inline: '👩🏽‍💻 e\u0301 家庭👨‍👩‍👧‍👦 🪷',
    ),
    (
      name: 'adjacent line breaks and Markdown characters',
      intention: '\r\n *a*\r\n#b\\\n_中_ \r',
      inline: r'\*a\* \#b\\ \_中\_',
    ),
    (name: 'empty intention', intention: '', inline: null),
    (name: 'missing intention', intention: null, inline: null),
    (name: 'whitespace-only intention', intention: ' \t\r\n ', inline: ''),
  ];

  for (final entry in cases) {
    for (final useChinese in [false, true]) {
      test(
        'exact ${useChinese ? 'Chinese' : 'English'} Markdown for ${entry.name}',
        () async {
          final original = _snapshot([_leaf(_today, entry.intention)]);
          final store = MemoryStateStore(value: original);
          final controller = _controller(store);
          await controller.load();

          expect(controller.isLoaded, isTrue);
          expect(
            controller.exportMarkdown(useChinese: useChinese),
            useChinese
                ? _expectedChinese(entry.inline)
                : _expectedEnglish(entry.inline),
          );
          expect(store.value, original);
          expect(store.writeCount, 0);
        },
      );
    }
  }

  test(
    'fake unordered 365-leaf schema-one history exports without rewriting',
    () async {
      final chronological = [
        for (var daysAgo = 364; daysAgo >= 0; daysAgo--)
          _leaf(
            _today.subtract(Duration(days: daysAgo)),
            '保留 #$daysAgo\r\n👩🏽‍💻',
          ),
      ];
      final unordered = [
        for (var index = 0; index < chronological.length; index += 2)
          chronological[index],
        for (var index = 1; index < chronological.length; index += 2)
          chronological[index],
      ];
      final original = _snapshot(unordered);
      final store = MemoryStateStore(value: original);
      final controller = _controller(store);
      await controller.load();

      expect(controller.data!.schemaVersion, 1);
      final firstExports = <bool, String>{};
      for (final useChinese in [false, true]) {
        final markdown = controller.exportMarkdown(useChinese: useChinese);
        firstExports[useChinese] = markdown;
        expect(controller.exportMarkdown(useChinese: useChinese), markdown);
        final headings = const LineSplitter()
            .convert(markdown)
            .where((line) => line.startsWith('## '))
            .toList();
        expect(
          headings,
          chronological.reversed.map((leaf) => '## ${leaf.dateKey}').toList(),
        );
        for (var daysAgo = 0; daysAgo < 365; daysAgo++) {
          expect(markdown.contains('保留 \\#$daysAgo 👩🏽‍💻'), isTrue);
        }
        expect(markdown.contains('\r'), isFalse);
      }
      for (final useChinese in [false, true]) {
        expect(
          controller.exportMarkdown(useChinese: useChinese),
          firstExports[useChinese],
        );
      }
      expect(jsonEncode(controller.data!.toJson()), original);
      expect(store.value, original);
      expect(store.writeCount, 0);
    },
  );

  test(
    'fake save failure preserves export and recovery survives relaunch',
    () async {
      const intention = r'保留 **today** [日笺](x)';
      final original = _snapshot([_leaf(_today, intention)]);
      final store = MemoryStateStore(value: original);
      final controller = _controller(store);
      await controller.load();
      final englishBefore = controller.exportMarkdown(useChinese: false);
      final chineseBefore = controller.exportMarkdown(useChinese: true);
      store.failWrite = true;

      expect(
        await controller.reflectToday(ReflectionOutcome.released),
        isFalse,
      );
      expect(controller.hasSaveFailure, isTrue);
      expect(controller.exportMarkdown(useChinese: false), englishBefore);
      expect(controller.exportMarkdown(useChinese: true), chineseBefore);
      expect(store.value, original);

      store.failWrite = false;
      expect(await controller.reflectToday(ReflectionOutcome.released), isTrue);
      expect(controller.hasSaveFailure, isFalse);
      final relaunched = _controller(store);
      await relaunched.load();
      expect(
        relaunched.exportMarkdown(useChinese: false),
        englishBefore.replaceFirst(
          '- Reflection: Practiced',
          '- Reflection: Released',
        ),
      );
      expect(
        relaunched.exportMarkdown(useChinese: true),
        chineseBefore.replaceFirst('- 回看: 践行', '- 回看: 放下'),
      );
      expect(relaunched.todayLeaf.intention, intention);
    },
  );
}
