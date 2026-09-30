import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/reader_edit_app.dart';
import 'app/reader_edit_store.dart';
import 'data/session_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final supportDirectory = await getApplicationSupportDirectory();
  final store = ReaderEditStore(
    JsonFileSessionRepository(
      directory: supportDirectory,
      preferences: preferences,
    ),
  );
  await store.load();
  runApp(ReaderEditApp(store: store));
}
