import 'package:flutter/widgets.dart';

class WebModeActions {
  const WebModeActions({required this.save, required this.activate});
  final Future<void> Function() save;
  final Future<void> Function(Locale) activate;
}
