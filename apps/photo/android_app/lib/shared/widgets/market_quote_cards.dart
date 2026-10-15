import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/context_adaptive_colors.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/market_product_model.dart';
import '../../features/market/market_tab_config.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/providers/app_events.dart';
import '../../features/market/market_list_ui_prefs.dart';
import 'card_factory.dart';
import 'market_pair_icons.dart';
import 'st_toast.dart';

/// iOS `Cards/*/podspec` 中带 `_1` 后缀的行情组件（自选列表 / 分类 Tab / 分类行情列表）
bool cardStyleIsVariantOne(String style) {
  final i = style.lastIndexOf('_');
  if (i <= 0 || i >= style.length - 1) return false;
  return style.substring(i + 1) == '1';
}

bool cardStyleIsVariantTwo(String style) {
  final i = style.lastIndexOf('_');
  if (i <= 0 || i >= style.length - 1) return false;
  return style.substring(i + 1) == '2';
}

/// `selfmarket_1` / `selfmarket_2`（对齐 iOS + Figma `1:1956` 无自选宫格）：未加自选 →「自选推荐」宫格 + 一键添加；已加自选 → 表头 + 列表 + 涨跌胶囊。
class SelfMarketCardTwo extends ConsumerStatefulWidget {
  final ConfigCardItemData cardData;
  final CardNavigateCallback? onNavigate;
  final Map<String, dynamic>? dataCache;

  const SelfMarketCardTwo({
    super.key,
    required this.cardData,
    this.onNavigate,
    this.dataCache,
  });

  @override
  ConsumerState<SelfMarketCardTwo> createState() => _SelfMarketCardTwoState();
}

class _SelfMarketCardTwoState extends ConsumerState<SelfMarketCardTwo> {
  static const Color _figmaFlatPill = Color(0xFF949494);
  static const Color _ctaGreen = Color(0xFF00B57A);
  static const Color _ctaBlack = Color(0xFF000000);

  /// selfmarket_2：稿中 2×4 宫格最多 8 个；selfmarket_1 对齐 iOS `kSelfmarket1GridPageSize = 10`
  static const int _kSelfMarket2GridSlots = 8;
  static const int _kSelfMarket1GridSlots = 10;
  static const double _kFigmaGridGap = 12;
  static const double _kFigmaCellH = 80;
  static const double _kFigmaCellRadius = 8;
  static const Map<String, String> _cardFallbackText = {
    'self_recommendation_title': '自选推荐',
    'change_batch': '换一批',
    'add_with_one_click': '一键添加',
    'column_name': '名称',
    'column_last_price': '最新价',
    'column_24h_change': '24H',
    'list_header_latest_price': '最新价',
    'list_header_24h_change': '24H 涨跌幅',
    'list_header_sell': '卖出价',
    'list_header_spread': '点差',
    'list_header_buy': '买入价',
  };
  static const Map<String, String> _globalFallbackText = {
    'add_stock_null_tips': '暂无自选品种',
    'add_success': '添加成功',
    'no_data': '暂无数据',
    'select_please': '请选择',
    'requestfail': '请求失败',
  };
  static const Map<String, String> _fallbackText = {
    ..._cardFallbackText,
    ..._globalFallbackText,
  };

  final Set<String> _selected = {};
  int _batchOffset = 0;
  int _sortKey = 0;
  int _sortSign = 1;
  bool _submitting = false;
  String? _selectionBatchKey;

  /// 对齐 iOS `STMarketManager` / `Selfmarket1CardView` 全局列表开关
  bool _listKlineSwitch = true;
  bool _listStyleSwitch = false;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedResourceKey;

  bool get _isVariantOne => cardStyleIsVariantOne(widget.cardData.cardStyle);

  int get _gridPageSize =>
      _isVariantOne ? _kSelfMarket1GridSlots : _kSelfMarket2GridSlots;

  Color get _ctaColor => _isVariantOne ? _ctaBlack : _ctaGreen;

  String _cacheKey() =>
      '${widget.cardData.cardStyle}_${widget.cardData.cardId}';

  @override
  void initState() {
    super.initState();
    _loadMarketListPrefs();
  }

  Future<void> _loadMarketListPrefs() async {
    final k = await MarketListUiPrefs.readListKlineSwitch();
    final s = await MarketListUiPrefs.readListStyleSwitch();
    if (!mounted) return;
    setState(() {
      _listKlineSwitch = k;
      _listStyleSwitch = s;
    });
  }

  Future<void> _toggleListKline() async {
    final v = !_listKlineSwitch;
    setState(() => _listKlineSwitch = v);
    await MarketListUiPrefs.writeListKlineSwitch(v);
  }

  Future<void> _toggleListStyle() async {
    final v = !_listStyleSwitch;
    setState(() => _listStyleSwitch = v);
    await MarketListUiPrefs.writeListStyleSwitch(v);
  }

  @override
  void didUpdateWidget(covariant SelfMarketCardTwo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardData.cardId != widget.cardData.cardId ||
        oldWidget.cardData.cardStyle != widget.cardData.cardStyle) {
      _selected.clear();
      _batchOffset = 0;
    } else if (oldWidget.dataCache?[_cacheKey()] !=
        widget.dataCache?[_cacheKey()]) {
      _batchOffset = 0;
      _selected.clear();
      final pool = _parseProducts().where((p) => !p.inOptional).toList();
      _selectAllVisible(_batchVisible(pool));
    }
  }

  List<SelfMarketProductModel> _parseProducts() {
    final raw = widget.dataCache?[_cacheKey()];
    final out = <SelfMarketProductModel>[];
    if (raw is Map && raw['products'] is List) {
      for (final e in raw['products'] as List) {
        if (e is SelfMarketProductModel) {
          out.add(e);
        } else if (e is Map<String, dynamic>) {
          out.add(SelfMarketProductModel.fromJson(e));
        }
      }
    }
    return out;
  }

  static String _formatPrice(SelfMarketProductModel p) {
    final d = p.precision.clamp(0, 8);
    if (d == 0) return NumberFormat('#,###', 'en_US').format(p.price);
    final zeros = List.filled(d, '0').join();
    return NumberFormat('#,##0.$zeros', 'en_US').format(p.price);
  }

  static ({String base, String quote}) _pairLines(SelfMarketProductModel p) {
    final s = p.symbol.trim();
    if (s.contains('/')) {
      final parts = s.split('/');
      final b = CardTool.hqSymbolTitleLine(parts[0].trim(), p.name);
      final q = parts.length > 1 ? parts[1].trim().toUpperCase() : 'USDT';
      return (base: b, quote: '/ $q');
    }
    final b = CardTool.hqSymbolTitleLine(s, p.name);
    return (base: b, quote: '/ USDT');
  }

  static Color _pillBg(num pct) {
    if (pct > 0) return CardTool.priceColor(1);
    if (pct < 0) return CardTool.priceColor(-1);
    return _figmaFlatPill;
  }

  List<SelfMarketProductModel> _sortedRows(List<SelfMarketProductModel> rows) {
    final copy = [...rows];
    int cmp(SelfMarketProductModel a, SelfMarketProductModel b) {
      if (_sortKey == 0) {
        final sa = _pairLines(a).base;
        final sb = _pairLines(b).base;
        return sa.compareTo(sb) * _sortSign;
      }
      if (_sortKey == 1) {
        return a.price.compareTo(b.price) * _sortSign;
      }
      return a.changePercent.compareTo(b.changePercent) * _sortSign;
    }

    copy.sort(cmp);
    return copy;
  }

  void _onSortHeaderTap(int key) {
    setState(() {
      if (_sortKey == key) {
        _sortSign = -_sortSign;
      } else {
        _sortKey = key;
        _sortSign = 1;
      }
    });
  }

  Widget _sortHint(BuildContext context, int key) {
    final active = _sortKey == key;
    return Icon(
      active
          ? (_sortSign > 0 ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.unfold_more,
      size: 12,
      color: active ? context.adaptiveTextTertiary : context.adaptiveTextHint,
    );
  }

  List<SelfMarketProductModel> _batchVisible(
    List<SelfMarketProductModel> pool,
  ) {
    if (pool.isEmpty) return [];
    final n = pool.length;
    final take = min(_gridPageSize, n);
    return List.generate(take, (i) => pool[(_batchOffset + i) % n]);
  }

  void _selectAllVisible(List<SelfMarketProductModel> visible) {
    _selected
      ..clear()
      ..addAll(visible.map((p) => p.symbol));
  }

  Future<void> _onAddBatch() async {
    if (_submitting) return;
    final isLogin = ref.read(userStateProvider).isLogin;
    if (!isLogin) {
      widget.onNavigate?.call('/login', null);
      return;
    }
    final items = _parseProducts();
    final pool = items.where((p) => !p.inOptional).toList();
    final visible = _batchVisible(pool);
    final visibleSyms = visible.map((p) => p.symbol).toSet();
    final symbols = _selected.where(visibleSyms.contains).toList();
    if (symbols.isEmpty) {
      STToast.show(context, _t('select_please'));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(stServiceProvider).addToWatchlist(symbols);
      if (!mounted) return;
      _selected.clear();
      notifyWatchlistChanged(ref);
      STToast.show(context, _t('add_success'));
    } catch (e) {
      if (mounted) {
        STToast.show(
          context,
          '${_t('requestfail')}: ${stUserVisibleErrorMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    final resourceKey = '$languageCode:${widget.cardData.cardStyle}';
    if (_localizedResourceKey == resourceKey) return;
    _localizedResourceKey = resourceKey;
    _localizedText = _fallbackText;
    Future.wait([
      ..._cardFallbackText.entries.map((entry) async {
        final value = await _localizedCardText(
          localizations,
          entry.key,
          fallback: entry.value,
        );
        return MapEntry(entry.key, value);
      }),
      ..._globalFallbackText.entries.map((entry) async {
        final value = await localizations.text(
          entry.key,
          fallback: entry.value,
        );
        return MapEntry(entry.key, value);
      }),
    ]).then((entries) {
      if (!mounted || _localizedResourceKey != resourceKey) return;
      setState(() {
        _localizedText = Map<String, String>.fromEntries(entries);
      });
    });
  }

  Future<String> _localizedCardText(
    STLocalizations localizations,
    String key, {
    required String fallback,
  }) async {
    final cardNames = <String>[
      widget.cardData.cardStyle,
      'selfmarket_2',
      'categorymarket_2',
      'categorymarket_1',
    ];
    for (final cardName in cardNames.toSet()) {
      final value = await localizations.cardText(
        cardName,
        key,
        fallback: fallback,
      );
      if (value != fallback || localizations.languageCode.startsWith('zh')) {
        return value;
      }
    }
    return fallback;
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    final mgr = ref.watch(configDataManagerProvider);
    final hor = mgr.cardHorGap;
    final ver = mgr.cardVerGap;
    final corner = mgr.cardCorner.clamp(8.0, 20.0);

    final isLogin = ref.watch(userStateProvider.select((s) => s.isLogin));
    final items = _parseProducts();
    final opted = items.where((p) => p.inOptional).toList();
    final useListMode = isLogin && opted.isNotEmpty;
    final listRows = useListMode ? _sortedRows(opted) : items;

    final pool = items.where((p) => !p.inOptional).toList();
    final visibleGrid = useListMode
        ? <SelfMarketProductModel>[]
        : _batchVisible(pool);

    if (!useListMode && visibleGrid.isNotEmpty) {
      final batchKey =
          '$_batchOffset:${visibleGrid.map((p) => p.symbol).join(',')}';
      if (batchKey != _selectionBatchKey) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _selectionBatchKey = batchKey;
            _selectAllVisible(visibleGrid);
          });
        });
      }
    }

    final moreRoute = CardFactory.extractItemRoute({
      'router': widget.cardData.link?.isNotEmpty == true
          ? '/web'
          : '/tabbar/market/optional',
      'link': widget.cardData.link ?? '',
    });

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hor, vertical: 8),
      child: useListMode
          ? (_isVariantOne
                ? _buildVariantOneListBody(context, listRows, moreRoute)
                : _buildListBody(context, listRows, moreRoute))
          : _buildGridBody(
              context,
              visibleGrid,
              pool,
              ver,
              corner,
              moreRoute,
              isLogin,
            ),
    );
  }

  /// selfmarket_1 已加自选：表头工具栏 + 迷你线列表（对齐 iOS `Selfmarket1CardView` 列表态）
  Widget _buildVariantOneListBody(
    BuildContext context,
    List<SelfMarketProductModel> rows,
    ({String path, Map<String, dynamic>? params}) moreRoute,
  ) {
    const iconColor = Color(0xFF343434);
    final chartAccent = _listKlineSwitch ? iconColor : const Color(0xFF1BCC83);
    final styleAccent = _listStyleSwitch ? iconColor : const Color(0xFF1BCC83);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleListStyle,
              child: Icon(
                _listStyleSwitch
                    ? Icons.grid_view_rounded
                    : Icons.table_rows_rounded,
                size: 22,
                color: styleAccent,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleListKline,
              child: Icon(
                Icons.show_chart_rounded,
                size: 22,
                color: chartAccent,
              ),
            ),
            const Spacer(),
            Text(
              widget.cardData.title ?? _t('self_recommendation_title'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const Spacer(),
            if (moreRoute.path.isNotEmpty)
              GestureDetector(
                onTap: () =>
                    widget.onNavigate?.call(moreRoute.path, moreRoute.params),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                _t('column_name'),
                style: TextStyle(
                  fontSize: 12,
                  color: context.adaptiveTextTertiary,
                ),
              ),
            ),
            if (_listKlineSwitch) const SizedBox(width: 50),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_listStyleSwitch) ...[
                    Text(
                      _t('list_header_latest_price'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Text(
                      _t('list_header_24h_change'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _t('list_header_sell'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _t('list_header_spread'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _t('list_header_buy'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                _t('add_stock_null_tips'),
                style: TextStyle(
                  color: context.adaptiveTextTertiary,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...rows.map(
            (p) => _variantOneListRow(
              context,
              p,
              showSparkline: _listKlineSwitch,
              showBuySell: _listStyleSwitch,
            ),
          ),
      ],
    );
  }

  Widget _variantOneListRow(
    BuildContext context,
    SelfMarketProductModel p, {
    required bool showSparkline,
    required bool showBuySell,
  }) {
    final sym = p.symbol.isNotEmpty ? p.symbol : p.name;
    final pct = p.changePercent;
    final pillColor = _pillBg(pct);
    final priceStr = _formatPrice(p);

    return InkWell(
      onTap: () => widget.onNavigate?.call('/market/detail', {'symbol': sym}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CardTool.hqSymbolTitleLine(sym, p.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      MarketPairIcons(
                        isSingleIcon: p.isSingleIcon,
                        icon: p.icon,
                        currencyBaseIcon: p.currencyBaseIcon,
                        currencyProfitIcon: p.currencyProfitIcon,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showSparkline && p.points.length >= 2)
              SizedBox(
                width: 50,
                height: 23,
                child: CustomPaint(
                  painter: _SparkPainter(
                    p.points,
                    pct > 0
                        ? CardTool.priceColor(1)
                        : (pct < 0 ? CardTool.priceColor(-1) : _figmaFlatPill),
                    fillUnder: pct > 0,
                  ),
                ),
              ),
            if (showSparkline && p.points.length >= 2) const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: showBuySell
                    ? [
                        Text(
                          p.sell.toStringAsFixed(p.precision),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.spread.toStringAsFixed(p.precision),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.adaptiveTextTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.buy.toStringAsFixed(p.precision),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                      ]
                    : [
                        Text(
                          priceStr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pillColor,
                            borderRadius: BorderRadius.circular(
                              pct > 0 ? 3 : 5,
                            ),
                          ),
                          child: Text(
                            '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBody(
    BuildContext context,
    List<SelfMarketProductModel> visible,
    List<SelfMarketProductModel> pool,
    double ver,
    double corner,
    ({String path, Map<String, dynamic>? params}) moreRoute,
    bool isLogin,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              widget.cardData.title ?? _t('self_recommendation_title'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 24 / 14,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (pool.isEmpty) return;
                setState(() {
                  final n = pool.length;
                  final step = n <= _gridPageSize ? n : _gridPageSize;
                  _batchOffset = (_batchOffset + step) % max(n, 1);
                  _selectAllVisible(_batchVisible(pool));
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 11,
                    color: context.adaptiveTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _t('change_batch'),
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w400,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (moreRoute.path.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    widget.onNavigate?.call(moreRoute.path, moreRoute.params),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (pool.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                _t('no_data'),
                style: TextStyle(
                  color: context.adaptiveTextTertiary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cellW = (w - _kFigmaGridGap) / 2;
              final cellH = _isVariantOne ? 102.0 : _kFigmaCellH;
              final aspect = cellW / cellH;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: _kFigmaGridGap,
                mainAxisSpacing: _kFigmaGridGap,
                childAspectRatio: aspect,
                children: visible
                    .map(
                      (p) => _isVariantOne
                          ? _buildSelfMarket1RecommendTile(context, p)
                          : _buildSelfMarketFigmaRecommendTile(context, p),
                    )
                    .toList(),
              );
            },
          ),
        if (pool.isNotEmpty) ...[
          SizedBox(height: ver + 4),
          Center(
            child: SizedBox(
              width: _isVariantOne ? 250 : 250,
              height: _isVariantOne ? 44 : 42,
              child: FilledButton(
                onPressed: (_submitting || !_hasGridSelection(visible))
                    ? null
                    : _onAddBatch,
                style: FilledButton.styleFrom(
                  backgroundColor: _ctaColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _ctaColor.withValues(alpha: 0.3),
                  disabledForegroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  textStyle: TextStyle(
                    fontSize: _isVariantOne ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    height: _isVariantOne ? 1.2 : 24 / 16,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_t('add_with_one_click')),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _hasGridSelection(List<SelfMarketProductModel> visible) {
    final syms = visible.map((p) => p.symbol).toSet();
    return _selected.any(syms.contains);
  }

  /// selfmarket_1 推荐宫格：交易对 + 图标 + 价格 + 涨跌幅 + 圆形勾选（对齐 iOS `Selfmarket1GridCell`）
  Widget _buildSelfMarket1RecommendTile(
    BuildContext context,
    SelfMarketProductModel p,
  ) {
    final sym = p.symbol;
    final checked = _selected.contains(sym);
    final pctColor = CardTool.iosHqListLegibleChangeColor(p.changePercent);
    final priceStr = p.price != 0 || sym.isNotEmpty
        ? p.price.toStringAsFixed(p.precision)
        : '--';

    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onNavigate?.call('/market/detail', {'symbol': sym}),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      CardTool.hqSymbolTitleLine(sym, p.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (checked) {
                          _selected.remove(sym);
                        } else {
                          _selected.add(sym);
                        }
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: checked
                            ? const Color(0xFF1BCC83)
                            : Colors.transparent,
                        border: Border.all(
                          color: checked
                              ? const Color(0xFF1BCC83)
                              : const Color(0xFFD0D0D0),
                          width: 1.5,
                        ),
                      ),
                      child: checked
                          ? const Icon(
                              Icons.check,
                              size: 13,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  MarketPairIcons(
                    isSingleIcon: p.isSingleIcon,
                    icon: p.icon,
                    currencyBaseIcon: p.currencyBaseIcon,
                    currencyProfitIcon: p.currencyProfitIcon,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9A9DA2),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      priceStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  Text(
                    '${p.changePercent >= 0 ? '+' : ''}${p.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: pctColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Figma `1:1956` 推荐宫格单格：左交易对 + 下中文名，右侧勾选。
  Widget _buildSelfMarketFigmaRecommendTile(
    BuildContext context,
    SelfMarketProductModel p,
  ) {
    final sym = p.symbol;
    final pair = _pairLines(p);
    final checked = _selected.contains(sym);
    final t1 = context.adaptiveTextPrimary;
    final t3 = context.adaptiveTextSecondary;
    return Material(
      color: context.adaptiveMutedBlock,
      borderRadius: BorderRadius.circular(_kFigmaCellRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            if (checked) {
              _selected.remove(sym);
            } else {
              _selected.add(sym);
            }
          });
        },
        child: SizedBox(
          height: _kFigmaCellH,
          child: Stack(
            children: [
              Positioned(
                left: 16,
                right: 44,
                top: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 20 / 14,
                          color: t1,
                        ),
                        children: [
                          TextSpan(text: pair.base),
                          TextSpan(
                            text: pair.quote,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              height: 20 / 14,
                              color: t1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.name.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 15 / 12,
                          color: t3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(child: _squareCheckbox(context, checked)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _squareCheckbox(BuildContext context, bool checked) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) {
      return SizedBox(
        width: 18,
        height: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: checked ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: checked ? Colors.black : const Color(0xFFECECEC),
              width: 1,
            ),
          ),
          child: checked
              ? const Center(
                  child: Icon(Icons.check, size: 12, color: Colors.white),
                )
              : null,
        ),
      );
    }
    final on = context.adaptiveTextPrimary;
    final off = context.adaptiveCard;
    final border = context.adaptiveHairline;
    return SizedBox(
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: checked ? on : off,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: checked ? on : border, width: 1),
        ),
        child: checked
            ? Center(child: Icon(Icons.check, size: 12, color: off))
            : null,
      ),
    );
  }

  Widget _buildListBody(
    BuildContext context,
    List<SelfMarketProductModel> rows,
    ({String path, Map<String, dynamic>? params}) moreRoute,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _onSortHeaderTap(0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('column_name'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    _sortHint(context, 0),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: InkWell(
                onTap: () => _onSortHeaderTap(1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _t('column_last_price'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    _sortHint(context, 1),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 88,
              child: InkWell(
                onTap: () => _onSortHeaderTap(2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _t('column_24h_change'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    _sortHint(context, 2),
                  ],
                ),
              ),
            ),
            if (moreRoute.path.isNotEmpty)
              GestureDetector(
                onTap: () =>
                    widget.onNavigate?.call(moreRoute.path, moreRoute.params),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        Divider(height: 20, thickness: 0.5, color: context.adaptiveDivider),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                _t('add_stock_null_tips'),
                style: TextStyle(
                  color: context.adaptiveTextTertiary,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...rows.map((p) => _listRow(context, p)),
      ],
    );
  }

  Widget _listRow(BuildContext context, SelfMarketProductModel p) {
    final sym = p.symbol.isNotEmpty ? p.symbol : p.name;
    final pair = _pairLines(p);
    final pct = p.changePercent;
    final tPrimary = context.adaptiveTextPrimary;
    final tSub = context.adaptiveTextSecondary;
    return InkWell(
      onTap: () => widget.onNavigate?.call('/market/detail', {'symbol': sym}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MarketPairIcons(
              isSingleIcon: p.isSingleIcon,
              icon: p.icon,
              currencyBaseIcon: p.currencyBaseIcon,
              currencyProfitIcon: p.currencyProfitIcon,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pair.base,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    pair.quote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: tSub,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                _formatPrice(p),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: tPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _pillBg(pct),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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

/// `category_1`：横向分类，联动全局 `selectedCategorySymbolGroup`
class CategoryTabsCardOne extends ConsumerStatefulWidget {
  final ConfigCardItemData cardData;

  /// 选中分类后触发：重新拉取 `categorymarket_*` 卡片数据
  final Future<void> Function()? onReloadCategoryMarket;

  const CategoryTabsCardOne({
    super.key,
    required this.cardData,
    this.onReloadCategoryMarket,
  });

  @override
  ConsumerState<CategoryTabsCardOne> createState() =>
      _CategoryTabsCardOneState();
}

class _CategoryTabsCardOneState extends ConsumerState<CategoryTabsCardOne> {
  static const double _kContentHeight = 40;
  static const double _kLeadingInset = 14;
  static const double _kTrailingPad = 8;
  static const double _kTabSpacing = 34;
  static const double _kTitleFontSize = 16;
  static const double _kIndicatorWidth = 24;
  static const double _kIndicatorHeight = 4;
  static const Color _kLightSelectedTitle = Color(0xFF000000);
  static const Color _kLightNormalTitle = Color(0xFF60656D);
  static const Color _kDarkSelectedTitle = Color(0xFFFFFFFF);
  static const Color _kDarkNormalTitle = Color(0xFF9A9DA2);

  List<Map<String, dynamic>> _items() {
    final raw = widget.cardData.cardDetail?['items'] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncSelectionFromManager();
    });
  }

  @override
  void didUpdateWidget(covariant CategoryTabsCardOne oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardData.cardId != widget.cardData.cardId ||
        oldWidget.cardData.cardDetail != widget.cardData.cardDetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _syncSelectionFromManager();
      });
    }
  }

  Future<void> _syncSelectionFromManager() async {
    final mgr = ref.read(configDataManagerProvider);
    final items = _items();
    if (items.isEmpty) return;
    final g = mgr.selectedCategorySymbolGroup;
    for (var i = 0; i < items.length; i++) {
      final gi = MarketTabShellConfig.categoryItemSymbolGroup(items[i]);
      if (gi >= 0 && gi == g) {
        return;
      }
    }
    if (g < 0) {
      final first = MarketTabShellConfig.categoryItemSymbolGroup(items[0]);
      if (first >= 0) {
        ref
            .read(configDataManagerProvider)
            .applyCategorySymbolGroupSelection(first);
        await widget.onReloadCategoryMarket?.call();
      }
    } else {
      final first = MarketTabShellConfig.categoryItemSymbolGroup(items[0]);
      if (first >= 0 && first != g) {
        ref
            .read(configDataManagerProvider)
            .applyCategorySymbolGroupSelection(first);
        await widget.onReloadCategoryMarket?.call();
      }
    }
  }

  int _indexForGroup(int g, List<Map<String, dynamic>> items) {
    if (g < 0) return 0;
    for (var i = 0; i < items.length; i++) {
      if (MarketTabShellConfig.categoryItemSymbolGroup(items[i]) == g) return i;
    }
    return 0;
  }

  Color _selectedTitleColor(BuildContext context) {
    if ((widget.cardData.bgColor ?? '').isNotEmpty) {
      return _kLightSelectedTitle;
    }
    return Theme.of(context).brightness == Brightness.dark
        ? _kDarkSelectedTitle
        : _kLightSelectedTitle;
  }

  Color _normalTitleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _kDarkNormalTitle
        : _kLightNormalTitle;
  }

  String _titleForItem(Map<String, dynamic> item) {
    return item['title']?.toString() ?? item['name']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final g = ref.watch(
      configDataManagerProvider.select((m) => m.selectedCategorySymbolGroup),
    );
    final selectedIndex = _indexForGroup(g, items);
    final selectedTitleColor = _selectedTitleColor(context);
    final normalTitleColor = _normalTitleColor(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);

    return SizedBox(
      height: _kContentHeight + hairline,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          left: _kLeadingInset,
          right: _kTrailingPad,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(width: _kTabSpacing),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final gi = MarketTabShellConfig.categoryItemSymbolGroup(
                    items[index],
                  );
                  if (gi < 0) return;
                  ref
                      .read(configDataManagerProvider)
                      .applyCategorySymbolGroupSelection(gi);
                  await widget.onReloadCategoryMarket?.call();
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _titleForItem(items[index]),
                      style: TextStyle(
                        fontSize: _kTitleFontSize,
                        fontWeight: index == selectedIndex
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: index == selectedIndex
                            ? selectedTitleColor
                            : normalTitleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: _kIndicatorWidth,
                      height: _kIndicatorHeight,
                      decoration: BoxDecoration(
                        color: index == selectedIndex
                            ? selectedTitleColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `categorymarket_1`：分类下的品种列表 + 迷你走势（sparkline）
/// 样式对齐 Figma `3585:294`；默认折叠展示前 [_kPreviewRows] 条，可展开 / 「加载更多」与 iOS 分页一致。
class CategoryMarketCardOne extends ConsumerStatefulWidget {
  final ConfigCardItemData cardData;
  final CardNavigateCallback? onNavigate;
  final Map<String, dynamic>? dataCache;
  final VoidCallback? onLoadMore;

  const CategoryMarketCardOne({
    super.key,
    required this.cardData,
    this.onNavigate,
    this.dataCache,
    this.onLoadMore,
  });

  @override
  ConsumerState<CategoryMarketCardOne> createState() =>
      _CategoryMarketCardOneState();
}

class _CategoryMarketCardOneState extends ConsumerState<CategoryMarketCardOne> {
  static const int _kPreviewRows = 5;

  static const Color _kUp = Color(0xFF1BCC83);
  static const Color _kDown = Color(0xFFF95959);
  static const Color _kFlat = Color(0xFF949494);
  static const Map<String, String> _fallbackText = {
    'loading': '加载中..',
    'no_data': '暂无数据',
    'open': '展开',
    'pack_up': '收起',
    'pull_up_to_load_more': '加载更多',
  };

  bool _expanded = false;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  String _cacheKey() =>
      '${widget.cardData.cardStyle}_${widget.cardData.cardId}';

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    localizations.textMap(_fallbackText).then((text) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = text;
      });
    });
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  @override
  void didUpdateWidget(covariant CategoryMarketCardOne oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardData.cardId != widget.cardData.cardId ||
        oldWidget.cardData.cardStyle != widget.cardData.cardStyle) {
      _expanded = false;
    }
  }

  static int _trendDir(List<double> pts, num changePercent) {
    if (pts.length >= 2) {
      final d = pts.last - pts.first;
      if (d > 1e-9) return 1;
      if (d < -1e-9) return -1;
    }
    if (changePercent > 1e-9) return 1;
    if (changePercent < -1e-9) return -1;
    return 0;
  }

  static Color _trendColor(List<double> pts, num changePercent) {
    final d = _trendDir(pts, changePercent);
    if (d > 0) return _kUp;
    if (d < 0) return _kDown;
    return _kFlat;
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    final raw = widget.dataCache?[_cacheKey()];
    List<CategoryMarketProductModel> items = [];
    if (raw is Map && raw['products'] is List) {
      for (final e in (raw['products'] as List)) {
        if (e is CategoryMarketProductModel) {
          items.add(e);
        } else if (e is Map<String, dynamic>) {
          items.add(CategoryMarketProductModel.fromJson(e));
        }
      }
    }

    final mgr = ref.watch(configDataManagerProvider);
    final showToggle = items.length > _kPreviewRows;
    final visible = _expanded || !showToggle
        ? items
        : items.take(_kPreviewRows).toList();

    final title = widget.cardData.title?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(title, style: CardTool.titleStyle),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  mgr.categoryMarketLoading ? _t('loading') : _t('no_data'),
                  style: TextStyle(color: context.adaptiveTextTertiary),
                ),
              ),
            )
          else
            ...visible.map<Widget>((p) => _buildRow(context, p)),
          if (showToggle)
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? _t('pack_up') : _t('open')),
              ),
            ),
          if (mgr.categoryMarketHasMore &&
              items.isNotEmpty &&
              widget.onLoadMore != null)
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(120, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: mgr.categoryMarketLoading ? null : widget.onLoadMore,
                child: Text(
                  mgr.categoryMarketLoading
                      ? _t('loading')
                      : _t('pull_up_to_load_more'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, CategoryMarketProductModel p) {
    final cp = p.changePercent;
    final sym = p.symbol.isNotEmpty ? p.symbol : p.name;
    final spark = p.sparklinePrices;
    final sparkColor = _trendColor(spark, cp);
    final fillUnder = _trendDir(spark, cp) > 0;

    Color badgeBg;
    BorderRadius badgeRadius;
    if (cp > 1e-9) {
      badgeBg = _kUp;
      badgeRadius = BorderRadius.circular(3);
    } else if (cp < -1e-9) {
      badgeBg = _kDown;
      badgeRadius = BorderRadius.circular(5);
    } else {
      badgeBg = _kFlat;
      badgeRadius = BorderRadius.circular(5);
    }

    final prec = p.precision.clamp(0, 8);
    final priceStr = p.price.toStringAsFixed(prec);
    final changeAbs = p.change.toStringAsFixed(prec.clamp(2, 5));
    final changeLine = '${p.change >= 0 ? '+' : ''}$changeAbs';

    final nameLine = p.name.isNotEmpty ? p.name : (p.subTitle ?? '');
    final tMain = context.adaptiveTextPrimary;
    final tSub = context.adaptiveTextSecondary;

    return InkWell(
      onTap: () => widget.onNavigate?.call('/market/detail', {'symbol': sym}),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.adaptiveDivider, width: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sym,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tMain,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        MarketPairIcons.category(p, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nameLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: tSub,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                height: 26,
                child: CustomPaint(
                  painter: _SparkPainter(
                    spark,
                    sparkColor,
                    fillUnder: fillUnder,
                    fillBaseColor: sparkColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      priceStr,
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tMain,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 78,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: badgeRadius,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${cp >= 0 ? '+' : ''}${cp.toStringAsFixed(2)}%',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        changeLine,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          color: tSub,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `categorymarket_2`：分类行情排序表格。
///
/// 对齐 iOS `Categorymarket2CardView`：16 高排序表头、56 高透明列表行、三列循环排序。
class CategoryMarketCardTwo extends ConsumerStatefulWidget {
  final ConfigCardItemData cardData;
  final CardNavigateCallback? onNavigate;
  final Map<String, dynamic>? dataCache;

  const CategoryMarketCardTwo({
    super.key,
    required this.cardData,
    this.onNavigate,
    this.dataCache,
  });

  @override
  ConsumerState<CategoryMarketCardTwo> createState() =>
      _CategoryMarketCardTwoState();
}

enum _CategoryMarket2SortColumn { none, name, price, zdf }

class _CategoryMarketCardTwoState extends ConsumerState<CategoryMarketCardTwo> {
  static const _fallbackText = {
    'column_name': '名称',
    'column_last_price': '最新价',
    'column_24h_change': '24H',
  };

  _CategoryMarket2SortColumn _sortColumn = _CategoryMarket2SortColumn.none;
  bool _sortAscending = true;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  String _cacheKey() =>
      '${widget.cardData.cardStyle}_${widget.cardData.cardId}';

  void _cycleSort(_CategoryMarket2SortColumn column) {
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
      } else {
        _sortAscending = !_sortAscending;
      }
    });
  }

  List<CategoryMarketProductModel> _items() {
    final raw = widget.dataCache?[_cacheKey()];
    final items = <CategoryMarketProductModel>[];
    if (raw is Map && raw['products'] is List) {
      for (final e in raw['products'] as List) {
        if (e is CategoryMarketProductModel) {
          items.add(e);
        } else if (e is Map<String, dynamic>) {
          items.add(CategoryMarketProductModel.fromJson(e));
        }
      }
    }

    if (_sortColumn == _CategoryMarket2SortColumn.none) {
      return items;
    }

    final sorted = [...items];
    sorted.sort((a, b) {
      int result;
      switch (_sortColumn) {
        case _CategoryMarket2SortColumn.name:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _CategoryMarket2SortColumn.price:
          result = a.price.compareTo(b.price);
          break;
        case _CategoryMarket2SortColumn.zdf:
          result = a.changePercent.compareTo(b.changePercent);
          break;
        case _CategoryMarket2SortColumn.none:
          result = 0;
          break;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    Future.wait(
      _fallbackText.entries.map((entry) async {
        final value = await localizations.cardText(
          'categorymarket_2',
          entry.key,
          fallback: entry.value,
        );
        return MapEntry(entry.key, value);
      }),
    ).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = Map<String, String>.fromEntries(entries);
      });
    });
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final riseAndFallType = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseAndFallType);
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    final items = _items();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _CategoryMarket2HeaderButton(
                  label: _t('column_name'),
                  active: _sortColumn == _CategoryMarket2SortColumn.name,
                  ascending: _sortAscending,
                  onTap: () => _cycleSort(_CategoryMarket2SortColumn.name),
                ),
                const Spacer(),
                _CategoryMarket2HeaderButton(
                  label: _t('column_last_price'),
                  active: _sortColumn == _CategoryMarket2SortColumn.price,
                  ascending: _sortAscending,
                  onTap: () => _cycleSort(_CategoryMarket2SortColumn.price),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 64,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _CategoryMarket2HeaderButton(
                      label: _t('column_24h_change'),
                      active: _sortColumn == _CategoryMarket2SortColumn.zdf,
                      ascending: _sortAscending,
                      onTap: () => _cycleSort(_CategoryMarket2SortColumn.zdf),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(
          (p) => SizedBox(
            height: 56,
            child: _CategoryMarket2Row(
              product: p,
              onTap: () {
                final symbol = p.symbol.isNotEmpty ? p.symbol : p.name;
                if (symbol.isEmpty) return;
                widget.onNavigate?.call('/market/productdetail', {
                  'symbol': symbol,
                }, action: '分类行情详情');
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CategoryMarket2HeaderButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  const _CategoryMarket2HeaderButton({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    var asset = 'assets/images/categoty_market_sort_normal.png';
    if (active) {
      asset = ascending
          ? (dark
                ? 'assets/images/categoty_market_sort_ascend_dark.png'
                : 'assets/images/categoty_market_sort_ascend.png')
          : (dark
                ? 'assets/images/categoty_market_sort_descend_dark.png'
                : 'assets/images/categoty_market_sort_descend.png');
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF666666),
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Image.asset(asset, width: 12, height: 12, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}

class _CategoryMarket2Row extends StatelessWidget {
  final CategoryMarketProductModel product;
  final VoidCallback? onTap;

  const _CategoryMarket2Row({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final rawPrice = p.displayPrice?.trim();
    final price = rawPrice != null && rawPrice.isNotEmpty
        ? rawPrice
        : p.symbol.isNotEmpty || p.name.isNotEmpty
        ? p.price.toStringAsFixed(p.precision.clamp(0, 8))
        : '--';
    final rawZdf = p.displayChangePercent?.trim();
    final zdfText = rawZdf != null && rawZdf.isNotEmpty
        ? rawZdf
        : '${p.changePercent >= 0 ? '+' : ''}'
              '${p.changePercent.toStringAsFixed(2)}%';
    final zdfColor = CardTool.priceColor(p.changePercent);
    final quote = (p.subTitle?.isNotEmpty ?? false) ? '/ ${p.subTitle}' : '';

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _CategoryMarket2Icons(product: p),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    p.name.isNotEmpty ? p.name : p.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.adaptiveTextPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                if (quote.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      quote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF999999),
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, maxWidth: 108),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                price,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            constraints: const BoxConstraints(minWidth: 64),
            height: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: zdfColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                zdfText,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1,
                ),
              ),
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

class _CategoryMarket2Icons extends StatelessWidget {
  final CategoryMarketProductModel product;

  const _CategoryMarket2Icons({required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.isSingleIcon) {
      return _CategoryMarket2Coin(url: product.icon, size: 36);
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        children: [
          Positioned.fill(
            child: _CategoryMarket2Coin(
              url: product.currencyBaseIcon ?? product.icon,
              size: 36,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _CategoryMarket2Coin(
              url: product.currencyProfitIcon,
              size: 16,
              ring: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMarket2Coin extends StatelessWidget {
  final String? url;
  final double size;
  final bool ring;

  const _CategoryMarket2Coin({
    required this.url,
    required this.size,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    final image = ClipOval(
      child: u == null || u.isEmpty
          ? Container(width: size, height: size, color: const Color(0xFFE8E8E8))
          : Image.network(
              u,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: size,
                height: size,
                color: const Color(0xFFE8E8E8),
              ),
            ),
    );

    if (!ring) return image;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final bool fillUnder;
  final Color? fillBaseColor;

  _SparkPainter(
    this.points,
    this.color, {
    this.fillUnder = false,
    this.fillBaseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    if (points.length == 1) {
      final y = size.height * 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - ((points[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (fillUnder) {
      final base = fillBaseColor ?? color;
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final g = Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base.withValues(alpha: 0.22), base.withValues(alpha: 0.04)],
        ).createShader(rect);
      canvas.drawPath(fillPath, g);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.fillUnder != fillUnder ||
      oldDelegate.fillBaseColor != fillBaseColor;
}
