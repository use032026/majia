import 'package:flutter/material.dart';
import '../../core/network/st_error_messages.dart';

Future<bool?> showIosCommonAlertDialog({
  required BuildContext context,
  required String title,
  String? message,
  String cancelText = '取消',
  String confirmText = '确定',
  Future<void> Function()? onCancel,
  Future<void> Function()? onConfirm,
  bool showCancel = true,
  bool showConfirm = true,
  bool barrierDismissible = false,
  Color? backgroundColor,
  Color? dividerColor,
  Color? cancelTextColor,
  Color? confirmTextColor,
  TextStyle? titleStyle,
  TextStyle? messageStyle,
  TextStyle? cancelButtonTextStyle,
  TextStyle? confirmButtonTextStyle,
}) async {
  assert(showCancel || showConfirm, '至少显示一个按钮');
  final safeTitle = stSanitizeUserVisibleText(title);
  final safeMessage = message == null
      ? null
      : stSanitizeUserVisibleText(message);
  final effectiveBackgroundColor = backgroundColor ?? Colors.white;
  final effectiveDividerColor = _visibleDividerColor(
    backgroundColor: effectiveBackgroundColor,
    dividerColor: dividerColor ?? const Color(0xFFEFEFF0),
  );

  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: _IosCommonAlterDialog(
        title: safeTitle,
        message: safeMessage,
        backgroundColor: effectiveBackgroundColor,
        dividerColor: effectiveDividerColor,
        cancelText: cancelText,
        confirmText: confirmText,
        showCancel: showCancel,
        showConfirm: showConfirm,
        cancelTextColor: cancelTextColor ?? const Color(0xFF60656D),
        confirmTextColor: confirmTextColor ?? const Color(0xFFF95959),
        titleStyle:
            titleStyle ??
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        messageStyle:
            messageStyle ??
            const TextStyle(
              fontSize: 16,
              color: Color(0xFF9A9DA2),
              height: 1.4,
            ),
        cancelButtonTextStyle:
            cancelButtonTextStyle ??
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        confirmButtonTextStyle:
            confirmButtonTextStyle ??
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    ),
  ).then((value) async {
    if (value == true) {
      await onConfirm?.call();
      return true;
    }
    if (value == false) {
      await onCancel?.call();
      return false;
    }
    return null;
  });
}

Color _visibleDividerColor({
  required Color backgroundColor,
  required Color dividerColor,
}) {
  return dividerColor == backgroundColor
      ? const Color(0xFFD9D9D9)
      : dividerColor;
}

class _IosCommonAlterDialog extends StatelessWidget {
  const _IosCommonAlterDialog({
    required this.title,
    required this.backgroundColor,
    required this.dividerColor,
    required this.cancelText,
    required this.confirmText,
    required this.showCancel,
    required this.showConfirm,
    required this.cancelTextColor,
    required this.confirmTextColor,
    required this.titleStyle,
    required this.messageStyle,
    required this.cancelButtonTextStyle,
    required this.confirmButtonTextStyle,
    this.message,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String? message;
  final Color backgroundColor;
  final Color dividerColor;
  final String cancelText;
  final String confirmText;
  final bool showCancel;
  final bool showConfirm;
  final Color cancelTextColor;
  final Color confirmTextColor;
  final TextStyle titleStyle;
  final TextStyle messageStyle;
  final TextStyle cancelButtonTextStyle;
  final TextStyle confirmButtonTextStyle;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final contentColor = messageStyle.copyWith(color: messageStyle.color);
    final separatorColor = dividerColor;

    return Center(
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: titleStyle.copyWith(
                        color: titleStyle.color ?? Colors.black,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: contentColor,
                      ),
                    ],
                  ],
                ),
              ),
              Container(height: 1, color: separatorColor),
              if (showCancel && showConfirm)
                SizedBox(
                  height: 57,
                  child: Row(
                    children: [
                      Expanded(
                        child: _IosDialogButton(
                          text: cancelText,
                          textStyle: cancelButtonTextStyle.copyWith(
                            color: cancelTextColor,
                          ),
                          onTap: onCancel,
                        ),
                      ),
                      Container(width: 1, height: 57, color: dividerColor),
                      Expanded(
                        child: _IosDialogButton(
                          text: confirmText,
                          textStyle: confirmButtonTextStyle.copyWith(
                            color: confirmTextColor,
                          ),
                          onTap: onConfirm,
                        ),
                      ),
                    ],
                  ),
                )
              else if (showCancel)
                _IosDialogButton(
                  text: cancelText,
                  textStyle: cancelButtonTextStyle.copyWith(
                    color: cancelTextColor,
                  ),
                  onTap: onCancel,
                  fullWidth: true,
                )
              else
                _IosDialogButton(
                  text: confirmText,
                  textStyle: confirmButtonTextStyle.copyWith(
                    color: confirmTextColor,
                  ),
                  onTap: onConfirm,
                  fullWidth: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosDialogButton extends StatelessWidget {
  const _IosDialogButton({
    required this.text,
    required this.textStyle,
    required this.onTap,
    this.fullWidth = false,
  });

  final String text;
  final TextStyle textStyle;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 57,
      child: InkWell(
        onTap: onTap,
        child: Center(child: Text(text, style: textStyle)),
      ),
    );
  }
}
