import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/almanac_app.dart';
import 'src/app_controller.dart';
import 'src/data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    store: PreferencesStateStore(preferences),
    seedFactory: () => Random.secure().nextInt(0x7fffffff).toRadixString(16),
  );
  await controller.load();
  runApp(AlmanacApp(controller: controller));
}
