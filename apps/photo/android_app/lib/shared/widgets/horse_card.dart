import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_data_manager.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'card_factory.dart';

class Horse3Card extends ConsumerStatefulWidget {
  final ConfigCardItemData cardData;
  final CardNavigateCallback? onNavigate;

  const Horse3Card({super.key, required this.cardData, this.onNavigate});

  @override
  ConsumerState<Horse3Card> createState() => _Horse3CardState();
}

class _Horse3CardState extends ConsumerState<Horse3Card>
    with SingleTickerProviderStateMixin {
  static const double _outerPadding = 16;
  static const double _elementGap = 16;
  static const double _arrowGap = 8;
  static const double _badgeSize = 32;
  static const double _arrowSize = 24;
  static const double _tickerHeight = 37;
  static const double _cardHeight = 69;
  static const Duration _pauseDuration = Duration(milliseconds: 2000);
  static const Duration _animationDuration = Duration(milliseconds: 500);
  static const Color _brandGreen = Color(0xFF00B57A);
  static const Color _cardBgLight = Color(0xFFFFFFFF);
  static const Color _cardBgDark = Color(0xFF212229);
  static const String _rightIconAssetLight =
      'assets/images/st_mine_arrow_more.png';
  static const String _rightIconAssetDark =
      'assets/images/st_mine_arrow_more.png';

  late final AnimationController _controller;
  Timer? _timer;
  int _index = 0;
  int _nextIndex = 0;
  bool _paused = false;
  bool _animating = false;
  String _messageSignature = '';

  List<_HorseMessage> get _messages =>
      _HorsePayload.from(widget.cardData).items;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animationDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _index = _nextIndex;
            _animating = false;
            _controller.reset();
          });
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messages = _messages;
      _messageSignature = _signatureFor(messages);
      _restartTimer(messages);
    });
  }

  @override
  void didUpdateWidget(covariant Horse3Card oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardData.cardId != widget.cardData.cardId ||
        oldWidget.cardData.cardDetail != widget.cardData.cardDetail) {
      _index = 0;
      _nextIndex = 0;
      _animating = false;
      _paused = false;
      _messageSignature = _signatureFor(_messages);
      _controller.reset();
      _restartTimer(_messages);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer(List<_HorseMessage> messages) {
    _timer?.cancel();
    _timer = null;
    if (!mounted || messages.length <= 1) return;
    _timer = Timer.periodic(_pauseDuration + _animationDuration, (_) {
      if (!mounted || _paused || _animating) return;
      final messages = _messages;
      if (messages.length <= 1) return;
      setState(() {
        _nextIndex = (_index + 1) % messages.length;
        _animating = true;
      });
      _controller.forward(from: 0);
    });
  }

  void _syncTickerMessages(List<_HorseMessage> messages) {
    final signature = _signatureFor(messages);
    final changed = signature != _messageSignature;
    final timerMissing = messages.length > 1 && _timer == null;
    if (!changed && !timerMissing) return;

    _messageSignature = signature;
    if (changed) {
      _index = 0;
      _nextIndex = messages.length > 1 ? 1 : 0;
      _animating = false;
      _paused = false;
      _controller.reset();
    } else if (messages.isNotEmpty) {
      _index = _index.clamp(0, messages.length - 1).toInt();
      _nextIndex = _nextIndex.clamp(0, messages.length - 1).toInt();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restartTimer(messages);
      }
    });
  }

  String _signatureFor(List<_HorseMessage> messages) {
    return messages
        .map((e) => '${e.title}\u0001${e.subtitle}\u0001${e.route.path}')
        .join('\u0002');
  }

  void _togglePause() {
    if (_messages.length <= 1) return;
    setState(() => _paused = !_paused);
  }

  void _openRoute(_HorseRoute route, {String? action}) {
    if (route.path.isEmpty) return;
    widget.onNavigate?.call(route.path, route.params, action: action);
  }

  @override
  Widget build(BuildContext context) {
    final configMgr = ref.watch(configDataManagerProvider);
    final payload = _HorsePayload.from(widget.cardData);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = payload.items;
    _syncTickerMessages(messages);
    final visible = messages.isEmpty
        ? _HorseMessage(title: widget.cardData.title ?? '市场快讯')
        : messages[_index.clamp(0, messages.length - 1)];
    final incoming = messages.isEmpty
        ? visible
        : messages[_nextIndex.clamp(0, messages.length - 1)];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _togglePause(),
      child: Container(
        height: _cardHeight,
        margin: EdgeInsets.symmetric(
          horizontal: configMgr.cardHorGap,
          vertical: configMgr.cardVerGap,
        ),
        decoration: BoxDecoration(
          color: isDark ? _cardBgDark : _cardBgLight,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            const SizedBox(width: _outerPadding),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openRoute(payload.left.route, action: 'Horse左按钮'),
              child: const _HorseVoiceBadge(),
            ),
            const SizedBox(width: _elementGap),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openRoute(visible.route, action: 'Horse消息'),
                child: SizedBox(
                  height: _tickerHeight,
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final v = Curves.easeInOut.transform(_controller.value);
                        return Stack(
                          children: [
                            Transform.translate(
                              offset: Offset(
                                0,
                                _animating ? -_tickerHeight * v : 0,
                              ),
                              child: _Horse3TextSlot(
                                message: visible,
                                isDark: isDark,
                              ),
                            ),
                            if (_animating)
                              Transform.translate(
                                offset: Offset(0, _tickerHeight * (1 - v)),
                                child: _Horse3TextSlot(
                                  message: incoming,
                                  isDark: isDark,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: _arrowGap),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openRoute(payload.right.route, action: 'Horse右按钮'),
              child: SizedBox.square(
                dimension: _arrowSize,
                child: _HorseIcon(
                  url: payload.right.iconFor(isDark),
                  fallback: Icons.chevron_right_rounded,
                  size: _arrowSize,
                  fallbackAssetLight: _rightIconAssetLight,
                  fallbackAssetDark: _rightIconAssetDark,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: _outerPadding),
          ],
        ),
      ),
    );
  }
}

class _Horse3TextSlot extends StatelessWidget {
  static const Color _titleColorLight = Color(0xFF000000);
  static const Color _titleColorDark = Color(0xFFEDF1F8);
  static const Color _subtitleColorLight = Color(0xFF60656D);
  static const Color _subtitleColorDark = Color(0xFFABAFB8);

  final _HorseMessage message;
  final bool isDark;

  const _Horse3TextSlot({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final title = message.title.trim();
    final subtitle = message.subtitle.trim();
    final titleStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 15 / 12,
      letterSpacing: 1,
      color: isDark ? _titleColorDark : _titleColorLight,
    );
    final subtitleStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 20 / 12,
      color: isDark ? _subtitleColorDark : _subtitleColorLight,
    );
    return SizedBox(
      height: _Horse3CardState._tickerHeight,
      width: double.infinity,
      child: subtitle.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                if (title.isNotEmpty) const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
              ],
            ),
    );
  }
}

class _HorseVoiceBadge extends StatelessWidget {
  static const String _asset = 'assets/images/st_voice.png';

  const _HorseVoiceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Horse3CardState._badgeSize,
      height: _Horse3CardState._badgeSize,
      decoration: BoxDecoration(
        color: _Horse3CardState._brandGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Image.asset(_asset, width: 20, height: 16, fit: BoxFit.contain),
    );
  }
}

class _HorseIcon extends StatelessWidget {
  final String url;
  final IconData fallback;
  final double size;
  final bool isDark;
  final String fallbackAssetLight;
  final String fallbackAssetDark;

  const _HorseIcon({
    required this.url,
    required this.fallback,
    required this.size,
    required this.isDark,
    required this.fallbackAssetLight,
    required this.fallbackAssetDark,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return _buildFallback(
        context,
        fallbackAsset: isDark ? fallbackAssetDark : fallbackAssetLight,
      );
    }
    return Image.network(
      url.trim(),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return _buildFallback(
          context,
          fallbackAsset: isDark ? fallbackAssetDark : fallbackAssetLight,
        );
      },
    );
  }

  Widget _buildFallback(BuildContext context, {required String fallbackAsset}) {
    final color = context.adaptiveTextTertiary;
    if (fallbackAsset.isNotEmpty) {
      return Image.asset(
        fallbackAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(fallback, size: size, color: color),
      );
    }
    return Icon(fallback, size: size, color: color);
  }
}

class _HorsePayload {
  final _HorseButton left;
  final _HorseButton right;
  final List<_HorseMessage> items;

  const _HorsePayload({
    required this.left,
    required this.right,
    required this.items,
  });

  factory _HorsePayload.from(ConfigCardItemData card) {
    final detail = card.cardDetail ?? const <String, dynamic>{};
    final rawItems =
        detail['items'] ??
        detail['messages'] ??
        detail['message_list'] ??
        detail['messageList'] ??
        detail['data_list'] ??
        detail['dataList'] ??
        detail['list'] ??
        detail['data'];
    return _HorsePayload(
      left: _HorseButton.from(detail['left_button']),
      right: _HorseButton.from(detail['right_button']),
      items: _asList(rawItems)
          .map(_HorseMessage.from)
          .where((e) => e.title.isNotEmpty || e.subtitle.isNotEmpty)
          .toList(),
    );
  }
}

class _HorseButton {
  final String icon;
  final String iconDark;
  final _HorseRoute route;

  const _HorseButton({
    required this.icon,
    required this.iconDark,
    required this.route,
  });

  factory _HorseButton.from(dynamic raw) {
    final map = _asMap(raw);
    final icon = _string(map['icon']);
    final iconDark = _string(map['icon_dark'] ?? map['iconDark']);
    return _HorseButton(
      icon: icon,
      iconDark: iconDark.isEmpty ? icon : iconDark,
      route: _HorseRoute.from(map),
    );
  }

  String iconFor(bool isDark) => isDark ? iconDark : icon;
}

class _HorseMessage {
  final String title;
  final String subtitle;
  final _HorseRoute route;

  const _HorseMessage({
    this.title = '',
    this.subtitle = '',
    this.route = const _HorseRoute(path: ''),
  });

  factory _HorseMessage.from(dynamic raw) {
    final map = _asMap(raw);
    return _HorseMessage(
      title: _string(map['title']),
      subtitle: _string(map['sub_title'] ?? map['subTitle'] ?? map['subtitle']),
      route: _HorseRoute.from(map),
    );
  }
}

class _HorseRoute {
  final String path;
  final Map<String, dynamic>? params;

  const _HorseRoute({required this.path, this.params});

  factory _HorseRoute.from(Map<String, dynamic> map) {
    final extracted = CardFactory.extractItemRoute(map);
    return _HorseRoute(path: extracted.path, params: extracted.params);
  }
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic raw) => raw is List ? raw : const [];

String _string(dynamic value) => value?.toString() ?? '';
