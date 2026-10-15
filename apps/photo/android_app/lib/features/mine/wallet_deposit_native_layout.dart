import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/bank_card_model.dart';
import '../../core/services/wallet_deposit_withdraw_contract.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

String walletNativeMaskedAccountId(String id) {
  final value = id.trim();
  if (value.isEmpty) return '';
  final tail = value.length >= 2 ? value.substring(value.length - 2) : value;
  return '**$tail';
}

String walletNativeAccountTitle(WalletFundingAccount account) {
  final maskedId = walletNativeMaskedAccountId(account.id);
  return maskedId.isEmpty ? account.label : '${account.label}($maskedId)';
}

String walletNativeAccountIconAsset(WalletFundingAccount account) {
  if (account.role == WalletFundingAccountRole.wallet) {
    return 'assets/images/st_mine_wallet_sec.png';
  }
  final type =
      (account.raw['type'] ??
              account.raw['account_type_code'] ??
              account.raw['account_type_num'] ??
              '')
          .toString();
  final platform = account.platform.toLowerCase();
  if (type == '1' ||
      platform.contains('demo') ||
      platform.contains('simulate')) {
    return 'assets/images/st_mine_simulate.png';
  }
  if (type == '2') {
    return 'assets/images/st_mine_trans.png';
  }
  return 'assets/images/st_mine_firm.png';
}

class WalletDepositNativeColors {
  const WalletDepositNativeColors._();

  static const pageGray = Color(0xFFF7F7F7);
  static const textPrimary = Color(0xFF000000);
  static const textSecondary = Color(0xFF60656D);
  static const textTertiary = Color(0xFF9A9DA2);
  static const blue = Color(0xFF00B57A);
  static const border = Color(0xFFECECEC);
  static const tileGray = Color(0xFFF7F7F7);

  static Color pageGrayOf(BuildContext context) => context.adaptivePageGrey;
  static Color surfaceOf(BuildContext context) => context.adaptiveCard;
  static Color depositPageBackgroundOf(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptivePageGrey : surfaceOf(context);
  static Color tileGrayOf(BuildContext context) => context.adaptiveMutedBlock;
  static Color borderOf(BuildContext context) => context.adaptiveDivider;
  static Color themeOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color textPrimaryOf(BuildContext context) =>
      context.adaptiveTextPrimary;
  static Color textSecondaryOf(BuildContext context) =>
      context.adaptiveTextTertiary;
  static Color textTertiaryOf(BuildContext context) =>
      context.adaptiveTextSecondary;
  static Color hintOf(BuildContext context) => context.adaptiveTextHint;

  static Color resolveToken(BuildContext context, Color color) {
    if (color == textPrimary) return textPrimaryOf(context);
    if (color == textSecondary) return textSecondaryOf(context);
    if (color == textTertiary) return textTertiaryOf(context);
    if (color == border) return borderOf(context);
    if (color == tileGray) return tileGrayOf(context);
    if (color == pageGray) return pageGrayOf(context);
    return color;
  }
}

class WalletNativeAccountPickerSheet extends StatelessWidget {
  const WalletNativeAccountPickerSheet({
    super.key,
    required this.accounts,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<WalletFundingAccount> accounts;
  final String? selectedKey;
  final ValueChanged<WalletFundingAccount> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet_native_account_sheet_shell'),
      height: MediaQuery.sizeOf(context).height / 2,
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.pageGrayOf(context),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: WalletDepositNativeColors.borderOf(context),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '选择账户',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: WalletDepositNativeColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          return WalletNativeAccountPickerRow(
                            account: account,
                            selected: account.key == selectedKey,
                            onTap: () => onSelected(account),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                key: const ValueKey('wallet_native_account_sheet_close'),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, size: 20),
                color: WalletDepositNativeColors.textTertiaryOf(context),
                padding: const EdgeInsets.only(top: 16, right: 16),
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WalletNativeAccountPickerRow extends StatelessWidget {
  const WalletNativeAccountPickerRow({
    super.key,
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final WalletFundingAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: WalletDepositNativeColors.textPrimaryOf(context),
    );
    final accountIdStyle = TextStyle(
      fontSize: 12,
      height: 1.2,
      color: WalletDepositNativeColors.textTertiaryOf(context),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: WalletDepositNativeColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Image.asset(_accountIconAsset, width: 32, height: 32),
                const SizedBox(width: 9),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.max(0, constraints.maxWidth - 3),
                            ),
                            child: Text(
                              '(${account.id})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: accountIdStyle,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Image.asset(
                  selected
                      ? 'assets/images/st_mine_checked_sec.png'
                      : 'assets/images/st_mine_unchecked.png',
                  key: ValueKey(
                    selected
                        ? 'wallet_native_account_checked'
                        : 'wallet_native_account_unchecked',
                  ),
                  width: 27,
                  height: 27,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _accountIconAsset {
    return walletNativeAccountIconAsset(account);
  }
}

class WalletNativeBankPickerSheet extends StatelessWidget {
  const WalletNativeBankPickerSheet({
    super.key,
    required this.cards,
    required this.selectedId,
    required this.onSelected,
    required this.onAddBank,
  });

  final List<BankCardModel> cards;
  final String? selectedId;
  final ValueChanged<BankCardModel> onSelected;
  final VoidCallback onAddBank;

  @override
  Widget build(BuildContext context) {
    return _WalletNativeSelectionShell(
      containerKey: const ValueKey('wallet_native_bank_sheet_shell'),
      title: stLocalizedText('选择银行卡'),
      child: cards.isEmpty
          ? _WalletNativeEmptyBank(onAddBank: onAddBank)
          : ListView.builder(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return _WalletNativeBankRow(
                  card: card,
                  selected: card.id == selectedId,
                  onTap: () => onSelected(card),
                );
              },
            ),
    );
  }
}

class WalletNativeEWalletPickerSheet extends StatelessWidget {
  const WalletNativeEWalletPickerSheet({
    super.key,
    required this.wallets,
    required this.selectedId,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> wallets;
  final String? selectedId;
  final String Function(Map<String, dynamic>) labelBuilder;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    return _WalletNativeSelectionShell(
      containerKey: const ValueKey('wallet_native_ewallet_sheet_shell'),
      title: stLocalizedText('选择收款钱包'),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: wallets.length,
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          final id = '${wallet['id'] ?? wallet['wallet_id'] ?? index}';
          return _WalletNativeSimpleRow(
            title: labelBuilder(wallet),
            selected: id == selectedId,
            selectedKey: const ValueKey('wallet_native_ewallet_checked'),
            unselectedKey: const ValueKey('wallet_native_ewallet_unchecked'),
            onTap: () => onSelected(wallet),
          );
        },
      ),
    );
  }
}

class _WalletNativeSelectionShell extends StatelessWidget {
  const _WalletNativeSelectionShell({
    this.containerKey,
    required this.title,
    required this.child,
  });

  final Key? containerKey;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: containerKey,
      height: MediaQuery.sizeOf(context).height / 2,
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.pageGrayOf(context),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: WalletDepositNativeColors.borderOf(context),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: WalletDepositNativeColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                    child: child,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, size: 20),
                color: WalletDepositNativeColors.textTertiaryOf(context),
                padding: const EdgeInsets.only(top: 16, right: 16),
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletNativeBankRow extends StatelessWidget {
  const _WalletNativeBankRow({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final BankCardModel card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _WalletNativeSimpleRow(
      title: card.bankName,
      subtitle: card.maskedCardNumber,
      selected: selected,
      selectedKey: const ValueKey('wallet_native_bank_checked'),
      unselectedKey: const ValueKey('wallet_native_bank_unchecked'),
      onTap: onTap,
    );
  }
}

class _WalletNativeSimpleRow extends StatelessWidget {
  const _WalletNativeSimpleRow({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.selectedKey,
    required this.unselectedKey,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final Key selectedKey;
  final Key unselectedKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: WalletDepositNativeColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: WalletDepositNativeColors.textPrimaryOf(
                            context,
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: WalletDepositNativeColors.textTertiaryOf(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Image.asset(
                  selected
                      ? 'assets/images/st_mine_checked_sec.png'
                      : 'assets/images/st_mine_unchecked.png',
                  key: selected ? selectedKey : unselectedKey,
                  width: 27,
                  height: 27,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletNativeEmptyBank extends StatelessWidget {
  const _WalletNativeEmptyBank({required this.onAddBank});

  final VoidCallback onAddBank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/st_mine_bank_add_empty.png',
            width: 108,
            height: 108,
          ),
          const SizedBox(height: 8),
          const Text(
            '暂无银行卡',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: WalletDepositNativeColors.textTertiary,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: onAddBank,
            style: OutlinedButton.styleFrom(
              foregroundColor: WalletDepositNativeColors.blue,
              side: const BorderSide(
                color: WalletDepositNativeColors.blue,
                width: 0.5,
              ),
              minimumSize: const Size(140, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontSize: 14),
            ),
            child: Text(stLocalizedTextFromZhHans('+ 添加银行卡')),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '* 添加银行时请填写完整银行名称，避免选择错误',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: WalletDepositNativeColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum WalletNativeBottomBarMode { deposit, withdraw }

class WalletNativeSection extends StatelessWidget {
  const WalletNativeSection({
    super.key,
    this.containerKey,
    required this.title,
    required this.child,
    this.titleColor = WalletDepositNativeColors.textSecondary,
    this.topPadding = 12,
    this.horizontalPadding = 20,
    this.bottomPadding = 12,
    this.backgroundColor,
  });

  final Key? containerKey;
  final String title;
  final Widget child;
  final Color titleColor;
  final double topPadding;
  final double horizontalPadding;
  final double bottomPadding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: containerKey,
      decoration: BoxDecoration(
        color: backgroundColor ?? WalletDepositNativeColors.surfaceOf(context),
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w400,
                color: WalletDepositNativeColors.resolveToken(
                  context,
                  titleColor,
                ),
              ),
            ),
            const SizedBox(height: 11),
          ],
          child,
        ],
      ),
    );
  }
}

class WalletNativeSectionGap extends StatelessWidget {
  const WalletNativeSectionGap({super.key, this.height = 6});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}

class WalletNativeAccountTile extends StatelessWidget {
  const WalletNativeAccountTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.account_balance_wallet_rounded,
    this.iconAsset,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('wallet_native_account_tile_shell'),
      color: WalletDepositNativeColors.tileGrayOf(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 0, 16),
          child: Row(
            children: [
              if (iconAsset != null && iconAsset!.isNotEmpty)
                Image.asset(
                  iconAsset!,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                )
              else
                Icon(icon, size: 24, color: WalletDepositNativeColors.blue),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: WalletDepositNativeColors.textPrimaryOf(context),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: WalletDepositNativeColors.textTertiaryOf(
                            context,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: WalletDepositNativeColors.textTertiaryOf(context),
              ),
              const SizedBox(width: 11),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletNativeChoiceTile extends StatelessWidget {
  const WalletNativeChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? WalletDepositNativeColors.blue
                  : WalletDepositNativeColors.border,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: WalletDepositNativeColors.blue),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: WalletDepositNativeColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            color: WalletDepositNativeColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected
                    ? WalletDepositNativeColors.blue
                    : WalletDepositNativeColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletWithdrawMethodTile extends StatelessWidget {
  const WalletWithdrawMethodTile({
    super.key,
    required this.title,
    required this.iconAsset,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String iconAsset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = WalletDepositNativeColors.themeOf(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          key: ValueKey(
            selected
                ? 'wallet_withdraw_method_selected_shell'
                : 'wallet_withdraw_method_unselected_shell',
          ),
          height: 52,
          padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
          decoration: BoxDecoration(
            color: context.adaptiveIsDark
                ? WalletDepositNativeColors.surfaceOf(context)
                : (selected
                      ? WalletDepositNativeColors.blue.withValues(alpha: 0.1)
                      : WalletDepositNativeColors.surfaceOf(context)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? themeColor
                  : WalletDepositNativeColors.borderOf(context),
              width: selected ? 0.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Image.asset(
                iconAsset,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                      ).copyWith(
                        color: WalletDepositNativeColors.textPrimaryOf(context),
                      ),
                ),
              ),
              Image.asset(
                selected
                    ? 'assets/images/st_mine_checked_sec.png'
                    : 'assets/images/st_mine_unchecked.png',
                key: ValueKey(
                  selected
                      ? 'wallet_withdraw_method_checked'
                      : 'wallet_withdraw_method_unchecked',
                ),
                width: 16,
                height: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletWithdrawDestinationTile extends StatelessWidget {
  const WalletWithdrawDestinationTile({
    super.key,
    required this.title,
    this.subtitle,
    this.iconAsset,
    this.selected = true,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? iconAsset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          key: const ValueKey('wallet_withdraw_destination_tile_shell'),
          height: hasSubtitle ? 64 : 50,
          padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
          decoration: BoxDecoration(
            color: WalletDepositNativeColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: WalletDepositNativeColors.borderOf(context),
            ),
          ),
          child: Row(
            children: [
              if (iconAsset != null && iconAsset!.isNotEmpty) ...[
                Image.asset(
                  iconAsset!,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: WalletDepositNativeColors.textPrimaryOf(context),
                      ),
                    ),
                    if (hasSubtitle)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: WalletDepositNativeColors.textTertiaryOf(
                              context,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Image.asset(
                selected
                    ? 'assets/images/st_mine_checked_sec.png'
                    : 'assets/images/st_mine_unchecked.png',
                key: ValueKey(
                  selected
                      ? 'wallet_withdraw_destination_checked'
                      : 'wallet_withdraw_destination_unchecked',
                ),
                width: 16,
                height: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletWithdrawChannelBlock extends StatelessWidget {
  const WalletWithdrawChannelBlock({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          key: const ValueKey('wallet_withdraw_channel_title'),
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            color: WalletDepositNativeColors.textTertiaryOf(context),
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class WalletNativePayMethodTile extends StatelessWidget {
  const WalletNativePayMethodTile({
    super.key,
    required this.title,
    required this.selected,
    this.iconUrl,
    this.onTap,
  });

  final String title;
  final bool selected;
  final String? iconUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = WalletDepositNativeColors.themeOf(context);
    final shellKey = ValueKey(
      selected
          ? 'wallet_native_pay_method_selected_shell'
          : 'wallet_native_pay_method_unselected_shell',
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          key: shellKey,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.fromLTRB(12, 15, 10, 15),
          decoration: BoxDecoration(
            color: selected
                ? WalletDepositNativeColors.surfaceOf(context)
                : WalletDepositNativeColors.tileGrayOf(context),
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: themeColor) : null,
          ),
          child: Row(
            children: [
              _PayMethodIcon(iconUrl: iconUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? WalletDepositNativeColors.textPrimaryOf(context)
                        : WalletDepositNativeColors.textTertiaryOf(context),
                  ),
                ),
              ),
              Image.asset(
                selected
                    ? 'assets/images/st_mine_checked_sec.png'
                    : 'assets/images/st_mine_unchecked.png',
                key: ValueKey(
                  selected
                      ? 'wallet_native_pay_method_checked'
                      : 'wallet_native_pay_method_unchecked',
                ),
                width: 20,
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayMethodIcon extends StatelessWidget {
  const _PayMethodIcon({this.iconUrl});

  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final url = iconUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Image.asset(
      'assets/images/st_mine_wallet_sec.png',
      width: 24,
      height: 24,
      fit: BoxFit.contain,
    );
  }
}

class WalletNativePresetAmountTile extends StatelessWidget {
  const WalletNativePresetAmountTile({
    super.key,
    required this.amount,
    required this.currency,
    required this.selected,
    this.onTap,
  });

  final String amount;
  final String currency;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = WalletDepositNativeColors.themeOf(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          key: ValueKey(
            selected
                ? 'wallet_native_preset_amount_selected_shell'
                : 'wallet_native_preset_amount_unselected_shell',
          ),
          height: 64,
          decoration: BoxDecoration(
            color: selected
                ? WalletDepositNativeColors.surfaceOf(context)
                : WalletDepositNativeColors.tileGrayOf(context),
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: themeColor) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatPresetAmount(amount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1,
                        color: selected
                            ? themeColor
                            : WalletDepositNativeColors.textTertiaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1,
                        color: selected
                            ? themeColor
                            : WalletDepositNativeColors.textTertiaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CustomPaint(
                    key: const ValueKey('wallet_native_preset_amount_check'),
                    size: const Size(24, 20),
                    painter: _PresetAmountCornerCheckPainter(themeColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPresetAmount(String raw) {
    final text = raw.trim();
    final number = num.tryParse(text);
    if (number == null) {
      return text;
    }
    final normalized = number % 1 == 0
        ? number.toInt().toString()
        : number.toString();
    final parts = normalized.split('.');
    final integer = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i += 1) {
      final remaining = integer.length - i;
      buffer.write(integer[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    if (parts.length > 1) {
      buffer.write('.${parts[1]}');
    }
    return buffer.toString();
  }
}

class _PresetAmountCornerCheckPainter extends CustomPainter {
  const _PresetAmountCornerCheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final check = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(size.width - 14, size.height - 7)
      ..lineTo(size.width - 10, size.height - 3)
      ..lineTo(size.width - 4, size.height - 12);
    canvas.drawPath(checkPath, check);
  }

  @override
  bool shouldRepaint(covariant _PresetAmountCornerCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}

class WalletWithdrawPresetAmountGrid extends StatelessWidget {
  const WalletWithdrawPresetAmountGrid({
    super.key,
    required this.amounts,
    required this.currency,
    this.selectedAmount,
    this.onSelected,
  });

  final List<String> amounts;
  final String currency;
  final String? selectedAmount;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (amounts.isEmpty) {
      return const SizedBox.shrink();
    }
    return WalletNativeChoiceGrid(
      columns: 3,
      spacing: 10,
      runSpacing: 14,
      children: [
        for (final amount in amounts)
          _WithdrawPresetAmountTile(
            amount: amount,
            currency: currency,
            selected: amount == selectedAmount,
            onTap: () => onSelected?.call(amount),
          ),
      ],
    );
  }
}

class _WithdrawPresetAmountTile extends StatelessWidget {
  const _WithdrawPresetAmountTile({
    required this.amount,
    required this.currency,
    required this.selected,
    this.onTap,
  });

  final String amount;
  final String currency;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = WalletDepositNativeColors.themeOf(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          key: ValueKey(
            selected
                ? 'wallet_withdraw_preset_amount_selected'
                : 'wallet_withdraw_preset_amount_unselected',
          ),
          height: 56,
          decoration: BoxDecoration(
            color: WalletDepositNativeColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? themeColor
                  : WalletDepositNativeColors.borderOf(context),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatWithdrawPresetAmount(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  height: 1,
                  color: selected
                      ? themeColor
                      : WalletDepositNativeColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currency,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  color: selected
                      ? themeColor
                      : WalletDepositNativeColors.textTertiaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWithdrawPresetAmount(String raw) {
    final value = num.tryParse(raw.trim());
    if (value == null) return raw.trim();
    if (value % 1 == 0) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

class WalletWithdrawAmountHeader extends StatelessWidget {
  const WalletWithdrawAmountHeader({
    super.key,
    required this.availableText,
    this.title = '自定义金额',
    this.availableLabel = '可提现',
  });

  final String title;
  final String availableLabel;
  final String availableText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              color: WalletDepositNativeColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          availableLabel,
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            color: WalletDepositNativeColors.textSecondaryOf(context),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          availableText,
          key: const ValueKey('wallet_withdraw_available_value'),
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            color: WalletDepositNativeColors.textPrimaryOf(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class WalletWithdrawConfirmDetails extends StatelessWidget {
  const WalletWithdrawConfirmDetails({
    super.key,
    required this.receivedAmount,
    required this.convertedAmount,
    required this.feeAmount,
    required this.deductAmount,
    this.title = '确认明细',
    this.receivedLabel = '本次到账',
    this.convertedLabel = '折合金额',
    this.feeLabel = '手续费',
    this.deductLabel = '实际取款金额',
    this.onReceivedInfoTap,
    this.onConvertedInfoTap,
  });

  final String title;
  final String receivedLabel;
  final String convertedLabel;
  final String feeLabel;
  final String deductLabel;
  final String receivedAmount;
  final String convertedAmount;
  final String feeAmount;
  final String deductAmount;
  final VoidCallback? onReceivedInfoTap;
  final VoidCallback? onConvertedInfoTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet_withdraw_confirm_details_shell'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WalletDepositNativeColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: WalletDepositNativeColors.themeOf(context),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: WalletDepositNativeColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _WithdrawConfirmRow(
            label: receivedLabel,
            value: receivedAmount,
            infoKey: const ValueKey('wallet_withdraw_received_info'),
            onInfoTap: onReceivedInfoTap,
          ),
          const SizedBox(height: 12),
          _WithdrawConfirmRow(
            label: convertedLabel,
            value: convertedAmount,
            infoKey: const ValueKey('wallet_withdraw_converted_info'),
            onInfoTap: onConvertedInfoTap,
            valueColor: WalletDepositNativeColors.blue,
            valueWeight: FontWeight.w700,
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: WalletDepositNativeColors.borderOf(context),
          ),
          const SizedBox(height: 16),
          _WithdrawConfirmRow(label: feeLabel, value: feeAmount),
          const SizedBox(height: 16),
          _WithdrawConfirmRow(
            label: deductLabel,
            value: deductAmount,
            labelColor: WalletDepositNativeColors.textPrimary,
            labelWeight: FontWeight.w700,
            valueColor: WalletDepositNativeColors.blue,
            valueWeight: FontWeight.w700,
            valueFontSize: 28,
          ),
        ],
      ),
    );
  }
}

class _WithdrawConfirmRow extends StatelessWidget {
  const _WithdrawConfirmRow({
    required this.label,
    required this.value,
    this.labelColor = WalletDepositNativeColors.textSecondary,
    this.labelWeight = FontWeight.w400,
    this.valueColor = WalletDepositNativeColors.textPrimary,
    this.valueWeight = FontWeight.w600,
    this.valueFontSize = 16,
    this.infoKey,
    this.onInfoTap,
  });

  final String label;
  final String value;
  final Color labelColor;
  final FontWeight labelWeight;
  final Color valueColor;
  final FontWeight valueWeight;
  final double valueFontSize;
  final Key? infoKey;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: WalletDepositNativeColors.resolveToken(
                      context,
                      labelColor,
                    ),
                    fontWeight: labelWeight,
                  ),
                ),
              ),
              if (onInfoTap != null) ...[
                const SizedBox(width: 5),
                GestureDetector(
                  key: infoKey,
                  onTap: onInfoTap,
                  child: Image.asset(
                    'assets/images/st_common_help_sec.png',
                    width: 16,
                    height: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: valueFontSize,
            height: 1.05,
            color: WalletDepositNativeColors.resolveToken(context, valueColor),
            fontWeight: valueWeight,
          ),
        ),
      ],
    );
  }
}

enum WithdrawDetailHintType { received, converted }

Future<void> showWithdrawDetailHintSheet(
  BuildContext context,
  WithdrawDetailHintType type,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (sheetContext) => WithdrawDetailHintSheet(type: type),
  );
}

class WithdrawDetailHintSheet extends StatelessWidget {
  const WithdrawDetailHintSheet({super.key, required this.type});

  final WithdrawDetailHintType type;

  String get _title => type == WithdrawDetailHintType.received
      ? '本次到账'
      : stLocalizedTextFromZhHans('');

  String get _message => type == WithdrawDetailHintType.received
      ? '本次到账为填写的 CNY 金额，CNY 仅支持整数。'
      : stLocalizedTextFromZhHans('');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet_withdraw_detail_hint_sheet'),
      height: 235 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.fromLTRB(
        28,
        20,
        28,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFEFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: WalletDepositNativeColors.textSecondary,
            ),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 120,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '我知道了',
                  style: TextStyle(fontSize: 14, color: Color(0xFF00B57A)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletNativeChoiceGrid extends StatelessWidget {
  const WalletNativeChoiceGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 11,
    this.runSpacing = 5,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

enum WalletNativeAmountFieldStyle { depositLine, framed, withdrawFramed }

class WalletNativeAmountField extends StatelessWidget {
  const WalletNativeAmountField({
    super.key,
    required this.controller,
    required this.unit,
    required this.hintText,
    this.conversionText,
    this.errorText,
    this.style = WalletNativeAmountFieldStyle.depositLine,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String unit;
  final String hintText;
  final String? conversionText;
  final String? errorText;
  final WalletNativeAmountFieldStyle style;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (style == WalletNativeAmountFieldStyle.withdrawFramed) {
      return _buildWithdrawFramedField(context);
    }
    if (style == WalletNativeAmountFieldStyle.framed) {
      return _buildFramedField(context);
    }
    return _buildDepositLineField(context);
  }

  Widget _buildDepositLineField(BuildContext context) {
    final conversion = conversionText ?? '';
    final error = errorText?.trim() ?? '';
    return Container(
      key: const ValueKey('wallet_native_amount_field_shell'),
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.surfaceOf(context),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 37,
            child: Row(
              children: [
                const SizedBox(width: 17),
                Expanded(child: _buildTextField(context, fontSize: 16)),
                Text(
                  unit,
                  key: const ValueKey('wallet_native_amount_unit'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: WalletDepositNativeColors.textTertiaryOf(context),
                  ),
                ),
                const SizedBox(width: 15),
              ],
            ),
          ),
          SizedBox(
            height: 10,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 17, right: 15),
                child: Text(
                  conversion,
                  key: const ValueKey('wallet_native_amount_conversion'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    color: WalletDepositNativeColors.hintOf(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            key: const ValueKey('wallet_native_amount_divider'),
            height: 1,
            thickness: 1,
            indent: 17,
            endIndent: 15,
            color: WalletDepositNativeColors.borderOf(context),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 17, top: 6, right: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  error,
                  key: const ValueKey('wallet_native_amount_error'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: Color(0xFFF95959),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFramedField(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.tileGrayOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            unit.isEmpty ? r'$' : unit,
            style: TextStyle(
              fontSize: 20,
              color: WalletDepositNativeColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(context, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildWithdrawFramedField(BuildContext context) {
    final error = errorText?.trim() ?? '';
    final hasError = error.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('wallet_native_withdraw_amount_field_shell'),
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: WalletDepositNativeColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFF95959)
                  : WalletDepositNativeColors.borderOf(context),
            ),
          ),
          child: Row(
            children: [
              Text(
                unit.isEmpty ? r'$' : unit,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  color: WalletDepositNativeColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(child: _buildTextField(context, fontSize: 18)),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                error,
                key: const ValueKey('wallet_native_withdraw_amount_error'),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: Color(0xFFF95959),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, {required double fontSize}) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [_WalletAmountInputFormatter()],
      decoration: InputDecoration(
        hintText: hintText,
        isCollapsed: true,
        border: InputBorder.none,
        hintStyle: TextStyle(
          fontSize: 14,
          color: WalletDepositNativeColors.hintOf(context),
        ),
      ),
      style: TextStyle(
        fontSize: fontSize,
        height: 1.2,
        color: WalletDepositNativeColors.textPrimaryOf(context),
      ),
      onChanged: onChanged,
    );
  }
}

class _WalletAmountInputFormatter extends TextInputFormatter {
  const _WalletAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final source = newValue.text;
    final next = _filterAmountText(source);
    if (next == source) return newValue;
    return TextEditingValue(
      text: next,
      selection: _filteredAmountSelectionFor(newValue, next),
      composing: TextRange.empty,
    );
  }

  static String _filterAmountText(String source) {
    final buffer = StringBuffer();
    var hasDot = false;
    var decimalCount = 0;

    for (final codeUnit in source.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      if (isDigit) {
        if (hasDot) {
          if (decimalCount >= 2) continue;
          decimalCount++;
        }
        buffer.write(char);
      } else if (char == '.' && !hasDot) {
        hasDot = true;
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  static TextSelection _filteredAmountSelectionFor(
    TextEditingValue value,
    String filtered,
  ) {
    final selection = value.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: filtered.length);
    }
    return TextSelection(
      baseOffset: _filteredAmountOffsetFor(value.text, selection.baseOffset),
      extentOffset: _filteredAmountOffsetFor(
        value.text,
        selection.extentOffset,
      ),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  static int _filteredAmountOffsetFor(String source, int offset) {
    if (offset < 0) return _filterAmountText(source).length;
    final clamped = offset.clamp(0, source.length).toInt();
    return _filterAmountText(source.substring(0, clamped)).length;
  }
}

class WalletNativeTip extends StatelessWidget {
  const WalletNativeTip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: WalletDepositNativeColors.textTertiary,
        ),
      ),
    );
  }
}

class WalletNativeDepositNoticeCard extends StatelessWidget {
  const WalletNativeDepositNoticeCard({
    super.key,
    this.title = '入金须知',
    this.text = _defaultNoticeText,
  });

  static const _defaultNoticeText =
      '1.需依存款提案金额进行转账, 【多汇】或 【少汇】 的资金都无法到账。\n'
      '2.转账完成后, 如10分钟没有到账, 请联络客服协助。\n'
      '3.请勿对 【过往账户】 存款, 资金无法找回。\n'
      '4.仅接受本人账户存款, 不接受第三方存款。';

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 0),
      child: Container(
        key: const ValueKey('wallet_native_deposit_notice_card'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
        decoration: BoxDecoration(
          color: WalletDepositNativeColors.tileGrayOf(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: WalletDepositNativeColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                height: 1.35,
                color: WalletDepositNativeColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum WalletNativeInfoRowsStyle { plain, boxed }

class WalletNativeInfoRows extends StatelessWidget {
  const WalletNativeInfoRows({
    super.key,
    required this.rows,
    this.style = WalletNativeInfoRowsStyle.boxed,
    this.primaryValueKeys = const <String>{},
  });

  final Map<String, String> rows;
  final WalletNativeInfoRowsStyle style;
  final Set<String> primaryValueKeys;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    if (style == WalletNativeInfoRowsStyle.plain) {
      return _buildRows(
        context: context,
        horizontalPadding: 17,
        verticalPadding: 0,
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WalletDepositNativeColors.tileGrayOf(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildRows(
        context: context,
        horizontalPadding: 0,
        verticalPadding: 3,
      ),
    );
  }

  Widget _buildRows({
    required BuildContext context,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in rows.entries)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: WalletDepositNativeColors.textTertiaryOf(context),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: primaryValueKeys.contains(entry.key)
                            ? WalletDepositNativeColors.textPrimaryOf(context)
                            : WalletDepositNativeColors.textSecondaryOf(
                                context,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class WalletNativeBottomBar extends StatelessWidget {
  const WalletNativeBottomBar({
    super.key,
    required this.mode,
    required this.primaryText,
    required this.enabled,
    this.loading = false,
    this.amountText,
    this.conversionText,
    this.backgroundColor,
    this.onPressed,
  });

  final WalletNativeBottomBarMode mode;
  final String primaryText;
  final bool enabled;
  final bool loading;
  final String? amountText;
  final String? conversionText;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  bool get _isWithdraw => mode == WalletNativeBottomBarMode.withdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? WalletDepositNativeColors.surfaceOf(context),
        boxShadow: _isWithdraw
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        _isWithdraw ? 25 : 24,
        10,
        _isWithdraw ? 25 : 15,
        _isWithdraw ? 16 : 7,
      ),
      child: SafeArea(
        top: false,
        child: _isWithdraw ? _withdrawButton() : _depositRow(context),
      ),
    );
  }

  Widget _depositRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                amountText ?? '--',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: WalletDepositNativeColors.blue.withValues(
                    alpha: amountText == null ? 0.35 : 1,
                  ),
                ),
              ),
              Text(
                conversionText ?? '≈--',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: WalletDepositNativeColors.textTertiaryOf(context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 193, height: 48, child: _button(15)),
      ],
    );
  }

  Widget _withdrawButton() {
    return SizedBox(width: double.infinity, height: 50, child: _button(8));
  }

  Widget _button(double radius) {
    return ElevatedButton(
      key: const ValueKey('wallet_native_bottom_button'),
      onPressed: enabled && !loading ? onPressed : null,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: WalletDepositNativeColors.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: WalletDepositNativeColors.blue.withValues(
          alpha: 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: EdgeInsets.zero,
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              primaryText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: _isWithdraw ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
    );
  }
}
