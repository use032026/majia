import 'dart:async';

import 'package:flutter/services.dart';

import 'src/safe_event_stream.dart';
import 'src/stmini_event.dart';
import 'src/stmini_package.dart';

export 'src/stmini_event.dart';
export 'src/stmini_package.dart';
export 'src/stmini_local_view.dart';

/// Foundation, read-only inventory and verified local PlatformViews.
/// Full openMini/openWeb link loading remains unavailable.
class StminiFlutter {
  StminiFlutter._();
  static const runtimeStage = 'foundation';
  static const _methods = MethodChannel('stmini_flutter/methods');
  static final Stream<StminiEvent> _events = SafeStminiEventStream();

  /// Shared native diagnostics, using main's `{name, payload}` contract.
  /// Activation/envelope failures are stream errors. The last listener must
  /// await cancellation to handle a native cancellation failure locally.
  static Stream<StminiEvent> get events => _events;

  /// Configures the native foundation. Only packageName is supported here.
  /// Native rejects capabilities/parameters that are not part of this stage.
  static Future<void> initialize({
    String? loadingImage,
    Map<String, dynamic>? bridgeContext,
  }) => _methods.invokeMethod<void>('initialize', {
    if (loadingImage != null) 'loadingImage': loadingImage,
    if (bridgeContext != null) 'bridgeContext': bridgeContext,
  });

  /// Reads validated local metadata only. Rendering uses StminiLocalView and
  /// independently revalidates package identity and local resource boundaries.
  /// A missing or malformed native reply is a failure, never an empty inventory.
  static Future<List<StminiPackage>> installedPackages() async {
    final value = await _methods.invokeMethod<Object?>('installedPackages');
    if (value is! List || value.length > 256) {
      throw const FormatException('Invalid local inventory response.');
    }
    final ids = <String>{};
    final packages = <StminiPackage>[];
    for (final item in value) {
      if (item is! Map) {
        throw const FormatException('Invalid local inventory item.');
      }
      final package = StminiPackage.fromMap(item);
      if (!ids.add(package.miniId)) {
        throw const FormatException('Duplicate local inventory identity.');
      }
      packages.add(package);
    }
    return List<StminiPackage>.unmodifiable(packages);
  }

  /// Actual native stage/identity/language state; not a complete-runtime claim.
  static Future<Map<String, dynamic>> get foundationState async {
    final value = await _methods.invokeMapMethod<String, dynamic>(
      'foundationState',
    );
    if (value == null) {
      throw StateError('Native STMini foundation did not return its state.');
    }
    return Map<String, dynamic>.unmodifiable(value);
  }
}
