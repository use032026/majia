import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/user_state.dart';
import '../../core/network/device_id_manager.dart';
import '../../core/network/st_service.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/router/policy_link_route.dart';
import '../../core/services/startup_device_registrar.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../shared/widgets/st_action_refreshing_hud.dart';
import 'auth_api_helpers.dart';
import 'auth_captcha_dialog.dart';
import 'auth_oauth_flow.dart';
import 'auth_theme.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'register_config.dart';
import 'register_country.dart';
import '../../shared/widgets/st_base_scaffold.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_toast.dart';
import 'auth_name_input_formatter.dart';

/// 对齐 iOS `STUserInfoManger.isAgreePrivacy`
const _kPrivacyAgreedKey = 'is_agree_privacy';

/// 注册页（对齐 iOS `STNewRegisterViewController`）
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  static final Map<String, String> _fallbackText = {
    'new_register_account_registration': stLocalizedTextFromZhHans('开户注册'),
    'new_register_create_account': stLocalizedTextFromZhHans('创建帐户'),
    'new_register_start_trading': stLocalizedTextFromZhHans('开启您的全球交易之旅'),
    'email': stLocalizedTextFromZhHans('邮箱'),
    'phone': stLocalizedTextFromZhHans('手机'),
    'country_area': stLocalizedTextFromZhHans('国家/地区'),
    'phone_number': stLocalizedTextFromZhHans('手机号码'),
    'phone_number_input': stLocalizedTextFromZhHans('请输入手机号码'),
    'phone_number_format_error': stLocalizedTextFromZhHans('手机号格式不对'),
    'phone_error': stLocalizedTextFromZhHans('手机号码不正确'),
    'phone_size_error': stLocalizedTextFromZhHans('手机号码位数错误'),
    'please_input_email': stLocalizedTextFromZhHans('请输入邮箱'),
    'email_format_error': stLocalizedTextFromZhHans('邮箱格式不正确'),
    'verify_code': stLocalizedTextFromZhHans('验证码'),
    'please_input_code': stLocalizedTextFromZhHans('请输入验证码'),
    'get_verification_code': stLocalizedTextFromZhHans('获取验证码'),
    'send_verification_code_success': stLocalizedTextFromZhHans('验证码发送成功'),
    'set_pwd': stLocalizedTextFromZhHans('设置密码'),
    'password_input': stLocalizedTextFromZhHans('请输入密码'),
    'password_error_format_tips': stLocalizedTextFromZhHans(
      '密码必须是5~15位英文字母、数字组合',
    ),
    'password_empty_error': stLocalizedTextFromZhHans('密码不能包含空格'),
    'new_register_password_placehorder': stLocalizedTextFromZhHans(
      '8~20位，含数字和字母',
    ),
    'new_register_password_confirm': stLocalizedTextFromZhHans('确认密码'),
    'new_register_password_confirm_placehorder': stLocalizedTextFromZhHans(
      '请输入一致的密码',
    ),
    'new_register_password_mismatch': stLocalizedTextFromZhHans('密码不一致'),
    'real_name': stLocalizedTextFromZhHans('真实姓名'),
    'new_register_please_input_name': stLocalizedTextFromZhHans('请输入真实姓名'),
    'card_type': stLocalizedTextFromZhHans('证件类型'),
    'card_type_hint': stLocalizedTextFromZhHans('选择证件类型'),
    'select_id_type': stLocalizedTextFromZhHans('选择证件类型'),
    'id_card': stLocalizedTextFromZhHans('身份证'),
    'passport': stLocalizedTextFromZhHans('护照'),
    'driver_license': stLocalizedTextFromZhHans('驾驶证'),
    'card_num': stLocalizedTextFromZhHans('证件号码'),
    'new_register_please_input_card_num': stLocalizedTextFromZhHans('请填写证件号码'),
    'id_card_error': stLocalizedTextFromZhHans('证件号位数错误'),
    'new_register_no_receive_phone_code': stLocalizedTextFromZhHans(
      '请核对手机号，检查短信拦截/垃圾箱',
    ),
    'new_register_no_receive_email_code': stLocalizedTextFromZhHans(
      '请检查垃圾邮件，如仍未收到，请重试或联系客服。',
    ),
    'next': stLocalizedTextFromZhHans('下一步'),
    'or': stLocalizedTextFromZhHans('或'),
    'have_read_and_agree': stLocalizedTextFromZhHans('我已阅读并同意'),
    'user_agreement': stLocalizedTextFromZhHans('《用户协议》'),
    'privacy_policy': stLocalizedTextFromZhHans('《隐私政策》'),
    'and': stLocalizedTextFromZhHans('和'),
    'verification_code_not_received': stLocalizedTextFromZhHans('没收到验证码？'),
    'cancel': stLocalizedTextFromZhHans('取消'),
    'online_custom': stLocalizedTextFromZhHans('在线客服'),
    'requestfail': stLocalizedTextFromZhHans('数据加载失败'),
    'authorization_fail': stLocalizedTextFromZhHans('授权失败'),
    'flutter_prompt_address_not_configured': stLocalizedTextFromZhHans(
      '{title}地址未配置',
    ),
    'flutter_prompt_oauth_sdk_required': stLocalizedTextFromZhHans(
      '{provider} 登录需要接入对应 Flutter SDK 后完成',
    ),
    'flutter_prompt_register_config_load_failed': stLocalizedTextFromZhHans(
      '加载注册配置失败',
    ),
  };

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _idNumController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _idNumFocus = FocusNode();

  bool _loadingConfig = true;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;
  bool _usePhone = true;
  bool _codeSentOnce = false;
  bool _cleaningName = false;

  RegisterUiState _ui = RegisterUiState();
  RegisterCountry _country = CountryModel.china;
  String _vcodeSessionId = '';
  String _vcodeId = '';
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  List<String> _idTypeOptions = const ['ID_CARD'];
  int _idTypeIndex = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(
          () => _agreeTerms = prefs.getBool(_kPrivacyAgreedKey) ?? false,
        );
      }
    });
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _codeController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
    _nameController.addListener(_onNameFieldChanged);
    _idNumController.addListener(_onFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
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

  AuthValidatorMessages get _validatorMessages =>
      AuthValidatorMessages.fromMap(_localized);

  String _agreementIntroText() {
    final value = _t('have_read_and_agree');
    return value.endsWith(' ') ? value : '$value ';
  }

  String _policyTitle({required bool privacy}) {
    final text = privacy ? _t('privacy_policy') : _t('user_agreement');
    return text.replaceAll('《', '').replaceAll('》', '');
  }

  String _idTypeLabel(String code) {
    switch (code) {
      case 'ID_CARD':
        return _t('id_card');
      case 'PASSPORT':
        return _t('passport');
      case 'DRIVER_LICENSE':
        return _t('driver_license');
      default:
        return code;
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    final service = ref.read(stServiceProvider);
    try {
      await ref.read(countryManagerProvider.notifier).ensureLoaded();
      final selected = ref.read(effectiveSelectedCountryProvider);
      _country = selected;

      final sessionRaw = await service.requestVcodeSession();
      AuthApiHelpers.ensureOk(sessionRaw);
      final sessionData = AuthApiHelpers.unwrapLoginPayload(sessionRaw);
      _vcodeSessionId = '${sessionData['session_id'] ?? ''}';

      final configRaw = await service.getRegisterConfigList();
      AuthApiHelpers.ensureOk(configRaw);
      final configData = AuthApiHelpers.unwrapLoginPayload(configRaw);
      final configs = configData['configs'];
      final list = configs is List ? configs : <dynamic>[];

      if (mounted) {
        setState(() {
          _country = selected;
          _ui = parseRegisterUiState(
            configs: list,
            countryKey: selected.key,
            phoneFirstDefault: true,
          );
          _usePhone = _ui.showPhoneTabFirst;
          if (!_ui.mobileEnabled && _ui.emailEnabled) _usePhone = false;
          if (_ui.mobileEnabled && !_ui.emailEnabled) _usePhone = true;
          _applyIdTypeDefaults();
          _loadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingConfig = false);
        showStLocalizedToastByKey(
          context,
          'flutter_prompt_register_config_load_failed',
          fallback: _fallbackText['flutter_prompt_register_config_load_failed'],
        );
      }
    }
  }

  void _applyIdTypeDefaults() {
    final fields = _activeFields;
    final spec = _ui.spec(fields, 'id_type');
    if (spec != null && spec.options.isNotEmpty) {
      _idTypeOptions = spec.options;
      _idTypeIndex = AuthValidators.defaultIdTypeIndex(
        _idTypeOptions,
        _country.key,
      );
    }
  }

  List<RegisterFieldSpec> get _activeFields =>
      _usePhone ? _ui.phoneFields : _ui.emailFields;

  List<FocusNode> get _keyboardFocusNodes {
    final fields = _activeFields;
    return [
      if (_usePhone && _ui.fieldVisible(fields, 'tel')) _phoneFocus,
      if (!_usePhone && _ui.fieldVisible(fields, 'email')) _emailFocus,
      if (_shouldShowVerCode(fields)) _codeFocus,
      if (_ui.fieldVisible(fields, 'password')) _passwordFocus,
      if (_ui.fieldVisible(fields, 'confirm_password')) _confirmPasswordFocus,
      if (_ui.fieldVisible(fields, 'name')) _nameFocus,
      if (_ui.fieldVisible(fields, 'id_number')) _idNumFocus,
    ];
  }

  int get _loginMode => _usePhone ? 1 : 2;

  String get _currentRegisteredAccount {
    if (_loginMode == 1) {
      return _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
    }
    if (_loginMode == 2) return _emailController.text.trim();
    return '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _idNumController.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _nameFocus.dispose();
    _idNumFocus.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final next = await showRegisterCountryPicker(context, current: _country);
    if (next == null || !mounted) return;
    ref.read(countryManagerProvider.notifier).setSelectedCountry(next);
    setState(() {
      _country = next;
      _applyIdTypeDefaults();
    });
    await _reloadConfigForCountry(phoneFirstDefault: _usePhone);
  }

  void _onNameFieldChanged() {
    if (!_cleaningName) {
      _cleaningName = true;
      AuthNameInputFormatter.cleanControllerText(
        _nameController,
        countryKey: _country.key,
      );
      _cleaningName = false;
    }
    _onFieldChanged();
  }

  Future<void> _reloadConfigForCountry({
    required bool phoneFirstDefault,
  }) async {
    try {
      final configRaw = await ref
          .read(stServiceProvider)
          .getRegisterConfigList();
      AuthApiHelpers.ensureOk(configRaw);
      final configData = AuthApiHelpers.unwrapLoginPayload(configRaw);
      final configs = configData['configs'];
      if (configs is! List || !mounted) return;
      setState(() {
        _ui = parseRegisterUiState(
          configs: configs,
          countryKey: _country.key,
          phoneFirstDefault: phoneFirstDefault,
        );
        if (!_ui.mobileEnabled && _ui.emailEnabled) _usePhone = false;
        if (_ui.mobileEnabled && !_ui.emailEnabled) _usePhone = true;
        _applyIdTypeDefaults();
      });
    } catch (_) {}
  }

  Future<void> _pickIdType() async {
    final labels = _idTypeOptions.map(_idTypeLabel).toList();
    final idx = await showRegisterIdTypePicker(
      context,
      labels: labels,
      selectedIndex: _idTypeIndex,
    );
    if (idx != null && mounted) setState(() => _idTypeIndex = idx);
  }

  Future<bool> _sendRegisterCode() async {
    final service = ref.read(stServiceProvider);
    final h5 = ref.read(userStateProvider).h5AddressModel;
    final configuredCaptchaUrl = h5?.codeVerifyUrl.trim() ?? '';
    final captchaUrl = configuredCaptchaUrl.isEmpty
        ? 'localMini://codeverify'
        : configuredCaptchaUrl;
    final captchaBaseHost = service.dio.baseUrl.replaceFirst(
      RegExp(r'/violet/?$'),
      '',
    );
    final captchaBridgeUserInfo = await _captchaBridgeUserInfo(service);
    if (!mounted) return false;

    if (_usePhone) {
      final tel = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
      final captcha = await showAuthCaptchaDialog(
        context,
        url: captchaUrl,
        baseHost: captchaBaseHost,
        captchaApiKey: h5?.captchaApiKey ?? '',
        bridgeUserInfo: captchaBridgeUserInfo,
      );
      if (captcha == null) return false;
      AuthApiHelpers.ensureOk(
        await service.checkRegisterUnique(
          telAreaCode: _country.dialCode,
          tel: tel,
          country: _country.key,
        ),
      );
      if (!mounted) return false;
      _vcodeId = await AuthVerCodeRequests.sendRegisterSms(
        service: service,
        tel: tel,
        telAreaCode: _country.dialCode,
        vcodeSessionId: _vcodeSessionId,
        countryKey: _country.key,
        captchaId: '${captcha['id'] ?? ''}',
        captchaKey: '${captcha['captchaKey'] ?? ''}',
        captchaValue: '${captcha['value'] ?? ''}',
      );
    } else {
      final email = _emailController.text.trim();
      final captcha = await showAuthCaptchaDialog(
        context,
        url: captchaUrl,
        baseHost: captchaBaseHost,
        captchaApiKey: h5?.captchaApiKey ?? '',
        bridgeUserInfo: captchaBridgeUserInfo,
      );
      if (captcha == null) return false;
      AuthApiHelpers.ensureOk(
        await service.checkRegisterUnique(email: email, country: _country.key),
      );
      if (!mounted) return false;
      _vcodeId = await AuthVerCodeRequests.sendRegisterEmail(
        service: service,
        email: email,
        vcodeSessionId: _vcodeSessionId,
        countryKey: _country.key,
        captchaId: '${captcha['id'] ?? ''}',
        captchaKey: '${captcha['captchaKey'] ?? ''}',
        captchaValue: '${captcha['value'] ?? ''}',
      );
    }
    if (mounted) {
      setState(() => _codeSentOnce = true);
      STToast.show(context, _t('send_verification_code_success'));
    }
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

  Future<void> _setPrivacyAgreed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrivacyAgreedKey, value);
    if (mounted) setState(() => _agreeTerms = value);
  }

  Future<bool> _ensurePrivacy() async {
    if (_agreeTerms) return true;
    final ok = await showAuthPrivacyConfirmDialog(context);
    if (ok) await _setPrivacyAgreed(true);
    return ok;
  }

  Future<void> _handleNext() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!await _ensurePrivacy()) return;
    if (!mounted) return;

    final fields = _activeFields;
    if (_usePhone) {
      final err = AuthValidators.phoneError(
        _phoneController.text.trim().replaceAll(RegExp(r'\s'), ''),
        _country.dialCode,
        messages: _validatorMessages,
      );
      if (err != null) {
        STToast.show(context, err);
        return;
      }
    } else if (!AuthValidators.isEmailValid(_emailController.text.trim())) {
      STToast.show(context, _t('email_format_error'));
      return;
    }

    final pwdErr = AuthValidators.passwordFormatError(
      _passwordController.text,
      messages: _validatorMessages,
    );
    if (pwdErr != null) {
      STToast.show(context, pwdErr);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      STToast.show(context, _t('new_register_password_mismatch'));
      return;
    }

    if (_ui.fieldVisible(fields, 'id_number')) {
      final type = _idTypeOptions.isNotEmpty
          ? _idTypeOptions[_idTypeIndex.clamp(0, _idTypeOptions.length - 1)]
          : 'ID_CARD';
      if (!AuthValidators.idCardValid(
        idcard: _idNumController.text.trim(),
        type: type,
        areaCode: _country.dialCode,
      )) {
        STToast.show(context, _t('id_card_error'));
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final service = ref.read(stServiceProvider);
      await _checkRegisterUnique(service, fields);
      final validateRaw = await service.validateRegisterCode(
        code: _codeController.text.trim(),
        vcodeId: _vcodeId,
        areaCode: _country.dialCode,
        phone: _usePhone
            ? _phoneController.text.trim().replaceAll(RegExp(r'\s'), '')
            : '',
        mail: _usePhone ? '' : _emailController.text.trim(),
        type: _usePhone ? '1' : '2',
      );
      AuthApiHelpers.ensureOk(validateRaw);
      await _registerStart(service);
    } catch (e) {
      if (mounted) {
        showStLocalizedToast(context, AuthApiHelpers.userVisibleErrorSeed(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _checkRegisterUnique(
    STService service,
    List<RegisterFieldSpec> fields,
  ) async {
    final idType =
        _ui.fieldVisible(fields, 'id_type') && _idTypeOptions.isNotEmpty
        ? _idTypeOptions[_idTypeIndex.clamp(0, _idTypeOptions.length - 1)]
        : '';
    final idNumber = _ui.fieldVisible(fields, 'id_number')
        ? _idNumController.text.trim()
        : '';
    final raw = await service.checkRegisterUnique(
      email: _usePhone ? '' : _emailController.text.trim(),
      telAreaCode: _country.dialCode,
      tel: _usePhone
          ? _phoneController.text.trim().replaceAll(RegExp(r'\s'), '')
          : '',
      identityDocumentType: idType,
      identityDocumentNumber: idNumber,
      password: _passwordController.text,
      country: _country.key,
    );
    AuthApiHelpers.ensureOk(raw);
  }

  Future<void> _registerStart(STService service) async {
    final prefs = await SharedPreferences.getInstance();

    final fields = _activeFields;
    final idType = _idTypeOptions.isNotEmpty
        ? _idTypeOptions[_idTypeIndex.clamp(0, _idTypeOptions.length - 1)]
        : '';

    final params = <String, dynamic>{
      'oauth_token': '',
      'country': _country.key,
      'language': await UserPreferencePrefs.readAppLanguage(),
      'tel_area_code': _country.dialCode,
      'tel': _usePhone
          ? _phoneController.text.trim().replaceAll(RegExp(r'\s'), '')
          : '',
      'email': _usePhone ? '' : _emailController.text.trim(),
      'password': _passwordController.text,
      'verify_code': _codeController.text.trim(),
      'invite_code': await readIosRegisterInviteCode(),
      'vcode_session_id': _vcodeSessionId,
      'is_google_jwt': 0,
    };
    if (_ui.fieldVisible(fields, 'name')) {
      params['name'] = _nameController.text.trim();
      params['first_name'] = '';
      params['last_name'] = '';
    }
    if (_ui.fieldVisible(fields, 'id_type') && idType.isNotEmpty) {
      params['identity_document_type'] = idType;
    }
    if (_ui.fieldVisible(fields, 'id_number')) {
      params['identity_document_number'] = _idNumController.text.trim();
    }

    final raw = await service.registerStart(params);
    AuthApiHelpers.ensureOk(raw);
    await prefs.remove('STUserInviteCode');
    await prefs.remove('STUserTempInviteCode');
    final data = AuthApiHelpers.unwrapLoginPayload(raw);
    final result = '${data['result'] ?? ''}';
    final nextStep = '${data['next_step'] ?? ''}';
    final token = '${data['register_token'] ?? ''}';
    final registerTokenHeader = UserState.pickString(data, ['token']) ?? token;

    if (!mounted) return;

    final outcome = parseRegisterOutcome(result);
    final registeredAccount = _currentRegisteredAccount;
    if (outcome == RegisterOutcome.inProgress && nextStep == 'IDENTITY') {
      final identityFields = _usePhone
          ? _ui.identityFieldsForPhone()
          : _ui.identityFieldsForEmail();
      context.push(
        '/register/identity',
        extra: {
          'fields': identityFields,
          'registerToken': registerTokenHeader,
          'loginMode': _loginMode,
          'registeredAccount': registeredAccount,
        },
      );
      return;
    }

    if (outcome == RegisterOutcome.success) {
      final loginToken = UserState.pickString(data, ['token']) ?? '';
      if (loginToken.isNotEmpty) {
        service.dio.setAuthToken(loginToken);
      }
      final currentRaw = await service.getCurrentTransAccount();
      AuthApiHelpers.ensureOk(currentRaw);
      final currentData = AuthApiHelpers.unwrapLoginPayload(currentRaw);
      ref
          .read(userStateProvider.notifier)
          .updateTransactionAccounts(currentData);
      await ref
          .read(startupDeviceRegistrarProvider)
          .registerIfPossible(service);
      if (!mounted) return;
    }

    if (outcome == RegisterOutcome.success ||
        outcome == RegisterOutcome.rejected ||
        outcome == RegisterOutcome.pending) {
      context.push(
        '/register/result',
        extra: {
          'outcome': outcome!.index,
          'loginMode': _loginMode,
          'userInfo': data,
          'registeredAccount': registeredAccount,
        },
      );
    }
  }

  Future<void> _handleAppleOAuthTap() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await handleAppleOAuthFlow(
        ref: ref,
        context: context,
        countryKey: _country.key,
        uiState: _ui,
        vcodeSessionId: _vcodeSessionId,
        retryFailedRouter: false,
      );
    } catch (e) {
      if (mounted) {
        showStLocalizedToast(context, AuthApiHelpers.userVisibleErrorSeed(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  bool get _idTypeHasValue {
    if (_idTypeOptions.isEmpty) return false;
    return _idTypeIndex >= 0 && _idTypeIndex < _idTypeOptions.length;
  }

  bool _shouldShowVerCode(List<RegisterFieldSpec> fields) {
    if (_usePhone) return _ui.fieldVisible(fields, 'tel');
    return _ui.fieldVisible(fields, 'email');
  }

  bool get _canSubmit {
    if (_loadingConfig) return false;
    final f = _activeFields;
    if (_ui.fieldRequired(f, 'country') && _country.key.isEmpty) return false;
    if (_usePhone && _ui.fieldRequired(f, 'tel')) {
      if (_phoneController.text.trim().isEmpty) return false;
    }
    if (!_usePhone && _ui.fieldRequired(f, 'email')) {
      if (_emailController.text.trim().isEmpty) return false;
    }
    if (_shouldShowVerCode(f) && _codeController.text.trim().isEmpty) {
      return false;
    }
    if (_ui.fieldRequired(f, 'password') && _passwordController.text.isEmpty) {
      return false;
    }
    if (_ui.fieldRequired(f, 'confirm_password') &&
        _confirmPasswordController.text.isEmpty) {
      return false;
    }
    if (_ui.fieldRequired(f, 'name') && _nameController.text.trim().isEmpty) {
      return false;
    }
    if (_ui.fieldRequired(f, 'id_type') && !_idTypeHasValue) {
      return false;
    }
    if (_ui.fieldRequired(f, 'id_number') &&
        _idNumController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  void _showNoReceiveCodeHelp() {
    final msg = _usePhone
        ? _t('new_register_no_receive_phone_code')
        : _t('new_register_no_receive_email_code');
    showAuthNotReceiveCodeDialog(
      context,
      message: msg,
      title: _t('verification_code_not_received'),
      closeText: _t('cancel'),
      serviceText: _t('online_custom'),
      onService: () => CustomerServiceRoute.open(context, ref),
    );
  }

  bool get _canSendVerCode {
    if (_usePhone) {
      return _phoneController.text
          .trim()
          .replaceAll(RegExp(r'\s'), '')
          .isNotEmpty;
    }
    return _emailController.text.trim().isNotEmpty;
  }

  Future<void> _openPolicyWeb({required bool privacy}) async {
    final title = _policyTitle(privacy: privacy);
    final opened = await PolicyLinkRoute.open(
      context,
      ref,
      privacy: privacy,
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

  Widget _registerLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AuthUi.registerLabelFieldGap),
    child: Text(text, style: AuthUi.registerLabelStyle(context)),
  );

  int _formSection = 0;

  void _onBackPressed() {
    context.popOrGoRoot();
  }

  Widget _nextSectionGap(List<RegisterFieldSpec> fields) {
    final isCountryFirst =
        _formSection == 0 && _ui.fieldVisible(fields, 'country');
    final gap = SizedBox(
      height: isCountryFirst
          ? AuthUi.registerCountryGap
          : AuthUi.registerFieldGap,
    );
    _formSection++;
    return gap;
  }

  Widget _passwordEye(bool hidden, VoidCallback onTap) {
    return IconButton(
      padding: const EdgeInsets.only(right: 10),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 24),
      icon: AuthUi.authAsset(
        hidden ? 'st_password_eye_hide' : 'st_password_eye_show',
        width: 24,
        height: 24,
        fallbackIcon: hidden
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fields = _activeFields;
    _formSection = 0;

    return Stack(
      children: [
        STBaseScaffold(
          showNavigationBar: true,
          backgroundColor: AuthUi.pageBg(context),
          centerTitle: true,
          title: _t('new_register_account_registration'),
          onBack: _onBackPressed,
          keyboardFocusNodes: _keyboardFocusNodes,
          leading: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: AuthUi.label(context),
            ),
            onPressed: _onBackPressed,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                icon: AuthUi.authAsset(
                  'st_login_service_new',
                  width: 24,
                  height: 24,
                  fallbackIcon: Icons.headset_mic_outlined,
                  fallbackColor: AuthUi.label(context),
                  tintColor: AuthUi.label(context),
                ),
                onPressed: () => CustomerServiceRoute.open(context, ref),
              ),
            ),
          ],
          body: _loadingConfig
              ? const Center(child: STLoadAnimationView())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AuthUi.padH,
                          0,
                          AuthUi.padH,
                          _ui.showThirdLogin ? 12 : 0,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AuthUi.registerTitleTop),
                              Text(
                                _t('new_register_create_account'),
                                style: AuthUi.registerTitleStyle(context),
                              ),
                              const SizedBox(
                                height: AuthUi.registerSubtitleGap,
                              ),
                              Text(
                                _t('new_register_start_trading'),
                                style: AuthUi.registerSubtitleStyle(context),
                              ),
                              if (_ui.showModeTabs) ...[
                                const SizedBox(height: AuthUi.registerTabGap),
                                AuthRegisterModeTabs(
                                  phoneSelected: _usePhone,
                                  onPhone: () {
                                    if (!_ui.mobileEnabled) return;
                                    setState(() => _usePhone = true);
                                  },
                                  onEmail: () {
                                    if (!_ui.emailEnabled) return;
                                    setState(() => _usePhone = false);
                                  },
                                  emailLabel: _t('email'),
                                  phoneLabel: _t('phone'),
                                ),
                              ],
                              if (_ui.fieldVisible(fields, 'country')) ...[
                                _nextSectionGap(fields),
                                _registerLabel(context, _t('country_area')),
                                AuthRegisterPickerTile(
                                  title: _country.name,
                                  flagUrl: _country.flagUrl,
                                  flagEmoji: _country.flag,
                                  enabled: _ui.fieldEditable(fields, 'country'),
                                  onTap: _pickCountry,
                                ),
                              ],
                              if (_usePhone &&
                                  _ui.fieldVisible(fields, 'tel')) ...[
                                _nextSectionGap(fields),
                                _registerLabel(context, _t('phone_number')),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthRegisterAreaCodeTile(
                                      dialCode: _country.dialCode,
                                      flagUrl: _country.flagUrl,
                                      flagEmoji: _country.flag,
                                      enabled: _ui.fieldEditable(fields, 'tel'),
                                      onTap: _pickCountry,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: _phoneField(context)),
                                  ],
                                ),
                              ],
                              if (!_usePhone &&
                                  _ui.fieldVisible(fields, 'email')) ...[
                                _nextSectionGap(fields),
                                _registerLabel(context, _t('email')),
                                AuthRegisterEmailField(
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  enabled: _ui.fieldEditable(fields, 'email'),
                                  onChanged: _onFieldChanged,
                                  hintText: _t('please_input_email'),
                                  validator: (v) {
                                    if (!_ui.fieldRequired(
                                      _activeFields,
                                      'email',
                                    )) {
                                      return null;
                                    }
                                    if (!AuthValidators.isEmailValid(
                                      v?.trim() ?? '',
                                    )) {
                                      return _t('email_format_error');
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              if (_shouldShowVerCode(fields)) ...[
                                _nextSectionGap(fields),
                                Row(
                                  // 1. 设置垂直方向重心对齐 (默认即为 center，但显式写出更清晰)
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  // 2. 主轴(水平)起始对齐，确保内容从左开始排列，方便控制间距
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AuthUi.registerLabelFieldGap,
                                      ),
                                      child: Text(
                                        _t('verify_code'),
                                        style: AuthUi.registerLabelStyle(
                                          context,
                                        ),
                                      ),
                                    ),
                                    //文字部分
                                    if (_codeSentOnce) ...[
                                      // 3. 设置固定的水平间距为 10px
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: _showNoReceiveCodeHelp,
                                        child: AuthUi.authAsset(
                                          'st_new_reg_code_help',
                                          width: 12,
                                          height: 12,
                                          fallbackIcon: Icons.help_outline,
                                          fallbackColor: AuthUi.hint(context),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                AuthRegisterVerCodeField(
                                  controller: _codeController,
                                  focusNode: _codeFocus,
                                  canSend: _canSendVerCode,
                                  onSend: _sendRegisterCode,
                                  hintText: _t('please_input_code'),
                                  sendLabel: _t('get_verification_code'),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return _t('please_input_code');
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              if (_ui.fieldVisible(fields, 'password')) ...[
                                _nextSectionGap(fields),
                                _registerLabel(context, _t('set_pwd')),
                                _passwordField(),
                              ],
                              if (_ui.fieldVisible(
                                fields,
                                'confirm_password',
                              )) ...[
                                _nextSectionGap(fields),
                                _registerLabel(
                                  context,
                                  _t('new_register_password_confirm'),
                                ),
                                _confirmPasswordField(),
                              ],
                              if (_ui.fieldVisible(fields, 'name')) ...[
                                _nextSectionGap(fields),
                                _registerLabel(context, _t('real_name')),
                                TextFormField(
                                  controller: _nameController,
                                  focusNode: _nameFocus,
                                  enabled: _ui.fieldEditable(fields, 'name'),
                                  textAlignVertical: TextAlignVertical.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AuthUi.label(context),
                                  ),
                                  inputFormatters: [
                                    AuthNameInputFormatter(
                                      countryKey: _country.key,
                                    ),
                                  ],
                                  decoration: AuthUi.registerField(
                                    context: context,
                                    hintText: _t(
                                      'new_register_please_input_name',
                                    ),
                                  ),
                                ),
                              ],
                              if (_ui.fieldVisible(fields, 'id_type')) ...[
                                _nextSectionGap(fields),
                                _registerLabel(context, _t('card_type')),
                                _idTypePicker(
                                  enabled: _ui.fieldEditable(fields, 'id_type'),
                                ),
                              ],
                              if (_ui.fieldVisible(fields, 'id_number')) ...[
                                _nextSectionGap(fields),
                                _registerLabel(context, _t('card_num')),
                                TextFormField(
                                  controller: _idNumController,
                                  focusNode: _idNumFocus,
                                  enabled: _ui.fieldEditable(
                                    fields,
                                    'id_number',
                                  ),
                                  keyboardType: TextInputType.visiblePassword,
                                  textAlignVertical: TextAlignVertical.center,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  inputFormatters: [
                                    _RegisterIdNumberInputFormatter(
                                      countryKey: _country.key,
                                    ),
                                  ],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AuthUi.label(context),
                                  ),
                                  decoration: AuthUi.registerField(
                                    context: context,
                                    hintText: _t(
                                      'new_register_please_input_card_num',
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_ui.showThirdLogin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 29),
                        child: AuthRegisterThirdLoginBar(
                          showGoogle: _ui.showGoogleOAuth,
                          showApple: _ui.showAppleOAuth,
                          onGoogle: () => _handleUnavailableOAuthTap('Google'),
                          onApple: _handleAppleOAuthTap,
                          orLabel: _t('or'),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuthUi.registerNextBtnHPad,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: AuthUi.primaryBtnH,
                        child: FilledButton(
                          onPressed: (_submitting || !_canSubmit)
                              ? null
                              : _handleNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            disabledBackgroundColor: primary.withValues(
                              alpha: 0.2,
                            ),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.9,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                                  _t('next'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: AuthPrivacyNoticeView(
                        agreed: _agreeTerms,
                        onChanged: (v) => _setPrivacyAgreed(v),
                        onUserAgreement: () => _openPolicyWeb(privacy: false),
                        onPrivacyPolicy: () => _openPolicyWeb(privacy: true),
                        intro: _agreementIntroText(),
                        userAgreement: _t('user_agreement'),
                        conjunction: _t('and'),
                        privacyPolicy: _t('privacy_policy'),
                      ),
                    ),
                    SizedBox(
                      height:
                          AuthUi.registerNoticeBottom +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                  ],
                ),
        ),
        if (_submitting)
          const STActionRefreshingHud(
            key: ValueKey('auth-action-refreshing-hud'),
          ),
      ],
    );
  }

  Widget _phoneField(BuildContext context) {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocus,
      enabled: _ui.fieldEditable(_activeFields, 'tel'),
      keyboardType: TextInputType.phone,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: AuthUi.registerField(
        context: context,
        hintText: _t('phone_number_input'),
      ),
      validator: (v) {
        if (!_ui.fieldRequired(_activeFields, 'tel')) return null;
        return AuthValidators.phoneError(
          v?.trim() ?? '',
          _country.dialCode,
          messages: _validatorMessages,
        );
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      enabled: _ui.fieldEditable(_activeFields, 'password'),
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
      decoration: AuthUi.registerField(
        context: context,
        hintText: _t('new_register_password_placehorder'),
        suffixIcon: _passwordEye(
          _obscurePassword,
          () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (!_ui.fieldRequired(_activeFields, 'password')) return null;
        if (v == null || v.isEmpty) return _t('password_input');
        return AuthValidators.passwordFormatError(
          v,
          messages: _validatorMessages,
        );
      },
    );
  }

  Widget _confirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      focusNode: _confirmPasswordFocus,
      obscureText: _obscureConfirm,
      enabled: _ui.fieldEditable(_activeFields, 'confirm_password'),
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(fontSize: 15, color: AuthUi.label(context)),
      decoration: AuthUi.registerField(
        context: context,
        hintText: _t('new_register_password_confirm_placehorder'),
        suffixIcon: _passwordEye(
          _obscureConfirm,
          () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),
      validator: (v) {
        if (!_ui.fieldRequired(_activeFields, 'confirm_password')) return null;
        if (v != _passwordController.text) {
          return _t('new_register_password_mismatch');
        }
        return null;
      },
    );
  }

  Widget _idTypePicker({required bool enabled}) {
    final label = _idTypeOptions.isNotEmpty
        ? _idTypeLabel(_idTypeOptions[_idTypeIndex])
        : '';
    return AuthRegisterPickerTile(
      title: label,
      placeholder: _t('card_type_hint'),
      enabled: enabled,
      onTap: _pickIdType,
    );
  }
}

/// 对齐 iOS `STLoginTextFieldTypeIdCard`：
/// 只允许数字和英文，自动大写；中港澳台证件号最长 18 位。
class _RegisterIdNumberInputFormatter extends TextInputFormatter {
  _RegisterIdNumberInputFormatter({required this.countryKey});

  final String countryKey;

  static final _allowed = RegExp(r'[0-9A-Z]');
  static const _limitedCountries = {'CN', 'HK', 'MO', 'TW'};

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _filterText(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: _filteredSelectionFor(newValue, text),
      composing: TextRange.empty,
    );
  }

  String _filterText(String source) {
    final buffer = StringBuffer();
    for (final rune in source.toUpperCase().runes) {
      final ch = String.fromCharCode(rune);
      if (_allowed.hasMatch(ch)) buffer.write(ch);
    }
    var text = buffer.toString();
    if (_limitedCountries.contains(countryKey) && text.length > 18) {
      text = text.substring(0, 18);
    }
    return text;
  }

  TextSelection _filteredSelectionFor(TextEditingValue value, String filtered) {
    final selection = value.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: filtered.length);
    }
    return TextSelection(
      baseOffset: _filteredOffsetFor(value.text, selection.baseOffset),
      extentOffset: _filteredOffsetFor(value.text, selection.extentOffset),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  int _filteredOffsetFor(String source, int offset) {
    if (offset < 0) return _filterText(source).length;
    final clamped = offset.clamp(0, source.length).toInt();
    return _filterText(source.substring(0, clamped)).length;
  }
}
