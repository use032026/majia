// Test-only target. Fixtures are installed externally into this task App's
// sandbox; neither this target nor fixture pages are imported by lib/main.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final paint = _FixturePaintDiagnostics();
  SchedulerBinding.instance.addTimingsCallback(paint.onTimings);
  runApp(
    _FixtureHost(
      paint: paint,
      child: const ColoredBox(color: Color(0xFFF59E0B)),
    ),
  );
  unawaited(_verify(paint));
}

// Test-only Flutter paint controls distinguish a missing Flutter scene from a
// missing native child. Raster timing and layout are diagnostics, not proof
// that a screenshot displayed either the header or the local HTML content.
final class _FixturePaintDiagnostics {
  final host = GlobalKey();
  final header = GlobalKey();
  final localView = GlobalKey();
  int frameCount = 0;
  Map<String, Object?>? firstRasterTiming;
  final layouts = <String, Map<String, Object?>>{};

  void onTimings(List<FrameTiming> timings) {
    frameCount += timings.length;
    if (firstRasterTiming == null && timings.isNotEmpty) {
      final timing = timings.first;
      firstRasterTiming = {
        'buildMicros': timing.buildDuration.inMicroseconds,
        'rasterMicros': timing.rasterDuration.inMicroseconds,
        'rasterStartMicros': timing.timestampInMicroseconds(
          FramePhase.rasterStart,
        ),
        'rasterFinishMicros': timing.timestampInMicroseconds(
          FramePhase.rasterFinish,
        ),
      };
      // ignore: avoid_print
      print('STMINI_LOCAL_RENDERER_RASTER ${jsonEncode(snapshot())}');
    }
  }

  Map<String, Object?> snapshot() => {
    'scope': 'flutter_raster_callback_and_layout_not_screen_visibility',
    'timingFrameCount': frameCount,
    'firstRasterTiming': firstRasterTiming,
    'layouts': Map<String, Map<String, Object?>>.of(layouts),
  };

  Future<void> sampleLayout(String stage) async {
    final completed = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final sizes = <String, Object?>{};
      for (final entry in {
        'host': host,
        'header': header,
        'localView': localView,
      }.entries) {
        final box = entry.value.currentContext?.findRenderObject();
        sizes[entry.key] = box is RenderBox && box.hasSize
            ? {'width': box.size.width, 'height': box.size.height}
            : null;
      }
      layouts[stage] = sizes;
      // ignore: avoid_print
      print(
        'STMINI_LOCAL_RENDERER_LAYOUT ${jsonEncode({'stage': stage, 'sizes': sizes})}',
      );
      completed.complete();
    });
    SchedulerBinding.instance.scheduleFrame();
    await completed.future.timeout(const Duration(seconds: 5));
  }
}

class _FixtureHost extends StatelessWidget {
  const _FixtureHost({required this.paint, required this.child});
  final _FixturePaintDiagnostics paint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      key: paint.host,
      color: const Color(0xFF0EA5A4),
      child: Column(
        children: [
          SizedBox(
            key: paint.header,
            height: 72,
            width: double.infinity,
            child: const ColoredBox(
              color: Color(0xFF243B80),
              child: Center(
                child: Text(
                  'Engine fixture host',
                  style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 22),
                ),
              ),
            ),
          ),
          Expanded(
            child: SizedBox(key: paint.localView, child: child),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _reloadAndAwaitCurrentCommit(
  StminiLocalController controller,
) async {
  final completed = Completer<bool>();
  var loading = false;
  void changed() {
    final state = controller.state;
    if (state?.phase == StminiLocalPhase.loading) {
      loading = true;
    }
    if (!completed.isCompleted && state?.phase == StminiLocalPhase.failed) {
      completed.complete(false);
    }
    if (!completed.isCompleted &&
        loading &&
        state?.phase == StminiLocalPhase.ready) {
      completed.complete(true);
    }
  }

  controller.addListener(changed);
  try {
    await controller.reload().timeout(const Duration(seconds: 5));
    return await completed.future.timeout(const Duration(seconds: 12));
  } finally {
    controller.removeListener(changed);
  }
}

Future<void> _awaitReadyHistory(StminiLocalController controller) async {
  // The runner changes only installed Engine probe.js auto-navigation to
  // 20 seconds. Native fixtures remain unchanged; allow that first timer here.
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final state = controller.state;
    if (state?.phase == StminiLocalPhase.failed ||
        controller.hasProtocolError) {
      throw StateError('History fixture failed.');
    }
    if (state?.phase == StminiLocalPhase.ready && state?.canGoBack == true) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  throw StateError('History fixture did not navigate.');
}

Future<bool> _goBackAndAwaitCurrentCommit(
  StminiLocalController controller,
) async {
  final completed = Completer<bool>();
  var loading = false;
  void changed() {
    final state = controller.state;
    if (state?.phase == StminiLocalPhase.loading) {
      loading = true;
    }
    if (!completed.isCompleted && state?.phase == StminiLocalPhase.failed) {
      completed.complete(false);
    }
    if (!completed.isCompleted &&
        loading &&
        state?.phase == StminiLocalPhase.ready) {
      completed.complete(true);
    }
  }

  controller.addListener(changed);
  try {
    if (!await controller.goBack().timeout(const Duration(seconds: 5))) {
      return false;
    }
    return await completed.future.timeout(const Duration(seconds: 12));
  } finally {
    controller.removeListener(changed);
  }
}

Future<void> _verify(_FixturePaintDiagnostics paint) async {
  final result = <String, Object?>{
    'kind': 'real_flutter_native_local_renderer',
  };
  final controller = StminiLocalController();
  final ready = Completer<void>();
  final phases = <String>[];
  try {
    await StminiFlutter.initialize(
      bridgeContext: {'packageName': 'com.almanac.lite'},
    );
    final native = await StminiFlutter.foundationState;
    if (native['localRendererAvailable'] != true ||
        native['miniLoadingAvailable'] != Platform.isIOS ||
        native['webLoadingAvailable'] != false ||
        native['capabilities'] is! List ||
        !(native['capabilities'] as List).contains('local_renderer')) {
      throw StateError('Local renderer capability unavailable.');
    }
    // Deterministic test-only identity, never a production link or root override.
    final packages = await StminiFlutter.installedPackages();
    final fixture = packages.singleWhere(
      (package) => package.miniId == 'renderer_fixture',
    );
    runApp(
      _FixtureHost(
        paint: paint,
        child: StminiLocalView(
          miniId: fixture.miniId,
          version: fixture.version,
          controller: controller,
          onStateChanged: (state) {
            phases.add(state.phase.name);
            if (state.phase == StminiLocalPhase.ready && !ready.isCompleted) {
              ready.complete();
            }
            if (state.phase == StminiLocalPhase.failed && !ready.isCompleted) {
              ready.completeError(StateError('Local renderer failed.'));
            }
          },
        ),
      ),
    );
    await ready.future.timeout(const Duration(seconds: 15));
    await paint.sampleLayout('initial_ready');
    result['ready'] = true;
    // Ready proves the current native main-document commit, not DOM completion.
    // Separate native tests inspect DOM/CSS/image/interaction and network attempts.
    // ignore: avoid_print
    print(
      'STMINI_LOCAL_RENDERER_READY ${jsonEncode({'kind': result['kind'], 'phase': 'ready'})}',
    );
    final current = await controller.getState();
    result['commitStillReady'] = current.phase == StminiLocalPhase.ready;
    result['rootGoBackFalse'] = !await controller.goBack();
    // The Engine-only installed fixture enables its own delayed click to a
    // same-package second.html. Native fixture tests keep that flag disabled.
    // No renderer control API executes JavaScript or chooses an arbitrary URL.
    await _awaitReadyHistory(controller);
    result['localHistoryReady'] = true;
    result['goBackLoadingThenReady'] = await _goBackAndAwaitCurrentCommit(
      controller,
    );
    result['rootAfterBack'] = !await controller.goBack();
    final reloads = <bool>[];
    for (var round = 0; round < 2; round += 1) {
      reloads.add(await _reloadAndAwaitCurrentCommit(controller));
      if (await controller.goBack()) {
        throw StateError('Reload introduced root history.');
      }
    }
    result['reloadLoadingThenReady'] = reloads;
    // The runner changes only its installed Engine fixture auto timer from
    // 5 to 20 seconds. This final 15-second observation window ends before the
    // next automatic navigation; retain rootStillReady as a real assertion.
    await paint.sampleLayout('reloaded');
    // ignore: avoid_print
    print(
      'STMINI_LOCAL_RENDERER_RELOADED ${jsonEncode({'phase': controller.state?.phase.name, 'reloads': reloads})}',
    );
    await Future<void>.delayed(const Duration(seconds: 15));
    result['flutterPaintDiagnostics'] = {
      'timingFrameCount': paint.frameCount,
      'firstRasterTiming': paint.firstRasterTiming,
    };
    result['rootStillReady'] =
        controller.state?.phase == StminiLocalPhase.ready &&
        controller.state?.canGoBack == false;
    final firstClose = controller.close();
    final secondClose = controller.close();
    result['repeatedCloseSharesFuture'] = identical(firstClose, secondClose);
    await firstClose.timeout(const Duration(seconds: 5));
    await secondClose;
    result['closed'] = controller.state?.phase == StminiLocalPhase.closed;
    result['passed'] =
        result['ready'] == true &&
        result['commitStillReady'] == true &&
        result['rootGoBackFalse'] == true &&
        result['localHistoryReady'] == true &&
        result['goBackLoadingThenReady'] == true &&
        result['rootAfterBack'] == true &&
        result['rootStillReady'] == true &&
        reloads.length == 2 &&
        reloads.every((value) => value) &&
        result['repeatedCloseSharesFuture'] == true &&
        result['closed'] == true &&
        !controller.hasProtocolError;
  } catch (_) {
    result['passed'] = false;
    result['issue'] = 'local_renderer_verification_failed';
  } finally {
    runApp(const SizedBox.shrink());
    controller.dispose();
    SchedulerBinding.instance.removeTimingsCallback(paint.onTimings);
    result['flutterPaintDiagnostics'] = {
      'timingFrameCount': paint.frameCount,
      'firstRasterTiming': paint.firstRasterTiming,
    };
    result['phases'] = phases;
  }
  // ignore: avoid_print
  print('STMINI_LOCAL_RENDERER_RESULT ${jsonEncode(result)}');
  await Future<void>.delayed(const Duration(milliseconds: 150));
  exit(result['passed'] == true ? 0 : 1);
}
