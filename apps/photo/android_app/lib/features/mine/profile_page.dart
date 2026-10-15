import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_network_image.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_localized_prompt.dart';

enum ProfileMediaPermission { granted, denied, restricted }

typedef ProfileMediaPermissionChecker =
    Future<ProfileMediaPermission> Function(ImageSource source);

typedef ProfileOpenAppSettings = Future<bool> Function();

/// 个人信息
/// 对齐 iOS STPersonalInfoViewController 与截图：头像 / 信息列表 / 铅笔编辑
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({
    super.key,
    this.mediaPermissionChecker,
    this.openAppSettings,
  });

  final ProfileMediaPermissionChecker? mediaPermissionChecker;
  final ProfileOpenAppSettings? openAppSettings;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfileVm {
  _ProfileVm({
    required this.nickname,
    required this.realName,
    required this.nationality,
    required this.phoneRaw,
    required this.phoneBrowse,
    required this.phoneEdit,
    required this.email,
    required this.idType,
    required this.idNumberMasked,
    required this.autograph,
    required this.avatarUrl,
    required this.registerTimeRaw,
    required this.registerTimeDisplay,
    required this.isPhoneBound,
    required this.isEmailBound,
  });

  final String nickname;
  final String realName;
  final String nationality;

  /// 原始数字串（若无则空）
  final String phoneRaw;

  /// 浏览态：`135****55`
  final String phoneBrowse;

  /// 编辑列表：`+86 135****55`
  final String phoneEdit;
  final String email;
  final String idType;
  final String idNumberMasked;
  final String autograph;
  final String? avatarUrl;
  final String registerTimeRaw;
  final String registerTimeDisplay;
  final bool isPhoneBound;
  final bool isEmailBound;

  static _ProfileVm empty() => _ProfileVm(
    nickname: '',
    realName: '',
    nationality: '',
    phoneRaw: '',
    phoneBrowse: '--',
    phoneEdit: '--',
    email: '',
    idType: '--',
    idNumberMasked: '--',
    autograph: '',
    avatarUrl: null,
    registerTimeRaw: '',
    registerTimeDisplay: '--',
    isPhoneBound: false,
    isEmailBound: false,
  );

  /// 从 `/api/user/info` data 松散解析。
  factory _ProfileVm.fromJson(Map<String, dynamic> raw) {
    String pick(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && '$v'.trim().isNotEmpty) {
          return '$v'.trim();
        }
      }
      return '';
    }

    bool pickBool(Map m, List<String> keys) {
      for (final k in keys) {
        if (!m.containsKey(k)) continue;
        final v = m[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        final s = '$v'.toLowerCase().trim();
        if (s == '1' || s == 'true' || s == 'yes') return true;
      }
      return false;
    }

    String formatOpenTime(String raw) {
      if (raw.isEmpty) return '--';
      final sec = int.tryParse(raw);
      if (sec != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      }
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      }
      return raw;
    }

    final nick = pick(raw, ['nickname', 'nick_name', 'nickName', 'name']);

    final real = pick(raw, [
      'real_name',
      'realName',
      'true_name',
      'trueName',
      'fullname',
      'full_name',
      'name',
    ]);

    final nation = pick(raw, [
      'nationality_name',
      'country_name',
      'country',
      'nationality',
    ]);

    final phoneDigits = pick(raw, [
      'tel',
      'mobile',
      'phone',
      'telphone',
    ]).replaceAll(RegExp(r'\D'), '');
    final phoneBound = pickBool(raw, [
      'is_bind_phone',
      'isBindPhone',
      'tel_bind_status',
    ]);
    final phoneRaw = pick(raw, ['tel', 'mobile', 'phone', 'telphone']);
    final phoneDisplay = phoneRaw.isNotEmpty ? phoneRaw : '--';

    final emailAddr = pick(raw, ['email', 'email_address']);
    final emailBindFlag = pickBool(raw, [
      'email_bind_status',
      'emailBound',
      'is_bind_email',
    ]);
    final mailDisplay = emailAddr.isNotEmpty ? emailAddr : '--';

    final certType = pick(raw, [
      'identity_type_str',
      'identityTypeStr',
      'identity_type',
      'identityType',
      'certificate_type_name',
      'id_type_name',
      'cert_type',
      'id_type',
    ]);
    final idPlain = pick(raw, [
      'identity_value',
      'identityValue',
      'id_card',
      'id_number',
      'identity_no',
      'identityValueStr',
    ]);
    final idShown = idPlain.isNotEmpty ? idPlain : '--';

    final avatar = pick(raw, [
      'avatar',
      'avatar_url',
      'head_img',
      'headImg',
      'head_url',
      'portrait',
      'photo',
    ]);
    final avatarResolved = avatar.isNotEmpty ? avatar : null;

    final bio = pick(raw, ['signature', 'autograph', 'bio']);

    final regRaw = pick(raw, [
      'account_opened_time',
      'open_time',
      'openTime',
      'open_account_time',
      'open_time',
      'created_at',
      'register_at',
      'create_time',
      'opened_at',
    ]);
    final regDisplay = formatOpenTime(regRaw);

    return _ProfileVm(
      nickname: nick,
      realName: real.isNotEmpty ? real : '--',
      nationality: nation.isNotEmpty ? nation : '--',
      phoneRaw: phoneDigits,
      phoneBrowse: phoneDisplay,
      phoneEdit: phoneDigits,
      email: mailDisplay,
      idType: certType.isNotEmpty ? certType : '--',
      idNumberMasked: idShown,
      autograph: bio,
      avatarUrl: avatarResolved,
      registerTimeRaw: regRaw,
      registerTimeDisplay: regDisplay,
      isPhoneBound: phoneBound,
      isEmailBound: emailBindFlag,
    );
  }
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const Map<String, String> _fallbackText = {
    'profile_detail': '个人信息',
    'nickname': '昵称',
    'real_name': '真实姓名',
    'country': '国籍',
    'phone': '手机',
    'email': '邮箱',
    'card_type': '证件类型',
    'card_num': '证件号码',
    'open_account_time': '签发日期',
    'autograph': '个性签名',
    'no_bind': '未绑定',
    'click_add_nickname': '添加昵称',
    'click_set_signature': '设置签名',
    'change_the_avatar': '更换头像',
    'from_album': '从相册选择',
    'take_photo': '拍照',
    'cancel': '取消',
    'later': '稍后',
    'setting': '设置',
    'id_card': '身份证',
    'passport': '护照',
    'driver_license': '驾驶证',
  };

  bool _isLoading = true;
  bool _hasLoadedProfile = false;
  bool _isUploadingAvatar = false;
  late _ProfileVm _vm = _ProfileVm.empty();
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  /// 与 iOS `STMineCommonCell` 个人信息行：`trailLbl`/`editLbl` 右对齐，`editBtn` 贴右。

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  Future<String> _iosText(String key, String fallback) {
    return stLocalizationsOfContext(context, ref).text(key, fallback: fallback);
  }

  String _identityTypeLabel(String rawType) {
    final trimmed = rawType.trim();
    final normalized = trimmed.toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    switch (normalized) {
      case 'IDCARD':
      case '身份证':
        return _t('id_card');
      case 'PASSPORT':
      case '护照':
        return _t('passport');
      case 'DRIVERLICENSE':
      case '驾驶证':
        return _t('driver_license');
      default:
        return trimmed.isNotEmpty ? trimmed : '--';
    }
  }

  Future<void> _loadProfile({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || !_hasLoadedProfile;
    if (shouldShowLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final service = ref.read(stServiceProvider);
      final profile = await service.getUserProfile();
      Map<String, dynamic> data;
      if (profile.containsKey('data') && profile['data'] is Map) {
        data = profile['data'] as Map<String, dynamic>;
      } else {
        data = profile;
      }
      ref.read(userStateProvider.notifier).mergeUserInfoApi(data);
      if (mounted) {
        setState(() {
          _vm = _ProfileVm.fromJson(data);
          _hasLoadedProfile = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && shouldShowLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final granted = await _ensureMediaPermission(source);
    if (!granted) return;

    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 95,
      );
      if (!mounted || file == null) return;
      await _uploadAvatar(file);
    } catch (_) {
      if (!mounted) return;
      showStLocalizedToastByKey(
        context,
        'flutter_prompt_avatar_load_failed',
        fallback: '无法获取照片，请检查相册或相机权限',
      );
    }
  }

  Future<bool> _ensureMediaPermission(ImageSource source) async {
    final ProfileMediaPermission status;
    try {
      status = widget.mediaPermissionChecker == null
          ? await _checkSystemMediaPermission(source)
          : await widget.mediaPermissionChecker!(source);
    } catch (_) {
      return true;
    }
    if (status == ProfileMediaPermission.granted) return true;
    if (!mounted) return false;
    await _showMediaPermissionAlert(source);
    return false;
  }

  Future<ProfileMediaPermission> _checkSystemMediaPermission(
    ImageSource source,
  ) async {
    final permission = source == ImageSource.camera
        ? permissions.Permission.camera
        : permissions.Permission.photos;
    var status = await permission.status;
    if (_isPermissionGranted(status)) {
      return ProfileMediaPermission.granted;
    }
    if (status.isRestricted) {
      return ProfileMediaPermission.restricted;
    }
    if (!status.isPermanentlyDenied) {
      status = await permission.request();
      if (_isPermissionGranted(status)) {
        return ProfileMediaPermission.granted;
      }
      if (status.isRestricted) {
        return ProfileMediaPermission.restricted;
      }
    }
    return ProfileMediaPermission.denied;
  }

  bool _isPermissionGranted(permissions.PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<void> _showMediaPermissionAlert(ImageSource source) async {
    final title = await _iosText(
      source == ImageSource.camera
          ? 'enable_camera_permission'
          : 'enable_album_permission',
      source == ImageSource.camera
          ? '请开启相机权限以进行拍照或录像。'
          : '请开启相册权限以选择照片或视频。',
    );
    final cancel = await _iosText('later', '稍后');
    final confirm = await _iosText('setting', '设置');
    if (!mounted) return;

    await showIosCommonAlertDialog(
      context: context,
      title: title,
      cancelText: cancel,
      confirmText: confirm,
      onConfirm: () async {
        final opened = await _openSystemSettings();
        if (!opened && mounted) {
          showStLocalizedToastByKey(
            context,
            'flutter_prompt_open_settings_failed',
            fallback: '无法打开系统设置，请稍后重试',
          );
        }
      },
    );
  }

  Future<bool> _openSystemSettings() {
    final customOpen = widget.openAppSettings;
    if (customOpen != null) return customOpen();
    return launchUrl(
      Uri.parse('app-settings:'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _pickMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _uploadAvatar(XFile file) async {
    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty
          ? file.name
          : 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final service = ref.read(stServiceProvider);
      final url = await service.uploadIdentityImage(
        bytes: bytes,
        filename: filename,
        mimeType: _pickMime(filename),
      );
      await service.updateUserProfile({'avatar': url});
      ref.read(userStateProvider.notifier).updateAvatar(url);

      if (!mounted) return;
      showStLocalizedToastByKey(
        context,
        'flutter_prompt_avatar_update_success',
        fallback: '头像更新成功',
      );
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      showStLocalizedErrorToast(context, '头像上传失败', e);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _openBindPhone() async {
    await context.push('/mine/bind_phone');
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _openBindEmail() async {
    await context.push('/mine/bind_email');
    if (mounted) {
      await _loadProfile();
    }
  }

  void _showAvatarPicker() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(15, 0, 15, 8 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: context.adaptiveCard,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      _t('change_the_avatar'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.adaptiveHairline,
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _pickImage(ImageSource.gallery);
                      },
                      child: SizedBox(
                        height: 49,
                        child: Center(
                          child: Text(
                            _t('from_album'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.adaptiveTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.adaptiveHairline,
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _pickImage(ImageSource.camera);
                      },
                      child: SizedBox(
                        height: 49,
                        child: Center(
                          child: Text(
                            _t('take_photo'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: context.adaptiveTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: context.adaptiveCard,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.pop(sheetCtx),
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        _t('cancel'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: context.adaptiveTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pushNicknameEditor() async {
    final saved = await context.push<bool>(
      '/mine/profile/nickname',
      extra: {'initial': _vm.nickname},
    );
    if (!mounted || saved != true) return;
    await _loadProfile();
  }

  Future<void> _pushSignatureEditor() async {
    final saved = await context.push<bool>(
      '/mine/profile/signature',
      extra: {'initial': _vm.autograph},
    );
    if (!mounted || saved != true) return;
    await _loadProfile();
  }

  Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: context.adaptiveHairline,
  );

  /// 头像 64px + 相机角标。
  Widget _buildAvatarSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Center(
        child: GestureDetector(
          onTap: _showAvatarPicker,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child:
                      _vm.avatarUrl != null && _vm.avatarUrl!.startsWith('http')
                      ? STNetworkImage(
                          imageUrl: _vm.avatarUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholderBuilder: (_) => Container(
                            color: context.adaptivePlaceholderSurface,
                            child: Icon(
                              Icons.person,
                              size: 36,
                              color: context.adaptiveTextHint,
                            ),
                          ),
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: context.adaptivePlaceholderSurface,
                          child: Icon(
                            Icons.person,
                            size: 36,
                            color: context.adaptiveTextHint,
                          ),
                        ),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: context.adaptiveCard,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 13,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                ),
                if (_isUploadingAvatar)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool editable = false,
    VoidCallback? onTap,
    bool showDividerBelow = true,
    bool isPlaceholder = false,
    bool showArrow = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: isPlaceholder
                                  ? context.adaptiveTextHint
                                  : context.adaptiveTextSecondary,
                            ),
                          ),
                        ),
                        if (editable) ...[
                          const SizedBox(width: 9),
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: context.adaptiveTextPrimary,
                          ),
                        ] else if (showArrow) ...[
                          const SizedBox(width: 9),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: context.adaptiveTextSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDividerBelow) _divider(),
      ],
    );
  }

  Widget _buildInfoCard() {
    final nickShown = _vm.nickname.isNotEmpty
        ? _vm.nickname
        : _t('click_add_nickname');
    final sigShown = _vm.autograph.isNotEmpty
        ? _vm.autograph
        : _t('click_set_signature');
    final phoneNeedBind = !_vm.isPhoneBound;
    final emailNeedBind = !_vm.isEmailBound;
    final phoneShown = phoneNeedBind ? _t('no_bind') : _vm.phoneBrowse;
    final emailShown = emailNeedBind ? _t('no_bind') : _vm.email;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _infoRow(
            label: _t('nickname'),
            value: nickShown,
            editable: true,
            isPlaceholder: _vm.nickname.isEmpty,
            onTap: _pushNicknameEditor,
          ),
          _infoRow(
            label: _t('real_name'),
            value: _vm.realName,
          ),
          _infoRow(
            label: _t('country'),
            value: _vm.nationality,
          ),
          _infoRow(
            label: _t('phone'),
            value: phoneShown,
            onTap: phoneNeedBind ? _openBindPhone : null,
            showArrow: phoneNeedBind,
            isPlaceholder: phoneNeedBind,
          ),
          _infoRow(
            label: _t('email'),
            value: emailShown,
            onTap: emailNeedBind ? _openBindEmail : null,
            showArrow: emailNeedBind,
            isPlaceholder: emailNeedBind,
          ),
          _infoRow(
            label: _t('card_type'),
            value: _identityTypeLabel(_vm.idType),
          ),
          _infoRow(
            label: _t('card_num'),
            value: _vm.idNumberMasked,
          ),
          _infoRow(
            label: _t('open_account_time'),
            value: _vm.registerTimeDisplay,
          ),
          _infoRow(
            label: _t('autograph'),
            value: sigShown,
            editable: true,
            isPlaceholder: _vm.autograph.isEmpty,
            showDividerBelow: false,
            onTap: _pushSignatureEditor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        backgroundColor: context.adaptiveSurfacePrimary,
        elevation: 0,
        centerTitle: true,
        foregroundColor: context.adaptiveTextPrimary,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _t('profile_detail'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: context.adaptiveTextPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: context.adaptiveTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: STLoadAnimationView())
          : STPullRefresh(
              color: const Color(0xFF4DCB73),
              onRefresh: () => _loadProfile(showLoading: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 32),
                children: [_buildAvatarSection(), _buildInfoCard()],
              ),
            ),
    );
  }
}
