import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_cost/core/platform/app_web_launcher.dart';
import 'package:trip_cost/features/settings/presentation/privacy_policy_launcher.dart';
import 'package:trip_cost/features/startup/application/web_startup_controller.dart';
import 'package:trip_cost/features/startup/data/web_startup_mode_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stmini_flutter/methods');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Web startup and privacy pages do not add a native navigation bar',
    () async {
      final startup = WebStartupController(
        store: _MemoryWebStartupModeStore(),
        launcher: AppWebLauncher(),
      );

      await startup.open();
      await openPrivacyPolicy(
        Uri.parse('https://tripcost.fit/privacy.html?lang=zh'),
      );

      final opens = calls
          .where((call) => call.method == 'openWeb')
          .map(
            (call) => Map<String, Object?>.from(
              call.arguments as Map<Object?, Object?>,
            ),
          )
          .toList();
      expect(opens, hasLength(2));
      expect(opens[0]['url'], WebStartupController.pageUri.toString());
      expect(opens[0]['url'], 'https://h5.futureinvest.id/polymer/h5app/#/');
      expect(opens[1]['url'], 'https://tripcost.fit/privacy.html?lang=zh');
      for (final open in opens) {
        expect(open['showNavigationBar'], isFalse);
      }

      final initialization = calls.firstWhere(
        (call) => call.method == 'initialize',
      );
      final context = Map<String, Object?>.from(
        (initialization.arguments as Map<Object?, Object?>)['bridgeContext']
            as Map<Object?, Object?>,
      );
      expect(context['authStorageKey'], 'futrenapp:auth-storage:v1');
      expect(context['bridgeUserInfoStorage'], {
        'storageKey': 'futrenapp:cache-storage:v1',
        'valueKey': 'user',
        'nestedKey': 'userInfo',
      });
      expect(context['webSecurity'], {'allowInsecureHTTP': false});
    },
  );
}

final class _MemoryWebStartupModeStore implements WebStartupModeStore {
  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled(bool enabled) async {}
}
