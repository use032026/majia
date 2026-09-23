import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../config/app_links.dart';
import '../widgets/ios_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  String _languageLabel(BuildContext context, String languageCode) =>
      languageCode == 'zh'
      ? context.l10n.simplifiedChinese
      : context.l10n.english;

  Future<void> _selectLanguage() async {
    final store = StoreScope.of(context);
    final selected = await showIosActionSheet<String>(
      context: context,
      title: context.l10n.chooseLanguage,
      cancelLabel: context.l10n.cancel,
      options: ['zh', 'en']
          .map(
            (languageCode) => IosActionSheetOption(
              label: _languageLabel(context, languageCode),
              value: languageCode,
              isSelected: languageCode == store.languageCode,
            ),
          )
          .toList(growable: false),
    );
    if (selected == null || selected == store.languageCode) return;
    try {
      await store.setLanguageCode(selected);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.languageChangeFailed)),
        );
      }
    }
  }

  Future<void> _shareBackup() async {
    setState(() => _busy = true);
    try {
      final bytes = await StoreScope.of(context).exportBackupPackage();
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/zip')],
          fileNameOverrides: ['KIFXPRO-backup.movingbox.zip'],
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final store = StoreScope.of(context);
    final confirmed = await showIosConfirmation(
      context: context,
      title: context.l10n.restoreBackup,
      message: context.l10n.restoreWarning,
      cancelLabel: context.l10n.cancel,
      confirmLabel: context.l10n.restore,
      isDestructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip', 'movingbox', 'json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw const FormatException('Unreadable backup');
      final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
      final missingPhotos = isZip
          ? await store.importBackupPackage(bytes)
          : await store.importBackup(bytes).then((_) => 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              missingPhotos == 0
                  ? context.l10n.restoreSuccess
                  : context.l10n.restoreSuccessMissingPhotos(missingPhotos),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.invalidBackup)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showInfo(String title, String body) {
    return showIosInfoDialog(
      context: context,
      title: title,
      message: body,
      closeLabel: context.l10n.close,
    );
  }

  Future<void> _openPrivacy() async {
    final rawUrl = AppLinks.privacyPolicyUrlFor(
      StoreScope.of(context).languageCode,
    );
    final uri = Uri.tryParse(rawUrl);
    try {
      if (uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } on Exception {
      // Fall back to the complete built-in privacy notice below.
    }
    if (mounted) {
      await _showInfo(context.l10n.privacy, context.l10n.privacyBody);
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppLinks.supportEmail,
      queryParameters: {'subject': context.l10n.supportEmailSubject},
    );
    try {
      if (await launchUrl(uri)) return;
    } on Exception {
      // Show the support fallback below when no mail client is available.
    }
    if (mounted) {
      await _showInfo(
        context.l10n.contactSupport,
        context.l10n.supportNotConfigured,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final privacyPolicyUrl = AppLinks.privacyPolicyUrlFor(
      StoreScope.of(context).languageCode,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: const Key('settings-language'),
              leading: const Icon(Icons.language_outlined),
              title: Text(context.l10n.language),
              subtitle: Text(
                _languageLabel(context, StoreScope.of(context).languageCode),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectLanguage,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(context.l10n.backup),
                  trailing: const Icon(Icons.ios_share),
                  enabled: !_busy,
                  onTap: _shareBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined),
                  title: Text(context.l10n.restoreBackup),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy,
                  onTap: _restoreBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(context.l10n.privacy),
                  subtitle: Text(privacyPolicyUrl),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openPrivacy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: Text(context.l10n.contactSupport),
                  subtitle: const Text(AppLinks.supportEmail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _contactSupport,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 22),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
