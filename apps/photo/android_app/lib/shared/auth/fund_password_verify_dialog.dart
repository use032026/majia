import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'white_label_password_ui.dart';

/// Figma「输入资金密码」弹层：灰底卡片、6 格、错误、「忘记」链接（无独立确定键，输入满 6 位自动提交）
/// iOS `STInputFinancePwdPopView` uses a full-screen black mask at 30% alpha.
Future<String?> showFundPasswordVerifyDialog(
  BuildContext context, {
  String title = '请输入资金密码',
  String? errorText,
}) async {
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0x4D000000),
    builder: (ctx) =>
        _FundPasswordVerifyDialog(title: title, initialErrorText: errorText),
  );
}

class _FundPasswordVerifyDialog extends StatefulWidget {
  final String title;
  final String? initialErrorText;

  const _FundPasswordVerifyDialog({required this.title, this.initialErrorText});

  @override
  State<_FundPasswordVerifyDialog> createState() =>
      _FundPasswordVerifyDialogState();
}

class _FundPasswordVerifyDialogState extends State<_FundPasswordVerifyDialog> {
  late final TextEditingController _codeCtrl;
  late final FocusNode _focus;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _focus = FocusNode();
    _errorText = widget.initialErrorText;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_codeCtrl.text.length != 6) {
      setState(() => _errorText = '请输入6位资金密码');
      return;
    }
    Navigator.of(context).pop(_codeCtrl.text);
  }

  Widget _cell(int index) {
    final text = _codeCtrl.text;
    final hasValue = index < text.length;
    final focused =
        _focus.hasFocus && !hasValue && index == text.length && text.length < 6;
    final border = index == 5
        ? const Color(0xFFECECEC)
        : WhiteLabelAuthColors.border;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: hasValue
          ? Text(
              text[index],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            )
          : focused
          ? Container(width: 2, height: 16, color: Colors.black)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 299,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2E3330),
                ),
              ),
              const SizedBox(height: 33),
              Column(
                children: [
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0,
                      child: TextField(
                        controller: _codeCtrl,
                        focusNode: _focus,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(counterText: ''),
                        onChanged: (_) {
                          setState(() {});
                          if (_codeCtrl.text.length == 6) _submit();
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          _cell(i),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (_errorText != null && _errorText!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: WhiteLabelAuthColors.error,
                  ),
                ),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 54),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: WhiteLabelAuthColors.primary,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '忘记资金密码？',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: WhiteLabelAuthColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
