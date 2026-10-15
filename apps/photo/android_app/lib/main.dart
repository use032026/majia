import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'photo/app_settings.dart' as photo_settings;
import 'photo/photo_app.dart' as photo;
import 'trade_app.dart' as trade;

const androidTradeModeKey = 'android_trade_mode_enabled';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(AndroidModeHost(preferences: preferences));
}

class AndroidModeHost extends StatefulWidget {
  const AndroidModeHost({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<AndroidModeHost> createState() => _AndroidModeHostState();
}

class _AndroidModeHostState extends State<AndroidModeHost> {
  late final photo_settings.AppSettingsController _photoSettings =
      photo_settings.AppSettingsController(widget.preferences);
  late bool _tradeEnabled =
      widget.preferences.getBool(androidTradeModeKey) ?? false;

  Future<void> _openTrade() async {
    final saved = await widget.preferences.setBool(androidTradeModeKey, true);
    if (!saved) throw StateError('Could not save the Android launch mode.');
    if (mounted) setState(() => _tradeEnabled = true);
  }

  @override
  void dispose() {
    _photoSettings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tradeEnabled) {
      return KeyedSubtree(
        key: const ValueKey('trade-mode'),
        child: trade.buildTradeAppRoot(),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('photo-mode'),
      child: photo.JufuApp(
        settings: _photoSettings,
        preferences: widget.preferences,
        onOpenTrade: _openTrade,
      ),
    );
  }
}
