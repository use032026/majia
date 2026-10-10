import 'almanac_models.dart';

const int generatorVersion = 1;

const List<PromptItem> promptBank = <PromptItem>[
  PromptItem(
    id: 's-clear-one',
    side: PromptSide.suitable,
    domain: 'focus',
    zh: '理清一件事',
    en: 'Clarify one thing',
  ),
  PromptItem(
    id: 's-three-lines',
    side: PromptSide.suitable,
    domain: 'creativity',
    zh: '写下三行',
    en: 'Write three lines',
  ),
  PromptItem(
    id: 's-mend-small',
    side: PromptSide.suitable,
    domain: 'home',
    zh: '修补一处小事',
    en: 'Mend one small thing',
  ),
  PromptItem(
    id: 's-walk-slowly',
    side: PromptSide.suitable,
    domain: 'movement',
    zh: '慢走一段路',
    en: 'Take a slower walk',
  ),
  PromptItem(
    id: 's-finish-early',
    side: PromptSide.suitable,
    domain: 'rest',
    zh: '早点收尾',
    en: 'Finish a little earlier',
  ),
  PromptItem(
    id: 's-greet-someone',
    side: PromptSide.suitable,
    domain: 'relationship',
    zh: '问候一个人',
    en: 'Check in with someone',
  ),
  PromptItem(
    id: 's-clear-surface',
    side: PromptSide.suitable,
    domain: 'home',
    zh: '清出一小块桌面',
    en: 'Clear one small surface',
  ),
  PromptItem(
    id: 's-single-task',
    side: PromptSide.suitable,
    domain: 'focus',
    zh: '只做眼前一件事',
    en: 'Do one thing at a time',
  ),
  PromptItem(
    id: 's-leave-space',
    side: PromptSide.suitable,
    domain: 'rest',
    zh: '留一段空白',
    en: 'Leave a little space',
  ),
  PromptItem(
    id: 's-notice-sound',
    side: PromptSide.suitable,
    domain: 'creativity',
    zh: '听一会儿窗外',
    en: 'Listen beyond the window',
  ),
  PromptItem(
    id: 's-prepare-tomorrow',
    side: PromptSide.suitable,
    domain: 'focus',
    zh: '为明日备好一步',
    en: 'Prepare one step for tomorrow',
  ),
  PromptItem(
    id: 's-share-thanks',
    side: PromptSide.suitable,
    domain: 'relationship',
    zh: '认真说一声谢谢',
    en: 'Offer one sincere thanks',
  ),
  PromptItem(
    id: 'a-rushed-promise',
    side: PromptSide.avoid,
    domain: 'relationship',
    zh: '忙中许诺',
    en: 'Promising while rushed',
  ),
  PromptItem(
    id: 'a-endless-compare',
    side: PromptSide.avoid,
    domain: 'focus',
    zh: '反复比较',
    en: 'Comparing without end',
  ),
  PromptItem(
    id: 'a-late-push',
    side: PromptSide.avoid,
    domain: 'rest',
    zh: '深夜硬撑',
    en: 'Pushing late into the night',
  ),
  PromptItem(
    id: 'a-fill-every-gap',
    side: PromptSide.avoid,
    domain: 'rest',
    zh: '填满每处空隙',
    en: 'Filling every pause',
  ),
  PromptItem(
    id: 'a-fix-all',
    side: PromptSide.avoid,
    domain: 'home',
    zh: '一次收拾全部',
    en: 'Fixing everything at once',
  ),
  PromptItem(
    id: 'a-answer-too-fast',
    side: PromptSide.avoid,
    domain: 'relationship',
    zh: '急着回应',
    en: 'Answering too quickly',
  ),
  PromptItem(
    id: 'a-open-many',
    side: PromptSide.avoid,
    domain: 'focus',
    zh: '同时开太多头',
    en: 'Starting too many things',
  ),
  PromptItem(
    id: 'a-ignore-tired',
    side: PromptSide.avoid,
    domain: 'rest',
    zh: '把疲惫当懒散',
    en: 'Calling fatigue laziness',
  ),
  PromptItem(
    id: 'a-chase-perfect',
    side: PromptSide.avoid,
    domain: 'creativity',
    zh: '第一遍就求完美',
    en: 'Demanding perfection first',
  ),
  PromptItem(
    id: 'a-rush-the-route',
    side: PromptSide.avoid,
    domain: 'movement',
    zh: '只顾赶路',
    en: 'Only hurrying onward',
  ),
  PromptItem(
    id: 'a-keep-clutter',
    side: PromptSide.avoid,
    domain: 'home',
    zh: '把杂乱留给以后',
    en: 'Leaving clutter for later',
  ),
  PromptItem(
    id: 'a-assume-intent',
    side: PromptSide.avoid,
    domain: 'relationship',
    zh: '替别人猜心意',
    en: 'Guessing another mind',
  ),
];

PromptItem promptById(String id) =>
    promptBank.firstWhere((prompt) => prompt.id == id);

void validateLeafContent(DailyLeaf leaf) {
  final known = <String, PromptItem>{
    for (final item in promptBank) item.id: item,
  };
  if (leaf.suitablePromptIds.length != 3 || leaf.avoidPromptIds.length != 3) {
    throw const FormatException(
      'A daily leaf must contain three prompts per side',
    );
  }
  for (final id in leaf.suitablePromptIds) {
    if (known[id]?.side != PromptSide.suitable) {
      throw FormatException('Unknown or invalid suitable prompt: $id');
    }
  }
  for (final id in leaf.avoidPromptIds) {
    if (known[id]?.side != PromptSide.avoid) {
      throw FormatException('Unknown or invalid avoid prompt: $id');
    }
  }
  if (leaf.selectedSuitableId != null &&
      !leaf.suitablePromptIds.contains(leaf.selectedSuitableId)) {
    throw const FormatException('Selected suitable prompt is not in this leaf');
  }
  if (leaf.selectedAvoidId != null &&
      !leaf.avoidPromptIds.contains(leaf.selectedAvoidId)) {
    throw const FormatException('Selected avoid prompt is not in this leaf');
  }
  if (leaf.verseZh.length != 2 ||
      leaf.verseEn.length != 2 ||
      leaf.verseZh.any((line) => line.trim().isEmpty) ||
      leaf.verseEn.any((line) => line.trim().isEmpty)) {
    throw const FormatException('Daily verse is incomplete');
  }
}

const Map<String, List<List<String>>> _verseZh = <String, List<List<String>>>{
  'focus': <List<String>>[
    <String>['窗光停在纸边', '一件事慢慢显出名字'],
    <String>['墨色沉下一寸', '纷杂便让出一条路'],
    <String>['把远声留在门外', '眼前自有清楚的纹理'],
  ],
  'creativity': <List<String>>[
    <String>['风从空白处经过', '留下三行未完的光'],
    <String>['纸上没有旧脚印', '一笔也能领路'],
    <String>['茶汽升得很轻', '句子在杯沿相遇'],
  ],
  'home': <List<String>>[
    <String>['旧物接住晨光', '细小裂缝也有回声'],
    <String>['桌角空出一掌', '屋里便多了一点风'],
    <String>['门轴轻轻转动', '寻常日子重新合拢'],
  ],
  'movement': <List<String>>[
    <String>['脚步放慢半拍', '长路仍向前舒展'],
    <String>['鞋底收下尘声', '转角不必提前抵达'],
    <String>['桥影落在水面', '慢行也会越过岸边'],
  ],
  'rest': <List<String>>[
    <String>['灯影早些收拢', '夜便还你一段安静'],
    <String>['空白不是遗漏', '它替明日留住呼吸'],
    <String>['杯底留一点温度', '今天可以在此停笔'],
  ],
  'relationship': <List<String>>[
    <String>['一句问候越过门槛', '两处窗灯便有了回应'],
    <String>['把谢谢说得慢些', '寻常相见也会发亮'],
    <String>['风替你轻叩窗扉', '真心不必绕远路'],
  ],
};

const Map<String, List<List<String>>> _verseEn = <String, List<List<String>>>{
  'focus': <List<String>>[
    <String>[
      'Window light rests on the page.',
      'One thing slowly finds its name.',
    ],
    <String>['Ink settles an inch deeper.', 'The noise makes room for a path.'],
    <String>[
      'Leave the distant sounds outside.',
      'What is near begins to show its grain.',
    ],
  ],
  'creativity': <List<String>>[
    <String>[
      'Wind crosses the open space.',
      'Three unfinished lines keep the light.',
    ],
    <String>[
      'The page carries no old footprints.',
      'One mark can still lead the way.',
    ],
    <String>['Tea steam rises lightly.', 'A sentence meets itself at the rim.'],
  ],
  'home': <List<String>>[
    <String>[
      'A worn thing catches morning light.',
      'Even a small seam holds an echo.',
    ],
    <String>[
      'A handspan clears at the table.',
      'The room gains a little wind.',
    ],
    <String>[
      'The hinge turns without hurry.',
      'An ordinary day fits together again.',
    ],
  ],
  'movement': <List<String>>[
    <String>[
      'Let each step fall half a beat slower.',
      'The long road still unfolds.',
    ],
    <String>[
      'Soles gather the sound of dust.',
      'The corner need not arrive early.',
    ],
    <String>[
      'A bridge shadow rests on water.',
      'Slow feet still reach the farther bank.',
    ],
  ],
  'rest': <List<String>>[
    <String>[
      'Gather the lamplight a little sooner.',
      'Night returns a quiet space.',
    ],
    <String>[
      'Blank space is not an omission.',
      'It keeps a breath for tomorrow.',
    ],
    <String>[
      'A little warmth remains in the cup.',
      'Today may end its line here.',
    ],
  ],
  'relationship': <List<String>>[
    <String>[
      'A greeting crosses the threshold.',
      'Two windows answer with light.',
    ],
    <String>[
      'Say thank you a little slower.',
      'An ordinary meeting begins to shine.',
    ],
    <String>[
      'The wind taps softly at the window.',
      'Sincerity needs no longer road.',
    ],
  ],
};

class AlmanacGenerator {
  const AlmanacGenerator();

  DailyLeaf generate({
    required DateTime date,
    required String installationSeed,
  }) {
    final dateKey = formatDateKey(date);
    final seed = stableHash('$generatorVersion|$installationSeed|$dateKey');
    final suitable = _pickPrompts(PromptSide.suitable, seed);
    final avoid = _pickPrompts(PromptSide.avoid, seed ^ 0x5bd1e995);
    final theme = suitable.first.domain;
    final options = _verseZh[theme]!;
    final verseIndex = (seed & 0x7fffffff) % options.length;
    return DailyLeaf(
      dateKey: dateKey,
      createdAt: date,
      generatorVersion: generatorVersion,
      seedFingerprint: seed.toUnsigned(32).toRadixString(16).padLeft(8, '0'),
      suitablePromptIds: suitable
          .map((item) => item.id)
          .toList(growable: false),
      avoidPromptIds: avoid.map((item) => item.id).toList(growable: false),
      verseZh: List<String>.unmodifiable(_verseZh[theme]![verseIndex]),
      verseEn: List<String>.unmodifiable(_verseEn[theme]![verseIndex]),
    );
  }

  List<PromptItem> _pickPrompts(PromptSide side, int seed) {
    final source = promptBank.where((item) => item.side == side).toList();
    final random = _DeterministicRandom(seed);
    for (var index = source.length - 1; index > 0; index--) {
      final swapIndex = random.nextInt(index + 1);
      final current = source[index];
      source[index] = source[swapIndex];
      source[swapIndex] = current;
    }
    final result = <PromptItem>[];
    final domains = <String>{};
    for (final item in source) {
      if (domains.add(item.domain)) result.add(item);
      if (result.length == 3) break;
    }
    return result;
  }
}

String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

class _DeterministicRandom {
  _DeterministicRandom(int seed) : _state = seed & 0xffffffff;

  int _state;

  int nextInt(int max) {
    _state = (1664525 * _state + 1013904223) & 0xffffffff;
    return (_state & 0x7fffffff) % max;
  }
}
