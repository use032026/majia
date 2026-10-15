import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/st_hmac_sha256.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/models/user_state.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/validators/fund_password_validator.dart';
import '../../core/verification/verification_code_cooldown.dart';
import '../../shared/widgets/auth_popups.dart';
import '../../shared/auth/white_label_password_ui.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_captcha_dialog.dart';
import '../auth/auth_widgets.dart';

/// 资金密码：首次设置 / 修改 / 忘记重置（Figma：设置/重设 + 验证 + 完成）
enum FinancePwdMode { initialSet, change, forgot }

enum _FundStep { checkOld, form, verify, success }

enum _FundPwdVerificationChannel { phone, email }

class FinancePasswordPage extends ConsumerStatefulWidget {
  final FinancePwdMode mode;

  const FinancePasswordPage({super.key, required this.mode});

  @override
  ConsumerState<FinancePasswordPage> createState() =>
      _FinancePasswordPageState();
}

class _FinancePasswordPageState extends ConsumerState<FinancePasswordPage> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  _FundStep _step = _FundStep.form;

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _obscureOld = true;

  bool _submitting = false;
  bool _sendingCode = false;
  bool _checkingOldPassword = false;
  int _resendSec = 0;
  Timer? _resendTimer;

  bool _loadingProfile = false;
  String _maskedContact = '';
  bool _contactIsPhone = true;
  _FundPwdVerificationChannel _verificationChannel =
      _FundPwdVerificationChannel.phone;
  String _verificationPhone = '';
  String _verificationEmail = '';
  String _verifiedCode = '';
  String _verifiedOldPassword = '';
  String? _localizedLanguageCode;
  Map<String, String> _localized = _fallbackText;

  /// iOS `STCodeType_SetFundPassword = 7`
  static const int _kCodeTypeSetFundPassword = 7;
  static const Map<String, String> _fallbackText = {
    'set_sum_password': '设置资金密码',
    'set_sum_password_tip': '资金密码用于出金、划转等关键操作，请妥善保管。',
    'set_sum_password_success': '资金密码设置成功',
    'fund_password_success': '资金密码重置成功',
    'fund_password_used': '资金密码用于出金、划转等操作，请妥善保管。',
    'check_your_pwd': '验证您的密码',
    'mobile_verification': '手机验证',
    'email_verification': '邮箱验证',
    'verify_phone_or_email_to': '我们已将验证码发送至',
    'phone_code_tip': '如长时间未收到，请联系在线客服。',
    'mail_not_receive': '如长时间未收到验证码，请检查垃圾邮件。如仍未收到，可重试或联系客服。',
    'phone_not_receive': '请检查手机号填写及短信拦截、垃圾短信文件夹。',
    'verification_code_not_received': '未收到验证码？',
    'cancel': '取消',
    'online_custom': '在线客服',
    'verify_code_send_again': '重新发送',
    'confirm': '确认',
    'complete': '完成',
    'next': '下一步',
    'forget_the_password': '忘记密码？',
    'input_your_fund_pwd_continue': '输入您的资金密码以继续',
    'sum_password_input': '请输入资金密码',
    'sum_password_confirm': '确认资金密码',
    'sum_password_not_same': '两次输入的密码不一致。',
    'set_sum_password_bottom_tip': '6位数字，且不可重复或连续',
    'incorrect_fund_password': '当前资金密码错误。',
    'please_input_code': '请输入验证码',
    'error_vercode': '请输入6位验证码',
    'verification_code_sent_successfully': '验证码已发送',
    'requestfail': '请求失败',
  };

  void _ensureLocalizedText(STLocalizations localizations) {
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
  void initState() {
    super.initState();
    _otpFocus.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.mode == FinancePwdMode.change) {
      _step = _FundStep.checkOld;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startVerificationFirstFlow();
      });
    }
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

  String get _titleForm {
    switch (widget.mode) {
      case FinancePwdMode.initialSet:
      case FinancePwdMode.change:
      case FinancePwdMode.forgot:
        return _t('set_sum_password');
    }
  }

  String get _subtitleForm {
    switch (widget.mode) {
      case FinancePwdMode.initialSet:
      case FinancePwdMode.change:
      case FinancePwdMode.forgot:
        return _t('set_sum_password_tip');
    }
  }

  String get _successTitle {
    switch (widget.mode) {
      case FinancePwdMode.initialSet:
        return _t('set_sum_password_success');
      case FinancePwdMode.change:
      case FinancePwdMode.forgot:
        return _t('fund_password_success');
    }
  }

  String get _verifyTitle =>
      _contactIsPhone ? _t('mobile_verification') : _t('email_verification');

  String _maskedPhoneForDisplay(String phone) {
    if (phone.contains('*')) return phone;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    final head = digits.substring(0, 2);
    final tail = digits.substring(digits.length - 2);
    return '$head${'*' * (digits.length - 4)}$tail';
  }

  Future<void> _syncBindFlagsFromUserInfo() async {
    try {
      final raw = await ref.read(stServiceProvider).getUserProfile();
      final data = raw['data'];
      if (data is Map<String, dynamic>) {
        ref.read(userStateProvider.notifier).mergeUserInfoApi(data);
      }
    } catch (_) {}
  }

  Future<void> _loadMaskedContact() async {
    setState(() => _loadingProfile = true);
    try {
      final raw = await ref.read(stServiceProvider).getUserProfile();
      Map<String, dynamic> data;
      final d = raw['data'];
      if (d is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(d);
      } else {
        data = Map<String, dynamic>.from(raw);
      }
      final tel = UserState.pickString(data, [
        'tel',
        'phone',
        'mobile',
        'user_tel',
        'bind_phone',
      ]);
      final email = UserState.pickString(data, ['email', 'user_email']);
      final hasPhone = tel != null && tel.isNotEmpty;
      final hasEmail = email != null && email.isNotEmpty;

      _verificationPhone = (tel ?? '').trim();
      _verificationEmail = (email ?? '').trim();

      if (widget.mode == FinancePwdMode.initialSet) {
        final country = ref.read(effectiveSelectedCountryProvider).key;
        final isCnInitialSet = country == 'CN';
        if (hasPhone && hasEmail) {
          _verificationChannel = isCnInitialSet
              ? _FundPwdVerificationChannel.phone
              : _FundPwdVerificationChannel.email;
        } else if (hasPhone) {
          _verificationChannel = _FundPwdVerificationChannel.phone;
        } else if (hasEmail) {
          _verificationChannel = _FundPwdVerificationChannel.email;
        } else {
          _verificationChannel = _FundPwdVerificationChannel.phone;
        }
      } else if (widget.mode == FinancePwdMode.forgot) {
        if (hasPhone) {
          _verificationChannel = _FundPwdVerificationChannel.phone;
        }
        if (hasEmail) {
          _verificationChannel = _FundPwdVerificationChannel.email;
        }
      }

      final usePhoneChannel =
          _verificationChannel == _FundPwdVerificationChannel.phone;
      if (mounted) {
        setState(() {
          if (usePhoneChannel && hasPhone) {
            _maskedContact = _maskedPhoneForDisplay(_verificationPhone);
          } else if (!usePhoneChannel && hasEmail) {
            final at = _verificationEmail.indexOf('@');
            _maskedContact = at <= 1
                ? _verificationEmail
                : '${_verificationEmail.substring(0, 2)}***${_verificationEmail.substring(at)}';
          } else {
            _maskedContact = '';
          }
          _contactIsPhone = usePhoneChannel;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
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

  Future<void> _sendVerificationCode() async {
    if (_sendingCode || _resendSec > 0) return;
    if (_restoreResendIfActive()) return;
    setState(() => _sendingCode = true);
    try {
      final service = ref.read(stServiceProvider);
      final h5 = ref.read(userStateProvider).h5AddressModel;
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

      await service.sendWalletVerificationCode({
        'code_type': _kCodeTypeSetFundPassword,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      if (mounted) {
        STToast.show(context, _t('verification_code_sent_successfully'));
        _startResend(60);
      }
    } catch (e) {
      if (mounted) STToast.show(context, stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _startVerificationFirstFlow() async {
    if (!mounted) return;
    setState(() {
      _step = _FundStep.verify;
      _otpCtrl.clear();
      _verifiedCode = '';
    });
    await _loadMaskedContact();
    if (!mounted) return;
    if (_maskedContact.isEmpty) {
      STToast.show(context, _t('requestfail'));
      setState(() => _step = _FundStep.form);
      return;
    }
    if (_restoreResendIfActive()) return;
    await _sendVerificationCode();
  }

  Future<bool> _ensureCanResetFundPasswordWithVercode() async {
    final userState = ref.read(userStateProvider);
    if (userState.isBindEmail || userState.isBindPhone) return true;

    final shouldContinue = await showAuthGuideSheet(context: context);
    if (!mounted) return false;
    if (shouldContinue == true) {
      context.push('/mine/auth');
    }
    return false;
  }

  Future<void> _openForgotFinancePassword() async {
    if (!mounted) return;
    final passed = await _ensureCanResetFundPasswordWithVercode();
    if (!passed || !mounted) return;
    context.pushReplacement('/mine/finance_password?mode=forgot');
  }

  String? _validateForm() {
    final n = _newCtrl.text;
    final c = _confirmCtrl.text;
    if (!isSixDigitFundPasswordValid(n)) {
      return _t('set_sum_password_bottom_tip');
    }
    if (n != c) return _t('sum_password_not_same');
    return null;
  }

  Future<void> _onFormNext() async {
    if (widget.mode == FinancePwdMode.change && _verifiedOldPassword.isEmpty) {
      await _submitOldPasswordCheck();
      return;
    }
    final err = _validateForm();
    if (err != null) {
      STToast.show(context, err);
      return;
    }
    if (widget.mode == FinancePwdMode.change) {
      await _submitChange();
      return;
    }
    if (_verifiedCode.isNotEmpty) {
      await _submitSetOrForgot();
      return;
    }
    setState(() => _step = _FundStep.verify);
    _otpCtrl.clear();
    await _loadMaskedContact();
    if (!mounted) return;
    if (_maskedContact.isEmpty) {
      STToast.show(context, _t('requestfail'));
      setState(() => _step = _FundStep.form);
      return;
    }
    await _sendVerificationCode();
  }

  Future<bool> _isOldFundPasswordValid() async {
    try {
      final service = ref.read(stServiceProvider);
      final same = await service.checkFundsPasswordSame(
        oldPlainPassword: _oldCtrl.text,
      );
      if (!same && mounted) {
        STToast.show(context, _t('incorrect_fund_password'));
      }
      return same;
    } catch (e) {
      if (mounted) STToast.show(context, stUserVisibleErrorMessage(e));
      return false;
    }
  }

  Future<void> _submitOldPasswordCheck() async {
    if (_oldCtrl.text.isEmpty) {
      STToast.show(context, _t('sum_password_input'));
      return;
    }
    setState(() => _checkingOldPassword = true);
    try {
      final isSame = await _isOldFundPasswordValid();
      if (!isSame || !mounted) return;
      setState(() {
        _verifiedOldPassword = _oldCtrl.text;
        _newCtrl.clear();
        _confirmCtrl.clear();
        _step = _FundStep.form;
      });
    } finally {
      if (mounted) setState(() => _checkingOldPassword = false);
    }
  }

  Future<void> _submitChange() async {
    setState(() => _submitting = true);
    try {
      final service = ref.read(stServiceProvider);
      await service.editFundPassword({
        'old_password': stHmacSha256Hex(_verifiedOldPassword),
        'new_password': stHmacSha256Hex(_newCtrl.text),
        'confirm_password': stHmacSha256Hex(_confirmCtrl.text),
      });
      await _syncBindFlagsFromUserInfo();
      if (mounted) setState(() => _step = _FundStep.success);
    } catch (e) {
      if (mounted) STToast.show(context, stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitSetOrForgot() async {
    final code = _verifiedCode.isNotEmpty
        ? _verifiedCode
        : _otpCtrl.text.trim();
    if (code.length != 6) {
      STToast.show(context, _t('error_vercode'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = ref.read(stServiceProvider);
      if (widget.mode == FinancePwdMode.initialSet) {
        await service.setFundPassword({
          'new_password': stHmacSha256Hex(_newCtrl.text),
          'confirm_password': stHmacSha256Hex(_confirmCtrl.text),
          'code': code,
          'is_google_jwt': 0,
        });
      } else {
        await service.resetFundPassword({
          'new_password': stHmacSha256Hex(_newCtrl.text),
          'confirm_password': stHmacSha256Hex(_confirmCtrl.text),
          'code': code,
        });
      }
      await _syncBindFlagsFromUserInfo();
      if (mounted) setState(() => _step = _FundStep.success);
    } catch (e) {
      if (mounted) STToast.show(context, stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmVerificationBeforeForm() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      STToast.show(context, _t('error_vercode'));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(stServiceProvider)
          .validateUserCode(
            code: code,
            type: _contactIsPhone ? '1' : '2',
            areaCode: '',
            phone: '',
            mail: '',
            codeType: _kCodeTypeSetFundPassword,
          );
      if (!mounted) return;
      setState(() {
        _verifiedCode = code;
        _step = _FundStep.form;
      });
    } catch (e) {
      if (mounted) STToast.show(context, stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onBack() {
    switch (_step) {
      case _FundStep.checkOld:
        context.pop();
        break;
      case _FundStep.form:
        if (widget.mode == FinancePwdMode.change &&
            _verifiedOldPassword.isNotEmpty) {
          setState(() {
            _step = _FundStep.checkOld;
            _newCtrl.clear();
            _confirmCtrl.clear();
          });
          return;
        }
        context.pop();
        break;
      case _FundStep.verify:
        if (widget.mode != FinancePwdMode.change && _verifiedCode.isEmpty) {
          context.pop();
          return;
        }
        setState(() {
          _step = _FundStep.form;
          _otpCtrl.clear();
          _resendTimer?.cancel();
          _resendSec = 0;
        });
        break;
      case _FundStep.success:
        context.pop();
        break;
    }
  }

  void _onCancel() {
    context.pop();
  }

  Widget _digitField({
    required TextEditingController controller,
    required String hint,
    bool showToggle = true,
    ValueChanged<bool>? onToggle,
    bool obscureValue = true,
  }) {
    return WhiteLabelFieldBox(
      suffix: showToggle
          ? IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                obscureValue
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: Colors.black.withValues(alpha: 0.42),
              ),
              onPressed: () => onToggle?.call(!obscureValue),
            )
          : null,
      child: TextField(
        controller: controller,
        obscureText: obscureValue,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 15, letterSpacing: 2),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(
            color: WhiteLabelAuthColors.placeholder,
            fontSize: 15,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _titleForm,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          // Figma 2175:74496 标题 y72 → 说明 y110
          const SizedBox(height: 12),
          Text(
            _subtitleForm,
            style: const TextStyle(
              fontSize: 12,
              color: WhiteLabelAuthColors.subtitle,
              height: 1.35,
            ),
          ),
          // 说明 → 首个输入框 y167（多行说明时按比例留空）；修改模式无此稿另行压缩
          SizedBox(height: widget.mode == FinancePwdMode.change ? 24 : 47),
          _digitField(
            controller: _newCtrl,
            hint: _t('sum_password_input'),
            showToggle: true,
            obscureValue: _obscureNew,
            onToggle: (v) => setState(() => _obscureNew = v),
          ),
          const SizedBox(height: 12),
          _digitField(
            controller: _confirmCtrl,
            hint: _t('sum_password_confirm'),
            showToggle: true,
            obscureValue: _obscureConfirm,
            onToggle: (v) => setState(() => _obscureConfirm = v),
          ),
          const SizedBox(height: 14),
          Text(
            _t('set_sum_password_bottom_tip'),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: WhiteLabelAuthColors.inactiveTab,
            ),
          ),
          // 提示文案 y292 →「确认」y370
          const SizedBox(height: 64),
          Center(
            child: WhiteLabelPillButton(
              label: _t('confirm'),
              onPressed: _submitting ? null : _onFormNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckOldPassword() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('check_your_pwd'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('input_your_fund_pwd_continue'),
            style: const TextStyle(
              fontSize: 12,
              color: WhiteLabelAuthColors.subtitle,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 44),
          _digitField(
            controller: _oldCtrl,
            hint: _t('sum_password_input'),
            showToggle: true,
            obscureValue: _obscureOld,
            onToggle: (v) => setState(() => _obscureOld = v),
          ),
          const SizedBox(height: 164),
          Center(
            child: WhiteLabelPillButton(
              label: _t('next'),
              onPressed: _checkingOldPassword ? null : _submitOldPasswordCheck,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
              onPressed: _checkingOldPassword
                  ? null
                  : _openForgotFinancePassword,
              child: Text(
                _t('forget_the_password'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerify() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.5),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            _verifyTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          if (_loadingProfile)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('verify_phone_or_email_to'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: WhiteLabelAuthColors.subtitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _maskedContact,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _contactIsPhone
                      ? _t('phone_code_tip')
                      : _t('mail_not_receive'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: WhiteLabelAuthColors.subtitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 118),
            WhiteLabelOtpInput(
              controller: _otpCtrl,
              focusNode: _otpFocus,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 43),
            Center(
              child: GestureDetector(
                onTap: (_resendSec == 0 && !_sendingCode)
                    ? _sendVerificationCode
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
                  onPressed: _submitting || _otpCtrl.text.length != 6
                      ? null
                      : _confirmVerificationBeforeForm,
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
                  child: _submitting
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
                  foregroundColor: WhiteLabelAuthColors.primary,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  unawaited(
                    showAuthNotReceiveCodeDialog(
                      context,
                      message: _contactIsPhone
                          ? _t('phone_not_receive')
                          : _t('mail_not_receive'),
                      title: _t('verification_code_not_received'),
                      closeText: _t('cancel'),
                      serviceText: _t('online_custom'),
                      onService: () {
                        if (!mounted) return;
                        unawaited(CustomerServiceRoute.open(context, ref));
                      },
                    ),
                  );
                },
                child: Text(
                  _t('verification_code_not_received'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: WhiteLabelAuthColors.primary,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: WhiteLabelAuthColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: WhiteLabelAuthColors.success,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _successTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: WhiteLabelAuthColors.success,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _t('fund_password_used'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WhiteLabelAuthColors.subtitle,
                    height: 1.35,
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
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: WhiteLabelAuthColors.primary,
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
    _ensureLocalizedText(ref.watch(stLocalizationsProvider));
    const canPop = false;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              WhiteLabelAuthTopBar(
                onBack: _onBack,
                onCancel: _onCancel,
                cancelColor: _step == _FundStep.verify
                    ? WhiteLabelAuthColors.timer
                    : null,
                showCancel: _step == _FundStep.form,
              ),
              Expanded(
                child: switch (_step) {
                  _FundStep.checkOld => _buildCheckOldPassword(),
                  _FundStep.form => _buildForm(),
                  _FundStep.verify => _buildVerify(),
                  _FundStep.success => _buildSuccess(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
