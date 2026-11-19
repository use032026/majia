import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

typedef StminiInitializer =
    Future<void> Function(Map<String, dynamic> bridgeContext);

typedef StminiInventoryLoader = Future<List<StminiPackage>> Function();

/// Initializes native foundation configuration without changing app data.
class StminiStartup {
  StminiStartup({
    StminiInitializer? initialize,
    Stream<StminiEvent>? events,
    StminiInventoryLoader? loadInstalledPackages,
  }) : _initialize = initialize ?? _initializeNative,
       _events = events ?? StminiFlutter.events,
       _loadInstalledPackages =
           loadInstalledPackages ?? StminiFlutter.installedPackages;

  static final StminiStartup shared = StminiStartup();

  final StminiInitializer _initialize;
  final Stream<StminiEvent> _events;
  final StminiInventoryLoader _loadInstalledPackages;
  Future<void>? _initialization;
  StreamSubscription<StminiEvent>? _subscription;
  Future<void>? _disposal;
  bool _disposed = false;
  bool _initializationFinished = false;
  bool _eventsDone = false;
  int _eventCount = 0;
  String? _lastIssue;
  String _inventoryStatus = 'pending';
  int? _installedPackageCount;
  Map<String, dynamic>? _foundationState;

  /// Process-local diagnostics only; no widget/controller or persistent data.
  Map<String, Object?> get diagnostics => Map<String, Object?>.unmodifiable({
    'initializationFinished': _initializationFinished,
    'eventsDone': _eventsDone,
    'eventCount': _eventCount,
    'lastIssue': _lastIssue,
    'foundationState': _foundationState,
    'inventoryStatus': _inventoryStatus,
    'installedPackageCount': _installedPackageCount,
    'disposed': _disposed,
  });

  /// Keeps either terminal result for this process; startup never retries.
  Future<void> initializeOnce() {
    if (_disposed) return Future<void>.error(StateError('Startup disposed.'));
    if (_initialization != null) return _initialization!;
    final completion = Completer<void>();
    _initialization = completion.future;
    unawaited(_initializeSafely().then((_) => completion.complete()));
    return completion.future;
  }

  Future<void> _initializeSafely() async {
    try {
      _subscription = _events.listen(
        _consume,
        onError: (Object _, StackTrace __) {
          if (!_disposed) _lastIssue = 'event_stream_failed';
        },
        onDone: () {
          if (!_disposed) _eventsDone = true;
        },
      );
    } catch (_) {
      _lastIssue = 'event_subscription_failed';
    }
    try {
      await _initialize(const <String, dynamic>{
        'packageName': 'com.almanac.lite',
      });
      if (!_disposed) await _readInventory();
    } catch (_) {
      if (!_disposed) {
        _lastIssue = 'initialization_failed';
        _inventoryStatus = 'failed';
      }
      // Initialization is optional for the local app. Do not expose native
      // error details or let a failed plugin replace the existing home page.
      if (kDebugMode) debugPrint('[Deynu] STMini initialization failed.');
    } finally {
      if (!_disposed) _initializationFinished = true;
    }
  }

  Future<void> _readInventory() async {
    try {
      final packages = await _loadInstalledPackages().timeout(
        const Duration(seconds: 5),
      );
      if (_disposed) return;
      _installedPackageCount = packages.length;
      _inventoryStatus = 'available';
    } catch (_) {
      if (_disposed) return;
      _inventoryStatus = 'failed';
      _lastIssue = 'inventory_failed';
    }
  }

  void _consume(StminiEvent event) {
    if (_disposed ||
        !const {
          'runtime_initialized',
          'foundation_initialized',
        }.contains(event.name)) {
      return;
    }
    final state = event.payload;
    final mini =
        event.name == 'runtime_initialized' &&
        state['stage'] == 'mini' &&
        state['runtimeMode'] == 'mini' &&
        state['miniPackageMode'] == 'local_only' &&
        state['miniLoadingAvailable'] == true &&
        state['miniChildWebAvailable'] == true;
    final foundation =
        event.name == 'foundation_initialized' &&
        state['stage'] == 'foundation' &&
        state['miniLoadingAvailable'] == false &&
        state['miniChildWebAvailable'] == false;
    if ((!mini && !foundation) ||
        state['miniPackageDownloadAvailable'] != false ||
        state['miniPackageInstallAvailable'] != false ||
        state['miniPackageUpdateAvailable'] != false ||
        state['closedMiniCacheAvailable'] != false ||
        state['localRendererAvailable'] != true ||
        state['initialized'] != true ||
        state['packageName'] != 'com.almanac.lite' ||
        state['webLoadingAvailable'] != false) {
      _lastIssue = 'invalid_foundation_event';
      return;
    }
    // Keep only foundation fields, never arbitrary future event/bridge data.
    final capabilities = state['capabilities'];
    _foundationState = Map<String, dynamic>.unmodifiable({
      'stage': mini ? 'mini' : 'foundation',
      if (mini) 'runtimeMode': 'mini',
      if (mini) 'miniPackageMode': 'local_only',
      'miniPackageDownloadAvailable': false,
      'miniPackageInstallAvailable': false,
      'miniPackageUpdateAvailable': false,
      'initialized': true,
      'packageName': 'com.almanac.lite',
      'miniLoadingAvailable': mini,
      'webLoadingAvailable': false,
      'miniChildWebAvailable': mini,
      'closedMiniCacheAvailable': false,
      'localRendererAvailable': true,
      if (state['language'] is String) 'language': state['language'],
      if (state['localizedClose'] is String)
        'localizedClose': state['localizedClose'],
      if (capabilities is List)
        'capabilities': List<String>.unmodifiable(
          capabilities.whereType<String>().where(
            {
              'host_configuration',
              'language_resolution',
              'runtime_events',
              'local_inventory',
              'local_renderer',
              if (mini) 'local_mini_runtime',
              if (mini) 'framework_bridge',
              if (mini) 'isolated_storage',
            }.contains,
          ),
        ),
    });
    _eventCount += 1;
  }

  /// Nonshared services are owned by their creator. Host unmount does not
  /// dispose the process service or turn a pending callback into UI work.
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    try {
      await _subscription?.cancel();
    } catch (_) {
      _lastIssue = 'event_cancel_failed';
    }
  }

  static Future<void> _initializeNative(Map<String, dynamic> bridgeContext) =>
      StminiFlutter.initialize(bridgeContext: bridgeContext);
}

/// Shows the original app immediately and configures STMini after its first frame.
class StminiStartupHost extends StatefulWidget {
  const StminiStartupHost({super.key, required this.child, this.startup});

  final Widget child;
  final StminiStartup? startup;

  @override
  State<StminiStartupHost> createState() => _StminiStartupHostState();
}

class _StminiStartupHostState extends State<StminiStartupHost> {
  @override
  void initState() {
    super.initState();
    final startup = widget.startup ?? StminiStartup.shared;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(startup.initializeOnce());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
