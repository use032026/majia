import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_localized_prompt.dart';

/// 编辑个性签名（布局对齐昵称编辑卡片与提示风格）
class ProfileSignatureEditPage extends ConsumerStatefulWidget {
  const ProfileSignatureEditPage({
    super.key,
    required this.initialSignature,
    this.maxLength = 500,
  });

  final String initialSignature;
  final int maxLength;

  @override
  ConsumerState<ProfileSignatureEditPage> createState() =>
      _ProfileSignatureEditPageState();
}

class _ProfileSignatureEditPageState
    extends ConsumerState<ProfileSignatureEditPage> {
  static const Map<String, String> _fallbackText = {
    'edit_sign': '编辑签名',
    'save': '保存',
    'please_enter_your_signature': '编辑个性签名...',
    'edit_signature_tip': '请输入字母、数字或空格',
  };

  late final TextEditingController _ctrl;
  bool _saving = false;
  Map<String, String> _text = _fallbackText;
  String? _localizedLanguageCode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialSignature);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLocalizedText();
  }

  int get _len => _ctrl.text.characters.length;

  Future<void> _save() async {
    if (_saving || _len > widget.maxLength) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(stServiceProvider);
      await service.editUserInfo(autograph: _ctrl.text.trim());
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (mounted) {
        showStLocalizedErrorToast(context, '保存失败', e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _ensureLocalizedText() {
    final languageCode = stLanguageCodeOfContext(context);
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    stLocalizationsOfContext(context, ref).textMap(_fallbackText).then((text) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _text = text);
    });
  }

  String _t(String key) => _text[key] ?? _fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final maxLen = widget.maxLength;
    final pageBg = context.adaptivePageGrey;
    final navBg = context.adaptiveSurfacePrimary;
    final cardBg = context.adaptiveCard;
    final primaryText = context.adaptiveTextPrimary;
    final secondaryText = context.adaptiveTextSecondary;
    final hintText = context.adaptiveTextHint;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: navBg,
        foregroundColor: primaryText,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t('edit_sign'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: primaryText,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: primaryText),
          onPressed: () => context.pop(false),
        ),
        actions: [
          TextButton(
            onPressed: (_saving || _len > maxLen) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _t('save'),
                    style: TextStyle(
                      fontSize: 15,
                      color: (_saving || _len > maxLen)
                          ? const Color(0xFF4DCB73).withValues(alpha: 0.35)
                          : const Color(0xFF4DCB73),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 112),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLines: 5,
                    maxLength: maxLen,
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => const SizedBox.shrink(),
                    inputFormatters: [LengthLimitingTextInputFormatter(maxLen)],
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 15, color: hintText),
                      hintText: _t('please_enter_your_signature'),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: primaryText,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$_len/$maxLen',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: hintText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _t('edit_signature_tip'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
