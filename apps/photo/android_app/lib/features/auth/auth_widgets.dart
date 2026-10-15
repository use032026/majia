import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/country_model.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_service.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_toast.dart';
import 'select_country_page.dart';
import 'auth_api_helpers.dart';
import 'auth_theme.dart';

STLocalizations _authLocalizationsOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(stLocalizationsProvider);
  } catch (_) {
    return STLocalizations.ofContext(context);
  }
}

/// iOS `STSelectCountryViewController`：全屏国家/地区选择（含搜索、热门/其他分组）
Future<String?> showAuthAreaCodePicker(
  BuildContext context, {
  required String current,
}) async {
  final fallback = CountryModel.fallbackDefaults;
  final currentModel =
      CountryModel.fromDialCode(current, fallback) ?? CountryModel.china;
  final next = await openSelectCountryPage(
    context,
    selectedCountryKey: currentModel.key,
  );
  return next?.dialCode;
}

/// 底部双选项 + 滑动下划线（对齐 iOS `UISegmentedControl` / 登录页分段）
class AuthIosTwinTabs extends StatelessWidget {
  const AuthIosTwinTabs({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.useLeft,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool useLeft;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: _tabCell(
            context: context,
            label: leftLabel,
            selected: useLeft,
            accent: primary,
            onTap: onLeft,
          ),
        ),
        Expanded(
          child: _tabCell(
            context: context,
            label: rightLabel,
            selected: !useLeft,
            accent: primary,
            onTap: onRight,
          ),
        ),
      ],
    );
  }

  Widget _tabCell({
    required BuildContext context,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.42);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? accent : muted,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2,
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「获取验证码」+ 60s 倒计时（对齐 iOS登录注册发送验证码交互）
class AuthSendCodeControl extends StatefulWidget {
  const AuthSendCodeControl({
    super.key,
    required this.onSend,
    this.alignTop = true,
    this.label,
  });

  final Future<void> Function() onSend;
  final bool alignTop;
  final String? label;

  @override
  State<AuthSendCodeControl> createState() => _AuthSendCodeControlState();
}

class _AuthSendCodeControlState extends State<AuthSendCodeControl> {
  int _sec = 0;
  Timer? _timer;
  String? _languageCode;
  String? _defaultLabel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDefaultLabel();
  }

  void _loadDefaultLabel() {
    if (widget.label != null) return;
    final localizations = _authLocalizationsOf(context);
    final languageCode = localizations.languageCode;
    if (_languageCode == languageCode && _defaultLabel != null) return;
    _languageCode = languageCode;
    localizations.textMap(const {'get_verification_code': '获取验证码'}).then((
      entries,
    ) {
      if (!mounted || _languageCode != languageCode) return;
      setState(() => _defaultLabel = entries['get_verification_code']);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick([int start = 60]) {
    _timer?.cancel();
    setState(() => _sec = start);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_sec <= 1) {
        t.cancel();
        setState(() => _sec = 0);
      } else {
        setState(() => _sec -= 1);
      }
    });
  }

  Future<void> _tap() async {
    if (_sec > 0) return;
    try {
      await widget.onSend();
      if (mounted) _tick(60);
    } catch (e) {
      if (!mounted) return;
      final text = e is FormatException
          ? e.message
          : AuthApiHelpers.userVisibleErrorSeed(e);
      showStLocalizedToast(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _sec > 0;
    final pad = widget.alignTop
        ? const EdgeInsets.only(top: 6)
        : EdgeInsets.zero;
    return Padding(
      padding: pad,
      child: TextButton(
        onPressed: disabled ? null : _tap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          disabled ? '${_sec}s' : (widget.label ?? _defaultLabel ?? '获取验证码'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: disabled ? Colors.grey.shade500 : AuthUi.linkBlue,
          ),
        ),
      ),
    );
  }
}

/// 封装验证码发送与 code 校验（失败抛异常）
abstract final class AuthVerCodeRequests {
  static Future<void> sendLoginSms({
    required STService service,
    required String tel,
    required String telAreaCode,
  }) async {
    final raw = await service.requestSmsVerCode({
      'type': STService.smsVerCodeTypeLogin,
      'tel': tel,
      'tel_area_code': telAreaCode,
    });
    AuthApiHelpers.ensureOk(raw);
  }

  static Future<void> sendLoginEmail({
    required STService service,
    required String email,
  }) async {
    final raw = await service.requestEmailVerCode({
      'type': STService.emailVerCodeTypeLogin,
      'email': email.trim(),
    });
    AuthApiHelpers.ensureOk(raw);
  }

  static Future<String> sendRegisterEmail({
    required STService service,
    required String email,
    required String vcodeSessionId,
    required String countryKey,
    String captchaId = '',
    String captchaKey = '',
    String captchaValue = '',
  }) async {
    final raw = await service.requestEmailVerCode({
      'vcode_session_id': vcodeSessionId,
      'type': STService.emailVerCodeTypeRegister,
      'email': email.trim(),
      'captcha_id': captchaId,
      'captcha_key': captchaKey,
      'captcha_value': captchaValue,
      'first_name': '',
      'last_name': '',
      'country_code': countryKey,
    });
    AuthApiHelpers.ensureOk(raw);
    final data = AuthApiHelpers.unwrapLoginPayload(raw);
    return '${data['vcode_id'] ?? ''}';
  }

  static Future<String> sendRegisterSms({
    required STService service,
    required String tel,
    required String telAreaCode,
    required String vcodeSessionId,
    required String countryKey,
    String captchaId = '',
    String captchaKey = '',
    String captchaValue = '',
  }) async {
    final raw = await service.requestSmsVerCode({
      'vcode_session_id': vcodeSessionId,
      'type': STService.smsVerCodeTypeRegister,
      'tel': tel,
      'tel_area_code': telAreaCode,
      'captcha_id': captchaId,
      'captcha_key': captchaKey,
      'captcha_value': captchaValue,
      'first_name': '',
      'last_name': '',
      'country_code': countryKey,
    });
    AuthApiHelpers.ensureOk(raw);
    final data = AuthApiHelpers.unwrapLoginPayload(raw);
    return '${data['vcode_id'] ?? ''}';
  }
}

/// 邮箱后缀补全浮层（对齐 iOS `STPopView`：白底圆角 9、行高 34、阴影）
class AuthRegisterEmailField extends StatefulWidget {
  const AuthRegisterEmailField({
    super.key,
    required this.controller,
    required this.hintText,
    this.enabled = true,
    this.focusNode,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final VoidCallback? onChanged;
  final String hintText;

  static const _suffixes = [
    '@gmail.com',
    '@outlook.com',
    '@yahoo.com',
    '@hotmail.com',
    '@icloud.com',
  ];

  @override
  State<AuthRegisterEmailField> createState() => _AuthRegisterEmailFieldState();
}

class _AuthRegisterEmailFieldState extends State<AuthRegisterEmailField> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncOverlay);
  }

  @override
  void didUpdateWidget(covariant AuthRegisterEmailField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncOverlay);
      widget.controller.addListener(_syncOverlay);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncOverlay);
    _removeOverlay();
    super.dispose();
  }

  List<String> _buildSuggestions(String text) {
    if (text.isEmpty) return [];
    final at = text.indexOf('@');
    final pipei = at >= 0 ? text.substring(at) : '';
    final out = <String>[];
    for (final s in AuthRegisterEmailField._suffixes) {
      if (pipei.isNotEmpty) {
        if (s.contains(pipei)) out.add(text.replaceAll(pipei, '') + s);
      } else {
        out.add(text + s);
      }
    }
    return out;
  }

  void _syncOverlay() {
    final items = _buildSuggestions(widget.controller.text);
    if (items.isEmpty) {
      _removeOverlay();
      return;
    }
    _showOverlay(items);
    widget.onChanged?.call();
  }

  void _showOverlay(List<String> items) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, AuthUi.registerFieldHeight),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: MediaQuery.sizeOf(ctx).width - AuthUi.padH * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AuthUi.cardBg(context),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(items.length, (i) {
                        final text = items[i];
                        final isLast = i == items.length - 1;
                        return InkWell(
                          onTap: () {
                            widget.controller.text = text;
                            widget.controller.selection =
                                TextSelection.collapsed(offset: text.length);
                            _removeOverlay();
                            widget.onChanged?.call();
                          },
                          child: Container(
                            height: 34,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 15, right: 12),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : Border(
                                      bottom: BorderSide(
                                        color: AuthUi.divider(context),
                                        width: 1,
                                      ),
                                    ),
                            ),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 14,
                                color: AuthUi.label(context),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
        onTapOutside: (_) => _removeOverlay(),
        decoration: AuthUi.registerField(
          context: context,
          hintText: widget.hintText,
        ),
        validator: widget.validator,
        onChanged: (_) => _syncOverlay(),
      ),
    );
  }
}

/// @deprecated 使用 [AuthRegisterEmailField] 浮层补全
class AuthEmailSuggestions extends StatelessWidget {
  const AuthEmailSuggestions({
    super.key,
    required this.controller,
    required this.onSelected,
  });

  final TextEditingController controller;
  final VoidCallback onSelected;

  static const _suffixes = [
    '@gmail.com',
    '@outlook.com',
    '@yahoo.com',
    '@hotmail.com',
    '@icloud.com',
  ];

  List<String> _buildSuggestions(String text) {
    if (text.isEmpty) return [];
    final at = text.indexOf('@');
    final pipei = at >= 0 ? text.substring(at) : '';
    final out = <String>[];
    for (final s in _suffixes) {
      if (pipei.isNotEmpty) {
        if (s.contains(pipei)) {
          out.add(text.replaceAll(pipei, '') + s);
        }
      } else {
        out.add(text + s);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final items = _buildSuggestions(value.text);
        if (items.isEmpty) return const SizedBox.shrink();
        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(6),
          color: AuthUi.cardBg(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map(
                  (t) => InkWell(
                    onTap: () {
                      controller.text = t;
                      onSelected();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 14,
                          color: AuthUi.label(context),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// iOS `STNewRegisterViewController` 分段切换（灰底胶囊，邮箱在左、手机在右）
class AuthRegisterModeTabs extends StatelessWidget {
  const AuthRegisterModeTabs({
    super.key,
    required this.phoneSelected,
    required this.onPhone,
    required this.onEmail,
    required this.emailLabel,
    required this.phoneLabel,
  });

  final bool phoneSelected;
  final VoidCallback onPhone;
  final VoidCallback onEmail;
  final String emailLabel;
  final String phoneLabel;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleBg = isDark ? const Color(0xFF2F3340) : Colors.white;

    Widget cell(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? primary : idleBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: selected ? Colors.white : AuthUi.label(context),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AuthUi.cardBg(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          cell(emailLabel, !phoneSelected, onEmail),
          const SizedBox(width: 8),
          cell(phoneLabel, phoneSelected, onPhone),
        ],
      ),
    );
  }
}

/// 注册页协议勾选（对齐 iOS `STLoginNoticeView`）
class AuthPrivacyNoticeView extends StatelessWidget {
  const AuthPrivacyNoticeView({
    super.key,
    required this.agreed,
    required this.onChanged,
    required this.onUserAgreement,
    required this.onPrivacyPolicy,
    required this.intro,
    required this.userAgreement,
    required this.conjunction,
    required this.privacyPolicy,
  });

  final bool agreed;
  final ValueChanged<bool> onChanged;
  final VoidCallback onUserAgreement;
  final VoidCallback onPrivacyPolicy;
  final String intro;
  final String userAgreement;
  final String conjunction;
  final String privacyPolicy;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final baseStyle = TextStyle(
      fontSize: 12,
      color: AuthUi.labelSecondary(context),
    );
    final linkStyle = TextStyle(fontSize: 12, color: primary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => onChanged(!agreed),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            child: AuthUi.authAsset(
              agreed ? 'st_mine_checked_sec' : 'st_mine_unchecked',
              width: 22,
              height: 22,
              fallbackIcon: agreed
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              fallbackColor: primary,
            ),
          ),
        ),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(intro, style: baseStyle),
              GestureDetector(
                onTap: onUserAgreement,
                child: Text(userAgreement, style: linkStyle),
              ),
              Text(conjunction, style: baseStyle),
              GestureDetector(
                onTap: onPrivacyPolicy,
                child: Text(privacyPolicy, style: linkStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 注册验证码输入 + 内嵌获取按钮（对齐 `STLoginTextFieldTypeVerCodeNew`）
class AuthRegisterVerCodeField extends StatefulWidget {
  const AuthRegisterVerCodeField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.canSend,
    required this.hintText,
    required this.sendLabel,
    this.focusNode,
    this.validator,
  });

  final TextEditingController controller;
  final Future<bool> Function() onSend;
  final bool canSend;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final String hintText;
  final String sendLabel;

  @override
  State<AuthRegisterVerCodeField> createState() =>
      _AuthRegisterVerCodeFieldState();
}

class _AuthRegisterVerCodeFieldState extends State<AuthRegisterVerCodeField> {
  int _sec = 0;
  int _resendRequestCount = 0;
  bool _sentOnce = false;
  Timer? _timer;
  String? _languageCode;
  Map<String, String> _localized = const {};

  static const Map<String, String> _fallbackText = {
    'get_verification_code': '获取验证码',
    'verify_code_error': '请输入正确的验证码',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedText();
  }

  void _loadLocalizedText() {
    final localizations = _authLocalizationsOf(context);
    final languageCode = localizations.languageCode;
    if (_languageCode == languageCode && _localized.isNotEmpty) return;
    _languageCode = languageCode;
    localizations.textMap(_fallbackText).then((entries) {
      if (!mounted || _languageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick([int start = 60]) {
    _timer?.cancel();
    setState(() => _sec = start);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_sec <= 1) {
        t.cancel();
        setState(() => _sec = 0);
      } else {
        setState(() => _sec -= 1);
      }
    });
  }

  Future<void> _send() async {
    if (_sec > 0 || !widget.canSend) return;
    if (_sentOnce) {
      _resendRequestCount += 1;
      if (_resendRequestCount > 3) {
        STToast.show(context, _t('verify_code_error'));
        return;
      }
    }
    try {
      final sent = await widget.onSend();
      if (mounted && sent) {
        _sentOnce = true;
        _tick(60);
      }
    } catch (e) {
      if (!mounted) return;
      final text = e is FormatException
          ? e.message
          : AuthApiHelpers.userVisibleErrorSeed(e);
      showStLocalizedToast(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final countdown = _sec > 0;
    final enabled = widget.canSend && !countdown;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.number,
      validator: widget.validator,
      decoration: AuthUi.registerField(
        context: context,
        hintText: widget.hintText,
        contentPadding: const EdgeInsets.only(
          left: 13,
          top: 10,
          bottom: 10,
          right: 4,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(
            widthFactor: 1,
            child: SizedBox(
              width: 91,
              height: 32,
              child: TextButton(
                onPressed: enabled ? _send : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: enabled
                      ? primary
                      : primary.withValues(alpha: 0.1),
                  foregroundColor: enabled ? Colors.white : AuthUi.linkBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  countdown ? '${_sec}s' : widget.sendLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 注册页选择行（国家/证件类型，对齐 `STChangeAreaView`）
class AuthRegisterPickerTile extends StatelessWidget {
  const AuthRegisterPickerTile({
    super.key,
    required this.title,
    this.placeholder,
    this.flagUrl,
    this.flagEmoji,
    this.enabled = true,
    required this.onTap,
  });

  final String title;
  final String? placeholder;
  final String? flagUrl;
  final String? flagEmoji;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showTitle = title.isNotEmpty;
    return Material(
      color: AuthUi.cardBg(context),
      borderRadius: BorderRadius.circular(AuthUi.registerFieldRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AuthUi.registerFieldRadius),
        child: SizedBox(
          height: AuthUi.registerFieldHeight,
          child: Row(
            children: [
              if (flagUrl != null || flagEmoji != null) ...[
                const SizedBox(width: 16),
                _FlagView(url: flagUrl, emoji: flagEmoji),
                const SizedBox(width: 8),
              ] else if (showTitle) ...[
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Text(
                  showTitle ? title : (placeholder ?? ''),
                  style: TextStyle(
                    fontSize: 15,
                    color: showTitle
                        ? AuthUi.label(context)
                        : AuthUi.hint(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 13),
                child: AuthUi.authAsset(
                  'st_new_login_down',
                  width: 10,
                  height: 10,
                  fallbackIcon: Icons.keyboard_arrow_down,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagView extends StatelessWidget {
  const _FlagView({this.url, this.emoji});

  final String? url;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!,
          width: 16,
          height: 16,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => AuthUi.authAsset(
            'st_icon_symbol_image_grey',
            width: 16,
            height: 16,
          ),
        ),
      );
    }
    return Text(emoji ?? '🌐', style: const TextStyle(fontSize: 16));
  }
}

/// 登录/验证码登录手机号区号前缀图标（对齐 iOS 圆角国旗）
class AuthLoginCountryFlagView extends StatelessWidget {
  const AuthLoginCountryFlagView({
    super.key,
    required this.flagUrl,
    required this.flagEmoji,
    this.size = 16,
    this.radius = 8,
  });

  final String flagUrl;
  final String flagEmoji;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (flagUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          flagUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => AuthUi.authAsset(
            'st_icon_symbol_image_grey',
            width: size,
            height: size,
          ),
        ),
      );
    }
    return AuthUi.authAsset(
      'st_icon_symbol_image_grey',
      width: size,
      height: size,
    );
  }
}

/// 登录/验证码登录手机号区号前缀（国旗 + 区号 + 下拉箭头）
class AuthLoginAreaCodePrefix extends StatelessWidget {
  const AuthLoginAreaCodePrefix({
    super.key,
    required this.dialCode,
    required this.flagUrl,
    required this.flagEmoji,
    required this.onTap,
    this.leftPadding = 10,
  });

  final String dialCode;
  final String flagUrl;
  final String flagEmoji;
  final VoidCallback onTap;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthLoginCountryFlagView(flagUrl: flagUrl, flagEmoji: flagEmoji),
            const SizedBox(width: 4),
            Text(
              dialCode.replaceFirst('+', ''),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AuthUi.label(context),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AuthUi.labelSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手机区号选择（对齐 `STChangeAreaCodeView`）
class AuthRegisterAreaCodeTile extends StatelessWidget {
  const AuthRegisterAreaCodeTile({
    super.key,
    required this.dialCode,
    required this.flagUrl,
    required this.flagEmoji,
    this.enabled = true,
    required this.onTap,
  });

  final String dialCode;
  final String flagUrl;
  final String flagEmoji;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuthUi.cardBg(context),
      borderRadius: BorderRadius.circular(AuthUi.registerFieldRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AuthUi.registerFieldRadius),
        child: SizedBox(
          height: AuthUi.registerFieldHeight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 128),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FlagView(url: flagUrl, emoji: flagEmoji),
                  const SizedBox(width: 11),
                  Flexible(
                    child: Text(
                      dialCode,
                      style: TextStyle(
                        fontSize: 15,
                        color: AuthUi.label(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AuthUi.authAsset(
                    'st_new_login_down',
                    width: 10,
                    height: 10,
                    fallbackIcon: Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 证件正/反面拍照区（对齐 `STIdInfoViewController` `addIDImageView`）
class AuthRegisterIdCardUploadRow extends StatelessWidget {
  const AuthRegisterIdCardUploadRow({
    super.key,
    required this.onFrontTap,
    required this.onBackTap,
    required this.frontLabel,
    required this.backLabel,
    this.frontPreview,
    this.backPreview,
  });

  final VoidCallback onFrontTap;
  final VoidCallback onBackTap;
  final String frontLabel;
  final String backLabel;
  final ImageProvider? frontPreview;
  final ImageProvider? backPreview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = (constraints.maxWidth - 11) / 2;
        return Row(
          children: [
            _IdCardSlot(
              width: cardW,
              label: frontLabel,
              placeholderAsset: 'st_id_card_front',
              preview: frontPreview,
              onTap: onFrontTap,
            ),
            const SizedBox(width: 10),
            _IdCardSlot(
              width: cardW,
              label: backLabel,
              placeholderAsset: 'st_id_card_back',
              preview: backPreview,
              onTap: onBackTap,
            ),
          ],
        );
      },
    );
  }
}

class _IdCardSlot extends StatelessWidget {
  const _IdCardSlot({
    required this.width,
    required this.label,
    required this.placeholderAsset,
    required this.onTap,
    this.preview,
  });

  final double width;
  final String label;
  final String placeholderAsset;
  final VoidCallback onTap;
  final ImageProvider? preview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 100,
      child: Material(
        color: AuthUi.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview != null)
                Image(image: preview!, fit: BoxFit.cover)
              else
                Column(
                  children: [
                    const SizedBox(height: 13),
                    AuthUi.authAsset(
                      placeholderAsset,
                      width: width * 0.55,
                      height: 40,
                      fallbackIcon: Icons.credit_card_outlined,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AuthUi.label(context),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 证件示例弹窗（对齐 `STIdCardExampleView`）
Future<void> showAuthIdCardExampleDialog(BuildContext context) async {
  final text = await _authLocalizationsOf(
    context,
  ).textMap(const {'example': '示例', 'cancel': '关闭'});
  if (!context.mounted) return;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: AuthUi.cardBg(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text['example']!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AuthUi.label(context),
                  ),
                ),
                const SizedBox(height: 11),
                AuthUi.authAsset(
                  'st_id_card_example',
                  width: 280,
                  height: 160,
                  fallbackIcon: Icons.image_outlined,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    text['cancel']!,
                    style: TextStyle(color: AuthUi.linkBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 第三方登录分隔 + 按钮（对齐 `addThirdLoginView`）
class AuthRegisterThirdLoginBar extends StatelessWidget {
  const AuthRegisterThirdLoginBar({
    super.key,
    required this.showGoogle,
    required this.showApple,
    required this.onGoogle,
    required this.onApple,
    required this.orLabel,
  });

  final bool showGoogle;
  final bool showApple;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final String orLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 19),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Divider(color: AuthUi.divider(context), height: 1),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  orLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: AuthUi.labelSecondary(context),
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: AuthUi.divider(context), height: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showGoogle) ...[
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: AuthUi.authAsset(
                    'st_google_login',
                    width: 40,
                    height: 40,
                  ),
                  onPressed: onGoogle,
                ),
                if (showApple) const SizedBox(width: 16),
              ],
              if (showApple)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: AuthUi.authAsset(
                    'st_apple_login',
                    width: 40,
                    height: 40,
                  ),
                  onPressed: onApple,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 协议确认弹窗（对齐 iOS `STCommonPopView` + `register_private_tips`）
Future<bool> showAuthPrivacyConfirmDialog(BuildContext context) async {
  final localizations = STLocalizations.ofContext(context);
  const fallbackText = {
    'register_private_tips': '请阅读并同意《用户协议》与《隐私政策》',
    'not_agree': '不同意',
    'agree': '同意',
  };
  final text = localizations.languageCode == 'zh-Hans'
      ? fallbackText
      : await localizations.textMap(fallbackText);
  if (!context.mounted) return false;
  final backgroundColor = AuthUi.commonPopBg(context);
  final dividerColor = AuthUi.divider(context);
  final cancelTextColor = AuthUi.labelSecondary(context);
  final confirmTextColor = Theme.of(context).colorScheme.primary;
  final titleColor = AuthUi.labelSecondary(context);
  final result = await showIosCommonAlertDialog(
    context: context,
    title: text['register_private_tips']!,
    cancelText: text['not_agree']!,
    confirmText: text['agree']!,
    backgroundColor: backgroundColor,
    dividerColor: dividerColor,
    cancelTextColor: cancelTextColor,
    confirmTextColor: confirmTextColor,
    titleStyle: TextStyle(
      color: titleColor,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.35,
    ),
  );
  return result == true;
}

/// 未收到验证码弹窗（对齐 iOS `STNotReceiveCodeView`）
Future<void> showAuthNotReceiveCodeDialog(
  BuildContext context, {
  required String message,
  required VoidCallback onService,
  required String title,
  required String closeText,
  required String serviceText,
}) {
  final pageBg = AuthUi.pageBg(context);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: pageBg,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AuthUi.authAsset(
                  'st_id_card_bg',
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.image_outlined,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 27, 24, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AuthUi.label(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AuthUi.resultBody(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 19),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  backgroundColor: AuthUi.cardBg(context),
                                  foregroundColor: AuthUi.label(context),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                child: Text(
                                  closeText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11.5),
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  onService();
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: AuthUi.linkBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                child: Text(
                                  serviceText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 证件类型选择（对齐 iOS `STMarketSettingIndexAlertController` 底部 sheet）
Future<int?> showRegisterIdTypePicker(
  BuildContext context, {
  required List<String> labels,
  required int selectedIndex,
}) async {
  final title = await _authLocalizationsOf(
    context,
  ).text('select_id_type', fallback: '选择证件类型');
  if (!context.mounted) return null;
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AuthUi.pageBg(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return SafeArea(
        child: SizedBox(
          height: 289 + bottom,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AuthUi.label(context),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: labels.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: AuthUi.divider(context)),
                  itemBuilder: (_, i) {
                    final selected = i == selectedIndex;
                    return ListTile(
                      title: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 15,
                          color: selected
                              ? AuthUi.linkBlue
                              : AuthUi.label(context),
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check,
                              color: AuthUi.linkBlue,
                              size: 20,
                            )
                          : null,
                      onTap: () => Navigator.pop(ctx, i),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
