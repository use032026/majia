import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:trip_delta/domain.dart';
import 'package:trip_delta/main.dart';
import 'package:trip_delta/onboarding.dart';
import 'package:trip_delta/screens.dart';
import 'package:trip_delta/site_update.dart';
import 'package:trip_delta/store.dart';
import 'package:trip_delta/web_startup.dart';
import 'package:trip_delta/web_launch_splash.dart';

void iosTestWidgets(String description, WidgetTesterCallback callback) =>
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

void androidTestWidgets(String description, WidgetTesterCallback callback) =>
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

void main() {
  late FakeUpdateCheck updateCheck;
  late FakeSession session;
  var tripCreations = 0;
  var onboarded = true;

  TripDeltaStartup app() => TripDeltaStartup(
    checkUpdate: updateCheck.call,
    session: session,
    tripBuilder: () {
      tripCreations++;
      return TripDeltaApp(store: MemoryTripStore('en', onboarded));
    },
  );

  setUp(() {
    updateCheck = FakeUpdateCheck();
    session = FakeSession();
    tripCreations = 0;
    onboarded = true;
  });

  iosTestWidgets(
    'side A opens Web without creating or flashing the trip home',
    (tester) async {
      updateCheck.gate = Completer<SiteUpdate>();
      await tester.pumpWidget(app());
      expect(updateCheck.calls, 1);
      expect(tripCreations, 0);
      expect(find.byType(TripDeltaApp), findsNothing);
      updateCheck.gate!.complete(FakeUpdateCheck.result('A'));
      await tester.pumpAndSettle();
      expect(tripCreations, 0);
      expect(session.opens, 1);
      expect(find.byType(TripDeltaApp), findsNothing);
      expect(find.byKey(const Key('web_only_home')), findsOneWidget);
      expect(find.byType(WebLaunchSplash), findsOneWidget);
    },
  );

  iosTestWidgets(
    'side B opens the native home and a long press cannot switch to Web',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final title = find.descendant(
        of: find.byKey(const PageStorageKey('current_trips_scroll')),
        matching: find.text('Current'),
      );
      final gesture = await tester.startGesture(tester.getCenter(title));
      await tester.pump(const Duration(seconds: 5));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(updateCheck.calls, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(session.opens, 0);
    },
  );

  iosTestWidgets(
    'an update check failure retains the original onboarding flow',
    (tester) async {
      updateCheck.fails = true;
      onboarded = false;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tripCreations, 1);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(session.opens, 0);
      expect(session.listeners, 0);
    },
  );

  iosTestWidgets('a late side A cannot switch home after the startup timeout', (
    tester,
  ) async {
    updateCheck.gate = Completer<SiteUpdate>();
    await tester.pumpWidget(app());
    expect(find.byType(HomeScreen), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    updateCheck.gate!.complete(FakeUpdateCheck.result('A'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(updateCheck.calls, 1);
    expect(session.opens, 0);
  });

  iosTestWidgets('H5 manual English overrides a Chinese system at cold start', (
    tester,
  ) async {
    updateCheck.side = 'A';
    session.launchLanguage = 'en-US';
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'zh',
      'CN',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<WebLaunchSplash>(find.byType(WebLaunchSplash)).languageCode,
      'en',
    );
    expect(session.opens, 1);
  });

  iosTestWidgets('without H5 choice the splash follows system Chinese', (
    tester,
  ) async {
    updateCheck.side = 'A';
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'zh',
      'TW',
    );
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<WebLaunchSplash>(find.byType(WebLaunchSplash)).languageCode,
      'zh',
    );
  });

  iosTestWidgets(
    'Web root close is terminal until explicit retry, never journey fallback',
    (tester) async {
      updateCheck.side = 'A';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      session.controller.add(
        const StminiEvent(name: 'web_closed', payload: {}),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('web_home_retry')), findsOneWidget);
      expect(tripCreations, 0);
      expect(session.opens, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(updateCheck.calls, 1);
      expect(session.opens, 1);
      await tester.tap(find.byKey(const Key('web_home_retry')));
      // StreamSubscription.cancel may return Dart's root-zone shared future.
      // Let real cancellation complete before flushing widget frames.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(session.opens, 2);
      expect(tripCreations, 0);
    },
  );

  iosTestWidgets('late native open completion cannot undo root-close error', (
    tester,
  ) async {
    updateCheck.side = 'A';
    session.openGate = Completer<void>();
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();
    expect(session.opens, 1);
    session.controller.add(const StminiEvent(name: 'web_closed', payload: {}));
    await tester.pump();
    session.openGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web_home_retry')), findsOneWidget);
    expect(tripCreations, 0);
    expect(session.opens, 1);
  });

  iosTestWidgets(
    'open failure and event errors allow retry within Web-only root',
    (tester) async {
      updateCheck.side = 'A';
      session.openFails = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('web_home_retry')), findsOneWidget);
      session.openFails = false;
      await tester.tap(find.byKey(const Key('web_home_retry')));
      // StreamSubscription.cancel may return Dart's root-zone shared future.
      // Let real cancellation complete before flushing widget frames.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(session.opens, 2);
      session.controller.addError(StateError('controlled channel failure'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('web_home_retry')), findsOneWidget);
      expect(tripCreations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  iosTestWidgets(
    'synchronously ended event stream is terminal before native open',
    (tester) async {
      updateCheck.side = 'A';
      session.eventSource = ImmediateClosedStream();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(session.opens, 0);
      expect(find.byKey(const Key('web_home_retry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('web_home_retry')));
      // StreamSubscription.cancel may return Dart's root-zone shared future.
      // Let real cancellation complete before flushing widget frames.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(session.opens, 0);
      expect(find.byKey(const Key('web_home_retry')), findsOneWidget);
      expect(tripCreations, 0);
    },
  );

  iosTestWidgets(
    'branded preparation stays visible and dark error text remains readable',
    (tester) async {
      updateCheck.side = 'A';
      session.openGate = Completer<void>();
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump();
      void checkReadable(Finder text) {
        final scaffold = tester.widget<Scaffold>(
          find.byKey(const Key('web_only_home')),
        );
        final context = tester.element(text);
        final scheme = Theme.of(context).colorScheme;
        expect(scaffold.backgroundColor, scheme.surface);
        final rich = tester.widget<RichText>(
          find.descendant(of: text, matching: find.byType(RichText)).first,
        );
        final foreground = rich.text.style!.color!;
        expect(foreground, scheme.onSurface);
        final contrast =
            (foreground.computeLuminance() + 0.05) /
            (scaffold.backgroundColor!.computeLuminance() + 0.05);
        expect(contrast, greaterThan(4.5));
      }

      expect(find.byType(WebLaunchSplash), findsOneWidget);
      session.controller.add(
        const StminiEvent(name: 'web_closed', payload: {}),
      );
      session.openGate!.complete();
      await tester.pumpAndSettle();
      checkReadable(find.text('Web home is unavailable. Please retry.'));
    },
  );

  iosTestWidgets('disposal ignores the pending startup decision', (
    tester,
  ) async {
    updateCheck.gate = Completer<SiteUpdate>();
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox());
    updateCheck.gate!.complete(FakeUpdateCheck.result('A'));
    await tester.pumpAndSettle();
    expect(session.opens, 0);
    expect(session.disposes, 1);
    expect(tripCreations, 0);
    expect(tester.takeException(), isNull);
  });

  androidTestWidgets(
    'Android retains its native startup and does not call the iOS gate',
    (tester) async {
      updateCheck.side = 'A';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(updateCheck.calls, 0);
      expect(session.opens, 0);
      expect(session.listeners, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  iosTestWidgets(
    'late open after disposing root cannot update UI or keep listeners',
    (tester) async {
      updateCheck.side = 'A';
      session.openGate = Completer<void>();
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump();
      expect(session.opens, 1);
      await tester.pumpWidget(const SizedBox());
      session.openGate!.complete();
      await tester.pumpAndSettle();
      expect(session.controller.hasListener, isFalse);
      expect(session.disposes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  iosTestWidgets('side A preserves the Web error locale and dark theme', (
    tester,
  ) async {
    updateCheck.side = 'A';
    session.launchLanguage = 'zh-CN';
    session.openFails = true;
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('网页首页暂时不可用，请重试。'), findsOneWidget);
    expect(find.byType(TripDeltaApp), findsNothing);
  });
}

class FakeUpdateCheck {
  String side = 'B';
  bool fails = false;
  int calls = 0;
  Completer<SiteUpdate>? gate;

  static SiteUpdate result(String side) =>
      SiteUpdate(side: side, hasUpdate: false, forceUpdate: false);

  Future<SiteUpdate> call() async {
    calls++;
    if (fails) throw StateError('controlled update check failure');
    return gate == null ? result(side) : gate!.future;
  }
}

class FakeSession implements WebRootSession {
  final controller = StreamController<StminiEvent>.broadcast(sync: true);
  int opens = 0;
  int listeners = 0;
  int disposes = 0;
  bool openFails = false;
  Stream<StminiEvent>? eventSource;
  Completer<void>? openGate;
  String? launchLanguage;
  @override
  Future<String?> readLaunchLanguage() async => launchLanguage;
  @override
  Stream<StminiEvent> get events {
    listeners++;
    return eventSource ?? controller.stream;
  }

  @override
  Future<void> open() async {
    opens++;
    await openGate?.future;
    if (openFails) throw StateError('controlled presentation failure');
  }

  @override
  void dispose() {
    disposes++;
    unawaited(controller.close());
  }
}

class MemoryTripStore implements TripStore {
  MemoryTripStore(String language, bool onboarded)
    : value = AppData(language: language, onboardingComplete: onboarded);
  AppData value;
  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData data) async => value = data;
}

class ImmediateClosedStream extends Stream<StminiEvent> {
  @override
  StreamSubscription<StminiEvent> listen(
    void Function(StminiEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    onDone?.call();
    return const Stream<StminiEvent>.empty().listen(null);
  }
}
