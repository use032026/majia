import 'dart:math';

import 'package:flutter/material.dart';
import 'card_factory.dart';
import 'base_card.dart';
import '../../core/config/card_tool.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 网格图标卡片 (`grid_*`)
///
/// UI 对齐 iOS **Grid1CardView / Grid1CardItemView**：
/// - `numPerLine` 默认 5（来自 `cardDetail.num_per_line`）
/// - `grid_1` 对齐 Figma：一页最多 5 个，超过 5 个横向分页并显示底部指示条
/// - 图标 `BoxFit.contain`，**保持原色**（与 SDWebImage 一致，**不能传 color 染色**）
/// - 标题 12pt、`#000000`、最多 3 行、与图标间距 7
/// - 数据字段对齐 iOS `GridItemModel`：`title` / `icon` / `icon_dark` / `router` / `link` /
///   `router_permission`，`icon_dark` 为空时回退 `icon`。
///
/// 跳转对齐 iOS `Grid1CardView.tapGridItem` → `CardRouterOpen(GridItemModel.routerModel)`：
///   `routerModel.router = router`、`routerModel.params = {link, permission}`，
///   两个键始终存在（即使为空字符串）。router 空时不跳（对齐 iOS `STRouterManager`
///   `!router.isValid → return`，不做 `/web` 兜底）。
class GridCard extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const GridCard({super.key, required super.cardData, this.onNavigate});

  static const double _iconSize = 44;
  static const double _captionGap = 7;
  int _numPerLine(Map<String, dynamic>? detail) {
    if (detail == null) return 5;
    dynamic raw = detail['num_per_line'] ?? detail['numPerLine'];
    if (raw == null) {
      final nested = detail['grid_model'] ?? detail['gridModel'];
      if (nested is Map<String, dynamic>) {
        raw = nested['num_per_line'] ?? nested['numPerLine'];
      }
    }
    if (raw is int && raw > 0) return raw.clamp(1, 10);
    if (raw is num && raw > 0) return raw.toInt().clamp(1, 10);
    return 5;
  }

  /// 对齐 iOS `GridItemModel`：`icon_dark` 为空时回退 `icon`
  String? _iconUrl(Map<String, dynamic> item, bool isDark) {
    final iconLight = (item['icon'] as String?)?.trim();
    final iconDarkRaw = (item['icon_dark'] as String?)?.trim();
    final iconDark = (iconDarkRaw == null || iconDarkRaw.isEmpty)
        ? iconLight
        : iconDarkRaw;
    final url = isDark ? iconDark : iconLight;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  /// 对齐 iOS `GridItemModel.routerModel`：
  ///   `router`、`params = { link, permission }`（始终带这两个键，即使是空字符串）。
  /// 不做 `link → /web` 兜底（iOS `STRouterManager.openPageWithRouter` 内部统一处理空 router）。
  ({String router, Map<String, dynamic> params}) _gridRoute(
    Map<String, dynamic> item,
  ) {
    final route = CardFactory.extractItemRoute(item);
    return (
      router: route.path.trim(),
      params: route.params ?? <String, dynamic>{},
    );
  }

  @override
  Widget buildCardContent(BuildContext context) {
    final detail = cardData.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final allItems = rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // 对齐 iOS Grid1/2CardView：生产环境不对 grid item 做 show_permission 过滤
    final items = allItems;
    if (items.isEmpty) return const SizedBox.shrink();

    if (cardData.cardStyle == 'grid_2') {
      return _Grid2CardBody(
        items: items,
        numPerLine: _numPerLine(detail),
        iconUrlFor: _iconUrl,
        routeFor: _gridRoute,
        onNavigate: onNavigate,
        placeholderBuilder: _placeholderIcon,
      );
    }

    return _Grid1CardBody(
      items: items,
      iconUrlFor: _iconUrl,
      routeFor: _gridRoute,
      onNavigate: onNavigate,
      placeholderBuilder: _placeholderIcon,
    );
  }

  Widget _placeholderIcon(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.adaptiveIconPillBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.apps_outlined,
        size: 26,
        color: context.adaptiveTextHint,
      ),
    );
  }
}

typedef _GridIconResolver =
    String? Function(Map<String, dynamic> item, bool isDark);

typedef _GridRouteResolver =
    ({String router, Map<String, dynamic> params}) Function(
      Map<String, dynamic> item,
    );

typedef _GridPlaceholderBuilder = Widget Function(BuildContext context);

class _Grid1CardBody extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final _GridIconResolver iconUrlFor;
  final _GridRouteResolver routeFor;
  final CardNavigateCallback? onNavigate;
  final _GridPlaceholderBuilder placeholderBuilder;

  const _Grid1CardBody({
    required this.items,
    required this.iconUrlFor,
    required this.routeFor,
    required this.onNavigate,
    required this.placeholderBuilder,
  });

  @override
  State<_Grid1CardBody> createState() => _Grid1CardBodyState();
}

class _Grid1CardBodyState extends State<_Grid1CardBody> {
  static const double _iconSize = 28;
  static const double _singlePageHeight = 95;
  static const double _pagedContentHeight = 80;
  static const double _itemHeight = 52;
  static const int _maxItemsPerPage = 5;
  static const double _indicatorRailWidth = 25;
  static const double _indicatorSliderWidth = 13;
  static const double _indicatorHeight = 3;
  static const double _indicatorZoneHeight = 15;

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

  int _pageCount() => (widget.items.length / _maxItemsPerPage).ceil();

  List<Map<String, dynamic>> _pageItems(int index) {
    final start = index * _maxItemsPerPage;
    if (start >= widget.items.length) return const [];
    final end = min(start + _maxItemsPerPage, widget.items.length);
    return widget.items.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.items.length <= _maxItemsPerPage) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final count = widget.items.length;
          final itemWidth = count < 1 ? width : width / count;
          final itemHeight = max(
            _itemHeight,
            _GridCardItem.heightForTitles(
              context,
              widget.items,
              itemWidth,
              _iconSize,
            ),
          );

          return SizedBox(
            width: width,
            height: max(_singlePageHeight, itemHeight),
            child: Center(
              child: Row(
                children: List.generate(count, (i) {
                  final item = widget.items[i];
                  return SizedBox(
                    width: itemWidth,
                    child: _GridCardItem(
                      item: item,
                      width: itemWidth,
                      height: itemHeight,
                      iconSize: _iconSize,
                      iconUrl: widget.iconUrlFor(item, isDark),
                      route: widget.routeFor(item),
                      onNavigate: widget.onNavigate,
                      placeholderBuilder: widget.placeholderBuilder,
                    ),
                  );
                }),
              ),
            ),
          );
        },
      );
    }

    final totalPages = _pageCount();
    final maxOffset = max(totalPages - 1, 0);
    final needsIndicator = totalPages > 1;
    final sliderTravel = needsIndicator && maxOffset > 0
        ? (_scrollPage.clamp(0.0, maxOffset.toDouble()) / maxOffset) *
              (_indicatorRailWidth - _indicatorSliderWidth)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width / _maxItemsPerPage;
        final itemHeight = max(
          _itemHeight,
          _GridCardItem.heightForTitles(
            context,
            widget.items,
            itemWidth,
            _iconSize,
          ),
        );
        final contentHeight = max(_pagedContentHeight, itemHeight);
        final totalHeight =
            contentHeight + (needsIndicator ? _indicatorZoneHeight : 0);

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
                    final pageItemCount = pageItems.length;
                    return SizedBox(
                      height: contentHeight,
                      child: Center(
                        child: Row(
                          children: List.generate(_maxItemsPerPage, (i) {
                            if (i >= pageItemCount) {
                              return SizedBox(width: itemWidth);
                            }
                            final item = pageItems[i];
                            return SizedBox(
                              width: itemWidth,
                              child: _GridCardItem(
                                item: item,
                                width: itemWidth,
                                height: itemHeight,
                                iconSize: _iconSize,
                                iconUrl: widget.iconUrlFor(item, isDark),
                                route: widget.routeFor(item),
                                onNavigate: widget.onNavigate,
                                placeholderBuilder: widget.placeholderBuilder,
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (needsIndicator)
                Positioned(
                  left: (width - _indicatorRailWidth) / 2,
                  top:
                      contentHeight +
                      (_indicatorZoneHeight - _indicatorHeight) / 2,
                  child: Container(
                    width: _indicatorRailWidth,
                    height: _indicatorHeight,
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
                        width: _indicatorSliderWidth,
                        height: _indicatorHeight,
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

class _Grid2CardBody extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int numPerLine;
  final _GridIconResolver iconUrlFor;
  final _GridRouteResolver routeFor;
  final CardNavigateCallback? onNavigate;
  final _GridPlaceholderBuilder placeholderBuilder;

  const _Grid2CardBody({
    required this.items,
    required this.numPerLine,
    required this.iconUrlFor,
    required this.routeFor,
    required this.onNavigate,
    required this.placeholderBuilder,
  });

  @override
  State<_Grid2CardBody> createState() => _Grid2CardBodyState();
}

class _Grid2CardBodyState extends State<_Grid2CardBody> {
  static const double _horizontalSpacing = 12;
  static const double _itemHeight = 78;
  static const double _topPadding = 17;
  static const double _indicatorRailWidth = 25;
  static const double _indicatorSliderWidth = 8;
  static const double _indicatorHeight = 3;
  static const double _indicatorZoneHeight = _indicatorHeight + 12;

  final ScrollController _controller = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final offset = _controller.hasClients ? _controller.offset : 0.0;
    if ((offset - _scrollOffset).abs() < 0.5) return;
    setState(() {
      _scrollOffset = offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perLine = widget.numPerLine <= 0 ? 5 : widget.numPerLine;
        final allSpacing = (perLine + 1) * _horizontalSpacing;
        final rawItemWidth = (width - allSpacing) / perLine;
        final itemWidth = rawItemWidth < GridCard._iconSize
            ? GridCard._iconSize
            : rawItemWidth;
        final itemHeight = max(
          _itemHeight,
          _GridCardItem.heightForTitles(
            context,
            widget.items,
            itemWidth,
            GridCard._iconSize,
          ),
        );
        final contentWidth =
            _horizontalSpacing +
            widget.items.length * (itemWidth + _horizontalSpacing);
        final needsIndicator = contentWidth > width;
        final contentAreaHeight = _topPadding + itemHeight;
        final totalHeight =
            contentAreaHeight + (needsIndicator ? _indicatorZoneHeight : 0);
        final maxOffset = (contentWidth - width).clamp(0.0, double.infinity);
        final sliderX = maxOffset == 0
            ? 0.0
            : (_scrollOffset.clamp(0.0, maxOffset) / maxOffset) *
                  (_indicatorRailWidth - _indicatorSliderWidth);

        return SizedBox(
          width: width,
          height: totalHeight,
          child: Stack(
            children: [
              SizedBox(
                height: contentAreaHeight,
                child: SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(width: _horizontalSpacing),
                        for (final item in widget.items) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: _topPadding),
                            child: _GridCardItem(
                              item: item,
                              width: itemWidth,
                              height: itemHeight,
                              iconSize: GridCard._iconSize,
                              iconUrl: widget.iconUrlFor(item, isDark),
                              route: widget.routeFor(item),
                              onNavigate: widget.onNavigate,
                              placeholderBuilder: widget.placeholderBuilder,
                            ),
                          ),
                          const SizedBox(width: _horizontalSpacing),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (needsIndicator)
                Positioned(
                  left: (width - _indicatorRailWidth) / 2,
                  top:
                      contentAreaHeight +
                      (_indicatorZoneHeight - _indicatorHeight) / 2,
                  child: Container(
                    width: _indicatorRailWidth,
                    height: _indicatorHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: Offset(sliderX, 0),
                      child: Container(
                        width: _indicatorSliderWidth,
                        height: _indicatorHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
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

class _GridCardItem extends StatelessWidget {
  static const TextStyle _captionTextStyle = TextStyle(
    fontSize: 12,
    height: 1.15,
  );

  static double heightForTitles(
    BuildContext context,
    List<Map<String, dynamic>> items,
    double width,
    double iconSize,
  ) {
    final style = DefaultTextStyle.of(context).style.merge(_captionTextStyle);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var maxCaptionHeight = 0.0;
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(text: item['title'] as String? ?? '', style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: max(0, width - 4));
      maxCaptionHeight = max(maxCaptionHeight, painter.height);
      painter.dispose();
    }
    return (iconSize + GridCard._captionGap + maxCaptionHeight + 2)
        .ceilToDouble();
  }

  final Map<String, dynamic> item;
  final double width;
  final double height;
  final double iconSize;
  final String? iconUrl;
  final ({String router, Map<String, dynamic> params}) route;
  final CardNavigateCallback? onNavigate;
  final _GridPlaceholderBuilder placeholderBuilder;

  const _GridCardItem({
    required this.item,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.iconUrl,
    required this.route,
    required this.onNavigate,
    required this.placeholderBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? '';

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (route.router.isEmpty) return;
          onNavigate?.call(
            route.router,
            route.params,
            action: title.isNotEmpty ? 'Grid-$title' : 'Grid入口',
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: iconUrl != null
                  ? Image.network(
                      iconUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => placeholderBuilder(context),
                    )
                  : placeholderBuilder(context),
            ),
            const SizedBox(height: GridCard._captionGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _captionTextStyle.copyWith(
                  color:
                      CardTool.parseAdaptiveHexColor(
                        context,
                        '#000000',
                        category: CardTool.iosDarkModeTextColorKey,
                      ) ??
                      context.adaptiveTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
