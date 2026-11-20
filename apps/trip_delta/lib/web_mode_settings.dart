import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ios_overlays.dart';
import 'strings.dart';

class WebModeActions {
  const WebModeActions({required this.save, required this.activate});
  final Future<void> Function() save;
  final ValueChanged<Locale> activate;
}

Future<void> showWebModeSettings(
  BuildContext context,
  L l,
  WebModeActions actions,
) async {
  final enabled = await showCupertinoModalPopup<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        iosOverlayTheme(context, _WebModeSettings(l: l, save: actions.save)),
  );
  if (enabled == true && context.mounted) {
    actions.activate(Localizations.localeOf(context));
  }
}

class _WebModeSettings extends StatefulWidget {
  const _WebModeSettings({required this.l, required this.save});
  final L l;
  final Future<void> Function() save;

  @override
  State<_WebModeSettings> createState() => _WebModeSettingsState();
}

class _WebModeSettingsState extends State<_WebModeSettings> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _enable(bool enabled) async {
    if (!enabled || _saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.save();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return PopScope(
      canPop: !_saving,
      child: CupertinoPopupSurface(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l('webHomeSettings'),
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l('webHomeEnable'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    CupertinoSwitch(
                      key: const Key('web_home_switch'),
                      value: false,
                      onChanged: _saving ? null : _enable,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l('webHomeExplanation'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CupertinoActivityIndicator(),
                  ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l('saveError'),
                      key: const Key('web_home_save_error'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                CupertinoButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text(l('cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
