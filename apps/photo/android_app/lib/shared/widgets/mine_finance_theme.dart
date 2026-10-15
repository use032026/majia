import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/context_adaptive_colors.dart';
import 'st_localized_prompt.dart';

/// 对齐 iOS 资金/银行卡相关页面；浅色保持原 Figma 值，深色用 [AppAdaptiveColors] / BrandConfig
class MineFinanceTheme {
  MineFinanceTheme._();

  static const double horizontalInset = 15;
  static const double cardRadius = 10;

  static Color pageBg(BuildContext c) => c.adaptivePageGrey;

  static Color navBg(BuildContext c) => c.adaptiveSurfacePrimary;

  static Color cardBgNormal(BuildContext c) => c.adaptiveCard;

  static Color cardBgMuted(BuildContext c) => c.adaptiveFinanceCardMuted;

  static Color textPrimary(BuildContext c) => c.adaptiveTextPrimary;

  /// 次级说明（原 `#60656D`）
  static Color textSecondary(BuildContext c) => c.adaptiveTextTertiary;

  /// 禁用/浅文案（原 `#D9D9D9`）
  static Color textHint(BuildContext c) => c.adaptiveTextHint;

  /// 右上角「默认 / 审核中」丝带（对齐 STCornerButton）
  static Widget statusRibbon({required String label, required Color bg}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: bg,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 银行卡卡片（对齐 STBankCardListCell）
class MineBankCardTile extends StatelessWidget {
  final String bankName;
  final String holderName;
  final String? branchName;
  final String? branchLabel;
  final String cardNumberDisplay;
  final String? currency;
  final int status;
  final bool isDefault;
  final String? failRemark;
  final String? reviewLabel;
  final String? defaultLabel;
  final String? failureTitle;
  final String? reasonLabel;
  final VoidCallback? onCopy;
  final VoidCallback? onTap;

  const MineBankCardTile({
    super.key,
    required this.bankName,
    required this.holderName,
    this.branchName,
    this.branchLabel,
    required this.cardNumberDisplay,
    this.currency,
    required this.status,
    required this.isDefault,
    this.failRemark,
    this.reviewLabel,
    this.defaultLabel,
    this.failureTitle,
    this.reasonLabel,
    this.onCopy,
    this.onTap,
  });

  bool get _success => status == 1;
  bool get _wait => status == 0;
  bool get _failed => status == 2;

  @override
  Widget build(BuildContext context) {
    final bg = _failed || _wait
        ? MineFinanceTheme.cardBgMuted(context)
        : MineFinanceTheme.cardBgNormal(context);

    Widget? ribbon;
    if (_wait) {
      ribbon = MineFinanceTheme.statusRibbon(
        label: reviewLabel ?? stLocalizedTextFromZhHans('审核中'),
        bg: const Color(0xFFFF732A).withValues(alpha: 0.65),
      );
    } else if (_success && isDefault) {
      ribbon = MineFinanceTheme.statusRibbon(
        label: defaultLabel ?? stLocalizedTextFromZhHans('默认'),
        bg: const Color(0xFF4DCB73).withValues(alpha: 0.65),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(MineFinanceTheme.cardRadius),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: bg,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 20),
                  child: _bankBody(context),
                ),
                if (_failed) Positioned.fill(child: _failOverlay(context)),
                if (ribbon != null) Positioned(top: 0, right: 0, child: ribbon),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bankBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bankName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 19 / 16,
            color: MineFinanceTheme.textPrimary(context),
          ),
        ),
        Text(
          holderName,
          style: TextStyle(
            fontSize: 12,
            height: 14 / 12,
            color: MineFinanceTheme.textPrimary(context).withValues(alpha: 0.5),
          ),
        ),
        if ((branchName ?? '').isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            '${branchLabel ?? stLocalizedTextFromZhHans('支行名称')}：${branchName!}',
            style: TextStyle(
              fontSize: 12,
              height: 14 / 12,
              color: MineFinanceTheme.textPrimary(
                context,
              ).withValues(alpha: 0.5),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    cardNumberDisplay,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Gilroy',
                      height: 19 / 16,
                      color: _success
                          ? MineFinanceTheme.textPrimary(context)
                          : MineFinanceTheme.textHint(context),
                    ),
                  ),
                ),
              ),
            ),
            if (_success && onCopy != null) ...[
              const SizedBox(width: 6),
              _MineFinanceCopyButton(onTap: onCopy!),
            ],
            if (currency != null && currency!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  currency!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Gilroy',
                    height: 17 / 14,
                    color: _success
                        ? MineFinanceTheme.textPrimary(context)
                        : MineFinanceTheme.textHint(context),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _failOverlay(BuildContext context) {
    final remark = (failRemark?.trim().isNotEmpty ?? false)
        ? failRemark!.trim()
        : '—';
    return Container(
      color: const Color(0x802B2B2E),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel_rounded, size: 24, color: Colors.red.shade400),
          const SizedBox(height: 8),
          Text(
            '${failureTitle ?? stLocalizedTextFromZhHans('您的银行卡认证未通过。')}\n'
            '${reasonLabel ?? stLocalizedTextFromZhHans('原因：')}$remark',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MineFinanceCopyButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MineFinanceCopyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final asset = Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/st_mine_copy_cmsdark.png'
        : 'assets/images/st_mine_copy.png';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        key: const ValueKey('mine_finance_copy_button'),
        width: 28,
        height: 28,
        child: Center(
          child: Image(
            image: AssetImage(asset),
            width: 14,
            height: 14,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// 电子钱包卡片（对齐 STBankCardListCell eWallet）
class MineEWalletTile extends StatelessWidget {
  final String currencyTitle;
  final String addressDisplay;
  final int status;
  final bool isDefault;
  final String? failRemark;
  final String? reviewLabel;
  final String? defaultLabel;
  final String? failureTitle;
  final String? reasonLabel;
  final VoidCallback? onCopy;
  final VoidCallback? onTap;

  const MineEWalletTile({
    super.key,
    required this.currencyTitle,
    required this.addressDisplay,
    required this.status,
    required this.isDefault,
    this.failRemark,
    this.reviewLabel,
    this.defaultLabel,
    this.failureTitle,
    this.reasonLabel,
    this.onCopy,
    this.onTap,
  });

  bool get _success => status == 1;
  bool get _wait => status == 0;
  bool get _failed => status == 2;

  @override
  Widget build(BuildContext context) {
    final bg = _failed || _wait
        ? MineFinanceTheme.cardBgMuted(context)
        : MineFinanceTheme.cardBgNormal(context);
    final showCopy = _success && onCopy != null;

    Widget? ribbon;
    if (_wait) {
      ribbon = MineFinanceTheme.statusRibbon(
        label: reviewLabel ?? stLocalizedTextFromZhHans('审核中'),
        bg: const Color(0xFFFF732A).withValues(alpha: 0.65),
      );
    } else if (_success && isDefault) {
      ribbon = MineFinanceTheme.statusRibbon(
        label: defaultLabel ?? stLocalizedTextFromZhHans('默认'),
        bg: const Color(0xFF4DCB73).withValues(alpha: 0.65),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(MineFinanceTheme.cardRadius),
      child: Material(
        key: const ValueKey('mine_ewallet_tile'),
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                child: _failed
                    ? _failBody(context)
                    : _walletBody(context, showCopy),
              ),
              if (showCopy)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _MineFinanceCopyButton(onTap: onCopy!),
                ),
              if (ribbon != null) Positioned(top: 0, right: 0, child: ribbon),
            ],
          ),
        ),
      ),
    );
  }

  Widget _walletBody(BuildContext context, bool showCopy) {
    final dimmed = !_success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/st_mine_e_wallet.png',
          width: 32,
          height: 32,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: showCopy ? 60 : 16,
              bottom: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    currencyTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dimmed
                          ? MineFinanceTheme.textHint(context)
                          : MineFinanceTheme.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    addressDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: dimmed
                          ? MineFinanceTheme.textHint(context)
                          : MineFinanceTheme.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _failBody(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline_rounded, size: 26, color: Colors.red.shade400),
        const SizedBox(height: 8),
        Text(
          '${failureTitle ?? stLocalizedTextFromZhHans('您的电子钱包认证未通过。')}\n'
          '${reasonLabel ?? stLocalizedTextFromZhHans('原因：')}${failRemark ?? '—'}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: MineFinanceTheme.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

Future<void> copyMineClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    showStLocalizedToast(context, '已复制');
  }
}
