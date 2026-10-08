import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/app_controller.dart';
import 'data/session_repository.dart';
import 'services/audio_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await FileSessionRepository.create();
  final controller = AppController(
    repository: repository,
    recorder: DeviceRecorderService(),
    player: DeviceClipPlayerService(),
  );
  await controller.initialize();
  runApp(SomniloquyApp(controller: controller));
}
