import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/network/st_error_messages.dart';

/// 全局信息提示，视觉对齐 iOS `STMBProgressHUD showMessage`.
class STToast {
  STToast._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'STToastNavigatorKey');

  static OverlayEntry? _entry;
  static Timer? _hideTimer;

  static void showGlobal(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _showInOverlay(overlay, message, duration: duration);
  }

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _showInOverlay(overlay, message, duration: duration);
  }

  static void dismiss() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;
  }

  static void _showInOverlay(
    OverlayState overlay,
    String message, {
    required Duration duration,
  }) {
    final text = stSanitizeUserVisibleText(message);
    if (text.isEmpty) return;

    dismiss();
    final entry = OverlayEntry(
      builder: (context) => _STToastOverlay(message: text),
    );
    _entry = entry;
    overlay.insert(entry);
    _hideTimer = Timer(duration, dismiss);
  }
}

class _STToastOverlay extends StatelessWidget {
  const _STToastOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final size = MediaQuery.sizeOf(context);
    final maxWidth = math.max(120.0, math.min(size.width - 64, 300.0));
    final backgroundColor = brightness == Brightness.dark
        ? const Color(0xFF393940)
        : const Color(0xFF17171A);

    return IgnorePointer(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
