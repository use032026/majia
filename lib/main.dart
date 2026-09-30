import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/diary_repository.dart';
import 'state/diary_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await FileDiaryRepository.createDefault();
  final controller = DiaryController(repository);
  await controller.initialize();
  runApp(EchoPageApp(controller: controller));
}
