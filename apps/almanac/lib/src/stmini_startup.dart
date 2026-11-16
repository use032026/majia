import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stmini_flutter/stmini_flutter.dart';

typedef StminiInitializer =
    Future<void> Function(Map<String, dynamic> bridgeContext);

/// Initializes native foundation configuration without changing app data.
class StminiStartup {
  StminiStartup({StminiInitializer? initialize})
    : _initialize = initialize ?? _initializeNative;

  static final StminiStartup shared = StminiStartup();

  final StminiInitializer _initialize;
  Future<void>? _initialization;

  /// Keeps either terminal result for this process; startup never retries.
  Future<void> initializeOnce() => _initialization ??= _initializeSafely();

  Future<void> _initializeSafely() async {
    try {
      await _initialize(const <String, dynamic>{
        'packageName': 'com.almanac.lite',
      });
    } catch (_) {
      // Initialization is optional for the local app. Do not expose native
      // error details or let a failed plugin replace the existing home page.
      if (kDebugMode) debugPrint('[Deynu] STMini initialization failed.');
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
