import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import 'trade_confirm_dialog.dart';
import 'trade_empty_state.dart';
import 'trade_position_action_sheet.dart';
import '../../shared/widgets/st_localized_prompt.dart';

/// 挂单列表页面
/// 对齐 iOS `STTradeController`：`limit = 20`、`offset = limit * page`；
/// 撤单 `delete`：`order_id` + `symbol`；改单 `pending/update`：与详情页一致字段（不含改手数）。
class PendingOrderPage extends ConsumerStatefulWidget {
  final String? languageCodeOverride;

  const PendingOrderPage({super.key, this.languageCodeOverride});

  @override
  ConsumerState<PendingOrderPage> createState() => _PendingOrderPageState();
}

bool _orderIsLimit(Map<String, dynamic> order) {
  final pt = order['pending_type'];
  if (pt == 0 || pt == '0') return true;
  if (pt == 1 || pt == '1') return false;
  final t = order['type']?.toString().toLowerCase() ?? '';
  return !t.contains('stop');
}

bool _orderIsBuy(Map<String, dynamic> order) {
  final d = order['direction'];
  if (d == null) return true;
  if (d is num) return d.toInt() == 0;
  final s = d.toString().toLowerCase();
  if (s == '1' || s == 'sell') return false;
  return true;
}

class _PendingOrderPageState extends ConsumerState<PendingOrderPage> {
  static const int _kLimit = 20;
  static const Map<String, String> _fallbackText = {
    'pending_orders': '挂单',
    'limit_price': '限价',
    'stop_order': '停损单',
    'buy': '买入',
    'sell': '卖出',
    'hand': '手',
    'entrust_price': '委托价',
    'current_price': '当前价',
    'pending_time': '挂单时间',
    'modify': '修改',
    'cancel_order': '撤单',
    'no_pending_orders': '暂无挂单',
    'order_canceled': '订单已撤销',
    'order_cancel_failed': '撤单失败',
    'modify_success': '修改成功',
    'modify_fail': '修改失败',
    'flutter_prompt_enter_valid_pending_price': '请输入有效的挂单价格',
    'flutter_prompt_load_more_failed': '加载更多失败',
    'dkplayer_retry': '重试',
  };

  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _pendingOrders = [];
  int _pageIndex = 0;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _errorMessage;
  String? _languageCode;
  Future<Map<String, String>>? _localizedTextFuture;
  Map<String, String> _text = _fallbackText;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _ensureLocalizedTexts() {
    final languageCode =
        widget.languageCodeOverride ?? stLanguageCodeOfContext(context);
    if (_localizedTextFuture != null && _languageCode == languageCode) {
      return _localizedTextFuture!;
    }
    _languageCode = languageCode;
    _localizedTextFuture = STLocalizations(
      bundle: ref.read(iosLanguageBundleProvider),
      languageCode: languageCode,
    ).textMap(_fallbackText);
    return _localizedTextFuture!;
  }

  String _t(String key) => _text[key] ?? _fallbackText[key] ?? key;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_loadingMore || !_hasMore || _isLoading) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels < pos.maxScrollExtent - 200) return;
    _loadMore();
  }

  Future<void> _fetchFirstPage({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || !_hasLoadedOnce;
    setState(() {
      _isLoading = shouldShowLoading;
      if (shouldShowLoading) {
        _errorMessage = null;
      }
    });
    try {
      final stService = ref.read(stServiceProvider);
      final page = await stService.getPendingOrdersWithTotal(
        offset: 0,
        limit: _kLimit,
      );
      final batch = page.orders.whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _pendingOrders = batch;
        _pageIndex = 0;
        _hasLoadedOnce = true;
        _hasMore = page.total > 0
            ? _pendingOrders.length < page.total
            : batch.length >= _kLimit;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        if (shouldShowLoading) {
          setState(() {
            _errorMessage = stUserVisibleErrorMessage(e);
            _isLoading = false;
          });
        } else {
          showStLocalizedPrompt(
            context,
            _t('flutter_prompt_load_more_failed'),
            error: e,
          );
        }
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _pageIndex + 1;
      final stService = ref.read(stServiceProvider);
      final page = await stService.getPendingOrdersWithTotal(
        offset: nextPage * _kLimit,
        limit: _kLimit,
      );
      final batch = page.orders.whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        if (batch.isEmpty) {
          _hasMore = false;
        } else {
          _pageIndex = nextPage;
          _pendingOrders.addAll(batch);
          _hasMore = page.total > 0
              ? _pendingOrders.length < page.total
              : batch.length >= _kLimit;
        }
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        showStLocalizedPrompt(
          context,
          _t('flutter_prompt_load_more_failed'),
          error: e,
        );
      }
    }
  }

  String _fmtPrice(dynamic value) {
    if (value == null) return '--';
    final num v = (value is num)
        ? value
        : double.tryParse(value.toString()) ?? 0;
    return v.toStringAsFixed(5);
  }

  String _fmtTime(dynamic value) {
    if (value == null) return '--';
    return value.toString();
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final orderId =
        order['order_id']?.toString() ?? order['id']?.toString() ?? '';
    if (orderId.isEmpty) return;
    final symbol = order['symbol']?.toString() ?? '';

    final confirm = await showTradeCancelOrderDialog(
      context: context,
      orderId: orderId,
    );

    if (confirm != true) return;

    try {
      final stService = ref.read(stServiceProvider);
      final payload = <String, dynamic>{'symbol': symbol};
      final oid = int.tryParse(orderId);
      payload['order_id'] = oid ?? orderId;
      await stService.deleteOrder(payload);
      await _fetchFirstPage();
      if (mounted) {
        showStLocalizedPrompt(context, _t('order_canceled'));
      }
    } catch (e) {
      if (mounted) {
        showStLocalizedPrompt(context, _t('order_cancel_failed'), error: e);
      }
    }
  }

  Future<void> _editOrder(Map<String, dynamic> order) async {
    final orderId =
        order['order_id']?.toString() ?? order['id']?.toString() ?? '';
    if (orderId.isEmpty) return;

    final result = await showTradePendingEditPayloadSheet(
      context: context,
      order: order,
    );

    if (result == null) return;

    try {
      final px = double.tryParse(result['price']?.toString() ?? '') ?? 0;
      if (px <= 0) {
        if (mounted) {
          showStLocalizedPrompt(
            context,
            _t('flutter_prompt_enter_valid_pending_price'),
          );
        }
        return;
      }
      final stService = ref.read(stServiceProvider);
      final payload = <String, dynamic>{
        'symbol': result['symbol'],
        'price': result['price'],
        'take_profit': result['take_profit'],
        'stop_loss': result['stop_loss'],
        'expire_time': result['expire_time'],
      };
      final oid = int.tryParse(orderId);
      payload['order_id'] = oid ?? orderId;
      await stService.editPendingOrder(payload);
      await _fetchFirstPage();
      if (mounted) {
        showStLocalizedPrompt(context, _t('modify_success'));
      }
    } catch (e) {
      if (mounted) {
        showStLocalizedPrompt(context, _t('modify_fail'), error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _ensureLocalizedTexts(),
      initialData: _text,
      builder: (context, snapshot) {
        _text = snapshot.data ?? _fallbackText;
        final navBg = context.adaptiveSurfacePrimary;
        final textColor = context.adaptiveTextPrimary;
        return Scaffold(
          backgroundColor: context.adaptivePageGrey,
          appBar: AppBar(
            title: _LocalizedKeyText(
              text: _t('pending_orders'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            centerTitle: true,
            backgroundColor: navBg,
            foregroundColor: textColor,
            surfaceTintColor: navBg,
            elevation: 0,
          ),
          body: STPullRefresh(
            onRefresh: () => _fetchFirstPage(showLoading: false),
            child: _isLoading
                ? const Center(child: STLoadAnimationView())
                : _errorMessage != null
                ? _buildErrorView()
                : _pendingOrders.isEmpty
                ? _buildEmptyView()
                : _buildList(),
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _fetchFirstPage,
            child: Text(_t('dkplayer_retry')),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return TradeNoRecordsEmpty(
      message: _t('no_pending_orders'),
      scrollable: true,
      height: 300,
    );
  }

  Widget _buildList() {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _pendingOrders.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _pendingOrders.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _buildOrderCard(_pendingOrders[index]);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final symbol = order['symbol'] as String? ?? '---';
    final isLimit = _orderIsLimit(order);
    final isBuy = _orderIsBuy(order);
    final volume =
        order['lots']?.toString() ?? order['volume']?.toString() ?? '--';
    final price = order['pending_price'] ?? order['price'] ?? 0;
    final currentPrice = order['current_price'] ?? order['last_price'] ?? 0;
    final createTime = order['create_time'] ?? order['created_at'] ?? '--';
    final status = order['status']?.toString() ?? 'pending';
    final orderId =
        order['order_id']?.toString() ?? order['id']?.toString() ?? '';
    final textColor = context.adaptiveTextPrimary;
    final secondaryTextColor = context.adaptiveTextSecondary;

    return Dismissible(
      key: Key('pending_$orderId'),
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _cancelOrder(order);
        return false;
      },
      child: Card(
        color: context.adaptiveCard,
        surfaceTintColor: context.adaptiveCard,
        elevation: context.adaptiveIsDark ? 0 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    symbol,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _LocalizedKeyText(
                      text: _t(isLimit ? 'limit_price' : 'stop_order'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isBuy ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _LocalizedKeyText(
                      text: _t(isBuy ? 'buy' : 'sell'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBuy ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$volume ${_t("hand")}',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'pending'
                          ? Colors.orange[50]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: status == 'pending'
                            ? Colors.orange[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                      _t('entrust_price'),
                      _fmtPrice(price),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      _t('current_price'),
                      _fmtPrice(currentPrice),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${_t("pending_time")}: ${_fmtTime(createTime)}',
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editOrder(order),
                    icon: const Icon(Icons.edit, size: 16),
                    label: _LocalizedKeyText(
                      text: _t('modify'),
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _cancelOrder(order),
                    icon: const Icon(Icons.close, size: 16),
                    label: _LocalizedKeyText(
                      text: _t('cancel_order'),
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
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

  Widget _buildInfoColumn(String label, String value) {
    final labelColor = context.adaptiveTextSecondary;
    final valueColor = context.adaptiveTextPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocalizedKeyText(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, color: valueColor)),
      ],
    );
  }
}

class _LocalizedKeyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _LocalizedKeyText({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}
