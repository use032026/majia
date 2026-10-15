import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/auth_status_model.dart';
import '../../core/models/country_model.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/country_manager_provider.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/auth_popups.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_network_image.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_name_input_formatter.dart';
import '../auth/select_country_page.dart';

enum _AuthStage { pre, upload, confirm, status }

enum _AuthDocType {
  idCard('ID_CARD', 'id_card', 'st_mine_auth_id'),
  passport('PASSPORT', 'passport', 'st_mine_auth_pass'),
  driverLicense('DRIVER_LICENSE', 'driver_license', 'st_mine_auth_drive');

  const _AuthDocType(this.value, this.textKey, this.asset);

  final String value;
  final String textKey;
  final String asset;
}

class _AuthText {
  const _AuthText._();

  static const fallbackText = {
    'identity': '身份认证',
    'auth_top_tip': '为了您的资金安全，取款前请完成实名认证。',
    'reside_area': '所在国家/地区',
    'card_type': '证件类型',
    'name': '姓名',
    'card_num': '证件号码',
    'next_step': '下一步',
    'sel_photo': '选择照片',
    'select_from_album': '从相册选择',
    'take_photo': '拍照',
    'cancel': '取消',
    'identity_submit_wait_title': '审核中',
    'identity_submit_wait_sub': '我们已收到您提交的材料，正在审核中，请耐心等待。',
    'identity_submit_failed_title': '认证失败',
    'reason': '原因：',
    'confirm': '确定',
    'upload_card_title': '上传身份证件',
    'upload_card_tip': '请确保证件完整无遮挡，信息清晰可见。',
    'id_card': '身份证',
    'passport': '护照',
    'driver_license': '驾驶证',
    'recommend': '推荐',
    'id_card_forward': '人像面',
    'id_card_back': '国徽面',
    'card_photo': '证件照片',
    'identity_info': '身份信息',
    'modify': '修改',
    'submit': '提交',
    're_apply': '重新申请',
    'see_an_example': '查看示例',
    'flutter_auth_enter_name': '请输入姓名',
    'flutter_auth_enter_id_number': '请输入证件号码',
    'flutter_auth_submitting': '提交中...',
    'flutter_auth_camera_unauthorized': '未授权使用相机',
    'flutter_auth_camera_permission_hint': '请在系统设置中允许“相机”权限，然后重试。',
  };
}

/// 身份认证 — 对齐 iOS `STAuthPreController` / `STAuthController` /
/// `STAuthConfirmController`
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _idFocus = FocusNode();
  final _picker = ImagePicker();

  _AuthStage _stage = _AuthStage.pre;
  _AuthDocType _docType = _AuthDocType.idCard;
  CountryModel? _countryModel;
  Map<String, dynamic>? _statusDoc;

  bool _loading = true;
  bool _busy = false;
  bool _uploadingFront = false;
  bool _uploadingBack = false;
  String _frontUrl = '';
  String _backUrl = '';
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  bool _cleaningName = false;
  String? _localizedLanguageCode;
  Map<String, String> _localized = _AuthText.fallbackText;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _nameCtrl.addListener(_onNameChanged);
    _idCtrl.addListener(_updateForm);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _idCtrl.removeListener(_updateForm);
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _nameFocus.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  void _updateForm() {
    if (mounted) setState(() {});
  }

  void _onNameChanged() {
    if (!_cleaningName) {
      _cleaningName = true;
      AuthNameInputFormatter.cleanControllerText(
        _nameCtrl,
        countryKey: _countryCode,
      );
      _cleaningName = false;
    }
    _updateForm();
  }

  Future<void> _bootstrap() async {
    try {
      final service = ref.read(stServiceProvider);
      await ref.read(countryManagerProvider.notifier).ensureLoaded();

      final user = ref.read(userStateProvider);
      var userName = user.nickname.trim();
      CountryModel? model;
      if (user.isExplicitlyLoggedIn) {
        await ref
            .read(countryManagerProvider.notifier)
            .syncLoggedInCountry(userId: user.userId);
        model = ref.read(countryManagerProvider).loggedInCountry;
      }
      try {
        final profile = await service.getUserProfile();
        final data = profile['data'];
        if (data is Map<String, dynamic>) {
          final profileName = UserState.pickString(data, [
            'name',
            'real_name',
            'realName',
            'true_name',
            'trueName',
            'fullname',
            'full_name',
          ])?.trim();
          if (profileName != null && profileName.isNotEmpty) {
            userName = profileName;
          }
          final countryKey = UserState.pickString(data, ['country']) ?? 'CN';
          if (model == null) {
            await syncCountryManagerFromProfile(
              ref.read(countryManagerProvider.notifier),
              userId: user.userId,
              countryKey: countryKey,
            );
            model =
                ref.read(countryManagerProvider).loggedInCountry ??
                ref
                    .read(countryManagerProvider.notifier)
                    .countryByKey(countryKey);
          }
        }
      } catch (_) {}
      model ??= ref.read(effectiveSelectedCountryProvider);

      Map<String, dynamic>? doc;
      final docs = await service.getIdentityStatus();
      if (docs.isNotEmpty && docs.first is Map) {
        doc = Map<String, dynamic>.from(docs.first as Map);
      }

      if (!mounted) return;
      setState(() {
        if (_nameCtrl.text.trim().isEmpty && userName.isNotEmpty) {
          _nameCtrl.text = userName;
        }
        _countryModel = model;
        _statusDoc = doc;
        _stage = doc == null ? _AuthStage.pre : _AuthStage.status;
        _loading = false;
      });
      if (doc != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showStatusPop(doc!),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(stUserVisibleErrorMessage(e));
    }
  }

  int get _statusValue => int.tryParse('${_statusDoc?['status'] ?? ''}') ?? -1;

  bool get _isPassport => _docType == _AuthDocType.passport;

  bool get _canPreNext {
    return (_countryModel?.value.isNotEmpty ?? false) &&
        _nameCtrl.text.trim().isNotEmpty;
  }

  bool get _canUploadNext {
    if (_isPassport) return _frontUrl.isNotEmpty;
    return _frontUrl.isNotEmpty && _backUrl.isNotEmpty;
  }

  String get _countryCode =>
      (_countryModel?.key.isNotEmpty ?? false) ? _countryModel!.key : 'CN';

  String get _areaCode =>
      (_countryModel?.dialCode ?? '+86').replaceAll('+', '');

  List<_AuthDocType> get _docTypes {
    return _docTypesForCountry(_countryCode);
  }

  List<_AuthDocType> _docTypesForCountry(String countryCode) {
    if (countryCode.toUpperCase() == 'CN') return const [_AuthDocType.idCard];
    return const [
      _AuthDocType.idCard,
      _AuthDocType.passport,
      _AuthDocType.driverLicense,
    ];
  }

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_AuthText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _AuthText.fallbackText[key] ?? key;

  String _docTypeLabel(_AuthDocType type) => _t(type.textKey);

  Future<void> _pickCountry() async {
    final next = await openSelectCountryPage(
      context,
      selectedCountryKey: _countryModel?.key,
    );
    if (next == null || !mounted) return;
    setState(() {
      _countryModel = next;
    });
  }

  Future<void> _preNext() async {
    final name = _nameCtrl.text.trim();
    final id = _idCtrl.text.trim();
    if (name.length > 24) {
      showStLocalizedToast(context, '姓名长度错误');
      return;
    }
    if (RegExp(r'[0-9!-/:-@\[-`{-~]').hasMatch(name)) {
      showStLocalizedToast(context, '姓名不能包含数字或特殊符号。');
      return;
    }
    if (!_idCardValid(id, _docType.value, _areaCode)) {
      showStLocalizedToast(context, '证件号位数错误');
      return;
    }
    setState(() => _stage = _AuthStage.upload);
  }

  bool _idCardValid(String id, String type, String areaCode) {
    if (id.isEmpty || type.isEmpty || areaCode.isEmpty) return false;
    if (type == 'ID_CARD') {
      switch (areaCode) {
        case '86':
          return RegExp(
            r'(^[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[1-2]\d|3[0-1])\d{3}(\d|X|x)$)|(^[1-9]\d{5}\d{2}(0[1-9]|1[0-2])(0[1-9]|[1-2]\d|3[0-1])\d{3}$)',
          ).hasMatch(id);
        case '852':
          return RegExp(
            r'^[A-Z]{1,2}[0-9]{6}(\([0-9A]\)|[0-9A])?$',
          ).hasMatch(id);
        case '81':
        case '84':
        case '60':
          return RegExp(r'^[0-9]{12}$').hasMatch(id);
        case '853':
          return RegExp(r'^[0-9]{7}[0-9A-Za-z]{1}$').hasMatch(id);
        case '1':
          return RegExp(
            r'^(?!000|666|9\d{2})\d{3}-(?!00)\d{2}-(?!0000)\d{4}$',
          ).hasMatch(id);
        default:
          return true;
      }
    }
    if (type == 'PASSPORT') return id.length <= 16;
    return true;
  }

  Future<void> _choosePhoto({required bool front}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(15, 0, 15, 8),
            child: Material(
              color: context.adaptiveCard,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        _t('sel_photo'),
                        style: TextStyle(
                          fontSize: 15,
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                    ),
                  ),
                  _sheetItem(
                    _t('select_from_album'),
                    () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  Divider(height: 1, color: context.adaptiveDivider),
                  _sheetItem(
                    _t('take_photo'),
                    () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                  Divider(height: 1, color: context.adaptiveDivider),
                  _sheetItem(_t('cancel'), () => Navigator.pop(ctx)),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (source == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (_isPermissionError(e.code)) {
        _showPhotoPermissionHint(forCamera: source == ImageSource.camera);
        return;
      }
      _toast(stSanitizeUserVisibleText(e.message ?? e.code));
      return;
    } catch (e) {
      if (mounted) _toast(stSanitizeUserVisibleText(e.toString()));
      return;
    }
    if (picked == null) return;

    setState(() {
      if (front) {
        _uploadingFront = true;
      } else {
        _uploadingBack = true;
      }
    });
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref
          .read(stServiceProvider)
          .uploadIdentityImage(
            bytes: bytes,
            filename: picked.name,
            mimeType: _mimeTypeFor(picked.name),
          );
      if (!mounted) return;
      setState(() {
        if (front) {
          _frontUrl = url;
          _frontBytes = bytes;
        } else {
          _backUrl = url;
          _backBytes = bytes;
        }
      });
    } catch (e) {
      if (mounted) _toast(stSanitizeUserVisibleText(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingFront = false;
          _uploadingBack = false;
        });
      }
    }
  }

  String _mimeTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(stServiceProvider).submitAuth({
        'name': _nameCtrl.text.trim(),
        'type': _docType.value,
        'id_number': _idCtrl.text.trim(),
        if (!_isPassport) 'back_picture': _backUrl,
        'front_picture': _frontUrl,
      });
      ref
          .read(userStateProvider.notifier)
          .updateAuthStatus(const AuthStatusModel(status: 'pending'));
      if (!mounted) return;
      context.push(
        '/mine/commit_success',
        extra: const {'kind': 'auth'},
      );
    } catch (e) {
      if (mounted) _showAuthFailed(stUserVisibleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showStatusPop(Map<String, dynamic> doc) {
    if (!mounted) return;
    final status = int.tryParse('${doc['status'] ?? ''}');
    if (status == 0) {
      _showStatusDialog(
        title: _t('identity_submit_wait_title'),
        titleColor: const Color(0xFF00B57A),
        message: _t('identity_submit_wait_sub'),
        useWarnStyle: true,
      );
    } else if (status == 2) {
      final remark = '${doc['remark'] ?? ''}';
      _showStatusDialog(
        title: _t('identity_submit_failed_title'),
        titleColor: const Color(0xFFF95959),
        message: '${_t('reason')}$remark',
        useWarnStyle: true,
      );
    }
  }

  void _showAuthFailed(String title) {
    final safeTitle = stSanitizeUserVisibleText(title);
    _showStatusDialog(
      title: safeTitle,
      titleColor: const Color(0xFFF95959),
      message: '',
      useWarnStyle: true,
      buttonLabel: _t('confirm'),
    );
  }

  void _showStatusDialog({
    required String title,
    required Color titleColor,
    required String message,
    bool useWarnStyle = false,
    String? buttonLabel,
    Color? messageColor,
    VoidCallback? onButtonPressed,
  }) {
    if (useWarnStyle && titleColor == const Color(0xFFF95959)) {
      showAuthFailedDialog(
        context: context,
        title: title,
        reason: message,
        buttonLabel: buttonLabel ?? _t('confirm'),
        onConfirm: onButtonPressed,
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (useWarnStyle) ...[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Color(0xFFF7A500),
                ),
                const SizedBox(height: 11),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: messageColor ?? const Color(0xFF9A9DA2),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 42,
                width: 125,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onButtonPressed?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B57A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(buttonLabel ?? _t('confirm')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPermissionError(String code) {
    final normalized = code.toLowerCase();
    return normalized.contains('denied') ||
        normalized.contains('permission') ||
        normalized == 'photo_access_denied' ||
        normalized == 'camera_access_denied';
  }

  void _showPhotoPermissionHint({required bool forCamera}) {
    _showStatusDialog(
      title: forCamera ? _t('flutter_auth_camera_unauthorized') : '',
      titleColor: const Color(0xFFF95959),
      message: forCamera ? _t('flutter_auth_camera_permission_hint') : '',
      useWarnStyle: true,
      buttonLabel: _t('confirm'),
      onButtonPressed: () => _openAppSettings(),
    );
  }

  Future<void> _openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showStLocalizedToast(context, '未授权使用照片/相机权限，无法继续选择');
    }
  }

  void _toast(String message) {
    STToast.show(context, stSanitizeUserVisibleText(message));
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _t('identity'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextPrimary,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: context.adaptiveTextPrimary,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: context.adaptiveTextPrimary,
          ),
          onPressed: _handleBack,
        ),
      ),
      body: _loading ? const Center(child: STLoadAnimationView()) : _body(),
    );
  }

  void _handleBack() {
    if (_stage == _AuthStage.confirm) {
      setState(() => _stage = _AuthStage.upload);
    } else if (_stage == _AuthStage.upload) {
      setState(() => _stage = _AuthStage.pre);
    } else {
      context.pop();
    }
  }

  Widget _body() {
    switch (_stage) {
      case _AuthStage.pre:
        return STKeyboardActions(
          focusNodes: [_nameFocus, _idFocus],
          child: _preView(),
        );
      case _AuthStage.upload:
        return _uploadView();
      case _AuthStage.confirm:
        return _confirmView();
      case _AuthStage.status:
        return _statusView();
    }
  }

  Widget _preView() {
    final country = _countryModel ?? CountryModel.china;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    Image.asset(
                      'assets/images/st_mine_auth_top_tip.png',
                      width: 12,
                      height: 12,
                      errorBuilder: (_, __, ___) {
                        return Icon(
                          Icons.info,
                          size: 12,
                          color: context.adaptiveTextPrimary,
                        );
                      },
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _t('auth_top_tip'),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adaptiveTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _label(_t('reside_area')),
                const SizedBox(height: 5),
                _countryField(country),
                const SizedBox(height: 20),
                _label(_t('card_type')),
                const SizedBox(height: 5),
                for (var i = 0; i < _docTypes.length; i++) ...[
                  _docTypeTile(_docTypes[i], recommend: i == 0),
                  if (i != _docTypes.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 20),
                _label(_t('name')),
                const SizedBox(height: 5),
                _input(
                  _nameCtrl,
                  _t('flutter_auth_enter_name'),
                  focusNode: _nameFocus,
                  inputFormatters: [
                    AuthNameInputFormatter(countryKey: _countryCode),
                  ],
                ),
                const SizedBox(height: 20),
                _label(_t('card_num')),
                const SizedBox(height: 5),
                _input(
                  _idCtrl,
                  _t('flutter_auth_enter_id_number'),
                  focusNode: _idFocus,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomButton(_t('next_step'), enabled: _canPreNext, onTap: _preNext),
      ],
    );
  }

  Widget _countryField(CountryModel country) {
    return InkWell(
      onTap: _pickCountry,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: context.adaptiveDivider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _countryFlag(country),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                country.value,
                style: TextStyle(
                  fontSize: 15,
                  color: context.adaptiveTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: context.adaptiveTextSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _countryFlag(CountryModel country) {
    if (country.flagUrl.isNotEmpty) {
      return ClipOval(
        child: STNetworkImage(
          imageUrl: country.flagUrl,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Text(country.flagEmoji),
        ),
      );
    }
    return Text(country.flagEmoji, style: const TextStyle(fontSize: 20));
  }

  Widget _docTypeTile(_AuthDocType type, {required bool recommend}) {
    final selected = type == _docType;
    return GestureDetector(
      onTap: () => setState(() => _docType = type),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          18,
          recommend ? 14 : 15,
          14,
          recommend ? 14 : 15,
        ),
        decoration: BoxDecoration(
          color: selected ? context.adaptiveCard : context.adaptiveMutedBlock,
          border: Border.all(color: context.adaptiveDivider),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/${type.asset}.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _docTypeLabel(type),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  if (recommend) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4DCB73).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _t('recommend'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF4DCB73),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Image.asset(
              selected
                  ? 'assets/images/st_ca_unfinish_true.png'
                  : 'assets/images/st_mine_unchecked.png',
              width: 18,
              height: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 25),
                Text(
                  '${_t('upload_card_title')}(${_docTypeLabel(_docType)})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _t('upload_card_tip'),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: context.adaptiveDivider),
                const SizedBox(height: 57),
                Center(
                  child: _photoButton(
                    front: true,
                    title: '${_t('id_card')}${_t('id_card_forward')}',
                    placeholder: 'st_mine_auth_front',
                    url: _frontUrl,
                    bytes: _frontBytes,
                    uploading: _uploadingFront,
                  ),
                ),
                if (!_isPassport) ...[
                  const SizedBox(height: 60),
                  Center(
                    child: _photoButton(
                      front: false,
                      title: '${_t('id_card')}${_t('id_card_back')}',
                      placeholder: 'st_mine_auth_back',
                      url: _backUrl,
                      bytes: _backBytes,
                      uploading: _uploadingBack,
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                Center(
                  child: TextButton(
                    onPressed: _showExample,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(97, 20),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      _t('see_an_example'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF00B57A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        _bottomButton(
          _t('next_step'),
          enabled: _canUploadNext && !_uploadingFront && !_uploadingBack,
          onTap: () => setState(() => _stage = _AuthStage.confirm),
        ),
      ],
    );
  }

  Widget _photoButton({
    required bool front,
    required String title,
    required String placeholder,
    required String url,
    required Uint8List? bytes,
    required bool uploading,
  }) {
    final hasPhoto = url.isNotEmpty || bytes != null;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: uploading ? null : () => _choosePhoto(front: front),
              child: SizedBox(
                width: 161,
                height: 93,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _photoContent(placeholder, url, bytes),
                ),
              ),
            ),
            if (!hasPhoto)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Image.asset(
                      'assets/images/st_add_green.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                ),
              ),
            if (uploading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (hasPhoto)
              Positioned(
                right: -12,
                top: -12,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  icon: Image.asset(
                    'assets/images/st_mine_del.png',
                    width: 24,
                    height: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      if (front) {
                        _frontUrl = '';
                        _frontBytes = null;
                      } else {
                        _backUrl = '';
                        _backBytes = null;
                      }
                    });
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextTertiary,
          ),
        ),
      ],
    );
  }

  Widget _photoContent(String placeholder, String url, Uint8List? bytes) {
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
    if (url.isNotEmpty) {
      return STNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholderBuilder: (_) =>
            Image.asset('assets/images/$placeholder.png'),
      );
    }
    return Image.asset('assets/images/$placeholder.png', fit: BoxFit.cover);
  }

  void _showExample() {
    showAuthExampleDialog(context: context);
  }

  Widget _confirmView() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _sectionHeader(_t('card_photo')),
              _photoInfoRow(
                '${_t('id_card')}${_t('id_card_forward')}',
                _frontUrl,
                _frontBytes,
              ),
              if (!_isPassport)
                _photoInfoRow(
                  '${_t('id_card')}${_t('id_card_back')}',
                  _backUrl,
                  _backBytes,
                ),
              _sectionHeader(_t('identity_info')),
              _infoRow(
                _t('card_type'),
                _docTypeLabel(_docType),
                bottomHidden: false,
              ),
              _infoRow(_t('name'), _nameCtrl.text.trim(), bottomHidden: false),
              _infoRow(
                _t('card_num'),
                _idCtrl.text.trim(),
                bottomHidden: false,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 20),
            child: Row(
              children: [
                Expanded(
                  child: _outlineAction(
                    _t('modify'),
                    () => setState(() => _stage = _AuthStage.pre),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _solidAction(
                    _busy ? _t('flutter_auth_submitting') : _t('submit'),
                    enabled: !_busy,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusView() {
    final doc = _statusDoc ?? const <String, dynamic>{};
    final type = _typeLabel('${doc['type'] ?? ''}');
    final status = _statusValue;
    final front = '${doc['front_picture'] ?? ''}';
    final back = '${doc['back_picture'] ?? ''}';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _sectionHeader(_t('card_photo')),
              _photoInfoRow(
                '${_t('id_card')}${_t('id_card_forward')}',
                front,
                null,
              ),
              if ('${doc['type'] ?? ''}' != 'PASSPORT')
                _photoInfoRow(
                  '${_t('id_card')}${_t('id_card_back')}',
                  back,
                  null,
                ),
              _sectionHeader(_t('identity_info')),
              _infoRow(_t('card_type'), type, bottomHidden: false),
              _infoRow(_t('name'), '${doc['name'] ?? ''}', bottomHidden: false),
              _infoRow(
                _t('card_num'),
                '${doc['id_number'] ?? ''}',
                bottomHidden: false,
              ),
            ],
          ),
        ),
        if (status == 2)
          _bottomButton(
            _t('re_apply'),
            enabled: true,
            onTap: () => setState(() {
              _statusDoc = null;
              _stage = _AuthStage.pre;
              _frontUrl = '';
              _backUrl = '';
              _frontBytes = null;
              _backBytes = null;
            }),
          ),
      ],
    );
  }

  String _typeLabel(String raw) {
    for (final type in _AuthDocType.values) {
      if (type.value == raw) return _docTypeLabel(type);
    }
    return '';
  }

  Widget _sectionHeader(String title) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.only(left: 15),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoInfoRow(String title, String url, Uint8List? bytes) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 104),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.adaptiveDivider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: context.adaptiveTextTertiary,
                ),
              ),
            ),
            SizedBox(
              width: 112,
              height: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _photoContent('st_mine_auth_front', url, bytes),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String name, String content, {required bool bottomHidden}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: bottomHidden
            ? null
            : Border(bottom: BorderSide(color: context.adaptiveDivider)),
      ),
      child: Row(
        children: [
          Text(
            name,
            style: TextStyle(fontSize: 15, color: context.adaptiveTextTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: context.adaptiveTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: context.adaptiveTextSecondary),
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint, {
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: context.adaptiveDivider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 15,
            color: context.adaptiveTextSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        style: TextStyle(fontSize: 15, color: context.adaptiveTextPrimary),
      ),
    );
  }

  Widget _bottomButton(
    String title, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 20),
        child: _solidAction(title, enabled: enabled, onTap: onTap),
      ),
    );
  }

  Widget _solidAction(
    String title, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00B57A),
          disabledBackgroundColor: const Color(
            0xFF00B57A,
          ).withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _outlineAction(String title, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00B57A),
          side: const BorderSide(color: Color(0xFF00B57A)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _sheetItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Center(
          child: Text(
            title,
            style: TextStyle(fontSize: 16, color: context.adaptiveTextPrimary),
          ),
        ),
      ),
    );
  }
}
