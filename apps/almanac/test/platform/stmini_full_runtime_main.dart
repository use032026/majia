// Test-only entry point. The runner installs synthetic packages in its own
// fresh simulator/emulator sandbox. lib/main.dart never imports this target.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

import 'stmini_full_report_writer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF5F8FC),
        child: Center(child: Text('Controlled full runtime test')),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(_probeThenVerify()),
  );
}

Future<void> _probeThenVerify() async {
  const nonce = String.fromEnvironment('STMINI_FULL_RUN_NONCE');
  final privateDirectory = Platform.isIOS
      ? Directory.systemTemp.path
      : const String.fromEnvironment('STMINI_FULL_REPORT_DIR');
  var verificationStarted = false;
  var reportStage = 'prepare';
  try {
    final writer = FullRuntimeReportWriter(privateDirectory, nonce);
    await writer.prepare();
    reportStage = 'probe_write';
    final file = await writer.writeProbe();
    // ignore: avoid_print
    print(
      'STMINI_FULL_REPORT_PROBE ${jsonEncode({'runNonce': nonce, 'file': file})}',
    );
    reportStage = 'reader_ack';
    await writer.waitForReaderAcknowledgement();
    verificationStarted = true;
    reportStage = 'verify';
    await _verify(writer);
  } catch (error) {
    // No initialization/open is attempted until the real reader acknowledges
    // this App process's actual probe. No absolute path is printed.
    // ignore: avoid_print
    print(
      'STMINI_FULL_RUNTIME_RESULT ${jsonEncode({'runNonce': nonce, 'passed': false, 'verificationStarted': verificationStarted, 'reportStage': reportStage, 'reportErrorType': error.runtimeType.toString()})}',
    );
  }
}

Future<void> _verify(FullRuntimeReportWriter writer) async {
  final reports = <Map<String, dynamic>>[];
  final packageMutationEvents = <String>[];
  final lifecycle = <String, Set<String>>{};
  Completer<Map<String, dynamic>>? waiting;
  String? expectedMiniId;
  final subscription = StminiFlutter.events.listen((event) {
    if (const {
      'mini_download_started',
      'mini_download_progress',
      'mini_download_completed',
      'mini_package_installed',
      'installed_packages_changed',
    }.contains(event.name)) {
      packageMutationEvents.add(event.name);
    }
    final text = event.payload['message'];
    if (event.name != 'native_log' || text is! String) return;
    if (text.startsWith('FULL_RUNTIME_LIFECYCLE ')) {
      final value = jsonDecode(
        text.substring('FULL_RUNTIME_LIFECYCLE '.length),
      );
      if (value is Map &&
          value['miniId'] is String &&
          value['method'] is String) {
        lifecycle
            .putIfAbsent(value['miniId'] as String, () => <String>{})
            .add(value['method'] as String);
      }
      return;
    }
    if (!text.startsWith('FULL_RUNTIME_FIXTURE_RESULT ')) return;
    final value = jsonDecode(
      text.substring('FULL_RUNTIME_FIXTURE_RESULT '.length),
    );
    if (value is Map<String, dynamic> &&
        value['miniId'] == expectedMiniId &&
        waiting?.isCompleted == false) {
      waiting!.complete(value);
    }
  });
  final result = <String, Object?>{
    'passed': false,
    'runNonce': writer.runNonce,
    'scope': 'test_only_sdk_to_full_native_container_and_real_CMS_bridge',
  };
  try {
    await StminiFlutter.initialize(
      bridgeContext: const {'packageName': 'com.almanac.lite'},
    );
    final state = await StminiFlutter.foundationState;
    result['fullState'] =
        state['runtimeMode'] == 'mini' &&
        state['miniPackageMode'] == 'local_only' &&
        state['miniPackageDownloadAvailable'] == false &&
        state['miniPackageInstallAvailable'] == false &&
        state['miniPackageUpdateAvailable'] == false &&
        state['miniLoadingAvailable'] == true &&
        state['webLoadingAvailable'] == false &&
        state['miniChildWebAvailable'] == true &&
        state['closedMiniCacheAvailable'] == false;
    final rejected = <String, bool>{};
    for (final entry in <String, String>{
      'mini://runtime_fixture?downloadUrl=https://127.0.0.1:1/forbidden.zip':
          'unsupported',
      'mini://runtime_fixture?__st_force_self_update=1': 'unsupported',
      'mini://missing_fixture': 'mini_package_unavailable',
      'mini://runtime_fixture?minSupportVersion=2.0':
          'mini_package_unavailable',
    }.entries) {
      try {
        await StminiFlutter.openMini(entry.key);
        rejected[entry.key] = false;
      } on PlatformException catch (error) {
        rejected[entry.key] = error.code == entry.value;
      }
    }
    result['localOnlyRejections'] = rejected.values.every((value) => value);
    final packages = await StminiFlutter.installedPackages();
    result['fixturePresent'] = packages.any(
      (item) => item.miniId == 'runtime_fixture',
    );
    for (final mini in ['runtime_fixture', 'runtime_fixture_b']) {
      expectedMiniId = mini;
      waiting = Completer<Map<String, dynamic>>();
      await StminiFlutter.openMini('mini://$mini');
      final report = await waiting.future.timeout(const Duration(seconds: 25));
      reports.add(report);
      // ignore: avoid_print
      print('STMINI_FULL_RUNTIME_REPORT ${jsonEncode(report)}');
      // ignore: avoid_print
      print(
        'STMINI_FULL_RUNTIME_READY ${jsonEncode({'miniId': mini, 'passed': report['passed']})}',
      );
      await Future<void>.delayed(const Duration(seconds: 12));
      await StminiFlutter.closeMini();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    result['reports'] = reports;
    result['closedBoth'] = true;
    result['packageMutationEvents'] = packageMutationEvents;
    result['passed'] =
        result['fullState'] == true &&
        result['fixturePresent'] == true &&
        result['localOnlyRejections'] == true &&
        packageMutationEvents.isEmpty &&
        reports.length == 2 &&
        reports.every((item) => item['passed'] == true) &&
        reports[0]['miniId'] == 'runtime_fixture' &&
        reports[1]['miniId'] == 'runtime_fixture_b';
  } catch (error) {
    result['errorType'] = error.runtimeType.toString();
    result['reports'] = reports;
  } finally {
    await subscription.cancel();
    result['lifecycle'] = lifecycle.map(
      (key, value) => MapEntry(key, value.toList()),
    );
    final summary = <String, Object?>{
      'runNonce': writer.runNonce,
      'passed': false,
      'verificationStarted': true,
    };
    try {
      result['runNonce'] = writer.runNonce;
      final name = await writer.writeResult(result);
      summary['file'] = name;
      summary['passed'] = result['passed'];
      summary['reports'] = reports
          .map(
            (item) => {
              'miniId': item['miniId'],
              'passed': item['passed'],
              'checkCount': (item['checks'] as Map?)?.length,
              'provider': item['providerSemantics'],
            },
          )
          .toList();
      summary['lifecycle'] = result['lifecycle'];
    } catch (error) {
      summary['reportErrorType'] = error.runtimeType.toString();
    }
    // The full result stays in this fresh task sandbox. Console output is
    // intentionally short because the iOS Flutter logger truncates long lines.
    // ignore: avoid_print
    print('STMINI_FULL_RUNTIME_RESULT ${jsonEncode(summary)}');
  }
}
