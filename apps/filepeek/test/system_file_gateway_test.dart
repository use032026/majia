import 'dart:async';
import 'dart:io';

import 'package:filerecheck/src/data/file_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  test('export cleanup only removes entries in its temporary folder', () async {
    final root = await Directory.systemTemp.createTemp('fylto-exports-');
    addTearDown(() => root.delete(recursive: true));
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getTemporaryDirectory');
      return root.path;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final gateway = SystemFileGateway();
    await gateway.clearOldExports();
    final exports = Directory('${root.path}/filerecheck_exports');
    final shared = await exports.createTemp('share_');
    await File('${shared.path}/result.log').writeAsString('old export');
    await File('${exports.path}/legacy.txt').writeAsString('old export');
    final unrelated = await File(
      '${root.path}/untouched.txt',
    ).writeAsString('keep');

    await gateway.clearOldExports();

    expect(await exports.list().toList(), isEmpty);
    expect(await unrelated.readAsString(), 'keep');
  });

  for (final cleanupFails in [false, true]) {
    test(
      cleanupFails
          ? 'a pending cleanup failure does not prevent sharing'
          : 'sharing waits for pending cleanup and preserves the new export',
      () async {
        final root = await Directory.systemTemp.createTemp('fylto-share-');
        addTearDown(() => root.delete(recursive: true));
        final exports = await Directory(
          '${root.path}/filerecheck_exports',
        ).create();
        final old = await File('${exports.path}/old.log').writeAsString('old');
        final cleanupDirectory = Completer<String>();
        final cleanupStarted = Completer<void>();
        final messenger = binding.defaultBinaryMessenger;
        final sharedPaths = <String>[];
        var directoryCalls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getTemporaryDirectory');
          if (++directoryCalls == 1) {
            cleanupStarted.complete();
            return cleanupDirectory.future;
          }
          return root.path;
        });
        messenger.setMockMethodCallHandler(shareChannel, (call) async {
          expect(call.method, 'share');
          sharedPaths.addAll(call.arguments['paths'].cast<String>());
          return 'com.example.receiver';
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(channel, null);
          messenger.setMockMethodCallHandler(shareChannel, null);
        });

        final gateway = SystemFileGateway();
        final cleanup = gateway.clearOldExports();
        final cleanupChecked = cleanupFails
            ? expectLater(cleanup, throwsA(isA<PlatformException>()))
            : cleanup;
        await cleanupStarted.future;
        final share = gateway.shareFile(
          'new.log',
          Uint8List.fromList([1, 2, 3]),
          const Rect.fromLTWH(0, 0, 10, 10),
        );
        await Future<void>.delayed(Duration.zero);
        expect(directoryCalls, 1);
        expect(sharedPaths, isEmpty);

        if (cleanupFails) {
          cleanupDirectory.completeError(
            PlatformException(code: 'unavailable'),
          );
        } else {
          cleanupDirectory.complete(root.path);
        }
        await cleanupChecked;
        await share;

        expect(directoryCalls, 2);
        expect(await old.exists(), cleanupFails);
        expect(sharedPaths, hasLength(1));
        expect(await File(sharedPaths.single).readAsBytes(), [1, 2, 3]);
      },
    );
  }
}
