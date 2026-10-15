import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_card.dart';
import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/router/st_router.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 余额卡片 `balance_1` ~ `balance_3`
///
/// 对齐 iOS `Balance1CardView` / `Balance2CardView` / `Balance3CardView`。
class BalanceCard extends BaseCard {
  const BalanceCard({super.key, required super.cardData});

  static const String _assetActionKey = 'wallet_assets';
  static const String _loginActionKey = 'login_now';
  static const String _equityFallback = '净值';

  @override
  Widget buildCardContent(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(userStateProvider);
        final data = _BalanceData.from(user, cardData.cardDetail);
        final style = cardData.cardStyle;

        return switch (style) {
          'balance_2' => _Balance2View(data: data, cardName: style),
          'balance_3' => _Balance3View(data: data, cardName: style),
          _ => _Balance1View(data: data, cardName: style),
        };
      },
    );
  }

  static void openAsset(BuildContext context, WidgetRef ref, bool loggedIn) {
    ref
        .read(stRouterProvider)
        .openPage(
          context,
          loggedIn ? '/mine/asset' : '/login',
          action: loggedIn ? _assetActionKey : _loginActionKey,
        );
  }

  static Widget arrow(BuildContext context, double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? context.adaptiveTextPrimary.withValues(alpha: 0.55)
        : CardTool.iosMutedLabel;
    return Image.asset(
      'assets/images/st_mine_arrow_right.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.chevron_right, size: size, color: color),
    );
  }

  static Color primary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? context.adaptiveTextPrimary
        : const Color(0xFF000000);
  }

  static Color secondary(
    BuildContext context, {
    Color light = CardTool.iosMutedLabel,
  }) {
    return Theme.of(context).brightness == Brightness.dark
        ? context.adaptiveTextPrimary.withValues(alpha: 0.62)
        : light;
  }
}

Future<String> _balanceEquityTitle(BuildContext context, String cardName) {
  return STLocalizations.ofContext(
    context,
  ).cardText(cardName, 'account_equity', fallback: BalanceCard._equityFallback);
}

class _BalanceData {
  final bool loggedIn;
  final String equity;
  final String currency;

  const _BalanceData({
    required this.loggedIn,
    required this.equity,
    required this.currency,
  });

  factory _BalanceData.from(UserState user, Map<String, dynamic>? detail) {
    final account = _currentAccount(user);
    final accountEquity = account?.equity.trim();
    final equity = accountEquity?.isNotEmpty == true ? accountEquity! : '--';
    final accountCurrency = account?.currency.trim() ?? '';
    final currency = accountCurrency.isNotEmpty ? accountCurrency : '';

    return _BalanceData(
      loggedIn: user.hasActiveSession,
      equity: equity,
      currency: currency,
    );
  }

  static STAccountModel? _currentAccount(UserState user) {
    if (user.accountAry.isEmpty) return null;
    if (user.isB) {
      for (final account in user.accountAry) {
        if (account.type == '1') return account;
      }
      return null;
    }
    if (user.transactionAccount.trim().isEmpty) return null;
    for (final account in user.accountAry) {
      if (account.accountId == user.transactionAccount &&
          account.accountId.isNotEmpty) {
        return account;
      }
    }
    return null;
  }
}

class _Balance1View extends ConsumerWidget {
  final _BalanceData data;
  final String cardName;

  const _Balance1View({required this.data, required this.cardName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = data.loggedIn
        ? CardTool.formatBalanceAmount(data.equity)
        : '--';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => BalanceCard.openAsset(context, ref, data.loggedIn),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FutureBuilder<String>(
                    future: _balanceEquityTitle(context, cardName),
                    builder: (context, snapshot) {
                      final baseTitle =
                          snapshot.data ?? BalanceCard._equityFallback;
                      final title = data.currency.isNotEmpty
                          ? '$baseTitle (${data.currency})'
                          : baseTitle;
                      return Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: BalanceCard.secondary(context),
                        ),
                      );
                    },
                  ),
                  BalanceCard.arrow(context, 14),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    height: 1.05,
                    color: BalanceCard.primary(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Balance2View extends ConsumerWidget {
  final _BalanceData data;
  final String cardName;

  const _Balance2View({required this.data, required this.cardName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = data.loggedIn
        ? CardTool.formatBalanceAmount(data.equity)
        : '--';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => BalanceCard.openAsset(context, ref, data.loggedIn),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<String>(
                    future: _balanceEquityTitle(context, cardName),
                    builder: (context, snapshot) {
                      final baseTitle =
                          snapshot.data ?? BalanceCard._equityFallback;
                      final title = data.currency.isNotEmpty
                          ? '$baseTitle (${data.currency})'
                          : baseTitle;
                      return Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: BalanceCard.secondary(
                            context,
                            light: const Color(0xFF60656D),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  BalanceCard.arrow(context, 16),
                ],
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    color: BalanceCard.primary(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Balance3View extends StatefulWidget {
  final _BalanceData data;
  final String cardName;

  const _Balance3View({required this.data, required this.cardName});

  @override
  State<_Balance3View> createState() => _Balance3ViewState();
}

class _Balance3ViewState extends State<_Balance3View> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final amount = widget.data.loggedIn
            ? CardTool.formatBalanceAmount(widget.data.equity)
            : '--';
        final balance = _hidden ? '****' : amount;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                BalanceCard.openAsset(context, ref, widget.data.loggedIn),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? context.adaptiveCard
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<String>(
                        future: _balanceEquityTitle(context, widget.cardName),
                        builder: (context, snapshot) {
                          final baseTitle =
                              snapshot.data ?? BalanceCard._equityFallback;
                          final title = widget.data.currency.isNotEmpty
                              ? '$baseTitle (${widget.data.currency})'
                              : baseTitle;
                          return Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: BalanceCard.secondary(context),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() => _hidden = !_hidden),
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Image.asset(
                            _hidden
                                ? 'assets/images/st_password_eye_hide.png'
                                : 'assets/images/st_password_eye_show.png',
                            width: 18,
                            height: 18,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              _hidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: BalanceCard.secondary(
                                context,
                                light: const Color(0xFF60656D),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    balance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: BalanceCard.primary(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
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
