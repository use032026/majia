import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';

import '../../core/models/user_state.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/router/st_router.dart';
import '../../core/config/brand_config.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../features/mine/mine_margin_sheets.dart';
import 'base_card.dart';
import 'card_factory.dart';
import 'st_load_animation_view.dart';
import 'st_toast.dart';

/// 邀请/推广 H5 地址（对齐 iOS：卡片 `partnerUrl` / `partner_url` / `invite_url` / `link` → 无则 H5 `partner_url`）
String? mineAccount3InviteH5Url(WidgetRef ref, Map<String, dynamic>? detail) {
  final d = detail ?? {};
  for (final key in <String>[
    'partnerUrl',
    'partner_url',
    'inviteUrl',
    'invite_url',
    'link',
  ]) {
    final v = d[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  final rm = d['routerModel'] ?? d['router_model'];
  if (rm is Map) {
    final m = Map<String, dynamic>.from(rm);
    final link = (m['link'] as String?)?.trim();
    if (link != null && link.isNotEmpty) return link;
  }
  final h5 = ref.read(configDataManagerProvider).h5Config;
  if (h5 != null) {
    final u = h5['partner_url'] as String?;
    if (u != null && u.trim().isNotEmpty) return u.trim();
  }
  return null;
}

/// 当前展示的交易账户（对齐 `MinePage._currentAccount`）。
STAccountModel minePageCurrentTradeAccount(UserState userState) {
  final fallback = STAccountModel(accountId: '', accountType: '--');
  final accounts = userState.accountAry;
  if (accounts.isEmpty) return fallback;
  if (userState.isB) {
    for (final a in accounts) {
      if (a.type == '1') return a;
    }
    return accounts.first;
  }
  for (final a in accounts) {
    if (a.accountId == userState.transactionAccount && a.accountId.isNotEmpty) {
      return a;
    }
  }
  return accounts.first;
}

class _MineLocalizedStrings {
  const _MineLocalizedStrings(this._values);

  final Map<String, String> _values;

  String _t(String key) => _values[key] ?? key;
}

class _MineLocalizedScope extends ConsumerStatefulWidget {
  const _MineLocalizedScope({
    required this.cardNames,
    required this.fallbacks,
    required this.builder,
  });

  final List<String> cardNames;
  final Map<String, String> fallbacks;
  final Widget Function(
    BuildContext context,
    WidgetRef ref,
    _MineLocalizedStrings strings,
  )
  builder;

  @override
  ConsumerState<_MineLocalizedScope> createState() =>
      _MineLocalizedScopeState();
}

class _MineLocalizedScopeState extends ConsumerState<_MineLocalizedScope> {
  Map<String, String> _localizedText = const {};
  String? _resourceKey;

  @override
  Widget build(BuildContext context) {
    final localizations = ref.watch(stLocalizationsProvider);
    _ensureLocalizedText(localizations);
    final merged = <String, String>{...widget.fallbacks, ..._localizedText};
    return widget.builder(context, ref, _MineLocalizedStrings(merged));
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final resourceKey =
        '${localizations.languageCode}:${widget.cardNames.join(",")}';
    if (_resourceKey == resourceKey) return;
    _resourceKey = resourceKey;
    _localizedText = const {};
    Future.wait(
      widget.fallbacks.entries.map((entry) async {
        final value = await _localizedTextForKey(
          localizations,
          entry.key,
          fallback: entry.value,
        );
        return MapEntry(entry.key, value);
      }),
    ).then((entries) {
      if (!mounted || _resourceKey != resourceKey) return;
      setState(() {
        _localizedText = Map<String, String>.fromEntries(entries);
      });
    });
  }

  Future<String> _localizedTextForKey(
    STLocalizations localizations,
    String key, {
    required String fallback,
  }) async {
    for (final cardName in widget.cardNames) {
      final value = await localizations.cardText(
        cardName,
        key,
        fallback: fallback,
      );
      if (value != fallback) return value;
    }
    return localizations.text(key, fallback: fallback);
  }
}

String _formatIosPlaceholder(String pattern, String value) {
  return pattern
      .replaceAll('%@', value)
      .replaceAll('%s', value)
      .replaceAll('{}', value);
}

String _withCurrency(String label, String currency) {
  final trimmed = currency.trim();
  if (trimmed.isEmpty) return label;
  return '$label ($trimmed)';
}

const Map<String, String> _mineHeaderTextFallbacks = {
  'please_login': "请登录",
  'replicating_success': "复制成功",
  'welcome_to_future_invest': "欢迎使用 %@",
  'contact_customer_service': "联系客服",
  'setting': "设置",
};

const Map<String, String> _mineBalanceTextFallbacks = {'account_equity': "净值"};

const Map<String, String> _mineGridTextFallbacks = {
  'deposit': "入金",
  'withdrawal': "出金",
  'positions': "持仓",
};

const Map<String, String> _mineAccount3TextFallbacks = {
  'balance': "余额",
  'margin_level': "保证金水平",
  'floating_profit_loss': "浮动盈亏",
  'my_commission': "我的返佣",
  'all': "全部",
  'account3_commission_obtained': "已获得",
  'account3_commission_pending_withdraw': "待提现",
  'send_an_invitation': "立即邀请",
};

const Map<String, String> _mineListTextFallbacks = {
  'already_auth': "已认证",
  'authentication_failed': "认证失败",
  'under_review': "审核中",
  'certification': "去认证",
  'bind': "已绑定",
  'go_bind': "立即绑定",
};

Widget _mineLeadingImageAsset(
  BuildContext context,
  String name,
  double size, {
  BoxFit fit = BoxFit.contain,
  IconData? fallbackIcon,
  Color? fallbackColor,
}) {
  final neutral = fallbackColor ?? context.adaptiveTextHint;
  if (name.isEmpty) {
    if (fallbackIcon != null) {
      return Icon(fallbackIcon, size: size, color: neutral);
    }
    return SizedBox(width: size, height: size);
  }
  return Image.asset(
    'assets/images/$name.png',
    width: size,
    height: size,
    fit: fit,
    errorBuilder: (_, __, ___) {
      if (fallbackIcon != null) {
        return Icon(fallbackIcon, size: size, color: neutral);
      }
      return Icon(Icons.image_not_supported, size: size, color: neutral);
    },
  );
}

/// 顶栏客服/设置图标色（对齐 iOS `STHeader` / [HeaderCard]）
Color _mineHeaderToolbarIconColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.adaptiveTextPrimary.withValues(alpha: 0.85)
      : const Color(0xFF343434);
}

String? _pickHeaderToolbarIconUrl(
  Map<String, dynamic>? detail,
  List<String> keys,
  bool isDark,
) {
  if (detail == null) return null;
  if (isDark) {
    for (final k in keys) {
      for (final dk in ['${k}_dark', '${k}Dark', '${k}_night']) {
        final v = detail[dk];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
  }
  for (final k in keys) {
    final v = detail[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// 我的页 header 右上：本地 `icon_asset` → 网络 icon → Material 兜底（与 iOS 一致）
Widget _mineHeaderToolbarIcon(
  BuildContext context, {
  required bool isDark,
  required String assetName,
  required IconData fallbackIcon,
  required double size,
  String? networkUrl,
}) {
  final color = _mineHeaderToolbarIconColor(context);
  if (networkUrl != null && networkUrl.isNotEmpty) {
    return Image.network(
      networkUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(fallbackIcon, size: size, color: color),
    );
  }
  return _mineLeadingImageAsset(
    context,
    assetName,
    size,
    fallbackIcon: fallbackIcon,
    fallbackColor: color,
  );
}

/// 昵称展示脱敏（Figma 「我的」header，如 `An*****2524`）
String mineMaskNicknameDisplay(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;
  if (s.runes.length <= 2) {
    final ch = String.fromCharCode(s.runes.first);
    return '$ch*****';
  }
  final runes = s.runes.toList();
  if (runes.length <= 6) {
    return '${String.fromCharCode(runes.first)}*****'
        '${String.fromCharCode(runes.last)}';
  }
  final head = String.fromCharCodes(runes.take(2));
  final tail = String.fromCharCodes(runes.skip(runes.length - 4));
  return '$head*****$tail';
}

/// 我的页头部 `header_1` / `header_4`（对齐 iOS STHeader 登录/未登录分支）
///
/// - 未登录：56 头像 +「请登录」+ 品牌欢迎语 + 右侧 chevron，整行进 `/login`
/// - 已登录：脱敏昵称 + ID 胶囊（`header_4` 浅灰 `#F7F7F7`，`header_1` 白底）+ 复制 + chevron → 资料页
class MineHeaderCard1 extends BaseCard {
  const MineHeaderCard1({super.key, required super.cardData});

  static const String _guestAvatarAsset =
      'assets/images/st_mine_guest_default_avatar.jpg';
  bool get _isHeader4 => cardData.cardStyle == 'header_4';

  @override
  Widget buildCardContent(BuildContext context) {
    // 顶部安全区由 CardListPage 的 SafeArea 承担，此处仅保留与稿面一致的间距
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: _MineLocalizedScope(
        cardNames: <String>[cardData.cardStyle, 'header_4', 'header_1'],
        fallbacks: _mineHeaderTextFallbacks,
        builder: (context, ref, strings) {
          final user = ref.watch(userStateProvider);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final router = ref.read(stRouterProvider);
          final detail = cardData.cardDetail;
          final serviceUrl = _pickHeaderToolbarIconUrl(detail, const [
            'service_icon',
            'customer_icon',
            'icon_service',
            'serviceIcon',
            'customerIcon',
          ], isDark);
          final settingUrl = _pickHeaderToolbarIconUrl(detail, const [
            'setting_icon',
            'setup_icon',
            'icon_setting',
            'settingIcon',
            'setupIcon',
          ], isDark);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _topIcon(
                    context,
                    isDark: isDark,
                    asset: 'st_login_service',
                    networkUrl: serviceUrl,
                    fallbackIcon: Icons.headset_mic_outlined,
                    tooltip: strings._t('contact_customer_service'),
                    onTap: () => CustomerServiceRoute.open(
                      context,
                      ref,
                      action: strings._t('contact_customer_service'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _topIcon(
                    context,
                    isDark: isDark,
                    asset: 'st_mine_setup',
                    networkUrl: settingUrl,
                    fallbackIcon: Icons.settings_outlined,
                    tooltip: strings._t('setting'),
                    onTap: () => router.openPage(context, '/mine/setting'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              user.hasActiveSession
                  ? _loggedHeader(context, ref, user, strings)
                  : _guestHeader(context, ref, strings),
            ],
          );
        },
      ),
    );
  }

  static const double _headerAvatarSize = 56;

  Widget _guestAvatar(BuildContext context) {
    return Image.asset(
      _guestAvatarAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ColoredBox(
        color: context.adaptiveIconPillBg,
        child: Icon(
          Icons.person_rounded,
          size: 30,
          color: context.adaptiveTextHint,
        ),
      ),
    );
  }

  Widget _topIcon(
    BuildContext context, {
    required bool isDark,
    required String asset,
    required IconData fallbackIcon,
    required String tooltip,
    required VoidCallback onTap,
    String? networkUrl,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: _mineHeaderToolbarIcon(
              context,
              isDark: isDark,
              assetName: asset,
              fallbackIcon: fallbackIcon,
              size: 22,
              networkUrl: networkUrl,
            ),
          ),
        ),
      ),
    );
  }

  Widget _guestHeader(
    BuildContext context,
    WidgetRef ref,
    _MineLocalizedStrings strings,
  ) {
    void goLogin() => ref.read(stRouterProvider).openPage(context, '/login');
    final t1 = context.adaptiveTextPrimary;
    final t2 = context.adaptiveTextTertiary;
    final t3 = context.adaptiveTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: goLogin,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: goLogin,
                child: Container(
                  width: _headerAvatarSize,
                  height: _headerAvatarSize,
                  decoration: BoxDecoration(
                    color: context.adaptiveCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.adaptiveHairline),
                  ),
                  child: ClipOval(child: _guestAvatar(context)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings._t('please_login'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 28 / 18,
                        color: t1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatIosPlaceholder(
                        strings._t('welcome_to_future_invest'),
                        BrandConfig.jufu().appNameEn,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w400,
                        color: t2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: t3),
            ],
          ),
        ),
      ),
    );
  }

  Color _idPillBackground(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return context.adaptiveCard;
    }
    return _isHeader4 ? context.adaptiveMutedBlock : Colors.white;
  }

  Widget _loggedHeader(
    BuildContext context,
    WidgetRef ref,
    UserState user,
    _MineLocalizedStrings strings,
  ) {
    Future<void> copyUid() async {
      if (user.userId.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: user.userId));
      if (context.mounted) {
        STToast.show(context, strings._t('replicating_success'));
      }
    }

    void openProfile() =>
        ref.read(stRouterProvider).openPage(context, '/mine/personalinfo');

    final nick = user.nickname.trim();
    final rawName = nick.isNotEmpty
        ? nick
        : (user.transactionAccount.isNotEmpty
              ? user.transactionAccount
              : (user.userId.isNotEmpty ? '用户${user.userId}' : '用户'));
    final displayName = mineMaskNicknameDisplay(rawName);

    final t1 = context.adaptiveTextPrimary;
    final t2 = context.adaptiveTextTertiary;
    final t3 = context.adaptiveTextSecondary;
    final pillBg = _idPillBackground(context);
    final pillMaxW =
        (MediaQuery.sizeOf(context).width - 32 - _headerAvatarSize - 16 - 28)
            .clamp(88.0, 560.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openProfile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: openProfile,
                child: Container(
                  width: _headerAvatarSize,
                  height: _headerAvatarSize,
                  decoration: BoxDecoration(
                    color: pillBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.adaptiveHairline),
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: context.adaptiveIconPillBg,
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: context.adaptiveTextHint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 28 / 18,
                        color: t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: pillMaxW),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Theme.of(context).brightness == Brightness.dark
                                ? Border.all(color: context.adaptiveDivider)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  user.userId.isEmpty
                                      ? 'ID: --'
                                      : 'ID: ${user.userId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 16 / 12,
                                    fontWeight: FontWeight.w400,
                                    color: t2,
                                  ),
                                ),
                              ),
                              if (user.userId.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: copyUid,
                                  behavior: HitTestBehavior.opaque,
                                  child: _mineLeadingImageAsset(
                                    context,
                                    'st_mine_copy_sec',
                                    14,
                                    fallbackIcon: Icons.copy_outlined,
                                    fallbackColor: t2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: t3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 我的页总资产（`balance_1` / `balance_2` 共用）：对齐 iOS 登录态金额、未登录 `--`、
/// B 面标题 `Balance (USD)`、点击钱包 / 登录。
class MineBalanceCard2 extends BaseCard {
  const MineBalanceCard2({super.key, required super.cardData});

  @override
  Widget buildCardContent(BuildContext context) {
    final balanceSubtitleStyle = TextStyle(
      fontSize: 12,
      color: context.adaptiveTextPrimary.withValues(alpha: 0.5),
      fontWeight: FontWeight.w400,
    );
    final amountColor = Theme.of(context).brightness == Brightness.dark
        ? context.adaptiveTextPrimary
        : const Color(0xFF2F3E58);
    final loggedStyle = TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w500,
      color: amountColor,
    );
    final guestStyle = TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w300,
      color: amountColor,
    );

    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(userStateProvider);
        final isLogin = user.isLogin;

        return _MineLocalizedScope(
          cardNames: <String>[cardData.cardStyle, 'balance_2', 'balance_1'],
          fallbacks: _mineBalanceTextFallbacks,
          builder: (context, ref, strings) {
            final title = _withCurrency(strings._t('account_equity'), 'USD');
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => isLogin
                        ? context.push('/mine/wallet')
                        : context.push('/login'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title, style: balanceSubtitleStyle),
                        const SizedBox(width: 2),
                        _mineLeadingImageAsset(
                          context,
                          'st_mine_arrow_right',
                          14,
                          fallbackIcon: Icons.chevron_right,
                          fallbackColor: context.adaptiveTextSecondary,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => isLogin
                        ? context.push('/mine/wallet')
                        : context.push('/login'),
                    child: Text(
                      isLogin
                          ? CardTool.formatBalanceAmount(user.totalAmountUSD)
                          : '--',
                      style: isLogin ? loggedStyle : guestStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// `grid + grid_1` 圆形快捷入口（入金 / 出金 / 持仓）
class MineGridQuickCard1 extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const MineGridQuickCard1({
    super.key,
    required super.cardData,
    this.onNavigate,
  });

  static const double _iconSize = 28;
  static const double _gap = 7;
  static const int _maxItemsPerPage = 5;
  static const double _singlePageHeight = 95;
  static const double _pagedContentHeight = 80;
  static const double _itemHeight = 52;
  static const double _indicatorRailWidth = 25;
  static const double _indicatorSliderWidth = 13;
  static const double _indicatorHeight = 3;
  static const double _indicatorZoneHeight = 15;

  @override
  Widget buildCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _MineLocalizedScope(
        cardNames: const <String>[],
        fallbacks: _mineGridTextFallbacks,
        builder: (context, ref, strings) {
          final detail = cardData.cardDetail;
          final rawItems = detail?['items'] as List<dynamic>?;
          final List<Map<String, dynamic>> items;
          if (rawItems == null || rawItems.isEmpty) {
            items = [
              {
                'title': strings._t('deposit'),
                'icon_asset': 'st_mine_deposit_th',
                'router': '/mine/deposit',
              },
              {
                'title': strings._t('withdrawal'),
                'icon_asset': 'st_mine_draw_th',
                'router': '/mine/draw',
              },
              {
                'title': strings._t('positions'),
                'icon_asset': 'st_mine_position',
                'router': '/trade/positions',
              },
            ];
          } else {
            items = rawItems.map((e) => e as Map<String, dynamic>).toList();
          }
          return _MineGridQuickCard1Body(items: items, onNavigate: onNavigate);
        },
      ),
    );
  }
}

class _MineGridQuickCard1Body extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final CardNavigateCallback? onNavigate;

  const _MineGridQuickCard1Body({
    required this.items,
    required this.onNavigate,
  });

  @override
  State<_MineGridQuickCard1Body> createState() =>
      _MineGridQuickCard1BodyState();
}

class _MineGridQuickCard1BodyState extends State<_MineGridQuickCard1Body> {
  final PageController _controller = PageController();
  double _scrollPage = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    if ((page - _scrollPage).abs() < 0.5) return;
    setState(() {
      _scrollPage = page;
    });
  }

  int _pageCount() =>
      (widget.items.length / MineGridQuickCard1._maxItemsPerPage).ceil();

  List<Map<String, dynamic>> _pageItems(int index) {
    final start = index * MineGridQuickCard1._maxItemsPerPage;
    if (start >= widget.items.length) return const [];
    final end = min(
      start + MineGridQuickCard1._maxItemsPerPage,
      widget.items.length,
    );
    return widget.items.sublist(start, end);
  }

  void _handleItemTap(BuildContext context, Map<String, dynamic> item) {
    final route = CardFactory.extractItemRoute(item);
    if (route.path.isEmpty) return;
    final title = item['title'] as String? ?? '';
    widget.onNavigate?.call(
      route.path,
      route.params,
      action: title.isNotEmpty ? 'Grid-$title' : 'Grid入口',
    );
  }

  Widget _buildItem(
    BuildContext context,
    Map<String, dynamic> item,
    double itemWidth,
  ) {
    final title = item['title'] as String? ?? '';
    final asset = item['icon_asset'] as String? ?? '';

    return SizedBox(
      width: itemWidth,
      height: MineGridQuickCard1._itemHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleItemTap(context, item),
        child: Column(
          children: [
            SizedBox(
              width: MineGridQuickCard1._iconSize,
              height: MineGridQuickCard1._iconSize,
              child: asset.isNotEmpty
                  ? _mineLeadingImageAsset(
                      context,
                      asset,
                      MineGridQuickCard1._iconSize,
                    )
                  : Icon(
                      Icons.circle,
                      size: MineGridQuickCard1._iconSize,
                      color: context.adaptiveTextHint,
                    ),
            ),
            const SizedBox(height: MineGridQuickCard1._gap),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.length <= MineGridQuickCard1._maxItemsPerPage) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final count = widget.items.length;
          final itemWidth = count < 1 ? width : width / count;

          return SizedBox(
            height: MineGridQuickCard1._singlePageHeight,
            child: Center(
              child: Row(
                children: widget.items
                    .map((item) => _buildItem(context, item, itemWidth))
                    .toList(),
              ),
            ),
          );
        },
      );
    }

    final totalPages = _pageCount();
    final maxOffset = max(totalPages - 1, 0);
    final needsIndicator = totalPages > 1;
    final contentHeight = MineGridQuickCard1._pagedContentHeight;
    final totalHeight =
        contentHeight +
        (needsIndicator ? MineGridQuickCard1._indicatorZoneHeight : 0);
    final sliderTravel = needsIndicator && maxOffset > 0
        ? (_scrollPage.clamp(0.0, maxOffset.toDouble()) / maxOffset) *
              (MineGridQuickCard1._indicatorRailWidth -
                  MineGridQuickCard1._indicatorSliderWidth)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return SizedBox(
          width: width,
          height: totalHeight,
          child: Stack(
            children: [
              SizedBox(
                height: contentHeight,
                child: PageView.builder(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: totalPages,
                  onPageChanged: (page) {
                    if ((_scrollPage - page).abs() < 0.5) return;
                    setState(() {
                      _scrollPage = page.toDouble();
                    });
                  },
                  itemBuilder: (context, index) {
                    final pageItems = _pageItems(index);
                    final itemWidth =
                        width / MineGridQuickCard1._maxItemsPerPage;
                    return SizedBox(
                      height: contentHeight,
                      child: Center(
                        child: Row(
                          children: List.generate(
                            MineGridQuickCard1._maxItemsPerPage,
                            (i) {
                              if (i >= pageItems.length) {
                                return SizedBox(width: itemWidth);
                              }
                              return _buildItem(
                                context,
                                pageItems[i],
                                itemWidth,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (needsIndicator)
                Positioned(
                  left: (width - MineGridQuickCard1._indicatorRailWidth) / 2,
                  top:
                      contentHeight +
                      (MineGridQuickCard1._indicatorZoneHeight -
                              MineGridQuickCard1._indicatorHeight) /
                          2,
                  child: Container(
                    width: MineGridQuickCard1._indicatorRailWidth,
                    height: MineGridQuickCard1._indicatorHeight,
                    decoration: BoxDecoration(
                      color:
                          CardTool.parseAdaptiveHexColor(
                            context,
                            '#ECECEC',
                            category: CardTool.iosDarkModeChildBgColorKey,
                          ) ??
                          const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: Offset(sliderTravel, 0),
                      child: Container(
                        width: MineGridQuickCard1._indicatorSliderWidth,
                        height: MineGridQuickCard1._indicatorHeight,
                        decoration: BoxDecoration(
                          color: context.adaptiveTextPrimary,
                          borderRadius: BorderRadius.circular(1.5),
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
}

/// `vip + vip_1` 对齐 iOS STVipCardView + MinePage Figma
class MineVipCard1 extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const MineVipCard1({super.key, required super.cardData, this.onNavigate});

  @override
  Widget buildCardContent(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(userStateProvider);
        if (!user.isLogin || user.isB) return const SizedBox.shrink();

        final vip = user.vipLevelPayload;
        Map<String, dynamic> lvlMap(dynamic v) {
          if (v is Map<String, dynamic>) return Map<String, dynamic>.from(v);
          if (v is Map) {
            return v.map((k, dynamic val) => MapEntry(k.toString(), val));
          }
          return <String, dynamic>{};
        }

        final cur = lvlMap(vip['current_level']);
        final currentLevelName =
            UserState.pickString(cur, ['name'])?.trim() ?? '';
        dynamic pendingRaw = vip['pending_level'];
        final Map<String, dynamic> nextLvl =
            pendingRaw is Map && pendingRaw.isNotEmpty
            ? lvlMap(pendingRaw)
            : lvlMap(vip['next_level']);
        final nextName = UserState.pickString(nextLvl, ['name'])?.trim() ?? '';

        late final double progressRatio;
        late final String centerMsg;
        if (nextName.isNotEmpty) {
          final pr = vip['progress'];
          if (pr is num) {
            progressRatio = pr.toDouble().clamp(0.0, 1.0);
          } else {
            progressRatio =
                double.tryParse(pr?.toString() ?? '')?.clamp(0.0, 1.0) ?? 0.6;
          }
          centerMsg = '升级$nextName享更多权益，收益提升200%';
        } else {
          progressRatio = 1.0;
          final nm = currentLevelName.isNotEmpty ? currentLevelName : 'VIP';
          centerMsg = '期待解锁更高的$nm专属权益';
        }

        final String titleBadge = currentLevelName.isNotEmpty
            ? currentLevelName
            : 'VIP1';
        final double fillFactor = vip.isEmpty
            ? 0.6
            : progressRatio.clamp(0.0, 1.0);
        // 数值进度，如 200/1000
        final currentScore =
            vip['current_score'] ??
            vip['current_exp'] ??
            (fillFactor * 1000).round();
        final targetScore = vip['target_score'] ?? vip['target_exp'] ?? 1000;
        final progressText = '$currentScore/$targetScore';

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 17, 0),
          child: GestureDetector(
            onTap: () {
              if (user.isLogin) {
                context.push('/vipcenter');
              } else {
                context.push('/login');
              }
            },
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1E4B), Color(0xFF2D2D5A)],
                ),
              ),
              child: Stack(
                children: [
                  // 左上：升级提示
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Text(
                      centerMsg,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCCCCCC),
                      ),
                    ),
                  ),
                  // 中左：我的等级 + 进度条 + 数值
                  Positioned(
                    left: 16,
                    top: 46,
                    right: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '我的等级',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                        Text(
                          titleBadge,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: fillFactor,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          progressText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右上：VIP 图标
                  Positioned(
                    top: 8,
                    right: 16,
                    child: _mineLeadingImageAsset(
                      context,
                      'st_mine_vip_icon',
                      56,
                    ),
                  ),
                  // 右下：去升级按钮
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFFFE4C4),
                      ),
                      child: const Text(
                        '去升级',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `account + account_3`（Figma `2:7637`–`2:7681` / iOS：无单独「账户类型+管理」顶栏，
/// 仅深色净值卡 + 白底返佣区；访客返佣摘要由 [CardListController] 拉取）
class MineAccountCard3 extends BaseCard {
  const MineAccountCard3({super.key, required super.cardData});

  static const LinearGradient _equityGradient = LinearGradient(
    begin: Alignment(-0.82, -0.86),
    end: Alignment(0.92, 0.98),
    colors: [Color(0xFF0B0A01), Color(0xFF0B0802), Color(0xFFDF9815)],
    stops: [0.082365, 0.68505, 1.0],
  );

  static const Color _onGradientPrimary = Color(0xFFEDF1F8);
  static const Color _onGradientMuted = Color(0xFFABAFB8);
  static const String _switchIcon = 'account_3_change';
  static const String _trendIcon = 'account_3_top_right_icon';
  static const String _inviteIcon = 'account_3_invite';

  Widget _marginLevelOnDark(String raw) {
    final v = raw.trim();
    if (!v.endsWith('%')) {
      return Text(
        v,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _onGradientPrimary,
        ),
      );
    }
    final body = v.substring(0, v.length - 1).trim();
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: _onGradientPrimary,
        ),
        children: [
          TextSpan(text: body, style: const TextStyle(fontSize: 16)),
          const TextSpan(text: '%', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget buildCardContent(BuildContext context) {
    return _MineLocalizedScope(
      cardNames: <String>[cardData.cardStyle, 'account_3'],
      fallbacks: _mineAccount3TextFallbacks,
      builder: (context, ref, strings) {
        final userState = ref.watch(userStateProvider);
        final isLogin = userState.isLogin;
        final current = minePageCurrentTradeAccount(userState);
        final isB = userState.isB;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final loadingAccountDetail = isLogin && userState.accountAry.isEmpty;

        void openHelp() {
          final ml = minePageCurrentTradeAccount(userState).marginLevel;
          final append = userState.appendMarginLevel.isNotEmpty
              ? userState.appendMarginLevel
              : '50';
          final close = userState.closeMarginLevel.isNotEmpty
              ? userState.closeMarginLevel
              : '30';

          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MarginLevelHelpSheet(
              marginLevel: ml.isNotEmpty ? ml : '--',
              appendMarginLevel: append,
              closeMarginLevel: close,
              onDetail: () {
                Navigator.of(context).pop();
                final appendVal = double.tryParse(append) ?? 0;
                final safe = appendVal + 50;
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MarginLevelDetailSheet(
                    appendMarginLevel: append,
                    closeMarginLevel: close,
                    safeMarginLevel: safe.toStringAsFixed(0),
                  ),
                );
              },
            ),
          );
        }

        final equity = current.balance.isNotEmpty && isLogin
            ? CardTool.formatBalanceAmount(current.balance)
            : '--';
        final marginLv = isLogin && current.marginLevel.isNotEmpty
            ? current.marginLevel
            : '--';
        final profit = isLogin && current.profit.isNotEmpty
            ? CardTool.formatBalanceAmount(current.profit)
            : '--';

        void onInvite() {
          final raw = mineAccount3InviteH5Url(ref, cardData.cardDetail);
          if (raw != null && raw.isNotEmpty) {
            ref
                .read(stRouterProvider)
                .openPage(
                  context,
                  '/web',
                  params: {'link': raw},
                  action: '邀请好友',
                );
            return;
          }
          ref
              .read(stRouterProvider)
              .openPage(context, '/partner', action: '邀请好友');
        }

        void onEquityCardTap() {
          if (!isLogin) {
            context.push('/login');
            return;
          }
          context.push('/mine/wallet');
        }

        void onSwitchAccountTap() {
          if (!isLogin) {
            context.push('/login');
            return;
          }
          context.push('/mine/accountmanager');
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: onEquityCardTap,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: _equityGradient,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: loadingAccountDetail
                            ? const SizedBox(
                                height: 104,
                                child: Center(child: STLoadAnimationView()),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  strings._t('balance'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    height: 16 / 12,
                                                    fontWeight: FontWeight.w400,
                                                    color: _onGradientPrimary
                                                        .withValues(alpha: 0.9),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                InkWell(
                                                  onTap: onSwitchAccountTap,
                                                  child: _mineLeadingImageAsset(
                                                    context,
                                                    _switchIcon,
                                                    16,
                                                    fit: BoxFit.contain,
                                                    fallbackIcon: Icons
                                                        .swap_horiz_rounded,
                                                    fallbackColor:
                                                        _onGradientPrimary
                                                            .withValues(
                                                              alpha: 0.85,
                                                            ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              equity,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                height: 32 / 24,
                                                fontWeight: FontWeight.w700,
                                                color: _onGradientPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Material(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        child: IgnorePointer(
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: Center(
                                              child: _mineLeadingImageAsset(
                                                context,
                                                _trendIcon,
                                                16,
                                                fit: BoxFit.contain,
                                                fallbackIcon:
                                                    Icons.show_chart_rounded,
                                                fallbackColor:
                                                    _onGradientPrimary
                                                        .withValues(
                                                          alpha: 0.85,
                                                        ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: openHelp,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                strings._t('margin_level'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  height: 16 / 12,
                                                  fontWeight: FontWeight.w400,
                                                  color: _onGradientMuted
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              marginLv.endsWith('%')
                                                  ? _marginLevelOnDark(marginLv)
                                                  : Text(
                                                      marginLv,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        height: 24 / 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            _onGradientPrimary,
                                                      ),
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              strings._t(
                                                'floating_profit_loss',
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 16 / 12,
                                                fontWeight: FontWeight.w400,
                                                color: _onGradientMuted
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              profit,
                                              style: TextStyle(
                                                fontSize: 16,
                                                height: 24 / 16,
                                                fontWeight: FontWeight.w700,
                                                color: _onGradientPrimary,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              // 非 B 面展示佣金/邀请区（对齐 iOS）
              if (!isB && !loadingAccountDetail) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: context.adaptiveCard,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    border: isDark
                        ? Border.all(color: context.adaptiveDivider)
                        : Border.all(color: context.adaptiveHairline),
                  ),
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings._t('my_commission'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w700,
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _rebateColumn(
                              context,
                              strings._t('all'),
                              userState.totalRevenue.isNotEmpty
                                  ? userState.totalRevenue
                                  : '--',
                            ),
                          ),
                          Expanded(
                            child: _rebateColumn(
                              context,
                              strings._t('account3_commission_obtained'),
                              userState.withdrawnFunds.isNotEmpty
                                  ? userState.withdrawnFunds
                                  : '--',
                            ),
                          ),
                          Expanded(
                            child: _rebateColumn(
                              context,
                              strings._t(
                                'account3_commission_pending_withdraw',
                              ),
                              userState.canWithdraw.isNotEmpty
                                  ? userState.canWithdraw
                                  : '--',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: context.adaptiveMutedBlock,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: onInvite,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.adaptiveHairline,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  strings._t('send_an_invitation'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 16 / 12,
                                    fontWeight: FontWeight.w500,
                                    color: context.adaptiveTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                _mineLeadingImageAsset(
                                  context,
                                  _inviteIcon,
                                  14,
                                  fallbackIcon: Icons.north_east_rounded,
                                  fallbackColor: context.adaptiveTextPrimary
                                      .withValues(alpha: 0.75),
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _rebateColumn(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w400,
            color: context.adaptiveTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            height: 20 / 18,
            fontWeight: FontWeight.w700,
            color: context.adaptiveTextPrimary,
          ),
        ),
      ],
    );
  }
}

/// `list-component + list_1`（支持 `icon_asset` 与绑定态 subtitle）
class MineListCard1 extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const MineListCard1({super.key, required super.cardData, this.onNavigate});

  static const double _rowHeight = 60;
  static const double _leadingInset = 15;

  (String subtitle, Color color) _subtitleForMineMode(
    BuildContext context,
    UserState user,
    Map<String, dynamic> item,
    _MineLocalizedStrings strings,
  ) {
    final mode = item['mine_subtitle_mode'] as String?;

    if (mode == null || mode.isEmpty) {
      final subTitle =
          item['sub_title'] as String? ?? item['subTitle'] as String? ?? '';
      final hex =
          item['sub_title_color'] as String? ??
          item['subTitleColor'] as String?;
      final c =
          CardTool.parseAdaptiveHexColor(
            context,
            hex,
            category: CardTool.iosDarkModeTextColorKey,
          ) ??
          context.adaptiveTextTertiary;
      return (subTitle, c);
    }

    if (mode == 'auth') {
      final s = user.authStatus;
      if (s.isApproved || s.status == 'approved') {
        return (strings._t('already_auth'), const Color(0xFF4DCB73));
      }
      if (s.status == 'rejected' || s.status == STUserAuthStatus.failed) {
        return (strings._t('authentication_failed'), const Color(0xFFF95959));
      }
      if (s.status == STUserAuthStatus.wait || s.status == 'pending') {
        return (strings._t('under_review'), const Color(0xFFFF7913));
      }
      return (strings._t('certification'), const Color(0xFF00B57A));
    }
    if (mode == 'bank') {
      return user.isBindBankCard
          ? (strings._t('bind'), context.adaptiveTextSecondary)
          : (strings._t('go_bind'), const Color(0xFF00B57A));
    }
    if (mode == 'ewallet') {
      return user.isBindEWallet
          ? (strings._t('bind'), context.adaptiveTextSecondary)
          : (strings._t('go_bind'), const Color(0xFF00B57A));
    }

    final subTitle =
        item['sub_title'] as String? ?? item['subTitle'] as String? ?? '';
    return (subTitle, Theme.of(context).colorScheme.onSurface);
  }

  Widget _leadingIcon(
    BuildContext context,
    Map<String, dynamic> item,
    bool dark,
  ) {
    final asset =
        item['icon_asset'] as String? ?? item['iconAsset'] as String? ?? '';
    if (asset.isNotEmpty) {
      return SizedBox(
        width: 30,
        height: 30,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _mineLeadingImageAsset(context, asset, 30, fit: BoxFit.cover),
        ),
      );
    }
    final iconLight = item['icon'] as String?;
    final iconDark =
        item['icon_dark'] as String? ??
        item['iconDark'] as String? ??
        iconLight;
    final url = dark ? iconDark : iconLight;
    return SizedBox(
      width: 30,
      height: 30,
      child: url != null && url.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.circle,
                  size: 28,
                  color: context.adaptiveTextHint,
                ),
              ),
            )
          : Icon(Icons.circle, size: 28, color: context.adaptiveTextHint),
    );
  }

  @override
  Widget buildCardContent(BuildContext context) {
    final detail = cardData.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) => e as Map<String, dynamic>).toList();

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            cardData.title ?? '列表',
            style: TextStyle(color: context.adaptiveTextHint),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _MineLocalizedScope(
      cardNames: const <String>[],
      fallbacks: _mineListTextFallbacks,
      builder: (context, ref, strings) {
        final user = ref.watch(userStateProvider);
        return Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final title = item['title'] as String? ?? '';
            final route = CardFactory.extractItemRoute(item);
            final sub = _subtitleForMineMode(context, user, item, strings);
            final isLast = index == items.length - 1;

            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (route.path.isEmpty) return;
                      onNavigate?.call(route.path, route.params);
                    },
                    child: SizedBox(
                      height: _rowHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: _leadingInset,
                          right: _leadingInset,
                        ),
                        child: Row(
                          children: [
                            _leadingIcon(context, item, isDark),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (sub.$1.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                sub.$1,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: sub.$2,
                                ),
                              ),
                            ],
                            const SizedBox(width: 15),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: context.adaptiveTextTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: _leadingInset,
                    endIndent: 0,
                    color: context.adaptiveMutedBlock,
                  ),
              ],
            );
          }),
        );
      },
    );
  }
}
