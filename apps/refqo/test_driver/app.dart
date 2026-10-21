import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final folder = Directory(
        'docs/release/evidence/runtime/${Platform.environment['REFQO_DEVICE'] ?? 'device'}',
      );
      await folder.create(recursive: true);
      await File('${folder.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
