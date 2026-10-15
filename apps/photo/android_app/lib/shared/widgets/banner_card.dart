import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/tab_bar_item.dart';
import '../../core/models/banner_item_model.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'base_card.dart';
import 'card_factory.dart';
import 'st_network_image.dart';

/// Banner 轮播（banner_*，规格对齐原生 `Banner1CardView` / `CustomPageIndicatorView`）
///
/// 仓库内无 iOS 源码时以 Android `Cards/banner_1` 为准（与 iOS 同源产品线）：透明背景区域、
/// `fitXY` 铺满、指示器叠在底部（默认左对齐 `marginStart=30` / `bottom=12`）、点 6×6 /
/// 当前 12×6 / 间距 4、浅色系 `#80FFFFFF` / `#FFFFFF`，3s 自动轮播 + 首尾循环。
class BannerCard extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const BannerCard({
    super.key,
    required super.cardData,
    super.compactTop,
    this.onNavigate,
  });

  @override
  Widget buildCardContent(BuildContext context) {
    return _BannerCarouselBody(cardData: cardData, onNavigate: onNavigate);
  }
}

class _BannerCarouselBody extends StatefulWidget {
  final ConfigCardItemData cardData;
  final CardNavigateCallback? onNavigate;

  const _BannerCarouselBody({required this.cardData, this.onNavigate});

  @override
  State<_BannerCarouselBody> createState() => _BannerCarouselBodyState();
}

class _BannerCarouselBodyState extends State<_BannerCarouselBody> {
  static const Duration _scrollInterval = Duration(milliseconds: 3000);
  static const Duration _animDuration = Duration(milliseconds: 350);

  /// 默认宽高比：与常见配置图 Banner 接近（无 `aspect_ratio` 时使用）
  static const double _defaultAspect = 343 / 131;

  late PageController _controller;
  Timer? _autoTimer;
  int _realIndex = 0;
  bool _userDragging = false;

  List<BannerItemModel> get _items {
    final detail = widget.cardData.cardDetail;
    final raw = detail?['items'] as List<dynamic>? ?? [];
    return raw
        .map((e) => BannerItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  bool get _loop => _items.length > 1;

  List<BannerItemModel> get _pages {
    final items = _items;
    if (!_loop) return items;
    return [items.last, ...items, items.first];
  }

  int get _initialPage => _loop ? 1 : 0;

  /// 0=start+30dp, 1=center, 2=end+30dp — 对齐 `Banner1CardView.indicatorPosition`
  int get _indicatorAlign {
    final d = widget.cardData.cardDetail;
    final v = d?['indicator_position'] ?? d?['indicatorPosition'];
    if (v is int) return v.clamp(0, 2);
    if (v is String) return int.tryParse(v)?.clamp(0, 2) ?? 0;
    return 0;
  }

  Color _dotNormal(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? context.adaptiveTextPrimary.withValues(alpha: 0.45)
        : const Color(0x80FFFFFF);
  }

  Color _dotSelected(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? context.adaptiveTextPrimary : const Color(0xFFFFFFFF);
  }

  @override
  void initState() {
    super.initState();
    _realIndex = 0;
    _controller = PageController(initialPage: _initialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAuto());
  }

  @override
  void didUpdateWidget(covariant _BannerCarouselBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItems = oldWidget.cardData.cardDetail?['items'] as List?;
    final newItems = widget.cardData.cardDetail?['items'] as List?;
    if (oldItems?.length != newItems?.length) {
      _autoTimer?.cancel();
      _controller.dispose();
      _controller = PageController(initialPage: _initialPage);
      _realIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAuto());
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAuto() {
    _autoTimer?.cancel();
    final items = _items;
    if (items.length <= 1 || !mounted) return;
    _autoTimer = Timer(_scrollInterval, () {
      if (!mounted || !_controller.hasClients || _userDragging) return;
      final cur = _controller.page?.round() ?? _controller.initialPage;
      _controller.animateToPage(
        cur + 1,
        duration: _animDuration,
        curve: Curves.easeInOut,
      );
      _scheduleAuto();
    });
  }

  void _onUserScrollStart() {
    _userDragging = true;
    _autoTimer?.cancel();
  }

  void _onScrollIdle() {
    _userDragging = false;
    _scheduleAuto();
  }

  void _onPageChanged(int vpIndex) {
    final items = _items;
    final expanded = _pages;

    if (!_loop || items.length <= 1) {
      setState(() => _realIndex = vpIndex);
      _onScrollIdle();
      return;
    }

    final n = items.length;
    final lastIdx = expanded.length - 1;

    if (vpIndex == 0) {
      _realIndex = n - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpToPage(n);
        }
      });
      setState(() {});
      _onScrollIdle();
      return;
    }
    if (vpIndex == lastIdx) {
      _realIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpToPage(1);
        }
      });
      setState(() {});
      _onScrollIdle();
      return;
    }

    setState(() => _realIndex = vpIndex - 1);
    _onScrollIdle();
  }

  double _aspect(BuildContext context) {
    final r = widget.cardData.aspectRatio;
    if (r != null && r > 0.01) return r;
    return _defaultAspect;
  }

  Widget _bannerImagePlaceholder(BuildContext context) {
    return ColoredBox(
      color: context.adaptivePlaceholderSurface,
      child: Icon(
        Icons.image_outlined,
        color: context.adaptiveTextHint,
        size: 44,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final pages = _pages;
    final aspect = _aspect(context);

    if (items.isEmpty) {
      return AspectRatio(
        aspectRatio: aspect,
        child: ColoredBox(
          color: context.adaptivePlaceholderSurface,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 40,
              color: context.adaptiveTextHint,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollStartNotification>(
            onNotification: (_) {
              _onUserScrollStart();
              return false;
            },
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _onScrollIdle();
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final item = pages[index];
                  final picture = item.picture.isNotEmpty ? item.picture : null;
                  final route = CardFactory.extractItemRoute(item.raw);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (route.path.isNotEmpty && widget.onNavigate != null) {
                        widget.onNavigate!(route.path, route.params);
                      }
                    },
                    child: picture == null
                        ? ColoredBox(
                            color: context.adaptivePlaceholderSurface,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: context.adaptiveTextHint,
                              size: 44,
                            ),
                          )
                        : STNetworkImage(
                            imageUrl: picture,
                            fit: BoxFit.fill,
                            width: double.infinity,
                            height: double.infinity,
                            placeholderBuilder: _bannerImagePlaceholder,
                          ),
                  );
                },
              ),
            ),
          ),
          if (items.length > 1)
            Positioned(
              left: _indicatorAlign == 0 ? 30 : null,
              right: _indicatorAlign == 2 ? 30 : null,
              bottom: 12,
              child: _indicatorAlign == 1
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: _Banner1Dots(
                        count: items.length,
                        current: _realIndex.clamp(0, items.length - 1),
                        normalColor: _dotNormal(context),
                        selectedColor: _dotSelected(context),
                      ),
                    )
                  : _Banner1Dots(
                      count: items.length,
                      current: _realIndex.clamp(0, items.length - 1),
                      normalColor: _dotNormal(context),
                      selectedColor: _dotSelected(context),
                    ),
            ),
        ],
      ),
    );
  }
}

/// 对齐 `CustomPageIndicatorView`：圆角胶囊点，当前项宽 12，其余 6，高 6，间距 4
class _Banner1Dots extends StatelessWidget {
  final int count;
  final int current;
  final Color normalColor;
  final Color selectedColor;

  const _Banner1Dots({
    required this.count,
    required this.current,
    required this.normalColor,
    required this.selectedColor,
  });

  static double _totalWidth(int count, int current) {
    if (count <= 0) return 0;
    const dotW = 6.0;
    const selW = 12.0;
    const spacing = 4.0;
    double w = 0;
    for (int i = 0; i < count; i++) {
      w += (i == current ? selW : dotW);
      if (i < count - 1) w += spacing;
    }
    return w;
  }

  static double _height() => 6;

  @override
  Widget build(BuildContext context) {
    final h = _height();
    final w = _totalWidth(count, current);
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _BannerDotsPainter(
          count: count,
          current: current,
          normalColor: normalColor,
          selectedColor: selectedColor,
        ),
      ),
    );
  }
}

class _BannerDotsPainter extends CustomPainter {
  final int count;
  final int current;
  final Color normalColor;
  final Color selectedColor;

  static const double dotW = 6;
  static const double selW = 12;
  static const double dotH = 6;
  static const double spacing = 4;

  _BannerDotsPainter({
    required this.count,
    required this.current,
    required this.normalColor,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0) return;
    var x = 0.0;
    final y = (size.height - dotH) / 2;
    final r = dotH / 2;

    for (int i = 0; i < count; i++) {
      final sel = i == current;
      final w = sel ? selW : dotW;
      final paint = Paint()
        ..color = sel ? selectedColor : normalColor
        ..style = PaintingStyle.fill;

      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, dotH),
        Radius.circular(r),
      );
      canvas.drawRRect(rr, paint);
      x += w + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _BannerDotsPainter oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.current != current ||
        oldDelegate.normalColor != normalColor ||
        oldDelegate.selectedColor != selectedColor;
  }
}
