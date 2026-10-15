import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/st_service.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/router/policy_link_route.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/models/country_model.dart';
import '../../shared/widgets/st_action_refreshing_hud.dart';
import '../../shared/widgets/st_base_scaffold.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import 'auth_api_helpers.dart';
import 'auth_login_commit.dart';
import 'auth_oauth_flow.dart';
import 'auth_widgets.dart';
import 'auth_theme.dart';
import 'register_config.dart';

/// SharedPreferences key for privacy agreement (对齐 iOS `STUserInfoManger.isAgreePrivacy`)
const _kPrivacyAgreedKey = 'is_agree_privacy';

/// 读取本地持久化的协议同意状态
Future<bool> _loadPrivacyAgreed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPrivacyAgreedKey) ?? false;
}

/// 保存协议同意状态
Future<void> _savePrivacyAgreed(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPrivacyAgreedKey, value);
}

/// 登录页（对齐 Figma APP 白标 2.0 截图）
/// - 白底、无 AppBar 标题、右上角客服
/// - 大标题 + 邮箱/手机 切换
/// - 白色圆角输入框（淡灰边框）
/// - 浅绿胶囊登录按钮、绿色边框注册按钮
/// - 底部协议勾选 + 用户协议/隐私政策链接
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

enum _LoginAccountKind { phone, email }

class _LoginPageState extends ConsumerState<LoginPage> {
  static const Map<String, String> _fallbackText = {
    'password_login': '密码登录',
    'email': '邮箱',
    'phone': '手机',
    'otp_login': '验证码登录',
    'forget_the_password': '忘记密码？',
    'login': '登录',
    'no_account': '没有账号？',
    'go_register': '去注册',
    'have_read_and_agree': '我已阅读并同意',
    'phone_number_input': '请输入手机号码',
    'phone_number_format_error': '手机号格式不对',
    'please_input_email': '请输入邮箱',
    'email_format_error': '邮箱格式不正确',
    'password_input': '请输入密码',
    'password_error': '密码长度必须为5-15位',
    'user_agreement': '《用户协议》',
    'privacy_policy': '《隐私政策》',
    'and': '和',
    'or': '或',
    'requestfail': '数据加载失败',
    'flutter_prompt_oauth_sdk_required': '{provider} 登录需要接入对应 Flutter SDK 后完成',
    'flutter_prompt_address_not_configured': '{title}地址未配置',
  };

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  CountryModel _selectedCountry = CountryModel.china;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreed = false;
  _LoginAccountKind _acctKind = _LoginAccountKind.phone;
  String _telAreaCode = '+86';
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};
  RegisterUiState _oauthUi = RegisterUiState();

  void _onBackPressed() {
    context.popOrGoRoot();
  }

  @override
  void initState() {
    super.initState();
    _loadPrivacyAgreed().then((v) {
      if (mounted) setState(() => _agreed = v);
    });
    _phoneController.addListener(_updateButtonState);
    _emailController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(countryManagerProvider.notifier).ensureLoaded();
      if (!mounted) return;
      final selected = ref.read(effectiveSelectedCountryProvider);
      setState(() {
        _selectedCountry = selected;
        _telAreaCode = _selectedCountry.dialCode;
      });
      await _reloadOAuthConfigForCountry(selected.key);
    });
  }

  Future<void> _reloadOAuthConfigForCountry(String countryKey) async {
    try {
      final raw = await ref.read(stServiceProvider).getRegisterConfigList();
      AuthApiHelpers.ensureOk(raw);
      final data = AuthApiHelpers.unwrapLoginPayload(raw);
      final configs = data['configs'];
      if (configs is! List || !mounted) return;
      setState(() {
        _oauthUi = parseRegisterUiState(
          configs: configs,
          countryKey: countryKey,
          phoneFirstDefault: true,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _oauthUi = RegisterUiState());
      }
    }
  }

  CountryModel _currentCountryModel() {
    return CountryModel.fromDialCode(
          _telAreaCode,
          ref.read(countryManagerProvider).allCountries,
        ) ??
        _selectedCountry;
  }

  void _updateButtonState() {
    if (mounted) setState(() {});
  }

  bool get _canLogin {
    if (_acctKind == _LoginAccountKind.phone) {
      return _phoneController.text
                  .trim()
                  .replaceAll(RegExp(r'\s'), '')
                  .length >=
              6 &&
          _passwordController.text.length >= 6;
    }
    return _emailController.text.trim().contains('@') &&
        _passwordController.text.length >= 6;
  }

  static const Color _primaryGreen = Color(0xFF34C759);
  static const Color _lightGreen = Color(0xFFD1F2E1);

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
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAreaCode() async {
    final next = await showAuthAreaCodePicker(context, current: _telAreaCode);
    if (next == null || !mounted) return;
    final matched = CountryModel.fromDialCode(
      next,
      ref.read(countryManagerProvider).allCountries,
    );
    final country = matched ?? _selectedCountry;
    setState(() {
      _telAreaCode = next;
      _selectedCountry = country;
    });
    await _reloadOAuthConfigForCountry(country.key);
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
      late Map<String, dynamic> loginResult;

      if (_acctKind == _LoginAccountKind.phone) {
        final tel = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
        loginResult = await service.loginPhonePassword(
          telAreaCode: _telAreaCode,
          tel: tel,
          plainPassword: _passwordController.text,
        );
      } else {
        final email = _emailController.text.trim();
        loginResult = await service.loginEmailPassword(
          email: email,
          plainPassword: _passwordController.text,
        );
      }

      if (!mounted) return;
      await commitLoginSuccess(
        ref: ref,
        context: context,
        loginResult: loginResult,
        retryFailedRouter: false,
        successPopCount: 1,
      );
    } catch (e) {
      if (mounted) {
        showStLocalizedToast(context, AuthApiHelpers.userVisibleErrorSeed(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleOAuthTap() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await handleAppleOAuthFlow(
        ref: ref,
        context: context,
        countryKey: _selectedCountry.key,
        uiState: _oauthUi,
        retryFailedRouter: false,
        loginSuccessPopCount: 1,
      );
    } catch (e) {
      if (mounted) {
        showStLocalizedToast(context, AuthApiHelpers.userVisibleErrorSeed(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleUnavailableOAuthTap(String provider) {
    showStLocalizedToastByKey(
      context,
      'flutter_prompt_oauth_sdk_required',
      fallback: _fallbackText['flutter_prompt_oauth_sdk_required'],
      replacements: {'provider': provider},
    );
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
            onPressed: _onBackPressed,
          ),
          onBack: _onBackPressed,
          keyboardFocusNodes: _acctKind == _LoginAccountKind.phone
              ? [_phoneFocus, _passwordFocus]
              : [_emailFocus, _passwordFocus],
          actions: [
            IconButton(
              icon: Icon(
                Icons.headset_mic_outlined,
                size: 22,
                color: AuthUi.label(context),
              ),
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
                      _t('password_login'),
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
                          _acctKind == _LoginAccountKind.email,
                          () {
                            setState(() => _acctKind = _LoginAccountKind.email);
                          },
                        ),
                        const SizedBox(width: 32),
                        _kindTab(
                          context,
                          _t('phone'),
                          _acctKind == _LoginAccountKind.phone,
                          () {
                            setState(() => _acctKind = _LoginAccountKind.phone);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_acctKind == _LoginAccountKind.phone)
                      _phoneField(context)
                    else
                      _emailField(context),
                    const SizedBox(height: 16),
                    _passwordField(context),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/auth/login_with_code'),
                          child: Text(
                            _t('otp_login'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AuthUi.label(context),
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/auth/forgot_password'),
                          child: Text(
                            _t('forget_the_password'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AuthUi.label(context),
                            ),
                          ),
                        ),
                      ],
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
                            backgroundColor: _primaryGreen,
                            disabledBackgroundColor: _lightGreen,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AuthUi.cardBg(context),
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
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => context.push('/register'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AuthUi.label(context),
                            side: const BorderSide(color: _primaryGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: _t('no_account'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AuthUi.label(context),
                              ),
                              children: [
                                TextSpan(
                                  text: _t('go_register'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_oauthUi.showThirdLogin) ...[
                      const SizedBox(height: 24),
                      AuthRegisterThirdLoginBar(
                        showGoogle: _oauthUi.showGoogleOAuth,
                        showApple: _oauthUi.showAppleOAuth,
                        onGoogle: () => _handleUnavailableOAuthTap('Google'),
                        onApple: _handleAppleOAuthTap,
                        orLabel: _t('or'),
                      ),
                    ],
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
                                  ? Icon(
                                      Icons.check,
                                      size: 12,
                                      color: AuthUi.cardBg(context),
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

  Widget _emailField(BuildContext context) {
    return _inputBox(
      context: context,
      child: TextFormField(
        controller: _emailController,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
        autofillHints: const [AutofillHints.email],
        decoration: _inputDecoration(context, _t('please_input_email')),
        validator: (v) {
          final e = v?.trim() ?? '';
          if (e.isEmpty) return _t('please_input_email');
          if (!e.contains('@')) return _t('email_format_error');
          return null;
        },
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

  Widget _passwordField(BuildContext context) {
    return _inputBox(
      context: context,
      child: TextFormField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        obscureText: _obscurePassword,
        style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
        decoration: _inputDecoration(context, _t('password_input')).copyWith(
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.lock_outline,
              size: 20,
              color: AuthUi.labelSecondary(context),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: AuthUi.labelSecondary(context),
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return _t('password_input');
          if (v.length < 6) return _t('password_error');
          return null;
        },
      ),
    );
  }

  String _agreementIntroText() {
    final value = _t('have_read_and_agree');
    return value.endsWith(' ') ? value : '$value ';
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

  /// 对齐 iOS `STCommonPopView`：未勾选协议时弹出确认对话框
  Future<bool> _showPrivacyDialog() async {
    final agreed = await showAuthPrivacyConfirmDialog(context);
    if (agreed) {
      if (mounted) setState(() => _agreed = true);
      await _savePrivacyAgreed(true);
    }
    return agreed;
  }
}
