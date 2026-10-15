import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/router/customer_service_route.dart';
import '../../shared/auth/white_label_password_ui.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_api_helpers.dart';
import '../auth/auth_captcha_dialog.dart';
import '../auth/auth_widgets.dart';
import '../auth/auth_validators.dart';

enum _CloseAccountStep { check, verify, success }

class _CloseAccountText {
  const _CloseAccountText._();

  static const fallback = <String, String>{
    'account_cancellation': '注销账户',
    'cancel_account_title': '注销账户 %1\$s',
    'after_account_cancellation': '注销后，你的账户将无法继续使用',
    'cancel_account_note_one': '账户身份、会员权益将被清除',
    'cancel_account_note_two': '交易记录将被清除',
    'cancel_account_note_three': '个人隐私信息将被清除',
    'cancel_conditions_need_complete': '账户注销前需要完成以下事项',
    'cancel_conditions_one': '账户资产已清空',
    'cancel_conditions_two': '无未平仓订单',
    'verify_code_send_to': '验证码将发送至：%1\$s',
    'continue': '继续',
    'think_again': '我再想想',
    'account_cancel_verify_code': '账户注销验证码',
    'verification_code_sent_to_prefix': '验证码已发送至\n',
    'verify_code_valid_10_minutes': '\n验证码10分钟内有效',
    'verify_code_send_again': '重新发送',
    'resend_verification_code': '重新发送验证码',
    'submitting': '提交中...',
    'certain': '确定',
    'verification_code_not_received': '收不到验证码？',
    'account_cancelled': '账户已注销',
    'thank_you_for_using': '感谢你的使用',
    'return': '返回',
    'close_account_cannot': '当前账户不满足注销条件',
    'phone_number_input': '请输入手机号码',
    'phone_error': '手机号码不正确',
    'phone_size_error': '手机号码位数错误',
    'verification_code_sent_successfully': '验证码已发送',
    'verification_code_error': '验证码错误，请稍后再试',
    'please_input_6_code': '请输入6位验证码',
    'phone_not_receive': '请检查手机号填写及短信拦截、垃圾短信文件夹。',
    'mail_not_receive': '如长时间未收到验证码，请检查垃圾邮件。如仍未收到，可重试或联系客服。',
    'not_receive_code_title': '未收到验证码',
    'cancel': '取消',
    'online_custom': '在线客服',
  };
}

/// 注销账户（对齐 iOS `STCloseAccountController` + `STInputVerCodeController`）
class CloseAccountPage extends ConsumerStatefulWidget {
  const CloseAccountPage({super.key});

  @override
  ConsumerState<CloseAccountPage> createState() => _CloseAccountPageState();
}

class _CloseAccountPageState extends ConsumerState<CloseAccountPage> {
  static const Color _kPrimary = WhiteLabelAuthColors.primary;
  static const Color _kSubtitle = WhiteLabelAuthColors.subtitle;
  static const Color _kMuted = WhiteLabelAuthColors.muted;
  static const Color _kSuccess = Color(0xFF1BCC83);

  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  _CloseAccountStep _step = _CloseAccountStep.check;
  int _resendSec = 0;
  Timer? _resendTimer;

  bool _checking = true;
  bool _sendingCode = false;
  bool _submitting = false;
  bool _isBalance = false;
  bool _isPosition = false;
  String _phone = '';
  String _email = '';
  String _areaCode = '+86';
  int _resendRequestCount = 0;
  Map<String, String> _localized = _CloseAccountText.fallback;
  String? _localizedLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadPrecheck();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  bool get _canSendToSms => _phone.isNotEmpty;
  bool get _canCloseAccount =>
      !_isBalance && !_isPosition && (_phone.isNotEmpty || _email.isNotEmpty);

  String get _contactDisplay {
    if (_phone.isNotEmpty) return _maskPhoneForDisplay();
    if (_email.isNotEmpty) return _maskEmail(_email);
    return '';
  }

  String get _accountDisplay {
    if (_phone.isNotEmpty) return _phone;
    if (_email.isNotEmpty) return _email;
    return '';
  }

  static void _ensureApiOk(Map<String, dynamic> raw) {
    AuthApiHelpers.ensureOk(raw);
  }

  void _showMessage(Object? message) {
    STToast.show(context, stSanitizeUserVisibleText(message?.toString() ?? ''));
  }

  void _ensureLocalizedText() {
    final localizations = ref.watch(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_CloseAccountText.fallback).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _CloseAccountText.fallback[key] ?? key;

  AuthValidatorMessages get _validatorMessages =>
      AuthValidatorMessages.fromMap(_localized);

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

  String _maskPhoneForDisplay() {
    final d = _phone.replaceAll(RegExp(r'\D'), '');
    if (d.length < 7) return '(${_areaCode.replaceAll('+', '')}) $d';
    final head = d.substring(0, d.length - 6);
    final tail = d.substring(d.length - 3);
    return '(${_areaCode.replaceAll('+', '')}) $head****$tail';
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final shown = email.substring(0, 2);
    return '$shown***${email.substring(at)}';
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

  Future<void> _loadPrecheck() async {
    setState(() {
      _checking = true;
    });
    try {
      final raw = await ref
          .read(stServiceProvider)
          .checkCloseAccountPrecondition();
      _ensureApiOk(raw);
      final d = (raw['data'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : Map<String, dynamic>.from(raw);

      final phone =
          UserState.pickString(d, [
            'tel_phone',
            'tel',
            'phone',
            'mobile',
            'bind_tel',
          ]) ??
          '';
      final area =
          UserState.pickString(d, ['tel_area_code', 'area_code']) ?? _areaCode;
      final email = UserState.pickString(d, ['email', 'bind_email']) ?? '';
      final isBalance = UserState.parseApiBool(d['is_balance']);
      final isPosition = UserState.parseApiBool(d['is_position']);

      setState(() {
        _phone = phone;
        _email = email;
        _areaCode = area.isNotEmpty ? area : _areaCode;
        _isBalance = isBalance;
        _isPosition = isPosition;
        _resendRequestCount = 0;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(e);
      setState(() {
        _checking = false;
      });
    }
  }

  Future<bool> _sendVerificationCode() async {
    if (_sendingCode || _resendSec > 0) return false;
    if (!_canCloseAccount) {
      _showMessage(_t('close_account_cannot'));
      return false;
    }
    if (_canSendToSms) {
      final phoneErr = AuthValidators.phoneError(
        _phone,
        _areaCode,
        messages: _validatorMessages,
      );
      if (phoneErr != null) {
        _showMessage(phoneErr);
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
      final captcha = await showAuthCaptchaDialog(
        context,
        url: captchaUrl,
        baseHost: service.dio.baseUrl.replaceFirst(RegExp(r'/violet/?$'), ''),
        captchaApiKey: h5?.captchaApiKey ?? '',
        bridgeUserInfo: bridgeUserInfo,
      );
      if (captcha == null) return false;

      final raw = await service.sendVerificationCode({
        'code_type': STService.codeTypeCloseAccount,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      _ensureApiOk(raw);
      if (!mounted) return false;
      _showMessage(_t('verification_code_sent_successfully'));
      _startResendCooldown(60);
      return true;
    } catch (e) {
      if (mounted) _showMessage(e);
      return false;
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _goVerify() async {
    if (!_canCloseAccount) return;
    final ok = await _sendVerificationCode();
    if (!ok) return;

    setState(() {
      _step = _CloseAccountStep.verify;
      _otpCtrl.clear();
      _resendRequestCount = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  Future<void> _resend() async {
    if (_resendSec > 0 || _sendingCode) return;
    _resendRequestCount += 1;
    if (_resendRequestCount > 3) {
      _showMessage(_t('verification_code_error'));
      return;
    }
    await _sendVerificationCode();
  }

  Future<void> _submit() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      _showMessage(_t('please_input_6_code'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final raw = await ref
          .read(stServiceProvider)
          .closeAccountWithCode(code: code);
      _ensureApiOk(raw);
      if (mounted) {
        setState(() => _step = _CloseAccountStep.success);
      }
    } catch (e) {
      if (mounted) _showMessage(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    if (_step == _CloseAccountStep.verify) {
      _resendTimer?.cancel();
      _resendSec = 0;
      setState(() => _step = _CloseAccountStep.check);
      return;
    }
    if (_step == _CloseAccountStep.success) {
      _finishSuccess();
      return;
    }
    context.pop();
  }

  void _cancel() => context.pop();

  Future<void> _handleCodeUnavailable() async {
    final message = _canSendToSms
        ? _t('phone_not_receive')
        : _t('mail_not_receive');
    await showAuthNotReceiveCodeDialog(
      context,
      message: message,
      title: _t('not_receive_code_title'),
      closeText: _t('cancel'),
      serviceText: _t('online_custom'),
      onService: () {
        if (!mounted) return;
        unawaited(CustomerServiceRoute.open(context, ref));
      },
    );
  }

  void _finishSuccess() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Widget _topBar() {
    return WhiteLabelAuthTopBar(
      onBack: _back,
      onCancel: _cancel,
      showCancel: _step != _CloseAccountStep.success,
    );
  }

  Widget _checkStep() {
    if (_checking) {
      return const Center(child: STLoadAnimationView());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 26),
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(27),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF5656),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 29),
          Text(
            _accountDisplay.isEmpty
                ? _t('account_cancellation')
                : _t(
                    'cancel_account_title',
                  ).replaceAll('%1\$s', _accountDisplay),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            _t('after_account_cancellation'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _kSubtitle,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _infoCard(
            children: [
              _BulletText(_t('cancel_account_note_one')),
              const SizedBox(height: 13),
              _BulletText(_t('cancel_account_note_two')),
              const SizedBox(height: 13),
              _BulletText(_t('cancel_account_note_three')),
            ],
          ),
          const SizedBox(height: 11),
          _infoCard(
            children: [
              Text(
                _t('cancel_conditions_need_complete'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 9),
              _CloseConditionRow(
                failed: _isBalance,
                label: _t('cancel_conditions_one'),
              ),
              const SizedBox(height: 9),
              _CloseConditionRow(
                failed: _isPosition,
                label: _t('cancel_conditions_two'),
              ),
            ],
          ),
          if (_contactDisplay.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _t('verify_code_send_to').replaceAll('%1\$s', _contactDisplay),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
          ],
          const SizedBox(height: 43),
          Center(
            child: SizedBox(
              width: 193,
              height: 48,
              child: ElevatedButton(
                onPressed: _canCloseAccount ? _goVerify : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  _t('continue'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: SizedBox(
              width: 193,
              height: 48,
              child: TextButton(
                onPressed: _back,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF7F7F7),
                  foregroundColor: _kSubtitle,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  _t('think_again'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
            _t('account_cancel_verify_code'),
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
                TextSpan(text: _t('verification_code_sent_to_prefix')),
                TextSpan(
                  text: _contactDisplay,
                  style: const TextStyle(color: Colors.black),
                ),
                TextSpan(text: _t('verify_code_valid_10_minutes')),
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
                    ? '${_t('verify_code_send_again')} ($_resendSec s)'
                    : _t('resend_verification_code'),
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
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: () => _handleCodeUnavailable(),
              child: Text(
                _t('verification_code_not_received'),
                style: const TextStyle(fontSize: 14, color: _kPrimary),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
            _t('account_cancelled'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _kSuccess,
            ),
          ),
        ),
        const SizedBox(height: 11),
        Text(
          _t('thank_you_for_using'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _kSubtitle, height: 1.35),
        ),
        const SizedBox(height: 163),
        WhiteLabelPillButton(
          label: _t('return'),
          width: 128,
          height: 34,
          onPressed: _finishSuccess,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final body = switch (_step) {
      _CloseAccountStep.check => _checkStep(),
      _CloseAccountStep.verify => _verifyStep(),
      _CloseAccountStep.success => _successStep(),
    };

    return PopScope(
      canPop: _step == _CloseAccountStep.check,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _infoCard({required List<Widget> children}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF60656D),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60656D),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _CloseConditionRow extends StatelessWidget {
  const _CloseConditionRow({required this.failed, required this.label});

  final bool failed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = failed ? Colors.black : const Color(0xFF9A9DA2);
    return Row(
      children: [
        failed
            ? const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: Color(0xFFFF5656),
              )
            : Image.asset(
                'assets/images/st_ca_unfinish_true.png',
                width: 18,
                height: 18,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: Color(0xFF1BCC83),
                ),
              ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: color, height: 1.3),
          ),
        ),
      ],
    );
  }
}
