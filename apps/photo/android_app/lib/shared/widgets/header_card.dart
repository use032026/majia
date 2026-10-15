import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_card.dart';
import '../../core/config/brand_config.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/router/st_router.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'st_toast.dart';

/// Header 卡片 `header_1` ~ `header_4`
///
/// 对齐 iOS `Header1CardView` / `Header2CardView` / `Header3CardView` /
/// `Header4CardView`：右上设置与客服、登录态昵称/UID、编辑资料、复制 UID。
class HeaderCard extends BaseCard {
  const HeaderCard({super.key, required super.cardData});

  static const _black = Color(0xFF000000);
  static const _sub = Color(0xFF60656D);
  static const _line = Color(0xFFECECEC);
  static const _defaultAvatarAsset =
      'assets/images/st_mine_guest_default_avatar.jpg';

  @override
  Widget buildCardContent(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(userStateProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final style = cardData.cardStyle;

        return _HeaderLocalizedScope(
          cardName: style,
          builder: (context, strings) {
            final data = _HeaderUserData.from(
              user,
              cardData.cardDetail,
              strings,
            );
            return switch (style) {
              'header_2' => _Header2Layout(data: data, isDark: isDark),
              'header_3' => _Header3Layout(data: data, isDark: isDark),
              'header_4' => _Header4Layout(data: data, isDark: isDark),
              _ => _Header1Layout(data: data, isDark: isDark),
            };
          },
        );
      },
    );
  }

  static void _openSettings(BuildContext context, WidgetRef ref) {
    ref
        .read(stRouterProvider)
        .openPage(context, '/mine/setting', action: 'Header设置');
  }

  static void _openService(BuildContext context, WidgetRef ref) {
    CustomerServiceRoute.open(context, ref, action: 'Header客服');
  }

  static void _openProfile(BuildContext context, WidgetRef ref, bool loggedIn) {
    ref
        .read(stRouterProvider)
        .openPage(
          context,
          loggedIn ? '/mine/profile' : '/login',
          action: loggedIn ? 'Header个人资料' : 'Header登录',
        );
  }

  static Future<void> _copyUid(
    BuildContext context,
    String uid,
    String successText,
  ) async {
    if (uid.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: uid));
    if (!context.mounted) return;
    STToast.show(context, successText);
  }

  static Widget _toolbarIcon(
    BuildContext context, {
    required bool isDark,
    required String asset,
    required IconData fallback,
    required VoidCallback onTap,
    double imageSize = 24,
    double tapSize = 44,
    String? networkUrl,
  }) {
    final iconColor = isDark
        ? context.adaptiveTextPrimary
        : const Color(0xFF343434);
    Widget icon;
    if (networkUrl?.trim().isNotEmpty == true) {
      icon = Image.network(
        networkUrl!.trim(),
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, size: imageSize, color: iconColor),
      );
    } else {
      icon = Image.asset(
        'assets/images/$asset.png',
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, size: imageSize, color: iconColor),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tapSize / 2),
      child: SizedBox(
        width: tapSize,
        height: tapSize,
        child: Center(child: icon),
      ),
    );
  }

  static Widget _avatar(
    BuildContext context, {
    required _HeaderUserData data,
    required double outer,
    required double inner,
    bool ring = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF48484A) : const Color(0xFFDEE0E3);
    final image = data.avatarUrl != null && data.avatarUrl!.startsWith('http')
        ? Image.network(
            data.avatarUrl!,
            width: inner,
            height: inner,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarPlaceholder(context, inner),
          )
        : _avatarPlaceholder(context, inner);

    final clipped = ClipOval(
      child: ColoredBox(color: bg, child: image),
    );
    if (!ring) {
      return SizedBox(width: outer, height: outer, child: clipped);
    }
    return Container(
      width: outer,
      height: outer,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3C) : _line,
          width: 1,
        ),
      ),
      child: SizedBox(width: inner, height: inner, child: clipped),
    );
  }

  static Widget _avatarPlaceholder(BuildContext context, double size) {
    return Image.asset(
      _defaultAvatarAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.person_rounded,
          size: size * 0.58,
          color: context.adaptiveTextHint,
        ),
      ),
    );
  }

  static Widget _editIcon(BuildContext context, bool isDark, double size) {
    final color = isDark
        ? context.adaptiveTextPrimary
        : const Color(0xFF343434);
    return Image.asset(
      'assets/images/st_mine_edit.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.edit_outlined, size: size, color: color),
    );
  }

  static Widget _copyIcon(
    BuildContext context,
    bool isDark,
    double size, {
    String asset = 'st_mine_copy_sec',
    String? darkAsset,
  }) {
    final color = isDark ? const Color(0xFFA0A4AB) : _sub;
    final effectiveAsset = isDark && (darkAsset?.trim().isNotEmpty == true)
        ? darkAsset!.trim()
        : asset;
    return Image.asset(
      'assets/images/$effectiveAsset.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.copy_outlined, size: size, color: color),
    );
  }

  static Color _titleColor(BuildContext context, bool isDark) {
    return isDark ? context.adaptiveTextPrimary : _black;
  }

  static Color _subtitleColor(BuildContext context, bool isDark) {
    return isDark ? const Color(0xFFA0A4AB) : _sub;
  }
}

typedef _HeaderLocalizedBuilder =
    Widget Function(BuildContext context, _HeaderLocalizedStrings strings);

class _HeaderLocalizedScope extends ConsumerStatefulWidget {
  final String cardName;
  final _HeaderLocalizedBuilder builder;

  const _HeaderLocalizedScope({required this.cardName, required this.builder});

  @override
  ConsumerState<_HeaderLocalizedScope> createState() =>
      _HeaderLocalizedScopeState();
}

class _HeaderLocalizedScopeState extends ConsumerState<_HeaderLocalizedScope> {
  static const Map<String, String> _fallbacks = {
    'please_login': '请登录',
    'replicating_success': '复制成功',
    'welcome_to_future_invest': '欢迎使用 %@',
  };

  String? _loadKey;
  int _loadToken = 0;
  Map<String, String> _localized = _fallbacks;

  @override
  Widget build(BuildContext context) {
    final localizations = ref.watch(stLocalizationsProvider);
    _ensureLocalized(localizations);
    return widget.builder(context, _HeaderLocalizedStrings(_localized));
  }

  void _ensureLocalized(STLocalizations localizations) {
    final cardName = widget.cardName.trim().isEmpty
        ? 'header_1'
        : widget.cardName.trim();
    final loadKey = '$cardName:${localizations.languageCode}';
    if (_loadKey == loadKey) return;
    _loadKey = loadKey;
    _localized = _fallbacks;

    final token = ++_loadToken;
    Future.wait(
      _fallbacks.entries.map((entry) async {
        final value = await localizations.cardText(
          cardName,
          entry.key,
          fallback: entry.value,
        );
        return MapEntry(entry.key, value);
      }),
    ).then((entries) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _localized = Map<String, String>.fromEntries(entries);
      });
    });
  }
}

class _HeaderLocalizedStrings {
  final Map<String, String> _values;

  const _HeaderLocalizedStrings(this._values);

  String t(String key) =>
      _values[key] ?? _HeaderLocalizedScopeState._fallbacks[key] ?? key;
}

String _formatHeaderWelcome(String template) {
  final brandName = BrandConfig.jufu().appNameEn;
  if (template.contains('%@')) {
    return template.replaceAll('%@', brandName);
  }
  if (template.contains('%s')) {
    return template.replaceAll('%s', brandName);
  }
  return template;
}

class _HeaderUserData {
  final bool loggedIn;
  final String uid;
  final String displayName;
  final String subtitle;
  final String copySuccessText;
  final String? avatarUrl;
  final String? serviceIconUrl;
  final String? settingIconUrl;

  const _HeaderUserData({
    required this.loggedIn,
    required this.uid,
    required this.displayName,
    required this.subtitle,
    required this.copySuccessText,
    this.avatarUrl,
    this.serviceIconUrl,
    this.settingIconUrl,
  });

  factory _HeaderUserData.from(
    UserState user,
    Map<String, dynamic>? detail,
    _HeaderLocalizedStrings strings,
  ) {
    final detailUid = _pick(detail, const ['uid', 'user_id', 'userId']);
    final uid = detailUid ?? user.userId;
    final loggedIn = user.hasActiveSession && uid.trim().isNotEmpty;
    final name =
        _pick(detail, const ['nickName', 'nickname', 'name']) ??
        (user.nickname.trim().isNotEmpty
            ? user.nickname.trim()
            : (user.transactionAccount.trim().isNotEmpty
                  ? user.transactionAccount.trim()
                  : (uid.trim().isNotEmpty ? '用户$uid' : '')));

    final avatar = _pick(detail, const [
      'avatar',
      'avatar_url',
      'head_img',
      'headImg',
      'head_url',
      'portrait',
      'photo',
    ]);

    return _HeaderUserData(
      loggedIn: loggedIn,
      uid: uid,
      displayName: loggedIn ? name : strings.t('please_login'),
      subtitle: loggedIn
          ? 'UID:$uid'
          : _formatHeaderWelcome(strings.t('welcome_to_future_invest')),
      copySuccessText: strings.t('replicating_success'),
      avatarUrl:
          avatar ??
          (user.avatarUrl.trim().isNotEmpty ? user.avatarUrl.trim() : null),
      serviceIconUrl: _pick(detail, const [
        'service_icon',
        'customer_icon',
        'icon_service',
        'serviceIcon',
        'customerIcon',
      ]),
      settingIconUrl: _pick(detail, const [
        'setting_icon',
        'setup_icon',
        'icon_setting',
        'settingIcon',
        'setupIcon',
      ]),
    );
  }

  static String? _pick(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final value = map[k];
      if (value == null) continue;
      final s = value.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }
}

class _HeaderToolbar extends ConsumerWidget {
  final _HeaderUserData data;
  final bool isDark;
  final double right;
  final double top;
  final double gap;
  final double iconSize;
  final double tapSize;
  final String serviceAsset;
  final String? serviceAssetDark;
  final String settingAsset;
  final String? settingAssetDark;

  const _HeaderToolbar({
    required this.data,
    required this.isDark,
    required this.right,
    required this.top,
    required this.gap,
    required this.iconSize,
    required this.tapSize,
    this.serviceAsset = 'st_login_service',
    this.serviceAssetDark,
    this.settingAsset = 'st_mine_setup',
    this.settingAssetDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveServiceAsset =
        isDark && (serviceAssetDark?.trim().isNotEmpty == true)
        ? serviceAssetDark!.trim()
        : serviceAsset;
    final effectiveSettingAsset =
        isDark && (settingAssetDark?.trim().isNotEmpty == true)
        ? settingAssetDark!.trim()
        : settingAsset;

    return Positioned(
      top: top,
      right: right,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeaderCard._toolbarIcon(
            context,
            isDark: isDark,
            asset: effectiveServiceAsset,
            networkUrl: data.serviceIconUrl,
            fallback: Icons.headset_mic_outlined,
            imageSize: iconSize,
            tapSize: tapSize,
            onTap: () => HeaderCard._openService(context, ref),
          ),
          SizedBox(width: gap),
          HeaderCard._toolbarIcon(
            context,
            isDark: isDark,
            asset: effectiveSettingAsset,
            networkUrl: data.settingIconUrl,
            fallback: Icons.settings_outlined,
            imageSize: iconSize,
            tapSize: tapSize,
            onTap: () => HeaderCard._openSettings(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Header1Layout extends ConsumerWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header1Layout({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _HeaderToolbar(
            data: data,
            isDark: isDark,
            right: 0,
            top: 2,
            gap: 10,
            iconSize: 24,
            tapSize: 34,
          ),
          Positioned(
            left: 0,
            right: 68,
            bottom: 0,
            height: 48,
            child: InkWell(
              onTap: () => HeaderCard._openProfile(context, ref, data.loggedIn),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  HeaderCard._avatar(context, data: data, outer: 48, inner: 48),
                  const SizedBox(width: 9),
                  Flexible(
                    child: _Header1TextColumn(data: data, isDark: isDark),
                  ),
                  if (data.loggedIn) ...[
                    const SizedBox(width: 12),
                    HeaderCard._editIcon(context, isDark, 20),
                  ],
                ],
              ),
            ),
          ),
          if (data.loggedIn)
            Positioned(
              left: 48 + 9 + 135,
              bottom: 0,
              width: 24,
              height: 24,
              child: InkWell(
                onTap: () => HeaderCard._copyUid(
                  context,
                  data.uid,
                  data.copySuccessText,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Center(child: HeaderCard._copyIcon(context, isDark, 14)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header1TextColumn extends StatelessWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header1TextColumn({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 20 / 18,
            color: HeaderCard._titleColor(context, isDark),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            height: 16 / 12,
            color: HeaderCard._subtitleColor(context, isDark),
          ),
        ),
      ],
    );
  }
}

class _Header2Layout extends ConsumerWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header2Layout({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 115,
      child: Stack(
        children: [
          _HeaderToolbar(
            data: data,
            isDark: isDark,
            right: 16,
            top: 0,
            gap: 10,
            iconSize: 24,
            tapSize: 34,
          ),
          Positioned(
            top: 45,
            right: 16,
            child: InkWell(
              onTap: () => HeaderCard._openProfile(context, ref, data.loggedIn),
              borderRadius: BorderRadius.circular(25),
              child: HeaderCard._avatar(
                context,
                data: data,
                outer: 50,
                inner: 50,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 78,
            top: 45,
            height: 50,
            child: InkWell(
              onTap: () => HeaderCard._openProfile(context, ref, data.loggedIn),
              borderRadius: BorderRadius.circular(8),
              child: _Header2TextRow(data: data, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header2TextRow extends StatelessWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header2TextRow({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                data.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 20 / 16,
                  color: HeaderCard._titleColor(context, isDark),
                ),
              ),
            ),
            if (data.loggedIn) ...[
              const SizedBox(width: 12),
              HeaderCard._editIcon(context, isDark, 20),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  height: 20 / 12,
                  color: HeaderCard._subtitleColor(context, isDark),
                ),
              ),
            ),
            if (data.loggedIn) ...[
              const SizedBox(width: 6),
              _HeaderCopyTap(data: data, isDark: isDark, size: 20),
            ],
          ],
        ),
      ],
    );
  }
}

class _Header3Layout extends ConsumerWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header3Layout({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 138,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          _HeaderToolbar(
            data: data,
            isDark: isDark,
            right: 16,
            top: 0,
            gap: 10,
            iconSize: 24,
            tapSize: 34,
          ),
          Positioned(
            top: 40,
            child: InkWell(
              onTap: () => HeaderCard._openProfile(context, ref, data.loggedIn),
              borderRadius: BorderRadius.circular(25),
              child: HeaderCard._avatar(
                context,
                data: data,
                outer: 50,
                inner: 50,
              ),
            ),
          ),
          if (data.loggedIn)
            Positioned(
              top: 70,
              child: Transform.translate(
                offset: const Offset(37, 0),
                child: HeaderCard._editIcon(context, isDark, 20),
              ),
            ),
          Positioned(
            top: 90,
            left: 16,
            right: 16,
            bottom: 20,
            child: InkWell(
              onTap: () => HeaderCard._openProfile(context, ref, data.loggedIn),
              borderRadius: BorderRadius.circular(8),
              child: _Header3Text(data: data, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header3Text extends StatelessWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header3Text({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          data.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 20 / 16,
            color: HeaderCard._titleColor(context, isDark),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  height: 20 / 12,
                  color: HeaderCard._subtitleColor(context, isDark),
                ),
              ),
            ),
            if (data.loggedIn) ...[
              const SizedBox(width: 4),
              _HeaderCopyTap(data: data, isDark: isDark, size: 20),
            ],
          ],
        ),
      ],
    );
  }
}

class _Header4Layout extends ConsumerWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header4Layout({required this.data, required this.isDark});

  static double _pillHeight(BuildContext context) {
    final scaledTextHeight =
        MediaQuery.textScalerOf(context).scale(12) * 16 / 12 + 4;
    return scaledTextHeight > 20 ? scaledTextHeight.ceilToDouble() : 20;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final textTop = safeTop + (data.loggedIn ? 48 : 38);
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight = scaler.scale(18) * 28 / 18;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableTextWidth = (constraints.maxWidth - 88 - 64).clamp(
          0.0,
          double.infinity,
        );
        final subtitlePainter = TextPainter(
          text: TextSpan(
            text: data.subtitle,
            style: const TextStyle(fontSize: 12, height: 16 / 12),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 2,
        )..layout(maxWidth: availableTextWidth);
        final subtitleHeight = subtitlePainter.height;
        subtitlePainter.dispose();
        final textBottom = data.loggedIn
            ? 48 + titleHeight + 4 + _pillHeight(context)
            : 38 + titleHeight + 12 + subtitleHeight;
        final contentHeight = textBottom + (data.loggedIn ? 2 : 8);
        final cardHeight = contentHeight > 102 ? contentHeight : 102.0;
        return SizedBox(
          height: safeTop + cardHeight,
          child: Stack(
            children: [
              _HeaderToolbar(
                data: data,
                isDark: isDark,
                right: 16,
                top: safeTop + 12,
                gap: 20,
                iconSize: 22,
                tapSize: 22,
                serviceAsset: 'cms_login_service',
                serviceAssetDark: 'cms_login_service_cmsdark',
                settingAsset: 'cms_mine_setup',
                settingAssetDark: 'cms_mine_setup_cmsdark',
              ),
              Positioned(
                left: 16,
                bottom: 5,
                // top: safeTop + 36,
                child: InkWell(
                  onTap: () =>
                      HeaderCard._openProfile(context, ref, data.loggedIn),
                  borderRadius: BorderRadius.circular(28),
                  child: HeaderCard._avatar(
                    context,
                    data: data,
                    outer: 56,
                    inner: 54,
                    ring: true,
                  ),
                ),
              ),
              Positioned(
                left: 88,
                right: 64,
                top: textTop,
                child: InkWell(
                  onTap: () =>
                      HeaderCard._openProfile(context, ref, data.loggedIn),
                  borderRadius: BorderRadius.circular(8),
                  child: _Header4Text(data: data, isDark: isDark),
                ),
              ),
              Positioned(
                right: 36,
                top: safeTop + 66,
                width: 16,
                height: 16,
                child: InkWell(
                  onTap: () =>
                      HeaderCard._openProfile(context, ref, data.loggedIn),
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/header_4_arrow_right.png',
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: isDark
                          ? const Color(0xFFA0A4AB)
                          : const Color(0xFF999999),
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
}

class _Header4Text extends StatelessWidget {
  final _HeaderUserData data;
  final bool isDark;

  const _Header4Text({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 28 / 18,
      color: HeaderCard._titleColor(context, isDark),
    );

    if (!data.loggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 16 / 12,
              color: HeaderCard._subtitleColor(context, isDark),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxPillWidth = (constraints.maxWidth - 8 - 22).clamp(
              0.0,
              constraints.maxWidth,
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxPillWidth),
                  child: InkWell(
                    onTap: () => HeaderCard._copyUid(
                      context,
                      data.uid,
                      data.copySuccessText,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: _Header4Layout._pillHeight(context),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF212229)
                            : const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: Text(
                          data.uid.isEmpty ? 'ID: --' : 'ID: ${data.uid}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 16 / 12,
                            color: HeaderCard._subtitleColor(context, isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _HeaderCopyTap(
                  data: data,
                  isDark: isDark,
                  size: 22,
                  copyAsset: 'cms_mine_copy_sec',
                  copyAssetDark: 'cms_mine_copy_sec_cmsdark',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeaderCopyTap extends StatelessWidget {
  final _HeaderUserData data;
  final bool isDark;
  final double size;
  final String copyAsset;
  final String? copyAssetDark;

  const _HeaderCopyTap({
    required this.data,
    required this.isDark,
    required this.size,
    this.copyAsset = 'st_mine_copy_sec',
    this.copyAssetDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => HeaderCard._copyUid(context, data.uid, data.copySuccessText),
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: HeaderCard._copyIcon(
            context,
            isDark,
            14,
            asset: copyAsset,
            darkAsset: copyAssetDark,
          ),
        ),
      ),
    );
  }
}
