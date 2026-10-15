import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_card.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/router/st_router.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../features/mine/mine_margin_sheets.dart';

/// 账户卡片 `account_1` ~ `account_2`
///
/// 对齐 iOS `Account1CardView` / `Account2CardView`：账户顶栏、三列指标、
/// 返佣区域、保证金说明、账户管理与邀请入口。
class AccountCard extends BaseCard {
  const AccountCard({super.key, required super.cardData});

  static const String _accountManageAction = 'account_manage';
  static const String _loginAction = 'login_now';
  static const String _inviteFriendsAction = 'invite_friends';

  @override
  Widget buildCardContent(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(userStateProvider);
        final data = _AccountCardData.from(user);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return switch (cardData.cardStyle) {
          'account_2' => _Account2View(
            data: data,
            isDark: isDark,
            detail: cardData.cardDetail,
            cardName: 'account_2',
          ),
          'account_1' => _Account1View(
            data: data,
            isDark: isDark,
            detail: cardData.cardDetail,
            cardName: 'account_1',
          ),
          _ => _Account1View(
            data: data,
            isDark: isDark,
            detail: cardData.cardDetail,
            cardName: 'account_1',
          ),
        };
      },
    );
  }

  static void openManage(BuildContext context, WidgetRef ref, bool loggedIn) {
    ref
        .read(stRouterProvider)
        .openPage(
          context,
          loggedIn ? '/mine/accountmanager' : '/login',
          action: loggedIn ? _accountManageAction : _loginAction,
        );
  }

  static void openInvite(
    BuildContext context,
    WidgetRef ref,
    bool loggedIn,
    Map<String, dynamic>? detail,
  ) {
    if (!loggedIn) {
      ref
          .read(stRouterProvider)
          .openPage(context, '/login', action: _loginAction);
      return;
    }

    final link = _inviteUrl(ref, detail);
    if (link.isNotEmpty) {
      ref
          .read(stRouterProvider)
          .openPage(
            context,
            '/web',
            params: {'link': link},
            action: _inviteFriendsAction,
          );
      return;
    }
    ref
        .read(stRouterProvider)
        .openPage(context, '/partner', action: _inviteFriendsAction);
  }

  static Future<void> _openHelp(
    BuildContext context,
    WidgetRef ref,
    _AccountCardData data,
  ) async {
    if (!data.loggedIn) return;

    final user = ref.read(userStateProvider);
    final append = user.appendMarginLevel.isNotEmpty
        ? user.appendMarginLevel
        : '50';
    final close = user.closeMarginLevel.isNotEmpty
        ? user.closeMarginLevel
        : '30';
    final safe = (double.tryParse(append) ?? 50) + 50;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MarginLevelHelpSheet(
        marginLevel: data.marginLevel,
        appendMarginLevel: append,
        closeMarginLevel: close,
        onDetail: () {
          Navigator.of(context).pop();
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

  static String _inviteUrl(WidgetRef ref, Map<String, dynamic>? detail) {
    final d = detail ?? const <String, dynamic>{};
    for (final key in const [
      'partnerUrl',
      'partner_url',
      'inviteUrl',
      'invite_url',
      'link',
    ]) {
      final value = d[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final routerModel = d['routerModel'] ?? d['router_model'];
    if (routerModel is Map) {
      final link = routerModel['link'];
      if (link is String && link.trim().isNotEmpty) return link.trim();
    }
    final h5 = ref.read(configDataManagerProvider).h5Config;
    final partner = h5?['partner_url'];
    return partner is String ? partner.trim() : '';
  }
}

class _AccountCardData {
  final bool loggedIn;
  final bool isB;
  final String accountType;
  final String accountId;
  final String accountAsset;
  final String equity;
  final String marginLevel;
  final String floatingProfit;
  final String totalRevenue;
  final String canWithdraw;
  final String withdrawnFunds;
  final Color profitColor;

  const _AccountCardData({
    required this.loggedIn,
    required this.isB,
    required this.accountType,
    required this.accountId,
    required this.accountAsset,
    required this.equity,
    required this.marginLevel,
    required this.floatingProfit,
    required this.totalRevenue,
    required this.canWithdraw,
    required this.withdrawnFunds,
    required this.profitColor,
  });

  factory _AccountCardData.from(UserState user) {
    final current = _currentAccount(user);
    final loggedIn = user.hasActiveSession;
    final profitRaw = loggedIn ? current?.profit ?? '' : '';
    final profitNumber = double.tryParse(profitRaw.replaceAll(',', ''));
    CardTool.setRiseAndFallType(user.riseAndFallType);

    return _AccountCardData(
      loggedIn: loggedIn,
      isB: user.isB,
      accountType: loggedIn
          ? _nonEmpty(current?.accountType, user.transactionAccountType, '--')
          : '--',
      accountId: '',
      accountAsset: _assetForAccount(current),
      equity: loggedIn ? _money(current?.equity) : '--',
      marginLevel: loggedIn ? _nonEmpty(current?.marginLevel, '--') : '--',
      floatingProfit: loggedIn ? _money(profitRaw) : '--',
      totalRevenue: loggedIn ? _money(user.totalRevenue) : '--',
      canWithdraw: loggedIn ? _money(user.canWithdraw) : '--',
      withdrawnFunds: loggedIn ? _money(user.withdrawnFunds) : '--',
      profitColor: loggedIn && profitNumber != null
          ? CardTool.priceColor(profitNumber)
          : const Color(0xFF000000),
    );
  }

  static STAccountModel? _currentAccount(UserState user) {
    if (user.accountAry.isEmpty) return null;
    if (user.isB) {
      for (final account in user.accountAry) {
        if (account.type == '1') return account;
      }
      return user.accountAry.first;
    }
    for (final account in user.accountAry) {
      if (account.accountId == user.transactionAccount &&
          account.accountId.isNotEmpty) {
        return account;
      }
    }
    return user.accountAry.first;
  }

  static String _assetForAccount(STAccountModel? account) {
    final type = int.tryParse(account?.type ?? '');
    return switch (type) {
      0 || 4 => 'st_mine_firm',
      1 => 'st_mine_simulate',
      2 => '',
      _ => 'st_mine_trans',
    };
  }

  static String _money(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return '--';
    return CardTool.formatBalanceAmount(text);
  }

  static String _nonEmpty(
    String? first,
    String second, [
    String fallback = '',
  ]) {
    final a = first?.trim() ?? '';
    if (a.isNotEmpty) return a;
    final b = second.trim();
    if (b.isNotEmpty) return b;
    return fallback;
  }
}

class _Account1View extends ConsumerWidget {
  final _AccountCardData data;
  final bool isDark;
  final Map<String, dynamic>? detail;
  final String cardName;

  const _Account1View({
    required this.data,
    required this.isDark,
    required this.detail,
    required this.cardName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = isDark ? context.adaptiveTextPrimary : Colors.black;
    final panel = isDark ? context.adaptiveCard : Colors.white;
    final topBg = isDark
        ? context.adaptiveCard.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.54);

    return Padding(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          _TopAccountBar(
            data: data,
            cardName: cardName,
            height: 58,
            yOffset: -7,
            backgroundColor: topBg,
            textColor: primary,
            manageColor: primary,
            manageIcon: 'st_mine_arrow_right',
            showManage: !data.isB,
            onManage: () => AccountCard.openManage(context, ref, data.loggedIn),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 44),
            padding: const EdgeInsets.fromLTRB(17, 32, 17, 17),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AccountGridRow(
                  items: [
                    _AccountGridItem(
                      cardName: cardName,
                      titleKey: 'account_equity',
                      titleFallback: '净值',
                      value: data.equity,
                    ),
                    _AccountGridItem(
                      cardName: cardName,
                      titleKey: 'margin_level',
                      titleFallback: '保证金水平',
                      value: data.marginLevel,
                      help: true,
                    ),
                    _AccountGridItem(
                      cardName: cardName,
                      titleKey: 'floating_profit_loss',
                      titleFallback: '浮动盈亏',
                      value: data.floatingProfit,
                      valueColor: data.loggedIn
                          ? data.profitColor
                          : (isDark
                                ? context.adaptiveTextPrimary
                                : Colors.black),
                      alignEnd: true,
                    ),
                  ],
                  onHelp: () => AccountCard._openHelp(context, ref, data),
                ),
                if (!data.isB) ...[
                  const SizedBox(height: 24),
                  _CommissionHeader(
                    cardName: cardName,
                    titleKey: 'my_commission',
                    titleFallback: '我的佣金',
                    actionKey: 'send_an_invitation',
                    actionFallback: '立即邀请',
                    inlineAction: true,
                    onAction: () => AccountCard.openInvite(
                      context,
                      ref,
                      data.loggedIn,
                      detail,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AccountGridRow(
                    items: [
                      _AccountGridItem(
                        cardName: cardName,
                        titleKey: 'total_revenue',
                        titleFallback: '总收益',
                        value: data.totalRevenue,
                      ),
                      _AccountGridItem(
                        cardName: cardName,
                        titleKey: 'enable_draw',
                        titleFallback: '可出金',
                        value: data.canWithdraw,
                      ),
                      _AccountGridItem(
                        cardName: cardName,
                        titleKey: 'has_draw',
                        titleFallback: '已出金',
                        value: data.withdrawnFunds,
                        alignEnd: true,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Account2View extends ConsumerWidget {
  final _AccountCardData data;
  final bool isDark;
  final Map<String, dynamic>? detail;
  final String cardName;

  const _Account2View({
    required this.data,
    required this.isDark,
    required this.detail,
    required this.cardName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = isDark ? context.adaptiveTextPrimary : Colors.black;

    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isDark
                ? 'assets/images/account_2_bg_dark.png'
                : 'assets/images/account_2_bg.png',
          ),
          fit: BoxFit.fill,
          onError: (_, __) {},
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TopAccountBar(
              data: data,
              cardName: cardName,
              height: 58,
              yOffset: -7,
              backgroundColor: Colors.transparent,
              textColor: primary,
              manageColor: const Color(0xFF00B57A),
              manageIcon: isDark
                  ? 'account_2_change_cmsdark'
                  : 'account_2_change',
              showManage: !data.isB,
              iconBeforeText: true,
              onManage: () =>
                  AccountCard.openManage(context, ref, data.loggedIn),
            ),
            Transform.translate(
              offset: const Offset(0, -14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(17, 32, 17, 17),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AccountGridRow(
                      items: [
                        _AccountGridItem(
                          cardName: cardName,
                          titleKey: 'account_equity',
                          titleFallback: '账户净值',
                          value: data.equity,
                        ),
                        _AccountGridItem(
                          cardName: cardName,
                          titleKey: 'margin_level',
                          titleFallback: '保证金水平',
                          value: data.marginLevel,
                        ),
                        _AccountGridItem(
                          cardName: cardName,
                          titleKey: 'floating_profit_loss',
                          titleFallback: '浮动盈亏',
                          value: data.floatingProfit,
                          valueColor: data.loggedIn
                              ? data.profitColor
                              : (isDark
                                    ? context.adaptiveTextPrimary
                                    : Colors.black),
                          alignEnd: true,
                        ),
                      ],
                    ),
                    if (!data.isB) ...[
                      const SizedBox(height: 24),
                      _CommissionHeader(
                        cardName: cardName,
                        titleKey: 'earnings_details',
                        titleFallback: '收益明细',
                      ),
                      const SizedBox(height: 16),
                      _AccountGridRow(
                        items: [
                          _AccountGridItem(
                            cardName: cardName,
                            titleKey: 'total_revenue',
                            titleFallback: '全部',
                            value: data.totalRevenue,
                          ),
                          _AccountGridItem(
                            cardName: cardName,
                            titleKey: 'has_draw',
                            titleFallback: '已获得收益',
                            value: data.withdrawnFunds,
                          ),
                          _AccountGridItem(
                            cardName: cardName,
                            titleKey: 'enable_draw',
                            titleFallback: '待提现',
                            value: data.canWithdraw,
                            alignEnd: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: SizedBox(
                          width: 150,
                          height: 36,
                          child: FilledButton(
                            onPressed: () => AccountCard.openInvite(
                              context,
                              ref,
                              data.loggedIn,
                              detail,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00B57A),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: _CardLocalizedText(
                              cardName: cardName,
                              textKey: 'send_an_invitation',
                              fallback: '立即邀请',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopAccountBar extends StatelessWidget {
  final _AccountCardData data;
  final String cardName;
  final double height;
  final double yOffset;
  final Color backgroundColor;
  final Color textColor;
  final Color manageColor;
  final String manageIcon;
  final bool showManage;
  final bool iconBeforeText;
  final VoidCallback onManage;

  const _TopAccountBar({
    required this.data,
    required this.cardName,
    required this.height,
    required this.yOffset,
    required this.backgroundColor,
    required this.textColor,
    required this.manageColor,
    required this.manageIcon,
    required this.showManage,
    required this.onManage,
    this.iconBeforeText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Transform.translate(
        offset: Offset(0, yOffset),
        child: Row(
          children: [
            const SizedBox(width: 15),
            _AccountAssetIcon(asset: data.accountAsset),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                data.accountType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (data.accountId.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                data.accountId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: CardTool.iosMutedLabel,
                ),
              ),
            ],
            const Spacer(),
            if (showManage)
              TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(
                  foregroundColor: manageColor,
                  minimumSize: const Size(0, 24),
                  padding: const EdgeInsets.only(left: 13, right: 5),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: iconBeforeText
                      ? [
                          _SmallAssetIcon(asset: manageIcon),
                          const SizedBox(width: 4),
                          _CardLocalizedText(
                            cardName: cardName,
                            textKey: 'manage',
                            fallback: '管理',
                            style: TextStyle(
                              color: manageColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]
                      : [
                          _CardLocalizedText(
                            cardName: cardName,
                            textKey: 'manage',
                            fallback: '管理',
                            style: TextStyle(
                              color: manageColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          _SmallAssetIcon(asset: manageIcon),
                        ],
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _AccountAssetIcon extends StatelessWidget {
  final String asset;

  const _AccountAssetIcon({required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset.isEmpty) return const SizedBox(width: 20, height: 20);
    return Image.asset(
      'assets/images/$asset.png',
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.account_balance_wallet_outlined,
        size: 20,
        color: context.adaptiveTextHint,
      ),
    );
  }
}

class _SmallAssetIcon extends StatelessWidget {
  final String asset;

  const _SmallAssetIcon({required this.asset});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      'assets/images/$asset.png',
      width: 14,
      height: 14,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.chevron_right,
        size: 14,
        color: isDark
            ? context.adaptiveTextPrimary.withValues(alpha: 0.58)
            : CardTool.iosMutedLabel,
      ),
    );
  }
}

class _AccountGridItem {
  final String cardName;
  final String titleKey;
  final String titleFallback;
  final String value;
  final Color? valueColor;
  final bool help;
  final bool alignEnd;

  const _AccountGridItem({
    required this.cardName,
    required this.titleKey,
    required this.titleFallback,
    required this.value,
    this.valueColor,
    this.help = false,
    this.alignEnd = false,
  });
}

class _AccountGridRow extends StatelessWidget {
  final List<_AccountGridItem> items;
  final VoidCallback? onHelp;

  const _AccountGridRow({required this.items, this.onHelp});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _AccountMetric(item: items[i], onHelp: onHelp),
          ),
        ],
      ],
    );
  }
}

class _AccountMetric extends StatelessWidget {
  final _AccountGridItem item;
  final VoidCallback? onHelp;

  const _AccountMetric({required this.item, this.onHelp});

  @override
  Widget build(BuildContext context) {
    final align = item.alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final textAlign = item.alignEnd ? TextAlign.right : TextAlign.left;
    final primary = Theme.of(context).brightness == Brightness.dark
        ? context.adaptiveTextPrimary
        : Colors.black;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _CardLocalizedText(
                cardName: item.cardName,
                textKey: item.titleKey,
                fallback: item.titleFallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w400,
                  color: CardTool.iosMutedLabel,
                ),
              ),
            ),
            if (item.help) ...[
              const SizedBox(width: 3),
              InkWell(
                onTap: onHelp,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(3, 3, 6, 6),
                  child: Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/st_common_help_sec_cmsdark.png'
                        : 'assets/images/st_common_help_sec.png',
                    width: 15,
                    height: 15,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.help_outline_rounded,
                      size: 15,
                      color: context.adaptiveTextHint,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          item.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 16,
            height: 22 / 16,
            fontWeight: FontWeight.w500,
            color: item.valueColor ?? primary,
          ),
        ),
      ],
    );
  }
}

class _CommissionHeader extends StatelessWidget {
  final String cardName;
  final String titleKey;
  final String titleFallback;
  final String? actionKey;
  final String? actionFallback;
  final bool inlineAction;
  final VoidCallback? onAction;

  const _CommissionHeader({
    required this.cardName,
    required this.titleKey,
    required this.titleFallback,
    this.actionKey,
    this.actionFallback,
    this.inlineAction = false,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? context.adaptiveTextPrimary
        : Colors.black;
    return Row(
      children: [
        _CardLocalizedText(
          cardName: cardName,
          textKey: titleKey,
          fallback: titleFallback,
          style: TextStyle(
            fontSize: 14,
            height: 18 / 14,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1, color: Color(0xFFECECEC))),
        if (inlineAction && actionKey != null && actionFallback != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _CardLocalizedText(
                cardName: cardName,
                textKey: actionKey!,
                fallback: actionFallback!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 18 / 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00B57A),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CardLocalizedText extends StatelessWidget {
  final String cardName;
  final String textKey;
  final String fallback;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const _CardLocalizedText({
    required this.cardName,
    required this.textKey,
    required this.fallback,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: STLocalizations.ofContext(
        context,
      ).cardText(cardName, textKey, fallback: fallback),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? fallback,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        );
      },
    );
  }
}
