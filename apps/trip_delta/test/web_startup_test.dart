import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:trip_delta/domain.dart';
import 'package:trip_delta/main.dart';
import 'package:trip_delta/onboarding.dart';
import 'package:trip_delta/screens.dart';
import 'package:trip_delta/store.dart';
import 'package:trip_delta/web_mode_actions.dart';
import 'package:trip_delta/web_startup.dart';
import 'package:trip_delta/web_startup_preference.dart';
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
  late FakePreference preference;
  late FakeSession session;
  late MemoryTripStore store;
  var tripCreations = 0;
  var language = 'en';
  var onboarded = true;
  WebModeActions? lastActions;

  TripDeltaStartup app() => TripDeltaStartup(
    preference: preference,
    session: session,
    tripBuilder: (actions) {
      tripCreations++;
      lastActions = actions;
      store = MemoryTripStore(language, onboarded);
      return TripDeltaApp(store: store, webModeActions: actions);
    },
  );

  Future<void> holdCurrentTitle(WidgetTester tester) async {
    final title = find.byKey(const Key('current_title_web_hold'));
    final gesture = await tester.startGesture(tester.getCenter(title));
    await tester.pump(const Duration(seconds: 5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPopupSurface), findsNothing);
  }

  setUp(() {
    preference = FakePreference();
    session = FakeSession();
    tripCreations = 0;
    language = 'en';
    onboarded = true;
    lastActions = null;
  });

  iosTestWidgets(
    'preference gate creates no trip store/UI before true cold startup',
    (tester) async {
      preference.readGate = Completer<bool>();
      await tester.pumpWidget(app());
      expect(tripCreations, 0);
      expect(find.byType(TripDeltaApp), findsNothing);
      preference.readGate!.complete(true);
      await tester.pumpAndSettle();
      expect(tripCreations, 0);
      expect(session.opens, 1);
      expect(find.byType(TripDeltaApp), findsNothing);
      expect(find.byKey(const Key('web_only_home')), findsOneWidget);
      expect(find.byType(WebLaunchSplash), findsOneWidget);
      expect(find.byKey(const Key('current_title_web_hold')), findsNothing);
    },
  );

  iosTestWidgets(
    'off/read failure retains original onboarding flow without native Web',
    (tester) async {
      preference.readFails = true;
      onboarded = false;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tripCreations, 1);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(session.opens, 0);
      expect(session.listeners, 0);
      expect(preference.writes, 0);
    },
  );

  iosTestWidgets('H5 manual English overrides a Chinese system at cold start', (
    tester,
  ) async {
    preference.enabled = true;
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
    preference.enabled = true;
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
    'five-second hold saves then switches directly without a popup',
    (tester) async {
      preference.saveGate = Completer<void>();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await holdCurrentTitle(tester);
      expect(find.byType(CupertinoSwitch), findsNothing);
      await tester.pump();
      expect(preference.writes, 1);
      expect(session.opens, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      await holdCurrentTitle(tester);
      expect(preference.writes, 1);
      expect(session.opens, 0);
      preference.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(preference.enabled, isTrue);
      expect(session.opens, 1);
      expect(find.byType(TripDeltaApp), findsNothing);
      expect(find.byKey(const Key('web_home_switch')), findsNothing);
      expect(tripCreations, 1);
      expect(store.loads, 1);
    },
  );

  iosTestWidgets('failed direct enable retains journey UI and allows retry', (
    tester,
  ) async {
    preference.saveFails = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await holdCurrentTitle(tester);
    await tester.pumpAndSettle();
    expect(preference.enabled, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(session.opens, 0);
    preference.saveFails = false;
    await holdCurrentTitle(tester);
    expect(preference.writes, 2);
    expect(preference.enabled, isTrue);
    expect(session.opens, 1);
    expect(find.byType(TripDeltaApp), findsNothing);
  });

  iosTestWidgets(
    'Web root close is terminal until explicit retry, never journey fallback',
    (tester) async {
      preference.enabled = true;
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
    preference.enabled = true;
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
      preference.enabled = true;
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
      preference.enabled = true;
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
      preference.enabled = true;
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

  iosTestWidgets(
    'disposal cancels subscription and ignores pending preference/open',
    (tester) async {
      preference.readGate = Completer<bool>();
      await tester.pumpWidget(app());
      await tester.pumpWidget(const SizedBox());
      preference.readGate!.complete(true);
      await tester.pumpAndSettle();
      expect(session.opens, 0);
      expect(session.disposes, 1);
      expect(tripCreations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  androidTestWidgets(
    'Android never reads preference, calls Web or exposes title gesture',
    (tester) async {
      preference.enabled = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(preference.reads, 0);
      expect(session.opens, 0);
      expect(session.listeners, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('current_title_web_hold')), findsNothing);
    },
  );

  androidTestWidgets(
    'Android HomeScreen rejects a mistakenly injected title callback',
    (tester) async {
      store = MemoryTripStore('en', true);
      var activated = false;
      await tester.pumpWidget(
        TripDeltaApp(
          store: store,
          webModeActions: WebModeActions(
            save: () async {},
            activate: (_) async {
              activated = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('current_title_web_hold')), findsNothing);
      expect(activated, isFalse);
    },
  );

  iosTestWidgets(
    'same saved enable callback never duplicates persistence or Web root',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final actions = lastActions!;
      await actions.save();
      await actions.activate(const Locale('en'));
      await tester.pumpAndSettle();
      await actions.save();
      await actions.activate(const Locale('en'));
      await tester.pumpAndSettle();
      expect(preference.writes, 1);
      expect(session.opens, 1);
      expect(tripCreations, 1);
    },
  );

  iosTestWidgets(
    'late open after disposing root cannot update UI or keep listeners',
    (tester) async {
      preference.enabled = true;
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

  iosTestWidgets('AppBar title never activates Web mode', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Trip Delta'),
    );
    final gesture = await tester.startGesture(tester.getCenter(title));
    await tester.pump(const Duration(seconds: 5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web_home_switch')), findsNothing);
    expect(session.opens, 0);
  });

  iosTestWidgets(
    'Chinese direct activation preserves Web error locale and dark theme',
    (tester) async {
      language = 'zh';
      session.launchLanguage = 'zh-CN';
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      session.openFails = true;
      await holdCurrentTitle(tester);
      await tester.pumpAndSettle();
      expect(find.text('网页首页暂时不可用，请重试。'), findsOneWidget);
      expect(find.byType(TripDeltaApp), findsNothing);
    },
  );
}

class FakePreference implements WebStartupPreference {
  bool enabled = false;
  bool readFails = false;
  bool saveFails = false;
  int reads = 0;
  int writes = 0;
  Completer<bool>? readGate;
  Completer<void>? saveGate;
  @override
  Future<bool> readEnabled() async {
    reads++;
    if (readFails) throw StateError('controlled read failure');
    return readGate == null ? enabled : readGate!.future;
  }

  @override
  Future<void> saveEnabled() async {
    writes++;
    await saveGate?.future;
    if (saveFails) throw StateError('controlled save failure');
    enabled = true;
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
  int loads = 0;
  @override
  Future<AppData> load() async {
    loads++;
    return value;
  }

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
