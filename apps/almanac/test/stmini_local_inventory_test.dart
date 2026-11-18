import 'dart:async';

import 'package:almanac/src/stmini_startup.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

Map<String, Object?> _record({String id = 'alpha', String version = '1.0'}) => {
  'miniId': id,
  'miniName': 'Local package',
  'version': version,
  'entry': 'pages/index.html',
  'icon': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stmini_flutter/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'real SDK method wire reads immutable empty and nonempty metadata',
    () async {
      final calls = <MethodCall>[];
      Object? response = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return response;
      });
      final empty = await StminiFlutter.installedPackages();
      expect(empty, isEmpty);
      expect(
        () => empty.add(StminiPackage.fromMap(_record())),
        throwsUnsupportedError,
      );
      response = [_record()];
      final packages = await StminiFlutter.installedPackages();
      expect(packages.single.miniId, 'alpha');
      expect(packages.single.version, '1.0');
      expect(packages.single.entry, 'pages/index.html');
      expect(packages.single.icon, isEmpty);
      expect(() => packages.clear(), throwsUnsupportedError);
      expect(
        calls.every(
          (call) =>
              call.method == 'installedPackages' && call.arguments == null,
        ),
        isTrue,
      );
    },
  );

  test(
    'real SDK wire rejects missing old iOS envelope and malformed items',
    () async {
      final invalid = <Object?>[
        null,
        {'packages': <Object?>[]},
        '[]',
        [null],
        [7],
        [
          {'miniId': 'alpha'},
        ],
        [
          {..._record(), 'version': 1},
        ],
        [
          {..._record(), 'launchLink': 'mini://alpha'},
        ],
        [_record(), _record()],
        List.generate(257, (index) => _record(id: 'p$index')),
      ];
      for (final response in invalid) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        await expectLater(
          StminiFlutter.installedPackages(),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'native inventory failures remain failures rather than legal zero',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'inventory_unavailable',
          message: 'Unavailable',
        );
      });
      await expectLater(
        StminiFlutter.installedPackages(),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test('strict metadata enforces identity version path and UTF16 bounds', () {
    for (final id in ['', 'Alpha', '../alpha', '_alpha', 'alpha\n', 'a' * 65]) {
      expect(
        () => StminiPackage.fromMap({..._record(), 'miniId': id}),
        throwsFormatException,
      );
    }
    for (final version in [
      '',
      '1.',
      '.1',
      '1..2',
      '-1',
      '1e2',
      '1-beta',
      '1_2',
      '1\n',
      '1234567890',
      List.filled(9, '1').join('.'),
    ]) {
      expect(
        () => StminiPackage.fromMap({..._record(), 'version': version}),
        throwsFormatException,
      );
    }
    for (final path in [
      '',
      '/index.html',
      'a//b',
      'a/',
      '.',
      '..',
      'a/../b',
      r'a\b',
      'https:x',
      'a?b',
      'a#b',
      'a%b',
      'a\u0000b',
      'a\u001fb',
      'a\u007fb',
      'a\u0085b',
      'a' * 129,
      List.filled(17, 'a').join('/'),
      List.filled(8, 'a' * 128).join('/'),
    ]) {
      expect(
        () => StminiPackage.fromMap({..._record(), 'entry': path}),
        throwsFormatException,
        reason: 'invalid entry',
      );
      if (path.isNotEmpty) {
        expect(
          () => StminiPackage.fromMap({..._record(), 'icon': path}),
          throwsFormatException,
          reason: 'invalid icon',
        );
      }
    }
    expect(
      () => StminiPackage.fromMap({..._record(), 'miniName': '😀' * 129}),
      throwsFormatException,
    );
    final boundary = StminiPackage.fromMap({
      ..._record(id: 'a' * 64, version: List.filled(8, '123456789').join('.')),
      'miniName': '😀' * 128,
      'entry': List.filled(16, 'a').join('/'),
      'icon': 'images/icon.png',
    });
    expect(boundary.miniName.length, 256);
    expect(boundary.version.length, 79);
    final maximumPath = [...List.filled(7, 'a' * 128), 'a' * 121].join('/');
    expect(maximumPath.length, 1024);
    expect(
      StminiPackage.fromMap({..._record(), 'entry': maximumPath}).entry,
      maximumPath,
    );
    expect(StminiPackage.fromMap(_record(version: '000.01')).version, '000.01');
  });

  StminiStartup startup({
    required StminiInventoryLoader load,
    StminiInitializer? initialize,
  }) {
    final service = StminiStartup(
      initialize: initialize ?? (_) async {},
      events: const Stream<StminiEvent>.empty(),
      loadInstalledPackages: load,
    );
    addTearDown(service.dispose);
    return service;
  }

  test(
    'startup consumes inventory once and stores only status and count',
    () async {
      var reads = 0;
      final service = startup(
        load: () async {
          reads += 1;
          return [StminiPackage.fromMap(_record())];
        },
      );
      final first = service.initializeOnce();
      expect(service.initializeOnce(), same(first));
      await first;
      expect(service.initializeOnce(), same(first));
      expect(reads, 1);
      expect(service.diagnostics['inventoryStatus'], 'available');
      expect(service.diagnostics['installedPackageCount'], 1);
      expect(
        service.diagnostics.values.any((value) => value is List<StminiPackage>),
        isFalse,
      );
      expect(service.diagnostics.toString(), isNot(contains('Local package')));
      expect(
        service.diagnostics.toString(),
        isNot(contains('pages/index.html')),
      );
    },
  );

  test(
    'legal zero inventory differs from failed and initialization never queries after failure',
    () async {
      final empty = startup(load: () async => []);
      await empty.initializeOnce();
      expect(empty.diagnostics['inventoryStatus'], 'available');
      expect(empty.diagnostics['installedPackageCount'], 0);
      var reads = 0;
      final failed = startup(
        load: () async => throw StateError('private detail'),
      );
      await failed.initializeOnce();
      expect(failed.diagnostics['inventoryStatus'], 'failed');
      expect(failed.diagnostics['installedPackageCount'], isNull);
      expect(failed.diagnostics['lastIssue'], 'inventory_failed');
      expect(failed.diagnostics.toString(), isNot(contains('private detail')));
      final initializationFailed = startup(
        initialize: (_) async => throw StateError('native init failure'),
        load: () async {
          reads += 1;
          return [];
        },
      );
      await initializationFailed.initializeOnce();
      expect(reads, 0);
      expect(initializationFailed.diagnostics['inventoryStatus'], 'failed');
      expect(
        initializationFailed.diagnostics['lastIssue'],
        'initialization_failed',
      );
    },
  );

  for (final lateError in [false, true]) {
    testWidgets(
      'inventory timeout is terminal despite late ${lateError ? 'failure' : 'success'}',
      (tester) async {
        final pending = Completer<List<StminiPackage>>();
        var reads = 0;
        final service = startup(
          load: () {
            reads += 1;
            return pending.future;
          },
        );
        final result = service.initializeOnce();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4999));
        expect(service.diagnostics['inventoryStatus'], 'pending');
        expect(service.diagnostics['installedPackageCount'], isNull);
        await tester.pump(const Duration(milliseconds: 1));
        await result;
        final terminal = service.diagnostics;
        expect(terminal['inventoryStatus'], 'failed');
        expect(terminal['installedPackageCount'], isNull);
        if (lateError) {
          pending.completeError(StateError('late private failure'));
        } else {
          pending.complete([StminiPackage.fromMap(_record())]);
        }
        await tester.pump();
        expect(service.diagnostics, terminal);
        expect(service.initializeOnce(), same(result));
        expect(reads, 1);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'disposal ignores pending inventory late ${lateError ? 'failure' : 'success'}',
      () async {
        final pending = Completer<List<StminiPackage>>();
        final started = Completer<void>();
        final service = startup(
          load: () {
            started.complete();
            return pending.future;
          },
        );
        final result = service.initializeOnce();
        await started.future;
        await service.dispose();
        final terminal = service.diagnostics;
        if (lateError) {
          pending.completeError(StateError('late failure'));
        } else {
          pending.complete([StminiPackage.fromMap(_record())]);
        }
        await result;
        expect(service.diagnostics, terminal);
        expect(service.diagnostics['installedPackageCount'], isNull);
      },
    );
  }

  testWidgets(
    'Host remount shares one pending and completed inventory result',
    (tester) async {
      final pending = Completer<List<StminiPackage>>();
      var reads = 0;
      final service = startup(
        load: () {
          reads += 1;
          return pending.future;
        },
      );
      Widget host() =>
          StminiStartupHost(startup: service, child: const SizedBox.shrink());
      await tester.pumpWidget(host());
      await tester.pump();
      expect(reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host());
      await tester.pump();
      expect(reads, 1);
      pending.complete([]);
      await tester.pump();
      expect(service.diagnostics['inventoryStatus'], 'available');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host());
      await tester.pump();
      expect(reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
