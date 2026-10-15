import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/card_tool.dart';
import 'kline_indicators.dart';

/// 主图 K 线样式（对齐 iOS：K线图 / 空心K线图 / 涨·跌空心 / 美国线 / 面积图）
enum KlineMainChartStyle {
  candle,

  /// 多空均为空心描边（无实体填充）
  candleHollowAll,

  /// 仅阳线空心（阴线实心）
  candleHollowRise,

  /// 仅阴线空心（阳线实心）
  candleHollowFall,
  usLine,
  area,
}

bool _klineCandleBodyOutlineOnly(KlineMainChartStyle style, bool bull) {
  switch (style) {
    case KlineMainChartStyle.candleHollowAll:
      return true;
    case KlineMainChartStyle.candleHollowRise:
      return bull;
    case KlineMainChartStyle.candleHollowFall:
      return !bull;
    case KlineMainChartStyle.candle:
    case KlineMainChartStyle.usLine:
    case KlineMainChartStyle.area:
      return false;
  }
}

/// 主图均线类叠加（由行情详情页副图 Tab 中 MA/EMA/BOLL 等映射）
enum KlineMainOverlay { none, ma, ema, boll }

/// 副图类型
enum KlineSubChartType { volume, macd, kdj, rsi, dmi }

class _KlineVisibleWindow {
  const _KlineVisibleWindow(this.start, this.end);

  final int start;
  final int end;
}

_KlineVisibleWindow _klineVisibleWindow({
  required int dataLength,
  required double pxPerBar,
  required double viewportWidth,
  required double scrollOffset,
}) {
  if (dataLength <= 0) return const _KlineVisibleWindow(0, 0);
  final safeSlot = max(pxPerBar, 1.0);
  final start = ((scrollOffset - _KlineCandleChartState._leftAxis) / safeSlot)
      .floor()
      .clamp(0, dataLength - 1)
      .toInt();
  final end =
      ((scrollOffset + viewportWidth - _KlineCandleChartState._leftAxis) /
              safeSlot)
          .ceil()
          .clamp(start + 1, dataLength)
          .toInt();
  return _KlineVisibleWindow(start, end);
}

@visibleForTesting
double klineLatestScrollOffsetForTest(
  int dataLength, {
  required double viewportWidth,
  required double pxPerBar,
}) {
  final contentWidth =
      _KlineCandleChartState._leftAxis +
      dataLength * pxPerBar +
      _KlineCandleChartState._rightAxisWidth +
      _KlineCandleChartState._rightPad;
  return max(0, contentWidth - viewportWidth);
}

@visibleForTesting
double klineMacdAxisMaxForTest(
  List<Map<String, dynamic>> data, {
  double? viewportWidth,
  double scrollOffset = 0,
  double pxPerBar = _KlineCandleChartState._defaultPxPerBar,
  int macdFast = 12,
  int macdSlow = 26,
  int macdSignal = 9,
}) {
  if (data.isEmpty) return 1;
  final visible = viewportWidth == null
      ? _KlineVisibleWindow(0, data.length)
      : _klineVisibleWindow(
          dataLength: data.length,
          pxPerBar: pxPerBar,
          viewportWidth: viewportWidth,
          scrollOffset: scrollOffset,
        );
  return _macdAxisMax(
    _klineCloses(data),
    visible.start,
    visible.end,
    macdFast: macdFast,
    macdSlow: macdSlow,
    macdSignal: macdSignal,
  );
}

/// 可横向拖动、双指缩放、滑到左端触发加载更早数据的 K 线区域
///
/// 对齐 iOS [STYYKlineView]（横向 scroll + UIPinchGestureRecognizer +
/// UILongPressGestureRecognizer 十字线 + [STKlineLongPressInfoView]）+
/// [STMarketDetailController klineViewDidMoveToLeftBorder:]（左缘加载历史）。
class KlineCandleChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final int precision;

  /// 接近左缘（更早时间）时回调；由父组件拉 `end_time = 首根 timestamp` 的历史并 prepend
  final VoidCallback? onNearLeftEdge;

  /// 仅在整表刷新（切周期、首次加载）时递增；prepend 历史时不改，用于滚到最新 K 线
  final int scrollToLatestNonce;

  final KlineMainChartStyle mainStyle;
  final KlineMainOverlay mainOverlay;
  final KlineSubChartType subChartType;

  /// 显示主图网格
  final bool showGrid;

  /// 长按十字线检视（对齐 iOS event_longPressMethod）
  final bool enableCrosshair;

  /// 分时（`chartParam` → `1MIN` 的 FS 周期）：主图为青绿面积 + MA5/10/20 + 现价虚线与右侧价签（对齐 iOS 分时图）
  final bool timeSharingMode;

  /// 主图 MA 周期（默认 5/10/20，与行情设置页一致）
  final List<int> maPeriods;

  /// 主图 EMA 周期（默认 12/26）
  final List<int> emaPeriods;

  /// 副图 MACD：快线 / 慢线 / 信号（默认 12,26,9）
  final int macdFast;
  final int macdSlow;
  final int macdSignal;

  /// 副图 KDJ：RSV 周期 / K 平滑 / D 平滑（默认 9,3,3）
  final int kdjPeriod;
  final int kdjKSmooth;
  final int kdjDSmooth;

  final int rsiPeriod;
  final int dmiPeriod;

  const KlineCandleChart({
    super.key,
    required this.data,
    this.precision = 2,
    this.onNearLeftEdge,
    this.scrollToLatestNonce = 0,
    this.mainStyle = KlineMainChartStyle.candle,
    this.mainOverlay = KlineMainOverlay.none,
    this.subChartType = KlineSubChartType.volume,
    this.showGrid = true,
    this.enableCrosshair = true,
    this.timeSharingMode = false,
    this.maPeriods = const [5, 10, 20],
    this.emaPeriods = const [12, 26],
    this.macdFast = 12,
    this.macdSlow = 26,
    this.macdSignal = 9,
    this.kdjPeriod = 9,
    this.kdjKSmooth = 3,
    this.kdjDSmooth = 3,
    this.rsiPeriod = 14,
    this.dmiPeriod = 14,
  });

  @override
  State<KlineCandleChart> createState() => _KlineCandleChartState();
}

class _KlineCandleChartState extends State<KlineCandleChart> {
  static const double _leftAxis = 46;
  static const double _rightAxisWidth = 48;
  static const double _rightPad = 8;

  double _axisGutterWidth(BuildContext context) {
    var largestPrice = 0.0;
    var largestVolume = 0.0;
    for (final row in widget.data) {
      largestPrice = max(
        largestPrice,
        max(
          ((row['high'] as num?)?.toDouble() ?? 0).abs(),
          ((row['low'] as num?)?.toDouble() ?? 0).abs(),
        ),
      );
      if (widget.subChartType == KlineSubChartType.volume) {
        largestVolume = max(
          largestVolume,
          ((row['volume'] as num?)?.toDouble() ?? 0).abs(),
        );
      }
    }
    final labels = <String>[
      largestPrice.toStringAsFixed(widget.precision),
      (-largestPrice).toStringAsFixed(widget.precision),
      if (widget.subChartType == KlineSubChartType.volume)
        largestVolume.toStringAsFixed(0),
    ];
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var measuredWidth = 0.0;
    for (final label in labels) {
      painter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 11, height: 1),
      );
      painter.layout();
      measuredWidth = max(measuredWidth, painter.width);
    }
    painter.dispose();
    return max(_rightAxisWidth, (measuredWidth + 4).ceilToDouble());
  }

  double _rightAxisWidthFor(
    BuildContext context,
    _KlineMainScale mainScale,
    _KlineSubAxisScale subScale,
    double minimumWidth,
  ) {
    final labels = <String>[
      for (var i = 0; i < 5; i++)
        (mainScale.maxP - (mainScale.maxP - mainScale.minP) * i / 4)
            .toStringAsFixed(widget.precision),
      for (var i = 0; i < 3; i++)
        (subScale.maxValue - (subScale.maxValue - subScale.minValue) * i / 2)
            .toStringAsFixed(subScale.precision),
    ];
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var measuredWidth = 0.0;
    for (final label in labels) {
      painter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 11, height: 1),
      );
      painter.layout();
      measuredWidth = max(measuredWidth, painter.width);
    }
    painter.dispose();
    return max(minimumWidth, (measuredWidth + 4).ceilToDouble());
  }

  /// 与 iOS `YYKlineLineMinWidth` / `YYKlineLineMaxWidth` 一致
  static const double _minPxPerBar = 2.0;
  static const double _maxPxPerBar = 20.0;
  static const double _defaultPxPerBar = 7;

  /// 与 iOS `YYKlineScaleBound`：捏合比例变化超过此值才触发一档缩放
  static const double _iosPinchScaleBound = 0.02;

  /// 与 iOS `YYKlineScaleFactor`：每档将柱宽乘以 (1±factor)
  static const double _iosPinchScaleFactor = 0.07;
  static const double _pad = 4;
  static const int _longPressDelayMs = 420;
  static const double _longPressCancelMove = 18;

  late final ScrollController _hScroll;
  double _pxPerBar = _defaultPxPerBar;
  bool _scheduledEndScroll = false;
  int? _lastFirstTimeMs;

  /// 捏合锚点（对齐 iOS event_pichMethod 以焦点所在 K 线为中心缩放）
  int _pinchAnchorIndex = 0;
  double _pinchFocalViewportX = 0;

  /// iOS `oldScale`：上次应用缩放后记录的 `pinch.scale`，仅当 |scale - this| > bound 时再步进一档
  double _pinchLastCommittedScale = 1.0;

  /// 与 iOS 捏合时 `scrollView.scrollEnabled = NO` 一致
  bool _pinchActive = false;
  bool _scheduledPinchAnchor = false;
  final Map<int, Offset> _touchPoints = {};
  double _pinchStartDistance = 1;

  /// 长按十字线检视（对齐 iOS event_longPressMethod）
  bool _longPressInspect = false;
  OverlayEntry? _dismissInspectOverlay;
  int? _selectedBarIndex;
  Offset _inspectLocal = Offset.zero;
  int? _activePointer;
  Offset? _pointerDownLocal;
  Offset _lastPointerLocal = Offset.zero;
  Timer? _longPressTimer;

  static final DateFormat _klineTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  static double subHeightFraction(KlineSubChartType t) {
    switch (t) {
      case KlineSubChartType.volume:
        return 0.14;
      case KlineSubChartType.macd:
        return 0.24;
      case KlineSubChartType.kdj:
        return 0.22;
      case KlineSubChartType.rsi:
        return 0.18;
      case KlineSubChartType.dmi:
        return 0.18;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.timeSharingMode) {
      _pxPerBar = 5;
    }
    _hScroll = ScrollController()..addListener(_onHScroll);
    _lastFirstTimeMs = _firstTimeMs(widget.data);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEndIfNeeded());
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _removeDismissInspectOverlay();
    _hScroll.removeListener(_onHScroll);
    _hScroll.dispose();
    super.dispose();
  }

  int? _firstTimeMs(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return null;
    return list.first['time'] as int?;
  }

  void _onHScroll() {
    if (!mounted || !_hScroll.hasClients) return;
    setState(() {});
    if (widget.onNearLeftEdge == null) return;
    if (_longPressInspect) return;
    final p = _hScroll.position;
    if (p.pixels <= 72 && p.maxScrollExtent > 8) {
      widget.onNearLeftEdge!();
    }
  }

  void _scrollToEndIfNeeded() {
    if (!mounted || !_hScroll.hasClients || widget.data.isEmpty) return;
    final max = _hScroll.position.maxScrollExtent;
    _hScroll.jumpTo(max);
  }

  void _scheduleScrollToEnd() {
    if (_scheduledEndScroll) return;
    _scheduledEndScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledEndScroll = false;
      if (mounted) _scrollToEndIfNeeded();
    });
  }

  void _endInspect() {
    _longPressTimer?.cancel();
    _removeDismissInspectOverlay();
    if (!mounted) return;
    setState(() {
      _longPressInspect = false;
      _selectedBarIndex = null;
    });
  }

  void _removeDismissInspectOverlay() {
    _dismissInspectOverlay?.remove();
    _dismissInspectOverlay = null;
  }

  void _showDismissInspectOverlay() {
    if (_dismissInspectOverlay != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        key: const ValueKey('kline-long-press-dismiss-cover'),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _endInspect,
        ),
      ),
    );
    _dismissInspectOverlay = entry;
    overlay.insert(entry);
  }

  void _onPointerDown(PointerDownEvent e) {
    _touchPoints[e.pointer] = e.localPosition;
    if (_touchPoints.length == 2) {
      _longPressTimer?.cancel();
      _beginPinch();
    }
    if (!widget.enableCrosshair) return;
    if (_longPressInspect) return;
    if (_activePointer != null && _activePointer != e.pointer) {
      _longPressTimer?.cancel();
      return;
    }
    _activePointer = e.pointer;
    _pointerDownLocal = e.localPosition;
    _lastPointerLocal = e.localPosition;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(
      const Duration(milliseconds: _longPressDelayMs),
      () {
        if (!mounted || _activePointer == null) return;
        if (!_hScroll.hasClients || widget.data.isEmpty) return;
        _removeDismissInspectOverlay();
        setState(() {
          _longPressInspect = true;
          _updateInspectAtLocal(_lastPointerLocal);
        });
      },
    );
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_touchPoints.containsKey(e.pointer)) {
      _touchPoints[e.pointer] = e.localPosition;
      if (_pinchActive && _touchPoints.length >= 2) {
        final points = _touchPoints.values.take(2).toList();
        final distance = (points[0] - points[1]).distance;
        _applyPinchScale(distance / _pinchStartDistance);
      }
    }
    if (!widget.enableCrosshair) return;
    if (_longPressInspect && e.pointer == _activePointer) {
      _lastPointerLocal = e.localPosition;
      _updateInspectAtLocal(e.localPosition);
      return;
    }
    if (_pointerDownLocal != null &&
        _activePointer == e.pointer &&
        !_longPressInspect) {
      final d = (e.localPosition - _pointerDownLocal!).distance;
      if (d > _longPressCancelMove) {
        _longPressTimer?.cancel();
      }
      _lastPointerLocal = e.localPosition;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _touchPoints.remove(e.pointer);
    if (_pinchActive && _touchPoints.length < 2) _onScaleEnd();
    if (!widget.enableCrosshair) return;
    if (_longPressInspect && e.pointer == _activePointer) {
      _showDismissInspectOverlay();
    }
    _longPressTimer?.cancel();
    if (e.pointer == _activePointer) {
      _activePointer = null;
      _pointerDownLocal = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _touchPoints.remove(e.pointer);
    if (_pinchActive && _touchPoints.length < 2) _onScaleEnd();
    if (!widget.enableCrosshair) return;
    if (_longPressInspect && e.pointer == _activePointer) {
      _showDismissInspectOverlay();
    }
    _longPressTimer?.cancel();
    if (e.pointer == _activePointer) {
      _activePointer = null;
      _pointerDownLocal = null;
    }
  }

  void _updateInspectAtLocal(Offset local) {
    if (!_hScroll.hasClients || widget.data.isEmpty) return;
    final scrollX = _hScroll.offset;
    final contentX = scrollX + local.dx;
    final rawIdx = ((contentX - _leftAxis) / _pxPerBar).floor();
    final idx = rawIdx.clamp(0, widget.data.length - 1);
    setState(() {
      _selectedBarIndex = idx;
      _inspectLocal = local;
    });
  }

  void _applyPinchScrollAnchor() {
    if (!_hScroll.hasClients || widget.data.isEmpty) return;
    final n = widget.data.length;
    final idx = _pinchAnchorIndex.clamp(0, n - 1);
    final slot = _pxPerBar;
    final barCenterContentX = _leftAxis + (idx + 0.5) * slot;
    final target = barCenterContentX - _pinchFocalViewportX;
    final max = _hScroll.position.maxScrollExtent;
    _hScroll.jumpTo(target.clamp(0.0, max));
  }

  void _schedulePinchAnchor() {
    if (_scheduledPinchAnchor) return;
    _scheduledPinchAnchor = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledPinchAnchor = false;
      if (mounted) _applyPinchScrollAnchor();
    });
  }

  void _beginPinch() {
    final points = _touchPoints.values.take(2).toList();
    final focalX = (points[0].dx + points[1].dx) / 2;
    _pinchStartDistance = max(1, (points[0] - points[1]).distance);
    _pinchLastCommittedScale = 1.0;
    setState(() => _pinchActive = true);
    if (!_hScroll.hasClients || widget.data.isEmpty) return;
    final vx = focalX + _hScroll.offset;
    _pinchAnchorIndex = ((vx - _leftAxis) / _pxPerBar).floor().clamp(
      0,
      widget.data.length - 1,
    );
    _pinchFocalViewportX = focalX;
  }

  /// 离散步进缩放（对齐 iOS：|Δscale| > 0.02 时柱宽 ×1.07 或 ×0.93），避免连续乘 scale 带来的抖动
  void _applyPinchScale(double scale) {
    if (_longPressInspect) return;
    final diff = scale - _pinchLastCommittedScale;
    if (diff.abs() <= _iosPinchScaleBound) return;

    final zoomIn = diff > 0;
    final oldW = _pxPerBar;
    if (oldW <= _minPxPerBar && !zoomIn) {
      _pinchLastCommittedScale = scale;
      return;
    }
    if (oldW >= _maxPxPerBar && zoomIn) {
      _pinchLastCommittedScale = scale;
      return;
    }

    final mult = zoomIn
        ? (1.0 + _iosPinchScaleFactor)
        : (1.0 - _iosPinchScaleFactor);
    final newW = (oldW * mult).clamp(_minPxPerBar, _maxPxPerBar);
    if ((newW - oldW).abs() < 1e-9) {
      _pinchLastCommittedScale = scale;
      return;
    }

    setState(() => _pxPerBar = newW);
    _pinchLastCommittedScale = scale;
    _schedulePinchAnchor();
  }

  void _onScaleEnd() {
    if (!_pinchActive) return;
    setState(() => _pinchActive = false);
  }

  @override
  void didUpdateWidget(KlineCandleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLen = oldWidget.data.length;
    final newLen = widget.data.length;
    final oldFirst = _lastFirstTimeMs;
    final newFirst = _firstTimeMs(widget.data);

    if (newLen == 0) {
      _lastFirstTimeMs = null;
      if (_longPressInspect) _endInspect();
      return;
    }

    if (widget.scrollToLatestNonce != oldWidget.scrollToLatestNonce) {
      _scheduleScrollToEnd();
    }

    if (widget.timeSharingMode != oldWidget.timeSharingMode &&
        widget.timeSharingMode) {
      _pxPerBar = 5;
    }

    if (oldLen > 0 &&
        newLen > oldLen &&
        newFirst != null &&
        oldFirst != null &&
        newFirst != oldFirst) {
      final added = newLen - oldLen;
      final delta = added * _pxPerBar;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_hScroll.hasClients) return;
        final max = _hScroll.position.maxScrollExtent;
        final target = (_hScroll.offset + delta).clamp(0.0, max);
        _hScroll.jumpTo(target);
      });
    } else if (oldLen == 0 && newLen > 0) {
      _scheduleScrollToEnd();
    }

    if (_longPressInspect &&
        _selectedBarIndex != null &&
        _selectedBarIndex! >= newLen) {
      _endInspect();
    }

    _lastFirstTimeMs = newFirst;
  }

  double _scrollOffsetForViewport(double viewportWidth, double contentWidth) {
    if (_hScroll.hasClients) return _hScroll.offset;
    return max(0, contentWidth - viewportWidth);
  }

  Map<String, dynamic>? get _selectedBar {
    final i = _selectedBarIndex;
    if (i == null || i < 0 || i >= widget.data.length) return null;
    return widget.data[i];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const SizedBox.expand();
    }

    final subFrac = subHeightFraction(widget.subChartType);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final axisGutterWidth = _axisGutterWidth(context);
        final contentWidth =
            _leftAxis +
            widget.data.length * _pxPerBar +
            axisGutterWidth +
            _rightPad;
        final scrollOffset = _scrollOffsetForViewport(w, contentWidth);
        final visibleWindow = _klineVisibleWindow(
          dataLength: widget.data.length,
          pxPerBar: _pxPerBar,
          viewportWidth: w,
          scrollOffset: scrollOffset,
        );
        final scale = _KlineMainScale.fromChart(
          widget.data,
          Size(w, h),
          subFrac,
          widget.mainOverlay,
          widget.timeSharingMode,
          visibleStart: visibleWindow.start,
          visibleEnd: visibleWindow.end,
          maPeriods: widget.maPeriods,
          emaPeriods: widget.emaPeriods,
        );
        final subScale = _KlineSubAxisScale.fromChart(
          widget.data,
          widget.subChartType,
          visibleStart: visibleWindow.start,
          visibleEnd: visibleWindow.end,
          macdFast: widget.macdFast,
          macdSlow: widget.macdSlow,
          macdSignal: widget.macdSignal,
          dmiPeriod: widget.dmiPeriod,
        );
        final rightAxisWidth = _rightAxisWidthFor(
          context,
          scale,
          subScale,
          axisGutterWidth,
        );
        final visibleLastIndex = max(0, visibleWindow.end - 1);
        final legendIndex = (_selectedBarIndex ?? visibleLastIndex).clamp(
          0,
          widget.data.length - 1,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: ClipRect(
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  physics: (_longPressInspect || _pinchActive)
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: max(contentWidth, constraints.maxWidth),
                    height: constraints.maxHeight,
                    child: CustomPaint(
                      size: Size(
                        max(contentWidth, constraints.maxWidth),
                        constraints.maxHeight,
                      ),
                      painter: _KlineCandlePainter(
                        data: widget.data,
                        precision: widget.precision,
                        rightAxisWidth: rightAxisWidth,
                        pxPerBar: _pxPerBar,
                        selectedIndex: _longPressInspect
                            ? _selectedBarIndex
                            : null,
                        visibleStart: visibleWindow.start,
                        visibleEnd: visibleWindow.end,
                        viewportWidth: w,
                        viewportScrollOffset: scrollOffset,
                        mainStyle: widget.mainStyle,
                        mainOverlay: widget.mainOverlay,
                        subChartType: widget.subChartType,
                        showGrid: widget.showGrid,
                        timeSharingMode: widget.timeSharingMode,
                        maPeriods: widget.maPeriods,
                        emaPeriods: widget.emaPeriods,
                        macdFast: widget.macdFast,
                        macdSlow: widget.macdSlow,
                        macdSignal: widget.macdSignal,
                        kdjPeriod: widget.kdjPeriod,
                        kdjKSmooth: widget.kdjKSmooth,
                        kdjDSmooth: widget.kdjDSmooth,
                        rsiPeriod: widget.rsiPeriod,
                        dmiPeriod: widget.dmiPeriod,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.timeSharingMode)
              Positioned(
                left: 6,
                right: rightAxisWidth + 4,
                top: 2,
                child: _KlineMainIndicatorLegend(
                  data: widget.data,
                  index: legendIndex,
                  overlay: widget.mainOverlay,
                  precision: widget.precision,
                  maPeriods: widget.maPeriods,
                  emaPeriods: widget.emaPeriods,
                ),
              ),
            if (!widget.timeSharingMode)
              Positioned(
                left: 6,
                right: rightAxisWidth + 4,
                top: scale.chartH + 6,
                child: _KlineSubIndicatorLegend(
                  data: widget.data,
                  index: legendIndex,
                  subChartType: widget.subChartType,
                  macdFast: widget.macdFast,
                  macdSlow: widget.macdSlow,
                  macdSignal: widget.macdSignal,
                  kdjPeriod: widget.kdjPeriod,
                  kdjKSmooth: widget.kdjKSmooth,
                  kdjDSmooth: widget.kdjDSmooth,
                  rsiPeriod: widget.rsiPeriod,
                  dmiPeriod: widget.dmiPeriod,
                ),
              ),
            if (!widget.timeSharingMode)
              Positioned(
                key: const ValueKey('kline-main-right-axis'),
                right: 0,
                top: scale.chartTop,
                width: rightAxisWidth,
                height: max(0, scale.chartBottom - scale.chartTop),
                child: _KlineRightAxisLabels(
                  maxValue: scale.maxP,
                  minValue: scale.minP,
                  precision: widget.precision,
                  count: 5,
                  hideLast: true,
                ),
              ),
            if (!widget.timeSharingMode)
              Positioned(
                key: const ValueKey('kline-sub-right-axis'),
                right: 0,
                top: scale.chartH + 6,
                width: rightAxisWidth,
                height: max(0, h - scale.chartH - 10),
                child: _KlineRightAxisLabels(
                  maxValue: subScale.maxValue,
                  minValue: subScale.minValue,
                  precision: subScale.precision,
                  count: 3,
                  hideLast: false,
                ),
              ),
            if (widget.enableCrosshair &&
                _longPressInspect &&
                _selectedBarIndex != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _KlineCrosshairPainter(
                      viewportW: w,
                      viewportH: h,
                      pxPerBar: _pxPerBar,
                      scrollOffset: _hScroll.hasClients ? _hScroll.offset : 0,
                      selectedIndex: _selectedBarIndex!,
                      inspectLocalY: _inspectLocal.dy,
                      scale: scale,
                    ),
                  ),
                ),
              ),
            if (widget.enableCrosshair &&
                _longPressInspect &&
                _selectedBar != null)
              ..._inspectOverlays(context, w, h, scale),
          ],
        );
      },
    );
  }

  List<Widget> _inspectOverlays(
    BuildContext context,
    double w,
    double h,
    _KlineMainScale scale,
  ) {
    final bar = _selectedBar!;
    final scrollX = _hScroll.hasClients ? _hScroll.offset : 0.0;
    final idx = _selectedBarIndex!;
    final cxContent = _leftAxis + (idx + 0.5) * _pxPerBar;
    final vx = cxContent - scrollX;
    if (vx < _leftAxis - 2 || vx > w + 2) return [];

    final open = (bar['open'] as num?)?.toDouble() ?? 0;
    final close = (bar['close'] as num?)?.toDouble() ?? 0;
    final high = (bar['high'] as num?)?.toDouble() ?? 0;
    final low = (bar['low'] as num?)?.toDouble() ?? 0;
    final diff = close - open;
    final pct = open.abs() < 1e-12 ? 0.0 : (diff / open * 100);
    final p = widget.precision;
    final timeMs = bar['time'] as int?;
    final timeStr = timeMs == null
        ? '--'
        : _klineTimeFmt.format(DateTime.fromMillisecondsSinceEpoch(timeMs));

    final yMain = _inspectLocal.dy.clamp(scale.chartTop, scale.chartBottom);
    final crossPrice = scale.priceAtY(yMain);
    final priceLabelW = 52.0;

    final panelLeft = _inspectLocal.dx > w / 2;

    final riseColor = diff >= 0
        ? CardTool.priceColor(1)
        : CardTool.priceColor(-1);
    final rows = <MapEntry<String, String>>[
      MapEntry(timeStr, ''),
      MapEntry('开盘', open.toStringAsFixed(p)),
      MapEntry('收盘', close.toStringAsFixed(p)),
      MapEntry('最高', high.toStringAsFixed(p)),
      MapEntry('最低', low.toStringAsFixed(p)),
      MapEntry('涨跌额', '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(p)}'),
      MapEntry('涨跌幅', '${diff >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'),
    ];

    return [
      Positioned(
        left: 0,
        top: (yMain - 7).clamp(0.0, h - 14),
        width: priceLabelW,
        height: 15,
        child: IgnorePointer(
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF60656D)),
            child: Text(
              crossPrice.toStringAsFixed(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        ),
      ),
      Positioned(
        left: (vx - 40).clamp(0.0, w - 80),
        top: scale.chartH + 2,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: const BoxDecoration(color: Color(0xFF60656D)),
            child: Text(
              timeStr,
              style: const TextStyle(fontSize: 9, color: Colors.white),
            ),
          ),
        ),
      ),
      Positioned(
        left: panelLeft ? 8 : null,
        right: panelLeft ? null : 8,
        top: 32,
        width: 132,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows.asMap().entries.map((e) {
                final i = e.key;
                final name = e.value.key;
                final value = e.value.value;
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                    ),
                  );
                }
                final isChg = name == '涨跌额' || name == '涨跌幅';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9A9DA2),
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 10,
                          color: isChg ? riseColor : const Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ];
  }
}

const List<Color> _klineIndicatorColors = [
  Color(0xFFFF783C),
  Color(0xFF49A5FF),
  Colors.purple,
  Colors.black,
  Colors.red,
  Colors.blue,
];

List<double> _klineCloses(List<Map<String, dynamic>> data) {
  return [for (final item in data) (item['close'] as num?)?.toDouble() ?? 0];
}

List<double> _klineHighs(List<Map<String, dynamic>> data) {
  return [for (final item in data) (item['high'] as num?)?.toDouble() ?? 0];
}

List<double> _klineLows(List<Map<String, dynamic>> data) {
  return [for (final item in data) (item['low'] as num?)?.toDouble() ?? 0];
}

double _macdAxisMax(
  List<double> closes,
  int visibleStart,
  int visibleEnd, {
  required int macdFast,
  required int macdSlow,
  required int macdSignal,
}) {
  if (closes.isEmpty) return 1;
  final macd = KlineIndicators.macd(
    closes,
    fast: macdFast,
    slow: macdSlow,
    signal: macdSignal,
  );
  var yMax = 1e-12;
  final start = visibleStart.clamp(0, closes.length - 1).toInt();
  final end = visibleEnd.clamp(start + 1, closes.length).toInt();
  for (var i = start; i < end; i++) {
    yMax = max(yMax, (macd.dif[i] ?? 0).abs());
    yMax = max(yMax, (macd.dea[i] ?? 0).abs());
    yMax = max(yMax, (macd.hist[i] ?? 0).abs());
  }
  return yMax < 1e-9 ? 1 : yMax;
}

String _formatIndicatorValue(double? value, int digits) {
  if (value == null || !value.isFinite) return '--';
  return value.toStringAsFixed(digits);
}

class _KlineMainIndicatorLegend extends StatelessWidget {
  const _KlineMainIndicatorLegend({
    required this.data,
    required this.index,
    required this.overlay,
    required this.precision,
    required this.maPeriods,
    required this.emaPeriods,
  });

  final List<Map<String, dynamic>> data;
  final int index;
  final KlineMainOverlay overlay;
  final int precision;
  final List<int> maPeriods;
  final List<int> emaPeriods;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final closes = _klineCloses(data);
    const digits = 3;

    void addSeries(
      String prefix,
      List<int> periods,
      List<List<double?>> lines,
    ) {
      final n = min(periods.length, lines.length);
      for (var i = 0; i < n && i < _klineIndicatorColors.length; i++) {
        spans.add(
          TextSpan(
            text:
                '$prefix${periods[i]}:${_formatIndicatorValue(lines[i][index], digits)} ',
            style: TextStyle(
              fontSize: 10,
              color: _klineIndicatorColors[i],
              height: 1.1,
            ),
          ),
        );
      }
    }

    switch (overlay) {
      case KlineMainOverlay.ma:
        addSeries('MA', maPeriods, [
          for (final p in maPeriods.take(6)) KlineIndicators.sma(closes, p),
        ]);
        break;
      case KlineMainOverlay.ema:
        addSeries('EMA', emaPeriods, [
          for (final p in emaPeriods.take(6)) KlineIndicators.ema(closes, p),
        ]);
        break;
      case KlineMainOverlay.boll:
        final boll = KlineIndicators.boll(closes, period: 20, k: 2);
        final items = [
          MapEntry('UP', boll.upper[index]),
          MapEntry('MID', boll.mid[index]),
          MapEntry('LOW', boll.lower[index]),
        ];
        for (var i = 0; i < items.length; i++) {
          spans.add(
            TextSpan(
              text:
                  '${items[i].key}:${_formatIndicatorValue(items[i].value, digits)} ',
              style: TextStyle(
                fontSize: 10,
                color: _klineIndicatorColors[i],
                height: 1.1,
              ),
            ),
          );
        }
        break;
      case KlineMainOverlay.none:
        final row = data[index];
        final open = (row['open'] as num?)?.toDouble();
        final high = (row['high'] as num?)?.toDouble();
        final low = (row['low'] as num?)?.toDouble();
        final close = (row['close'] as num?)?.toDouble();
        spans.add(
          TextSpan(
            text:
                '开:${_formatIndicatorValue(open, precision)}  高:${_formatIndicatorValue(high, precision)}  低:${_formatIndicatorValue(low, precision)}  收:${_formatIndicatorValue(close, precision)}',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8E8E93),
              height: 1.1,
            ),
          ),
        );
        break;
    }

    return IgnorePointer(
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.clip,
        text: TextSpan(children: spans),
      ),
    );
  }
}

class _KlineSubIndicatorLegend extends StatelessWidget {
  const _KlineSubIndicatorLegend({
    required this.data,
    required this.index,
    required this.subChartType,
    required this.macdFast,
    required this.macdSlow,
    required this.macdSignal,
    required this.kdjPeriod,
    required this.kdjKSmooth,
    required this.kdjDSmooth,
    required this.rsiPeriod,
    required this.dmiPeriod,
  });

  final List<Map<String, dynamic>> data;
  final int index;
  final KlineSubChartType subChartType;
  final int macdFast;
  final int macdSlow;
  final int macdSignal;
  final int kdjPeriod;
  final int kdjKSmooth;
  final int kdjDSmooth;
  final int rsiPeriod;
  final int dmiPeriod;

  @override
  Widget build(BuildContext context) {
    final highs = _klineHighs(data);
    final lows = _klineLows(data);
    final closes = _klineCloses(data);
    final spans = <InlineSpan>[];

    void addGray(String text) {
      spans.add(
        TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8E8E93),
            height: 1.1,
          ),
        ),
      );
    }

    void addColored(String text, Color color) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(fontSize: 10, color: color, height: 1.1),
        ),
      );
    }

    switch (subChartType) {
      case KlineSubChartType.macd:
        final macd = KlineIndicators.macd(
          closes,
          fast: macdFast,
          slow: macdSlow,
          signal: macdSignal,
        );
        final hist = macd.hist[index];
        addGray('MACD($macdFast,$macdSlow,$macdSignal):');
        addColored(
          'DIFF:${_formatIndicatorValue(macd.dif[index], 4)} ',
          _klineIndicatorColors[0],
        );
        addColored(
          'DEA:${_formatIndicatorValue(macd.dea[index], 4)} ',
          _klineIndicatorColors[1],
        );
        addColored(
          'MACD:${_formatIndicatorValue(hist, 4)} ',
          (hist ?? 0) < 0 ? CardTool.priceColor(1) : CardTool.priceColor(-1),
        );
        break;
      case KlineSubChartType.kdj:
        final kdj = KlineIndicators.kdj(
          highs,
          lows,
          closes,
          period: kdjPeriod,
          kSmooth: kdjKSmooth,
          dSmooth: kdjDSmooth,
        );
        addGray('KDJ($kdjPeriod,$kdjKSmooth,$kdjDSmooth):');
        addColored(
          'K:${_formatIndicatorValue(kdj.k[index], 3)} ',
          _klineIndicatorColors[0],
        );
        addColored(
          'D:${_formatIndicatorValue(kdj.d[index], 3)} ',
          _klineIndicatorColors[1],
        );
        addColored(
          'J:${_formatIndicatorValue(kdj.j[index], 3)} ',
          _klineIndicatorColors[2],
        );
        break;
      case KlineSubChartType.rsi:
        final rsi = KlineIndicators.rsi(closes, period: rsiPeriod);
        addGray('RSI($rsiPeriod):');
        addColored(
          'RSI$rsiPeriod:${_formatIndicatorValue(rsi[index], 3)} ',
          _klineIndicatorColors[0],
        );
        break;
      case KlineSubChartType.dmi:
        final dmi = KlineIndicators.dmiNet(
          highs,
          lows,
          closes,
          period: dmiPeriod,
        );
        addGray('DMI($dmiPeriod):');
        addColored(
          'DMI:${_formatIndicatorValue(dmi[index], 3)} ',
          _klineIndicatorColors[0],
        );
        break;
      case KlineSubChartType.volume:
        final volume = (data[index]['volume'] as num?)?.toDouble();
        addGray('成交量:${_formatIndicatorValue(volume, 0)}');
        break;
    }

    return IgnorePointer(
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.clip,
        text: TextSpan(children: spans),
      ),
    );
  }
}

class _KlineRightAxisLabels extends StatelessWidget {
  const _KlineRightAxisLabels({
    required this.maxValue,
    required this.minValue,
    required this.precision,
    required this.count,
    required this.hideLast,
  });

  final double maxValue;
  final double minValue;
  final int precision;
  final int count;
  final bool hideLast;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final range = maxValue - minValue;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final lineHeight = MediaQuery.textScalerOf(context).scale(11) + 1;
          return Stack(
            children: [
              for (var i = 0; i < count; i++)
                if (!(hideLast && i == count - 1))
                  Positioned(
                    right: 2,
                    top: _labelTop(i, constraints.maxHeight, lineHeight),
                    child: Text(
                      (maxValue - range * i / (count - 1)).toStringAsFixed(
                        precision,
                      ),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                        height: 1.0,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  double _labelTop(int index, double height, double lineHeight) {
    if (index == 0) return 0;
    if (index == count - 1) return max(0, height - lineHeight);
    final marginY = height / count;
    final startY = marginY / 2 - lineHeight / 2;
    return (startY + marginY * index).clamp(0, max(0, height - lineHeight));
  }
}

/// 主图价格刻度（与 [_KlineCandlePainter] 一致，用于十字线左侧价格）
class _KlineMainScale {
  _KlineMainScale({
    required this.maxP,
    required this.minP,
    required this.range,
    required this.chartH,
  });

  final double maxP;
  final double minP;
  final double range;
  final double chartH;

  double get chartTop => _KlineCandleChartState._pad;
  double get chartBottom => chartH - _KlineCandleChartState._pad;

  double priceAtY(double y) {
    final yy = y.clamp(chartTop, chartBottom);
    return maxP - (yy - chartTop) / (chartBottom - chartTop) * range;
  }

  /// 与 [_KlineCandlePainter] 使用同一套区间扩展，保证十字线价位与 K 线对齐
  static _KlineMainScale fromChart(
    List<Map<String, dynamic>> data,
    Size size,
    double subFrac,
    KlineMainOverlay mainOverlay,
    bool timeSharingMode, {
    required int visibleStart,
    required int visibleEnd,
    List<int> maPeriods = const [5, 10, 20],
    List<int> emaPeriods = const [12, 26],
  }) {
    final closes = <double>[];
    for (final item in data) {
      closes.add((item['close'] as num?)?.toDouble() ?? 0);
    }
    final start = visibleStart.clamp(0, data.length - 1).toInt();
    final end = visibleEnd.clamp(start + 1, data.length).toInt();
    var maxP = -double.infinity;
    var minP = double.infinity;
    for (var i = start; i < end; i++) {
      final high = (data[i]['high'] as num?)?.toDouble() ?? 0;
      final low = (data[i]['low'] as num?)?.toDouble() ?? 0;
      maxP = max(maxP, high);
      minP = min(minP, low);
    }
    if (!maxP.isFinite || !minP.isFinite) {
      maxP = 1;
      minP = -1;
    }

    final maP = maPeriods;
    final emaP = emaPeriods;
    final maLines = <List<double?>>[
      for (var i = 0; i < maP.length && i < 6; i++)
        KlineIndicators.sma(closes, maP[i]),
    ];
    final emaLines = <List<double?>>[
      for (var i = 0; i < emaP.length && i < 6; i++)
        KlineIndicators.ema(closes, emaP[i]),
    ];
    final boll = KlineIndicators.boll(closes, period: 20, k: 2);

    void absorbOverlay(double? v) {
      if (v == null || !v.isFinite) return;
      maxP = max(maxP, v);
      minP = min(minP, v);
    }

    final overlay = timeSharingMode ? KlineMainOverlay.ma : mainOverlay;
    switch (overlay) {
      case KlineMainOverlay.ma:
        for (final s in maLines) {
          for (var i = start; i < end; i++) {
            absorbOverlay(s[i]);
          }
        }
        break;
      case KlineMainOverlay.ema:
        for (final s in emaLines) {
          for (var i = start; i < end; i++) {
            absorbOverlay(s[i]);
          }
        }
        break;
      case KlineMainOverlay.boll:
        for (var i = start; i < end; i++) {
          absorbOverlay(boll.upper[i]);
          absorbOverlay(boll.mid[i]);
          absorbOverlay(boll.lower[i]);
        }
        break;
      case KlineMainOverlay.none:
        break;
    }

    var range = maxP - minP;
    if (range <= 0 || !range.isFinite) {
      maxP += 1;
      minP -= 1;
      range = maxP - minP;
    }
    final padY = range * 0.04;
    maxP += padY;
    minP -= padY;
    range = maxP - minP;
    if (range <= 0) range = 1;

    final chartH = size.height * (1 - subFrac);
    return _KlineMainScale(
      maxP: maxP,
      minP: minP,
      range: range,
      chartH: chartH,
    );
  }
}

class _KlineSubAxisScale {
  const _KlineSubAxisScale({
    required this.maxValue,
    required this.minValue,
    required this.precision,
  });

  final double maxValue;
  final double minValue;
  final int precision;

  static _KlineSubAxisScale fromChart(
    List<Map<String, dynamic>> data,
    KlineSubChartType subChartType, {
    required int visibleStart,
    required int visibleEnd,
    int macdFast = 12,
    int macdSlow = 26,
    int macdSignal = 9,
    int dmiPeriod = 14,
  }) {
    if (data.isEmpty) {
      return const _KlineSubAxisScale(maxValue: 1, minValue: -1, precision: 2);
    }
    final highs = _klineHighs(data);
    final lows = _klineLows(data);
    final closes = _klineCloses(data);
    final start = visibleStart.clamp(0, data.length - 1).toInt();
    final end = visibleEnd.clamp(start + 1, data.length).toInt();

    switch (subChartType) {
      case KlineSubChartType.volume:
        var maxVolume = 1.0;
        for (var i = start; i < end; i++) {
          maxVolume = max(
            maxVolume,
            (data[i]['volume'] as num?)?.toDouble() ?? 0,
          );
        }
        return _KlineSubAxisScale(
          maxValue: max(maxVolume, 1),
          minValue: 0,
          precision: 0,
        );
      case KlineSubChartType.macd:
        final yMax = _macdAxisMax(
          closes,
          start,
          end,
          macdFast: macdFast,
          macdSlow: macdSlow,
          macdSignal: macdSignal,
        );
        return _KlineSubAxisScale(
          maxValue: yMax,
          minValue: -yMax,
          precision: 2,
        );
      case KlineSubChartType.kdj:
      case KlineSubChartType.rsi:
        return const _KlineSubAxisScale(
          maxValue: 100,
          minValue: 0,
          precision: 2,
        );
      case KlineSubChartType.dmi:
        final dmi = KlineIndicators.dmiNet(
          highs,
          lows,
          closes,
          period: dmiPeriod,
        );
        var yMax = 1e-12;
        for (var i = start; i < end; i++) {
          final value = dmi[i];
          if (value != null) yMax = max(yMax, value.abs());
        }
        if (yMax < 1e-9) yMax = 1;
        return _KlineSubAxisScale(
          maxValue: yMax,
          minValue: -yMax,
          precision: 2,
        );
    }
  }
}

/// 视口内十字线（竖线在选中 K 线中心，横线在触点 Y）
class _KlineCrosshairPainter extends CustomPainter {
  _KlineCrosshairPainter({
    required this.viewportW,
    required this.viewportH,
    required this.pxPerBar,
    required this.scrollOffset,
    required this.selectedIndex,
    required this.inspectLocalY,
    required this.scale,
  });

  final double viewportW;
  final double viewportH;
  final double pxPerBar;
  final double scrollOffset;
  final int selectedIndex;
  final double inspectLocalY;
  final _KlineMainScale scale;

  static const double _leftAxis = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF60656D)
      ..strokeWidth = 0.8;

    final cxContent = _leftAxis + (selectedIndex + 0.5) * pxPerBar;
    final vx = cxContent - scrollOffset;
    if (vx >= _leftAxis && vx <= viewportW) {
      canvas.drawLine(Offset(vx, 0), Offset(vx, viewportH), line);
    }

    final y = inspectLocalY.clamp(scale.chartTop, scale.chartBottom);
    canvas.drawLine(Offset(_leftAxis, y), Offset(viewportW, y), line);
  }

  @override
  bool shouldRepaint(covariant _KlineCrosshairPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.inspectLocalY != inspectLocalY ||
        oldDelegate.pxPerBar != pxPerBar ||
        oldDelegate.viewportW != viewportW;
  }
}

class _KlineCandlePainter extends CustomPainter {
  _KlineCandlePainter({
    required this.data,
    required this.precision,
    required this.rightAxisWidth,
    required this.pxPerBar,
    this.selectedIndex,
    required this.visibleStart,
    required this.visibleEnd,
    required this.viewportWidth,
    required this.viewportScrollOffset,
    required this.mainStyle,
    required this.mainOverlay,
    required this.subChartType,
    required this.showGrid,
    this.timeSharingMode = false,
    required this.maPeriods,
    required this.emaPeriods,
    required this.macdFast,
    required this.macdSlow,
    required this.macdSignal,
    required this.kdjPeriod,
    required this.kdjKSmooth,
    required this.kdjDSmooth,
    required this.rsiPeriod,
    required this.dmiPeriod,
  });

  final List<Map<String, dynamic>> data;
  final int precision;
  final double rightAxisWidth;
  final double pxPerBar;
  final int? selectedIndex;
  final int visibleStart;
  final int visibleEnd;
  final double viewportWidth;
  final double viewportScrollOffset;
  final KlineMainChartStyle mainStyle;
  final KlineMainOverlay mainOverlay;
  final KlineSubChartType subChartType;
  final bool showGrid;
  final bool timeSharingMode;
  final List<int> maPeriods;
  final List<int> emaPeriods;
  final int macdFast;
  final int macdSlow;
  final int macdSignal;
  final int kdjPeriod;
  final int kdjKSmooth;
  final int kdjDSmooth;
  final int rsiPeriod;
  final int dmiPeriod;

  /// iOS 分时图底部时间刻度：`05/11 15:46`
  static final DateFormat _tsAxisTimeFmt = DateFormat('MM/dd HH:mm');

  /// iOS 分时走势线 / 列表迷你线青绿色
  static const Color _tsLineTeal = Color(0xFF26C6DA);

  static const List<Color> _tsMaColors = _klineIndicatorColors;

  static void _paintDashedHorizontal(
    Canvas canvas,
    double x1,
    double x2,
    double y,
    Paint paint, {
    double dash = 5,
    double gap = 4,
  }) {
    if (x2 < x1) return;
    final dx = x2 - x1;
    var d = 0.0;
    while (d < dx) {
      final xa = x1 + d;
      final xb = min(x1 + d + dash, x2);
      canvas.drawLine(Offset(xa, y), Offset(xb, y), paint);
      d += dash + gap;
    }
  }

  void _paintCurrentPriceLine(
    Canvas canvas, {
    required double chartLeft,
    required double chartRight,
    required double chartH,
    required double close,
    required double Function(double price) yForPrice,
  }) {
    if (!close.isFinite || close.abs() <= 1e-12) return;
    final y = yForPrice(close);
    if (!y.isFinite) return;

    final lineLeft = max(chartLeft, viewportScrollOffset);
    final lineRight = min(
      chartRight,
      viewportScrollOffset + viewportWidth - rightAxisWidth,
    );
    if (lineRight <= lineLeft) return;

    _paintDashedHorizontal(
      canvas,
      lineLeft,
      lineRight,
      y,
      Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = 0.9,
      dash: 2,
      gap: 2,
    );

    final tag = close.toStringAsFixed(precision);
    final tagPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tagPainter.text = TextSpan(
      text: tag,
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
    tagPainter.layout();
    final tw = max(50.0, tagPainter.width + 10);
    final th = max(15.0, tagPainter.height + 4);
    final tx = (viewportScrollOffset + viewportWidth - tw - 2)
        .clamp(lineLeft, max(lineLeft, lineRight - tw))
        .toDouble();
    final ty = (y - th / 2).clamp(_pad, chartH - _pad - th);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty, tw, th),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black,
    );
    tagPainter.paint(canvas, Offset(tx + (tw - tagPainter.width) / 2, ty + 2));
  }

  /// 主图底沿时间刻度（与 K 线索引对齐，随横向滚动完整内容绘制）
  static int? _barTimeMs(Map<String, dynamic> row) {
    final t = row['time'];
    if (t == null) return null;
    int ms;
    if (t is int) {
      ms = t;
    } else if (t is num) {
      ms = t.toInt();
    } else {
      return null;
    }
    if (ms == 0) return null;
    if (ms < 100000000000) ms *= 1000;
    return ms;
  }

  void _paintTimeSharingTimeAxis(
    Canvas canvas,
    List<Map<String, dynamic>> rows,
    int n,
    double slot,
    double chartLeft,
    double chartRight,
    double chartH,
  ) {
    if (n <= 0) return;

    final idxSet = <int>{0, n - 1};
    if (n > 2) {
      idxSet.add(((n - 1) * 0.25).round());
      idxSet.add(((n - 1) * 0.5).round());
      idxSet.add(((n - 1) * 0.75).round());
    }
    final indices = idxSet.toList()..sort();

    final tp = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    const style = TextStyle(fontSize: 9, color: Color(0xFF8E8E93), height: 1.0);
    final yTop = chartH - 15;
    double? lastPaintRight;

    for (final i in indices) {
      if (i < 0 || i >= rows.length) continue;
      final ms = _barTimeMs(rows[i]);
      if (ms == null) continue;

      final text = _tsAxisTimeFmt.format(
        DateTime.fromMillisecondsSinceEpoch(ms),
      );
      tp.text = TextSpan(text: text, style: style);
      tp.layout(maxWidth: chartRight - chartLeft);

      final cx = chartLeft + (i + 0.5) * slot;
      var left = cx - tp.width / 2;
      if (left < chartLeft) left = chartLeft;
      if (left + tp.width > chartRight) left = chartRight - tp.width;

      if (lastPaintRight != null && left < lastPaintRight + 8) {
        continue;
      }

      tp.paint(canvas, Offset(left, yTop));
      lastPaintRight = left + tp.width;
    }
  }

  static void _paintMaLegend(
    Canvas canvas,
    Offset at,
    double maxLabelWidth,
    List<List<double?>> maLines,
    List<int> periods,
    int lastIdx,
    int prec,
  ) {
    String fmt(double? v) {
      if (v == null || !v.isFinite) return '--';
      final d = prec.clamp(2, 6);
      return v.toStringAsFixed(d);
    }

    final children = <InlineSpan>[];
    final n = min(maLines.length, periods.length);
    for (var i = 0; i < n; i++) {
      if (i > 0) {
        children.add(
          const TextSpan(text: '  ', style: TextStyle(fontSize: 10)),
        );
      }
      children.addAll([
        TextSpan(
          text: 'MA${periods[i]}:',
          style: TextStyle(
            fontSize: 10,
            color: _tsMaColors[i % _tsMaColors.length],
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: fmt(maLines[i][lastIdx]),
          style: const TextStyle(fontSize: 10, color: Color(0xFF303030)),
        ),
      ]);
    }

    final tp = TextPainter(
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(children: children),
    );
    tp.layout(maxWidth: maxLabelWidth);
    tp.paint(canvas, at);
  }

  static const double _leftAxis = 46;
  static const double _pad = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final opens = <double>[];
    final highs = <double>[];
    final lows = <double>[];
    final closes = <double>[];
    final vols = <int>[];

    for (final item in data) {
      opens.add((item['open'] as num?)?.toDouble() ?? 0);
      highs.add((item['high'] as num?)?.toDouble() ?? 0);
      lows.add((item['low'] as num?)?.toDouble() ?? 0);
      closes.add((item['close'] as num?)?.toDouble() ?? 0);
      vols.add((item['volume'] as num?)?.toInt() ?? 0);
    }

    final n = data.length;
    final subFrac = _KlineCandleChartState.subHeightFraction(subChartType);
    final chartH = size.height * (1 - subFrac);
    final subTop = chartH + 2;
    final subH = size.height - subTop - _pad;
    final chartW = size.width - _leftAxis - _pad;
    final chartLeft = _leftAxis;
    final chartRight = chartLeft + chartW;

    final visibleStartIndex = visibleStart.clamp(0, n - 1).toInt();
    final visibleEndIndex = visibleEnd.clamp(visibleStartIndex + 1, n).toInt();

    var maxP = -double.infinity;
    var minP = double.infinity;
    for (var i = visibleStartIndex; i < visibleEndIndex; i++) {
      maxP = max(maxP, highs[i]);
      minP = min(minP, lows[i]);
    }
    if (!maxP.isFinite || !minP.isFinite) {
      maxP = highs.reduce(max);
      minP = lows.reduce(min);
    }

    final maP = maPeriods;
    final emaP = emaPeriods;
    final maLines = <List<double?>>[
      for (var i = 0; i < maP.length && i < 6; i++)
        KlineIndicators.sma(closes, maP[i]),
    ];
    final emaLines = <List<double?>>[
      for (var i = 0; i < emaP.length && i < 6; i++)
        KlineIndicators.ema(closes, emaP[i]),
    ];
    final tsPeriods = maP.take(6).toList();
    final tsMaLines = <List<double?>>[
      for (final period in tsPeriods) KlineIndicators.sma(closes, period),
    ];
    final boll = KlineIndicators.boll(closes, period: 20, k: 2);

    void absorbOverlay(double? v) {
      if (v == null || !v.isFinite) return;
      maxP = max(maxP, v);
      minP = min(minP, v);
    }

    final effectiveOverlay = timeSharingMode
        ? KlineMainOverlay.ma
        : mainOverlay;
    switch (effectiveOverlay) {
      case KlineMainOverlay.ma:
        for (final s in maLines) {
          for (var i = visibleStartIndex; i < visibleEndIndex; i++) {
            absorbOverlay(s[i]);
          }
        }
        break;
      case KlineMainOverlay.ema:
        for (final s in emaLines) {
          for (var i = visibleStartIndex; i < visibleEndIndex; i++) {
            absorbOverlay(s[i]);
          }
        }
        break;
      case KlineMainOverlay.boll:
        for (var i = visibleStartIndex; i < visibleEndIndex; i++) {
          absorbOverlay(boll.upper[i]);
          absorbOverlay(boll.mid[i]);
          absorbOverlay(boll.lower[i]);
        }
        break;
      case KlineMainOverlay.none:
        break;
    }

    var range = maxP - minP;
    if (range <= 0 || !range.isFinite) {
      maxP += 1;
      minP -= 1;
      range = maxP - minP;
    }
    final padY = range * 0.04;
    maxP += padY;
    minP -= padY;
    range = maxP - minP;
    if (range <= 0) range = 1;

    double yForPrice(double price) {
      return _pad + (maxP - price) / range * (chartH - 2 * _pad);
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 0.5;
    if (showGrid) {
      for (var i = 0; i <= 4; i++) {
        final y = _pad + (chartH - 2 * _pad) * i / 4;
        canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      }
      canvas.drawLine(
        Offset(chartLeft, _pad),
        Offset(chartLeft, chartH - _pad),
        gridPaint,
      );
      canvas.drawLine(
        Offset(chartRight, _pad),
        Offset(chartRight, chartH - _pad),
        gridPaint,
      );
    }

    if (timeSharingMode) {
      final rtp = TextPainter(
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      for (var i = 0; i <= 4; i++) {
        final price = maxP - range * i / 4;
        rtp.text = TextSpan(
          text: price.toStringAsFixed(precision),
          style: const TextStyle(fontSize: 9, color: Color(0xFF8E8E93)),
        );
        rtp.layout(maxWidth: size.width - chartRight - 4);
        rtp.paint(
          canvas,
          Offset(
            chartRight + 3,
            _pad + (chartH - 2 * _pad) * i / 4 - rtp.height / 2,
          ),
        );
      }
    }

    final slot = pxPerBar;
    final bodyW = max(1.0, slot * 0.62);
    final sel = selectedIndex;

    void strokePriceLine(
      List<double?> series,
      Color color, [
      double width = 1,
    ]) {
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = series[i];
        if (v == null) continue;
        final cx = chartLeft + (i + 0.5) * slot;
        final y = yForPrice(v);
        if (!started) {
          path.moveTo(cx, y);
          started = true;
        } else {
          path.lineTo(cx, y);
        }
      }
      if (started) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = width,
        );
      }
    }

    // —— 主图：分时（iOS 面积 + MA + 现价虚线） / 面积图 / K 线 ——
    if (timeSharingMode) {
      final fillPath = Path();
      var startedFill = false;
      double firstX = 0;
      for (var i = 0; i < n; i++) {
        final c = closes[i];
        final cx = chartLeft + (i + 0.5) * slot;
        final y = yForPrice(c);
        if (!startedFill) {
          fillPath.moveTo(cx, y);
          firstX = cx;
          startedFill = true;
        } else {
          fillPath.lineTo(cx, y);
        }
      }
      if (startedFill) {
        final baseY = chartH - _pad;
        fillPath.lineTo(chartLeft + (n - 0.5) * slot, baseY);
        fillPath.lineTo(firstX, baseY);
        fillPath.close();
        final topC = _tsLineTeal.withValues(alpha: 0.38);
        final shader = ui.Gradient.linear(Offset(0, _pad), Offset(0, chartH), [
          topC,
          _tsLineTeal.withValues(alpha: 0.02),
        ]);
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = shader
            ..style = PaintingStyle.fill,
        );
        strokePriceLine(List<double?>.from(closes), _tsLineTeal, 1.25);
      }
      for (var i = 0; i < tsMaLines.length && i < _tsMaColors.length; i++) {
        strokePriceLine(tsMaLines[i], _tsMaColors[i]);
      }

      if (n > 0) {
        final li = (visibleEndIndex - 1).clamp(0, n - 1).toInt();
        _paintMaLegend(
          canvas,
          Offset(chartLeft + 4, _pad + 2),
          chartRight - chartLeft - 8,
          tsMaLines,
          tsPeriods,
          li,
          precision,
        );

        _paintCurrentPriceLine(
          canvas,
          chartLeft: chartLeft,
          chartRight: chartRight,
          chartH: chartH,
          close: closes[li],
          yForPrice: yForPrice,
        );

        _paintTimeSharingTimeAxis(
          canvas,
          data,
          n,
          slot,
          chartLeft,
          chartRight,
          chartH,
        );
      }
    } else if (mainStyle == KlineMainChartStyle.area) {
      final fillPath = Path();
      var started = false;
      double firstX = 0;
      for (var i = 0; i < n; i++) {
        final c = closes[i];
        final cx = chartLeft + (i + 0.5) * slot;
        final y = yForPrice(c);
        if (!started) {
          fillPath.moveTo(cx, y);
          firstX = cx;
          started = true;
        } else {
          fillPath.lineTo(cx, y);
        }
      }
      if (started) {
        final baseY = chartH - _pad;
        fillPath.lineTo(chartLeft + (n - 0.5) * slot, baseY);
        fillPath.lineTo(firstX, baseY);
        fillPath.close();
        final rise = CardTool.priceColor(1).withValues(alpha: 0.35);
        final shader = ui.Gradient.linear(Offset(0, _pad), Offset(0, chartH), [
          rise,
          rise.withValues(alpha: 0.05),
        ]);
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = shader
            ..style = PaintingStyle.fill,
        );
        strokePriceLine(
          List<double?>.from(closes),
          CardTool.priceColor(1),
          1.2,
        );
      }
    } else {
      for (var i = 0; i < n; i++) {
        final o = opens[i];
        final h = highs[i];
        final l = lows[i];
        final c = closes[i];
        final cx = chartLeft + (i + 0.5) * slot;
        final yH = yForPrice(h);
        final yL = yForPrice(l);
        final yO = yForPrice(o);
        final yC = yForPrice(c);
        final bull = c >= o;
        var col = CardTool.priceColor(bull ? 1.0 : -1.0);
        if (sel != null && i == sel) {
          col = Color.lerp(col, Colors.black, 0.35) ?? col;
        }

        if (mainStyle == KlineMainChartStyle.usLine) {
          final wickPaint = Paint()
            ..color = col
            ..strokeWidth = sel == i ? 1.4 : 1.1
            ..style = PaintingStyle.stroke;
          canvas.drawLine(Offset(cx, yH), Offset(cx, yL), wickPaint);
          final tick = max(1.0, slot * 0.22);
          canvas.drawLine(Offset(cx - tick, yO), Offset(cx, yO), wickPaint);
          canvas.drawLine(Offset(cx, yC), Offset(cx + tick, yC), wickPaint);
          continue;
        }

        final wickPaint = Paint()
          ..color = col
          ..strokeWidth = sel == i ? 1.4 : 1
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx, yH), Offset(cx, yL), wickPaint);

        final top = min(yO, yC);
        final bottom = max(yO, yC);
        final half = bodyW / 2;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx - half,
            top,
            cx + half,
            bottom == top ? top + 1 : bottom,
          ),
          const Radius.circular(0.5),
        );

        if (_klineCandleBodyOutlineOnly(mainStyle, bull)) {
          final bodyStroke = Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = sel == i ? 1.2 : 1;
          if (bottom - top < 1.5) {
            canvas.drawLine(
              Offset(cx - half, top),
              Offset(cx + half, top),
              bodyStroke,
            );
          } else {
            canvas.drawRRect(rect, bodyStroke);
          }
        } else {
          final bodyFill = Paint()
            ..color = col
            ..style = PaintingStyle.fill;
          final bodyStroke = Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = sel == i ? 1.2 : 1;
          if (bottom - top < 1.5) {
            canvas.drawLine(
              Offset(cx - half, top),
              Offset(cx + half, top),
              bodyStroke,
            );
          } else {
            canvas.drawRRect(rect, bodyFill);
            canvas.drawRRect(rect, bodyStroke);
          }
        }
      }
    }

    if (!timeSharingMode) {
      const maColors = _klineIndicatorColors;
      switch (mainOverlay) {
        case KlineMainOverlay.ma:
          for (var i = 0; i < maLines.length && i < maColors.length; i++) {
            strokePriceLine(maLines[i], maColors[i]);
          }
          break;
        case KlineMainOverlay.ema:
          for (var i = 0; i < emaLines.length && i < maColors.length; i++) {
            strokePriceLine(emaLines[i], maColors[i]);
          }
          break;
        case KlineMainOverlay.boll:
          strokePriceLine(boll.upper, const Color(0xFF8E8E93), 0.9);
          strokePriceLine(boll.mid, const Color(0xFFFF9500), 1);
          strokePriceLine(boll.lower, const Color(0xFF8E8E93), 0.9);
          break;
        case KlineMainOverlay.none:
          break;
      }
    }

    if (!timeSharingMode) {
      final li = (visibleEndIndex - 1).clamp(0, n - 1).toInt();
      _paintCurrentPriceLine(
        canvas,
        chartLeft: chartLeft,
        chartRight: chartRight,
        chartH: chartH,
        close: closes[li],
        yForPrice: yForPrice,
      );
    }

    // —— 副图 ——
    if (subChartType == KlineSubChartType.volume) {
      final vmax = vols.isEmpty ? 1 : vols.reduce(max);
      final vscale = vmax <= 0 ? 1.0 : 1.0 / vmax;
      final vPaintBull = Paint()
        ..color = CardTool.priceColor(1).withValues(alpha: 0.55);
      final vPaintBear = Paint()
        ..color = CardTool.priceColor(-1).withValues(alpha: 0.55);
      for (var i = 0; i < n; i++) {
        final v = vols[i].toDouble() * vscale;
        final hBar = subH * v;
        final cx = chartLeft + (i + 0.5) * slot;
        final half = max(1.0, slot * 0.35);
        final top = subTop + subH - hBar;
        final bull = closes[i] >= opens[i];
        final r = RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - half, top, cx + half, subTop + subH),
          const Radius.circular(1),
        );
        canvas.drawRRect(r, bull ? vPaintBull : vPaintBear);
      }
    } else if (subChartType == KlineSubChartType.macd) {
      final macd = KlineIndicators.macd(
        closes,
        fast: macdFast,
        slow: macdSlow,
        signal: macdSignal,
      );
      final ymax = _macdAxisMax(
        closes,
        visibleStartIndex,
        visibleEndIndex,
        macdFast: macdFast,
        macdSlow: macdSlow,
        macdSignal: macdSignal,
      );
      final midY = subTop + subH / 2;
      final scaleY = (subH / 2 - 4) / ymax;

      final zero = Paint()
        ..color = const Color(0xFFCCCCCC)
        ..strokeWidth = 0.5;
      canvas.drawLine(Offset(chartLeft, midY), Offset(chartRight, midY), zero);

      for (var i = 0; i < n; i++) {
        final hi = macd.hist[i];
        if (hi == null) continue;
        final cx = chartLeft + (i + 0.5) * slot;
        final half = max(1.0, slot * 0.22);
        final barH = hi.abs() * scaleY;
        final top = hi >= 0 ? midY - barH : midY;
        final bottom = hi >= 0 ? midY : midY + barH;
        final col = hi >= 0 ? CardTool.priceColor(1) : CardTool.priceColor(-1);
        final r = RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - half, top, cx + half, bottom),
          const Radius.circular(0.5),
        );
        canvas.drawRRect(r, Paint()..color = col.withValues(alpha: 0.65));
      }
      strokeSubLine(
        canvas,
        chartLeft,
        slot,
        n,
        midY,
        scaleY,
        macd.dif,
        const Color(0xFFFF9500),
      );
      strokeSubLine(
        canvas,
        chartLeft,
        slot,
        n,
        midY,
        scaleY,
        macd.dea,
        const Color(0xFF5856D6),
      );
    } else if (subChartType == KlineSubChartType.kdj) {
      final kdj = KlineIndicators.kdj(
        highs,
        lows,
        closes,
        period: kdjPeriod,
        kSmooth: kdjKSmooth,
        dSmooth: kdjDSmooth,
      );
      void line(List<double?> src, Color col) {
        final path = Path();
        var started = false;
        for (var i = 0; i < n; i++) {
          final v = src[i];
          if (v == null) continue;
          final cx = chartLeft + (i + 0.5) * slot;
          final y = subTop + subH - (v.clamp(0, 100) / 100.0) * subH;
          if (!started) {
            path.moveTo(cx, y);
            started = true;
          } else {
            path.lineTo(cx, y);
          }
        }
        if (started) {
          canvas.drawPath(
            path,
            Paint()
              ..color = col
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }

      line(kdj.k, const Color(0xFFFF9500));
      line(kdj.d, const Color(0xFF5856D6));
      line(kdj.j, const Color(0xFF34C759));
    } else if (subChartType == KlineSubChartType.rsi) {
      final rsi = KlineIndicators.rsi(closes, period: rsiPeriod);
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = rsi[i];
        if (v == null) continue;
        final cx = chartLeft + (i + 0.5) * slot;
        final y = subTop + subH - (v.clamp(0, 100) / 100.0) * subH;
        if (!started) {
          path.moveTo(cx, y);
          started = true;
        } else {
          path.lineTo(cx, y);
        }
      }
      if (started) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFF9500)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      }
      final dash = Paint()
        ..color = const Color(0x33AAAAAA)
        ..strokeWidth = 0.5;
      final y30 = subTop + subH * 0.7;
      final y70 = subTop + subH * 0.3;
      canvas.drawLine(Offset(chartLeft, y30), Offset(chartRight, y30), dash);
      canvas.drawLine(Offset(chartLeft, y70), Offset(chartRight, y70), dash);
    } else if (subChartType == KlineSubChartType.dmi) {
      final net = KlineIndicators.dmiNet(
        highs,
        lows,
        closes,
        period: dmiPeriod,
      );
      double ymax = 1e-12;
      for (var i = visibleStartIndex; i < visibleEndIndex; i++) {
        final v = net[i];
        if (v != null) ymax = max(ymax, v.abs());
      }
      if (ymax < 1e-9) ymax = 1;
      final midY = subTop + subH / 2;
      final scaleY = (subH / 2 - 2) / ymax;
      canvas.drawLine(
        Offset(chartLeft, midY),
        Offset(chartRight, midY),
        Paint()
          ..color = const Color(0xFFCCCCCC)
          ..strokeWidth = 0.5,
      );
      for (var i = 0; i < n; i++) {
        final v = net[i];
        if (v == null) continue;
        final cx = chartLeft + (i + 0.5) * slot;
        final half = max(1.0, slot * 0.28);
        final barH = v.abs() * scaleY;
        final top = v >= 0 ? midY - barH : midY;
        final bottom = v >= 0 ? midY : midY + barH;
        final col = v >= 0 ? CardTool.priceColor(1) : CardTool.priceColor(-1);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - half, top, cx + half, bottom),
            const Radius.circular(0.5),
          ),
          Paint()..color = col.withValues(alpha: 0.7),
        );
      }
    }

    if (showGrid && subH > 8) {
      final g = Paint()
        ..color = const Color(0xFFE8E8E8)
        ..strokeWidth = 0.5;
      canvas.drawLine(Offset(chartLeft, subTop), Offset(chartRight, subTop), g);
    }

    final border = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), border);
  }

  void strokeSubLine(
    Canvas canvas,
    double chartLeft,
    double slot,
    int n,
    double midY,
    double scaleY,
    List<double?> series,
    Color color,
  ) {
    final path = Path();
    var started = false;
    for (var i = 0; i < n; i++) {
      final v = series[i];
      if (v == null) continue;
      final cx = chartLeft + (i + 0.5) * slot;
      final y = midY - v * scaleY;
      if (!started) {
        path.moveTo(cx, y);
        started = true;
      } else {
        path.lineTo(cx, y);
      }
    }
    if (started) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KlineCandlePainter oldDelegate) {
    if (rightAxisWidth != oldDelegate.rightAxisWidth) return true;
    if (selectedIndex != oldDelegate.selectedIndex) return true;
    if (visibleStart != oldDelegate.visibleStart ||
        visibleEnd != oldDelegate.visibleEnd ||
        (viewportWidth - oldDelegate.viewportWidth).abs() > 0.01 ||
        (viewportScrollOffset - oldDelegate.viewportScrollOffset).abs() >
            0.01) {
      return true;
    }
    if (mainStyle != oldDelegate.mainStyle ||
        mainOverlay != oldDelegate.mainOverlay ||
        subChartType != oldDelegate.subChartType ||
        showGrid != oldDelegate.showGrid ||
        timeSharingMode != oldDelegate.timeSharingMode) {
      return true;
    }
    if (!listEquals(maPeriods, oldDelegate.maPeriods) ||
        !listEquals(emaPeriods, oldDelegate.emaPeriods)) {
      return true;
    }
    if (macdFast != oldDelegate.macdFast ||
        macdSlow != oldDelegate.macdSlow ||
        macdSignal != oldDelegate.macdSignal ||
        kdjPeriod != oldDelegate.kdjPeriod ||
        kdjKSmooth != oldDelegate.kdjKSmooth ||
        kdjDSmooth != oldDelegate.kdjDSmooth ||
        rsiPeriod != oldDelegate.rsiPeriod ||
        dmiPeriod != oldDelegate.dmiPeriod) {
      return true;
    }
    if (!identical(data, oldDelegate.data)) {
      if (data.length != oldDelegate.data.length) return true;
      if (data.isEmpty) return false;
      final a = data.last;
      final b = oldDelegate.data.last;
      if (a['close'] != b['close'] ||
          a['open'] != b['open'] ||
          a['high'] != b['high'] ||
          a['low'] != b['low'] ||
          a['time'] != b['time']) {
        return true;
      }
    }
    return (pxPerBar - oldDelegate.pxPerBar).abs() > 0.01;
  }
}
