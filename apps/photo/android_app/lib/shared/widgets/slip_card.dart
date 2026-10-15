import 'package:flutter/material.dart';
import 'base_card.dart';
import 'card_item_route.dart';
import 'card_navigation.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 滑动卡片 (slip_1)
/// 对齐 iOS Slip1CardView：横向滚动图片列表，可带标题
class SlipCard extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const SlipCard({super.key, required super.cardData, this.onNavigate});

  @override
  Widget buildCardContent(BuildContext context) {
    final detail = cardData.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final title = cardData.title ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 24;
        final itemWidth = _slipItemWidth(cardWidth, items.length);
        final itemHeight = itemWidth * (cardData.aspectRatio ?? 0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 22,
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            if (title.isNotEmpty && itemHeight > 0) const SizedBox(height: 8),
            SizedBox(
              height: itemHeight,
              child: itemHeight <= 0
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      key: const ValueKey('slip_1_collection'),
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == items.length - 1 ? 0 : 12,
                          ),
                          child: _SlipImageItem(
                            item: item,
                            width: itemWidth,
                            height: itemHeight,
                            onNavigate: onNavigate,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  double _slipItemWidth(double cardWidth, int itemCount) {
    if (itemCount <= 0) return 0;
    if (itemCount == 1) return cardWidth;
    if (itemCount == 2) return (cardWidth - 12) / 2;
    return (cardWidth - 24) / 5 * 2;
  }
}

class _SlipImageItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final double width;
  final double height;
  final CardNavigateCallback? onNavigate;

  const _SlipImageItem({
    required this.item,
    required this.width,
    required this.height,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final picture = _resolvedPicture(context, item);
    final route = extractCardItemRoute(item);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (route.path.isNotEmpty) onNavigate?.call(route.path, route.params);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                constraints: BoxConstraints.tightFor(
                  width: width,
                  height: height,
                ),
                decoration: BoxDecoration(
                  color: context.adaptiveMutedBlock,
                  image: picture.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(picture),
                          fit: BoxFit.fill,
                          onError: (_, __) {},
                        )
                      : null,
                ),
                child: picture.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.image,
                          size: 32,
                          color: context.adaptiveTextHint,
                        ),
                      )
                    : null,
              ),
              ..._pictureInfoText(context, width, height),
              ..._pictureInfoButtons(context, width, height),
            ],
          ),
        ),
      ),
    );
  }

  String _resolvedPicture(BuildContext context, Map<String, dynamic> item) {
    final light = _stringValue(item['picture']);
    final dark = _stringValue(item['picture_dark'] ?? item['pictureDark']);
    if (Theme.of(context).brightness == Brightness.dark && dark.isNotEmpty) {
      return dark;
    }
    return light;
  }

  List<Widget> _pictureInfoText(
    BuildContext context,
    double imageWidth,
    double imageHeight,
  ) {
    final pictureInfo = item['picture_info'];
    if (pictureInfo is! Map) return const [];
    final blocks = pictureInfo['picture_text_block'];
    if (blocks is! List) return const [];

    return blocks.whereType<Map>().map((raw) {
      final block = Map<String, dynamic>.from(raw);
      final rect = _percentRect(block, imageWidth, imageHeight);
      final text = _stringValue(block['text']);
      if (text.isEmpty || rect == null) return const SizedBox.shrink();

      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Text(
          text,
          maxLines: null,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: _doubleValue(block['font_size'], fallback: 14),
            fontWeight: _fontWeight(_stringValue(block['font_weight'])),
            color: _adaptiveHexColor(
              context,
              light: _stringValue(block['color']),
              dark: _stringValue(block['color_dark']),
              fallback: Colors.red,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _pictureInfoButtons(
    BuildContext context,
    double imageWidth,
    double imageHeight,
  ) {
    final pictureInfo = item['picture_info'];
    if (pictureInfo is! Map) return const [];
    final blocks = pictureInfo['picture_cta_block'];
    if (blocks is! List) return const [];

    return blocks.whereType<Map>().map((raw) {
      final block = Map<String, dynamic>.from(raw);
      final rect = _percentRect(block, imageWidth, imageHeight);
      final title = _stringValue(block['title']);
      if (title.isEmpty || rect == null) return const SizedBox.shrink();

      final route = extractCardItemRoute(block);
      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (route.path.isNotEmpty) {
              onNavigate?.call(route.path, route.params);
            }
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _adaptiveHexColor(
                context,
                light: _stringValue(block['bg_color']),
                dark: _stringValue(block['bg_color_dark']),
                fallback: Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(
                _doubleValue(block['corner']),
              ),
              border: _buttonBorder(context, block),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: _doubleValue(block['title_font_size'], fallback: 14),
                fontWeight: _fontWeight(
                  _stringValue(block['title_font_weight']),
                ),
                color: _adaptiveHexColor(
                  context,
                  light: _stringValue(block['title_color']),
                  dark: _stringValue(block['title_color_dark']),
                  fallback: context.adaptiveTextPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Border? _buttonBorder(BuildContext context, Map<String, dynamic> block) {
    final borderWidth = _doubleValue(block['border_width']);
    if (borderWidth <= 0) return null;
    return Border.all(
      width: borderWidth,
      color: _adaptiveHexColor(
        context,
        light: _stringValue(block['border_color']),
        dark: _stringValue(block['border_color_dark']),
        fallback: Colors.transparent,
      ),
    );
  }

  Rect? _percentRect(
    Map<String, dynamic> block,
    double imageWidth,
    double imageHeight,
  ) {
    final left = _doubleValue(block['left'], fallback: -1);
    final top = _doubleValue(block['top'], fallback: -1);
    final width = _doubleValue(block['width']);
    final height = _doubleValue(block['height']);
    if (left < 0 || top < 0 || width <= 0 || height <= 0) return null;
    return Rect.fromLTWH(
      imageWidth * left / 100,
      imageHeight * top / 100,
      imageWidth * width / 100,
      imageHeight * height / 100,
    );
  }

  Color _adaptiveHexColor(
    BuildContext context, {
    required String light,
    required String dark,
    required Color fallback,
  }) {
    final raw =
        Theme.of(context).brightness == Brightness.dark && dark.isNotEmpty
        ? dark
        : light;
    if (raw.isEmpty) return fallback;
    final normalized = raw.replaceFirst('#', '');
    final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
    final value = int.tryParse(withAlpha, radix: 16);
    return value == null ? fallback : Color(value);
  }

  FontWeight _fontWeight(String raw) {
    switch (raw.toLowerCase()) {
      case 'bold':
      case '700':
        return FontWeight.bold;
      case 'semibold':
      case 'semi_bold':
      case '600':
        return FontWeight.w600;
      case 'medium':
      case '500':
        return FontWeight.w500;
      case 'light':
      case '300':
        return FontWeight.w300;
      default:
        return FontWeight.w400;
    }
  }

  double _doubleValue(Object? raw, {double fallback = 0}) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? fallback;
    return fallback;
  }

  String _stringValue(Object? raw) => raw is String ? raw : '';
}
