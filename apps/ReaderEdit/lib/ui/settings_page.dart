import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/reader_edit_store.dart';
import '../l10n/app_strings.dart';
import 'app_notice.dart';
import 'page_safe_area.dart';
import 'onboarding_page.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.store, super.key});

  final ReaderEditStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final strings = AppStrings.of(context);
        final colors = CupertinoTheme.of(context);
        final background = CupertinoColors.systemGroupedBackground.resolveFrom(
          context,
        );
        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            title: Text(strings.settings),
            backgroundColor: background,
          ),
          body: PageSafeArea(
            builder: (context) => SizedBox.expand(
              child: DefaultTextStyle(
                style: colors.textTheme.textStyle,
                child: SingleChildScrollView(
                  padding: pageScrollPadding(context, horizontal: 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CupertinoListSection.insetGrouped(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(strings.language),
                                    const SizedBox(height: 14),
                                    CupertinoSlidingSegmentedControl<String>(
                                      key: const ValueKey('language_selector'),
                                      groupValue: store.languageCode,
                                      children: {
                                        'zh': Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            strings.chinese,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        'en': Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            strings.english,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      },
                                      onValueChanged: (value) async {
                                        if (value == null || store.isBusy) {
                                          return;
                                        }
                                        try {
                                          await store.setLanguageCode(value);
                                        } on Object {
                                          if (context.mounted) {
                                            _showError(context);
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(strings.darkMode)),
                                    const SizedBox(width: 16),
                                    CupertinoSwitch(
                                      key: const ValueKey('dark_mode_switch'),
                                      value: store.darkMode,
                                      onChanged: store.isBusy
                                          ? null
                                          : (value) async {
                                              try {
                                                await store.setDarkMode(value);
                                              } on Object {
                                                if (context.mounted) {
                                                  _showError(context);
                                                }
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          CupertinoListSection.insetGrouped(
                            header: Text(strings.help),
                            children: [
                              CupertinoListTile(
                                title: Text(strings.tour),
                                trailing: const Icon(
                                  CupertinoIcons.chevron_forward,
                                  size: 18,
                                ),
                                onTap: () => Navigator.of(context).push<void>(
                                  CupertinoPageRoute(
                                    builder: (_) => OnboardingPage(
                                      store: store,
                                      replay: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          CupertinoListSection.insetGrouped(
                            header: Text(strings.dataPrivacy),
                            children: [
                              CupertinoListTile(
                                key: const ValueKey('privacy_policy_button'),
                                title: Text(strings.privacyPolicy),
                                trailing: const Icon(
                                  CupertinoIcons.chevron_forward,
                                  size: 18,
                                ),
                                onTap: () => Navigator.of(context).push<void>(
                                  CupertinoPageRoute(
                                    builder: (_) => PrivacyPolicyPage(
                                      languageCode: store.languageCode,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          CupertinoListSection.insetGrouped(
                            children: [
                              CupertinoButton(
                                alignment: Alignment.centerLeft,
                                onPressed:
                                    (store.sessions.isEmpty &&
                                            store.novels.isEmpty) ||
                                        store.isBusy
                                    ? null
                                    : () => _confirmClear(context),
                                child: Text(
                                  strings.clearAll,
                                  style: TextStyle(
                                    color:
                                        (store.sessions.isEmpty &&
                                                store.novels.isEmpty) ||
                                            store.isBusy
                                        ? CupertinoColors.tertiaryLabel
                                              .resolveFrom(context)
                                        : CupertinoColors.systemRed.resolveFrom(
                                            context,
                                          ),
                                  ),
                                ),
                              ),
                            ],
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
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final strings = AppStrings.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(strings.clearAllTitle),
        content: Text(strings.clearAllBody),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.erase),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.clearAll();
      if (context.mounted) Navigator.pop(context);
    } on Object {
      if (context.mounted) _showError(context);
    }
  }

  void _showError(BuildContext context) {
    showAppNotice(context, AppStrings.of(context).saveFailed);
  }
}
