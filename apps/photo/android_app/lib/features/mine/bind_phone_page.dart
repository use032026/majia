import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/router/customer_service_route.dart';
import '../../shared/auth/white_label_password_ui.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_captcha_dialog.dart';
import '../auth/auth_validators.dart';

enum _BindPhoneStep { input, verify, success }

/// 绑定手机号（对齐 iOS `STBindPhoneController` + `STInputVerCodeController`）
class BindPhonePage extends ConsumerStatefulWidget {
  const BindPhonePage({super.key});

  @override
  ConsumerState<BindPhonePage> createState() => _BindPhonePageState();
}

class _BindPhonePageState extends ConsumerState<BindPhonePage> {
  static const Map<String, String> _fallbackText = {
    'phone_num_bind': '绑定手机号',
    'phone_number_input': '请输入手机号码',
    'phone_error': '手机号码不正确',
    'phone_size_error': '手机号码位数错误',
    'next': '下一步',
    'mobile_verification': '手机验证',
    'verify_phone_or_email_to': '我们已将验证码发送至',
    'phone_code_tip': '如长时间未收到，请联系在线客服。',
    'verify_code_send_again': '重新发送',
    'verification_code_not_received': '未收到验证码？',
    'certain': '确定',
    'submitting': '提交中...',
    'warm_tips': '温馨提示',
    'phone_not_receive': '请检查手机号填写及短信拦截、垃圾短信文件夹。',
    'cancel': '关闭',
    'online_custom': '在线客服',
    'phone_num_bind_success': '手机号绑定成功',
    'complete': '完成',
    'verification_code_sent_successfully': '验证码已发送',
    'verify_code_error': '请求过于频繁，请稍后再试',
    'error_vercode': '请输入6位验证码',
    'request_error': '请求出错，请联系客服',
  };
  static const Color _kPrimary = WhiteLabelAuthColors.primary;
  static const Color _kSubtitle = WhiteLabelAuthColors.subtitle;
  static const Color _kMuted = WhiteLabelAuthColors.muted;
  static const Color _kPlaceholder = WhiteLabelAuthColors.placeholder;
  static const Color _kSuccess = Color(0xFF1BCC83);

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  _BindPhoneStep _step = _BindPhoneStep.input;
  bool _sendingCode = false;
  bool _submitting = false;
  int _resendSec = 0;
  int _resendRequestCount = 0;
  Timer? _resendTimer;

  String _areaCode = '+86';
  String? _localizedLanguageCode;
  Map<String, String> _localized = _fallbackText;

  void _ensureLocalizedText() {
    final localizations = ref.watch(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  AuthValidatorMessages get _validatorMessages =>
      AuthValidatorMessages.fromMap(_localized);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(countryManagerProvider.notifier).ensureLoaded();
      if (!mounted) return;
      setState(() {
        _areaCode = ref.read(effectiveSelectedCountryProvider).dialCode;
      });
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _phone => _phoneCtrl.text.trim();

  static void _ensureApiOk(Map<String, dynamic> raw, String fallback) {
    final c = raw['code'];
    final ok = c == 0 || c == '0' || (c is num && c == 0);
    if (!ok) {
      throw Exception(raw['message']?.toString() ?? fallback);
    }
  }

  String _maskPhoneForDisplay() {
    final digits = _phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return '(${_areaCode.replaceAll('+', '')}) $digits';
    final head = digits.substring(0, digits.length - 6);
    final tail = digits.substring(digits.length - 3);
    final ac = _areaCode.replaceAll('+', '');
    return '($ac) $head****$tail';
  }

  String _flagEmoji(String areaCode) {
    switch (areaCode.trim()) {
      case '+86':
        return '🇨🇳';
      case '+852':
        return '🇭🇰';
      case '+1':
        return '🇺🇸';
      case '+44':
        return '🇬🇧';
      case '+65':
        return '🇸🇬';
      default:
        return '🌐';
    }
  }

  void _startResendCooldown([int sec = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSec = sec);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSec <= 1) {
        timer.cancel();
        setState(() => _resendSec = 0);
      } else {
        setState(() => _resendSec -= 1);
      }
    });
  }

  Future<Map<String, dynamic>> _captchaBridgeUserInfo(STService service) async {
    final user = ref.read(userStateProvider);
    return {
      if (user.userId.isNotEmpty) 'id': user.userId,
      'nickName': user.nickname,
      'funds_password_status': user.isBindFundPassword ? '1' : '0',
      'ab': user.isB ? 'b' : 'a',
      'language_code': service.dio.currentLanguage,
      'token': user.token,
      'device_type': 'ios',
      'dark_mode': Theme.of(context).brightness == Brightness.dark ? '1' : '0',
      'timeZone': '${DateTime.now().timeZoneOffset.inHours}',
    };
  }

  void _showMessage(Object? message) {
    STToast.show(context, stSanitizeUserVisibleText(message?.toString() ?? ''));
  }

  Future<bool> _sendVerificationCode() async {
    if (_sendingCode || _resendSec > 0) return false;
    final err = AuthValidators.phoneError(
      _phone,
      _areaCode,
      messages: _validatorMessages,
    );
    if (err != null) {
      _showMessage(err);
      return false;
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
      final raw = await service.requestSmsVerCode({
        'type': STService.smsVerCodeTypeBindPhone,
        'tel': _phone.replaceAll(RegExp(r'\D'), ''),
        'tel_area_code': _areaCode,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      _ensureApiOk(raw, _t('request_error'));
      if (!mounted) return false;
      _showMessage(_t('verification_code_sent_successfully'));
      _startResendCooldown(60);
      return true;
    } catch (e) {
      if (mounted) {
        _showMessage(e);
      }
      return false;
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _next() async {
    final err = AuthValidators.phoneError(
      _phone,
      _areaCode,
      messages: _validatorMessages,
    );
    if (err != null) {
      _showMessage(err);
      return;
    }
    final ok = await _sendVerificationCode();
    if (!ok) return;
    setState(() {
      _step = _BindPhoneStep.verify;
      _resendRequestCount = 0;
      _otpCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  Future<bool> _resend() async {
    if (_resendSec > 0 || _sendingCode) return false;
    _resendRequestCount += 1;
    if (_resendRequestCount > 3) {
      _showMessage(_t('verify_code_error'));
      return false;
    }
    return _sendVerificationCode();
  }

  Future<void> _submit() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      _showMessage(_t('error_vercode'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final raw = await ref
          .read(stServiceProvider)
          .bindPhone(
            code: code,
            areaCode: _areaCode,
            tel: _phone.replaceAll(RegExp(r'\D'), ''),
          );
      _ensureApiOk(raw, _t('request_error'));
      ref.read(userStateProvider.notifier).markPhoneBound();
      if (mounted) setState(() => _step = _BindPhoneStep.success);
    } catch (e) {
      if (mounted) {
        _showMessage(e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _cancel() => context.pop();

  void _back() {
    if (_step == _BindPhoneStep.verify) {
      _resendTimer?.cancel();
      _resendTimer = null;
      _resendSec = 0;
      setState(() => _step = _BindPhoneStep.input);
      return;
    }
    context.pop();
  }

  Future<void> _handleCodeUnavailable() async {
    await showIosCommonAlertDialog(
      context: context,
      title: _t('warm_tips'),
      message: _t('phone_not_receive'),
      cancelText: _t('cancel'),
      confirmText: _t('online_custom'),
      confirmTextColor: _kPrimary,
      onConfirm: () => CustomerServiceRoute.open(context, ref),
    );
  }

  Widget _topBar() {
    return WhiteLabelAuthTopBar(
      onBack: _back,
      onCancel: _cancel,
      showCancel: _step != _BindPhoneStep.success,
    );
  }

  Widget _inputStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('phone_num_bind'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 27),
          WhiteLabelFieldBox(
            child: Row(
              children: [
                Row(
                  children: [
                    Text(
                      _flagEmoji(_areaCode),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _areaCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Text(
                  '|',
                  style: TextStyle(color: WhiteLabelAuthColors.placeholder),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: _t('phone_number_input'),
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        color: _kPlaceholder,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_phone.isNotEmpty) _next();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 55),
          Center(
            child: WhiteLabelPillButton(
              label: _t('next'),
              onPressed: _phone.isEmpty ? null : _next,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verifyStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('mobile_verification'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${_t('verify_phone_or_email_to')}\n'),
                TextSpan(
                  text: _maskPhoneForDisplay(),
                  style: const TextStyle(color: Colors.black),
                ),
                TextSpan(text: '\n${_t('phone_code_tip')}'),
              ],
            ),
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: _kSubtitle,
            ),
          ),
          const SizedBox(height: 40),
          WhiteLabelOtpInput(
            controller: _otpCtrl,
            focusNode: _otpFocus,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 25),
          Center(
            child: GestureDetector(
              onTap: (_resendSec == 0 && !_sendingCode) ? _resend : null,
              child: Text(
                _resendSec > 0
                    ? '${_t('verify_code_send_again')} (${_resendSec}s)'
                    : _t('verify_code_send_again'),
                style: TextStyle(
                  fontSize: 14,
                  color: _resendSec > 0 ? _kMuted : _kPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 35),
          Center(
            child: WhiteLabelPillButton(
              label: _submitting ? _t('submitting') : _t('certain'),
              onPressed: (_submitting || _otpCtrl.text.trim().length != 6)
                  ? null
                  : _submit,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => unawaited(_handleCodeUnavailable()),
              child: Text(
                _t('verification_code_not_received'),
                style: const TextStyle(fontSize: 14, color: _kPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successStep() {
    return Column(
      children: [
        const SizedBox(height: 14),
        const Icon(Icons.check_circle, size: 54, color: _kSuccess),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            _t('phone_num_bind_success'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _kSuccess,
            ),
          ),
        ),
        const SizedBox(height: 174),
        WhiteLabelPillButton(
          label: _t('complete'),
          width: 128,
          height: 34,
          onPressed: () => context.pop(true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final body = switch (_step) {
      _BindPhoneStep.input => _inputStep(),
      _BindPhoneStep.verify => _verifyStep(),
      _BindPhoneStep.success => _successStep(),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
