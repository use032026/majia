import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refqo/domain.dart';
import 'package:refqo/main.dart';
import 'package:refqo/storage.dart';
import 'package:share_plus/share_plus.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

TextField input(WidgetTester tester, int index) => tester.widget<TextField>(
  find.descendant(
    of: find.byType(TextFormField).at(index),
    matching: find.byType(TextField),
  ),
);

Future<void> editor(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Chinese composition is preserved and cannot submit unfinished text',
    (tester) async {
      var saves = 0;
      await editor(
        tester,
        SupplyEditor(
          zh: true,
          save: (name, code, notes) async {
            saves++;
            expect(name, '客厅滤芯');
            expect(notes, '请核对中文标签');
            return false;
          },
        ),
      );
      await tester.showKeyboard(find.byType(TextFormField).first);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'keting',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 0, end: 6),
        ),
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saves, 0);
      expect(
        input(tester, 0).controller!.value.composing,
        const TextRange(start: 0, end: 6),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '客厅滤芯',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      input(tester, 2).controller!.text = '请核对中文标签';
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(input(tester, 0).controller!.text, '客厅滤芯');
      expect(input(tester, 2).controller!.text, '请核对中文标签');
    },
  );

  testWidgets('throwing save recovers button and retains the complete draft', (
    tester,
  ) async {
    var calls = 0;
    await editor(
      tester,
      SupplyEditor(
        zh: false,
        save: (_, _, _) async {
          calls++;
          throw const FileSystemException('disk full');
        },
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '中文耗材');
    await tapText(tester, 'Save supply');
    expect(find.textContaining('Your input is retained'), findsOneWidget);
    expect(input(tester, 0).controller!.text, '中文耗材');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNotNull,
    );
    await tapText(tester, 'Save supply');
    expect(calls, 2);
  });

  testWidgets(
    'pending save acknowledges within one frame, blocks duplicates and back navigation',
    (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      await editor(
        tester,
        SupplyEditor(
          zh: false,
          save: (_, _, _) {
            calls++;
            return pending.future;
          },
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Filter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(find.text('Saving…'), findsWidgets);
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      expect(
        tester.widget<PopScope>(find.byType(PopScope).first).canPop,
        false,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining('Still saving'), findsOneWidget);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('Enter validates and focuses the first invalid field', (
    tester,
  ) async {
    var saves = 0;
    await editor(
      tester,
      SupplyEditor(
        zh: false,
        save: (_, _, _) async {
          saves++;
          return false;
        },
      ),
    );
    await tester.showKeyboard(find.byType(TextFormField).at(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(input(tester, 0).focusNode!.hasFocus, true);
    expect(find.text('Supply name *'), findsOneWidget);
  });

  testWidgets(
    'Tab, Shift Tab and vertical arrows switch fields; horizontal arrows keep caret',
    (tester) async {
      await editor(
        tester,
        SupplyEditor(zh: false, save: (_, _, _) async => false),
      );
      await tester.enterText(find.byType(TextFormField).first, 'AB');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(input(tester, 0).focusNode!.hasFocus, true);
      expect(input(tester, 0).controller!.selection.extentOffset, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(input(tester, 1).focusNode!.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(input(tester, 2).focusNode!.hasFocus, true);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(input(tester, 1).focusNode!.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(input(tester, 0).focusNode!.hasFocus, true);
    },
  );

  testWidgets(
    'multiline arrows preserve internal navigation, selection and composition',
    (tester) async {
      await editor(
        tester,
        SupplyEditor(zh: false, save: (_, _, _) async => false),
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'first\nmiddle\nlast',
      );
      final notes = input(tester, 2).controller!;
      notes.selection = const TextSelection.collapsed(offset: 8);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(input(tester, 2).focusNode!.hasFocus, true);
      notes.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(input(tester, 2).focusNode!.hasFocus, true);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'zhong',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(input(tester, 2).focusNode!.hasFocus, true);
      notes.value = const TextEditingValue(
        text: 'first\nlast',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(input(tester, 1).focusNode!.hasFocus, true);
    },
  );

  testWidgets(
    'wrapped visual lines keep arrow navigation inside the notes field',
    (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await editor(
        tester,
        SupplyEditor(zh: false, save: (_, _, _) async => false),
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'This long note wraps across several visual lines without newline characters. ' *
            3,
      );
      final notes = input(tester, 2).controller!;
      notes.selection = const TextSelection.collapsed(offset: 70);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(input(tester, 2).focusNode!.hasFocus, true);
      notes.selection = const TextSelection.collapsed(offset: 70);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(input(tester, 2).focusNode!.hasFocus, true);
    },
  );

  testWidgets(
    'multiline Enter leaves newline editing to IME; Ctrl Enter submits once',
    (tester) async {
      var saves = 0;
      await editor(
        tester,
        SupplyEditor(
          zh: false,
          save: (_, _, _) async {
            saves++;
            return false;
          },
        ),
      );
      input(tester, 0).controller!.text = 'Filter';
      await tester.enterText(find.byType(TextFormField).at(2), 'note');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(saves, 0);
      expect(input(tester, 2).controller!.text, 'note');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'note\n',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      expect(input(tester, 2).controller!.text, 'note\n');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(saves, 1);
    },
  );

  testWidgets(
    'Backspace repeats delete graphemes once; empty and selected text are safe',
    (tester) async {
      await editor(
        tester,
        SupplyEditor(zh: false, save: (_, _, _) async => false),
      );
      await tester.enterText(find.byType(TextFormField).first, 'A中👨‍👩‍👦B');
      final controller = input(tester, 0).controller!;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, 'A中👨‍👩‍👦');
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, 'A中');
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, 'A');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.text, 'A');
      controller.value = const TextEditingValue(
        text: 'ABCD',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, 'AD');
      controller.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard centers first and last inputs and restores original scroll offset',
    (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await editor(
        tester,
        SupplyEditor(zh: false, save: (_, _, _) async => false),
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final original = scrollable.position.pixels;
      await tester.showKeyboard(find.byType(TextFormField).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(SingleChildScrollView).first);
      expect(
        (tester.getRect(find.byType(TextFormField).first).center.dy -
                viewport.center.dy)
            .abs(),
        lessThanOrEqualTo(24),
      );
      await tester.showKeyboard(find.byType(TextFormField).last);
      await tester.pumpAndSettle();
      expect(
        (tester.getRect(find.byType(TextFormField).last).center.dy -
                viewport.center.dy)
            .abs(),
        lessThanOrEqualTo(24),
      );
      input(tester, 2).focusNode!.unfocus();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(
        (scrollable.position.pixels - original).abs(),
        lessThanOrEqualTo(2),
      );
      expect(find.text('Done'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'double text size keyboard toolbar and final action remain reachable',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: SupplyEditor(zh: false, save: (_, _, _) async => false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextFormField).last);
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      expect(find.text('Done').hitTestable(), findsOneWidget);
      expect(find.text('Hide keyboard').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'receipt validates aggregate stock and readonly history date skips traversal',
    (tester) async {
      var calls = 0;
      await editor(
        tester,
        ReceiveEditor(
          zh: false,
          name: 'Filter',
          currentStock: 99999,
          save: (_) async {
            calls++;
            return false;
          },
        ),
      );
      await tapText(tester, 'Add to stock');
      expect(calls, 0);
      expect(find.text('Total stock cannot exceed 99999'), findsOneWidget);
      await editor(
        tester,
        SlotEditor(
          zh: false,
          supply: const Supply(id: 'a', name: 'Filter'),
          hasHistory: true,
          save: (_, _, _, _, _) async => false,
        ),
      );
      expect(input(tester, 3).readOnly, true);
      await tester.showKeyboard(find.byType(TextFormField).at(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(input(tester, 3).focusNode!.hasFocus, false);
    },
  );

  testWidgets(
    'details show pending writes immediately and only one replacement is saved',
    (tester) async {
      final repo = DelayedRepository(
        AppData(
          onboarded: true,
          supplies: const [Supply(id: 'a', name: 'Filter', stock: 3)],
          slots: [
            Slot(
              id: 's',
              supplyId: 'a',
              name: 'Kitchen',
              intervalDays: 30,
              lastChanged: DateTime.utc(2026, 1, 1),
              verified: true,
            ),
          ],
        ),
      );
      await tester.pumpWidget(RefqoApp(repository: repo));
      await tester.pumpAndSettle();
      await tapText(tester, 'Filter');
      await tapText(tester, 'Replaced today');
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Replaced today'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.saves, 1);
      expect(repo.data.events, isEmpty);
      repo.pending.complete();
      await tester.pumpAndSettle();
      expect(repo.data.supplies.single.stock, 2);
      expect(repo.data.events.length, 1);
      expect(find.textContaining('Replacement recorded'), findsOneWidget);
      expect(find.text('View ledger'), findsOneWidget);
    },
  );

  testWidgets(
    'share cancellation and unavailable results have accurate feedback and no mutation',
    (tester) async {
      var result = const ShareResult('', ShareResultStatus.dismissed);
      final repo = MemoryRepository(
        AppData(
          onboarded: true,
          supplies: const [Supply(id: 'a', name: 'Filter')],
          slots: [
            Slot(
              id: 's',
              supplyId: 'a',
              name: 'Kitchen',
              intervalDays: 30,
              lastChanged: DateTime.utc(2026, 1, 1),
              verified: true,
            ),
          ],
        ),
      );
      final before = encodeAppData(repo.data);
      await tester.pumpWidget(
        RefqoApp(repository: repo, share: (_) async => result),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Share purchase list');
      expect(find.textContaining('Sharing cancelled'), findsOneWidget);
      result = ShareResult.unavailable;
      await tapText(tester, 'Share purchase list');
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      expect(encodeAppData(repo.data), before);
    },
  );

  testWidgets(
    'file-picker cancellation and errors release the lock and retain library',
    (tester) async {
      final repo = MemoryRepository(AppData(onboarded: true));
      await tester.pumpWidget(
        RefqoApp(repository: repo, pickBackup: () async => null),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Settings');
      await tapText(tester, 'Restore backup');
      expect(find.textContaining('Import cancelled'), findsOneWidget);
      await tester.pumpWidget(
        RefqoApp(
          key: const ValueKey('errors'),
          repository: repo,
          pickBackup: () async =>
              throw const FileSystemException('provider denied'),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Settings');
      await tapText(tester, 'Restore backup');
      expect(
        find.textContaining('Could not restore this backup'),
        findsOneWidget,
      );
      expect(find.text('Choose backup'), findsOneWidget);
      expect(repo.data.supplies, isEmpty);
    },
  );

  testWidgets(
    'erasure cleanup failure displays committed empty library and can retry',
    (tester) async {
      final repo = PartialEraseRepository(
        AppData(
          onboarded: true,
          supplies: const [Supply(id: 'a', name: 'Filter', stock: 3)],
        ),
      );
      await tester.pumpWidget(
        RefqoApp(
          repository: repo,
          temporaryDirectory: () async => AbsentDirectory(),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Settings');
      await tapText(tester, 'Erase local library');
      await tapText(tester, 'Confirm');
      expect(
        find.textContaining('Library cleared. Some old copies'),
        findsOneWidget,
      );
      expect(find.text('Retry cleanup'), findsOneWidget);
      await tapText(tester, 'Retry cleanup');
      expect(
        find.textContaining('Local library and owned recovery copies cleared'),
        findsOneWidget,
      );
      await tapText(tester, 'Supplies');
      expect(find.text('Your shelf is empty'), findsOneWidget);
      expect(repo.data.supplies, isEmpty);
    },
  );

  testWidgets(
    'restore preview cancel keeps old data; confirm persists replacement across reload',
    (tester) async {
      final original = AppData(
        onboarded: true,
        supplies: const [Supply(id: 'old', name: 'Old filter')],
      );
      final replacement = AppData(
        onboarded: true,
        supplies: const [Supply(id: 'new', name: '中文备份滤芯')],
      );
      final repo = MemoryRepository(original);
      final backup = XFile.fromData(
        Uint8List.fromList(utf8.encode(encodeAppData(replacement))),
        name: 'backup.json',
      );
      await tester.pumpWidget(
        RefqoApp(repository: repo, pickBackup: () async => backup),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Settings');
      await tapText(tester, 'Restore backup');
      expect(find.text('Replace library?'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(encodeAppData(repo.data), encodeAppData(original));
      await tapText(tester, 'Restore backup');
      await tapText(tester, 'Confirm');
      expect(repo.data.supplies.single.name, '中文备份滤芯');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RefqoApp(repository: repo));
      await tester.pumpAndSettle();
      await tapText(tester, 'Supplies');
      expect(find.text('中文备份滤芯'), findsOneWidget);
    },
  );

  testWidgets(
    'share failures expose a working retry without duplicate launch',
    (tester) async {
      var attempts = 0;
      final repo = MemoryRepository(
        AppData(
          onboarded: true,
          supplies: const [Supply(id: 'a', name: 'Filter')],
          slots: [
            Slot(
              id: 's',
              supplyId: 'a',
              name: 'Kitchen',
              intervalDays: 30,
              lastChanged: DateTime.utc(2026),
              verified: true,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        RefqoApp(
          repository: repo,
          share: (_) async {
            attempts++;
            if (attempts == 1) throw const FileSystemException('share failed');
            return const ShareResult('target', ShareResultStatus.success);
          },
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Share purchase list');
      expect(
        find.text('Sharing did not finish. Please retry.'),
        findsOneWidget,
      );
      await tapText(tester, 'Retry');
      expect(
        find.text('Purchase list handed to the selected destination.'),
        findsOneWidget,
      );
      expect(attempts, 2);
      expect(repo.data.events, isEmpty);
    },
  );

  testWidgets('next action remains valid after leaving the details route', (
    tester,
  ) async {
    final repo = MemoryRepository(
      AppData(
        onboarded: true,
        supplies: const [Supply(id: 'a', name: 'Filter', stock: 2)],
        slots: [
          Slot(
            id: 's',
            supplyId: 'a',
            name: 'Kitchen',
            intervalDays: 30,
            lastChanged: DateTime.utc(2026),
            verified: true,
          ),
        ],
      ),
    );
    await tester.pumpWidget(RefqoApp(repository: repo));
    await tester.pumpAndSettle();
    await tapText(tester, 'Filter');
    await tapText(tester, 'Receive');
    await tapText(tester, 'Add to stock');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'View ledger');
    expect(find.text('Stock ledger'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid inset changes and disposal cancel obsolete scroll requests',
    (tester) async {
      addTearDown(tester.view.resetViewInsets);
      await editor(
        tester,
        SupplyEditor(zh: false, save: (_, _, _) async => false),
      );
      await tester.showKeyboard(find.byType(TextFormField).first);
      for (final bottom in [300.0, 500.0, 0.0, 250.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: bottom);
        await tester.pump();
      }
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('maximum ledger builds only visible entries', (tester) async {
    var data = AppData(
      onboarded: true,
      supplies: const [Supply(id: 'a', name: 'Filter')],
    );
    for (var i = 0; i < maxEvents; i++) {
      data = receiveSupply(
        data,
        'a',
        1,
        DateTime.utc(2026).add(Duration(seconds: i)),
      );
    }
    await tester.pumpWidget(RefqoApp(repository: MemoryRepository(data)));
    await tester.pumpAndSettle();
    await tapText(tester, 'Ledger');
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });
}

class DelayedRepository extends MemoryRepository {
  DelayedRepository(super.data);
  final pending = Completer<void>();
  int saves = 0;
  @override
  Future<void> save(AppData next) async {
    saves++;
    await pending.future;
    await super.save(next);
  }
}

class PartialEraseRepository extends MemoryRepository {
  PartialEraseRepository(super.data);
  bool fail = true;
  @override
  Future<void> erase(AppData empty) async {
    data = empty;
    if (fail) {
      fail = false;
      throw EraseCleanupException(
        empty,
        const FileSystemException('old copy locked'),
      );
    }
  }
}

class AbsentDirectory extends Fake implements Directory {
  @override
  Future<bool> exists() async => false;
}
