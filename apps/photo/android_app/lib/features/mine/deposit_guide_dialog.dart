import 'package:flutter/material.dart';

import '../../core/theme/context_adaptive_colors.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

Future<bool?> showDepositGuideDialog({required BuildContext context}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) => DepositGuideDialog(
      onConfirm: () => Navigator.of(dialogContext).pop(true),
      onClose: () => Navigator.of(dialogContext).pop(false),
    ),
  );
}

class DepositGuideDialog extends StatelessWidget {
  const DepositGuideDialog({super.key, this.onConfirm, this.onClose});

  final VoidCallback? onConfirm;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 100;
    final cardBg = context.adaptiveCard;
    final primaryText = context.adaptiveTextPrimary;
    final tertiaryText = context.adaptiveTextTertiary;
    final secondaryText = context.adaptiveTextSecondary;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const ValueKey('deposit_guide_dialog_shell'),
          width: width.clamp(260.0, 320.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/st_mine_deposit_guide.png',
                key: const ValueKey('deposit_guide_dialog_image'),
                width: 108,
                height: 108,
              ),
              Text(
                '账户未激活',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '立即入金领取',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  color: tertiaryText,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                key: const ValueKey('deposit_guide_confirm_button'),
                height: 36,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B57A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: Text(stLocalizedTextFromZhHans('立即入金')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 235,
                height: 20,
                child: TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryText,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: Text(stLocalizedTextFromZhHans('先逛逛')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
