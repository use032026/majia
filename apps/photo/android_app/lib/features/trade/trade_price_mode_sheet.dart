import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

const Map<String, String> _tradePriceModeFallbackText = {
  'delegate_type': '委托类型',
  'market_order': '市价单',
  'market_order_tip': '按照当前市场价格进行买入或卖出',
  'limit_order': '限价单',
  'limit_order_tip': '以低于市场价格买入或高于市场价格卖出',
  'stop_order': '停损单',
  'stop_order_tip': '以高于市场价格买入或低于市场价格卖出',
};

class TradePriceModeItem {
  const TradePriceModeItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

Future<int?> showTradePriceModeSheet({
  required BuildContext context,
  required int selectedIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    constraints: BoxConstraints.tightFor(
      width: MediaQuery.sizeOf(context).width,
    ),
    builder: (ctx) => SizedBox(
      width: MediaQuery.sizeOf(ctx).width,
      child: TradePriceModeSheet(
        selectedIndex: selectedIndex,
        onSelected: (index) => Navigator.of(ctx).pop(index),
      ),
    ),
  );
}

class TradePriceModeSheet extends StatelessWidget {
  const TradePriceModeSheet({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return FutureBuilder<Map<String, String>>(
      future: STLocalizations.ofContext(context).textMap(
        _tradePriceModeFallbackText,
      ),
      initialData: _tradePriceModeFallbackText,
      builder: (context, snapshot) {
        final text = snapshot.data ?? _tradePriceModeFallbackText;
        final tradePriceModeItems = List<TradePriceModeItem>.unmodifiable([
          TradePriceModeItem(
            title: text['market_order'] ?? _tradePriceModeFallbackText['market_order']!,
            subtitle:
                text['market_order_tip'] ??
                _tradePriceModeFallbackText['market_order_tip']!,
          ),
          TradePriceModeItem(
            title: text['limit_order'] ?? _tradePriceModeFallbackText['limit_order']!,
            subtitle:
                text['limit_order_tip'] ??
                _tradePriceModeFallbackText['limit_order_tip']!,
          ),
          TradePriceModeItem(
            title: text['stop_order'] ?? _tradePriceModeFallbackText['stop_order']!,
            subtitle:
                text['stop_order_tip'] ??
                _tradePriceModeFallbackText['stop_order_tip']!,
          ),
        ]);

        return SizedBox(
          width: double.infinity,
          child: Container(
            key: const ValueKey('trade_price_mode_sheet_shell'),
            decoration: BoxDecoration(
              color: context.adaptiveCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 40,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 15,
                          top: 15,
                          child: Text(
                            text['delegate_type'] ??
                                _tradePriceModeFallbackText['delegate_type']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveTextPrimary,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            key: const ValueKey('trade_price_mode_close'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).pop(),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16, right: 16),
                              child: Image.asset(
                                'assets/images/st_mine_close_gary.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 10, 30, 10),
                    child: SizedBox(
                      key: const ValueKey('trade_price_mode_rows'),
                      height: 54.0 * tradePriceModeItems.length,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < tradePriceModeItems.length; i++)
                              _TradePriceModeRow(
                                index: i,
                                item: tradePriceModeItems[i],
                                selected: i == selectedIndex,
                                isLast: i == tradePriceModeItems.length - 1,
                                onTap: () => onSelected(i),
                              ),
                          ],
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

class _TradePriceModeRow extends StatelessWidget {
  const _TradePriceModeRow({
    required this.index,
    required this.item,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  final int index;
  final TradePriceModeItem item;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.adaptiveCard,
      child: InkWell(
        key: ValueKey('trade_price_mode_row_$index'),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 34,
                top: 8,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 34,
                top: 28,
                child: Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: 0,
                  top: 15,
                  child: Image.asset(
                    'assets/images/st_icon_check_green_sec.png',
                    key: ValueKey('trade_price_mode_selected_$index'),
                    width: 24,
                    height: 24,
                  ),
                ),
              if (!isLast)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Divider(height: 1, color: context.adaptiveDivider),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
