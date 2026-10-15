import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_localized_prompt.dart';

/// Figma 2175:77584 — 编辑昵称
class ProfileNicknameEditPage extends ConsumerStatefulWidget {
  const ProfileNicknameEditPage({super.key, required this.initialNickname});

  final String initialNickname;

  @override
  ConsumerState<ProfileNicknameEditPage> createState() =>
      _ProfileNicknameEditPageState();
}

class _ProfileNicknameEditPageState
    extends ConsumerState<ProfileNicknameEditPage> {
  static const int _maxLen = 24;
  static const Map<String, String> _fallbackText = {
    'edit_nickname': '编辑昵称',
    'save': '保存',
    'please_enter_your_nickname': '输入昵称...',
    'edit_nickname_tip': '请输入2-24个字符，不支持@<>/等特殊字符。',
  };
  static final RegExp _invalidChars = RegExp(r'[@<>\/]');

  late final TextEditingController _ctrl;
  bool _saving = false;
  Map<String, String> _text = _fallbackText;
  String? _localizedLanguageCode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNickname);
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

  bool get _canSave {
    final t = _ctrl.text.trim();
    if (t.length < 2 || t.length > _maxLen) return false;
    if (_invalidChars.hasMatch(t)) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(stServiceProvider);
      await service.editUserInfo(nickName: _ctrl.text.trim());
      if (!mounted) return;
      ref.read(userStateProvider.notifier).updateNickname(_ctrl.text.trim());
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
          _t('edit_nickname'),
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
            onPressed: (_saving || !_canSave) ? null : _save,
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
                      color: (_saving || !_canSave)
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
              height: 48,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        maxLines: 1,
                        maxLength: _maxLen,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => const SizedBox.shrink(),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_maxLen),
                        ],
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: _t('please_enter_your_nickname'),
                          hintStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: hintText,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: primaryText,
                        ),
                      ),
                    ),
                    Text(
                      '$_len/$_maxLen',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: hintText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _t('edit_nickname_tip'),
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
