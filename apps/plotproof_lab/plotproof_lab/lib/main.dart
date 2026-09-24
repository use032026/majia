import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/lesson_catalog_repository.dart';
import 'data/progress_repository.dart';
import 'state/app_controller.dart';

const _lessonPackUrl = String.fromEnvironment(
  'PLOTPROOF_LESSON_PACK_URL',
  defaultValue:
      'https://raw.githubusercontent.com/use032026/majia/main/apps/plotproof_lab/plotproof_lab/content/lesson_pack.json',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    SharedPreferencesProgressRepository(preferences),
    lessonCatalogRepository: SharedPreferencesLessonCatalogRepository(
      preferences: preferences,
      client: http.Client(),
      endpoint: Uri.parse(_lessonPackUrl),
    ),
  );
  await controller.initialize(systemLocale: PlatformDispatcher.instance.locale);
  runApp(PlotProofApp(controller: controller));
  unawaited(controller.refreshLessons());
}
