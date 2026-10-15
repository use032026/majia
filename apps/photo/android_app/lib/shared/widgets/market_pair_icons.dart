import 'package:flutter/material.dart';
import '../../core/models/market_product_model.dart';
import 'st_network_image.dart';

/// 行情列表左侧币种图标
///
/// 数据与 iOS `CategoryMarketModel` / `STMarketProductModel` 一致：
/// [MarketProductModel.isSingleIcon]、[icon]、[currencyBaseIcon]、[currencyProfitIcon]。
/// 双币对时按 Figma 自选/行情列表样式：方形画布内主图占满，
/// quote 图标以 50% 尺寸叠在右下角并带白色描边。
class MarketPairIcons extends StatelessWidget {
  final bool isSingleIcon;
  final String? icon;
  final String? currencyBaseIcon;
  final String? currencyProfitIcon;
  final double size;

  const MarketPairIcons({
    super.key,
    required this.isSingleIcon,
    this.icon,
    this.currencyBaseIcon,
    this.currencyProfitIcon,
    this.size = 14,
  });

  factory MarketPairIcons.of(MarketProductModel p, {double size = 14}) {
    return MarketPairIcons(
      isSingleIcon: p.isSingleIcon,
      icon: p.icon,
      currencyBaseIcon: p.currencyBaseIcon,
      currencyProfitIcon: p.currencyProfitIcon,
      size: size,
    );
  }

  factory MarketPairIcons.category(
    CategoryMarketProductModel p, {
    double size = 14,
  }) {
    return MarketPairIcons(
      isSingleIcon: p.isSingleIcon,
      icon: p.icon,
      currencyBaseIcon: p.currencyBaseIcon,
      currencyProfitIcon: p.currencyProfitIcon,
      size: size,
    );
  }

  static const Color _placeholder = Color(0xFFE8E8E8);

  @override
  Widget build(BuildContext context) {
    if (isSingleIcon) {
      return _Coin(url: icon, size: size, ring: false);
    }
    final baseRaw = (currencyBaseIcon ?? icon)?.trim();
    final quoteRaw = currencyProfitIcon?.trim();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _Coin(
              url: (baseRaw != null && baseRaw.isNotEmpty) ? baseRaw : null,
              size: size,
              ring: false,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _Coin(
              url: (quoteRaw != null && quoteRaw.isNotEmpty) ? quoteRaw : null,
              size: size * 0.5,
              ring: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  final String? url;
  final double size;
  final bool ring;

  const _Coin({required this.url, required this.size, required this.ring});

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    final borderWidth = (size * 0.125).clamp(1.0, 2.0);
    if (u == null || u.isEmpty) {
      return _diskPlaceholder(ring: ring, borderWidth: borderWidth);
    }
    final inner = ring ? (size - borderWidth * 2).clamp(2.0, size) : size;
    final img = ClipOval(
      child: STNetworkImage(
        imageUrl: u,
        width: inner,
        height: inner,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => Container(
          width: inner,
          height: inner,
          color: MarketPairIcons._placeholder,
        ),
      ),
    );
    if (!ring) return img;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: img,
    );
  }

  Widget _diskPlaceholder({required bool ring, required double borderWidth}) {
    final inner = ring ? (size - borderWidth * 2).clamp(2.0, size) : size;
    final core = Container(
      width: inner,
      height: inner,
      decoration: const BoxDecoration(
        color: MarketPairIcons._placeholder,
        shape: BoxShape.circle,
      ),
    );
    if (!ring) return core;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderWidth),
      ),
      child: core,
    );
  }
}
