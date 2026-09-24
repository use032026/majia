import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof_lab/data/progress_repository.dart';
import 'package:plotproof_lab/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'shared preferences repository round-trips attempts, language, and onboarding',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesProgressRepository(preferences);
      final attempt = Attempt(
        lessonId: 'axis-baseline',
        verdict: Verdict.misleading,
        isCorrect: true,
        completedAt: DateTime.utc(2026, 9, 9, 8, 30),
        misconception: 'test misconception',
      );

      await repository.saveAttempts([attempt]);
      await repository.saveLanguageCode('en');
      expect(await repository.loadOnboardingCompleted(), isFalse);
      await repository.saveOnboardingCompleted(true);

      final restored = await repository.loadAttempts();
      expect(restored, hasLength(1));
      expect(restored.single.lessonId, attempt.lessonId);
      expect(restored.single.verdict, Verdict.misleading);
      expect(restored.single.completedAt, attempt.completedAt);
      expect(await repository.loadLanguageCode(), 'en');
      expect(await repository.loadOnboardingCompleted(), isTrue);

      await repository.clearAttempts();
      expect(await repository.loadAttempts(), isEmpty);
    },
  );

  test(
    'malformed local state fails visibly instead of silently mutating it',
    () async {
      SharedPreferences.setMockInitialValues({
        'learning_attempts_v1': '{not-json',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesProgressRepository(preferences);

      expect(repository.loadAttempts(), throwsA(isA<FormatException>()));
    },
  );
}
