import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_toast.dart';

abstract final class MarketProductPickerSheet {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String selectedSymbol,
    required Future<void> Function(String symbol) onPick,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.adaptiveCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (_) => _MarketProductPickerSheetBody(
        selectedSymbol: selectedSymbol,
        onPick: onPick,
      ),
    );
  }
}

class _DetailProductTab {
  const _DetailProductTab(this.labelKey, this.fallback, this.rankType);

  final String labelKey;
  final String fallback;
  final int rankType;
}

class _MarketProductPickerSheetBody extends ConsumerStatefulWidget {
  const _MarketProductPickerSheetBody({
    required this.selectedSymbol,
    required this.onPick,
  });

  final String selectedSymbol;
  final Future<void> Function(String symbol) onPick;

  @override
  ConsumerState<_MarketProductPickerSheetBody> createState() =>
      _MarketProductPickerSheetBodyState();
}

class _MarketProductPickerSheetBodyState
    extends ConsumerState<_MarketProductPickerSheetBody>
    with SingleTickerProviderStateMixin {
  static const _pageLimit = 20;
  static const _cardHeaderKeys = {
    'column_name',
    'column_last_price',
    'column_24h_change',
  };
  static const Map<String, String> _fallbackText = {
    'search_stock_group': '搜索品种...',
    'goods': '商品',
    'index_number': '指数',
    'foreign_exchange': '外汇',
    'encryption': '加密货币',
    'requestfail': '数据加载失败',
    'no_record': '暂无记录',
    'no_product_data': '暂无可交易产品',
    'column_name': '名称',
    'column_last_price': '最新价',
    'column_24h_change': '24H',
  };

  late final List<_DetailProductTab> _tabs;
  late final TabController _tabController;
  late final List<List<MarketProductModel>> _tabRows;
  late final List<bool> _tabLoaded;
  late final List<bool> _tabLoading;
  late final List<bool> _tabHasMore;
  late final List<int> _tabPages;
  late final List<String?> _tabErrors;

  final TextEditingController _searchCtl = TextEditingController();
  List<MarketProductModel> _searchHits = [];
  bool _searchLoading = false;
  String _lastSearchKeyword = '';
  int _searchReq = 0;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  @override
  void initState() {
    super.initState();
    final isB = ref.read(userStateProvider).isB;
    _tabs = [
      const _DetailProductTab('goods', '商品', 2),
      const _DetailProductTab('index_number', '指数', 5),
      const _DetailProductTab('foreign_exchange', '外汇', 1),
      if (!isB) const _DetailProductTab('encryption', '加密货币', 4),
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabRows = List.generate(_tabs.length, (_) => <MarketProductModel>[]);
    _tabLoaded = List.generate(_tabs.length, (_) => false);
    _tabLoading = List.generate(_tabs.length, (_) => false);
    _tabHasMore = List.generate(_tabs.length, (_) => true);
    _tabPages = List.generate(_tabs.length, (_) => 0);
    _tabErrors = List.generate(_tabs.length, (_) => null);
    _tabController.addListener(_onTabChanged);
    _searchCtl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureTabLoaded(_tabController.index);
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _ensureTabLoaded(_tabController.index);
  }

  void _onSearchChanged() {
    final q = _searchCtl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _searchHits = [];
        _lastSearchKeyword = '';
        _searchLoading = false;
      });
      return;
    }
    _runSearch(q);
  }

  Future<void> _ensureTabLoaded(int tabIndex) async {
    if (!_validTab(tabIndex) || _tabLoaded[tabIndex]) return;
    await _loadTabPage(tabIndex, reset: true);
  }

  Future<void> _loadNextPage(int tabIndex) async {
    if (!_validTab(tabIndex) ||
        _tabLoading[tabIndex] ||
        !_tabLoaded[tabIndex] ||
        !_tabHasMore[tabIndex]) {
      return;
    }
    await _loadTabPage(tabIndex, reset: false);
  }

  Future<void> _loadTabPage(int tabIndex, {required bool reset}) async {
    if (!_validTab(tabIndex) || _tabLoading[tabIndex]) return;
    setState(() {
      _tabLoading[tabIndex] = true;
      if (reset) {
        _tabErrors[tabIndex] = null;
        _tabHasMore[tabIndex] = true;
        _tabPages[tabIndex] = 0;
      }
    });

    final offset = reset ? 0 : _tabPages[tabIndex] * _pageLimit;
    try {
      final root = await ref
          .read(stServiceProvider)
          .getProductListByRank(
            rankType: _tabs[tabIndex].rankType,
            offset: offset,
            limit: _pageLimit,
            sortOrder: 'OrderAsce',
            needPoints: true,
          );
      final data = STService.marketListDataFromRoot(
        Map<String, dynamic>.from(root),
      );
      final symbols = STService.symbolArrayFromMarketDataMap(data);
      final rows = _productsFromRaw(symbols);
      final total = _intValue(data['count']);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _tabRows[tabIndex] = rows;
        } else {
          _tabRows[tabIndex] = [..._tabRows[tabIndex], ...rows];
        }
        _tabLoaded[tabIndex] = true;
        _tabLoading[tabIndex] = false;
        _tabErrors[tabIndex] = null;
        _tabPages[tabIndex] = (_tabRows[tabIndex].length / _pageLimit).ceil();
        _tabHasMore[tabIndex] = total > 0
            ? _tabRows[tabIndex].length < total
            : rows.length >= _pageLimit;
      });
    } catch (e) {
      if (!mounted) return;
      STToast.show(context, _t('requestfail'));
      setState(() {
        _tabLoading[tabIndex] = false;
        _tabLoaded[tabIndex] = true;
        if (reset) {
          _tabRows[tabIndex] = const [];
          _tabErrors[tabIndex] = _t('requestfail');
        }
      });
    }
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchReq;
    setState(() {
      _searchLoading = true;
      _lastSearchKeyword = q;
    });
    try {
      final raw = await ref
          .read(stServiceProvider)
          .searchSymbols(q, needPoints: false);
      if (!mounted || seq != _searchReq || _searchCtl.text.trim() != q) return;
      setState(() {
        _searchHits = _productsFromRaw(raw);
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchReq || _searchCtl.text.trim() != q) return;
      STToast.show(context, _t('requestfail'));
      setState(() {
        _searchHits = [];
        _searchLoading = false;
      });
    }
  }

  List<MarketProductModel> _productsFromRaw(List<dynamic> raw) {
    final out = <MarketProductModel>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        out.add(MarketProductModel.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    return out;
  }

  bool _validTab(int tabIndex) => tabIndex >= 0 && tabIndex < _tabs.length;

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    Future.wait(
      _fallbackText.entries.map((entry) async {
        final value = _cardHeaderKeys.contains(entry.key)
            ? await localizations.cardText(
                'categorymarket_2',
                entry.key,
                fallback: entry.value,
              )
            : await localizations.text(entry.key, fallback: entry.value);
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

  String _tabLabel(_DetailProductTab tab) {
    return _localizedText[tab.labelKey] ?? tab.fallback;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _searchCtl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _select(String symbol) async {
    final picked = symbol.trim();
    if (picked.isEmpty) return;
    Navigator.pop(context);
    await widget.onPick(picked);
  }

  static String _fmtLastPrice(MarketProductModel m) {
    final v = m.price;
    if (v == 0 && m.buy == 0 && m.sell == 0) return '--';
    final d = m.precision.clamp(0, 8);
    return v.toStringAsFixed(d);
  }

  @override
  Widget build(BuildContext context) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = math.min(632.0 + bottomInset, screenHeight * 0.88);
    final showSearchOverlay =
        _searchCtl.text.trim().isNotEmpty || _searchLoading;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 30, 15, 0),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchCtl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _t('search_stock_group'),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: context.adaptiveTextTertiary,
                  ),
                  suffixIcon: _searchCtl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: context.adaptiveTextTertiary,
                          onPressed: _searchCtl.clear,
                        ),
                  filled: true,
                  fillColor: context.adaptiveMutedBlock,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: showSearchOverlay
                ? _buildSearchBody()
                : Column(
                    children: [
                      SizedBox(
                        height: 37,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelColor: context.adaptiveTextPrimary,
                          unselectedLabelColor: context.adaptiveTextSecondary,
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          indicatorColor: context.adaptiveTextPrimary,
                          indicatorWeight: 2,
                          indicatorSize: TabBarIndicatorSize.label,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          tabs: _tabs
                              .map((t) => Tab(text: _tabLabel(t)))
                              .toList(),
                        ),
                      ),
                      Divider(height: 1, color: context.adaptiveDivider),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: List.generate(
                            _tabs.length,
                            _buildCategoryTab,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(int tabIndex) {
    if (_tabLoading[tabIndex] && _tabRows[tabIndex].isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final error = _tabErrors[tabIndex];
    if (error != null) {
      return Center(
        child: Text(error, style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    return Column(
      children: [
        _tableHeaderRow(),
        Expanded(
          child: _buildProductList(
            _tabRows[tabIndex],
            rowHeight: 64,
            onReachBottom: () => _loadNextPage(tabIndex),
            showFooterLoader:
                _tabLoading[tabIndex] &&
                _tabRows[tabIndex].isNotEmpty &&
                _tabHasMore[tabIndex],
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderRow() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF7F7F7))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _t('column_name'),
              style: TextStyle(
                fontSize: 13,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              _t('column_last_price'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ),
          const SizedBox(width: 13),
          SizedBox(
            width: 71,
            child: Text(
              _t('column_24h_change'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBody() {
    if (_searchLoading && _searchHits.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_searchHits.isEmpty &&
        _lastSearchKeyword.isNotEmpty &&
        !_searchLoading) {
      return Center(
        child: Text(
          _t('no_record'),
          style: TextStyle(color: context.adaptiveTextTertiary),
        ),
      );
    }
    return _buildProductList(_searchHits, rowHeight: 56);
  }

  Widget _buildProductList(
    List<MarketProductModel> data, {
    required double rowHeight,
    Future<void> Function()? onReachBottom,
    bool showFooterLoader = false,
  }) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          _t('no_product_data'),
          style: TextStyle(color: context.adaptiveTextTertiary),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (onReachBottom != null &&
            metrics.maxScrollExtent - metrics.pixels < 80) {
          onReachBottom();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: data.length + (showFooterLoader ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          indent: 15,
          color: context.adaptiveDivider,
        ),
        itemBuilder: (_, i) {
          if (i >= data.length) {
            return const SizedBox(
              height: 44,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _productTile(data[i], rowHeight: rowHeight);
        },
      ),
    );
  }

  Widget _productTile(MarketProductModel m, {required double rowHeight}) {
    final sym = m.symbol.trim();
    final name = m.name.trim();
    final sub = (m.subTitle ?? '').trim();
    final subtitle = sub.isNotEmpty ? sub : (name != sym ? name : '');
    final sel = sym.isNotEmpty && sym == widget.selectedSymbol;
    final priceStr = _fmtLastPrice(m);
    final pct = m.changePercent;
    final displayPct = m.changePercentString;
    final rise = pct > 0;
    final fall = pct < 0;
    final chipBg = rise
        ? CardTool.priceColor(1)
        : fall
        ? CardTool.priceColor(-1)
        : const Color(0xFFEDEFF2);
    final chipFg = rise || fall ? Colors.white : context.adaptiveTextPrimary;

    return InkWell(
      onTap: () => _select(sym),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: rowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sym.replaceAll('/', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? const Color(0xFF00C2B8)
                            : context.adaptiveTextPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  priceStr,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              SizedBox(
                width: 71,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 62),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      displayPct,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: chipFg,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
