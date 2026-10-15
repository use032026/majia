import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

Future<void> showTradeActionFailedDialog({
  required BuildContext context,
  required String title,
  required String reason,
  bool isSuccess = false,
  Color? titleColor,
  VoidCallback? onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) => _TradeActionFailedDialogContent(
      title: title,
      reason: reason,
      isSuccess: isSuccess,
      titleColor: titleColor,
      onConfirm: onConfirm,
    ),
  );
}

class _TradeActionFailedDialogContent extends StatefulWidget {
  const _TradeActionFailedDialogContent({
    required this.title,
    required this.reason,
    required this.isSuccess,
    required this.titleColor,
    required this.onConfirm,
  });

  final String title;
  final String reason;
  final bool isSuccess;
  final Color? titleColor;
  final VoidCallback? onConfirm;

  @override
  State<_TradeActionFailedDialogContent> createState() =>
      _TradeActionFailedDialogContentState();
}

class _TradeActionFailedDialogContentState
    extends State<_TradeActionFailedDialogContent> {
  String _confirmText = '确定';
  String? _languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    _loadLabels(languageCode);
  }

  Future<void> _loadLabels(String languageCode) async {
    final confirmText = await STLocalizations.ofContext(
      context,
    ).text('certain', fallback: '确定');
    if (!mounted || _languageCode != languageCode) return;
    setState(() => _confirmText = confirmText);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 50),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        key: const ValueKey('trade_action_failed_dialog_shell'),
        width: 298,
        decoration: BoxDecoration(
          color: context.adaptiveCard,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              widget.isSuccess
                  ? 'assets/images/st_common_success.png'
                  : 'assets/images/st_common_warn.png',
              key: ValueKey(
                widget.isSuccess
                    ? 'trade_action_failed_success_icon'
                    : 'trade_action_failed_warn_icon',
              ),
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 11),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: widget.titleColor ?? const Color(0xFFF95959),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.adaptiveTextPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 45),
            SizedBox(
              width: 80,
              height: 34,
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm?.call();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B57A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(_confirmText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
