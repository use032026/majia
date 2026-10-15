import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'card_factory.dart';
import 'market_pair_icons.dart';
import 'base_card.dart';
import '../../core/models/market_product_model.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 行情卡片
///
/// UI 对齐 iOS **Market1CardView / Market1CardCell**（`market_*` 后缀其它样式也以 `_1` 为准）。
/// [dataCache]：按卡片维度缓存的 `{ products: [...] }`
class MarketCard extends BaseCard {
  final CardNavigateCallback? onNavigate;
  final Map<String, dynamic>? dataCache;

  const MarketCard({
    super.key,
    required super.cardData,
    this.onNavigate,
    this.dataCache,
  });

  static const int _rowCount = 4;

  String _cacheKey() => '${cardData.cardStyle}_${cardData.cardId}';

  @override
  Widget buildCardContent(BuildContext context) {
    final marketRouter = _extractMarketListRouter(cardData);

    return Consumer(
      builder: (context, ref, _) {
        final configHorGap = ref.watch(
          configDataManagerProvider.select((c) => c.cardHorGap),
        );
        // 与 [BaseCard] 外沿 margin 叠加后仍偏窄，列表区内略收紧；标题区仍跟全局配置
        final rowInset = (configHorGap * 0.5).clamp(4.0, configHorGap);
        final horGap = configHorGap;

        final riseAndFallType = ref.watch(
          userStateProvider.select((s) => s.riseAndFallType),
        );
        CardTool.setRiseAndFallType(riseAndFallType);

        List<MarketProductModel> displayProducts = [];

        final cached = dataCache?[_cacheKey()];
        if (cached is Map && cached['products'] is List) {
          for (final e in cached['products'] as List) {
            if (e is MarketProductModel) {
              displayProducts.add(e);
            } else if (e is SelfMarketProductModel) {
              displayProducts.add(
                MarketProductModel(
                  symbol: e.symbol,
                  name: e.name,
                  price: e.price,
                  change: e.change,
                  changePercent: e.changePercent,
                  precision: e.precision,
                  points: e.points,
                  subTitle: e.subTitle,
                  isSingleIcon: e.isSingleIcon,
                  icon: e.icon,
                  currencyBaseIcon: e.currencyBaseIcon,
                  currencyProfitIcon: e.currencyProfitIcon,
                ),
              );
            } else if (e is CategoryMarketProductModel) {
              displayProducts.add(
                MarketProductModel(
                  symbol: e.symbol,
                  name: e.name,
                  price: e.price,
                  change: e.change,
                  changePercent: e.changePercent,
                  precision: e.precision,
                  points: e.sparklinePrices,
                  subTitle: e.subTitle,
                  isSingleIcon: e.isSingleIcon,
                  icon: e.icon,
                  currencyBaseIcon: e.currencyBaseIcon,
                  currencyProfitIcon: e.currencyProfitIcon,
                ),
              );
            } else if (e is Map<String, dynamic>) {
              displayProducts.add(MarketProductModel.fromJson(e));
            }
          }
        }

        if (displayProducts.isEmpty &&
            cardData.cardStyle.startsWith('market_')) {
          displayProducts = List<MarketProductModel>.from(
            ref.watch(productListProvider),
          );
        }

        final isZh = Localizations.localeOf(
          context,
        ).languageCode.toLowerCase().startsWith('zh');
        final titleColor = context.adaptiveTextPrimary;
        final style = cardData.cardStyle;
        final isGrid7 = style == 'market_4' || style == 'market_7';
        final isMarketVariant = _isDedicatedMarketVariant(style);
        final headerTitle = isMarketVariant || isGrid7
            ? '行情推荐'
            : (style.startsWith('market_') ? '基础行情' : (cardData.title ?? '行情'));
        final cardLocalizationName = isGrid7 ? 'market_7' : style;
        final localizations = ref.watch(stLocalizationsProvider);
        final headerTop = switch (style) {
          'market_2' => 15.0,
          'market_3' => 8.0,
          'market_5' || 'market_6' => 16.0,
          _ => 8.0,
        };
        final headerLeft = switch (style) {
          'market_2' => 10.0,
          'market_5' || 'market_6' => 0.0,
          _ => horGap,
        };
        final headerRight = switch (style) {
          'market_2' => 10.0,
          'market_5' || 'market_6' => 0.0,
          _ => horGap,
        };
        final contentGap = switch (style) {
          'market_2' => 16.0,
          'market_3' => 17.0,
          'market_5' || 'market_6' => 14.0,
          _ => 17.0,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: headerTop,
                left: headerLeft,
                right: headerRight,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _MarketCardLocalizedText(
                      localizations: localizations,
                      cardName: cardLocalizationName,
                      textKey: isGrid7 ? 'market_recommendation' : '',
                      fallback: headerTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        height: 1.2,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(50, 25),
                      maximumSize: const Size(80, 28),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: context.adaptiveTextSecondary,
                    ),
                    onPressed: () {
                      if (marketRouter.path.isNotEmpty) {
                        onNavigate?.call(
                          marketRouter.path,
                          marketRouter.params,
                          action: '行情更多',
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MarketCardLocalizedText(
                          localizations: localizations,
                          cardName: cardLocalizationName,
                          textKey: isGrid7 ? 'kline_More' : '',
                          fallback: '更多',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: contentGap),
            if (displayProducts.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(horGap, 8, horGap, 24),
                child: Text(
                  '暂无数据',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              )
            else if (style == 'market_2')
              _Market2Carousel(
                products: displayProducts,
                isZh: isZh,
                onNavigate: onNavigate,
              )
            else if (style == 'market_3')
              _Market3Layout(
                products: displayProducts,
                horGap: horGap,
                isZh: isZh,
                onNavigate: onNavigate,
              )
            else if (style == 'market_5')
              _Market5List(
                products: displayProducts,
                isZh: isZh,
                onNavigate: onNavigate,
              )
            else if (style == 'market_6')
              _Market6Layout(
                products: displayProducts,
                isZh: isZh,
                onNavigate: onNavigate,
              )
            else if (isGrid7)
              _MarketGrid7(
                products: displayProducts,
                horGap: horGap,
                onNavigate: onNavigate,
              )
            else
              Column(
                children: List.generate(_rowCount, (index) {
                  final p = index < displayProducts.length
                      ? displayProducts[index]
                      : null;
                  return Column(
                    children: [
                      _MarketOneRow(
                        product: p,
                        horGap: rowInset,
                        isZh: isZh,
                        titleColor: titleColor,
                        onTap: p != null && p.symbol.isNotEmpty
                            ? () => onNavigate?.call('/market/detail', {
                                'symbol': p.symbol,
                              }, action: '行情详情')
                            : null,
                      ),
                      if (index < _rowCount - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: rowInset,
                          endIndent: rowInset,
                          color: context.adaptiveMutedBlock,
                        ),
                    ],
                  );
                }),
              ),
          ],
        );
      },
    );
  }
}

bool _isDedicatedMarketVariant(String style) {
  return style == 'market_2' ||
      style == 'market_3' ||
      style == 'market_4' ||
      style == 'market_5' ||
      style == 'market_6';
}

class _MarketCardLocalizedText extends StatelessWidget {
  final STLocalizations localizations;
  final String cardName;
  final String textKey;
  final String fallback;
  final TextStyle? style;

  const _MarketCardLocalizedText({
    required this.localizations,
    required this.cardName,
    required this.textKey,
    required this.fallback,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (textKey.isEmpty || cardName.isEmpty) {
      return Text(fallback, style: style);
    }
    return FutureBuilder<String>(
      future: localizations.cardText(cardName, textKey, fallback: fallback),
      initialData: fallback,
      builder: (context, snapshot) {
        return Text(snapshot.data ?? fallback, style: style);
      },
    );
  }
}

({String path, Map<String, dynamic>? params}) _extractMarketListRouter(
  ConfigCardItemData card,
) {
  final detail = card.cardDetail;

  if (detail != null) {
    final nested = detail['market_model'] ?? detail['marketModel'];
    if (nested is Map<String, dynamic>) {
      final rm = nested['router_market_model'] ?? nested['routerMarketModel'];
      if (rm is Map<String, dynamic>) {
        final extracted = CardFactory.extractItemRoute(rm);
        if (extracted.path.isNotEmpty) return extracted;
      }
    }

    final flatRm = detail['router_market_model'] ?? detail['routerMarketModel'];
    if (flatRm is Map<String, dynamic>) {
      final extracted = CardFactory.extractItemRoute(flatRm);
      if (extracted.path.isNotEmpty) return extracted;
    }

    final fromDetailKeys = CardFactory.extractItemRoute({
      'router': detail['router'] as String? ?? '',
      'link': detail['link'] as String? ?? '',
    });
    if (fromDetailKeys.path.isNotEmpty) return fromDetailKeys;
  }

  return CardFactory.extractItemRoute({
    'router': card.link?.trim().isNotEmpty == true
        ? '/web'
        : '/tabbar/market/optional',
    'link': card.link ?? '',
  });
}

void _openMarketProduct(
  CardNavigateCallback? onNavigate,
  MarketProductModel p,
) {
  if (p.symbol.isEmpty) return;
  onNavigate?.call('/market/productdetail', {
    'symbol': p.symbol,
  }, action: '行情详情');
}

String _marketName(MarketProductModel p) =>
    p.name.isNotEmpty ? p.name : p.symbol;

String _marketPrice(MarketProductModel p) {
  return p.price != 0 || p.symbol.isNotEmpty
      ? p.price.toStringAsFixed(p.precision)
      : '--';
}

String _unsignedChange(MarketProductModel p) {
  return p.changePercentString.replaceFirst(RegExp(r'^[+-]'), '');
}

(double, double) _marketSparkMinMax(MarketProductModel p) {
  if (p.pointsMin != null &&
      p.pointsMax != null &&
      p.pointsMin! != p.pointsMax!) {
    return (p.pointsMin!, p.pointsMax!);
  }
  if (p.points.length < 2) return (0.0, 1.0);
  var lo = p.points.first;
  var hi = p.points.first;
  for (final v in p.points) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if ((hi - lo).abs() < 1e-9) {
    return (lo - 1, hi + 1);
  }
  return (lo, hi);
}

// ========================== market_2 横向推荐卡 ==========================

class _Market2Carousel extends StatelessWidget {
  final List<MarketProductModel> products;
  final bool isZh;
  final CardNavigateCallback? onNavigate;

  const _Market2Carousel({
    required this.products,
    required this.isZh,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final count = products.length.clamp(0, 6);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemW = ((constraints.maxWidth - 20) / 2.33).floorToDouble();
        return SizedBox(
          height: 164,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final p = products[index];
              return SizedBox(
                width: itemW,
                child: _Market2Cell(
                  product: p,
                  isZh: isZh,
                  onTap: () => _openMarketProduct(onNavigate, p),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Market2Cell extends StatelessWidget {
  final MarketProductModel product;
  final bool isZh;
  final VoidCallback? onTap;

  const _Market2Cell({required this.product, required this.isZh, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final tint = CardTool.priceColor(p.changePercent);
    final minMax = _marketSparkMinMax(p);
    final showSub = isZh && (p.subTitle?.isNotEmpty ?? false);
    final cell = Container(
      height: 148,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? context.adaptivePlaceholderSurface
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _marketName(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveTextPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _MarketProductIcons(
                product: p,
                singleSize: 14,
                pairSize: 14,
                quoteSize: 18,
              ),
            ],
          ),
          if (showSub) ...[
            const SizedBox(height: 2),
            Text(
              p.subTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9A9DA2),
                height: 1.2,
              ),
            ),
          ],
          SizedBox(height: showSub ? 15 : 29),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _marketPrice(p),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.adaptiveTextPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              _ChangeChip(
                text: _unsignedChange(p),
                color: tint,
                isDown: p.changePercent < 0,
                height: 18,
                fontSize: 10,
                iconSize: 10,
                backgroundAlpha: 0.10,
                showDirectionIcon: true,
              ),
            ],
          ),
          const SizedBox(height: 26),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _MarketUpperHalfSparklinePainter(
                points: p.points,
                minY: minMax.$1,
                maxY: minMax.$2,
                color: tint,
                fill: true,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: cell,
      ),
    );
  }
}

// ========================== market_3 左大右双卡 ==========================

class _Market3Layout extends StatelessWidget {
  final List<MarketProductModel> products;
  final double horGap;
  final bool isZh;
  final CardNavigateCallback? onNavigate;

  const _Market3Layout({
    required this.products,
    required this.horGap,
    required this.isZh,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horGap, 0, horGap, 8),
      child: SizedBox(
        height: 200,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final leftW = ((constraints.maxWidth - gap) * 0.55).floorToDouble();
            final rightW = constraints.maxWidth - gap - leftW;
            final rightH = (200 - gap) / 2;
            Widget cardAt(int index, {required bool showChart}) {
              if (index >= products.length) {
                return const SizedBox.shrink();
              }
              final p = products[index];
              return _Market3Cell(
                product: p,
                isZh: isZh,
                showChart: showChart,
                onTap: () => _openMarketProduct(onNavigate, p),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: leftW, child: cardAt(0, showChart: true)),
                const SizedBox(width: gap),
                SizedBox(
                  width: rightW,
                  child: Column(
                    children: [
                      SizedBox(
                        height: rightH,
                        child: cardAt(1, showChart: false),
                      ),
                      const SizedBox(height: gap),
                      SizedBox(
                        height: rightH,
                        child: cardAt(2, showChart: false),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Market3Cell extends StatelessWidget {
  final MarketProductModel product;
  final bool isZh;
  final bool showChart;
  final VoidCallback? onTap;

  const _Market3Cell({
    required this.product,
    required this.isZh,
    required this.showChart,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final tint = CardTool.priceColor(p.changePercent);
    final minMax = _marketSparkMinMax(p);
    final showSub = isZh && (p.subTitle?.isNotEmpty ?? false);
    final cell = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: _MarketProductIcons(
              product: p,
              singleSize: 14,
              pairSize: 14,
              quoteSize: 18,
            ),
          ),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 82,
                  child: Text(
                    _marketName(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.adaptiveTextPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                if (showSub) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.subTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9A9DA2),
                      height: 1.2,
                    ),
                  ),
                ],
                SizedBox(
                  height: showChart ? (showSub ? 20 : 34) : (showSub ? 10 : 22),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _marketPrice(p),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    _ChangeChip(
                      text: _unsignedChange(p),
                      color: tint,
                      isDown: p.changePercent < 0,
                      height: 18,
                      fontSize: 10,
                      iconSize: 10,
                      backgroundAlpha: 0.10,
                      showDirectionIcon: true,
                    ),
                  ],
                ),
                if (showChart) ...[
                  const Spacer(),
                  SizedBox(
                    height: 57,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MarketUpperHalfSparklinePainter(
                        points: p.points,
                        minY: minMax.$1,
                        maxY: minMax.$2,
                        color: tint,
                        fill: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: cell,
      ),
    );
  }
}

// ========================== market_4 白色列表卡 ==========================

class _Market4List extends StatelessWidget {
  final List<MarketProductModel> products;
  final bool isZh;
  final CardNavigateCallback? onNavigate;

  const _Market4List({
    required this.products,
    required this.isZh,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: List.generate(4, (index) {
          final p = index < products.length ? products[index] : null;
          return SizedBox(
            height: 64,
            child: p == null
                ? const SizedBox.shrink()
                : _Market4Row(
                    product: p,
                    isZh: isZh,
                    onTap: () => _openMarketProduct(onNavigate, p),
                  ),
          );
        }),
      ),
    );
  }
}

class _Market4Row extends StatelessWidget {
  final MarketProductModel product;
  final bool isZh;
  final VoidCallback? onTap;

  const _Market4Row({required this.product, required this.isZh, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final tint = CardTool.priceColor(p.changePercent);
    final minMax = _marketSparkMinMax(p);
    final showSub = isZh && (p.subTitle?.isNotEmpty ?? false);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _MarketProductIcons(
            product: p,
            singleSize: 34,
            pairSize: 22,
            quoteSize: 26,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: MediaQuery.sizeOf(context).width > 375 ? 100 : 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _marketName(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveTextPrimary,
                    height: 1.1,
                  ),
                ),
                if (showSub) ...[
                  const SizedBox(height: 6),
                  Text(
                    p.subTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9A9DA2),
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 13),
          SizedBox(
            width: 54,
            height: 24,
            child: CustomPaint(
              painter: _MarketSparklinePainter(
                points: p.points,
                minY: minMax.$1,
                maxY: minMax.$2,
                color: tint,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 78,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _marketPrice(p),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.adaptiveTextPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _ChangeChip(
                  text: p.changePercentString,
                  color: tint,
                  height: 26,
                  minWidth: 71,
                  fontSize: 14,
                  backgroundAlpha: 0,
                  textOnly: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

// ========================== market_5 边框块状列表 ==========================

class _Market5List extends StatelessWidget {
  final List<MarketProductModel> products;
  final bool isZh;
  final CardNavigateCallback? onNavigate;

  const _Market5List({
    required this.products,
    required this.isZh,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(
        children: List.generate(4, (index) {
          final p = index < products.length ? products[index] : null;
          return Padding(
            padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
            child: SizedBox(
              height: 72,
              child: p == null
                  ? const SizedBox.shrink()
                  : _Market5Row(
                      product: p,
                      isZh: isZh,
                      onTap: () => _openMarketProduct(onNavigate, p),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

class _Market5Row extends StatelessWidget {
  final MarketProductModel product;
  final bool isZh;
  final VoidCallback? onTap;

  const _Market5Row({required this.product, required this.isZh, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final tint = CardTool.priceColor(p.changePercent);
    final showSub = isZh && (p.subTitle?.isNotEmpty ?? false);
    final row = Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2F3340)
              : const Color(0xFFECECEC),
        ),
      ),
      child: Row(
        children: [
          _MarketProductIcons(
            product: p,
            singleSize: 40,
            pairSize: 38,
            quoteSize: 22,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _marketName(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveTextPrimary,
                    height: 1.25,
                  ),
                ),
                if (showSub)
                  Text(
                    p.subTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A9DA2),
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 120,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _marketPrice(p),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.adaptiveTextPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _ChangeChip(
                text: p.changePercentString,
                color: tint,
                height: 19,
                minWidth: 52,
                fontSize: 10,
                backgroundAlpha: 0.14,
              ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: row,
      ),
    );
  }
}

// ========================== market_6 双大卡 + 双小卡 ==========================

class _Market6Layout extends StatelessWidget {
  final List<MarketProductModel> products;
  final bool isZh;
  final CardNavigateCallback? onNavigate;

  const _Market6Layout({
    required this.products,
    required this.isZh,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    MarketProductModel? at(int index) =>
        index < products.length ? products[index] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: Row(
              children: [
                Expanded(child: _maybeMarket6Cell(at(0), big: true)),
                const SizedBox(width: 16),
                Expanded(child: _maybeMarket6Cell(at(1), big: true)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 74, child: _maybeMarket6Cell(at(2), big: false)),
          const SizedBox(height: 12),
          SizedBox(height: 74, child: _maybeMarket6Cell(at(3), big: false)),
        ],
      ),
    );
  }

  Widget _maybeMarket6Cell(MarketProductModel? p, {required bool big}) {
    if (p == null) return const SizedBox.expand();
    return _Market6Cell(
      product: p,
      isZh: isZh,
      big: big,
      onTap: () => _openMarketProduct(onNavigate, p),
    );
  }
}

class _Market6Cell extends StatelessWidget {
  final MarketProductModel product;
  final bool isZh;
  final bool big;
  final VoidCallback? onTap;

  const _Market6Cell({
    required this.product,
    required this.isZh,
    required this.big,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final tint = CardTool.priceColor(p.changePercent);
    final minMax = _marketSparkMinMax(p);
    final showSub = isZh && (p.subTitle?.isNotEmpty ?? false);
    final row = Container(
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: big
          ? const EdgeInsets.fromLTRB(8, 20, 8, 20)
          : const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: big
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MarketProductIcons(
                      product: p,
                      singleSize: 32,
                      pairSize: 30,
                      quoteSize: 12,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _marketName(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveTextPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (showSub)
                            Text(
                              p.subTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9A9DA2),
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      p.changePercentString,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tint,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _marketPrice(p),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.adaptiveTextPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: tint.withValues(alpha: 0.10),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _MarketUpperHalfSparklinePainter(
                          points: p.points,
                          minY: minMax.$1,
                          maxY: minMax.$2,
                          color: tint,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _MarketProductIcons(
                  product: p,
                  singleSize: 32,
                  pairSize: 30,
                  quoteSize: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _marketName(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.adaptiveTextPrimary,
                          height: 1.1,
                        ),
                      ),
                      if (showSub)
                        Text(
                          p.subTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9A9DA2),
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 120,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _marketPrice(p),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.adaptiveTextPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      p.changePercentString,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  final String text;
  final Color color;
  final double height;
  final double? minWidth;
  final double fontSize;
  final double iconSize;
  final double backgroundAlpha;
  final bool showDirectionIcon;
  final bool textOnly;
  final bool isDown;

  const _ChangeChip({
    required this.text,
    required this.color,
    required this.height,
    required this.fontSize,
    this.minWidth,
    this.iconSize = 10,
    this.backgroundAlpha = 0.10,
    this.showDirectionIcon = false,
    this.textOnly = false,
    this.isDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showDirectionIcon) ...[
          Icon(
            isDown ? Icons.arrow_downward : Icons.arrow_upward,
            size: iconSize,
            color: color,
          ),
          const SizedBox(width: 2),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: color,
              height: 1,
            ),
          ),
        ),
      ],
    );

    if (textOnly) {
      return SizedBox(
        height: height,
        width: minWidth,
        child: Align(alignment: Alignment.centerRight, child: content),
      );
    }

    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 0),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: content,
    );
  }
}

class _MarketProductIcons extends StatelessWidget {
  final MarketProductModel product;
  final double singleSize;
  final double pairSize;
  final double quoteSize;

  const _MarketProductIcons({
    required this.product,
    required this.singleSize,
    required this.pairSize,
    required this.quoteSize,
  });

  @override
  Widget build(BuildContext context) {
    if (product.isSingleIcon) {
      return _MarketCoin(url: product.icon, size: singleSize);
    }

    final base = (product.currencyBaseIcon ?? product.icon)?.trim();
    final quote = product.currencyProfitIcon?.trim();
    if (quoteSize <= pairSize) {
      return SizedBox(
        width: pairSize,
        height: pairSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _MarketCoin(url: base, size: pairSize),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _MarketCoin(url: quote, size: quoteSize),
            ),
          ],
        ),
      );
    }

    final overlap = pairSize * 0.58;
    return SizedBox(
      width: pairSize + overlap + (quoteSize - pairSize).clamp(0.0, 20.0),
      height: quoteSize > pairSize ? quoteSize : pairSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: ((quoteSize - pairSize) / 2).clamp(0, 20),
            child: _MarketCoin(url: base, size: pairSize),
          ),
          Positioned(
            left: overlap,
            top: 0,
            child: _MarketCoin(
              url: quote,
              size: quoteSize,
              ring: quoteSize > pairSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketCoin extends StatelessWidget {
  final String? url;
  final double size;
  final bool ring;

  const _MarketCoin({required this.url, required this.size, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    final inner = ring ? (size - 4).clamp(6.0, size) : size;
    final image = ClipOval(
      child: u == null || u.isEmpty
          ? Container(
              width: inner,
              height: inner,
              color: const Color(0xFFE8E8E8),
            )
          : Image.network(
              u,
              width: inner,
              height: inner,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: inner,
                height: inner,
                color: const Color(0xFFE8E8E8),
              ),
            ),
    );

    if (!ring) return image;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: image,
    );
  }
}

class _MarketUpperHalfSparklinePainter extends CustomPainter {
  final List<double> points;
  final double minY;
  final double maxY;
  final Color color;
  final bool fill;

  _MarketUpperHalfSparklinePainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.color,
    this.fill = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final range = (maxY - minY).abs();
    final denom = range < 1e-12 ? 1.0 : range;
    final usableH = size.height / 2;

    double normY(double v) {
      final t = ((v - minY) / denom).clamp(0.0, 1.0);
      return (usableH * (1 - t)).clamp(1.0, (usableH - 1).clamp(1.0, usableH));
    }

    final path = Path();
    if (points.length == 1) {
      path
        ..moveTo(0, usableH / 2)
        ..lineTo(size.width, usableH / 2);
    } else {
      for (var i = 0; i < points.length; i++) {
        final x = size.width * i / (points.length - 1);
        final y = normY(points[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(Offset.zero & size);
      canvas.drawPath(fillPath, fillPaint);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarketUpperHalfSparklinePainter oldDelegate) {
    return oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.color != color ||
        oldDelegate.fill != fill ||
        !listEquals(oldDelegate.points, points);
  }
}

// ========================== market_7 宫格布局 ==========================
class _MarketGrid7 extends StatelessWidget {
  final List<MarketProductModel> products;
  final double horGap;
  final CardNavigateCallback? onNavigate;

  const _MarketGrid7({
    required this.products,
    required this.horGap,
    this.onNavigate,
  });

  static const int _columns = 3;
  static const double _crossSpacing = 10;
  static const double _mainSpacing = 10;

  @override
  Widget build(BuildContext context) {
    final showCount = products.length.clamp(0, 6);
    final rows = <Widget>[];

    for (int row = 0; row < showCount; row += _columns) {
      final children = <Widget>[];
      for (int col = 0; col < _columns; col++) {
        final idx = row + col;
        if (col > 0) {
          children.add(const SizedBox(width: _crossSpacing));
        }
        if (idx < showCount) {
          final p = products[idx];
          children.add(
            Expanded(
              child: _MarketGrid7Cell(
                product: p,
                onTap: p.symbol.isNotEmpty
                    ? () => onNavigate?.call('/market/detail', {
                        'symbol': p.symbol,
                      }, action: '行情详情')
                    : null,
              ),
            ),
          );
        } else {
          children.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
      if (row + _columns < showCount) {
        rows.add(const SizedBox(height: _mainSpacing));
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: horGap, right: horGap, bottom: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

class _MarketGrid7Cell extends StatelessWidget {
  final MarketProductModel product;
  final VoidCallback? onTap;

  const _MarketGrid7Cell({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final sparkColor = CardTool.sparklineTrendColor(
      p.points,
      changePercent: p.changePercent,
    );
    final changeColor = CardTool.priceColor(p.changePercent);
    final priceStr = p.price != 0 || p.symbol.isNotEmpty
        ? p.price.toStringAsFixed(p.precision)
        : '--';
    final changeStr = p.changePercentString;
    final name = p.name.isNotEmpty ? p.name : p.symbol;

    final bgGrey = Theme.of(context).brightness == Brightness.dark
        ? context.adaptivePlaceholderSurface
        : const Color(0xFFF4F4F4);

    Widget cell = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 名称
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.adaptiveTextPrimary.withValues(alpha: 0.85),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // 价格
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              priceStr,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.adaptiveTextPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 涨跌幅
          Text(
            changeStr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: changeColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // 迷你走势图
          SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(
              size: const Size(double.infinity, 28),
              painter: _MarketSparklinePainter(
                points: p.points,
                minY: _sparkMinMax(p).$1,
                maxY: _sparkMinMax(p).$2,
                color: sparkColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return cell;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: cell,
      ),
    );
  }

  (double, double) _sparkMinMax(MarketProductModel p) {
    if (p.pointsMin != null &&
        p.pointsMax != null &&
        p.pointsMin! != p.pointsMax!) {
      return (p.pointsMin!, p.pointsMax!);
    }
    if (p.points.length < 2) return (0.0, 1.0);
    var lo = p.points.first;
    var hi = p.points.first;
    for (final v in p.points) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if ((hi - lo).abs() < 1e-9) {
      return (lo - 1, hi + 1);
    }
    return (lo, hi);
  }
}

// ========================== 原有列表行 ==========================

class _MarketOneRow extends StatelessWidget {
  final MarketProductModel? product;
  final double horGap;
  final bool isZh;
  final Color titleColor;
  final VoidCallback? onTap;

  const _MarketOneRow({
    required this.product,
    required this.horGap,
    required this.isZh,
    required this.titleColor,
    this.onTap,
  });

  static const double _sparkW = 50;
  static const double _sparkH = 23;

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p == null) {
      return SizedBox(height: 64, child: Container(color: Colors.transparent));
    }

    final sparkColor = CardTool.sparklineTrendColor(
      p.points,
      changePercent: p.changePercent,
    );
    final pillColor = CardTool.priceColor(p.changePercent);
    final showSub = isZh && (p.subTitle?.isNotEmpty ?? false);

    final minMax = _sparkMinMax(p);
    final priceStr = p.price != 0 || p.symbol.isNotEmpty
        ? p.price.toStringAsFixed(p.precision)
        : '--';

    final row = SizedBox(
      height: 64,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horGap),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final leftW = (constraints.maxWidth * 0.26).clamp(84.0, 128.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: leftW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.name.isNotEmpty ? p.name : p.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          MarketPairIcons.of(p),
                          if (showSub) ...[
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                p.subTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: context.adaptiveTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                CustomPaint(
                  size: const Size(_sparkW, _sparkH),
                  painter: _MarketSparklinePainter(
                    points: p.points,
                    minY: minMax.$1,
                    maxY: minMax.$2,
                    color: sparkColor,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          priceStr,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 68, maxWidth: 88),
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      p.changePercentString,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }

  (double, double) _sparkMinMax(MarketProductModel p) {
    if (p.pointsMin != null &&
        p.pointsMax != null &&
        p.pointsMin! != p.pointsMax!) {
      return (p.pointsMin!, p.pointsMax!);
    }
    if (p.points.length < 2) return (0.0, 1.0);
    var lo = p.points.first;
    var hi = p.points.first;
    for (final v in p.points) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if ((hi - lo).abs() < 1e-9) {
      return (lo - 1, hi + 1);
    }
    return (lo, hi);
  }
}

class _MarketSparklinePainter extends CustomPainter {
  final List<double> points;
  final double minY;
  final double maxY;
  final Color color;

  _MarketSparklinePainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (points.length == 1) {
      final y = size.height * 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    final range = (maxY - minY).abs();
    final denom = range < 1e-12 ? 1.0 : range;

    double normY(double v) {
      final t = ((v - minY) / denom).clamp(0.0, 1.0);
      return size.height - t * size.height * 0.85 - size.height * 0.075;
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = normY(points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarketSparklinePainter oldDelegate) {
    return oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.color != color ||
        !listEquals(oldDelegate.points, points);
  }
}
