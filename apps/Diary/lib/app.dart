import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_text.dart';
import 'state/diary_controller.dart';
import 'ui/app_theme.dart';
import 'ui/home_shell.dart';

class EchoPageApp extends StatelessWidget {
  const EchoPageApp({super.key, required this.controller});

  final DiaryController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'EchoPage',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: switch (controller.snapshot.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          locale: switch (controller.snapshot.localeCode) {
            'zh' => const Locale('zh', 'CN'),
            'en' => const Locale('en'),
            _ => null,
          },
          supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: controller.storageLocked
              ? _StorageLockedScreen(controller: controller)
              : HomeShell(controller: controller),
        );
      },
    );
  }
}

class _StorageLockedScreen extends StatelessWidget {
  const _StorageLockedScreen({required this.controller});

  final DiaryController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_outline_rounded, size: 52),
                  const SizedBox(height: 20),
                  Text(
                    text.storageErrorTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(text.storageErrorBody, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: controller.isLoading
                        ? null
                        : controller.initialize,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(text.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
