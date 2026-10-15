import 'package:flutter/material.dart';

import '../../core/config/card_tool.dart';
import '../../core/theme/context_adaptive_colors.dart';

abstract final class TradeIosChromeColors {
  static Color get rise => CardTool.priceColor(1);
  static Color get fall => CardTool.priceColor(-1);
  static const Color darkBlackSurface = Color(0xFF18191A);
  static const Color darkControlSurface = Color(0xFF212229);
  static const Color darkControlText = Color(0xFFABAFB8);
  static const Color switchOn = Color(0xFF34C759);
  static const Color switchOff = Color(0xFFD9D9D9);
  static const Color inputFill = Color(0xFFF7F7F7);
  static const Color labelMuted = Color(0xFF9A9DA2);
  static const Color labelDark = Color(0xFF60656D);
  static const Color labelMid = Color(0xFF656B78);
  static const Color tabIndicator = Color(0xFF60656D);
  static const Color border = Color(0xFFE6E6E6);
  static const Color divider = Color(0xFFECECEC);

  static Color blackSurface(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveSurfacePrimary : Colors.white;

  static Color blackSurfaceText(BuildContext context) =>
      context.adaptiveIsDark ? Colors.white : const Color(0xFF000000);

  static Color headerAccountPillSurface(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveSurfacePrimary : inputFill;

  static Color orderTypeSurface(BuildContext context) =>
      context.adaptiveIsDark ? darkControlSurface : Colors.white;

  static Color orderTypeText(BuildContext context) =>
      context.adaptiveIsDark ? darkControlText : const Color(0xFF000000);

  static Color darkControlOrInputFill(BuildContext context) =>
      context.adaptiveIsDark ? darkControlSurface : inputFill;

  static Color darkControlOrWhite(BuildContext context) =>
      context.adaptiveIsDark ? darkControlSurface : Colors.white;

  static Color ledgerSurface(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveSurfacePrimary : inputFill;
}

BorderRadius tradeCapsuleBorderRadius(double height) =>
    BorderRadius.circular(height / 2);

const String _tradeLedgerFilterIconAsset =
    'assets/images/trade_ledger_filter.png';

class TradeIosCheckbox extends StatelessWidget {
  const TradeIosCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.boxKey,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? boxKey;

  static const double size = 16;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedContainer(
          key: boxKey,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: value ? TradeIosChromeColors.labelDark : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: value
                ? null
                : Border.all(
                    color: context.adaptiveIsDark
                        ? TradeIosChromeColors.darkControlText
                        : TradeIosChromeColors.labelMuted,
                  ),
          ),
          child: value
              ? const Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class TradeIosInlineAlertIcon extends StatelessWidget {
  const TradeIosInlineAlertIcon({super.key, this.size = 12});

  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = context.adaptiveIsDark
        ? TradeIosChromeColors.darkControlText
        : TradeIosChromeColors.labelMuted;
    return Container(
      key: const ValueKey('trade-ios-inline-alert-icon'),
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '!',
        style: TextStyle(
          fontSize: size * 0.8,
          height: 0.9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class TradeIosSwitch extends StatelessWidget {
  const TradeIosSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double trackWidth = 26.4;
  static const double trackHeight = 16;
  static const double thumbSize = 14;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: trackWidth,
        height: TradeIosSwitchSlot.height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            key: const ValueKey('trade-ios-switch-track'),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: trackWidth,
            height: trackHeight,
            decoration: BoxDecoration(
              color: value
                  ? TradeIosChromeColors.switchOn
                  : TradeIosChromeColors.switchOff,
              borderRadius: BorderRadius.circular(trackHeight / 2),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  key: const ValueKey('trade-ios-switch-thumb'),
                  width: thumbSize,
                  height: thumbSize,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TradeIosSwitchSlot extends StatelessWidget {
  const TradeIosSwitchSlot({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const double width = 45;
  static const double height = 26;
  static const double leftInset = 15;

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('trade-ios-switch-slot'),
      width: width,
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: leftInset),
          child: TradeIosSwitch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}

class TradeIosInstrumentHeader extends StatelessWidget {
  const TradeIosInstrumentHeader({
    super.key,
    required this.title,
    required this.accountLabel,
    required this.isBuy,
    required this.loggedIn,
    required this.onTapSymbol,
    required this.onTapDetail,
    required this.onTapAccount,
    this.detailTooltip = '行情',
  });

  final String title;
  final String accountLabel;
  final bool isBuy;
  final bool loggedIn;
  final VoidCallback onTapSymbol;
  final VoidCallback onTapDetail;
  final VoidCallback onTapAccount;
  final String detailTooltip;

  static const String accountManageIconAsset =
      'assets/images/st_trade_manage_sec.png';
  static const String detailIconAsset =
      'assets/images/trade_market_detail_icon.png';
  static const String detailDarkIconAsset =
      'assets/images/trade_market_detail_icon_dark.png';

  @override
  Widget build(BuildContext context) {
    final foreground = TradeIosChromeColors.blackSurfaceText(context);
    return Container(
      key: const ValueKey('trade-ios-instrument-header'),
      width: double.infinity,
      color: TradeIosChromeColors.blackSurface(context),
      padding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            GestureDetector(
              onTap: onTapSymbol,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    key: const ValueKey('trade-ios-symbol-arrow'),
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onTapDetail,
              behavior: HitTestBehavior.opaque,
              child: Tooltip(
                message: detailTooltip,
                child: SizedBox(
                  key: const ValueKey('trade-ios-detail-icon'),
                  width: 24,
                  height: 24,
                  child: Image.asset(
                    context.adaptiveIsDark
                        ? detailDarkIconAsset
                        : detailIconAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onTapAccount,
              behavior: HitTestBehavior.opaque,
              child: Container(
                key: const ValueKey('trade-ios-account-pill'),
                height: 26,
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
                padding: EdgeInsets.fromLTRB(11, 0, loggedIn ? 4 : 11, 0),
                decoration: BoxDecoration(
                  color: TradeIosChromeColors.headerAccountPillSurface(context),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        accountLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1,
                          color: foreground,
                        ),
                      ),
                    ),
                    if (loggedIn) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        key: const ValueKey('trade-ios-account-icon'),
                        width: 16,
                        height: 16,
                        child: Image.asset(
                          accountManageIconAsset,
                          fit: BoxFit.contain,
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

class TradeIosBidAskToggle extends StatelessWidget {
  const TradeIosBidAskToggle({
    super.key,
    required this.isBuy,
    required this.askPrice,
    required this.bidPrice,
    required this.spread,
    required this.onSelectBuy,
    required this.onSelectSell,
    this.buyLabel = '买入',
    this.sellLabel = '卖出',
  });

  final bool isBuy;
  final String askPrice;
  final String bidPrice;
  final String spread;
  final VoidCallback onSelectBuy;
  final VoidCallback onSelectSell;
  final String buyLabel;
  final String sellLabel;

  @override
  Widget build(BuildContext context) {
    final inactiveSurface = TradeIosChromeColors.darkControlOrInputFill(
      context,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            key: const ValueKey('trade-ios-bidask-capsule'),
            height: 44,
            constraints: const BoxConstraints(maxHeight: 44),
            decoration: BoxDecoration(
              color: inactiveSurface,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                _TradeIosBidAskSegment(
                  label: sellLabel,
                  price: bidPrice,
                  selected: !isBuy,
                  color: TradeIosChromeColors.fall,
                  inactiveColor: inactiveSurface,
                  onTap: onSelectSell,
                ),
                _TradeIosBidAskSegment(
                  label: buyLabel,
                  price: askPrice,
                  selected: isBuy,
                  color: TradeIosChromeColors.rise,
                  inactiveColor: inactiveSurface,
                  onTap: onSelectBuy,
                ),
              ],
            ),
          ),
          Container(
            key: const ValueKey('trade-ios-bidask-spread'),
            height: 17,
            constraints: const BoxConstraints(maxHeight: 17),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                spread.trim().isEmpty ? '--' : spread,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeIosBidAskSegment extends StatelessWidget {
  const _TradeIosBidAskSegment({
    required this.label,
    required this.price,
    required this.selected,
    required this.color,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final String price;
  final bool selected;
  final Color color;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const segmentHeight = 44.0;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: segmentHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : inactiveColor,
            borderRadius: tradeCapsuleBorderRadius(segmentHeight),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : TradeIosChromeColors.labelMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : TradeIosChromeColors.labelMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TradeIosOrderTypeButton extends StatelessWidget {
  const TradeIosOrderTypeButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    final foreground = TradeIosChromeColors.orderTypeText(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: tradeCapsuleBorderRadius(_height),
        onTap: onTap,
        child: Container(
          key: const ValueKey('trade-ios-order-type-button'),
          height: _height,
          constraints: const BoxConstraints(maxHeight: _height),
          margin: const EdgeInsets.symmetric(horizontal: 15),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: TradeIosChromeColors.orderTypeSurface(context),
            borderRadius: tradeCapsuleBorderRadius(_height),
            border: Border.all(
              color: context.adaptiveIsDark
                  ? context.adaptiveHairline
                  : TradeIosChromeColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TradeIosStepperField extends StatelessWidget {
  const TradeIosStepperField({
    super.key,
    required this.title,
    required this.range,
    required this.controller,
    required this.onMinus,
    required this.onPlus,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.minusEnabled = true,
    this.plusEnabled = true,
    this.valueColor = const Color(0xFF000000),
    this.hintText = '未设置',
    this.trailingLabel,
    this.trailingValue,
    this.trailingValueColor,
    this.titleWidget,
    this.inputKey,
    this.focusNode,
    this.buttonChrome = TradeIosStepperButtonChrome.square,
  });

  final String title;
  final String range;
  final TextEditingController controller;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool minusEnabled;
  final bool plusEnabled;
  final Color valueColor;
  final String hintText;
  final String? trailingLabel;
  final String? trailingValue;
  final Color? trailingValueColor;
  final Widget? titleWidget;
  final Key? inputKey;
  final FocusNode? focusNode;
  final TradeIosStepperButtonChrome buttonChrome;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    final labelDark = context.adaptiveTextTertiary;
    final labelMuted = context.adaptiveTextSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            height: 18,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child:
                            titleWidget ??
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1,
                              ).copyWith(color: labelDark),
                            ),
                      ),
                      if (range.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            range,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1,
                            ).copyWith(color: labelMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingLabel != null || trailingValue != null)
                  Row(
                    key: const ValueKey('trade-ios-stepper-trailing-group'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trailingLabel != null)
                        Text(
                          trailingLabel!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1,
                          ).copyWith(color: labelDark),
                        ),
                      if (trailingLabel != null && trailingValue != null)
                        const SizedBox(width: 8),
                      if (trailingValue != null)
                        Text(
                          trailingValue!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1,
                            color: trailingValueColor ?? labelMuted,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Container(
            key: const ValueKey('trade-ios-stepper-bg'),
            constraints: const BoxConstraints.tightFor(height: _height),
            decoration: BoxDecoration(
              color: context.adaptiveMutedBlock,
              borderRadius: tradeCapsuleBorderRadius(_height),
            ),
            child: Row(
              children: [
                _TradeIosStepperButton(
                  icon: Icons.remove,
                  enabled: enabled && minusEnabled,
                  onTap: onMinus,
                  chrome: buttonChrome,
                ),
                Expanded(
                  child: TextField(
                    key: inputKey,
                    enabled: enabled,
                    controller: controller,
                    focusNode: focusNode,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hintText,
                      hintStyle: TextStyle(fontSize: 16, color: labelMuted),
                    ),
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                  ),
                ),
                _TradeIosStepperButton(
                  icon: Icons.add,
                  enabled: enabled && plusEnabled,
                  onTap: onPlus,
                  chrome: buttonChrome,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum TradeIosStepperButtonChrome { square, circleOutline }

class _TradeIosStepperButton extends StatelessWidget {
  const _TradeIosStepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.chrome,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final TradeIosStepperButtonChrome chrome;

  @override
  Widget build(BuildContext context) {
    if (chrome == TradeIosStepperButtonChrome.circleOutline) {
      final strokeColor = enabled
          ? (context.adaptiveIsDark
                ? TradeIosChromeColors.darkControlText
                : TradeIosChromeColors.labelDark)
          : context.adaptiveTextHint;
      return SizedBox(
        width: 44,
        height: 40,
        child: Center(
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              key: ValueKey(
                icon == Icons.remove
                    ? 'trade-ios-stepper-circle-button-minus'
                    : 'trade-ios-stepper-circle-button-plus',
              ),
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: strokeColor),
              ),
              child: Icon(icon, size: 14, color: strokeColor),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.adaptiveCard,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? context.adaptiveTextPrimary
                : context.adaptiveTextHint,
          ),
        ),
      ),
    );
  }
}

class TradeIosLotQuickButtons extends StatelessWidget {
  const TradeIosLotQuickButtons({
    super.key,
    required this.lots,
    required this.selectedLot,
    required this.onSelect,
  });

  final List<String> lots;
  final String selectedLot;
  final ValueChanged<String> onSelect;

  static const double _chipHeight = 28;

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          for (var i = 0; i < lots.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(lots[i]),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  key: const ValueKey('trade-ios-lot-chip'),
                  height: _chipHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TradeIosChromeColors.darkControlOrWhite(context),
                    borderRadius: tradeCapsuleBorderRadius(_chipHeight),
                    border: Border.all(
                      color: context.adaptiveIsDark
                          ? context.adaptiveHairline
                          : TradeIosChromeColors.border,
                    ),
                  ),
                  child: Text(
                    lots[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1,
                      color: lots[i] == selectedLot
                          ? const Color(0xFF00B57A)
                          : TradeIosChromeColors.labelDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TradeIosMarginSummaryRow extends StatelessWidget {
  const TradeIosMarginSummaryRow({
    super.key,
    required this.margin,
    this.marginUnit = '',
    required this.freeMargin,
    this.freeMarginUnit = '',
    required this.onAddFunds,
    this.freeMarginLabel = '可用保证金',
    this.marginLabel = '保证金',
  });

  final String margin;
  final String marginUnit;
  final String freeMargin;
  final String freeMarginUnit;
  final VoidCallback onAddFunds;
  final String freeMarginLabel;
  final String marginLabel;

  String _displayAmount(String value, String unit) {
    final trimmedValue = value.trim();
    final trimmedUnit = unit.trim().toUpperCase();
    if (trimmedUnit.isEmpty) return trimmedValue;
    if (trimmedValue.isEmpty) return trimmedUnit;
    return '$trimmedValue $trimmedUnit';
  }

  @override
  Widget build(BuildContext context) {
    final marginText = _displayAmount(margin, marginUnit);
    final freeMarginText = _displayAmount(freeMargin, freeMarginUnit);
    return SizedBox(
      key: const ValueKey('trade-ios-margin-row'),
      width: double.infinity,
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              key: const ValueKey('trade-ios-margin-free-group'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  freeMarginLabel,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1,
                    color: TradeIosChromeColors.labelDark,
                  ),
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    freeMarginText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1,
                      color: TradeIosChromeColors.labelMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: onAddFunds,
                  child: const SizedBox(
                    key: ValueKey('trade-ios-margin-add'),
                    width: 18,
                    height: 18,
                    child: Icon(
                      Icons.add_circle_outline,
                      size: 16,
                      color: TradeIosChromeColors.labelMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  marginLabel,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1,
                    color: TradeIosChromeColors.labelDark,
                  ),
                ),
                const Spacer(),
                ConstrainedBox(
                  key: const ValueKey('trade-ios-margin-occupied-group'),
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    marginText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1,
                      color: TradeIosChromeColors.labelMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TradeIosTpslRow extends StatelessWidget {
  const TradeIosTpslRow({
    super.key,
    required this.label,
    required this.range,
    required this.expectedProfit,
    required this.enabled,
    required this.controller,
    required this.valueColor,
    required this.onToggle,
    required this.onHelp,
    required this.onMinus,
    required this.onPlus,
    this.focusNode,
    this.onChanged,
    this.hintText = '未设置',
    this.expectedProfitLabel = '预估盈亏',
    this.checkboxKey,
  });

  final String label;
  final String range;
  final String expectedProfit;
  final bool enabled;
  final TextEditingController controller;
  final Color valueColor;
  final ValueChanged<bool> onToggle;
  final VoidCallback onHelp;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final String expectedProfitLabel;
  final Key? checkboxKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 26,
            child: Row(
              children: [
                const SizedBox(width: 16),
                SizedBox(
                  key: checkboxKey,
                  width: 16,
                  height: 16,
                  child: Center(
                    child: TradeIosCheckbox(
                      value: enabled,
                      onChanged: onToggle,
                      boxKey: const ValueKey('trade-ios-tpsl-checkbox-box'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  key: const ValueKey('trade-ios-tpsl-title'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: TradeIosChromeColors.labelMid,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  key: const ValueKey('trade-ios-tpsl-help'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onHelp,
                  child: const SizedBox(
                    width: 20,
                    height: 26,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TradeIosInlineAlertIcon(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 5),
            TradeIosStepperField(
              key: const ValueKey('trade-ios-tpsl-stepper-field'),
              title: label,
              range: range,
              controller: controller,
              focusNode: focusNode,
              valueColor: valueColor,
              hintText: hintText,
              trailingLabel: expectedProfitLabel,
              trailingValue: expectedProfit,
              trailingValueColor: expectedProfit.startsWith('-')
                  ? TradeIosChromeColors.fall
                  : TradeIosChromeColors.rise,
              buttonChrome: TradeIosStepperButtonChrome.circleOutline,
              onMinus: onMinus,
              onPlus: onPlus,
              onChanged: onChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class TradeIosSubmitArea extends StatelessWidget {
  const TradeIosSubmitArea({
    super.key,
    required this.marginLevel,
    required this.actionLabel,
    required this.color,
    required this.enabled,
    required this.onHelp,
    required this.onSubmit,
    this.isLoading = false,
    this.dimmed = false,
    this.warning,
    this.marginLevelLabel = '保证金水平',
  });

  final String marginLevel;
  final String actionLabel;
  final Color color;
  final bool enabled;
  final VoidCallback onHelp;
  final VoidCallback? onSubmit;
  final bool isLoading;
  final bool dimmed;
  final String? warning;
  final String marginLevelLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (warning != null && warning!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TradeIosChromeColors.fall.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                warning!,
                style: TextStyle(
                  fontSize: 12,
                  color: TradeIosChromeColors.fall,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: SizedBox(
            key: const ValueKey('trade-ios-submit-button'),
            height: 48,
            child: Material(
              color: enabled && !dimmed ? color : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: enabled ? onSubmit : null,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          actionLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          key: const ValueKey('trade-ios-margin-level-line'),
          height: 24,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$marginLevelLabel $marginLevel',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: TradeIosChromeColors.blackSurfaceText(context),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onHelp,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(child: TradeIosInlineAlertIcon()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TradeIosLedgerTabs extends StatelessWidget {
  const TradeIosLedgerTabs({
    super.key,
    required this.positionLabel,
    required this.pendingLabel,
    required this.positionsSelected,
    required this.onSelectPositions,
    required this.onSelectPending,
    required this.onOpenManager,
    this.managerTooltip = '持仓 / 挂单管理',
  });

  final String positionLabel;
  final String pendingLabel;
  final bool positionsSelected;
  final VoidCallback onSelectPositions;
  final VoidCallback onSelectPending;
  final VoidCallback onOpenManager;
  final String managerTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Container(
        key: const ValueKey('trade-ios-ledger-tabs-strip'),
        width: double.infinity,
        height: 44,
        constraints: const BoxConstraints(maxHeight: 44),
        decoration: BoxDecoration(
          color: TradeIosChromeColors.ledgerSurface(context),
        ),
        child: Row(
          children: [
            const SizedBox(width: 5),
            Expanded(
              child: Row(
                children: [
                  _TradeIosLedgerTab(
                    key: const ValueKey('trade-ios-ledger-positions-tab'),
                    label: positionLabel,
                    selected: positionsSelected,
                    onTap: onSelectPositions,
                  ),
                  _TradeIosLedgerTab(
                    key: const ValueKey('trade-ios-ledger-pending-tab'),
                    label: pendingLabel,
                    selected: !positionsSelected,
                    onTap: onSelectPending,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Image.asset(
                _tradeLedgerFilterIconAsset,
                key: const ValueKey('trade-ios-ledger-manager-icon'),
                width: 20,
                height: 20,
              ),
              tooltip: managerTooltip,
              onPressed: onOpenManager,
              constraints: const BoxConstraints.tightFor(width: 48, height: 44),
              padding: const EdgeInsets.all(10),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeIosLedgerTab extends StatelessWidget {
  const _TradeIosLedgerTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: context.adaptiveIsDark
                      ? Colors.white
                      : (selected
                            ? const Color(0xFF000000)
                            : const Color(0xFF656B78)),
                ),
              ),
              if (selected)
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 3,
                    decoration: BoxDecoration(
                      color: context.adaptiveIsDark
                          ? Colors.white
                          : TradeIosChromeColors.tabIndicator,
                      borderRadius: BorderRadius.circular(3),
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
