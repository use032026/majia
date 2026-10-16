import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Keeps side cutouts safe while letting scroll content reach the screen edge.
/// Use [pageScrollPadding] inside [builder] to protect the final item instead
/// of reserving a permanent strip outside the scrollable viewport.
class PageSafeArea extends StatelessWidget {
  const PageSafeArea({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(bottom: false, child: Builder(builder: builder));
  }
}

EdgeInsets pageScrollPadding(
  BuildContext context, {
  double horizontal = 20,
  double top = 8,
}) {
  // Scaffold already resizes for the keyboard and consumes the bottom padding
  // when it owns a bottom bar. Use the remaining inset, never viewInsets or
  // viewPadding, so neither obstruction is counted twice.
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    math.max(24.0, MediaQuery.paddingOf(context).bottom + 12),
  );
}
