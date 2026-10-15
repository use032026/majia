import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:jufu/core/models/user_state.dart' as user_state;
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/services/ios_logout_flow.dart';
import '../../core/verification/verification_code_cooldown.dart';
import '../../shared/widgets/auth_popups.dart';
import '../../shared/auth/white_label_password_ui.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_captcha_dialog.dart';

/// 修改登录密码（应用内「修改自己密码」）。
/// - 第一步：2175:74650 版式（标题下无灰色说明文案，三输入框 + 规则条 + 「下一步」）；
/// - 完成态：2175:74590 成功色 `#1bcc83`、灰副文案 `#60656d`（文案仍为「密码重置成功」登录场景）。
enum _ChangePwdStep { oldPassword, verifyForgot, reset, success }

class _LoginPasswordText {
  const _LoginPasswordText._();

  static const fallback = <String, String>{
    'cancel': '取消',
    'reset_password': '重设密码',
    'input_old_password': '请输入原密码',
    'next': '下一步',
    'forget_the_password': '忘记密码？',
    'new_password_hint': '请输入新密码',
    'confirm_password_input': '确认新密码',
    'password_rule_tip': '5~15个字符\n至少一个字母\n至少一个数字字符',
    'password_rule_error': '请按规则设置新密码',
    'password_not_match': '两次新密码输入不一致',
    'old_password_error': '当前密码错误。',
    'error_vercode': '请输入正确的验证码',
    'verification_code_sent_successfully': '验证码已发送',
    'please_input_code': '请输入验证码',
    'certain': '确定',
    'confirm': '确认',
    'verify_phone_or_email': '手机/邮箱验证',
    'mobile_verification': '手机验证',
    'email_verification': '邮箱验证',
    'verification_code_sent_to_mobile': '验证码已发送至你的手机，10分钟有效',
    'verification_code_sent_to_email': '验证码已发送至你的邮箱，10分钟有效',
    'verification_code_sent_to_prefix': '验证码已发送至',
    'verify_code_send_again': '重新发送',
    'warm_tips': '温馨提示',
    'phone_not_receive': '请检查手机号填写及短信拦截、垃圾短信文件夹。',
    'mail_not_receive': '如长时间未收到验证码，请检查垃圾邮件。如仍未收到，可重试或联系客服。',
    'verification_code_not_received': '未收到验证码？',
    'online_custom': '在线客服',
    'password_reset_success': '密码重置成功',
    'password_reset_success_tips': '请记住新密码并重新登录',
    'complete': '完成',
  };
}

class ChangeLoginPasswordPage extends ConsumerStatefulWidget {
  const ChangeLoginPasswordPage({super.key});

  @override
  ConsumerState<ChangeLoginPasswordPage> createState() =>
      _ChangeLoginPasswordPageState();
}

class _ChangeLoginPasswordPageState
    extends ConsumerState<ChangeLoginPasswordPage> {
  static const Color _kBorder = WhiteLabelAuthColors.border;
  static const Color _kPrimary = WhiteLabelAuthColors.primary;
  static const Color _kSubtitle = WhiteLabelAuthColors.subtitle;
  static const Color _kPlaceholder = WhiteLabelAuthColors.placeholder;
  static const Color _kCancel = WhiteLabelAuthColors.cancel;
  static const Color _kSuccess = WhiteLabelAuthColors.success;

  /// Figma 2175:74590「重设(或找回)资金密码完成」同款成功主色（本页用于登录密码完成态）
  static const Color _kDoneGreen = Color(0xFF1BCC83);

  _ChangePwdStep _step = _ChangePwdStep.oldPassword;

  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _checkingOldPassword = false;
  bool _sendingCode = false;
  bool _validatingCode = false;
  int _resendSec = 0;
  int _requestVercodeCount = 0;
  Timer? _resendTimer;
  String _forgotVerificationCode = '';
  bool _forgotContactIsPhone = false;
  String _forgotPhone = '';
  String _forgotAreaCode = '';
  String _forgotEmail = '';
  Map<String, String> _localized = _LoginPasswordText.fallback;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  bool _ruleLengthOk(String s) => s.length >= 5 && s.length <= 15;
  bool _ruleLetterOk(String s) => RegExp(r'[A-Za-z]').hasMatch(s);
  bool _ruleDigitOk(String s) => RegExp(r'[0-9]').hasMatch(s);

  bool _newPasswordValid(String s) =>
      _ruleLengthOk(s) && _ruleLetterOk(s) && _ruleDigitOk(s);

  void _ensureLocalizedText() {
    final localizations = ref.watch(stLocalizationsProvider);
    localizations.textMap(_LoginPasswordText.fallback).then((entries) {
      if (!mounted) return;
      if (identical(entries, _localized)) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _LoginPasswordText.fallback[key] ?? key;

  String? _oldPasswordError() {
    if (_oldCtrl.text.isEmpty) return _t('input_old_password');
    return null;
  }

  String? _resetFormError() {
    if (!_newPasswordValid(_newCtrl.text)) return _t('password_rule_error');
    if (_newCtrl.text != _confirmCtrl.text) return _t('password_not_match');
    return null;
  }

  Future<bool> _isOldLoginPasswordValid() async {
    try {
      final service = ref.read(stServiceProvider);
      final same = await service.checkLoginPasswordSame(
        oldPlainPassword: _oldCtrl.text,
      );
      if (!same && mounted) {
        STToast.show(context, _t('old_password_error'));
      }
      return same;
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
      return false;
    }
  }

  Future<bool> _ensureCanResetLoginPasswordWithVercode() async {
    final userState = ref.read(user_state.userStateProvider);
    if (userState.isBindEmail || userState.isBindPhone) return true;

    final shouldContinue = await showAuthGuideSheet(context: context);
    if (!mounted) return false;
    if (shouldContinue == true) {
      context.push('/mine/auth');
    }
    return false;
  }

  Future<void> _openForgotPassword() async {
    if (!mounted) return;
    final passed = await _ensureCanResetLoginPasswordWithVercode();
    if (!passed || !mounted) return;
    final userState = ref.read(user_state.userStateProvider);
    _forgotEmail = userState.email.trim();
    _forgotPhone = userState.phone.trim();
    _forgotAreaCode = userState.phoneAreaCode.trim();
    _forgotContactIsPhone = _forgotEmail.isEmpty;
    _forgotVerificationCode = '';
    _otpCtrl.clear();
    _requestVercodeCount = 0;
    setState(() => _step = _ChangePwdStep.verifyForgot);
    await _sendForgotVerificationCode();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  bool get _isForgotReset => _forgotVerificationCode.isNotEmpty;

  String get _forgotTargetDisplay {
    if (_forgotContactIsPhone) {
      final digits = _forgotPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7) {
        return '(${_forgotAreaCode.replaceAll('+', '')}) $digits';
      }
      final head = digits.substring(0, digits.length - 6);
      final tail = digits.substring(digits.length - 3);
      final ac = _forgotAreaCode.replaceAll('+', '');
      return ac.isEmpty ? '$head****$tail' : '($ac) $head****$tail';
    }
    final at = _forgotEmail.indexOf('@');
    if (at <= 1) return _forgotEmail;
    return '${_forgotEmail.substring(0, 2)}***${_forgotEmail.substring(at)}';
  }

  String get _forgotVerifyTitle => _forgotContactIsPhone
      ? _t('mobile_verification')
      : _t('email_verification');

  void _runResendTimer(int sec) {
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
    final user = ref.read(user_state.userStateProvider);
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

  Future<void> _sendForgotVerificationCode({bool fromResend = false}) async {
    if (_sendingCode || _resendSec > 0) return;
    if (_restoreResendIfActive()) return;
    if (fromResend) {
      _requestVercodeCount += 1;
      if (_requestVercodeCount > 3) {
        STToast.show(context, _t('error_vercode'));
        return;
      }
    }
    setState(() => _sendingCode = true);
    try {
      final service = ref.read(stServiceProvider);
      final h5 = ref.read(user_state.userStateProvider).h5AddressModel;
      final configuredCaptchaUrl = h5?.codeVerifyUrl.trim() ?? '';
      final captchaUrl = configuredCaptchaUrl.isEmpty
          ? 'localMini://codeverify'
          : configuredCaptchaUrl;
      final bridgeUserInfo = await _captchaBridgeUserInfo(service);
      if (!mounted) return;
      final captcha = await ref.read(authCaptchaDialogProvider)(
        context,
        url: captchaUrl,
        baseHost: service.dio.baseUrl.replaceFirst(RegExp(r'/violet/?$'), ''),
        captchaApiKey: h5?.captchaApiKey ?? '',
        bridgeUserInfo: bridgeUserInfo,
      );
      if (captcha == null) return;
      await service.sendVerificationCode({
        'code_type': STService.codeTypeForgotLoginPassword,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      if (mounted) {
        STToast.show(context, _t('verification_code_sent_successfully'));
        _startResend();
      }
    } catch (e) {
      if (mounted) STToast.show(context, stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _confirmForgotVerification() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      STToast.show(context, _t('please_input_code'));
      return;
    }
    setState(() => _validatingCode = true);
    try {
      await ref
          .read(stServiceProvider)
          .validateUserCode(
            code: code,
            type: _forgotContactIsPhone ? '1' : '2',
            codeType: STService.codeTypeForgotLoginPassword,
          );
      if (!mounted) return;
      setState(() {
        _forgotVerificationCode = code;
        _step = _ChangePwdStep.reset;
        _newCtrl.clear();
        _confirmCtrl.clear();
      });
    } catch (e) {
      if (mounted) STToast.show(context, stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _validatingCode = false);
    }
  }

  Future<void> _submitOldPassword() async {
    final err = _oldPasswordError();
    if (err != null) {
      STToast.show(context, err);
      return;
    }

    setState(() => _checkingOldPassword = true);
    try {
      final canContinue = await _isOldLoginPasswordValid();
      if (!canContinue || !mounted) return;
      setState(() {
        _forgotVerificationCode = '';
        _step = _ChangePwdStep.reset;
      });
    } finally {
      if (mounted) setState(() => _checkingOldPassword = false);
    }
  }

  Future<void> _submitLoginPassword() async {
    final err = _resetFormError();
    if (err != null) {
      STToast.show(context, err);
      return;
    }

    setState(() => _checkingOldPassword = true);
    try {
      final service = ref.read(stServiceProvider);
      if (_isForgotReset) {
        await service.resetLoggedInPasswordWithVerificationCode(
          verificationCode: _forgotVerificationCode,
          newPlainPassword: _newCtrl.text,
          confirmPlainPassword: _confirmCtrl.text,
        );
      } else {
        await service.changePassword(
          oldPlainPassword: _oldCtrl.text,
          newPlainPassword: _newCtrl.text,
          confirmPlainPassword: _confirmCtrl.text,
        );
      }
      ref
          .read(user_state.userStateProvider.notifier)
          .clearNeedUpdatePasswordFlag();
      if (!mounted) return;
      setState(() => _step = _ChangePwdStep.success);
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _checkingOldPassword = false);
    }
  }

  Future<void> _exitToLogin() async {
    await performIosAlignedLogout(ref);
    if (mounted) context.go('/login');
  }

  void _onCancel() {
    if (_step == _ChangePwdStep.success) {
      _exitToLogin();
      return;
    }
    context.pop();
  }

  void _onBack() {
    if (_step == _ChangePwdStep.success) {
      _exitToLogin();
      return;
    }
    if (_step == _ChangePwdStep.reset) {
      setState(
        () => _step = _isForgotReset
            ? _ChangePwdStep.verifyForgot
            : _ChangePwdStep.oldPassword,
      );
      return;
    }
    if (_step == _ChangePwdStep.verifyForgot) {
      _resendTimer?.cancel();
      setState(() {
        _resendSec = 0;
        _otpCtrl.clear();
        _forgotVerificationCode = '';
        _step = _ChangePwdStep.oldPassword;
      });
      return;
    }
    context.pop();
  }

  Widget _topBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            padding: const EdgeInsets.only(left: 2),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Colors.black,
            ),
            onPressed: _onBack,
          ),
          const Spacer(),
          if (_step != _ChangePwdStep.success)
            TextButton(
              onPressed: _onCancel,
              style: TextButton.styleFrom(
                foregroundColor: _kCancel,
                padding: const EdgeInsets.only(right: 8),
              ),
              child: Text(
                _t('cancel'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kCancel,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fieldBox({required Widget child, Widget? suffix}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Expanded(child: child),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _buildOldPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('reset_password'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 56),
          _fieldBox(
            child: TextField(
              controller: _oldCtrl,
              obscureText: true,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _t('input_old_password'),
                hintStyle: const TextStyle(color: _kPlaceholder, fontSize: 15),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 51),
          Center(
            child: SizedBox(
              width: 191,
              height: 48,
              child: ElevatedButton(
                onPressed: _oldPasswordError() == null && !_checkingOldPassword
                    ? _submitOldPassword
                    : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(31),
                  ),
                ),
                child: Text(
                  _t('next'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: _checkingOldPassword ? null : _openForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _t('forget_the_password'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFormStep() {
    final n = _newCtrl.text;
    return SingleChildScrollView(
      // Figma 2175:74699 内容区左右 15
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('reset_password'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.05,
            ),
          ),
          // 2175:74650：仅有主标题 → 首个输入框 y154（相对 y72≈56px）
          const SizedBox(height: 56),
          _fieldBox(
            child: TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _t('new_password_hint'),
                hintStyle: const TextStyle(color: _kPlaceholder, fontSize: 15),
              ),
              onChanged: (_) => setState(() {}),
            ),
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
          ),
          const SizedBox(height: 12),
          _fieldBox(
            child: TextField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: _t('confirm_password_input'),
                hintStyle: const TextStyle(color: _kPlaceholder, fontSize: 15),
              ),
              onChanged: (_) => setState(() {}),
            ),
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
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _ruleIcon(_ruleLengthOk(n)),
                  const SizedBox(height: 8),
                  _ruleIcon(_ruleLetterOk(n)),
                  const SizedBox(height: 8),
                  _ruleIcon(_ruleDigitOk(n)),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('password_rule_tip'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 24 / 12,
                    color: Color(0xFFA9A9A9),
                  ),
                ),
              ),
            ],
          ),
          // 无规则条时末格底→按钮约 51px（2175:74650 y328→379）；含规则条时间距按 2175:74699
          const SizedBox(height: 51),
          Center(
            child: SizedBox(
              width: 191,
              height: 48,
              child: ElevatedButton(
                onPressed: _resetFormError() == null && !_checkingOldPassword
                    ? _submitLoginPassword
                    : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(31),
                  ),
                ),
                child: Text(
                  _t('certain'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _ruleIcon(bool ok) {
    return Icon(
      ok ? Icons.check_circle : Icons.circle_outlined,
      size: 16,
      color: ok ? _kSuccess : const Color(0xFFD9D9D9),
    );
  }

  Widget _buildForgotVerificationStep() {
    final subtitle = _forgotContactIsPhone
        ? _t('verification_code_sent_successfully')
        : _t('verification_code_sent_successfully');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            _forgotVerifyTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 21),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: _kSubtitle,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 54),
          Text(
            _t('verification_code_sent_to_prefix'),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: _kSubtitle,
            ),
          ),
          Text(
            _forgotTargetDisplay,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 40),
          _fieldBox(
            child: TextField(
              controller: _otpCtrl,
              focusNode: _otpFocus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 18, letterSpacing: 0),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                border: InputBorder.none,
                hintText: _t('please_input_code'),
                hintStyle: const TextStyle(color: _kPlaceholder, fontSize: 15),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 43),
          Center(
            child: GestureDetector(
              onTap: (_resendSec == 0 && !_sendingCode)
                  ? () => _sendForgotVerificationCode(fromResend: true)
                  : null,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _t('verify_code_send_again'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _resendSec > 0
                            ? const Color(0xFFD9D9D9)
                            : _kPrimary,
                      ),
                    ),
                    if (_resendSec > 0)
                      const TextSpan(text: ' ', style: TextStyle(fontSize: 14)),
                    if (_resendSec > 0)
                      TextSpan(
                        text: '(${_resendSec}s)',
                        style: const TextStyle(
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
                onPressed: _validatingCode || _otpCtrl.text.length != 6
                    ? null
                    : _confirmForgotVerification,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(31),
                  ),
                ),
                child: _validatingCode
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _t('confirm'),
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
                foregroundColor: _kPrimary,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                unawaited(
                  showIosCommonAlertDialog(
                    context: context,
                    title: _t('warm_tips'),
                    message: _forgotContactIsPhone
                        ? _t('phone_not_receive')
                        : _t('mail_not_receive'),
                    cancelText: _t('cancel'),
                    confirmText: _t('online_custom'),
                    confirmTextColor: _kPrimary,
                    onConfirm: () => CustomerServiceRoute.open(context, ref),
                  ),
                );
              },
              child: Text(
                _t('verification_code_not_received'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    // Figma 2175:74590：标题/勾选 #1bcc83，说明 #60656d，完成按钮 151×45·圆角41
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kDoneGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: _kDoneGreen,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _t('password_reset_success'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: _kDoneGreen,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _t('password_reset_success_tips'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: _kSubtitle,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 151,
              height: 45,
              child: ElevatedButton(
                onPressed: _exitToLogin,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(41),
                  ),
                ),
                child: Text(
                  _t('complete'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    return PopScope(
      canPop: _step == _ChangePwdStep.oldPassword,
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
              _topBar(),
              Expanded(
                child: switch (_step) {
                  _ChangePwdStep.oldPassword => _buildOldPasswordStep(),
                  _ChangePwdStep.verifyForgot => _buildForgotVerificationStep(),
                  _ChangePwdStep.reset => _buildFormStep(),
                  _ChangePwdStep.success => _buildSuccessStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
