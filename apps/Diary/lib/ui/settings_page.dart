import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../state/diary_controller.dart';
import 'entry_widgets.dart';
import 'trash_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final DiaryController controller;

  Future<void> _clearAll(BuildContext context) async {
    final text = AppText.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.clearAllTitle),
        content: Text('${text.clearAllBody}\n\n${text.irreversible}'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(text.clearAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = await controller.clearAll();
    if (!context.mounted || succeeded) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.savedFailure)));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.settings)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.only(
              bottom: bottomSafeSpacing(context, minimum: 36),
            ),
            children: <Widget>[
              PageWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SectionTitle(text.language),
                    const SizedBox(height: 10),
                    _OptionCard(
                      children: <Widget>[
                        _SelectTile(
                          label: text.followSystem,
                          selected: controller.snapshot.localeCode == 'system',
                          onTap: controller.isSaving
                              ? null
                              : () => controller.setLocale('system'),
                        ),
                        _SelectTile(
                          label: text.chinese,
                          selected: controller.snapshot.localeCode == 'zh',
                          onTap: controller.isSaving
                              ? null
                              : () => controller.setLocale('zh'),
                        ),
                        _SelectTile(
                          label: text.english,
                          selected: controller.snapshot.localeCode == 'en',
                          onTap: controller.isSaving
                              ? null
                              : () => controller.setLocale('en'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(text.appearance),
                    const SizedBox(height: 10),
                    _OptionCard(
                      children: <Widget>[
                        _SelectTile(
                          label: text.followSystem,
                          selected: controller.snapshot.themeMode == 'system',
                          onTap: controller.isSaving
                              ? null
                              : () => controller.setTheme('system'),
                        ),
                        _SelectTile(
                          label: text.light,
                          selected: controller.snapshot.themeMode == 'light',
                          onTap: controller.isSaving
                              ? null
                              : () => controller.setTheme('light'),
                        ),
                        _SelectTile(
                          label: text.dark,
                          selected: controller.snapshot.themeMode == 'dark',
                          onTap: controller.isSaving
                              ? null
                              : () => controller.setTheme('dark'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(text.dataPrivacy),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(Icons.shield_outlined),
                                const SizedBox(width: 12),
                                Expanded(child: Text(text.privacySummary)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.restore_from_trash_outlined,
                              ),
                              title: Text(text.recentlyDeleted),
                              trailing: Text(
                                '${controller.trashEntries.length}',
                              ),
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TrashPage(controller: controller),
                                ),
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              textColor: Theme.of(context).colorScheme.error,
                              iconColor: Theme.of(context).colorScheme.error,
                              leading: const Icon(
                                Icons.delete_forever_outlined,
                              ),
                              title: Text(text.clearAll),
                              onTap: controller.isSaving
                                  ? null
                                  : () => _clearAll(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        'EchoPage · 1.0.0 (1)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(value, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(child: Column(children: children));
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.circle_outlined),
      selected: selected,
    );
  }
}
