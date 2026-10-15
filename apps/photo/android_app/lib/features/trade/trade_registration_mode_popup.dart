import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';

enum TradeRegistrationMode { limit, stop }

Future<TradeRegistrationMode?> showTradeRegistrationModePopup({
  required BuildContext context,
  required Rect anchorRect,
  required TradeRegistrationMode currentMode,
}) {
  return showGeneralDialog<TradeRegistrationMode>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.01),
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, _) => TradeRegistrationModePopup(
      anchorRect: anchorRect,
      currentMode: currentMode,
      onSelected: (mode) => Navigator.of(dialogContext).pop(mode),
    ),
  );
}

class TradeRegistrationModePopup extends StatefulWidget {
  const TradeRegistrationModePopup({
    super.key,
    required this.anchorRect,
    required this.currentMode,
    required this.onSelected,
  });

  final Rect anchorRect;
  final TradeRegistrationMode currentMode;
  final ValueChanged<TradeRegistrationMode> onSelected;

  @override
  State<TradeRegistrationModePopup> createState() =>
      _TradeRegistrationModePopupState();
}

class _TradeRegistrationModePopupState
    extends State<TradeRegistrationModePopup> {
  static const Map<String, String> _fallbackText = {
    'limit_order': '限价单',
    'stop_order': '停损单',
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
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(widget.anchorRect.width, screenSize.width);
    final left = widget.anchorRect.left.clamp(0.0, screenSize.width - width);
    final top = widget.anchorRect.top.clamp(0.0, screenSize.height - 68);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            height: 68,
            child: Container(
              key: const ValueKey('trade_registration_mode_shell'),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 1),
                    blurRadius: 6,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _TradeRegistrationModeRow(
                    key: const ValueKey('trade_registration_mode_row_limit'),
                    title: _t('limit_order'),
                    selected: widget.currentMode == TradeRegistrationMode.limit,
                    showDivider: true,
                    onTap: () => widget.onSelected(TradeRegistrationMode.limit),
                  ),
                  _TradeRegistrationModeRow(
                    key: const ValueKey('trade_registration_mode_row_stop'),
                    title: _t('stop_order'),
                    selected: widget.currentMode == TradeRegistrationMode.stop,
                    showDivider: false,
                    onTap: () => widget.onSelected(TradeRegistrationMode.stop),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;
}

class _TradeRegistrationModeRow extends StatelessWidget {
  const _TradeRegistrationModeRow({
    super.key,
    required this.title,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 34,
        child: Stack(
          children: [
            Center(
              child: Text(
                title,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF00B57A)
                      : const Color(0xFF000000),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (showDivider)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: Color(0xFFECECEC)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
