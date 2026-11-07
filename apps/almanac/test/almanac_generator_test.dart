import 'package:almanac/src/domain/almanac_content.dart';
import 'package:almanac/src/domain/almanac_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = AlmanacGenerator();

  test('all prompt IDs resolve without losing bilingual content or side', () {
    expect(
      promptBank.map((prompt) => prompt.id).toSet(),
      hasLength(promptBank.length),
    );
    for (final prompt in promptBank) {
      final resolved = promptById(prompt.id);
      expect(resolved.id, prompt.id);
      expect(resolved.side, prompt.side);
      expect(resolved.domain, prompt.domain);
      expect(resolved.text(useChinese: true), prompt.zh);
      expect(resolved.text(useChinese: false), prompt.en);
    }
  });

  test('unknown prompt lookup retains its StateError contract', () {
    for (final id in ['', 'removed-prompt']) {
      expect(
        () => promptById(id),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No element',
          ),
        ),
      );
    }
  });

  test(
    'leaf validation rejects unknown IDs and prompts from the wrong side',
    () {
      final original = generator.generate(
        date: DateTime(2026, 10, 10),
        installationSeed: 'validation-seed',
      );
      for (final side in PromptSide.values) {
        final key = side == PromptSide.suitable
            ? 'suitablePromptIds'
            : 'avoidPromptIds';
        final wrongSideId = promptBank
            .firstWhere((prompt) => prompt.side != side)
            .id;
        for (final id in ['removed-prompt', wrongSideId]) {
          final json = original.toJson();
          json[key] = [id, ...(json[key]! as List<String>).skip(1)];
          final leaf = DailyLeaf.fromJson(json);
          expect(
            () => validateLeafContent(leaf),
            throwsA(
              isA<FormatException>().having(
                (error) => error.message,
                'message',
                'Unknown or invalid ${side.name} prompt: $id',
              ),
            ),
          );
        }
      }
    },
  );

  test('same installation and date produces stable content', () {
    final date = DateTime(2026, 10, 10, 8);
    final first = generator.generate(date: date, installationSeed: 'seed-a');
    final second = generator.generate(date: date, installationSeed: 'seed-a');

    expect(second.suitablePromptIds, first.suitablePromptIds);
    expect(second.avoidPromptIds, first.avoidPromptIds);
    expect(second.verseZh, first.verseZh);
    expect(second.verseEn, first.verseEn);
    expect(second.seedFingerprint, first.seedFingerprint);
  });

  test('365 generated days satisfy content constraints in both languages', () {
    final fingerprints = <String>{};
    for (var offset = 0; offset < 365; offset++) {
      final leaf = generator.generate(
        date: DateTime(2026, 1, 1).add(Duration(days: offset)),
        installationSeed: 'constraint-seed',
      );
      expect(leaf.suitablePromptIds.toSet(), hasLength(3));
      expect(leaf.avoidPromptIds.toSet(), hasLength(3));
      expect(
        leaf.suitablePromptIds.map((id) => promptById(id).domain).toSet(),
        hasLength(3),
      );
      expect(
        leaf.avoidPromptIds.map((id) => promptById(id).domain).toSet(),
        hasLength(3),
      );
      expect(leaf.verseZh, hasLength(2));
      expect(leaf.verseEn, hasLength(2));
      expect(leaf.verseZh.every((line) => line.trim().isNotEmpty), isTrue);
      expect(leaf.verseEn.every((line) => line.trim().isNotEmpty), isTrue);
      fingerprints.add(leaf.seedFingerprint);
    }
    expect(fingerprints.length, greaterThan(350));
  });

  test('leaf JSON round trip preserves frozen generated content', () {
    final leaf = generator
        .generate(date: DateTime(2026, 10, 10), installationSeed: 'seed')
        .copyWith(
          selectedSuitableId: 's-clear-one',
          selectedAvoidId: 'a-open-many',
          intention: 'One clear thing.',
          outcome: ReflectionOutcome.reframed,
          sealedAt: DateTime(2026, 10, 10, 9),
          reflectedAt: DateTime(2026, 10, 10, 21),
        );

    final decoded = DailyLeaf.fromJson(leaf.toJson());
    expect(decoded.toJson(), leaf.toJson());
  });
}
