import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Figma「APP 白标 2.0」密码/验证相关色与基础块（找回密码 / 修改密码 / 资金密码共用）
class WhiteLabelAuthColors {
  WhiteLabelAuthColors._();

  static const Color border = Color(0xFFE7E8E9);
  static const Color primary = Color(0xFF00B57A);
  static const Color subtitle = Color(0xFF60656D);
  static const Color placeholder = Color(0xFFD9D9D9);
  static const Color muted = Color(0xFFA9A9A9);
  static const Color cancel = Color(0xFF949494);
  static const Color inactiveTab = Color(0xFF9A9DA2);
  /// 成功态主色（Figma APP 白标 2.0：修改密码完成 / 成功勾选）
  static const Color success = Color(0xFF4DCB73);
  static const Color timer = Color(0xFF4DCB73);
  static const Color error = Color(0xFFF95959);
}

class WhiteLabelAuthTopBar extends StatelessWidget {
  const WhiteLabelAuthTopBar({
    super.key,
    required this.onBack,
    required this.onCancel,
    this.cancelColor,
    this.cancelText = '取消',
    this.showCancel = true,
  });

  final VoidCallback onBack;
  final VoidCallback onCancel;
  final Color? cancelColor;
  final String cancelText;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            padding: const EdgeInsets.only(left: 2),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
            onPressed: onBack,
          ),
          const Spacer(),
          if (showCancel)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: cancelColor ?? WhiteLabelAuthColors.cancel,
                padding: const EdgeInsets.only(right: 8),
              ),
              onPressed: onCancel,
              child: Text(
                cancelText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cancelColor ?? WhiteLabelAuthColors.cancel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WhiteLabelPillButton extends StatelessWidget {
  const WhiteLabelPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 191,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: WhiteLabelAuthColors.primary,
          disabledBackgroundColor: WhiteLabelAuthColors.primary.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(31)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
      ),
    );
  }
}

class WhiteLabelFieldBox extends StatelessWidget {
  const WhiteLabelFieldBox({
    super.key,
    required this.child,
    this.suffix,
    this.borderColor = WhiteLabelAuthColors.border,
  });

  final Widget child;
  final Widget? suffix;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: child),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

/// 6 格验证码 + 隐藏输入（与修改登录密码 / 找回密码 / 资金密码验证页一致）
class WhiteLabelOtpInput extends StatefulWidget {
  const WhiteLabelOtpInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;

  @override
  State<WhiteLabelOtpInput> createState() => _WhiteLabelOtpInputState();
}

class _WhiteLabelOtpInputState extends State<WhiteLabelOtpInput> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_ref);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_ref);
    super.dispose();
  }

  void _ref() {
    if (mounted) setState(() {});
  }

  Widget _cell(int index) {
    final text = widget.controller.text;
    final has = index < text.length;
    final char = has ? text[index] : '';
    final len = text.length;
    final focused = widget.focusNode.hasFocus && !has && index == len && len < 6;
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: WhiteLabelAuthColors.border),
      ),
      child: has
          ? Text(char, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500))
          : focused
              ? Container(width: 2, height: 20, color: Colors.black)
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
              onChanged: (v) {
                setState(() {});
                widget.onChanged?.call(v);
              },
            ),
          ),
        ),
        GestureDetector(
          onTap: () => widget.focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                _cell(i),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
