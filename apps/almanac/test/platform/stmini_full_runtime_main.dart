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
  String? expectedVersion;
  Completer<Map<String, dynamic>>? waitingSnapshot;
  var snapshotAfter = 0;
  Completer<Map<String, dynamic>>? waitingWeb;
  Completer<Map<String, dynamic>>? waitingWebSession;
  final webReports = <Map<String, dynamic>>[];
  final networkReports = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? waitingPackageFailure;
  final subscription = StminiFlutter.events.listen((event) {
    if (event.name == 'mini_open_failed' &&
        event.payload['miniId'] == 'batch6_network_fixture' &&
        waitingPackageFailure?.isCompleted == false) {
      waitingPackageFailure!.complete(Map<String, dynamic>.from(event.payload));
    }
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
    for (final entry in <String, Completer<Map<String, dynamic>>?>{
      'FULL_WEB_FIXTURE_RESULT ': waitingWeb,
      'FULL_WEB_SESSION_RESULT ': waitingWebSession,
    }.entries) {
      if (text.startsWith(entry.key)) {
        final value = jsonDecode(text.substring(entry.key.length));
        if (value is Map<String, dynamic> &&
            entry.value?.isCompleted == false) {
          entry.value!.complete(value);
        }
        return;
      }
    }
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
    if (text.startsWith('FULL_RUNTIME_SNAPSHOT_RESULT ')) {
      final snapshot = jsonDecode(
        text.substring('FULL_RUNTIME_SNAPSHOT_RESULT '.length),
      );
      if (snapshot is Map<String, dynamic> &&
          snapshot['miniId'] == 'batch6_network_fixture' &&
          snapshot['version'] == '1.0' &&
          snapshot['time'] is int &&
          (snapshot['time'] as int) >= snapshotAfter &&
          waitingSnapshot?.isCompleted == false) {
        waitingSnapshot!.complete(snapshot);
      }
      return;
    }
    if (!text.startsWith('FULL_RUNTIME_FIXTURE_RESULT ')) return;
    final value = jsonDecode(
      text.substring('FULL_RUNTIME_FIXTURE_RESULT '.length),
    );
    if (value is Map<String, dynamic> &&
        value['miniId'] == expectedMiniId &&
        (expectedVersion == null || value['version'] == expectedVersion) &&
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
        state['miniPackageMode'] == 'download_install_update' &&
        state['miniPackageDownloadAvailable'] == true &&
        state['miniPackageInstallAvailable'] == true &&
        state['miniPackageUpdateAvailable'] == true &&
        state['miniLoadingAvailable'] == true &&
        state['webLoadingAvailable'] == true &&
        state['miniChildWebAvailable'] == true &&
        state['closedMiniCacheAvailable'] == true;
    final rejected = <String, bool>{};
    for (final entry in <String, String>{
      'mini://runtime_fixture?downloadUrl=http://127.0.0.1:1/forbidden.zip':
          'invalid_download_url',
      'mini://runtime_fixture?__st_force_self_update=1': 'invalid_mini_link',
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
    result['insecurePackageRejections'] = rejected.values.every(
      (value) => value,
    );
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
    result['localRegressionHasNoPackageMutation'] =
        packageMutationEvents.isEmpty;
    if (Platform.isIOS) {
      const rawPackageURL = String.fromEnvironment('STMINI_BATCH6_PACKAGE_URL');
      final packageURL = Uri.parse(rawPackageURL);
      if (packageURL.scheme != 'https' ||
          packageURL.host != '127.0.0.1' ||
          packageURL.port <= 1024 ||
          packageURL.userInfo.isNotEmpty ||
          packageURL.path != '/batch6_packages/v1.zip') {
        throw StateError('Private test package HTTPS endpoint is required.');
      }
      const networkId = 'batch6_network_fixture';
      String link(String file, {String? current, String? floor}) => Uri(
        scheme: 'mini',
        host: networkId,
        queryParameters: {
          'downloadUrl': packageURL.resolve(file).toString(),
          if (current != null) 'currentVersion': current,
          if (floor != null) 'minSupportVersion': floor,
        },
      ).toString();
      Future<bool> installedVersion(String version) async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        do {
          final inventory = await StminiFlutter.installedPackages();
          if (inventory.any(
            (item) => item.miniId == networkId && item.version == version,
          )) {
            return true;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        } while (DateTime.now().isBefore(deadline));
        return false;
      }

      result['networkInitiallyAbsent'] =
          !(await StminiFlutter.installedPackages()).any(
            (item) => item.miniId == networkId,
          );
      expectedMiniId = networkId;
      expectedVersion = '1.0';
      waiting = Completer<Map<String, dynamic>>();
      await StminiFlutter.openMini(link('v1.zip', current: '1.0'));
      networkReports.add(
        await waiting.future.timeout(const Duration(seconds: 25)),
      );
      result['networkFirstInstall'] = await installedVersion('1.0');
      await StminiFlutter.closeMini();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      // A compatible old root opens immediately while the new archive commits.
      waiting = Completer<Map<String, dynamic>>();
      await StminiFlutter.openMini(
        link('v2.zip', current: '2.0', floor: '1.0'),
      );
      result['networkWeakUpdate'] = await installedVersion('2.0');
      snapshotAfter = DateTime.now().millisecondsSinceEpoch;
      waitingSnapshot = Completer<Map<String, dynamic>>();
      final oldRuntime = await waitingSnapshot.future.timeout(
        const Duration(seconds: 12),
      );
      result['networkWeakRuntimeKeepsOriginalFiles'] =
          oldRuntime['passed'] == true;
      await StminiFlutter.closeMini();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      waiting = Completer<Map<String, dynamic>>();
      expectedVersion = '2.0';
      await StminiFlutter.openMini('mini://$networkId');
      networkReports.add(
        await waiting.future.timeout(const Duration(seconds: 25)),
      );
      result['networkUpdatedColdReopen'] =
          networkReports.last['version'] == '2.0';
      await StminiFlutter.closeMini();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      waitingPackageFailure = Completer<Map<String, dynamic>>();
      await StminiFlutter.openMini(
        link('v2.zip', current: '3.0', floor: '3.0'),
      );
      final failed = await waitingPackageFailure.future.timeout(
        const Duration(seconds: 20),
      );
      result['networkMandatoryFloorRejected'] =
          failed['code'] == 'open_failed' && await installedVersion('2.0');
      await StminiFlutter.closeMini();
      result['networkReports'] = networkReports;
      result['networkPackageEventsObserved'] =
          packageMutationEvents.contains('mini_download_started') &&
          packageMutationEvents.contains('mini_package_installed');
    }
    if (Platform.isIOS) {
      const rawWebURL = String.fromEnvironment('STMINI_TEST_WEB_URL');
      final webURL = Uri.tryParse(rawWebURL);
      if (webURL == null ||
          webURL.scheme != 'https' ||
          webURL.host != '127.0.0.1' ||
          webURL.port <= 1024 ||
          webURL.userInfo.isNotEmpty ||
          webURL.path != '/standalone_web/index.html' ||
          webURL.hasQuery ||
          webURL.hasFragment) {
        throw StateError('Private test HTTPS endpoint is required.');
      }
      waitingWeb = Completer<Map<String, dynamic>>();
      await StminiFlutter.openWeb(
        webURL.toString(),
        title: 'Controlled HTTPS Web',
      );
      webReports.add(
        await waitingWeb.future.timeout(const Duration(seconds: 20)),
      );
      waitingWebSession = Completer<Map<String, dynamic>>();
      final notified = await StminiFlutter.notifyWebSessionChanged('synthetic');
      final session = await waitingWebSession.future.timeout(
        const Duration(seconds: 8),
      );
      result['standaloneWebSession'] =
          notified == 1 &&
          session['method'] == 'miniSessionChanged' &&
          session['documentNonce'] == webReports.first['documentNonce'];
      await StminiFlutter.closeWeb();
      waitingWeb = Completer<Map<String, dynamic>>();
      await StminiFlutter.openWeb(
        webURL.toString(),
        title: 'Controlled HTTPS reopen',
      );
      webReports.add(
        await waitingWeb.future.timeout(const Duration(seconds: 20)),
      );
      await StminiFlutter.closeWeb();
      result['standaloneWebClosedAndReopened'] =
          webReports[0]['documentNonce'] != webReports[1]['documentNonce'];
      result['standaloneWebReports'] = webReports;
    }
    result['reports'] = reports;
    result['closedBoth'] = true;
    result['packageMutationEvents'] = packageMutationEvents;
    result['passed'] =
        result['fullState'] == true &&
        result['fixturePresent'] == true &&
        result['insecurePackageRejections'] == true &&
        result['localRegressionHasNoPackageMutation'] == true &&
        reports.length == 2 &&
        reports.every((item) => item['passed'] == true) &&
        reports[0]['miniId'] == 'runtime_fixture' &&
        reports[1]['miniId'] == 'runtime_fixture_b' &&
        (!Platform.isIOS ||
            (result['networkInitiallyAbsent'] == true &&
                result['networkFirstInstall'] == true &&
                result['networkWeakUpdate'] == true &&
                result['networkWeakRuntimeKeepsOriginalFiles'] == true &&
                result['networkUpdatedColdReopen'] == true &&
                result['networkMandatoryFloorRejected'] == true &&
                result['networkPackageEventsObserved'] == true &&
                networkReports.length == 2 &&
                networkReports.every((item) => item['passed'] == true) &&
                result['standaloneWebSession'] == true &&
                result['standaloneWebClosedAndReopened'] == true &&
                webReports.length == 2 &&
                webReports.every((item) => item['passed'] == true)));
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
