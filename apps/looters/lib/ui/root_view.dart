import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../state/app_controller.dart';
import 'screens/create_goal_screen.dart';
import 'screens/empty_screen.dart';
import 'screens/home_shell.dart';

class RootView extends StatelessWidget {
  const RootView({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return Scaffold(
        body: Center(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(AppText.of(context).get('loading')),
              ],
            ),
          ),
        ),
      );
    }
    if (controller.loadFailure) {
      return _LoadFailureScreen(controller: controller);
    }
    if (controller.corruptRecord) {
      return _CorruptRecordScreen(controller: controller);
    }
    if (controller.goal == null && controller.completedGoals.isEmpty) {
      return EmptyScreen(
        controller: controller,
        onCreate: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateGoalScreen(controller: controller),
          ),
        ),
      );
    }
    return HomeShell(controller: controller);
  }
}

class _LoadFailureScreen extends StatelessWidget {
  const _LoadFailureScreen({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.sync_problem_outlined,
                        color: Theme.of(context).colorScheme.error,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        text.get('loadFailedTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(text.get('loadFailed')),
                      const SizedBox(height: 8),
                      Text(text.get('loadFailedSafety')),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        key: const Key('retry-load'),
                        onPressed: controller.initialize,
                        icon: const Icon(Icons.refresh),
                        label: Text(text.get('retry')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CorruptRecordScreen extends StatefulWidget {
  const _CorruptRecordScreen({required this.controller});

  final AppController controller;

  @override
  State<_CorruptRecordScreen> createState() => _CorruptRecordScreenState();
}

class _CorruptRecordScreenState extends State<_CorruptRecordScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.get('appName')),
        actions: <Widget>[
          TextButton(
            onPressed: () => widget.controller.setLocaleCode(
              widget.controller.localeCode == 'zh' ? 'en' : 'zh',
            ),
            child: Text(widget.controller.localeCode == 'zh' ? 'EN' : '中'),
          ),
          IconButton(
            tooltip: text.get('darkMode'),
            onPressed: () =>
                widget.controller.setDarkMode(!widget.controller.darkMode),
            icon: Icon(
              widget.controller.darkMode ? Icons.light_mode : Icons.dark_mode,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.inventory_2_outlined,
                        color: Theme.of(context).colorScheme.error,
                        size: 36,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        text.get('corruptTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(text.get('corruptBody')),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _busy ? null : _confirmClear,
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: Text(text.get('clearCorrupt')),
                      ),
                      if (widget.controller.errorCode != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          text.get('saveFailed'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final text = AppText.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text(text.get('clearCorrupt')),
        content: Text(text.get('deleteBody')),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.get('cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await widget.controller.clearCorruptRecord();
    if (mounted) setState(() => _busy = false);
  }
}
