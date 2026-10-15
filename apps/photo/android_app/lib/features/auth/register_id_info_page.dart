import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_state.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/services/startup_device_registrar.dart';
import '../../shared/widgets/st_toast.dart';
import 'auth_api_helpers.dart';
import 'auth_name_input_formatter.dart';
import 'auth_theme.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'register_config.dart';
import 'register_country.dart';

/// 注册身份补充页（对齐 iOS `STIdInfoViewController`）
class RegisterIdInfoPage extends ConsumerStatefulWidget {
  const RegisterIdInfoPage({
    super.key,
    required this.fields,
    required this.registerToken,
    this.loginMode = 1,
    this.registeredAccount = '',
  });

  final List<Map<String, dynamic>> fields;
  final String registerToken;
  final int loginMode;
  final String registeredAccount;

  @override
  ConsumerState<RegisterIdInfoPage> createState() => _RegisterIdInfoPageState();
}

class _RegisterIdInfoPageState extends ConsumerState<RegisterIdInfoPage> {
  static const Map<String, String> _fallbackText = {
    'new_register_account_registration': '开户注册',
    'identity_information': '身份信息',
    'new_register_input_real_identity_info': '请填写真实身份信息以确保资金安全',
    'new_register_card_photo': '证件图片',
    'new_register_upload_card_front': '上传证件正面照',
    'new_register_upload_card_back': '上传证件背面照',
    'new_register_check_example': '查看示例',
    'country_area': '国家/地区',
    'real_name': '真实姓名',
    'new_register_please_input_name': '请输入真实姓名',
    'card_type': '证件类型',
    'select_id_type': '选择证件类型',
    'id_card': '身份证',
    'passport': '护照',
    'driver_license': '驾驶证',
    'card_num': '证件号码',
    'new_register_please_input_card_num': '请填写证件号码',
    'id_card_error': '证件号位数错误',
    'next': '下一步',
    'sel_photo': '选择照片',
    'from_album': '从相册选择',
    'take_photo': '拍照',
    'contact_customer_service': '联系客服',
  };

  final _nameCtrl = TextEditingController();
  final _idNumCtrl = TextEditingController();

  RegisterCountry _country = CountryModel.china;
  List<String> _idTypeOptions = const ['ID_CARD'];
  int _idTypeIndex = 0;
  bool _submitting = false;
  int _formSection = 0;

  bool _showName = false;
  bool _showCountry = false;
  bool _showIdType = false;
  bool _showIdNum = false;
  bool _showIdImage = false;
  bool _needName = false;
  bool _needCountry = false;
  bool _needIdType = false;
  bool _needIdNum = false;
  bool _needIdImage = false;
  bool _cleaningName = false;

  final String _frontImageUrl = '';
  final String _backImageUrl = '';
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  @override
  void initState() {
    super.initState();
    ref.read(stServiceProvider).dio.setRegisterToken(widget.registerToken);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(countryManagerProvider.notifier).ensureLoaded();
      final selected = ref.read(effectiveSelectedCountryProvider);
      if (mounted) setState(() => _country = selected);
    });
    _parseFields();
    _nameCtrl.addListener(_onNameChanged);
    _idNumCtrl.addListener(() => setState(() {}));
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

  String _localizedIdTypeLabel(String code) {
    switch (code) {
      case 'ID_CARD':
        return _t('id_card');
      case 'PASSPORT':
        return _t('passport');
      case 'DRIVER_LICENSE':
        return _t('driver_license');
      default:
        return AuthValidators.idTypeLabel(code);
    }
  }

  void _parseFields() {
    const order = ['id_image', 'country', 'name', 'id_type', 'id_number'];
    final visible = <Map<String, dynamic>>[];
    for (final f in widget.fields) {
      final v = f['visible'];
      if (v == true || v == 1) visible.add(f);
    }
    final sorted = <Map<String, dynamic>>[];
    for (final code in order) {
      for (final f in visible) {
        if ('${f['code']}' == code) {
          sorted.add(f);
          break;
        }
      }
    }
    for (final f in sorted) {
      final code = '${f['code']}';
      final req = f['required'] == true || f['required'] == 1;
      switch (code) {
        case 'name':
          _showName = true;
          _needName = req;
          break;
        case 'country':
          _showCountry = true;
          _needCountry = req;
          break;
        case 'id_type':
          _showIdType = true;
          _needIdType = req;
          final opts = f['options'];
          if (opts is List && opts.isNotEmpty) {
            _idTypeOptions = opts.map((e) => '$e').toList();
            _idTypeIndex = AuthValidators.defaultIdTypeIndex(
              _idTypeOptions,
              _country.key,
            );
          }
          break;
        case 'id_number':
          _showIdNum = true;
          _needIdNum = req;
          break;
        case 'id_image':
          _showIdImage = true;
          _needIdImage = req;
          break;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idNumCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!_cleaningName) {
      _cleaningName = true;
      AuthNameInputFormatter.cleanControllerText(
        _nameCtrl,
        countryKey: _country.key,
      );
      _cleaningName = false;
    }
    if (mounted) setState(() {});
  }

  Widget _nextSectionGap() {
    final gap = SizedBox(
      height: _formSection == 0
          ? AuthUi.idInfoFirstFieldGap
          : AuthUi.registerFieldGap,
    );
    _formSection++;
    return gap;
  }

  bool get _canSubmit {
    if (_needName && _nameCtrl.text.trim().isEmpty) return false;
    if (_needCountry && _country.key.isEmpty) return false;
    if (_needIdType && _idTypeOptions.isEmpty) return false;
    if (_needIdNum && _idNumCtrl.text.trim().isEmpty) return false;
    if (_needIdImage && (_frontImageUrl.isEmpty || _backImageUrl.isEmpty)) {
      return false;
    }
    return true;
  }

  Future<void> _pickPhoto({required bool front}) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _t('sel_photo'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(_t('from_album')),
              onTap: () {
                Navigator.pop(ctx);
                _onPhotoPicked(front);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(_t('take_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _onPhotoPicked(front);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onPhotoPicked(bool front) {
    STToast.show(context, _t('contact_customer_service'));
  }

  Future<void> _submit() async {
    if (_needIdNum) {
      final type = _idTypeOptions.isNotEmpty
          ? _idTypeOptions[_idTypeIndex.clamp(0, _idTypeOptions.length - 1)]
          : 'ID_CARD';
      if (!AuthValidators.idCardValid(
        idcard: _idNumCtrl.text.trim(),
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
      final idType = _idTypeOptions.isNotEmpty
          ? _idTypeOptions[_idTypeIndex.clamp(0, _idTypeOptions.length - 1)]
          : '';
      final raw = await service.registerStep({
        'name': _nameCtrl.text.trim(),
        'first_name': '',
        'last_name': '',
        'identity_document_type': idType,
        'identity_document_number': _idNumCtrl.text.trim(),
        'ocr_match': 0,
      });
      AuthApiHelpers.ensureOk(raw);
      final data = AuthApiHelpers.unwrapLoginPayload(raw);
      final result = '${data['result'] ?? ''}';
      final outcome = parseRegisterOutcome(result);
      if (!mounted) return;
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
            'loginMode': widget.loginMode,
            'userInfo': data,
            'registeredAccount': widget.registeredAccount,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickCountry() async {
    final next = await showRegisterCountryPicker(context, current: _country);
    if (next == null || !mounted) return;
    setState(() {
      _country = next;
      _idTypeIndex = AuthValidators.defaultIdTypeIndex(
        _idTypeOptions,
        _country.key,
      );
    });
  }

  Future<void> _pickIdType() async {
    final labels = _idTypeOptions.map(_localizedIdTypeLabel).toList();
    final idx = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _t('select_id_type'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...List.generate(labels.length, (i) {
              return ListTile(
                title: Text(labels[i]),
                trailing: i == _idTypeIndex ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, i),
              );
            }),
          ],
        ),
      ),
    );
    if (idx != null && mounted) setState(() => _idTypeIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isLight = theme.brightness == Brightness.light;
    _formSection = 0;

    return Scaffold(
      backgroundColor: isLight ? Colors.white : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isLight
            ? Colors.white
            : theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : null,
        title: Text(
          _t('new_register_account_registration'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AuthUi.labelBlack(context),
          ),
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
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AuthUi.padH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AuthUi.idInfoTitleTop),
                  Text(
                    _t('identity_information'),
                    style: AuthUi.registerTitleStyle(context),
                  ),
                  const SizedBox(height: AuthUi.registerSubtitleGap),
                  Text(
                    _t('new_register_input_real_identity_info'),
                    style: AuthUi.registerSubtitleStyle(context),
                  ),
                  if (_showIdImage) ...[
                    _nextSectionGap(),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AuthUi.registerLabelFieldGap,
                      ),
                      child: Text(
                        _t('new_register_card_photo'),
                        style: AuthUi.registerLabelStyle(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: AuthRegisterIdCardUploadRow(
                        frontLabel: _t('new_register_upload_card_front'),
                        backLabel: _t('new_register_upload_card_back'),
                        onFrontTap: () => _pickPhoto(front: true),
                        onBackTap: () => _pickPhoto(front: false),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Center(
                      child: TextButton(
                        onPressed: () => showAuthIdCardExampleDialog(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _t('new_register_check_example'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AuthUi.linkBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                  if (_showCountry) ...[
                    _nextSectionGap(),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AuthUi.registerLabelFieldGap,
                      ),
                      child: Text(
                        _t('country_area'),
                        style: AuthUi.registerLabelStyle(context),
                      ),
                    ),
                    AuthRegisterPickerTile(
                      title: _country.name,
                      flagUrl: _country.flagUrl,
                      flagEmoji: _country.flag,
                      onTap: _pickCountry,
                    ),
                  ],
                  if (_showName) ...[
                    _nextSectionGap(),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AuthUi.registerLabelFieldGap,
                      ),
                      child: Text(
                        _t('real_name'),
                        style: AuthUi.registerLabelStyle(context),
                      ),
                    ),
                    TextFormField(
                      controller: _nameCtrl,
                      inputFormatters: [
                        AuthNameInputFormatter(countryKey: _country.key),
                      ],
                      style: TextStyle(
                        fontSize: 15,
                        color: AuthUi.labelBlack(context),
                      ),
                      decoration: AuthUi.registerField(
                        context: context,
                        hintText: _t('new_register_please_input_name'),
                      ),
                    ),
                  ],
                  if (_showIdType && _idTypeOptions.isNotEmpty) ...[
                    _nextSectionGap(),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AuthUi.registerLabelFieldGap,
                      ),
                      child: Text(
                        _t('card_type'),
                        style: AuthUi.registerLabelStyle(context),
                      ),
                    ),
                    AuthRegisterPickerTile(
                      title: _localizedIdTypeLabel(
                        _idTypeOptions[_idTypeIndex],
                      ),
                      onTap: _pickIdType,
                    ),
                  ],
                  if (_showIdNum) ...[
                    _nextSectionGap(),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AuthUi.registerLabelFieldGap,
                      ),
                      child: Text(
                        _t('card_num'),
                        style: AuthUi.registerLabelStyle(context),
                      ),
                    ),
                    TextFormField(
                      controller: _idNumCtrl,
                      style: TextStyle(
                        fontSize: 15,
                        color: AuthUi.labelBlack(context),
                      ),
                      decoration: AuthUi.registerField(
                        context: context,
                        hintText: _t('new_register_please_input_card_num'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AuthUi.registerNextBtnHPad,
              0,
              AuthUi.registerNextBtnHPad,
              AuthUi.registerNoticeBottom +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: AuthUi.primaryBtnH,
              child: FilledButton(
                onPressed: (_submitting || !_canSubmit) ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  disabledBackgroundColor: primary.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
