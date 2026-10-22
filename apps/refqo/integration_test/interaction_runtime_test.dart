import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:refqo/domain.dart';
import 'package:refqo/main.dart';
import 'package:refqo/storage.dart';

import 'app_test.dart' as regression;

void main() {
  if (!const bool.fromEnvironment('REFQO_QA')) {
    throw StateError(
      'Use --dart-define=REFQO_QA=true on a disposable Refqo QA installation.',
    );
  }
  regression.main();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitUntil(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 250; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (condition()) return;
    }
    throw StateError('Runtime condition did not become ready');
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'native keyboard geometry, Chinese persistence and next-step links',
    (tester) async {
      binding.platformDispatcher.localeTestValue = const Locale('en');
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/interaction-qa',
      );
      final repo = FileRepository(dir);
      await repo.erase(AppData(onboarded: true));
      await tester.pumpWidget(RefqoApp(repository: repo));
      await tester.pumpAndSettle();
      await tap(tester, 'Add a supply');
      final formScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final original = formScroll.position.pixels;
      await tester.tap(find.byType(TextFormField).first);
      await waitUntil(
        tester,
        () =>
            View.of(
              tester.element(find.byType(TextFormField).first),
            ).viewInsets.bottom >
            0,
      );
      await tester.pumpAndSettle();
      double centerError(Finder field) =>
          (tester.getRect(field).center.dy -
                  tester
                      .getRect(find.byType(SingleChildScrollView).first)
                      .center
                      .dy)
              .abs();
      final firstError = centerError(find.byType(TextFormField).first);
      expect(firstError, lessThanOrEqualTo(24));
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('13-native-keyboard-first');
      await tester.enterText(find.byType(TextFormField).first, '客厅滤芯');
      await tester.enterText(
        find.byType(TextFormField).last,
        '请核对中文标签；不自动判断适配。',
      );
      await tester.pumpAndSettle();
      final lastError = centerError(find.byType(TextFormField).last);
      expect(lastError, lessThanOrEqualTo(24));
      await binding.takeScreenshot('14-native-keyboard-notes');
      await tap(tester, 'Hide keyboard');
      await waitUntil(
        tester,
        () =>
            View.of(
              tester.element(find.byType(TextFormField).first),
            ).viewInsets.bottom ==
            0,
      );
      await tester.pumpAndSettle();
      final restoreError = (formScroll.position.pixels - original).abs();
      expect(restoreError, lessThanOrEqualTo(2));
      await binding.takeScreenshot('15-keyboard-restored');
      await tap(tester, 'Save supply');
      expect((await repo.load()).supplies.single.name, '客厅滤芯');
      expect((await repo.load()).supplies.single.notes, contains('中文标签'));
      expect(find.text('Supply saved.'), findsOneWidget);
      await tap(tester, 'Link appliance');
      await tester.enterText(find.byType(TextFormField).first, '书房净化器');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(tester, 'I checked this part fits');
      await tap(tester, 'Save appliance');
      await tap(tester, 'View plan');
      expect(find.text('书房净化器 · 0 × 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RefqoApp(repository: FileRepository(dir)));
      await tester.pumpAndSettle();
      expect((await repo.load()).slots.single.name, '书房净化器');
      await binding.takeScreenshot('16-chinese-reloaded');
      final evidence = {
        'platform': Platform.operatingSystem,
        'first_center_error_logical_px': firstError,
        'last_center_error_logical_px': lastError,
        'restoration_error_logical_px': restoreError,
        'native_keyboard_visible': true,
        'chinese_values_injected_via_flutter_test_text_input': true,
        'native_chinese_ime_candidate_selection_tested': false,
      };
      binding.reportData ??= {};
      binding.reportData!['keyboard'] = evidence;
      // Also retained in driver logs when screenshots are collected separately.
      // ignore: avoid_print
      print('REFQO_KEYBOARD_EVIDENCE ${jsonEncode(evidence)}');
    },
  );

  testWidgets(
    '30 real-file saves measure dispatch to first framework feedback frame',
    (tester) async {
      binding.platformDispatcher.localeTestValue = const Locale('en');
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/latency-qa',
      );
      final repo = FileRepository(dir);
      await repo.erase(AppData(onboarded: true));
      await repo.save(
        AppData(
          onboarded: true,
          supplies: const [Supply(id: 'latency', name: 'Latency refill')],
        ),
      );
      await tester.pumpWidget(RefqoApp(repository: repo));
      await tester.pumpAndSettle();
      await tap(tester, 'Supplies');
      await tap(tester, 'Latency refill');
      final samples = <double>[];
      for (var i = 0; i < 30; i++) {
        await tap(tester, 'Receive');
        final button = find.text('Add to stock');
        await tester.ensureVisible(button);
        final stopwatch = Stopwatch()..start();
        double? firstFrame;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          firstFrame = stopwatch.elapsedMicroseconds / 1000;
        });
        await tester.tap(button);
        await tester.pump();
        await waitUntil(
          tester,
          () =>
              find
                  .textContaining('Received 1 unit(s).')
                  .evaluate()
                  .isNotEmpty &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        samples.add(firstFrame!);
        expect((await repo.load()).supplies.single.stock, i + 1);
      }
      final ordered = [...samples]..sort();
      final evidence = {
        'platform': Platform.operatingSystem,
        'mode': const bool.fromEnvironment('dart.vm.product')
            ? 'release'
            : 'debug_or_profile',
        'samples': samples,
        'count': samples.length,
        'median_ms': ordered[15],
        'p95_ms': ordered[28],
        'max_ms': ordered.last,
        'measures':
            'tap dispatch to first Flutter post-frame callback; excludes raster/presentation latency',
        'physical_device': false,
      };
      binding.reportData ??= {};
      binding.reportData!['save_feedback'] = evidence;
      // ignore: avoid_print
      print('REFQO_FEEDBACK_EVIDENCE ${jsonEncode(evidence)}');
      expect(
        ordered.last,
        lessThanOrEqualTo(100),
        reason: 'Framework acknowledgement exceeded 100 ms',
      );
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      await binding.takeScreenshot('17-thirty-saves-complete');
      expect(tester.takeException(), isNull);
    },
  );
}
