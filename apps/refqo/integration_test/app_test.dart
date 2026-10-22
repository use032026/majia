import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:refqo/main.dart';
import 'package:refqo/domain.dart';
import 'package:refqo/storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline shelf purchase replace undo and persistence on device', (
    tester,
  ) async {
    binding.platformDispatcher.localeTestValue = const Locale('en');
    final dir = await getApplicationSupportDirectory();
    final repo = FileRepository(dir);
    await repo.erase(AppData());
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(String text) async {
      final f = find.text(text).last;
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await shot('01-onboarding');
    await tap('Skip');
    await shot('02-empty-plan');
    await tap('Add a supply');
    await tester.enterText(find.byType(TextFormField).at(0), 'Carbon refill');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'CR-42 / 120 × 80 mm',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Check the housing label before buying. Shared by both kitchen and study.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tap('Save supply');
    await tap('Supplies');
    await tap('Carbon refill');
    for (final name in ['Kitchen purifier', 'Study purifier']) {
      await tap('Link appliance');
      await tester.enterText(find.byType(TextFormField).at(0), name);
      await tester.enterText(find.byType(TextFormField).at(1), '15');
      await tap('I checked this part fits');
      await tap('Save appliance');
    }
    await tap('Receive');
    await tester.enterText(find.byType(TextFormField).first, '2');
    await tap('Add to stock');
    await shot('03-supply-devices');
    await tap('Replaced today');
    await shot('04-replace-confirm');
    await tap('Cancel');
    await tap('Replaced today');
    await tap('Confirm');
    expect((await repo.load()).supplies.single.stock, 1);
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    await tap('Plan');
    await shot('05-pooled-plan');
    await tap('60 days');
    await shot('06-sixty-day-plan');
    await tap('Ledger');
    await shot('07-ledger');
    await tap('Undo latest entry');
    await tap('Confirm');
    expect((await repo.load()).supplies.single.stock, 2);
    await tap('Settings');
    await tap('Dark');
    await tap('简体中文');
    await shot('08-settings-zh-dark');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(RefqoApp(repository: FileRepository(dir)));
    await tester.pumpAndSettle();
    expect(find.text('补货计划'), findsOneWidget);
    await shot('09-returning-zh-dark');
    await tap('设置');
    await tap('重新查看引导');
    await shot('10-replay-zh');
    await tap('跳过');
    await tap('设置');
    await tap('English');
    await tap('Light');
    await tap('Plan');
    binding.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    await shot('11-plan-large-text');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    await shot('12-plan-large-text-end');
    binding.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
