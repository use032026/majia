import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';

class TradeCloseOutProgressOverlayController {
  TradeCloseOutProgressOverlayController._(this._entry, this._progressValue);

  final OverlayEntry _entry;
  final ValueNotifier<String?> _progressValue;
  bool _dismissed = false;

  void updateProgress(String? progressValue) {
    if (_dismissed) return;
    _progressValue.value = progressValue;
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _entry.remove();
    _progressValue.dispose();
  }
}

TradeCloseOutProgressOverlayController showTradeCloseOutProgressOverlay({
  required BuildContext context,
  String? progressValue,
}) {
  final progressNotifier = ValueNotifier<String?>(progressValue);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => ValueListenableBuilder<String?>(
      valueListenable: progressNotifier,
      builder: (context, value, _) =>
          TradeCloseOutProgressPopup(progressValue: value),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return TradeCloseOutProgressOverlayController._(entry, progressNotifier);
}

class TradeCloseOutProgressPopup extends StatefulWidget {
  const TradeCloseOutProgressPopup({super.key, this.progressValue});

  final String? progressValue;

  @override
  State<TradeCloseOutProgressPopup> createState() =>
      _TradeCloseOutProgressPopupState();
}

class _TradeCloseOutProgressPopupState
    extends State<TradeCloseOutProgressPopup> {
  static const Map<String, String> _fallbackText = {
    'closing_position': '平仓中',
    'complete': '完成',
  };

  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = _fallbackText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    final token = ++_languageLoadToken;
    STLocalizations.ofContext(context).textMap(_fallbackText).then((text) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final completed = _t('complete');
    final progressText =
        widget.progressValue == null || widget.progressValue!.trim().isEmpty
        ? completed
        : '$completed ${widget.progressValue!.trim()}';

    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth - 100, 298.0);
            return Container(
              key: const ValueKey('trade_close_out_progress_shell'),
              width: width.clamp(220.0, 298.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.fromLTRB(24, 42, 24, 71),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    key: const ValueKey('trade_close_out_progress_icon_bg'),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4DCB73),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/st_trade_one_key_sec.png',
                        key: const ValueKey('trade_close_out_progress_icon'),
                        width: 32,
                        height: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    _t('closing_position'),
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    progressText,
                    style: const TextStyle(
                      color: Color(0xFF9A9DA2),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;
}
