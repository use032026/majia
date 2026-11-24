import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ios_overlays.dart';
import 'site_update.dart';
import 'strings.dart';

class SiteUpdateButton extends StatefulWidget {
  const SiteUpdateButton({super.key, required this.l});

  final L l;

  @override
  State<SiteUpdateButton> createState() => _SiteUpdateButtonState();
}

class _SiteUpdateButtonState extends State<SiteUpdateButton> {
  bool _checking = false;

  Future<void> _check() async {
    final l = widget.l;
    setState(() => _checking = true);
    try {
      final update = await checkInstalledSiteUpdate();
      if (!mounted) return;
      if (!update.hasUpdate) {
        showIosNotice(context, l('noSiteUpdate'));
        return;
      }

      final notes = update.updateNotes?.trim() ?? '';
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(
            l(
              update.forceUpdate ? 'siteUpdateRequired' : 'siteUpdateAvailable',
            ),
          ),
          content: Text(
            '${l('siteUpdateVersion')} ${update.latestVersion}'
            '${notes.isEmpty ? '' : '\n\n$notes'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l('openSiteUpdate')),
            ),
          ],
        ),
      );
      if (open != true || !mounted) return;
      await _openDownload(update.downloadUrl!, l);
    } catch (_) {
      if (mounted) showIosNotice(context, l('siteUpdateCheckFailed'));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openDownload(Uri url, L l) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Surface the same feedback when a platform has no suitable handler.
    }
    if (mounted) showIosNotice(context, l('openSiteUpdateFailed'));
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.l(_checking ? 'checkingSiteUpdate' : 'checkSiteUpdate'),
    onPressed: _checking ? null : _check,
    icon: _checking
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.system_update_alt),
  );
}
