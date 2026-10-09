import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_links.dart';
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
                const SizedBox(height: 24),
                _SectionLabel(text.get('preferences')),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _PreferenceHeading(
                            icon: Icons.translate,
                            title: text.get('language'),
                            subtitle: text.get('languageHelp'),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              key: const Key('language-selector'),
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
                              showSelectedIcon:
                                  MediaQuery.textScalerOf(context).scale(1) <
                                  1.6,
                              expandedInsets: EdgeInsets.zero,
                              onSelectionChanged: (value) =>
                                  controller.setLocaleCode(value.first),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 62),
                    _SettingsRow(
                      key: const Key('dark-mode-setting'),
                      icon: controller.darkMode
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      title: text.get('darkMode'),
                      subtitle: text.get(
                        controller.darkMode ? 'darkModeOn' : 'darkModeOff',
                      ),
                      trailing: CupertinoSwitch(
                        value: controller.darkMode,
                        onChanged: controller.setDarkMode,
                      ),
                      onTap: () => controller.setDarkMode(!controller.darkMode),
                      semanticsButton: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionLabel(text.get('privacyTitle')),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsRow(
                      key: const Key('privacy-policy'),
                      icon: Icons.shield_outlined,
                      title: text.get('privacyPolicy'),
                      subtitle: text.get('privacyPolicyHelp'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPrivacy(context),
                    ),
                    const Divider(height: 1, indent: 62),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _PreferenceHeading(
                            icon: Icons.storage_outlined,
                            title: text.get('localData'),
                            subtitle: text.get('privacyBody'),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.only(left: 46),
                            child: OfflineBadge(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (controller.errorCode != null) ...<Widget>[
                  const SizedBox(height: 14),
                  ErrorBanner(message: text.get('saveFailed')),
                ],
                const SizedBox(height: 24),
                _SectionLabel(text.get('dataManagement')),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsRow(
                      key: const Key('delete-all'),
                      icon: Icons.delete_outline,
                      title: text.get('deleteAll'),
                      subtitle: text.get('deleteAllHelp'),
                      trailing: const Icon(Icons.chevron_right),
                      destructive: true,
                      onTap: () => _delete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacy(BuildContext context) async {
    final text = AppText.of(context);
    final uri = AppLinks.privacyPolicyUriFor(controller.localeCode);
    if (uri == null) {
      _showMessage(context, text.get('privacyLinkUnavailable'));
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );
      if (context.mounted && !opened) {
        _showMessage(context, text.get('privacyLinkFailed'));
      }
    } on Exception {
      if (context.mounted) {
        _showMessage(context, text.get('privacyLinkFailed'));
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete(BuildContext context) async {
    final text = AppText.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(text.get('deleteTitle')),
        content: Text(text.get('deleteBody')),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.get('cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAllData();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _PreferenceHeading extends StatelessWidget {
  const _PreferenceHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SettingsIcon(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.destructive = false,
    this.semanticsButton = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final bool destructive;
  final bool semanticsButton;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _SettingsIcon(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: destructive
                          ? color.withValues(alpha: 0.82)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconTheme(
              data: IconThemeData(color: color.withValues(alpha: 0.72)),
              child: trailing,
            ),
          ],
        ),
      ),
    );
    if (!semanticsButton) return row;
    return Semantics(
      container: true,
      button: true,
      label: title,
      hint: subtitle,
      excludeSemantics: true,
      child: row,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 19, color: foreground),
    );
  }
}
