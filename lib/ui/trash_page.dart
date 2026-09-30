import 'package:flutter/material.dart';

import '../domain/diary_entry.dart';
import '../l10n/app_text.dart';
import '../state/diary_controller.dart';
import 'entry_widgets.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key, required this.controller});

  final DiaryController controller;

  Future<bool> _confirm(BuildContext context, String title) async {
    final text = AppText.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(text.irreversible),
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
                child: Text(title),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteForever(BuildContext context, DiaryEntry entry) async {
    final text = AppText.of(context);
    if (!await _confirm(context, text.deleteForever) || !context.mounted) {
      return;
    }
    final succeeded = await controller.deleteForever(entry.id);
    if (!context.mounted || succeeded) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.savedFailure)));
  }

  Future<void> _restore(BuildContext context, DiaryEntry entry) async {
    final succeeded = await controller.restore(entry.id);
    if (!context.mounted || succeeded) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppText.of(context).savedFailure)));
  }

  Future<void> _empty(BuildContext context) async {
    final text = AppText.of(context);
    if (!await _confirm(context, text.emptyTrash) || !context.mounted) {
      return;
    }
    final succeeded = await controller.emptyTrash();
    if (!context.mounted || succeeded) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.savedFailure)));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.recentlyDeleted),
        actions: <Widget>[
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => TextButton(
              onPressed: controller.trashEntries.isEmpty || controller.isSaving
                  ? null
                  : () => _empty(context),
              child: Text(text.emptyTrash),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final entries = controller.trashEntries;
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.restore_from_trash_outlined,
              title: text.trashEmpty,
              body: '',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.title.isEmpty ? text.pageUntitled : entry.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(formatDiaryDate(context, entry.createdAt)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: controller.isSaving
                                ? null
                                : () => _restore(context, entry),
                            icon: const Icon(Icons.restore_rounded),
                            label: Text(text.restore),
                          ),
                          TextButton.icon(
                            onPressed: controller.isSaving
                                ? null
                                : () => _deleteForever(context, entry),
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: Text(text.deleteForever),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
