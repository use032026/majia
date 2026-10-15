import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

Future<bool?> showTradeCancelOrderDialog({
  required BuildContext context,
  required String orderId,
}) async {
  final id = orderId.trim();
  final localizations = STLocalizations.ofContext(context);
  final message = id.isEmpty
      ? '${await localizations.text('cancel_order', fallback: '撤单')}?'
      : (await localizations.text(
          'cancel_order_tip_ios',
          fallback: '确认撤销订单 %@？',
        )).replaceAll('%@', id);
  if (!context.mounted) return null;

  return showTradeConfirmDialog(
    context: context,
    message: message,
  );
}

Future<bool?> showTradeClosePositionDialog({
  required BuildContext context,
  required String symbol,
  required String lots,
}) async {
  final symbolText = symbol.trim().isEmpty ? '---' : symbol.trim();
  final lotsText = lots.trim().isEmpty ? '0' : lots.trim();
  final localizations = STLocalizations.ofContext(context);
  final labels = await localizations.textMap({
    'cancel': '取消',
    'confirm_close_position': '确认平仓',
    'hand': '手',
  });
  if (!context.mounted) return null;
  final confirmClosePosition =
      labels['confirm_close_position'] ?? '确认平仓';
  final handText = labels['hand'] ?? '手';

  return showTradeConfirmDialog(
    context: context,
    message: '$confirmClosePosition\n$symbolText\n$lotsText $handText',
    cancelText: labels['cancel'] ?? '取消',
    confirmText: confirmClosePosition,
  );
}

Future<bool?> showTradeConfirmDialog({
  required BuildContext context,
  required String message,
  String? cancelText,
  String? confirmText,
}) async {
  final localizations = STLocalizations.ofContext(context);
  final needCancelText = cancelText == null;
  final needConfirmText = confirmText == null;
  Map<String, String> resolvedText = const {};
  if (needCancelText || needConfirmText) {
    resolvedText = await localizations.textMap({
      if (needCancelText) 'cancel': '取消',
      if (needConfirmText) 'certain': '确定',
    });
  }
  if (!context.mounted) return null;
  final resolvedCancelText = cancelText ?? resolvedText['cancel'] ?? '取消';
  final resolvedConfirmText = confirmText ?? resolvedText['certain'] ?? '确定';

  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 50),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        key: const ValueKey('trade_confirm_dialog_shell'),
        width: 298,
        decoration: BoxDecoration(
          color: dialogContext.adaptiveCard,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 25),
        child: Stack(
          children: [
            Positioned(
              top: -2,
              right: -2,
              child: GestureDetector(
                key: const ValueKey('trade_confirm_close'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(false),
                child: Image.asset(
                  'assets/images/st_mine_close_gary.png',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/st_common_warn.png',
                  key: const ValueKey('trade_confirm_warn_icon'),
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: dialogContext.adaptiveTextPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 45),
                Row(
                  children: [
                    const SizedBox(width: 21),
                    Expanded(
                      child: _TradeConfirmButton(
                        text: resolvedCancelText,
                        backgroundColor:
                            dialogContext.adaptivePlaceholderSurface,
                        textColor: dialogContext.adaptiveTextPrimary,
                        onTap: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _TradeConfirmButton(
                        text: resolvedConfirmText,
                        backgroundColor: const Color(0xFF00B57A),
                        textColor: Colors.white,
                        onTap: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ),
                    const SizedBox(width: 21),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _TradeConfirmButton extends StatelessWidget {
  const _TradeConfirmButton({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        child: Text(text),
      ),
    );
  }
}
