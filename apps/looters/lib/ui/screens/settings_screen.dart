import 'package:flutter/material.dart';

import '../../l10n/app_text.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const PageStorageKey<String>('settings-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text.get('settings'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          text.get('language'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'zh',
                              label: Text('简体中文'),
                            ),
                            ButtonSegment<String>(
                              value: 'en',
                              label: Text('English'),
                            ),
                          ],
                          selected: <String>{controller.localeCode},
                          onSelectionChanged: (value) =>
                              controller.setLocaleCode(value.first),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(text.get('darkMode')),
                          secondary: Icon(
                            controller.darkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                          ),
                          value: controller.darkMode,
                          onChanged: controller.setDarkMode,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.privacy_tip_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                text.get('privacyTitle'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(text.get('privacyBody')),
                        const SizedBox(height: 12),
                        const OfflineBadge(),
                      ],
                    ),
                  ),
                ),
                if (controller.errorCode != null) ...<Widget>[
                  const SizedBox(height: 14),
                  ErrorBanner(message: text.get('saveFailed')),
                ],
                const SizedBox(height: 26),
                OutlinedButton.icon(
                  key: const Key('delete-all'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(text.get('deleteAll')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final text = AppText.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.get('deleteTitle')),
        content: Text(text.get('deleteBody')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteGoal();
  }
}
