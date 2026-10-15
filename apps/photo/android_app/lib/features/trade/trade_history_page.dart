import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/utils/ios_date_range.dart';
import '../../shared/widgets/ios_date_picker_sheet.dart';

// ─── 颜色常量 ───────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF4DCB73);
const _kRed = Color(0xFFF95959);
const _kGrey = Color(0xFF9A9DA2);

// ─── 筛选状态 ───────────────────────────────────────────────────────────────
enum _DirectionFilter { all, buy, sell }

enum _PnlFilter { all, profit, loss }

enum _StatusFilter { all, finished, canceled }

class _TradeHistoryText {
  const _TradeHistoryText([this.localized = const {}]);

  final Map<String, String> localized;

  static const fallbackText = <String, String>{
    'a_transaction_history': '订单历史',
    'filtering': '筛选',
    'today': '今日',
    'history': '历史',
    'direction': '方向',
    'all': '全部',
    'buy': '买入',
    'sell': '卖出',
    'status': '状态',
    'already_transacted': '已成交',
    'revoked': '已撤销',
    'profit_and_loss': '盈亏',
    'trade_history_profit_filter_positive': '盈利',
    'trade_history_profit_filter_negative': '亏损',
    'trade_history_symbol': '品种',
    'time': '时间',
    'start_date': '开始日期',
    'end_date': '结束日期',
    'reset': '重置',
    'trade_history_reset_filter': '重置筛选',
    'today_no_trade_records': '今日暂无交易记录',
    'no_history_yet': '暂无历史记录',
    'trade_history_loaded_all': '已加载全部',
    'trade_history_record_count': '共 {count} 笔',
    'trade_history_win_rate': '胜率 {rate}%',
    'total_profit_and_loss': '总盈亏',
    'lots': '交易量 (手)',
    'hand': '手',
    'open_price_title': '开仓价',
    'exit_price': '平仓价',
    'take_profit': '止盈',
    'stop_loss': '止损',
    'commission': '手续费',
    'overnight_interest_2': '隔夜利息',
    'open_time': '开仓时间',
    'close_time': '平仓时间',
    'retry': '重试',
    'stock_long': '买入',
    'stock_short': '卖出',
  };

  String t(String key) => localized[key] ?? fallbackText[key] ?? key;

  String format(String key, Map<String, String> replacements) {
    var value = t(key);
    for (final entry in replacements.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }
}

class _HistoryFilter {
  final _DirectionFilter direction;
  final _PnlFilter pnl;
  final _StatusFilter status;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> symbols;

  const _HistoryFilter({
    this.direction = _DirectionFilter.all,
    this.pnl = _PnlFilter.all,
    this.status = _StatusFilter.all,
    this.startDate,
    this.endDate,
    this.symbols = const <String>{},
  });

  _HistoryFilter copyWith({
    _DirectionFilter? direction,
    _PnlFilter? pnl,
    _StatusFilter? status,
    DateTime? startDate,
    DateTime? endDate,
    Set<String>? symbols,
    bool clearStart = false,
    bool clearEnd = false,
  }) => _HistoryFilter(
    direction: direction ?? this.direction,
    pnl: pnl ?? this.pnl,
    status: status ?? this.status,
    startDate: clearStart ? null : (startDate ?? this.startDate),
    endDate: clearEnd ? null : (endDate ?? this.endDate),
    symbols: symbols ?? this.symbols,
  );

  bool get hasFilter =>
      direction != _DirectionFilter.all ||
      pnl != _PnlFilter.all ||
      status != _StatusFilter.all ||
      startDate != null ||
      endDate != null ||
      symbols.isNotEmpty;
}

/// 交易历史页面
///
/// 对齐 iOS `STTradeAccountProfileHistoryController`（今日/历史分 Tab）+
/// `requestHistoryListWithSymbols:offset:startTime:endTime:status:direction:`
/// 支持方向、盈亏、时间范围筛选。
class TradeHistoryPage extends ConsumerStatefulWidget {
  const TradeHistoryPage({super.key});

  @override
  ConsumerState<TradeHistoryPage> createState() => _TradeHistoryPageState();
}

class _TradeHistoryPageState extends ConsumerState<TradeHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _TradeHistoryText _text = const _TradeHistoryText();
  String? _resolvedLanguageCode;
  int _languageLoadToken = 0;

  // ── 今日 ─────────────────────────────────────
  List<dynamic> _todayOrders = [];
  bool _todayLoading = true;
  String? _todayError;

  // ── 历史 ─────────────────────────────────────
  List<dynamic> _historyOrders = [];
  int _historyOffset = 0;
  bool _historyLoading = true;
  bool _historyLoadingMore = false;
  bool _historyHasMore = true;
  String? _historyError;

  // ── 筛选 ─────────────────────────────────────
  _HistoryFilter _filter = const _HistoryFilter();
  bool _showFilter = false;
  List<String> _availableSymbols = const [];

  static const int _kPageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadToday();
    _loadHistory();
    unawaited(_loadSymbols());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final localizations = stLocalizationsOfContext(context, ref);
    if (_resolvedLanguageCode == localizations.languageCode) return;
    _resolvedLanguageCode = localizations.languageCode;
    final token = ++_languageLoadToken;
    localizations.textMap(_TradeHistoryText.fallbackText).then((value) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _text = _TradeHistoryText(value));
    });
  }

  // ─────────────────────────────────────────────
  // 数据加载
  // ─────────────────────────────────────────────

  Future<void> _loadToday() async {
    setState(() {
      _todayLoading = true;
      _todayError = null;
    });
    try {
      final orders = await ref.read(stServiceProvider).getTodayOrders();
      if (!mounted) return;
      setState(() {
        _todayOrders = orders;
        _todayLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _todayError = stUserVisibleErrorMessage(e);
        _todayLoading = false;
      });
    }
  }

  Future<void> _loadHistory({bool loadMore = false}) async {
    if (loadMore && (_historyLoadingMore || !_historyHasMore)) return;

    if (loadMore) {
      setState(() => _historyLoadingMore = true);
    } else {
      setState(() {
        _historyLoading = true;
        _historyError = null;
        _historyOffset = 0;
      });
    }

    try {
      final offset = loadMore ? _historyOffset : 0;
      final timezone = ref.read(userStateProvider).selectedTimeZone;
      final startTime = _filter.startDate == null
          ? null
          : iosStartOfDaySeconds(_filter.startDate!, timezone: timezone);
      final endTime = _filter.endDate == null
          ? null
          : iosEndExclusiveSeconds(_filter.endDate!, timezone: timezone);
      final direction = switch (_filter.direction) {
        _DirectionFilter.buy => '0',
        _DirectionFilter.sell => '1',
        _DirectionFilter.all => null,
      };
      final status = switch (_filter.status) {
        _StatusFilter.finished => '1',
        _StatusFilter.canceled => '2',
        _StatusFilter.all => null,
      };
      final isProfit = switch (_filter.pnl) {
        _PnlFilter.profit => true,
        _PnlFilter.loss => false,
        _PnlFilter.all => null,
      };
      final orders = await ref
          .read(stServiceProvider)
          .getHistoryOrders(
            symbols: _filter.symbols.toList(),
            offset: offset,
            limit: _kPageSize,
            startTime: startTime,
            endTime: endTime,
            status: status,
            direction: direction,
            isProfit: isProfit,
          );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _historyOrders.addAll(orders);
        } else {
          _historyOrders = List<dynamic>.from(orders);
        }
        _historyOffset = offset + orders.length;
        _historyHasMore = orders.length >= _kPageSize;
        _historyLoading = false;
        _historyLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = stUserVisibleErrorMessage(e);
        _historyLoading = false;
        _historyLoadingMore = false;
      });
    }
  }

  Future<void> _loadSymbols() async {
    try {
      final raw = await ref.read(stServiceProvider).getTradeSymbols();
      final symbols = raw
          .whereType<Map>()
          .map(
            (item) =>
                item['symbol']?.toString() ??
                item['title']?.toString() ??
                item['name']?.toString() ??
                '',
          )
          .where((item) => item.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _availableSymbols = symbols);
    } catch (_) {
      if (!mounted) return;
      setState(() => _availableSymbols = const []);
    }
  }

  // ─────────────────────────────────────────────
  // 筛选逻辑（历史页筛选走服务端；今日页仍对已加载的今日数据做本地展示筛选）
  // ─────────────────────────────────────────────

  List<dynamic> _applyFilter(List<dynamic> orders, {required bool includePnl}) {
    return orders.where((o) {
      // 方向
      if (_filter.direction != _DirectionFilter.all) {
        final dir = _dirInt(o['direction']);
        if (_filter.direction == _DirectionFilter.buy && dir != 0) {
          return false;
        }
        if (_filter.direction == _DirectionFilter.sell && dir != 1) {
          return false;
        }
      }
      // 盈亏
      if (includePnl && _filter.pnl != _PnlFilter.all) {
        final pnl = _toDouble(o['profit'] ?? o['pnl']);
        if (_filter.pnl == _PnlFilter.profit && pnl <= 0) return false;
        if (_filter.pnl == _PnlFilter.loss && pnl >= 0) return false;
      }
      return true;
    }).toList();
  }

  void _updateFilter(_HistoryFilter next) {
    setState(() => _filter = next);
    unawaited(_loadHistory(loadMore: false));
  }

  // ─────────────────────────────────────────────
  // build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    final pageBg = context.adaptivePageGrey;
    final navBg = context.adaptiveSurfacePrimary;
    final textColor = context.adaptiveTextPrimary;
    final secondaryTextColor = context.adaptiveTextSecondary;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: navBg,
        foregroundColor: textColor,
        surfaceTintColor: navBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _text.t('a_transaction_history'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('trade-history-filter-button'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list_rounded, color: Color(0xFF00B57A)),
                if (_filter.hasFilter)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _kRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => setState(() => _showFilter = !_showFilter),
            tooltip: _text.t('filtering'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00B57A),
          labelColor: const Color(0xFF00B57A),
          unselectedLabelColor: secondaryTextColor,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: _text.t('today')),
            Tab(text: _text.t('history')),
          ],
        ),
      ),
      body: Column(
        children: [
          // 筛选面板
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _showFilter ? _buildFilterPanel() : const SizedBox.shrink(),
          ),
          // Tab 内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildTodayTab(), _buildHistoryTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 筛选面板 ────────────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    final labelStyle = TextStyle(
      fontSize: 13,
      color: context.adaptiveTextSecondary,
    );
    return Container(
      color: context.adaptiveCard,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 方向
          Row(
            children: [
              Text(_text.t('direction'), style: labelStyle),
              const SizedBox(width: 12),
              ..._DirectionFilter.values.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: {
                      _DirectionFilter.all: _text.t('all'),
                      _DirectionFilter.buy: _text.t('buy'),
                      _DirectionFilter.sell: _text.t('sell'),
                    }[d]!,
                    selected: _filter.direction == d,
                    selectedColor: const Color(0xFF00B57A),
                    onTap: () => _updateFilter(_filter.copyWith(direction: d)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_text.t('status'), style: labelStyle),
              const SizedBox(width: 12),
              ..._StatusFilter.values.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: {
                      _StatusFilter.all: _text.t('all'),
                      _StatusFilter.finished: _text.t('already_transacted'),
                      _StatusFilter.canceled: _text.t('revoked'),
                    }[s]!,
                    selected: _filter.status == s,
                    selectedColor: const Color(0xFF00B57A),
                    onTap: () => _updateFilter(_filter.copyWith(status: s)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 盈亏
          Row(
            children: [
              Text(_text.t('profit_and_loss'), style: labelStyle),
              const SizedBox(width: 12),
              ..._PnlFilter.values.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: {
                      _PnlFilter.all: _text.t('all'),
                      _PnlFilter.profit: _text.t(
                        'trade_history_profit_filter_positive',
                      ),
                      _PnlFilter.loss: _text.t(
                        'trade_history_profit_filter_negative',
                      ),
                    }[p]!,
                    selected: _filter.pnl == p,
                    selectedColor: const Color(0xFF00B57A),
                    onTap: () => _updateFilter(_filter.copyWith(pnl: p)),
                  ),
                ),
              ),
            ],
          ),
          if (_availableSymbols.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_text.t('trade_history_symbol'), style: labelStyle),
                for (final symbol in _availableSymbols)
                  _FilterChip(
                    label: symbol,
                    selected: _filter.symbols.contains(symbol),
                    selectedColor: const Color(0xFF00B57A),
                    onTap: () {
                      final next = {..._filter.symbols};
                      if (!next.add(symbol)) next.remove(symbol);
                      _updateFilter(_filter.copyWith(symbols: next));
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // 时间范围
          Row(
            children: [
              Text(_text.t('time'), style: labelStyle),
              const SizedBox(width: 12),
              _DatePickerButton(
                label: _filter.startDate != null
                    ? formatIosYmd(
                        _filter.startDate!,
                        languageCode: _languageCode,
                      )
                    : _text.t('start_date'),
                onTap: () => _pickDate(isStart: true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('—', style: TextStyle(color: labelStyle.color)),
              ),
              _DatePickerButton(
                label: _filter.endDate != null
                    ? formatIosYmd(
                        _filter.endDate!,
                        languageCode: _languageCode,
                      )
                    : _text.t('end_date'),
                onTap: () => _pickDate(isStart: false),
              ),
              if (_filter.startDate != null || _filter.endDate != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _updateFilter(
                    _filter.copyWith(clearStart: true, clearEnd: true),
                  ),
                  child: Icon(Icons.close, size: 16, color: labelStyle.color),
                ),
              ],
            ],
          ),
          // 重置
          if (_filter.hasFilter) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _updateFilter(const _HistoryFilter()),
              child: Text(
                _text.t('trade_history_reset_filter'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF00B57A)),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Divider(height: 1, color: context.adaptiveDivider),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showIosDatePickerSheet(
      context: context,
      initialDate: isStart ? _filter.startDate : _filter.endDate,
      minimumDate: isStart
          ? DateTime(2000)
          : (_filter.startDate ?? DateTime(2000)),
      maximumDate: isStart
          ? (_filter.endDate ?? DateTime(2050, 12, 30))
          : DateTime(2050, 12, 30),
    );
    if (picked == null || !mounted) return;
    _updateFilter(
      isStart
          ? _filter.copyWith(startDate: picked)
          : _filter.copyWith(endDate: picked),
    );
  }

  // ─── 今日 Tab ────────────────────────────────────────────────────────────

  Widget _buildTodayTab() {
    if (_todayLoading) return const Center(child: STLoadAnimationView());
    if (_todayError != null) {
      return _buildError(_todayError!, _loadToday);
    }
    final filtered = _applyFilter(_todayOrders, includePnl: true);
    if (filtered.isEmpty) {
      return STPullRefresh(
        onRefresh: _loadToday,
        child: _buildEmpty(_text.t('today_no_trade_records')),
      );
    }
    return STPullRefresh(
      onRefresh: _loadToday,
      child: _buildOrderList(filtered),
    );
  }

  // ─── 历史 Tab ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_historyLoading) {
      return const Center(child: STLoadAnimationView());
    }
    if (_historyError != null) {
      return _buildError(_historyError!, () => _loadHistory(loadMore: false));
    }
    final filtered = _applyFilter(_historyOrders, includePnl: false);
    if (filtered.isEmpty) {
      return STPullRefresh(
        onRefresh: () => _loadHistory(loadMore: false),
        child: _buildEmpty(_text.t('no_history_yet')),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
          _loadHistory(loadMore: true);
        }
        return false;
      },
      child: STPullRefresh(
        onRefresh: () => _loadHistory(loadMore: false),
        child: _buildOrderList(
          filtered,
          showLoadMore: _historyLoadingMore,
          hasMore: _historyHasMore,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 共用列表
  // ─────────────────────────────────────────────

  Widget _buildOrderList(
    List<dynamic> orders, {
    bool showLoadMore = false,
    bool hasMore = false,
  }) {
    final totalPnl = orders.fold<double>(
      0,
      (s, o) => s + _toDouble(o['profit'] ?? o['pnl']),
    );
    final winCount = orders.where((o) {
      final pnl = _toDouble(o['profit'] ?? o['pnl']);
      return pnl > 0;
    }).length;
    final winRate = orders.isEmpty ? 0.0 : winCount / orders.length * 100;

    return Column(
      children: [
        // 汇总栏
        _buildSummary(orders.length, totalPnl, winRate),
        // 列表
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length + (showLoadMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == orders.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: hasMore
                        ? const CircularProgressIndicator()
                        : Text(
                            _text.t('trade_history_loaded_all'),
                            style: const TextStyle(fontSize: 13, color: _kGrey),
                          ),
                  ),
                );
              }
              return _buildOrderCard(orders[i]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(int count, double totalPnl, double winRate) {
    final labelColor = context.adaptiveTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: context.adaptiveCard,
      child: Row(
        children: [
          Text(
            _text.format('trade_history_record_count', {
              'count': count.toString(),
            }),
            style: TextStyle(fontSize: 13, color: labelColor),
          ),
          const SizedBox(width: 16),
          Text(
            _text.format('trade_history_win_rate', {
              'rate': winRate.toStringAsFixed(1),
            }),
            style: TextStyle(fontSize: 13, color: labelColor),
          ),
          const Spacer(),
          Text(
            '${_text.t('total_profit_and_loss')} ',
            style: TextStyle(fontSize: 13, color: labelColor),
          ),
          Text(
            '${totalPnl >= 0 ? '+' : ''}${totalPnl.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: totalPnl >= 0
                  ? CardTool.priceColor(1)
                  : CardTool.priceColor(-1),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 订单卡片（对齐 iOS 历史订单 Cell 布局）──────────────────────────────

  Widget _buildOrderCard(dynamic order) {
    final sym = order['symbol']?.toString() ?? '---';
    final isBuy = _dirInt(order['direction']) == 0;
    final lots = (order['volume'] ?? order['lots'] ?? '--').toString();
    final openPrice = _toDouble(order['open_price'] ?? order['price']);
    final closePrice = _toDouble(
      order['close_price'] ?? order['current_price'],
    );
    final pnl = _toDouble(order['profit'] ?? order['pnl']);
    final swap = _toDouble(order['swap']);
    final commission = _toDouble(order['commission']);
    final openTime = _fmtTime(order['open_time'] ?? order['created_at']);
    final closeTime = _fmtTime(order['close_time'] ?? order['updated_at']);
    final orderId =
        (order['order_id'] ?? order['position_id'] ?? order['id'])
            ?.toString() ??
        '';
    final tp = _toDouble(order['take_profit']);
    final sl = _toDouble(order['stop_loss']);
    final cardColor = context.adaptiveCard;
    final textColor = context.adaptiveTextPrimary;
    final secondaryTextColor = context.adaptiveTextSecondary;
    final dividerColor = context.adaptiveDivider;
    final shadowColor = context.adaptiveIsDark
        ? Colors.black.withValues(alpha: 0.20)
        : Colors.black.withValues(alpha: 0.04);

    // 价格小数位
    final digits = _toInt(order['digits']) ?? 5;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 行1：方向 + 品种 + 手数 + 单号 ─────────────────────────
            Row(
              children: [
                _DirBadge(
                  isBuy: isBuy,
                  buyText: _text.t('stock_long'),
                  sellText: _text.t('stock_short'),
                ),
                const SizedBox(width: 8),
                Text(
                  sym,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '$lots ${_text.t('hand')}',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
                if (orderId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '#$orderId',
                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── 行2：开仓价 / 平仓价 / 盈亏 ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _KV(
                    label: _text.t('open_price_title'),
                    value: _fmtPriceD(openPrice, digits),
                  ),
                ),
                Expanded(
                  child: _KV(
                    label: _text.t('exit_price'),
                    value: _fmtPriceD(closePrice, digits),
                  ),
                ),
                Expanded(
                  child: _KV(
                    label: _text.t('profit_and_loss'),
                    value: '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}',
                    valueColor: pnl >= 0
                        ? CardTool.priceColor(1)
                        : CardTool.priceColor(-1),
                    align: CrossAxisAlignment.end,
                    bold: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── 行3：止盈止损（有值时显示）────────────────────────────
            if (tp > 0 || sl > 0) ...[
              Row(
                children: [
                  if (tp > 0)
                    Expanded(
                      child: _KV(
                        label: _text.t('take_profit'),
                        value: _fmtPriceD(tp, digits),
                        valueColor: _kGreen,
                      ),
                    ),
                  if (sl > 0)
                    Expanded(
                      child: _KV(
                        label: _text.t('stop_loss'),
                        value: _fmtPriceD(sl, digits),
                        valueColor: _kRed,
                      ),
                    ),
                  if (tp <= 0 || sl <= 0) const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── 行4：手续费/隔夜利息 ──────────────────────────────────
            if (swap != 0 || commission != 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (commission != 0)
                      Text(
                        '${_text.t('commission')} ${commission.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    if (swap != 0) ...[
                      if (commission != 0) const SizedBox(width: 12),
                      Text(
                        '${_text.t('overnight_interest_2')} ${swap.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // ── 行5：时间 ────────────────────────────────────────────
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 6),
            Row(
              children: [
                _TimeLabel(
                  icon: Icons.login,
                  label: _text.t('open_time'),
                  time: openTime,
                ),
                const Spacer(),
                _TimeLabel(
                  icon: Icons.logout,
                  label: _text.t('close_time'),
                  time: closeTime,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 工具
  // ─────────────────────────────────────────────

  Widget _buildError(String error, VoidCallback onRetry) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, size: 64, color: _kRed),
        const SizedBox(height: 16),
        Center(
          child: Text(error, style: const TextStyle(color: _kRed)),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: onRetry,
            child: Text(_text.t('retry')),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String message) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.history, size: 64, color: _kGrey),
        const SizedBox(height: 16),
        Center(
          child: Text(
            message,
            style: const TextStyle(color: _kGrey, fontSize: 16),
          ),
        ),
      ],
    );
  }

  int _dirInt(dynamic d) {
    if (d == null) return 0;
    if (d is int) return d;
    if (d is num) return d.toInt();
    final s = d.toString().toLowerCase();
    if (s == 'sell' || s == '1') return 1;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String _fmtPriceD(double price, int digits) {
    if (price == 0) return '--';
    return price.toStringAsFixed(digits.clamp(0, 8));
  }

  String _fmtTime(dynamic v) {
    if (v == null) return '--';
    final dt = _parseTime(v);
    if (dt == null) return v.toString();
    return formatIosYmdHm(dt, languageCode: _languageCode);
  }

  String get _languageCode =>
      languageCodeFromLocale(Localizations.localeOf(context));

  DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final ms = v > 1e10 ? v.toInt() : v.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.tryParse(v.toString());
  }
}

// ─────────────────────────────────────────────
// 子组件
// ─────────────────────────────────────────────

class _DirBadge extends StatelessWidget {
  final bool isBuy;
  final String buyText;
  final String sellText;
  const _DirBadge({
    required this.isBuy,
    required this.buyText,
    required this.sellText,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: (isBuy ? CardTool.priceColor(1) : CardTool.priceColor(-1))
          .withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      isBuy ? buyText : sellText,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isBuy ? CardTool.priceColor(1) : CardTool.priceColor(-1),
      ),
    ),
  );
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final CrossAxisAlignment align;
  final bool bold;

  const _KV({
    required this.label,
    required this.value,
    this.valueColor,
    this.align = CrossAxisAlignment.start,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11, color: context.adaptiveTextSecondary),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: valueColor ?? context.adaptiveTextPrimary,
        ),
      ),
    ],
  );
}

class _TimeLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  const _TimeLabel({
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 12, color: context.adaptiveTextSecondary),
      const SizedBox(width: 4),
      Text(
        '$label $time',
        style: TextStyle(fontSize: 11, color: context.adaptiveTextSecondary),
      ),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? selectedColor.withValues(alpha: 0.12)
            : context.adaptiveMutedBlock,
        borderRadius: BorderRadius.circular(20),
        border: selected ? Border.all(color: selectedColor, width: 1) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? selectedColor : context.adaptiveTextSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DatePickerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.adaptiveMutedBlock,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: context.adaptiveTextPrimary),
      ),
    ),
  );
}
