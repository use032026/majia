import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class STPullRefresh extends StatefulWidget {
  const STPullRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
  });

  static const double triggerDistance = 52;
  static const double indicatorSize = 30;
  static const String refreshAsset = 'assets/images/Pull_refresh.gif';
  static const Key headerKey = ValueKey<String>('st_pull_refresh_header');

  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;

  @override
  State<STPullRefresh> createState() => _STPullRefreshState();
}

class _STPullRefreshState extends State<STPullRefresh>
    with SingleTickerProviderStateMixin {
  static const Duration _minimumRefreshVisibleDuration = Duration(
    milliseconds: 300,
  );
  static const Duration _settleDuration = Duration(milliseconds: 180);

  late final AnimationController _settleController;

  Animation<double>? _settleAnimation;
  double _displayExtent = 0;
  bool _refreshing = false;
  Duration? _refreshVisibleSince;

  bool get _showHeader => _refreshing || _displayExtent > 0;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: _settleDuration,
    )..addListener(_handleSettleTick);
  }

  void _handleSettleTick() {
    final animation = _settleAnimation;
    if (animation == null) {
      return;
    }
    final nextValue = animation.value;
    if ((nextValue - _displayExtent).abs() < 0.5) {
      return;
    }
    setState(() => _displayExtent = nextValue);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_refreshing) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _settleController.stop();
      return false;
    }

    if (notification is OverscrollNotification && notification.overscroll < 0) {
      _setDisplayExtent(_displayExtent + -notification.overscroll);
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < notification.metrics.minScrollExtent) {
      _setDisplayExtent(
        notification.metrics.minScrollExtent - notification.metrics.pixels,
      );
      return false;
    }

    if (notification is ScrollEndNotification) {
      if (_displayExtent >= STPullRefresh.triggerDistance) {
        _startRefresh();
      } else {
        _animateDisplayExtent(0);
      }
    }

    return false;
  }

  void _setDisplayExtent(double value) {
    final nextValue = value.clamp(0, STPullRefresh.triggerDistance).toDouble();
    if ((nextValue - _displayExtent).abs() < 0.5) {
      return;
    }
    _settleController.stop();
    setState(() => _displayExtent = nextValue);
  }

  void _animateDisplayExtent(double target) {
    if ((target - _displayExtent).abs() < 0.5) {
      if (_displayExtent != target) {
        setState(() => _displayExtent = target);
      }
      return;
    }
    _settleAnimation = Tween<double>(
      begin: _displayExtent,
      end: target,
    ).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOut),
    );
    _settleController.forward(from: 0);
  }

  Future<void> _startRefresh() async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
      _displayExtent = STPullRefresh.triggerDistance;
      _refreshVisibleSince =
          SchedulerBinding.instance.currentSystemFrameTimeStamp;
    });
    try {
      await widget.onRefresh();
    } finally {
      final visibleSince = _refreshVisibleSince;
      if (visibleSince != null) {
        final elapsed =
            SchedulerBinding.instance.currentSystemFrameTimeStamp - visibleSince;
        final remaining = _minimumRefreshVisibleDuration - elapsed;
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
      }
      if (mounted) {
        setState(() {
          _refreshing = false;
          _refreshVisibleSince = null;
        });
        _animateDisplayExtent(0);
      }
    }
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headerOpacity = _refreshing
        ? 1.0
        : (_displayExtent / STPullRefresh.triggerDistance).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_showHeader)
          Positioned(
            top: math.max(
              0,
              (_displayExtent - STPullRefresh.indicatorSize) / 2,
            ),
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: headerOpacity,
                child: const Center(
                  child: SizedBox(
                    key: STPullRefresh.headerKey,
                    width: STPullRefresh.indicatorSize,
                    height: STPullRefresh.indicatorSize,
                    child: Image(
                      image: AssetImage(STPullRefresh.refreshAsset),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Transform.translate(
          offset: Offset(0, _displayExtent),
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
