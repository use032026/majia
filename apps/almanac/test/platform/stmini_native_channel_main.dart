// Test-only Flutter build target. Never imported by the production entry point.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:almanac/src/stmini_startup.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final startup = StminiStartup();
  runApp(StminiStartupHost(startup: startup, child: const SizedBox.shrink()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_verify(startup));
  });
}

Future<void> _verify(StminiStartup startup) async {
  final result = <String, Object?>{
    'kind': 'real_flutter_native_local_inventory',
    'runtimeStage': StminiFlutter.runtimeStage,
  };
  try {
    await startup.initializeOnce().timeout(const Duration(seconds: 10));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (startup.diagnostics['eventCount'] == 0 &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    final native = await StminiFlutter.foundationState.timeout(
      const Duration(seconds: 10),
    );
    final packages = await StminiFlutter.installedPackages().timeout(
      const Duration(seconds: 10),
    );
    const methods = MethodChannel('stmini_flutter/methods');
    var unsupportedRejected = true;
    for (final entry in const {
      'openMini': 'invalid_mini_link',
      'openWeb': 'invalid_web_url',
      'notifyWebSessionChanged': 'invalid_reason',
    }.entries) {
      try {
        await methods
            .invokeMethod<Object?>(entry.key)
            .timeout(const Duration(seconds: 5));
        unsupportedRejected = false;
      } on PlatformException catch (error) {
        if (error.code != entry.value) unsupportedRejected = false;
      } catch (_) {
        unsupportedRejected = false;
      }
    }
    result['inventoryCount'] = packages.length;
    result['unsupportedRejected'] = unsupportedRejected;
    result['nativeState'] = native;
    result['startupDiagnostics'] = startup.diagnostics;
    final eventState = startup.diagnostics['foundationState'] as Map?;
    result['passed'] =
        native['initialized'] == true &&
        native['stage'] == 'mini' &&
        native['runtimeMode'] == 'mini' &&
        native['packageName'] == 'com.almanac.lite' &&
        native['miniLoadingAvailable'] == true &&
        native['webLoadingAvailable'] == true &&
        eventState?['initialized'] == true &&
        eventState?['packageName'] == native['packageName'] &&
        (native['capabilities'] as List?)?.contains('local_inventory') ==
            true &&
        packages.isEmpty &&
        startup.diagnostics['inventoryStatus'] == 'available' &&
        startup.diagnostics['installedPackageCount'] == 0 &&
        startup.diagnostics['lastIssue'] == null &&
        unsupportedRejected;
  } catch (_) {
    result['passed'] = false;
    result['issue'] = 'native_channel_verification_failed';
  } finally {
    try {
      await startup.dispose().timeout(const Duration(seconds: 5));
    } catch (_) {
      result['passed'] = false;
      result['disposeIssue'] = 'native_channel_disposal_failed';
    }
    result['disposedDiagnostics'] = <String, Object?>{
      'disposed': startup.diagnostics['disposed'],
      'eventCount': startup.diagnostics['eventCount'],
      'lastIssue': startup.diagnostics['lastIssue'],
    };
  }
  // Structured local test output only; no URLs, account values or persistence.
  // ignore: avoid_print
  print('STMINI_NATIVE_CHANNEL_RESULT ${jsonEncode(result)}');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  exit(result['passed'] == true ? 0 : 1);
}
