import 'package:flutter/material.dart';
import 'card_factory.dart';
import 'base_card.dart';
import '../../core/config/card_tool.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 列表卡片 (`list_*`)
///
/// UI 对齐 iOS **List1CardView / List2CardView**：
/// - `list_1`：行高 60，左图标 30×30，标题 14 Medium，右侧副标题 + 20 箭头，
///   底部分割线 `#F7F7F7`（末行隐藏）。
/// - `list_2`：每行最多 4 个，外卡片白底/暗底，图标区单独圆角浅底，文字不包裹在底板里。
class ListCard extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const ListCard({super.key, required super.cardData, this.onNavigate});

  static const double _rowHeight = 60;
  static const double _leadingInset = 15;

  Color _titleColor(BuildContext context) {
    return CardTool.parseAdaptiveHexColor(
          context,
          '#000000',
          category: CardTool.iosDarkModeTextColorKey,
        ) ??
        context.adaptiveTextPrimary;
  }

  Color _subtitleColor(BuildContext context, String? hex) {
    final parsed = CardTool.parseAdaptiveHexColor(
      context,
      hex,
      category: CardTool.iosDarkModeTextColorKey,
    );
    if (parsed != null) return parsed;
    return _titleColor(context);
  }

  Color _dividerColor(BuildContext context) {
    return CardTool.parseAdaptiveHexColor(
          context,
          '#F7F7F7',
          category: CardTool.iosDarkModeChildBgColorKey,
        ) ??
        context.adaptiveDivider;
  }

  Color _list2TitleColor(BuildContext context) {
    return CardTool.parseAdaptiveHexColor(
          context,
          '#60656D',
          category: CardTool.iosDarkModeTextColorKey,
        ) ??
        context.adaptiveTextTertiary;
  }

  Color _list2IconBackgroundColor(BuildContext context) {
    return const Color(0x1A00B57A);
  }

  ({String path, Map<String, dynamic> params}) _listRoute(
    Map<String, dynamic> item,
  ) {
    final route = CardFactory.extractItemRoute(item);
    return (
      path: route.path.trim(),
      params: route.params ?? <String, dynamic>{},
    );
  }

  String? _iconUrl(Map<String, dynamic> item, bool isDark) {
    final iconLight = (item['icon'] as String?)?.trim();
    final iconDarkRaw =
        (item['icon_dark'] as String? ?? item['iconDark'] as String?)?.trim();
    final iconDark = iconDarkRaw == null || iconDarkRaw.isEmpty
        ? iconLight
        : iconDarkRaw;
    final url = isDark ? iconDark : iconLight;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  String _title(Map<String, dynamic> item) {
    return item['title'] as String? ?? '';
  }

  Widget _placeholderIcon(BuildContext context, double size) {
    return Icon(Icons.circle, size: size - 2, color: context.adaptiveTextHint);
  }

  Widget _networkIcon(
    BuildContext context, {
    required String? url,
    required double size,
  }) {
    if (url == null || url.isEmpty) {
      return _placeholderIcon(context, size);
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _placeholderIcon(context, size),
    );
  }

  @override
  Widget buildCardContent(BuildContext context) {
    final detail = cardData.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (cardData.cardStyle == 'list_2') {
      return _buildList2(context, items);
    }

    return _buildList1(context, items);
  }

  Widget _buildList1(BuildContext context, List<Map<String, dynamic>> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final title = _title(item);
        final subTitle =
            item['sub_title'] as String? ?? item['subTitle'] as String? ?? '';
        final subTitleColorHex =
            item['sub_title_color'] as String? ??
            item['subTitleColor'] as String?;
        final route = _listRoute(item);
        final isLast = index == items.length - 1;

        return Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (route.path.isNotEmpty) {
                    onNavigate?.call(route.path, route.params);
                  }
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
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: _networkIcon(
                            context,
                            url: _iconUrl(item, isDark),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _titleColor(context),
                            ),
                          ),
                        ),
                        if (subTitle.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            subTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _subtitleColor(context, subTitleColorHex),
                            ),
                          ),
                        ],
                        const SizedBox(width: 15),
                        Image.asset(
                          'assets/images/st_mine_arrow_more.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: context.adaptiveTextTertiary,
                          ),
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
                color: _dividerColor(context),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildList2(BuildContext context, List<Map<String, dynamic>> items) {
    const maxColumnCount = 4;
    const padding = 16.0;
    const gap = 12.0;
    const iconSize = 22.0;
    const iconBackgroundSize = 44.0;
    final titleHeight = (MediaQuery.textScalerOf(context).scale(13) * 18 / 13)
        .ceilToDouble();
    final contentHeight = iconBackgroundSize + 10 + titleHeight + 4;
    final itemHeight = contentHeight > 76 ? contentHeight : 76.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowCount = (items.length + maxColumnCount - 1) ~/ maxColumnCount;

    return Container(
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              CardTool.parseAdaptiveHexColor(
                context,
                '#ECECEC',
                category: CardTool.iosDarkModeChildBgColorKey,
              ) ??
              context.adaptiveHairline,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(rowCount, (rowIndex) {
            final start = rowIndex * maxColumnCount;
            final end = (start + maxColumnCount).clamp(0, items.length);
            final rowItems = items.sublist(start, end);
            if (rowItems.isEmpty) {
              return const SizedBox.shrink();
            }

            final rowChildren = <Widget>[];
            for (var index = 0; index < rowItems.length; index++) {
              rowChildren.add(
                Expanded(
                  child: _buildList2Item(
                    context,
                    isDark,
                    rowItems[index],
                    itemHeight: itemHeight,
                    iconSize: iconSize,
                    iconBackgroundSize: iconBackgroundSize,
                    titleHeight: titleHeight,
                  ),
                ),
              );
              if (index != rowItems.length - 1) {
                rowChildren.add(const SizedBox(width: gap));
              }
            }

            return Padding(
              padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rowChildren,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildList2Item(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> item, {
    required double itemHeight,
    required double iconSize,
    required double iconBackgroundSize,
    required double titleHeight,
  }) {
    final route = _listRoute(item);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (route.path.isEmpty) return;
        onNavigate?.call(route.path, route.params);
      },
      child: SizedBox(
        height: itemHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconBackgroundSize,
              height: iconBackgroundSize,
              decoration: BoxDecoration(
                color: _list2IconBackgroundColor(context),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: iconSize,
                height: iconSize,
                child: _networkIcon(
                  context,
                  url: _iconUrl(item, isDark),
                  size: iconSize,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: titleHeight,
                child: Text(
                  _title(item),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    fontWeight: FontWeight.w400,
                    color: _list2TitleColor(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
