import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/models/country_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/device_id_manager.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/verification/verification_code_cooldown.dart';
import '../../shared/auth/white_label_password_ui.dart';
import '../../shared/widgets/st_toast.dart';
import 'auth_api_helpers.dart';
import 'auth_captcha_dialog.dart';
import 'auth_widgets.dart';

enum _ForgotStep { contact, verify, reset, success }

/// 找回登录密码（Figma：找回密码第一步 → 验证 → 重设登录密码 → 完成）
class ForgotLoginPasswordPage extends ConsumerStatefulWidget {
  const ForgotLoginPasswordPage({super.key});

  @override
  ConsumerState<ForgotLoginPasswordPage> createState() =>
      _ForgotLoginPasswordPageState();
}

class _ForgotLoginPasswordPageState
    extends ConsumerState<ForgotLoginPasswordPage> {
  static const Map<String, String> _fallbackText = {
    'retrieve_password': '忘记密码？',
    'phone_forget': '手机找回',
    'email_forget': '邮箱找回',
    'phone_number_input': '请输入手机号码',
    'please_input_email': '请输入邮箱',
    'phone_number_format_error': '手机号格式不对',
    'email_format_error': '邮箱格式不正确',
    'send_verification_code_success': '验证码已发送',
    'please_input_code': '请输入验证码',
    'error_vercode': '请输入正确的验证码',
    'verify_phone_or_email': '手机/邮箱验证',
    'verify_phone_or_email_tips': '验证码已发送至您的手机/邮箱，有效期10分钟。',
    'mobile_verification': '手机验证',
    'email_verification': '邮箱验证',
    'verify_phone_or_email_to': '我们已将验证码发送至',
    'phone_code_tip': '如长时间未收到，请联系在线客服。',
    'mail_code_tip': '。如果您未在收件箱内看到此验证码，请查看您的垃圾箱。',
    'verify_phone_or_email_again': '重新发送',
    'verification_code_not_received': '没收到验证码？',
    'reset_password': '重设密码',
    'set_pwd': '设置密码',
    'set_pwd_tip_phone': '设置密码后可以通过手机号+密码登录',
    'set_pwd_tip_mail': '设置密码后可以通过邮箱+密码登录',
    'new_password_input': '新密码',
    'confirm_password_input': '确认新密码',
    'password_error_format_tips': '密码必须是5~15位英文字母、数字组合',
    'password_not_same': '两次输入的密码不一致。',
    'password_reset_success': '密码重置成功',
    'password_reset_success_tips': '请牢记您的新密码，并重新登录。',
    'system_busy': '系统繁忙，请稍后再试',
    'next': '下一步',
    'confirm': '确定',
    'complete': '完成',
    'cancel': '取消',
    'submit': '提交',
  };

  _ForgotStep _step = _ForgotStep.contact;
  bool _phoneMode = true;

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  String _areaCode = '+86';
  CountryModel _selectedCountry = CountryModel.china;

  int _resendSec = 0;
  Timer? _resendTimer;
  bool _sendingCode = false;
  bool _validatingCode = false;
  bool _submitting = false;
  int _requestVercodeCount = 0;
  String _vcodeId = '';

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  /// Figma「找回密码完成」节点 74628：标题/勾选主色。
  static const Color _kForgotDoneGreen = Color(0xFF1BCC83);

  void _otpL() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _otpFocus.addListener(_otpL);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(countryManagerProvider.notifier).ensureLoaded();
      if (!mounted) return;
      setState(() {
        _selectedCountry = ref.read(effectiveSelectedCountryProvider);
        _areaCode = _selectedCountry.dialCode;
      });
    });
  }

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
    _resendTimer?.cancel();
    _otpFocus.removeListener(_otpL);
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  CountryModel _currentCountryModel() {
    return CountryModel.fromDialCode(
          _areaCode,
          ref.read(countryManagerProvider).allCountries,
        ) ??
        _selectedCountry;
  }

  Future<void> _pickAreaCode() async {
    final next = await showAuthAreaCodePicker(context, current: _areaCode);
    if (next == null || !mounted) return;
    final matched = CountryModel.fromDialCode(
      next,
      ref.read(countryManagerProvider).allCountries,
    );
    setState(() {
      _areaCode = next;
      _selectedCountry = matched ?? _selectedCountry;
    });
  }

  void _ensureApiOk(Map<String, dynamic> raw) {
    final c = raw['code'];
    final ok = c == 0 || c == '0' || (c is num && c == 0);
    if (!ok) {
      throw Exception(raw['message']?.toString() ?? _t('system_busy'));
    }
  }

  String _maskPhoneDisplay() {
    final raw = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length < 7) return '(${_areaCode.replaceAll('+', '')}) $raw';
    final head = raw.substring(0, raw.length - 6);
    final tail = raw.substring(raw.length - 3);
    final ac = _areaCode.replaceAll('+', '');
    return '($ac) $head****$tail';
  }

  String _maskEmailDisplay() {
    final email = _emailCtrl.text.trim();
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email.substring(0, 2)}***${email.substring(at)}';
  }

  void _runResendTimer(int sec) {
    _resendTimer?.cancel();
    setState(() => _resendSec = sec);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSec <= 1) {
        t.cancel();
        setState(() => _resendSec = 0);
      } else {
        setState(() => _resendSec -= 1);
      }
    });
  }

  void _startResend([int sec = 60]) {
    ref.read(verificationCodeCooldownProvider.notifier).start(sec);
    _runResendTimer(sec);
  }

  bool _restoreResendIfActive() {
    final remaining = ref
        .read(verificationCodeCooldownProvider)
        .remainingSeconds();
    if (remaining <= 0) return false;
    _runResendTimer(remaining);
    return true;
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

  Future<bool> _sendVerificationCode({bool fromResend = false}) async {
    if (_sendingCode || _resendSec > 0) return false;
    if (_restoreResendIfActive()) return false;
    if (fromResend) {
      _requestVercodeCount++;
      if (_requestVercodeCount > 3) {
        STToast.show(context, _t('error_vercode'));
        return false;
      }
    }
    setState(() => _sendingCode = true);
    try {
      final service = ref.read(stServiceProvider);
      final h5 = ref.read(userStateProvider).h5AddressModel;
      final configuredCaptchaUrl = h5?.codeVerifyUrl.trim() ?? '';
      final captchaUrl = configuredCaptchaUrl.isEmpty
          ? 'localMini://codeverify'
          : configuredCaptchaUrl;
      final bridgeUserInfo = await _captchaBridgeUserInfo(service);
      if (!mounted) return false;
      final captcha = await ref.read(authCaptchaDialogProvider)(
        context,
        url: captchaUrl,
        baseHost: service.dio.baseUrl.replaceFirst(RegExp(r'/violet/?$'), ''),
        captchaApiKey: h5?.captchaApiKey ?? '',
        bridgeUserInfo: bridgeUserInfo,
      );
      if (captcha == null) return false;
      if (_phoneMode) {
        final raw = await service.requestSmsVerCode({
          'type': STService.smsTypeForgotLoginPassword,
          'tel': _phoneCtrl.text.replaceAll(RegExp(r'\D'), ''),
          'tel_area_code': _areaCode,
          'captcha_id': '${captcha['id'] ?? ''}',
          'captcha_key': '${captcha['captchaKey'] ?? ''}',
          'captcha_value': '${captcha['value'] ?? ''}',
        });
        _ensureApiOk(raw);
        final data = AuthApiHelpers.unwrapLoginPayload(raw);
        _vcodeId = '${data['vcode_id'] ?? ''}';
      } else {
        final raw = await service.requestEmailVerCode({
          'type': STService.emailTypeForgotLoginPassword,
          'email': _emailCtrl.text.trim(),
          'captcha_id': '${captcha['id'] ?? ''}',
          'captcha_key': '${captcha['captchaKey'] ?? ''}',
          'captcha_value': '${captcha['value'] ?? ''}',
        });
        _ensureApiOk(raw);
        final data = AuthApiHelpers.unwrapLoginPayload(raw);
        _vcodeId = '${data['vcode_id'] ?? ''}';
      }
      if (mounted) {
        STToast.show(context, _t('send_verification_code_success'));
        _startResend(60);
      }
      return true;
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  bool _contactValid() {
    if (_phoneMode) {
      return _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length >= 6;
    }
    return _emailCtrl.text.contains('@');
  }

  Future<void> _goVerify() async {
    if (!_contactValid()) {
      STToast.show(
        context,
        _phoneMode ? _t('phone_number_format_error') : _t('email_format_error'),
      );
      return;
    }
    setState(() {
      _step = _ForgotStep.verify;
      _requestVercodeCount = 0;
      _vcodeId = '';
    });
    _otpCtrl.clear();
    await _sendVerificationCode();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.requestFocus();
      });
    }
  }

  Future<void> _confirmOtp() async {
    if (_otpCtrl.text.length != 6) {
      STToast.show(context, _t('please_input_code'));
      return;
    }
    setState(() => _validatingCode = true);
    try {
      final service = ref.read(stServiceProvider);
      final tel = _phoneMode
          ? _phoneCtrl.text.replaceAll(RegExp(r'\D'), '')
          : '';
      final mail = _phoneMode ? '' : _emailCtrl.text.trim();
      final raw = await service.validateForgotPasswordCode(
        code: _otpCtrl.text.trim(),
        vcodeId: _vcodeId,
        areaCode: _phoneMode ? _areaCode : '',
        phone: tel,
        mail: mail,
        type: _phoneMode ? '1' : '2',
      );
      _ensureApiOk(raw);
      if (mounted) setState(() => _step = _ForgotStep.reset);
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _validatingCode = false);
    }
  }

  bool _pwdOk(String s) =>
      s.length >= 5 &&
      s.length <= 15 &&
      RegExp(r'[A-Za-z]').hasMatch(s) &&
      RegExp(r'[0-9]').hasMatch(s);

  Future<void> _submitNewPassword() async {
    if (!_pwdOk(_newCtrl.text)) {
      STToast.show(context, _t('password_error_format_tips'));
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      STToast.show(context, _t('password_not_same'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = ref.read(stServiceProvider);
      final tel = _phoneMode
          ? _phoneCtrl.text.replaceAll(RegExp(r'\D'), '')
          : null;
      final email = !_phoneMode ? _emailCtrl.text.trim() : null;
      await service.resetLoginPasswordWithVerificationCode(
        verificationCode: _otpCtrl.text.trim(),
        newPlainPassword: _newCtrl.text,
        confirmPlainPassword: _confirmCtrl.text,
        tel: tel,
        telAreaCode: _areaCode,
        email: email,
      );
      if (mounted) setState(() => _step = _ForgotStep.success);
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onBack() {
    switch (_step) {
      case _ForgotStep.contact:
        context.pop();
        break;
      case _ForgotStep.verify:
        setState(() {
          _step = _ForgotStep.contact;
          _resendTimer?.cancel();
          _resendSec = 0;
          _validatingCode = false;
          _otpCtrl.clear();
        });
        break;
      case _ForgotStep.reset:
        setState(() => _step = _ForgotStep.verify);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocus.requestFocus();
        });
        break;
      case _ForgotStep.success:
        context.go('/login');
        break;
    }
  }

  void _onCancel() {
    if (_step == _ForgotStep.success) {
      context.go('/login');
      return;
    }
    context.pop();
  }

  Widget _buildContact() {
    final country = _currentCountryModel();
    return SingleChildScrollView(
      // Figma 2175:74813 正文左右 15
      padding: const EdgeInsets.symmetric(horizontal: 15),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('retrieve_password'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          // 标题 y≈148 与 Tabs：约 76−标题行高（稿面全局坐标含状态栏，此处按比例）
          const SizedBox(height: 44),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _phoneMode = true),
                child: Text(
                  _t('phone_forget'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: _phoneMode
                        ? const Color(0xFF0B1023)
                        : WhiteLabelAuthColors.inactiveTab,
                  ),
                ),
              ),
              const SizedBox(width: 26),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _phoneMode = false),
                child: Text(
                  _t('email_forget'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: !_phoneMode
                        ? const Color(0xFF0B1023)
                        : WhiteLabelAuthColors.inactiveTab,
                  ),
                ),
              ),
            ],
          ),
          // Tabs y148 → 输入框顶 y186 ≈38px（含文案行）
          const SizedBox(height: 16),
          if (_phoneMode)
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.black),
              ),
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  AuthLoginAreaCodePrefix(
                    dialCode: _areaCode,
                    flagUrl: country.flagUrl,
                    flagEmoji: country.flagEmoji,
                    onTap: _pickAreaCode,
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    color: WhiteLabelAuthColors.border,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: _t('phone_number_input'),
                        hintStyle: TextStyle(
                          color: WhiteLabelAuthColors.placeholder,
                          fontSize: 15,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.black),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: _ForgotEmailField(
                controller: _emailCtrl,
                hintText: _t('please_input_email'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          // 输入框底 y236 →「下一步」顶 y346 ≈110
          const SizedBox(height: 110),
          Center(
            child: WhiteLabelPillButton(
              label: _t('next'),
              onPressed: _contactValid() ? _goVerify : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerify() {
    final target = _phoneMode ? _maskPhoneDisplay() : _maskEmailDisplay();
    final title = _phoneMode
        ? _t('mobile_verification')
        : _t('email_verification');
    final tip = _phoneMode ? _t('phone_code_tip') : _t('mail_code_tip');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.5),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          // 2175:74456 标题 → 灰字说明 y72→105≈21px
          const SizedBox(height: 21),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('verify_phone_or_email_to'),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: WhiteLabelAuthColors.muted,
                ),
              ),
              Text(
                target,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  height: 1.35,
                ),
              ),
              Text(
                tip,
                style: const TextStyle(
                  fontSize: 12,
                  color: WhiteLabelAuthColors.subtitle,
                  height: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          WhiteLabelOtpInput(
            controller: _otpCtrl,
            focusNode: _otpFocus,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 43),
          Center(
            child: GestureDetector(
              onTap: (_resendSec == 0 && !_sendingCode)
                  ? () => _sendVerificationCode(fromResend: true)
                  : null,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _t('verify_phone_or_email_again'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _resendSec > 0
                            ? const Color(0xFFD9D9D9)
                            : WhiteLabelAuthColors.primary,
                      ),
                    ),
                    if (_resendSec > 0)
                      TextSpan(
                        text: ' (${_resendSec}s)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: WhiteLabelAuthColors.timer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: SizedBox(
              width: 191,
              height: 48,
              child: ElevatedButton(
                onPressed: (_otpCtrl.text.length == 6 && !_validatingCode)
                    ? _confirmOtp
                    : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: WhiteLabelAuthColors.primary,
                  disabledBackgroundColor: WhiteLabelAuthColors.primary
                      .withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(31),
                  ),
                ),
                child: Text(
                  _validatingCode ? '${_t('confirm')}...' : _t('confirm'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: WhiteLabelAuthColors.primary,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                STToast.show(context, _t('verification_code_not_received'));
              },
              child: Text(
                _t('verification_code_not_received'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: WhiteLabelAuthColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _ruleIconForgot(bool ok) {
    return Icon(
      ok ? Icons.check_circle : Icons.circle_outlined,
      size: 16,
      color: ok ? WhiteLabelAuthColors.success : const Color(0xFFD9D9D9),
    );
  }

  Widget _buildReset() {
    final n = _newCtrl.text;
    bool lenOk(String s) => s.length >= 5 && s.length <= 15;
    final letterOk = RegExp(r'[A-Za-z]').hasMatch(n);
    final digitOk = RegExp(r'[0-9]').hasMatch(n);
    final subtitle = _phoneMode
        ? _t('set_pwd_tip_phone')
        : _t('set_pwd_tip_mail');
    return SingleChildScrollView(
      // Figma 2175:74758 左右 15
      padding: const EdgeInsets.symmetric(horizontal: 15),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('set_pwd'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          // y72→106 副标题约10px
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: WhiteLabelAuthColors.subtitle,
              height: 1.35,
            ),
          ),
          // y106→首个输入框顶 y167
          const SizedBox(height: 48),
          WhiteLabelFieldBox(
            suffix: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: Colors.black.withValues(alpha: 0.42),
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            child: TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _t('new_password_input'),
                hintStyle: TextStyle(
                  color: WhiteLabelAuthColors.placeholder,
                  fontSize: 15,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          WhiteLabelFieldBox(
            suffix: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: Colors.black.withValues(alpha: 0.42),
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            child: TextField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _t('confirm_password_input'),
                hintStyle: TextStyle(
                  color: WhiteLabelAuthColors.placeholder,
                  fontSize: 15,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (n.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _ruleIconForgot(lenOk(n)),
                    const SizedBox(height: 8),
                    _ruleIconForgot(letterOk),
                    const SizedBox(height: 8),
                    _ruleIconForgot(digitOk),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('password_error_format_tips'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 24 / 12,
                      color: WhiteLabelAuthColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // 规则区底→「提交」按钮顶 y443−369≈74
          SizedBox(height: n.isNotEmpty ? 68 : 164),
          Center(
            child: WhiteLabelPillButton(
              label: _t('submit'),
              onPressed: _submitting
                  ? null
                  : () {
                      if (!_pwdOk(_newCtrl.text) ||
                          _newCtrl.text != _confirmCtrl.text) {
                        STToast.show(context, _t('password_error_format_tips'));
                        return;
                      }
                      _submitNewPassword();
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _kForgotDoneGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_rounded,
                size: 34,
                color: _kForgotDoneGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _t('password_reset_success'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kForgotDoneGreen,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            _t('password_reset_success_tips'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF343434),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 146),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 128, maxWidth: 260),
              child: SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: WhiteLabelAuthColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    _t('complete'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPopContact = _step == _ForgotStep.contact;
    return PopScope(
      canPop: canPopContact,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WhiteLabelAuthTopBar(
                onBack: _onBack,
                onCancel: _onCancel,
                showCancel: _step != _ForgotStep.success,
                cancelText: _t('cancel'),
              ),
              Expanded(
                child: switch (_step) {
                  _ForgotStep.contact => _buildContact(),
                  _ForgotStep.verify => _buildVerify(),
                  _ForgotStep.reset => _buildReset(),
                  _ForgotStep.success => _buildSuccess(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgotEmailField extends StatefulWidget {
  const _ForgotEmailField({
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;

  static const _suffixes = [
    '@gmail.com',
    '@outlook.com',
    '@yahoo.com',
    '@hotmail.com',
    '@icloud.com',
  ];

  @override
  State<_ForgotEmailField> createState() => _ForgotEmailFieldState();
}

class _ForgotEmailFieldState extends State<_ForgotEmailField> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  List<String> _suggestions(String text) {
    if (text.isEmpty) return const [];
    final at = text.indexOf('@');
    final matched = at >= 0 ? text.substring(at) : '';
    final prefix = matched.isEmpty ? text : text.replaceAll(matched, '');
    return [
      for (final suffix in _ForgotEmailField._suffixes)
        if (matched.isEmpty || suffix.contains(matched)) '$prefix$suffix',
    ];
  }

  void _syncOverlay(String text) {
    final items = _suggestions(text);
    if (items.isEmpty) {
      _removeOverlay();
      return;
    }
    _showOverlay(items);
  }

  void _showOverlay(List<String> items) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 50),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: MediaQuery.sizeOf(ctx).width - 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      children: List.generate(items.length, (index) {
                        final value = items[index];
                        final isLast = index == items.length - 1;
                        return InkWell(
                          onTap: () {
                            widget.controller.text = value;
                            widget.controller.selection =
                                TextSelection.collapsed(offset: value.length);
                            _removeOverlay();
                            widget.onChanged?.call(value);
                          },
                          child: Container(
                            height: 34,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : const Border(
                                      bottom: BorderSide(
                                        color: WhiteLabelAuthColors.border,
                                      ),
                                    ),
                            ),
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
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
      child: TextField(
        controller: widget.controller,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(fontSize: 15),
        onTapOutside: (_) => _removeOverlay(),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: WhiteLabelAuthColors.placeholder,
            fontSize: 15,
          ),
        ),
        onChanged: (value) {
          _syncOverlay(value);
          widget.onChanged?.call(value);
        },
      ),
    );
  }
}
