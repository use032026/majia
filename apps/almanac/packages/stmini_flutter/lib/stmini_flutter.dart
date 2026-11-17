import 'dart:async';

import 'package:flutter/services.dart';

import 'src/safe_event_stream.dart';
import 'src/stmini_event.dart';

export 'src/stmini_event.dart';

/// Stage-one foundation only. No Mini/Web page or package loader is compiled.
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
