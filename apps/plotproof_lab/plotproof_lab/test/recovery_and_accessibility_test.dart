import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof_lab/app.dart';
import 'package:plotproof_lab/data/progress_repository.dart';
import 'package:plotproof_lab/domain/models.dart';
import 'package:plotproof_lab/state/app_controller.dart';
import 'package:plotproof_lab/ui/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('corrupt local data presents a confirmed recovery action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'learning_attempts_v1': '{not-json',
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(
      SharedPreferencesProgressRepository(preferences),
    );
    await controller.initialize(systemLocale: const Locale('zh'));
    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.hasRecoverableLoadError, isTrue);
    expect(find.byKey(const Key('storage-error-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-corrupt-data')));
    await tester.pumpAndSettle();
    expect(find.text('清除本地记录？'), findsOneWidget);
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(controller.errorMessage, isNull);
    expect(find.byKey(const Key('storage-error-banner')), findsNothing);
    expect(preferences.containsKey('learning_attempts_v1'), isFalse);
  });

  testWidgets('home remains usable in dark mode at large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppController(
      MemoryProgressRepository(onboardingCompleted: true),
    );
    await controller.initialize(systemLocale: const Locale('zh'));

    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('把“看起来”变成“有证据”'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed corrupt-data reset keeps an accurate retry action', (
    tester,
  ) async {
    final repository = _FailOnceRecoveryRepository();
    final controller = AppController(repository);
    await controller.initialize(systemLocale: const Locale('zh'));
    await tester.pumpWidget(PlotProofApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reset-corrupt-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(controller.errorKind, AppErrorKind.clear);
    expect(find.text('无法清除损坏的本地记录，请重试。'), findsOneWidget);
    expect(find.byKey(const Key('reset-corrupt-data')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reset-corrupt-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(controller.errorMessage, isNull);
    expect(find.byKey(const Key('storage-error-banner')), findsNothing);
  });

  test('semantic container color pairs meet normal-text contrast', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      expect(
        _contrast(scheme.primaryContainer, scheme.onPrimaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.secondaryContainer, scheme.onSecondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.errorContainer, scheme.onErrorContainer),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

class _FailOnceRecoveryRepository implements ProgressRepository {
  var clearCalls = 0;

  @override
  Future<void> clearAttempts() async {
    clearCalls += 1;
    if (clearCalls == 1) throw StateError('Test clear failure');
  }

  @override
  Future<List<Attempt>> loadAttempts() async =>
      throw const FormatException('Test corrupt data');

  @override
  Future<String?> loadLanguageCode() async => 'zh';

  @override
  Future<bool> loadOnboardingCompleted() async => false;

  @override
  Future<void> saveAttempts(List<Attempt> attempts) async {}

  @override
  Future<void> saveLanguageCode(String languageCode) async {}

  @override
  Future<void> saveOnboardingCompleted(bool completed) async {}
}

double _contrast(Color first, Color second) {
  final lighter = math.max(first.computeLuminance(), second.computeLuminance());
  final darker = math.min(first.computeLuminance(), second.computeLuminance());
  return (lighter + 0.05) / (darker + 0.05);
}
