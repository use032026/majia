import 'package:flutter_test/flutter_test.dart';
import 'package:reader_edit/domain/revision_session.dart';

void main() {
  group('draft parsing and metrics', () {
    test('splits only on blank lines and normalizes outer whitespace', () {
      expect(
        splitDraft('  First line\ncontinues.\n\n Second passage. \n\n\n第三段。 '),
        ['First line\ncontinues.', 'Second passage.', '第三段。'],
      );
    });

    test('counts CJK characters and Latin words independently', () {
      const source = "今天 we can't stop 2026.";
      expect(countCjkCharacters(source), 2);
      expect(countLatinWords(source), 4);
    });
  });

  test('round-trips durable revision state and produces a truthful log', () {
    final session = RevisionSession(
      id: 's1',
      title: 'A scene',
      knowPromise: 'who arrived',
      feelPromise: 'uneasy',
      wonderPromise: 'what is hidden',
      updatedAt: DateTime.utc(2026, 9, 30),
      knowChecked: true,
      feelChecked: true,
      wonderChecked: true,
      passages: const [
        PassageRevision(
          id: 'p1',
          original: 'The door opened.',
          revised: 'The locked door opened by itself.',
          signal: ReaderSignal.lost,
          note: 'The cause was unclear.',
          isResolved: true,
        ),
        PassageRevision(
          id: 'p2',
          original: 'Mara waited.',
          revised: 'Mara waited.',
          signal: ReaderSignal.clear,
          isResolved: true,
        ),
      ],
    );

    final decoded = RevisionSession.decode(session.encode());
    expect(
      decoded.revisedDraft,
      'The locked door opened by itself.\n\nMara waited.',
    );
    expect(decoded.changedCount, 1);
    expect(decoded.unresolvedCount, 0);
    expect(decoded.isComplete, isTrue);
    expect(
      decoded.revisionLog(chinese: false),
      contains('Before: The door opened.'),
    );
    expect(
      decoded.revisionLog(chinese: false),
      contains('After: The locked door'),
    );
  });
}
