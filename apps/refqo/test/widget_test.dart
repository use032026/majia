import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refqo/main.dart';
import 'package:refqo/domain.dart';
import 'package:refqo/storage.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'share popover uses a tiny visible anchor rather than the full screen',
    (tester) async {
      final anchorKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(key: anchorKey, width: 400, height: 500),
          ),
        ),
      );
      final rect = shareAnchor(
        anchorKey.currentContext!.findRenderObject()! as RenderBox,
      );
      expect(rect.size, const Size(1, 1));
      expect(rect.left, greaterThan(0));
      expect(rect.top, greaterThan(0));
    },
  );

  test('locale resolution maps Chinese and falls back explicitly', () {
    expect(resolveLocale(const Locale('zh', 'TW')).languageCode, 'zh');
    expect(resolveLocale(const Locale('en', 'GB')).languageCode, 'en');
    expect(resolveLocale(const Locale('de')).languageCode, 'en');
  });
  testWidgets(
    'onboarding skip failure, retry, relaunch, replay retains library',
    (tester) async {
      final repo = MemoryRepository();
      repo.failNextSave = true;
      await tester.pumpWidget(RefqoApp(repository: repo));
      await tester.pumpAndSettle();
      await tap(tester, 'Skip');
      expect(repo.data.onboarded, false);
      expect(find.textContaining('Could not complete'), findsOneWidget);
      await tap(tester, 'Skip');
      expect(repo.data.onboarded, true);
      expect(find.text('Purchase plan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RefqoApp(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsNothing);
      await tap(tester, 'Settings');
      await tap(tester, 'Replay introduction');
      expect(find.text('Skip'), findsOneWidget);
      await tap(tester, 'Skip');
      expect(repo.data.onboarded, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'create, cancel/reopen editor, pooled plan, receive, replace, cancel/reopen confirm and undo',
    (tester) async {
      final repo = MemoryRepository(AppData(onboarded: true));
      await tester.pumpWidget(RefqoApp(repository: repo));
      await tester.pumpAndSettle();
      await tap(tester, 'Add a supply');
      await tester.enterText(find.byType(TextFormField).first, 'discard');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repo.data.supplies, isEmpty);
      await tap(tester, 'Add a supply');
      await tester.enterText(find.byType(TextFormField).at(0), 'Carbon refill');
      await tester.enterText(find.byType(TextFormField).at(1), 'C-42');
      await tap(tester, 'Save supply');
      await tap(tester, 'Supplies');
      await tap(tester, 'Carbon refill');
      await tap(tester, 'Link appliance');
      await tester.enterText(find.byType(TextFormField).at(0), 'Kitchen');
      await tester.enterText(find.byType(TextFormField).at(1), '15');
      await tap(tester, 'I checked this part fits');
      await tap(tester, 'Save appliance');
      await tap(tester, 'Receive');
      await tester.enterText(find.byType(TextFormField).first, '4');
      await tap(tester, 'Add to stock');
      expect(repo.data.supplies.single.stock, 4);
      await tap(tester, 'Replaced today');
      await tap(tester, 'Cancel');
      expect(repo.data.supplies.single.stock, 4);
      await tap(tester, 'Replaced today');
      await tap(tester, 'Confirm');
      expect(repo.data.supplies.single.stock, 3);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Plan');
      expect(find.textContaining('needed −'), findsOneWidget);
      await tap(tester, 'Ledger');
      await tap(tester, 'Undo latest entry');
      await tap(tester, 'Cancel');
      await tap(tester, 'Undo latest entry');
      await tap(tester, 'Confirm');
      expect(repo.data.supplies.single.stock, 4);
      expect(repo.data.events.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('explicit preferences persist and system clears overrides', (
    tester,
  ) async {
    final repo = MemoryRepository(AppData(onboarded: true));
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    expect(repo.data.language, isNull);
    expect(repo.data.appearance, isNull);
    await tap(tester, 'Settings');
    await tap(tester, 'Dark');
    await tap(tester, '简体中文');
    expect(repo.data.language, 'zh');
    expect(repo.data.appearance, 'dark');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    await tap(tester, '设置');
    final system = find.text('跟随系统');
    await tester.tap(system.first);
    await tester.pumpAndSettle();
    expect(repo.data.language, isNull);
    await tester.tap(find.text('System').last);
    await tester.pumpAndSettle();
    expect(repo.data.appearance, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('live system locale changes and no override is saved', (
    tester,
  ) async {
    final repo = MemoryRepository(AppData(onboarded: true));
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('Purchase plan'), findsOneWidget);
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'zh',
      'CN',
    );
    await tester.pumpAndSettle();
    expect(find.text('补货计划'), findsOneWidget);
    expect(repo.data.language, isNull);
    tester.binding.platformDispatcher.localeTestValue = const Locale('fr');
    await tester.pumpAndSettle();
    expect(find.text('Purchase plan'), findsOneWidget);
  });
  testWidgets('local recovery preview can cancel reopen confirm', (
    tester,
  ) async {
    final repo = RecoveryRepository();
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    await tap(tester, 'Preview local recovery copy');
    await tap(tester, 'Cancel');
    expect(repo.restored, false);
    await tap(tester, 'Preview local recovery copy');
    await tap(tester, 'Confirm');
    expect(repo.restored, true);
    expect(find.text('Purchase plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact large text form final action is scroll reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            viewPadding: const EdgeInsets.only(bottom: 34),
          ),
          child: child!,
        ),
        home: SupplyEditor(zh: false, save: (_, _, _) async => false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Long supply name that should wrap without clipping',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save supply'));
    await tester.pumpAndSettle();
    expect(find.text('Save supply').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class RecoveryRepository extends FileRepository {
  RecoveryRepository() : super(Directory.systemTemp);
  bool restored = false;
  @override
  Future<AppData> load() async => throw const FormatException('corrupt');
  @override
  Future<AppData> loadPrevious() async => AppData(
    onboarded: true,
    supplies: const [Supply(id: 'r', name: 'Recovered refill')],
  );
  @override
  Future<void> restore(AppData data) async {
    restored = true;
  }
}
