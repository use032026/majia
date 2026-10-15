import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/category_market_paging.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/event_bus.dart';
import '../../shared/widgets/card_factory.dart';
import '../../shared/widgets/market_pair_icons.dart';
import '../../shared/widgets/st_load_animation_view.dart';
import 'market_list_ui_prefs.dart';

/// 行情列表（Figma `市场-1-默认模式` / `市场-2-暗黑模式`）
const double _kIosHqListPad = 16;

const double _kIosHqToolbarLead = 54;
const int _kIosHqNameFlex = 1;
const int _kIosHqPriceFlex = 3;
const double _kIosHqSparkW = 50;
const double _kIosHqSparkH = 23;

/// 名称区结束与迷你线之间（对齐 `titleLab`→`lineView` 间距 CTScaleNum6(13)）
const double _kIosHqSparkGap = 13;
const double _kIosHqPricePadH = 0;

/// 最新价与涨跌幅区：`priceLab` 与 `rateLab` 间距 CTScaleNum6(13)
const double _kIosHqPricePillGap = 16;
const double _kIosHqPillColMinW = 82;

/// 列表行高（Figma row 60）
const double _kIosHqRowH = 60;

/// 表头区高度（Figma y=139 h=31）
const double _kIosHqToolbarH = 31;

enum MarketSortColumn { name, price, changePercent }

/// 分类 / 排行榜行情列表（发现 Tab 子页 router `/tradeMarket`；行情 Tab 内嵌时为 `categorymarket_1`）
/// 对齐 iOS `Categorymarket1CardView`：`get_symbols_data` + `selectedCategorySymbolGroup` + offset/limit 分页。
class CategoryMarketListPage extends ConsumerStatefulWidget {
  final String? title;
  final int rankType;

  /// 底栏「行情」内嵌时由 [MarketHqSection] 传入，与 [ConfigDataManager.selectedCategorySymbolGroup] 一致；
  /// 用于在 [rankType] 与上一帧相同仍发生类目切换时强制重拉（对齐 iOS 头部类目切换筛数据）。
  final int? marketSelectedSymbolGroup;

  /// 为 true 时不包 Scaffold（嵌在 [MarketTabShellPage] 子 Tab 内）
  final bool embedded;

  /// iOS 行情列表样式：表头 + 迷你走势图 + 涨跌幅胶囊（参考 STMarketListView）
  final bool iosStyleRows;

  const CategoryMarketListPage({
    super.key,
    this.title,
    this.rankType = 0,
    this.marketSelectedSymbolGroup,
    this.embedded = false,
    this.iosStyleRows = true,
  });

  @override
  ConsumerState<CategoryMarketListPage> createState() =>
      _CategoryMarketListPageState();
}

class _CategoryMarketListPageState extends ConsumerState<CategoryMarketListPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const Map<String, String> _fallbackText = {
    'market': '市场',
    'no_data': '暂无数据',
    'column_name': '名称',
    'column_last_price': '最新价',
    'column_24h_change': '24H',
  };

  @override
  bool get wantKeepAlive => widget.embedded;

  final List<MarketProductModel> _items = [];
  final ScrollController _scroll = ScrollController();
  Map<String, String> _localizedText = _fallbackText;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  bool _isFirstEnter = true;
  String? _localizedLanguageCode;
  Timer? _priceBackgroundTimer;

  /// 与 iOS `listKlineSwitch` 一致：`true` = 展示迷你走势
  bool _listKlineSwitch = true;

  /// 与 iOS `listStyleSwitch` 一致：false=涨跌比(PriceRatio), true=买卖价(BuySell)
  bool _listStyleSwitch = false;

  MarketSortColumn _sortColumn = MarketSortColumn.changePercent;
  String _sortOrder = MarketListUiPrefs.sortDefault;
  late final VoidCallback _accountChangedListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MarketListUiPrefs.listKlineSwitchChanges.addListener(_onListKlineChanged);
    MarketListUiPrefs.listStyleSwitchChanges.addListener(_onListStyleChanged);
    _scroll.addListener(_onScroll);
    _accountChangedListener = () {
      if (!mounted) return;
      unawaited(_loadInitial());
    };
    EventBus().on(EventBus.accountChanged, _accountChangedListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLocalizedText();
  }

  Future<void> _bootstrap() async {
    final k = await MarketListUiPrefs.readListKlineSwitch();
    final style = await MarketListUiPrefs.readListStyleSwitch();
    final s = await MarketListUiPrefs.readListSortOrder();
    if (!mounted) return;
    setState(() {
      _listKlineSwitch = k;
      _listStyleSwitch = style;
      _sortOrder = s;
    });
    _syncPriceBackgroundTimer();
    await _loadInitial();
    _isFirstEnter = false;
  }

  @override
  void didUpdateWidget(covariant CategoryMarketListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rankChanged = oldWidget.rankType != widget.rankType;
    final groupChanged =
        oldWidget.marketSelectedSymbolGroup != widget.marketSelectedSymbolGroup;
    if (rankChanged || groupChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadInitial();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MarketListUiPrefs.listKlineSwitchChanges.removeListener(
      _onListKlineChanged,
    );
    MarketListUiPrefs.listStyleSwitchChanges.removeListener(
      _onListStyleChanged,
    );
    EventBus().off(EventBus.accountChanged, _accountChangedListener);
    _priceBackgroundTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isFirstEnter) {
      _loadInitial();
    }
  }

  void _onListKlineChanged() {
    final value = MarketListUiPrefs.listKlineSwitchChanges.value;
    if (!mounted || value == null || value == _listKlineSwitch) return;
    setState(() => _listKlineSwitch = value);
  }

  void _onListStyleChanged() {
    final value = MarketListUiPrefs.listStyleSwitchChanges.value;
    if (!mounted || value == null || value == _listStyleSwitch) return;
    setState(() => _listStyleSwitch = value);
    _syncPriceBackgroundTimer();
  }

  void _syncPriceBackgroundTimer() {
    _priceBackgroundTimer?.cancel();
    _priceBackgroundTimer = null;
    if (!_listStyleSwitch) return;
    _priceBackgroundTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final prefetch = categoryMarketScrollPrefetchPx(_kIosHqRowH);
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - prefetch) {
      _loadMore();
    }
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  void _ensureLocalizedText() {
    final localizations = stLocalizationsOfContext(context, ref);
    if (_localizedLanguageCode == localizations.languageCode) {
      return;
    }
    _localizedLanguageCode = localizations.languageCode;
    Future.wait<String>([
      localizations.text('market', fallback: _fallbackText['market']),
      localizations.text('no_data', fallback: _fallbackText['no_data']),
      localizations.cardText(
        'categorymarket_2',
        'column_name',
        fallback: _fallbackText['column_name'],
      ),
      localizations.cardText(
        'categorymarket_2',
        'column_last_price',
        fallback: _fallbackText['column_last_price'],
      ),
      localizations.cardText(
        'categorymarket_2',
        'column_24h_change',
        fallback: _fallbackText['column_24h_change'],
      ),
    ]).then((values) {
      if (!mounted || _localizedLanguageCode != localizations.languageCode) {
        return;
      }
      setState(() {
        _localizedText = {
          'market': values[0],
          'no_data': values[1],
          'column_name': values[2],
          'column_last_price': values[3],
          'column_24h_change': values[4],
        };
      });
    });
  }

  Future<void> _loadInitial() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });
    ref.read(configDataManagerProvider).resetCategoryMarketPaging();
    await _fetch(reset: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    await _fetch(reset: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetch({required bool reset}) async {
    final mgr = ref.read(configDataManagerProvider);
    try {
      mgr.categoryMarketLoadMoreRequest = !reset;
      final service = ref.read(stServiceProvider);
      final offset = reset ? 0 : _offset;
      final limit = mgr.categoryMarketPageSize > 0
          ? mgr.categoryMarketPageSize
          : kCategoryMarketSymbolsPageDefault;
      final batch = await CardFactory.loadMarketTabCategoryProducts(
        service: service,
        configMgr: mgr,
        rankType: widget.rankType,
        offset: offset,
        limit: limit,
        sortOrder: _sortColumn == MarketSortColumn.changePercent
            ? _sortOrder
            : MarketListUiPrefs.sortDefault,
      );
      if (batch.isEmpty && offset == 0) {
        debugPrint(
          '⚠️ 分类行情无品种: rankType=${widget.rankType} '
          'nextOffset=${mgr.categoryMarketNextOffset} hasMore=${mgr.categoryMarketHasMore}',
        );
      }
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(batch);
        } else {
          _items.addAll(batch);
        }
        _offset = mgr.categoryMarketNextOffset;
        _hasMore = mgr.categoryMarketHasMore;
      });
    } catch (e) {
      debugPrint('CategoryMarketListPage fetch error: $e');
    } finally {
      mgr.categoryMarketLoadMoreRequest = false;
    }
  }

  Future<void> _cycleSort(MarketSortColumn column) async {
    final next = _sortColumn == column
        ? MarketListUiPrefs.cycleSortOrder(_sortOrder)
        : MarketListUiPrefs.sortDesce;
    setState(() {
      _sortColumn = column;
      _sortOrder = next;
    });
    if (column == MarketSortColumn.changePercent) {
      await MarketListUiPrefs.writeListSortOrder(next);
      await _loadInitial();
    }
  }

  Widget _iosMarketToolbarHeader() {
    return MarketInstrumentListHeader(
      nameText: _t('column_name'),
      lastPriceText: _t('column_last_price'),
      changeText: _t('column_24h_change'),
      sortColumn: _sortColumn,
      sortOrder: _sortOrder,
      onSort: _cycleSort,
    );
  }

  List<MarketProductModel> _sortVisibleItems(List<MarketProductModel> items) {
    return sortMarketInstrumentItems(
      items,
      sortColumn: _sortColumn,
      sortOrder: _sortOrder,
    );
  }

  Widget _buildBody(BuildContext context, List<MarketProductModel> ordered) {
    if (widget.iosStyleRows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _iosMarketToolbarHeader(),
          Expanded(
            child: STPullRefresh(
              onRefresh: _loadInitial,
              child: _loading && _items.isEmpty
                  ? const Center(child: STLoadAnimationView())
                  : ListView(
                      controller: _scroll,
                      padding: EdgeInsets.zero,
                      primary: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (!_loading && ordered.isEmpty) ...[
                          const SizedBox(height: 72),
                          Center(
                            child: Text(
                              _t('no_data'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFA9A9A9),
                              ),
                            ),
                          ),
                        ],
                        for (int i = 0; i < ordered.length; i++)
                          _IosCategoryInstrumentRow(
                            product: ordered[i],
                            toolbarLeadingGutter: false,
                            showSparkline: false,
                            showBuySell: false,
                            onTap: () => context.push(
                              '/market/detail?symbol=${Uri.encodeComponent(ordered[i].symbol)}',
                            ),
                          ),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    return STPullRefresh(
      onRefresh: _loadInitial,
      child: _loading && _items.isEmpty
          ? const Center(child: STLoadAnimationView())
          : ListView.separated(
              controller: _scroll,
              padding: EdgeInsets.zero,
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: ordered.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, i) {
                if (i >= ordered.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final p = ordered[i];
                final up = p.changePercent > 0;
                final priceStr = p.price.toStringAsFixed(p.precision);
                return ListTile(
                  title: Text(
                    p.symbol,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        priceStr,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        p.changePercentString,
                        style: TextStyle(
                          fontSize: 12,
                          color: up ? Colors.redAccent : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => context.push(
                    '/market/detail?symbol=${Uri.encodeComponent(p.symbol)}',
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(userStateProvider.select((s) => s.riseAndFallType));
    CardTool.setRiseAndFallType(ref.read(userStateProvider).riseAndFallType);

    final mgr = ref.watch(configDataManagerProvider);
    final ordered = _sortVisibleItems(
      _items.map((p) {
        final i = mgr.productIndexForSymbol(p.symbol);
        if (i >= 0 && i < mgr.productList.length) return mgr.productList[i];
        return p;
      }).toList(),
    );

    if (widget.embedded) {
      return _buildBody(context, ordered);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? _t('market'))),
      body: _buildBody(context, ordered),
    );
  }
}

class MarketInstrumentListHeader extends StatelessWidget {
  final String nameText;
  final String lastPriceText;
  final String changeText;
  final MarketSortColumn sortColumn;
  final String sortOrder;
  final FutureOr<void> Function(MarketSortColumn column) onSort;

  const MarketInstrumentListHeader({
    super.key,
    this.nameText = '名称',
    this.lastPriceText = '最新价',
    this.changeText = '24H',
    required this.sortColumn,
    required this.sortOrder,
    required this.onSort,
  });

  IconData _sortIcon(MarketSortColumn column) {
    if (sortColumn != column || sortOrder == MarketListUiPrefs.sortDefault) {
      return Icons.unfold_more;
    }
    if (sortOrder == MarketListUiPrefs.sortDesce) {
      return Icons.arrow_downward_rounded;
    }
    if (sortOrder == MarketListUiPrefs.sortAsce) {
      return Icons.arrow_upward_rounded;
    }
    return Icons.unfold_more;
  }

  Widget _label({
    required String text,
    required TextStyle style,
    required Color iconColor,
    required MainAxisAlignment alignment,
    required MarketSortColumn column,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSort(column),
      child: Row(
        mainAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, style: style, maxLines: 1)),
          const SizedBox(width: 2),
          Icon(_sortIcon(column), size: 14, color: iconColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF6E727D) : const Color(0xFF9A9DA2);
    final sub = TextStyle(
      fontSize: 14,
      color: muted,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );

    return SizedBox(
      height: _kIosHqToolbarH,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_kIosHqListPad, 0, _kIosHqListPad, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _label(
                  text: nameText,
                  style: sub,
                  iconColor: muted,
                  alignment: MainAxisAlignment.start,
                  column: MarketSortColumn.name,
                ),
              ),
            ),
            SizedBox(
              width: 78,
              child: Align(
                alignment: Alignment.centerRight,
                child: _label(
                  text: lastPriceText,
                  style: sub,
                  iconColor: muted,
                  alignment: MainAxisAlignment.end,
                  column: MarketSortColumn.price,
                ),
              ),
            ),
            const SizedBox(width: _kIosHqPricePillGap),
            SizedBox(
              width: _kIosHqPillColMinW,
              child: Align(
                alignment: Alignment.centerRight,
                child: _label(
                  text: changeText,
                  style: sub,
                  iconColor: muted,
                  alignment: MainAxisAlignment.end,
                  column: MarketSortColumn.changePercent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<MarketProductModel> sortMarketInstrumentItems(
  List<MarketProductModel> items, {
  required MarketSortColumn sortColumn,
  required String sortOrder,
}) {
  if (sortOrder == MarketListUiPrefs.sortDefault) {
    return items;
  }
  final sorted = List<MarketProductModel>.from(items);
  int compare(MarketProductModel a, MarketProductModel b) {
    switch (sortColumn) {
      case MarketSortColumn.name:
        final nameA = CardTool.hqSymbolTitleLine(
          a.symbol,
          a.name,
        ).toUpperCase();
        final nameB = CardTool.hqSymbolTitleLine(
          b.symbol,
          b.name,
        ).toUpperCase();
        return nameA.compareTo(nameB);
      case MarketSortColumn.price:
        return a.price.compareTo(b.price);
      case MarketSortColumn.changePercent:
        return a.changePercent.compareTo(b.changePercent);
    }
  }

  sorted.sort((a, b) {
    final result = compare(a, b);
    if (sortOrder == MarketListUiPrefs.sortDesce) {
      return -result;
    }
    return result;
  });
  return sorted;
}

class FigmaMarketInstrumentRow extends StatelessWidget {
  final MarketProductModel product;
  final VoidCallback onTap;

  const FigmaMarketInstrumentRow({
    super.key,
    required this.product,
    required this.onTap,
  });

  ({String base, String quote}) _splitSymbol() {
    final raw = product.symbol.trim();
    if (raw.contains('/')) {
      final parts = raw.split('/');
      final base = parts.first.trim().toUpperCase();
      final quote = parts.skip(1).join('/').trim().toUpperCase();
      return (base: base, quote: quote.isEmpty ? '' : '/ $quote');
    }
    final base = raw.isNotEmpty ? raw.toUpperCase() : product.name.trim();
    final name = product.name.trim();
    final quote = name.isNotEmpty && name.toUpperCase() != base.toUpperCase()
        ? name
        : '';
    return (base: base, quote: quote);
  }

  Color _pillColor(BuildContext context) {
    return CardTool.iosHqListPillBg(product.changePercent);
  }

  Color _primaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFEDF1F8)
        : Colors.black;
  }

  Color _secondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6E727D)
        : const Color(0xFF9A9DA2);
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _splitSymbol();
    final priceStr = product.price != 0 || product.symbol.isNotEmpty
        ? product.price.toStringAsFixed(product.precision)
        : '--';
    final change = product.changePercent;
    final changeStr = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%';
    final dark = Theme.of(context).brightness == Brightness.dark;

    final row = SizedBox(
      height: _kIosHqRowH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kIosHqListPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MarketPairIcons.of(product, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      symbol.base,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primaryTextColor(context),
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (symbol.quote.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        symbol.quote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _secondaryTextColor(context),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 74,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  priceStr,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primaryTextColor(context),
                    height: 1.25,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _kIosHqPricePillGap),
            Container(
              width: _kIosHqPillColMinW,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pillColor(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  changeStr,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dark ? const Color(0xFF18191A) : Colors.white,
                    height: 1.5,
                    letterSpacing: 0.325,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// iOS 行情列表单行（`STMarketListPriceRatioCell` / `STMarketListBuySellCell`）。
class _IosCategoryInstrumentRow extends StatelessWidget {
  final MarketProductModel product;
  final bool toolbarLeadingGutter;
  final bool showSparkline;
  final bool showBuySell;
  final VoidCallback onTap;

  const _IosCategoryInstrumentRow({
    required this.product,
    this.toolbarLeadingGutter = false,
    this.showSparkline = true,
    this.showBuySell = false,
    required this.onTap,
  });

  (double, double) _sparkMinMax() {
    final p = product;
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

  @override
  Widget build(BuildContext context) {
    if (!showBuySell && !showSparkline) {
      return FigmaMarketInstrumentRow(product: product, onTap: onTap);
    }

    final titleColor = Theme.of(context).colorScheme.onSurface;

    if (!showBuySell) {
      final cp = product.changePercent;
      final sparkColor = CardTool.iosHqListSparkColor(
        product.points,
        changePercent: cp,
      );
      final pillColor = CardTool.iosHqListPillBg(cp);
      final mm = _sparkMinMax();
      final priceStr = product.price != 0 || product.symbol.isNotEmpty
          ? product.price.toStringAsFixed(product.precision)
          : '--';

      int sparkTrend;
      if (product.points.length >= 2) {
        final d = product.points.last - product.points.first;
        if (d > 1e-9) {
          sparkTrend = 1;
        } else if (d < -1e-9) {
          sparkTrend = -1;
        } else {
          sparkTrend = 0;
        }
      } else {
        if (cp > 1e-9) {
          sparkTrend = 1;
        } else if (cp < -1e-9) {
          sparkTrend = -1;
        } else {
          sparkTrend = 0;
        }
      }
      final fillSpark = sparkTrend > 0;

      final row = SizedBox(
        height: _kIosHqRowH,
        child: Padding(
          padding: EdgeInsets.fromLTRB(_kIosHqListPad, 0, _kIosHqListPad, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (toolbarLeadingGutter)
                const SizedBox(width: _kIosHqToolbarLead),
              Expanded(
                flex: _kIosHqNameFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      CardTool.hqSymbolTitleLine(product.symbol, product.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        MarketPairIcons.of(product, size: 12),
                        if (product.name.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: CardTool.iosHqListSubtitle,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: showSparkline ? _kIosHqSparkGap : 0),
              if (showSparkline)
                SizedBox(
                  width: _kIosHqSparkW,
                  child: Center(
                    child: CustomPaint(
                      size: const Size(_kIosHqSparkW, _kIosHqSparkH),
                      painter: _CategorySparklinePainter(
                        points: product.points,
                        minY: mm.$1,
                        maxY: mm.$2,
                        color: sparkColor,
                        fillUnder: fillSpark,
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: _kIosHqPriceFlex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kIosHqPricePadH,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 70,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            priceStr,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: _kIosHqPricePillGap),
                      Container(
                        width: _kIosHqPillColMinW,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pillColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${cp >= 0 ? '+' : ''}${cp.toStringAsFixed(2)}%',
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: row),
      );
    }

    // 买卖价样式（对齐 STMarketListBuySellCell）
    final pillColor = CardTool.iosHqListPillBg(product.changePercent);
    final sellStr = product.sell != 0 || product.symbol.isNotEmpty
        ? product.sell.toStringAsFixed(product.precision)
        : '--';
    final buyStr = product.buy != 0 || product.symbol.isNotEmpty
        ? product.buy.toStringAsFixed(product.precision)
        : '--';
    final spreadStr = _formatSpread(product.spread);
    final mm = _sparkMinMax();
    final sellColor = _priceBackgroundColor(
      product.sellPriceChangeDirection,
      product.lastSellPriceChangeAt,
    );
    final buyColor = _priceBackgroundColor(
      product.buyPriceChangeDirection,
      product.lastBuyPriceChangeAt,
    );

    final row = SizedBox(
      height: _kIosHqRowH,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_kIosHqListPad, 0, _kIosHqListPad, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (toolbarLeadingGutter) const SizedBox(width: _kIosHqToolbarLead),
            Expanded(
              flex: _kIosHqNameFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    CardTool.hqSymbolTitleLine(product.symbol, product.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      MarketPairIcons.of(product),
                      if (product.name.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF999999),
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: showSparkline ? _kIosHqSparkGap : 0),
            if (showSparkline)
              SizedBox(
                width: _kIosHqSparkW,
                child: Center(
                  child: CustomPaint(
                    size: const Size(_kIosHqSparkW, _kIosHqSparkH),
                    painter: _CategorySparklinePainter(
                      points: product.points,
                      minY: mm.$1,
                      maxY: mm.$2,
                      color: pillColor,
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: _kIosHqPriceFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kIosHqPricePadH,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _IosAdaptiveBuySellGroup(
                    sellText: sellStr,
                    buyText: buyStr,
                    spreadText: spreadStr,
                    sellColor: sellColor,
                    buyColor: buyColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }

  String _formatSpread(double spread) {
    final fixed = spread.toStringAsFixed(product.precision.clamp(0, 6));
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  Color _priceBackgroundColor(int direction, DateTime? changedAt) {
    if (direction == 0 || changedAt == null) {
      return CardTool.iosHqListPillFlat;
    }
    if (DateTime.now().difference(changedAt) >= const Duration(seconds: 60)) {
      return CardTool.iosHqListPillFlat;
    }
    return direction > 0 ? CardTool.priceColor(1) : CardTool.priceColor(-1);
  }
}

class _IosBuySellPill extends StatelessWidget {
  final String text;
  final double width;
  final Color color;

  const _IosBuySellPill({
    required this.text,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _IosAdaptiveBuySellGroup extends StatelessWidget {
  final String sellText;
  final String buyText;
  final String spreadText;
  final Color sellColor;
  final Color buyColor;

  const _IosAdaptiveBuySellGroup({
    required this.sellText,
    required this.buyText,
    required this.spreadText,
    required this.sellColor,
    required this.buyColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 164.0);
        final contentW = width > 5 ? width - 5 : 0.0;
        final sellW = contentW * 78 / 159;
        final buyW = contentW - sellW;
        return SizedBox(
          width: width,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  _IosBuySellPill(
                    text: sellText,
                    width: sellW,
                    color: sellColor,
                  ),
                  const SizedBox(width: 5),
                  _IosBuySellPill(text: buyText, width: buyW, color: buyColor),
                ],
              ),
              SizedBox(
                width: 24,
                height: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        spreadText,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                          height: 1,
                        ),
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

class _CategorySparklinePainter extends CustomPainter {
  final List<double> points;
  final double minY;
  final double maxY;
  final Color color;
  final bool fillUnder;

  _CategorySparklinePainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.color,
    this.fillUnder = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25
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

    if (fillUnder) {
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
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.04),
          ],
        ).createShader(rect);
      canvas.drawPath(fillPath, g);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CategorySparklinePainter oldDelegate) {
    return oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.color != color ||
        oldDelegate.fillUnder != fillUnder ||
        !listEquals(oldDelegate.points, points);
  }
}
