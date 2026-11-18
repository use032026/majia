// Exact pinned Dart method/model excerpts from b4462f63a33acf6c3fff63f0e67b3713bc00dff8.
// A channel/fragment harness only; this does not execute the full native runtime.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart' as current;

class _PinnedStminiFlutter {
  static const MethodChannel _methods = MethodChannel('stmini_flutter/methods');

  /// Returns only fully verified and runnable local Mini packages.
  static Future<List<StminiPackage>> installedPackages() async {
    final packages =
        await _methods.invokeListMethod<Map>('installedPackages') ?? const [];
    return packages
        .map((value) => StminiPackage.fromMap(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }
}

class StminiPackage {
  const StminiPackage({
    required this.miniId,
    required this.miniName,
    required this.iconUrl,
    required this.launchLink,
    this.version = '',
  });

  factory StminiPackage.fromMap(Map<String, dynamic> value) => StminiPackage(
    miniId: value['miniId'] as String? ?? '',
    miniName: value['miniName'] as String? ?? '',
    iconUrl: value['iconUrl'] as String? ?? '',
    launchLink: value['launchLink'] as String? ?? '',
    version: value['version'] as String? ?? '',
  );

  final String miniId;
  final String miniName;
  final String iconUrl;
  final String launchLink;

  /// Verified package version supplied by the native package manifest.
  final String version;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stmini_flutter/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'pinned Dart fails against pinned iOS Map envelope while Android List decodes version',
    () async {
      const legacyItem = {
        'miniId': 'alpha',
        'miniName': 'Alpha',
        'iconUrl': '',
        'launchLink': '',
      };
      // iOS plugin lines 991-1000 wraps packages and omits version.
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'packages': [legacyItem],
        },
      );
      await expectLater(
        _PinnedStminiFlutter.installedPackages(),
        throwsA(isA<TypeError>()),
      );
      // Android plugin lines 90-93 returns a top-level List with version.
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {...legacyItem, 'version': '1.2'},
        ],
      );
      expect(
        (await _PinnedStminiFlutter.installedPackages()).single.version,
        '1.2',
      );
    },
  );

  test(
    'pinned model silently accepts missing version and null inventory unlike new strict wire',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {'miniId': 'alpha'},
        ],
      );
      expect(
        (await _PinnedStminiFlutter.installedPackages()).single.version,
        '',
      );
      await expectLater(
        current.StminiFlutter.installedPackages(),
        throwsFormatException,
      );
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await _PinnedStminiFlutter.installedPackages(), isEmpty);
      await expectLater(
        current.StminiFlutter.installedPackages(),
        throwsFormatException,
      );
    },
  );

  test(
    'new derived List wire includes validated version and rejects old iOS envelope',
    () async {
      const item = {
        'miniId': 'alpha',
        'miniName': 'Alpha',
        'version': '1.2',
        'entry': 'index.html',
        'icon': '',
      };
      messenger.setMockMethodCallHandler(channel, (_) async => [item]);
      expect(
        (await current.StminiFlutter.installedPackages()).single.version,
        '1.2',
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'packages': [item],
        },
      );
      await expectLater(
        current.StminiFlutter.installedPackages(),
        throwsFormatException,
      );
    },
  );
}
