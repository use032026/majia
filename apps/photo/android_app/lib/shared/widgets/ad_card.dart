import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'base_card.dart';
import 'card_factory.dart';
import 'card_item_route.dart';

/// Ad 广告卡片 (ad_1)
/// 对齐 iOS `Ad1CardView`：单图 AspectFit、暗黑图、图片叠字/按钮和 CardRouterOpen 跳转。
class AdCard extends BaseCard {
  static const double _iosDefaultHeightRatio = 0.185;

  final CardNavigateCallback? onNavigate;

  const AdCard({super.key, required super.cardData, this.onNavigate});

  @override
  Widget buildCardContent(BuildContext context) {
    final payload = _adPayload;
    final route = extractCardItemRoute(_adPayload);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 24;
        final height = width * (cardData.aspectRatio ?? _iosDefaultHeightRatio);
        final picture = _resolvedPicture(context, payload);
        final placeholder = _stringValue(payload['placeholderImage']);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (route.path.isNotEmpty) {
              onNavigate?.call(route.path, route.params);
            }
          },
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: context.adaptivePlaceholderSurface,
                  child: _AdImage(
                    picture: picture,
                    placeholder: placeholder,
                    title: cardData.title,
                  ),
                ),
                ..._pictureInfoText(context, width, height),
                ..._pictureInfoButtons(context, width, height),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> get _adPayload {
    final detail = cardData.cardDetail;
    final items = detail?['items'];
    final item = items is List && items.isNotEmpty && items.first is Map
        ? Map<String, dynamic>.from(items.first as Map)
        : null;

    final base = detail == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(detail);
    if (item != null) {
      base.addAll(item);
      base.putIfAbsent('picture', () => item['image']);
      base.putIfAbsent(
        'placeholderImage',
        () => item['placeholderImage'] ?? item['placeholder_image'],
      );
    }

    base.putIfAbsent('link', () => cardData.link);
    return base;
  }

  String _resolvedPicture(BuildContext context, Map<String, dynamic> item) {
    final light = _stringValue(item['picture'] ?? item['image']);
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
    final pictureInfo = _adPayload['picture_info'] ?? _adPayload['pictureInfo'];
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
              fallback: context.adaptiveTextPrimary,
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
    final pictureInfo = _adPayload['picture_info'] ?? _adPayload['pictureInfo'];
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

class _AdImage extends StatelessWidget {
  final String picture;
  final String placeholder;
  final String? title;

  const _AdImage({
    required this.picture,
    required this.placeholder,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (picture.isNotEmpty) {
      return Image.network(
        picture,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(context),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    if (placeholder.isNotEmpty) {
      return Image.asset(
        'assets/images/$placeholder.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _localizedHint(context),
      );
    }
    return _localizedHint(context);
  }

  Widget _localizedHint(BuildContext context) {
    final localizations = STLocalizations.ofContext(context);
    return FutureBuilder<String>(
      future: localizations.text('ad_click_hint', fallback: title ?? '广告位'),
      builder: (context, snapshot) {
        return Center(
          child: Text(
            snapshot.data ?? title ?? '',
            style: TextStyle(color: context.adaptiveTextTertiary, fontSize: 14),
          ),
        );
      },
    );
  }
}
