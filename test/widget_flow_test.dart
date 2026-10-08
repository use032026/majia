import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:somniloquy/app.dart';
import 'package:somniloquy/controllers/app_controller.dart';
import 'package:somniloquy/domain/models.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('consent cancel, reopen, record, stop, review, and archive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemorySessionRepository();
    final controller = AppController(
      repository: repository,
      recorder: FakeRecorderService(),
      player: FakeClipPlayerService(),
    );
    await controller.initialize();
    await tester.pumpWidget(SomniloquyApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('prepare_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room_consent_checkbox')), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.isRecording, isFalse);

    await tester.tap(find.byKey(const Key('prepare_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_consent_checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_start_button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('recording_timer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stop_recording_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续录音'));
    await tester.pumpAndSettle();
    expect(controller.isRecording, isTrue);

    await tester.tap(find.byKey(const Key('stop_recording_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_stop_button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('morning_note_field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('morning_note_field')),
      '一列安静的火车',
    );
    await tester.tap(find.byKey(const Key('save_card_button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.sessions, hasLength(1));

    await tester.tap(find.byKey(const Key('archive_tab')));
    await tester.pumpAndSettle();
    expect(find.text('一列安静的火车'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('permission denial leaves history and settings reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recorder = FakeRecorderService()..permission = false;
    final controller = AppController(
      repository: MemorySessionRepository(),
      recorder: recorder,
      player: FakeClipPlayerService(),
    );
    await controller.initialize();
    await tester.pumpWidget(SomniloquyApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('prepare_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_consent_checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_start_button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('系统设置'), findsOneWidget);
    expect(controller.isRecording, isFalse);

    await tester.tap(find.byKey(const Key('settings_tab')));
    await tester.pumpAndSettle();
    expect(find.text('隐私与边界'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('small screen large text and tablet rail remain exception free', (
    tester,
  ) async {
    final controller = AppController(
      repository: MemorySessionRepository(localeCode: 'en'),
      recorder: FakeRecorderService(),
      player: FakeClipPlayerService(),
    );
    await controller.initialize();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(SomniloquyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('prepare_button')),
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.byKey(const Key('prepare_button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(834, 1194);
    await tester.pumpWidget(SomniloquyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('review can keep, resume, and permanently delete a local draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final draft = NightSession(
      id: 'draft',
      startedAt: DateTime(2026, 10, 8, 23),
      endedAt: DateTime(2026, 10, 9, 7),
      audioPath: '/memory/draft.m4a',
      prompt: '',
      contextTags: const [],
      moments: const [],
    );
    final repository = MemorySessionRepository(sessions: [draft]);
    final controller = AppController(
      repository: repository,
      recorder: FakeRecorderService(),
      player: FakeClipPlayerService(),
    );
    await controller.initialize();
    await tester.pumpWidget(SomniloquyApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('morning_note_field')), '不应保存');
    await tester.tap(find.byKey(const Key('review_later_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('keep_review_draft_button')));
    await tester.pumpAndSettle();
    expect(controller.reviewSession, isNull);
    expect(repository.state.sessions.single.morningNote, isEmpty);
    expect(find.text('待晨间核对'), findsOneWidget);

    await tester.tap(find.text('待晨间核对'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('morning_note_field')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('morning_note_field')))
          .controller
          ?.text,
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('review_later_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_review_draft_button')));
    await tester.pumpAndSettle();
    expect(controller.sessions, isEmpty);
    expect(repository.audioPaths, isEmpty);
    controller.dispose();
  });

  testWidgets('recording stop remains reachable in landscape with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppController(
      repository: MemorySessionRepository(localeCode: 'en'),
      recorder: FakeRecorderService(),
      player: FakeClipPlayerService(),
    );
    await controller.initialize();
    await controller.startRecording(prompt: '', contextTags: const []);
    await tester.pumpWidget(SomniloquyApp(controller: controller));
    await tester.pumpAndSettle();

    final stopButton = find.byKey(const Key('stop_recording_button'));
    await tester.ensureVisible(stopButton);
    await tester.pumpAndSettle();
    expect(stopButton, findsOneWidget);
    expect(tester.getRect(stopButton).bottom, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm_stop_button')), findsOneWidget);
    await tester.tap(find.text('Keep recording'));
    await tester.pumpAndSettle();
    expect(controller.isRecording, isTrue);
    controller.dispose();
  });
}
