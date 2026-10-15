import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/providers/event_bus.dart';
import '../../core/services/ios_language_bundle.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../core/utils/ios_date_range.dart';
import '../../shared/widgets/ios_date_picker_sheet.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import 'trade_account_detail_cell_contract.dart';
import 'trade_alignment.dart';
import 'trade_ios_chrome.dart';
import 'trade_order_live_update.dart';

enum TradePositionActionKind { positionStopLoss, pendingEdit }

class TradePositionActionResult {
  const TradePositionActionResult({
    this.price,
    required this.takeProfit,
    required this.stopLoss,
    this.expireTime,
    required this.profitOn,
    required this.stopLossOn,
  });

  final String? price;
  final String takeProfit;
  final String stopLoss;
  final int? expireTime;
  final bool profitOn;
  final bool stopLossOn;
}

Future<TradePositionActionResult?> showTradePositionActionSheet({
  required BuildContext context,
  required TradePositionActionKind kind,
  required Map<String, dynamic> order,
  ValueListenable<Map<String, dynamic>>? orderListenable,
  String? languageCode,
}) {
  return showModalBottomSheet<TradePositionActionResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: true,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: TradePositionActionSheet(
        kind: kind,
        order: order,
        orderListenable: orderListenable,
        languageCode: languageCode ?? stLanguageCodeOfContext(context),
      ),
    ),
  );
}

Future<Map<String, dynamic>?> showTradePositionStopLossPayloadSheet({
  required BuildContext context,
  required Map<String, dynamic> order,
  ValueListenable<Map<String, dynamic>>? orderListenable,
}) async {
  final result = await showTradePositionActionSheet(
    context: context,
    kind: TradePositionActionKind.positionStopLoss,
    order: order,
    orderListenable: orderListenable,
  );
  if (result == null) return null;
  final orderId = _idValue(order, const [
    'position_id',
    'positionId',
    'order_id',
    'id',
  ]);
  return {
    'position_id': orderId,
    'symbol': _symbolValue(order),
    'take_profit': result.takeProfit,
    'stop_loss': result.stopLoss,
  };
}

Future<Map<String, dynamic>?> showTradePendingEditPayloadSheet({
  required BuildContext context,
  required Map<String, dynamic> order,
  ValueListenable<Map<String, dynamic>>? orderListenable,
}) async {
  final result = await showTradePositionActionSheet(
    context: context,
    kind: TradePositionActionKind.pendingEdit,
    order: order,
    orderListenable: orderListenable,
  );
  if (result == null) return null;
  final orderId = _idValue(order, const ['order_id', 'orderId', 'id']);
  return {
    'order_id': orderId,
    'symbol': _symbolValue(order),
    'price': result.price ?? '',
    'take_profit': result.takeProfit,
    'stop_loss': result.stopLoss,
    if (result.expireTime != null) 'expire_time': result.expireTime,
  };
}

@visibleForTesting
class TradePositionActionSheet extends StatefulWidget {
  const TradePositionActionSheet({
    super.key,
    required this.kind,
    required this.order,
    this.orderListenable,
    this.languageCode,
  });

  final TradePositionActionKind kind;
  final Map<String, dynamic> order;
  final ValueListenable<Map<String, dynamic>>? orderListenable;
  final String? languageCode;

  @override
  State<TradePositionActionSheet> createState() =>
      _TradePositionActionSheetState();
}

class _TradePositionActionSheetState extends State<TradePositionActionSheet> {
  static const Color _fall = Color(0xFFF95959);
  static const Map<String, String> _fallbackText = {
    'stop_loss_and_take_profit': '止盈/止损',
    'modify': '修改',
    'price': '价格',
    'take_profit': '止盈',
    'stop_loss': '止损',
    'estimated_profit_loss': '预估盈亏',
    'select_validity_period': '选择有效期',
    'cancel': '取消',
    'confirm_other': '确认',
    'price_out_of_range': '开仓价格无效',
    'profit_out_of_range': '止盈价格无效',
    'stoploss_out_of_range': '止损价格无效',
    'target_profit_frozen_level_tip': '止盈价格处在冻结区，无法修改。',
    'stop_loss_frozen_level_tip': '止损价格处在冻结区，无法修改。',
    'buy': '买入',
    'sell': '卖出',
  };

  late final TextEditingController _priceController;
  late final TextEditingController _targetProfitController;
  late final TextEditingController _stopLossController;
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _targetProfitFocus = FocusNode();
  final FocusNode _stopLossFocus = FocusNode();
  late Map<String, dynamic> _liveOrder;
  late bool _profitOn;
  late bool _stopLossOn;
  late DateTime _validityDay;
  Map<String, String> _labels = _fallbackText;
  String? _languageCode;
  String? _errorMessage;
  void Function(Object? data)? _eventListener;

  bool get _isPending => widget.kind == TradePositionActionKind.pendingEdit;
  Map<String, dynamic> get _order => _liveOrder;
  String _t(String key) => _labels[key] ?? _fallbackText[key] ?? key;

  @override
  void initState() {
    super.initState();
    _liveOrder = Map<String, dynamic>.from(widget.order);
    widget.orderListenable?.addListener(_handleListenableOrderChanged);
    _eventListener = (payload) {
      if (payload is Map) {
        _mergeLiveOrder(Map<String, dynamic>.from(payload));
      }
    };
    EventBus().onData(EventBus.tradeActionViewRefresh, _eventListener!);
    final order = _order;
    final pendingPrice = _firstText(order, const [
      'pending_price',
      'pendingPrice',
      'price',
      'pending',
    ]);
    _priceController = TextEditingController(text: _visibleValue(pendingPrice));

    final originalProfit = _firstText(order, const [
      'take_profit',
      'target_profit',
      'targetProfit',
      'tp',
    ]);
    final originalStopLoss = _firstText(order, const [
      'stop_loss',
      'stopLosss',
      'stopLoss',
      'sl',
    ]);
    _profitOn = _switchOnFromOriginal(originalProfit);
    _stopLossOn = _switchOnFromOriginal(originalStopLoss);

    final targetDefault = _firstText(order, const [
      'target_profit_min',
      'targetProfitMin',
      'take_profit_min',
      'takeProfitMin',
      'tp_min',
    ]);
    final stopDefault = _firstText(order, const [
      'stop_loss_max',
      'stopLosssMax',
      'stopLossMax',
      'sl_max',
    ]);
    _targetProfitController = TextEditingController(
      text: _visibleTpslValue(originalProfit).isNotEmpty
          ? _visibleTpslValue(originalProfit)
          : _visibleValue(targetDefault),
    );
    _stopLossController = TextEditingController(
      text: _visibleTpslValue(originalStopLoss).isNotEmpty
          ? _visibleTpslValue(originalStopLoss)
          : _visibleValue(stopDefault),
    );
    _validityDay = _validityDayFromOrder(order);
    if (_isPending) {
      _refreshPendingDerivedFields(_priceController.text, notify: false);
    }
    final languageCode = widget.languageCode;
    if (languageCode != null && languageCode.isNotEmpty) {
      _loadLabelsFor(
        STLocalizations(
          bundle: IosLanguageBundle(),
          languageCode: languageCode,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant TradePositionActionSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.orderListenable, widget.orderListenable)) {
      oldWidget.orderListenable?.removeListener(_handleListenableOrderChanged);
      widget.orderListenable?.addListener(_handleListenableOrderChanged);
    }
    if (widget.orderListenable == null &&
        !identical(oldWidget.order, widget.order)) {
      _mergeLiveOrder(widget.order);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLabels();
  }

  @override
  void dispose() {
    widget.orderListenable?.removeListener(_handleListenableOrderChanged);
    final listener = _eventListener;
    if (listener != null) {
      EventBus().offData(EventBus.tradeActionViewRefresh, listener);
    }
    _priceController.dispose();
    _targetProfitController.dispose();
    _stopLossController.dispose();
    _priceFocus.dispose();
    _targetProfitFocus.dispose();
    _stopLossFocus.dispose();
    super.dispose();
  }

  void _handleListenableOrderChanged() {
    final next = widget.orderListenable?.value;
    if (next == null) return;
    _mergeLiveOrder(next);
  }

  void _mergeLiveOrder(Map<String, dynamic> update) {
    if (!TradeOrderLiveUpdate.matches(_liveOrder, update)) return;
    setState(() {
      _liveOrder = TradeOrderLiveUpdate.merge(_liveOrder, update);
      _errorMessage = null;
    });
  }

  void _loadLabels() {
    final localizations = widget.languageCode == null
        ? STLocalizations.ofContext(context)
        : STLocalizations(
            bundle: IosLanguageBundle(),
            languageCode: widget.languageCode!,
          );
    _loadLabelsFor(localizations);
  }

  void _loadLabelsFor(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    localizations.textMap(_fallbackText).then((labels) {
      if (!mounted || _languageCode != languageCode) return;
      setState(() => _labels = labels);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isPending ? _t('modify') : _t('stop_loss_and_take_profit');
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final keyboardFocusNodes = [
      if (_isPending) _priceFocus,
      if (_profitOn) _targetProfitFocus,
      if (_stopLossOn) _stopLossFocus,
    ];
    return STKeyboardActions(
      isDialog: true,
      focusNodes: keyboardFocusNodes,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const ValueKey('trade-position-action-sheet-root'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: BoxDecoration(
            color: context.adaptiveSurfacePrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 15),
                Center(
                  child: Text(
                    title,
                    key: const ValueKey('trade-position-action-sheet-title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      color: context.adaptiveTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildHeader(),
                if (_isPending) ...[
                  const SizedBox(height: 22),
                  _buildPriceField(),
                ],
                SizedBox(height: _isPending ? 17 : 45),
                _buildTargetProfitRow(),
                SizedBox(height: _profitOn ? 15 : 8),
                _buildStopLossRow(),
                if (_isPending) ...[
                  const SizedBox(height: 22),
                  _buildValidityRow(),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 13, color: _fall),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final order = _order;
    final symbol = _firstText(order, const ['symbol', 'symbol_code']);
    final alias = _firstText(order, const ['symbol_alias', 'symbolAlias']);
    final openPrice = _firstText(order, const [
      'open_price',
      'openPrice',
      'pending_price',
      'pendingPrice',
      'price',
    ], fallback: '--');
    final currentPrice = _firstText(order, const [
      'current_price',
      'currentPrice',
      'market_price',
      'marketPrice',
      'price',
    ], fallback: '--');
    final isBuy = _isBuy(order);
    return Padding(
      key: const ValueKey('trade-position-action-native-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  symbol.isEmpty ? '--' : symbol,
                  key: const ValueKey('trade-position-action-symbol-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.15,
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (alias.isNotEmpty) ...[
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      color: context.adaptiveTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _DirectionBadge(
                isBuy: isBuy,
                buyText: _t('buy'),
                sellText: _t('sell'),
              ),
              const SizedBox(width: 5),
              _LotBadge(text: tradeAccountDetailLotText(order)),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            '${openPrice.isEmpty ? '--' : openPrice} → ${currentPrice.isEmpty ? '--' : currentPrice}',
            style: TextStyle(
              fontSize: 14,
              height: 1.1,
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField() {
    final range = _priceRange();
    return _LabeledInput(
      key: const ValueKey('trade-position-action-price-section'),
      label: _t('price'),
      range: _pendingPriceRangeLabel(range),
      controller: _priceController,
      focusNode: _priceFocus,
      fieldKey: const ValueKey('trade-position-action-price-field'),
      valueColor: _inputColor(_priceController, range),
      minusEnabled: _canStepDown(_priceController, range),
      plusEnabled: _canStepUp(_priceController, range),
      onMinus: () => _step(_priceController, -_priceStep()),
      onPlus: () => _step(_priceController, _priceStep()),
      onChanged: _handlePendingPriceChanged,
    );
  }

  Widget _buildTargetProfitRow() {
    final range = _targetProfitRange();
    return _SwitchInput(
      label: _t('take_profit'),
      switchKey: const ValueKey('trade-position-action-tp-switch'),
      fieldKey: const ValueKey('trade-position-action-tp-field'),
      enabled: _profitOn,
      range: _profitRangeLabel(range),
      controller: _targetProfitController,
      focusNode: _targetProfitFocus,
      expectedValue: _expectedProfitText(isProfit: true),
      trailingLabel: _t('estimated_profit_loss'),
      valueColor: _inputColor(_targetProfitController, range),
      minusEnabled: _canStepDown(_targetProfitController, range),
      plusEnabled: _canStepUp(_targetProfitController, range),
      onToggle: (value) => setState(() {
        _profitOn = value;
        _errorMessage = null;
      }),
      onMinus: () => _step(_targetProfitController, -_priceStep()),
      onPlus: () => _step(_targetProfitController, _priceStep()),
      onChanged: _handleTextChanged,
    );
  }

  Widget _buildStopLossRow() {
    final range = _stopLossRange();
    return _SwitchInput(
      label: _t('stop_loss'),
      switchKey: const ValueKey('trade-position-action-sl-switch'),
      fieldKey: const ValueKey('trade-position-action-sl-field'),
      enabled: _stopLossOn,
      range: _stopLossRangeLabel(range),
      controller: _stopLossController,
      focusNode: _stopLossFocus,
      expectedValue: _expectedProfitText(isProfit: false),
      trailingLabel: _t('estimated_profit_loss'),
      valueColor: _inputColor(_stopLossController, range),
      minusEnabled: _canStepDown(_stopLossController, range),
      plusEnabled: _canStepUp(_stopLossController, range),
      onToggle: (value) => setState(() {
        _stopLossOn = value;
        _errorMessage = null;
      }),
      onMinus: () => _step(_stopLossController, -_priceStep()),
      onPlus: () => _step(_stopLossController, _priceStep()),
      onChanged: _handleTextChanged,
    );
  }

  Widget _buildValidityRow() {
    return InkWell(
      onTap: _pickValidity,
      child: SizedBox(
        height: 29,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Row(
            children: [
              Text(
                _t('select_validity_period'),
                style: TextStyle(
                  fontSize: 13,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatIosYmd(
                  _validityDay,
                  languageCode: languageCodeFromLocale(
                    Localizations.localeOf(context),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: context.adaptiveTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: context.adaptivePlaceholderSurface,
                  foregroundColor: context.adaptiveTextPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  _t('cancel'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('trade-position-action-confirm'),
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF00B57A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  _t('confirm_other'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickValidity() async {
    final today = _calendarDayOnly(DateTime.now());
    final picked = await showIosDatePickerSheet(
      context: context,
      initialDate: _validityDay.isBefore(today) ? today : _validityDay,
      minimumDate: today,
      maximumDate: DateTime(2050, 12, 30),
    );
    if (picked == null) return;
    setState(() => _validityDay = _calendarDayOnly(picked));
  }

  void _confirm() {
    final price = _priceController.text.trim();
    if (_isPending) {
      if (price.isEmpty || !_priceRange().containsText(price)) {
        _setError(_t('price_out_of_range'));
        return;
      }
    }

    final profit = _targetProfitController.text.trim();
    if (_profitOn) {
      if (profit.isEmpty || !_targetProfitRange().containsText(profit)) {
        _setError(_t('profit_out_of_range'));
        return;
      }
    }
    if (profit.isNotEmpty && !_enableCommitProfit()) {
      _setError(_t('target_profit_frozen_level_tip'));
      return;
    }

    final stopLoss = _stopLossController.text.trim();
    if (_stopLossOn) {
      if (stopLoss.isEmpty || !_stopLossRange().containsText(stopLoss)) {
        _setError(_t('stoploss_out_of_range'));
        return;
      }
    }
    if (stopLoss.isNotEmpty && !_enableCommitStopLoss()) {
      _setError(_t('stop_loss_frozen_level_tip'));
      return;
    }

    Navigator.of(context).pop(
      TradePositionActionResult(
        price: _isPending ? price : null,
        takeProfit: _profitOn && profit.isNotEmpty ? profit : '0',
        stopLoss: _stopLossOn && stopLoss.isNotEmpty ? stopLoss : '0',
        expireTime: _isPending ? _endOfDayUnixSeconds(_validityDay) : null,
        profitOn: _profitOn,
        stopLossOn: _stopLossOn,
      ),
    );
  }

  void _setError(String message) {
    setState(() => _errorMessage = message);
  }

  void _handlePendingPriceChanged(String value) {
    _refreshPendingDerivedFields(value, notify: false);
    setState(() => _errorMessage = null);
  }

  void _handleTextChanged(String _) {
    setState(() => _errorMessage = null);
  }

  Color _inputColor(TextEditingController controller, _NumericRange range) {
    final text = controller.text.trim();
    if (text.isEmpty || range.containsText(text)) {
      return context.adaptiveIsDark
          ? context.adaptiveTextPrimary
          : _TradeColors.text;
    }
    return _fall;
  }

  bool _canStepDown(TextEditingController controller, _NumericRange range) {
    final current = double.tryParse(controller.text.trim()) ?? 0;
    return range.min == null || current > range.min!;
  }

  bool _canStepUp(TextEditingController controller, _NumericRange range) {
    final current = double.tryParse(controller.text.trim()) ?? 0;
    return range.max == null || current < range.max!;
  }

  void _refreshPendingDerivedFields(String value, {required bool notify}) {
    final pending = double.tryParse(value.trim());
    final pips = double.tryParse(
      _firstText(_liveOrder, const ['pips', 'min_pips', 'minPips']),
    );
    if (pending == null || pips == null) {
      if (notify) setState(() => _errorMessage = null);
      return;
    }
    final next = Map<String, dynamic>.from(_liveOrder);
    next['pending_price'] = value.trim();
    if (_isBuy(next)) {
      next['target_profit_min'] = _trimDouble(pending + pips);
      next['stop_loss_max'] = _trimDouble(pending - pips);
    } else {
      next['target_profit_max'] = _trimDouble(pending - pips);
      next['stop_loss_min'] = _trimDouble(pending + pips);
    }
    if (notify) {
      setState(() => _liveOrder = next);
      return;
    }
    _liveOrder = next;
  }

  _NumericRange _priceRange() {
    return _NumericRange.fromOrder(
      _order,
      minKeys: const [
        'pending_min_price',
        'pendingMinPrice',
        'pending_price_min',
        'pendingPriceMin',
        'pending_min',
      ],
      maxKeys: const [
        'pending_max_price',
        'pendingMaxPrice',
        'pending_price_max',
        'pendingPriceMax',
        'pending_max',
      ],
    );
  }

  _NumericRange _targetProfitRange() {
    return _NumericRange.fromOrder(
      _order,
      minKeys: const [
        'target_profit_min',
        'targetProfitMin',
        'take_profit_min',
        'takeProfitMin',
        'tp_min',
      ],
      maxKeys: const [
        'target_profit_max',
        'targetProfitMax',
        'take_profit_max',
        'takeProfitMax',
        'tp_max',
      ],
    );
  }

  _NumericRange _stopLossRange() {
    return _NumericRange.fromOrder(
      _order,
      minKeys: const ['stop_loss_min', 'stopLosssMin', 'stopLossMin', 'sl_min'],
      maxKeys: const ['stop_loss_max', 'stopLosssMax', 'stopLossMax', 'sl_max'],
    );
  }

  String _profitRangeLabel(_NumericRange range) {
    if (_isBuy(_order) && range.minText.isNotEmpty) {
      return '≥${range.minText}';
    }
    if (!_isBuy(_order) && range.maxText.isNotEmpty) {
      return '≤${range.maxText}';
    }
    return range.label;
  }

  String _stopLossRangeLabel(_NumericRange range) {
    if (_isBuy(_order) && range.maxText.isNotEmpty) {
      return '≤${range.maxText}';
    }
    if (!_isBuy(_order) && range.minText.isNotEmpty) {
      return '≥${range.minText}';
    }
    return range.label;
  }

  String _pendingPriceRangeLabel(_NumericRange range) {
    final isLimit = _pendingAction(_order) == 1;
    final isBuy = _isBuy(_order);
    if (isLimit) {
      if (isBuy && range.maxText.isNotEmpty) return '≤${range.maxText}';
      if (!isBuy && range.minText.isNotEmpty) return '≥${range.minText}';
    } else {
      if (isBuy && range.minText.isNotEmpty) return '≥${range.minText}';
      if (!isBuy && range.maxText.isNotEmpty) return '≤${range.maxText}';
    }
    return range.label;
  }

  String _expectedProfitText({required bool isProfit}) {
    final calculated = _calculatedExpectedProfit(isProfit: isProfit);
    if (calculated != null) return calculated;
    final keys = isProfit
        ? const [
            'target_profit_expected',
            'targetProfitExpected',
            'target_expected_profit',
            'take_profit_expected',
            'tp_expected',
          ]
        : const [
            'stop_loss_expected',
            'stopLossExpected',
            'stop_expected_profit',
            'sl_expected',
          ];
    final text = _firstText(_order, keys);
    if (text.isEmpty) return '--';
    final number = double.tryParse(text);
    if (number == null) return text;
    final sign = number > 0 ? '+' : '';
    return '$sign${number.toStringAsFixed(2)}';
  }

  String? _calculatedExpectedProfit({required bool isProfit}) {
    final openPrice = _isPending
        ? _priceController.text.trim()
        : _firstText(_order, const ['open_price', 'openPrice']);
    final result = TradeExpectedProfit.calculate(
      isBuy: _isBuy(_order),
      openPrice: openPrice,
      closePrice: (isProfit ? _targetProfitController : _stopLossController)
          .text
          .trim(),
      lotText: _firstText(_order, const [
        'lots',
        'set_lot',
        'setLot',
        'volume',
      ]),
      contractSize: _firstText(_order, const ['contract_size', 'contractSize']),
      conversionRate: _conversionRate(_order),
    );
    if (result == '--') return null;
    final number = double.tryParse(result);
    if (number == null) return result;
    final sign = number > 0 ? '+' : '';
    return '$sign${number.toStringAsFixed(2)}';
  }

  bool _enableCommitProfit() {
    final targetProfit = _firstText(_order, const [
      'target_profit',
      'targetProfit',
      'take_profit',
      'takeProfit',
      'tp',
    ]);
    return _outsideFreezeLevel(targetProfit);
  }

  bool _enableCommitStopLoss() {
    final stopLoss = _firstText(_order, const [
      'stop_loss',
      'stopLosss',
      'stopLoss',
      'sl',
    ]);
    return _outsideFreezeLevel(stopLoss);
  }

  bool _outsideFreezeLevel(String originalPrice) {
    final original = _visibleTpslValue(originalPrice);
    if (original.isEmpty) return true;
    final current = _firstText(_order, const [
      'current_price',
      'currentPrice',
      'market_price',
      'marketPrice',
    ]);
    if (current.isEmpty) return true;
    final currentValue = double.tryParse(current);
    final originalValue = double.tryParse(original);
    if (currentValue == null || originalValue == null) return true;
    final freeze = double.tryParse(
      _firstText(_order, const [
        'freeze_level',
        'freezeLevel',
        'frozen_level',
        'frozenLevel',
      ], fallback: '0'),
    );
    if (freeze == null) return true;
    return (currentValue - originalValue).abs() > freeze;
  }

  void _step(TextEditingController controller, double delta) {
    final current = double.tryParse(controller.text.trim()) ?? 0;
    final next = current + delta;
    controller.text = _trimDouble(next);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    if (_isPending && identical(controller, _priceController)) {
      _refreshPendingDerivedFields(controller.text, notify: false);
    }
    setState(() => _errorMessage = null);
  }

  double _priceStep() {
    final text = _firstText(_order, const [
      'step_price',
      'stepPrice',
      'price_step',
      'priceStep',
      'digits_step',
    ]);
    final value = double.tryParse(text);
    if (value != null && value > 0) return value;
    return 0.01;
  }

  static bool _switchOnFromOriginal(String value) {
    return _visibleTpslValue(value).isNotEmpty;
  }

  static bool _isBuy(Map<String, dynamic> order) {
    final raw = _firstText(order, const [
      'direction',
      'cmd',
      'cmd_type',
      'cmdType',
      'trade_direction',
    ]);
    final lower = raw.toLowerCase();
    if (lower.contains('sell') || lower == '1') return false;
    return true;
  }

  static int _pendingAction(Map<String, dynamic> order) {
    final raw = _firstText(order, const [
      'action',
      'order_action',
      'orderAction',
      'pending_type',
      'pendingType',
      'order_type',
      'orderType',
    ]);
    final lower = raw.toLowerCase();
    if (lower.contains('stop')) return 2;
    if (lower.contains('limit')) return 1;
    final value = int.tryParse(raw);
    if (value != null) return value;
    return 1;
  }

  static String _visibleValue(String value) {
    final text = value.trim();
    if (text.isEmpty || text == '-1' || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  static String _visibleTpslValue(String value) {
    final text = _visibleValue(value);
    // iOS STTradeOrderModel normalizes server 0 TP/SL values to the unset sentinel.
    if (text == '0') return '';
    final number = double.tryParse(text);
    if (number != null && number == 0) return '';
    return text;
  }

  static String _firstText(
    Map<String, dynamic> order,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = order[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  static DateTime _validityDayFromOrder(Map<String, dynamic> order) {
    final expireText = _firstText(order, const [
      'expire_time',
      'expireTime',
      'expiration',
      'expiration_time',
    ]);
    final expire = int.tryParse(expireText);
    if (expire != null && expire > 0) {
      return _calendarDayOnly(
        DateTime.fromMillisecondsSinceEpoch(expire * 1000),
      );
    }
    final now = DateTime.now();
    return _calendarDayOnly(now).add(const Duration(days: 6));
  }

  static DateTime _calendarDayOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static int _endOfDayUnixSeconds(DateTime date) {
    return DateTime(
          date.year,
          date.month,
          date.day,
          23,
          59,
          59,
        ).millisecondsSinceEpoch ~/
        1000;
  }

  static String _trimDouble(double value) {
    final rounded = value.toStringAsFixed(8);
    return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static double _conversionRate(Map<String, dynamic> order) {
    final explicit = _number(
      _firstText(order, const [
        'conversion_rate',
        'conversionRate',
        'profit_conversion_rate',
        'profitCurrencyToAccountRate',
      ]),
    );
    if (explicit > 0) return explicit;
    final profitToUsd = _number(
      _firstText(order, const [
        'profit_currency_to_usd_rate',
        'profitCurrencyToUsdRate',
      ]),
    );
    final usdToAccount = _number(
      _firstText(order, const [
        'usd_to_account_currency_rate',
        'usdToAccountCurrencyRate',
      ]),
    );
    if (profitToUsd > 0 && usdToAccount > 0) {
      return profitToUsd * usdToAccount;
    }
    return 1;
  }

  static double _number(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }
}

Object _idValue(Map<String, dynamic> order, List<String> keys) {
  final value = _TradePositionActionSheetState._firstText(order, keys);
  return int.tryParse(value) ?? value;
}

String _symbolValue(Map<String, dynamic> order) {
  return _TradePositionActionSheetState._firstText(order, const [
    'symbol',
    'symbol_code',
    'symbolCode',
  ]);
}

class _SwitchInput extends StatelessWidget {
  const _SwitchInput({
    required this.label,
    required this.switchKey,
    required this.fieldKey,
    required this.enabled,
    required this.range,
    required this.controller,
    required this.focusNode,
    required this.expectedValue,
    required this.trailingLabel,
    required this.valueColor,
    required this.minusEnabled,
    required this.plusEnabled,
    required this.onToggle,
    required this.onMinus,
    required this.onPlus,
    this.onChanged,
  });

  final String label;
  final Key switchKey;
  final Key fieldKey;
  final bool enabled;
  final String range;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String expectedValue;
  final String trailingLabel;
  final Color valueColor;
  final bool minusEnabled;
  final bool plusEnabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: TradeIosSwitchSlot.height,
          child: Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Row(
              children: [
                SizedBox(
                  key: switchKey,
                  width: _ActionSheetSwitchSlot.width,
                  child: _ActionSheetSwitchSlot(
                    value: enabled,
                    onChanged: onToggle,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1,
                    color: context.adaptiveTextTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 5),
          _LabeledInput(
            label: label,
            range: range,
            controller: controller,
            focusNode: focusNode,
            fieldKey: fieldKey,
            trailingLabel: trailingLabel,
            trailingValue: expectedValue,
            trailingValueColor: expectedValue.startsWith('-')
                ? _TradeColors.fall
                : _TradeColors.rise,
            valueColor: valueColor,
            minusEnabled: minusEnabled,
            plusEnabled: plusEnabled,
            onMinus: onMinus,
            onPlus: onPlus,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

class _ActionSheetSwitchSlot extends StatelessWidget {
  const _ActionSheetSwitchSlot({required this.value, required this.onChanged});

  static const double width = 30;

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: TradeIosSwitchSlot.height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TradeIosSwitch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    super.key,
    required this.label,
    required this.range,
    required this.controller,
    required this.focusNode,
    required this.fieldKey,
    required this.onMinus,
    required this.onPlus,
    this.valueColor = _TradeColors.text,
    this.minusEnabled = true,
    this.plusEnabled = true,
    this.trailingLabel,
    this.trailingValue,
    this.trailingValueColor,
    this.onChanged,
  });

  final String label;
  final String range;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Key fieldKey;
  final Color valueColor;
  final bool minusEnabled;
  final bool plusEnabled;
  final String? trailingLabel;
  final String? trailingValue;
  final Color? trailingValueColor;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TradeIosStepperField(
      title: label,
      range: range,
      controller: controller,
      focusNode: focusNode,
      valueColor: valueColor,
      minusEnabled: minusEnabled,
      plusEnabled: plusEnabled,
      trailingLabel: trailingLabel,
      trailingValue: trailingValue,
      trailingValueColor: trailingValueColor,
      onMinus: onMinus,
      onPlus: onPlus,
      onChanged: onChanged,
      inputKey: fieldKey,
      buttonChrome: TradeIosStepperButtonChrome.circleOutline,
      titleWidget: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          height: 1,
          color: context.adaptiveTextTertiary,
        ),
      ),
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({
    required this.isBuy,
    required this.buyText,
    required this.sellText,
  });

  final bool isBuy;
  final String buyText;
  final String sellText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (isBuy ? _TradeColors.rise : _TradeColors.fall).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isBuy ? buyText : sellText,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          color: isBuy ? _TradeColors.rise : _TradeColors.fall,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LotBadge extends StatelessWidget {
  const _LotBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1,
          color: _TradeColors.text,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _NumericRange {
  const _NumericRange({
    required this.minText,
    required this.maxText,
    required this.min,
    required this.max,
  });

  factory _NumericRange.fromOrder(
    Map<String, dynamic> order, {
    required List<String> minKeys,
    required List<String> maxKeys,
  }) {
    final minText = _TradePositionActionSheetState._firstText(order, minKeys);
    final maxText = _TradePositionActionSheetState._firstText(order, maxKeys);
    return _NumericRange(
      minText: minText,
      maxText: maxText,
      min: double.tryParse(minText),
      max: double.tryParse(maxText),
    );
  }

  final String minText;
  final String maxText;
  final double? min;
  final double? max;

  String get label {
    if (minText.isNotEmpty && maxText.isNotEmpty) return '$minText - $maxText';
    if (minText.isNotEmpty) return '≥$minText';
    if (maxText.isNotEmpty) return '≤$maxText';
    return '';
  }

  bool containsText(String value) {
    final number = double.tryParse(value);
    if (number == null) return false;
    if (min != null && number < min!) return false;
    if (max != null && number > max!) return false;
    return true;
  }
}

abstract final class _TradeColors {
  static Color get rise => CardTool.priceColor(1);
  static Color get fall => CardTool.priceColor(-1);
  static const Color text = Color(0xFF343434);
}
