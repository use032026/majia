import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/router/customer_service_route.dart';
import '../../shared/auth/white_label_password_ui.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_captcha_dialog.dart';
import '../auth/auth_validators.dart';

enum _BindEmailStep { input, verify, success }

/// 绑定邮箱
/// 对齐 iOS `STBindEmailViewController` + `STInputVerCodeController`
/// 的绑定邮箱分支。
class BindEmailPage extends ConsumerStatefulWidget {
  const BindEmailPage({super.key});

  @override
  ConsumerState<BindEmailPage> createState() => _BindEmailPageState();
}

class _BindEmailPageState extends ConsumerState<BindEmailPage> {
  static const Map<String, String> _fallbackText = {
    'email_bind': '绑定邮箱',
    'please_input_email': '请输入邮箱',
    'email_format_error': '邮箱格式不正确',
    'next': '下一步',
    'email_verification': '邮箱验证',
    'verify_phone_or_email_to': '我们已将验证码发送至',
    'mail_code_tip': '。如果您未在收件箱内看到此验证码，请查看您的垃圾箱。',
    'verify_code_send_again': '重新发送',
    'verification_code_not_received': '未收到验证码？',
    'certain': '确定',
    'submitting': '提交中...',
    'warm_tips': '温馨提示',
    'mail_not_receive': '如长时间未收到验证码，请检查垃圾邮件。如仍未收到，可重试或联系客服。',
    'cancel': '关闭',
    'online_custom': '在线客服',
    'email_bind_success': '邮箱绑定成功',
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

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  _BindEmailStep _step = _BindEmailStep.input;
  bool _sendingCode = false;
  bool _submitting = false;
  int _resendSec = 0;
  int _resendRequestCount = 0;
  Timer? _resendTimer;
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

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim();

  void _showMessage(Object? message) {
    STToast.show(context, stSanitizeUserVisibleText(message?.toString() ?? ''));
  }

  void _ensureApiOk(Map<String, dynamic> raw, String fallback) {
    final c = raw['code'];
    final ok = c == 0 || c == '0' || (c is num && c == 0);
    if (!ok) {
      throw Exception(raw['message']?.toString() ?? fallback);
    }
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSec = seconds);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return {
      if (user.userId.isNotEmpty) 'id': user.userId,
      'nickName': user.nickname,
      'funds_password_status': user.isBindFundPassword ? '1' : '0',
      'ab': user.isB ? 'b' : 'a',
      'language_code': service.dio.currentLanguage,
      'token': user.token,
      'device_type': 'ios',
      'dark_mode': isDark ? '1' : '0',
      'timeZone': '${DateTime.now().timeZoneOffset.inHours}',
    };
  }

  Future<bool> _sendVerificationCode() async {
    if (_sendingCode || _resendSec > 0) return false;
    setState(() => _sendingCode = true);
    try {
      final service = ref.read(stServiceProvider);
      final h5 = ref.read(userStateProvider).h5AddressModel;
      final captchaUrl = (h5?.codeVerifyUrl.trim().isNotEmpty ?? false)
          ? h5!.codeVerifyUrl.trim()
          : 'localMini://codeverify';
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
      final raw = await service.requestEmailVerCode({
        'type': STService.emailVerCodeTypeBindEmail,
        'email': _email,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      _ensureApiOk(raw, _t('request_error'));
      if (!mounted) return true;
      _showMessage(_t('verification_code_sent_successfully'));
      _startResendCooldown();
      return true;
    } catch (e) {
      if (mounted) _showMessage(e);
      return false;
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _next() async {
    if (!AuthValidators.isEmailValid(_email)) {
      _showMessage(_t('email_format_error'));
      return;
    }
    setState(() {
      _step = _BindEmailStep.verify;
      _resendRequestCount = 0;
      _otpCtrl.clear();
    });
    await _sendVerificationCode();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  Future<void> _resend() async {
    if (_resendSec > 0 || _sendingCode) return;
    _resendRequestCount += 1;
    if (_resendRequestCount > 3) {
      _showMessage(_t('verify_code_error'));
      return;
    }
    await _sendVerificationCode();
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
          .bindEmail(email: _email, code: code);
      _ensureApiOk(raw, _t('request_error'));
      ref.read(userStateProvider.notifier).markEmailBound();
      if (mounted) setState(() => _step = _BindEmailStep.success);
    } catch (e) {
      if (mounted) _showMessage(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _cancel() => context.pop();

  void _back() {
    if (_step == _BindEmailStep.verify) {
      _resendTimer?.cancel();
      setState(() {
        _step = _BindEmailStep.input;
        _resendSec = 0;
        _otpCtrl.clear();
      });
      return;
    }
    context.pop();
  }

  Future<void> _handleCodeUnavailable() async {
    await showIosCommonAlertDialog(
      context: context,
      title: _t('warm_tips'),
      message: _t('mail_not_receive'),
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
      showCancel: _step != _BindEmailStep.success,
    );
  }

  Widget _inputStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('email_bind'),
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
                const Icon(
                  Icons.email_outlined,
                  size: 20,
                  color: Color(0xFF9A9DA2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: _t('please_input_email'),
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        color: _kPlaceholder,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_email.isNotEmpty) _next();
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
              onPressed: _email.isNotEmpty ? _next : null,
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
            _t('email_verification'),
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
                  text: _email,
                  style: const TextStyle(color: Colors.black),
                ),
                TextSpan(text: _t('mail_code_tip')),
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
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _t('verify_code_send_again'),
                      style: TextStyle(
                        fontSize: 14,
                        color: _resendSec > 0 ? _kMuted : _kPrimary,
                      ),
                    ),
                    if (_resendSec > 0)
                      TextSpan(
                        text: ' (${_resendSec}s)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: WhiteLabelAuthColors.timer,
                        ),
                      ),
                  ],
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
          const SizedBox(height: 25),
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
            _t('email_bind_success'),
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
    Widget body;
    switch (_step) {
      case _BindEmailStep.input:
        body = _inputStep();
      case _BindEmailStep.verify:
        body = _verifyStep();
      case _BindEmailStep.success:
        body = _successStep();
    }
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
