import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/goal_repository.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final systemLanguage =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final controller = AppController(
    repository: SharedPreferencesGoalRepository(),
    defaultLocaleCode: systemLanguage == 'zh' ? 'zh' : 'en',
  );
  runApp(PaceJarApp(controller: controller));
  controller.initialize();
}
