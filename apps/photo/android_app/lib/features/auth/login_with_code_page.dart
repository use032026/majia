import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/user_state.dart';
import '../../core/network/device_id_manager.dart';
import '../../core/models/country_model.dart';
import '../../core/network/st_service.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/router/policy_link_route.dart';
import '../../shared/widgets/st_action_refreshing_hud.dart';
import '../../shared/widgets/st_base_scaffold.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_toast.dart';
import 'auth_api_helpers.dart';
import 'auth_captcha_dialog.dart';
import 'auth_login_commit.dart';
import 'auth_theme.dart';
import 'auth_widgets.dart';

/// 与 iOS `STLoginWithVercodeController` 对齐：验证码登录页（独立页面）
enum _LoginVercodeKind { phone, email }

/// 账号登录页共用 key（对齐 iOS `STUserInfoManger.isAgreePrivacy`）
const _kPrivacyAgreedKey = 'is_agree_privacy';

class LoginWithCodePage extends ConsumerStatefulWidget {
  const LoginWithCodePage({super.key});

  @override
  ConsumerState<LoginWithCodePage> createState() => _LoginWithCodePageState();
}

class _LoginWithCodePageState extends ConsumerState<LoginWithCodePage> {
  static const Map<String, String> _fallbackText = {
    'verify_login': '验证码登录',
    'email': '邮箱',
    'phone': '手机',
    'password_login': '密码登录',
    'login': '登录',
    'have_read_and_agree': '我已阅读并同意',
    'phone_number_input': '请输入手机号码',
    'phone_number_format_error': '手机号格式不对',
    'please_input_email': '请输入邮箱',
    'email_format_error': '邮箱格式不正确',
    'please_input_phone_verify_code': '请输入手机验证码',
    'please_input_email_verify_code': '请输入邮箱验证码',
    'get_verification_code': '获取验证码',
    'verification_code_sent_to_mobile': '验证码已发送至您的手机，10分钟内有效。',
    'verification_code_sent_successfully': '验证码已发送',
    'verification_code_sent_to_email': '验证码已发送至您的邮箱，10分钟内有效。',
    'user_agreement': '《用户协议》',
    'privacy_policy': '《隐私政策》',
    'and': '和',
    'requestfail': '数据加载失败',
    'flutter_prompt_address_not_configured': '{title}地址未配置',
    'flutter_prompt_cancel_captcha': '已取消图形验证码',
    'flutter_prompt_vercode_retry_later': '验证码错误，请稍后重试',
  };

  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _isLoading = false;
  bool _agreed = false;
  int _requestVercodeCount = 0;
  _LoginVercodeKind _acctKind = _LoginVercodeKind.phone;
  String _telAreaCode = '+86';
  CountryModel _selectedCountry = CountryModel.china;
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final nextCode = stLanguageCodeOfContext(context);
    if (_languageCode == nextCode && _localized.isNotEmpty) return;
    _languageCode = nextCode;

    final token = ++_languageLoadToken;
    loadStLocalizedTextMap(context, ref, _fallbackText).then((entries) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _agreed = prefs.getBool(_kPrivacyAgreedKey) ?? false);
    });

    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _codeController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(countryManagerProvider.notifier).ensureLoaded();
      if (!mounted) return;
      setState(() {
        _selectedCountry = ref.read(effectiveSelectedCountryProvider);
        _telAreaCode = _selectedCountry.dialCode;
      });
    });
  }

  CountryModel _currentCountryModel() {
    return CountryModel.fromDialCode(
          _telAreaCode,
          ref.read(countryManagerProvider).allCountries,
        ) ??
        _selectedCountry;
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _canLogin {
    if (_acctKind == _LoginVercodeKind.phone) {
      final tel = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
      return tel.length >= 6 && _codeController.text.trim().isNotEmpty;
    }

    final email = _emailController.text.trim();
    return email.contains('@') && _codeController.text.trim().isNotEmpty;
  }

  Future<void> _pickAreaCode() async {
    final next = await showAuthAreaCodePicker(context, current: _telAreaCode);
    if (!mounted || next == null) return;
    final matched = CountryModel.fromDialCode(
      next,
      ref.read(countryManagerProvider).allCountries,
    );
    setState(() {
      _telAreaCode = next;
      _selectedCountry = matched ?? _selectedCountry;
    });
  }

  Future<void> _savePrivacyAgreed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrivacyAgreedKey, value);
  }

  Future<bool> _showPrivacyDialog() async {
    final agreed = await showAuthPrivacyConfirmDialog(context);
    if (agreed) {
      if (mounted) setState(() => _agreed = true);
      await _savePrivacyAgreed(true);
    }
    return agreed;
  }

  Future<Map<String, dynamic>> _captchaBridgeUserInfo(STService service) async {
    final user = ref.read(userStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceId = await DeviceIdManager.getDeviceId();
    var appVersion = '';
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}

    return {
      if (user.userId.isNotEmpty) 'id': user.userId,
      'avatar': '',
      'firstName': '',
      'lastName': '',
      'nickName': user.nickname,
      'level': '',
      'domain_id': '',
      'funds_password_status': user.isBindFundPassword ? '1' : '0',
      'ab': user.isB ? 'b' : 'a',
      'language_code': service.dio.currentLanguage,
      'token': user.token,
      'device_id': deviceId,
      'device_type': 'ios',
      'dark_mode': isDark ? '1' : '0',
      'appVersion': appVersion,
      'timeZone': '${DateTime.now().timeZoneOffset.inHours}',
    };
  }

  Future<void> _sendLoginCode() async {
    if (_requestVercodeCount > 2) {
      throw Exception(_t('flutter_prompt_vercode_retry_later'));
    }

    final service = ref.read(stServiceProvider);
    final h5 = ref.read(userStateProvider).h5AddressModel;
    final configuredCaptchaUrl = h5?.codeVerifyUrl.trim() ?? '';
    final captchaUrl = configuredCaptchaUrl.isEmpty
        ? 'localMini://codeverify'
        : configuredCaptchaUrl;

    final bridgeUserInfo = await _captchaBridgeUserInfo(service);
    if (!mounted) return;
    final captcha = await showAuthCaptchaDialog(
      context,
      url: captchaUrl,
      baseHost: service.dio.baseUrl.replaceFirst(RegExp(r'/violet/?$'), ''),
      captchaApiKey: h5?.captchaApiKey ?? '',
      bridgeUserInfo: bridgeUserInfo,
    );
    if (!mounted) return;
    if (captcha == null) {
      throw Exception(_t('flutter_prompt_cancel_captcha'));
    }

    if (_acctKind == _LoginVercodeKind.phone) {
      final tel = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
      if (tel.length < 6) {
        throw FormatException(_t('phone_number_format_error'));
      }
      _requestVercodeCount++;
      final raw = await service.requestSmsVerCode({
        'type': STService.smsVerCodeTypeLogin,
        'tel': tel,
        'tel_area_code': _telAreaCode,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      AuthApiHelpers.ensureOk(raw);
    } else {
      final email = _emailController.text.trim();
      if (!email.contains('@')) {
        throw FormatException(_t('email_format_error'));
      }
      _requestVercodeCount++;
      final raw = await service.requestEmailVerCode({
        'type': STService.emailVerCodeTypeLogin,
        'email': email,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      AuthApiHelpers.ensureOk(raw);
    }

    if (!mounted) return;
    STToast.show(
      context,
      _acctKind == _LoginVercodeKind.phone
          ? _t('verification_code_sent_successfully')
          : _t('verification_code_sent_successfully'),
    );
  }

  Future<void> _handleLogin() async {
    if (!_agreed) {
      final agreed = await _showPrivacyDialog();
      if (!agreed) return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(stServiceProvider);
      late Map<String, dynamic> result;

      if (_acctKind == _LoginVercodeKind.phone) {
        final tel = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
        final code = _codeController.text.trim();
        result = await service.loginPhoneSms(
          telAreaCode: _telAreaCode,
          tel: tel,
          verifyCode: code,
        );
      } else {
        final email = _emailController.text.trim();
        final code = _codeController.text.trim();
        result = await service.loginEmailSms(email: email, verifyCode: code);
      }

      if (!mounted) return;
      await commitLoginSuccess(
        ref: ref,
        context: context,
        loginResult: result,
        retryFailedRouter: false,
        successPopCount: 2,
      );
    } catch (e) {
      if (mounted) {
        showStLocalizedToast(context, AuthApiHelpers.userVisibleErrorSeed(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openWeb(String route, String title) async {
    final opened = await PolicyLinkRoute.open(
      context,
      ref,
      privacy: route == '/privacy',
      title: title,
    );
    if (!opened && mounted) {
      showStLocalizedToastByKey(
        context,
        'flutter_prompt_address_not_configured',
        fallback: _fallbackText['flutter_prompt_address_not_configured'],
        replacements: {'title': title},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        STBaseScaffold(
          showNavigationBar: true,
          backgroundColor: AuthUi.pageBg(context),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 20,
              color: AuthUi.label(context),
            ),
            onPressed: () => context.pop(),
          ),
          onBack: () => context.pop(),
          keyboardFocusNodes: _acctKind == _LoginVercodeKind.phone
              ? [_phoneFocus, _codeFocus]
              : [_emailFocus, _codeFocus],
          actions: [
            IconButton(
              icon: const Icon(Icons.headset_mic_outlined, size: 22),
              color: AuthUi.label(context),
              onPressed: () => CustomerServiceRoute.open(context, ref),
            ),
          ],
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      _t('verify_login'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AuthUi.label(context),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        _kindTab(
                          context,
                          _t('email'),
                          _acctKind == _LoginVercodeKind.email,
                          () => setState(
                            () => _acctKind = _LoginVercodeKind.email,
                          ),
                        ),
                        const SizedBox(width: 32),
                        _kindTab(
                          context,
                          _t('phone'),
                          _acctKind == _LoginVercodeKind.phone,
                          () => setState(
                            () => _acctKind = _LoginVercodeKind.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_acctKind == _LoginVercodeKind.phone)
                      _phoneField(context)
                    else
                      _emailField(context),
                    const SizedBox(height: 16),
                    _codeField(context),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _t('password_login'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AuthUi.label(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 48,
                        child: FilledButton(
                          onPressed: (_isLoading || !_canLogin)
                              ? null
                              : _handleLogin,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF34C759),
                            disabledBackgroundColor: const Color(0xFFD1F2E1),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _t('login'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          setState(() => _agreed = !_agreed);
                          await _savePrivacyAgreed(_agreed);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _agreed
                                    ? AuthUi.linkBlue
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _agreed
                                      ? AuthUi.linkBlue
                                      : AuthUi.labelSecondary(context),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _agreed
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _agreementIntroText(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AuthUi.labelSecondary(context),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _openWeb(
                                      '/agreement',
                                      _t('user_agreement'),
                                    ),
                                    child: Text(
                                      _t('user_agreement'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AuthUi.linkBlue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _t('and'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AuthUi.labelSecondary(context),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _openWeb(
                                      '/privacy',
                                      _t('privacy_policy'),
                                    ),
                                    child: Text(
                                      _t('privacy_policy'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AuthUi.linkBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          const STActionRefreshingHud(
            key: ValueKey('auth-action-refreshing-hud'),
          ),
      ],
    );
  }

  Widget _kindTab(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: selected
              ? AuthUi.label(context)
              : AuthUi.labelSecondary(context),
        ),
      ),
    );
  }

  Widget _phoneField(BuildContext context) {
    final country = _currentCountryModel();
    return _inputBox(
      context: context,
      child: Row(
        children: [
          AuthLoginAreaCodePrefix(
            dialCode: _telAreaCode,
            flagUrl: country.flagUrl,
            flagEmoji: country.flagEmoji,
            onTap: _pickAreaCode,
          ),
          Container(
            width: 1,
            height: 20,
            color: AuthUi.divider(context),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
              ],
              decoration: _inputDecoration(context, _t('phone_number_input')),
              validator: (v) {
                final t = v?.trim().replaceAll(RegExp(r'\s'), '') ?? '';
                if (t.length < 6) return _t('phone_number_format_error');
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailField(BuildContext context) {
    return _inputBox(
      context: context,
      child: TextFormField(
        controller: _emailController,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
        decoration: _inputDecoration(context, _t('please_input_email')),
        validator: (v) {
          final email = v?.trim() ?? '';
          if (email.isEmpty) return _t('please_input_email');
          if (!email.contains('@')) return _t('email_format_error');
          return null;
        },
      ),
    );
  }

  Widget _codeField(BuildContext context) {
    return _inputBox(
      context: context,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: _CodePrefixIcon(),
          ),
          Expanded(
            child: TextFormField(
              controller: _codeController,
              focusNode: _codeFocus,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
              decoration: _inputDecoration(
                context,
                _acctKind == _LoginVercodeKind.email
                    ? _t('please_input_email_verify_code')
                    : _t('please_input_phone_verify_code'),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return _acctKind == _LoginVercodeKind.email
                      ? _t('please_input_email_verify_code')
                      : _t('please_input_phone_verify_code');
                }
                return null;
              },
            ),
          ),
          AuthSendCodeControl(
            onSend: _sendLoginCode,
            alignTop: false,
            label: _t('get_verification_code'),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _inputBox({required BuildContext context, required Widget child}) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AuthUi.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthUi.divider(context)),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 15, color: AuthUi.hint(context)),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: true,
    );
  }

  String _agreementIntroText() {
    final value = _t('have_read_and_agree');
    return value.endsWith(' ') ? value : '$value ';
  }
}

/// 验证码输入框左侧 "123" 图标（灰色圆角矩形背景）
class _CodePrefixIcon extends StatelessWidget {
  const _CodePrefixIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 20,
      decoration: BoxDecoration(
        color: AuthUi.cardBg(context),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '123',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AuthUi.labelSecondary(context),
        ),
      ),
    );
  }
}
