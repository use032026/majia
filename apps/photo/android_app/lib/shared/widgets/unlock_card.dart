import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/st_localizations.dart';
import 'base_card.dart';
import 'card_navigation.dart';

/// 交易解锁卡片。
///
/// 后台可能返回 `unlock_1` / `unlock_2`，Flutter 统一按 iOS `unlock_2`
/// 的视觉和交互渲染。
class UnlockCard extends BaseCard {
  final CardNavigateCallback? onNavigate;
  final Map<String, dynamic>? dataCache;

  const UnlockCard({
    super.key,
    required super.cardData,
    this.onNavigate,
    this.dataCache,
  });

  String _cacheKey() => '${cardData.cardStyle}_${cardData.cardId}';

  Map<String, dynamic>? _payload() {
    final cached = dataCache?[_cacheKey()];
    if (cached is Map<String, dynamic>) return cached;
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return cardData.cardDetail;
  }

  @override
  Widget buildCardContent(BuildContext context) {
    final payload = _payload();
    if (payload == null || payload.isEmpty) return const SizedBox.shrink();

    return Consumer(
      builder: (context, ref, _) {
        return _UnlockLocalizedScope(
          payload: payload,
          builder: (context, strings) {
            final stage = _intValue(payload['stage']);

            void openActivity() {
              final route = _activityRoute(
                payload,
                fallbackLink: cardData.link,
              );
              if (route.path.isEmpty) return;
              onNavigate?.call(route.path, route.params, action: '交易解锁活动');
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: openActivity,
                  borderRadius: BorderRadius.circular(10),
                  child: stage == 0
                      ? _Unlock2NewbieBody(
                          payload: payload,
                          strings: strings,
                          onNavigate: onNavigate,
                        )
                      : _Unlock2CurrentBody(
                          payload: payload,
                          strings: strings,
                          onOpenActivity: openActivity,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UnlockLocalizedScope extends ConsumerStatefulWidget {
  final Map<String, dynamic> payload;
  final Widget Function(BuildContext context, _UnlockStrings strings) builder;

  const _UnlockLocalizedScope({required this.payload, required this.builder});

  @override
  ConsumerState<_UnlockLocalizedScope> createState() =>
      _UnlockLocalizedScopeState();
}

class _UnlockLocalizedScopeState extends ConsumerState<_UnlockLocalizedScope> {
  String? _loadKey;
  int _loadToken = 0;
  _UnlockStrings _strings = _UnlockStrings.defaults;

  @override
  Widget build(BuildContext context) {
    final localizations = ref.watch(stLocalizationsProvider);
    _ensureLocalized(localizations);
    return widget.builder(context, _strings);
  }

  void _ensureLocalized(STLocalizations localizations) {
    final titleKey = _stringValue(widget.payload['title_key']);
    final titleFallback = _stringValue(widget.payload['title']);
    final loadKey = '${localizations.languageCode}:$titleKey:$titleFallback';
    if (_loadKey == loadKey) return;
    _loadKey = loadKey;
    _strings = _UnlockStrings.defaults.copyWith(
      title: titleFallback.isEmpty
          ? _fallbackTitle(widget.payload)
          : titleFallback,
    );

    final token = ++_loadToken;
    Future.wait([
      localizations.cardText('unlock_2', 'days_unit', fallback: '天'),
      localizations.cardText('unlock_2', 'completed', fallback: '已完成'),
      localizations.cardText('unlock_2', 'limited_time', fallback: '限时'),
      localizations.cardText(
        'unlock_2',
        'total_award_title',
        fallback: '注册登录即可获得',
      ),
      localizations.cardText('unlock_2', 'unlocking', fallback: '正在解锁'),
      localizations.text(
        titleKey.isEmpty ? _fallbackTitleKey(widget.payload) : titleKey,
        fallback: _fallbackTitle(widget.payload),
      ),
    ]).then((values) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _strings = _UnlockStrings(
          daysUnit: values[0],
          completed: values[1],
          limitedTime: values[2],
          totalAwardTitle: values[3],
          unlocking: values[4],
          title: values[5],
        );
      });
    });
  }
}

class _UnlockStrings {
  final String daysUnit;
  final String completed;
  final String limitedTime;
  final String totalAwardTitle;
  final String unlocking;
  final String title;

  const _UnlockStrings({
    required this.daysUnit,
    required this.completed,
    required this.limitedTime,
    required this.totalAwardTitle,
    required this.unlocking,
    required this.title,
  });

  static const defaults = _UnlockStrings(
    daysUnit: '天',
    completed: '已完成',
    limitedTime: '限时',
    totalAwardTitle: '注册登录即可获得',
    unlocking: '正在解锁',
    title: '新人奖励',
  );

  _UnlockStrings copyWith({String? title}) {
    return _UnlockStrings(
      daysUnit: daysUnit,
      completed: completed,
      limitedTime: limitedTime,
      totalAwardTitle: totalAwardTitle,
      unlocking: unlocking,
      title: title ?? this.title,
    );
  }
}

class _Unlock2NewbieBody extends StatefulWidget {
  final Map<String, dynamic> payload;
  final _UnlockStrings strings;
  final CardNavigateCallback? onNavigate;

  const _Unlock2NewbieBody({
    required this.payload,
    required this.strings,
    required this.onNavigate,
  });

  @override
  State<_Unlock2NewbieBody> createState() => _Unlock2NewbieBodyState();
}

class _Unlock2NewbieBodyState extends State<_Unlock2NewbieBody> {
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _readCountdown(widget.payload);
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _Unlock2NewbieBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload != widget.payload) {
      _remaining = _readCountdown(widget.payload);
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    if (_timer != null || _remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) _remaining--;
      });
    });
  }

  void _openTask(int index, List<_UnlockTask> tasks) {
    final task = tasks[index];
    final previousDone = index == 0 || tasks[index - 1].completed;
    if (task.completed || !previousDone) return;
    if (task.path.isEmpty) return;
    widget.onNavigate?.call(task.path, task.params, action: task.name);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks(widget.payload);
    final completedCount = tasks.where((task) => task.completed).length;
    final totalCount = tasks.isEmpty ? 3 : tasks.length;
    final progressRatio = _newbieProgressRatio(completedCount, totalCount);
    final total = _stringValue(
      widget.payload['total_amount'] ?? widget.payload['totalAmount'],
    );
    final subtitle = total.isEmpty
        ? ''
        : '${widget.strings.totalAwardTitle}\$$total';

    return _Unlock2Background(
      key: const ValueKey('unlock_2_newbie_body'),
      height: 160,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            top: 14,
            height: 16,
            child: _Unlock2Header(
              title: widget.strings.title,
              countdown: _CountdownParts.fromSeconds(
                _remaining,
              ).newbieLabel(widget.strings.daysUnit),
              countdownTextColor: Colors.black,
              trailing: Text(
                '${widget.strings.completed}$completedCount/$totalCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF60656D)),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 38,
            height: 16,
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9A9DA2)),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 72,
            height: 24,
            child: _TaskButtonRow(
              tasks: tasks,
              onTap: (index) => _openTask(index, tasks),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 102,
            height: 20,
            child: _ProgressRow(tasks: tasks, progressRatio: progressRatio),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 124,
            height: 20,
            child: _TaskAmountRow(tasks: tasks),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 146,
            height: 14,
            child: _TaskNameRow(tasks: tasks),
          ),
        ],
      ),
    );
  }
}

class _Unlock2CurrentBody extends StatefulWidget {
  final Map<String, dynamic> payload;
  final _UnlockStrings strings;
  final VoidCallback onOpenActivity;

  const _Unlock2CurrentBody({
    required this.payload,
    required this.strings,
    required this.onOpenActivity,
  });

  @override
  State<_Unlock2CurrentBody> createState() => _Unlock2CurrentBodyState();
}

class _Unlock2CurrentBodyState extends State<_Unlock2CurrentBody> {
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _readCountdown(widget.payload);
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _Unlock2CurrentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload != widget.payload) {
      _remaining = _readCountdown(widget.payload);
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    if (_timer != null || _remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) _remaining--;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _stringValue(
      widget.payload['unlocked_amount'] ?? widget.payload['unlockedAmount'],
      fallback: '0',
    );
    final total = _stringValue(
      widget.payload['total_amount'] ?? widget.payload['totalAmount'],
    );
    final symbols = _symbols(widget.payload);

    return _Unlock2Background(
      key: const ValueKey('unlock_2_current_body'),
      height: 109,
      lightAsset: 'assets/images/current_unlock_light.png',
      darkAsset: 'assets/images/current_unlock_dark.png',
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            height: 16,
            child: _Unlock2Header(
              title: widget.strings.title,
              countdown: _CountdownParts.fromSeconds(_remaining).currentLabel(
                widget.strings.limitedTime,
                widget.strings.daysUnit,
              ),
              countdownTextColor: Colors.white,
              trailing: Text(
                widget.strings.unlocking,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A9DA2)),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 32,
            child: Text(
              total.isEmpty
                  ? widget.strings.title
                  : '${widget.strings.totalAwardTitle}\$$total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9A9DA2)),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 58,
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '\$$unlocked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.06,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenActivity,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Image.asset(
                        'assets/images/st_activity_right.png',
                        width: 16,
                        height: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final symbol in symbols) _SymbolChip(symbol: symbol),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Unlock2Background extends StatelessWidget {
  final double height;
  final String lightAsset;
  final String darkAsset;
  final Widget child;

  const _Unlock2Background({
    super.key,
    required this.height,
    this.lightAsset = 'assets/images/unlock_2_bg.png',
    this.darkAsset = 'assets/images/unlock_2_bg_dark.png',
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _isDark(context) ? darkAsset : lightAsset,
              fit: BoxFit.fill,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Unlock2Header extends StatelessWidget {
  final String title;
  final String countdown;
  final Color countdownTextColor;
  final Widget trailing;

  const _Unlock2Header({
    required this.title,
    required this.countdown,
    required this.countdownTextColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF4DCB73),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _TimePill(
                    label: countdown,
                    textColor: countdownTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Align(
          alignment: Alignment.centerRight,
          child: trailing,
        ),
      ],
    );
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final Color textColor;

  const _TimePill({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/unlock_2_time_bg.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _TaskButtonRow extends StatelessWidget {
  final List<_UnlockTask> tasks;
  final ValueChanged<int> onTap;

  const _TaskButtonRow({required this.tasks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final anchors = _taskAnchors(width);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < 3; i++)
              if (i < tasks.length)
                Positioned(
                  left: anchors[i],
                  top: 0,
                  height: 24,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: _UnionButton(task: tasks[i], onTap: () => onTap(i)),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _UnionButton extends StatelessWidget {
  final _UnlockTask task;
  final VoidCallback onTap;

  const _UnionButton({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: const Alignment(0, -0.2),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              task.completed
                  ? 'assets/images/unlock_2_union_completed.png'
                  : 'assets/images/unlock_2_union_no_complete.png',
            ),
            fit: BoxFit.fill,
          ),
        ),
        child: Text(
          task.buttonTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: task.completed ? Colors.white : const Color(0xFF9A9DA2),
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final List<_UnlockTask> tasks;
  final double progressRatio;

  const _ProgressRow({required this.tasks, required this.progressRatio});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final anchors = _taskAnchors(width);
        return SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: anchors.first,
                right: width - anchors.last,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFFF0F0F0)),
                        FractionallySizedBox(
                          widthFactor: progressRatio,
                          alignment: Alignment.centerLeft,
                          child: const ColoredBox(color: Color(0xFF00B57A)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: anchors[i] - 10,
                  top: 0,
                  width: 20,
                  height: 20,
                  child: Image.asset(
                    i < tasks.length && tasks[i].completed
                        ? 'assets/images/unlock_2_completed_icon.png'
                        : 'assets/images/unlock_2_no_complete_icon.png',
                    width: 20,
                    height: 20,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskAmountRow extends StatelessWidget {
  final List<_UnlockTask> tasks;

  const _TaskAmountRow({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchors = _taskAnchors(constraints.maxWidth);
        return Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: anchors[i] - 45,
                top: 0,
                width: 90,
                height: 20,
                child: Text(
                  '+\$${i < tasks.length ? tasks[i].amount : '--'}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskNameRow extends StatelessWidget {
  final List<_UnlockTask> tasks;

  const _TaskNameRow({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchors = _taskAnchors(constraints.maxWidth);
        return Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: anchors[i] - 48,
                top: 0,
                width: 96,
                child: Text(
                  i < tasks.length ? tasks[i].name : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF60656D),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

const double _taskAnchorInset = 30;

List<double> _taskAnchors(double width) {
  return [_taskAnchorInset, width / 2, width - _taskAnchorInset];
}

class _SymbolChip extends StatelessWidget {
  final String symbol;

  const _SymbolChip({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 50, maxWidth: 90),
      height: 18,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00B57A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        symbol,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Color(0xFF60656D)),
      ),
    );
  }
}

class _CountdownParts {
  final String days;
  final String hours;
  final String minutes;
  final String seconds;

  const _CountdownParts({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  factory _CountdownParts.fromSeconds(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final days = safe ~/ 86400;
    final hours = (safe % 86400) ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final secs = safe % 60;
    return _CountdownParts(
      days: _twoDigits(days),
      hours: _twoDigits(hours),
      minutes: _twoDigits(minutes),
      seconds: _twoDigits(secs),
    );
  }

  String newbieLabel(String daysUnit) =>
      '$days$daysUnit $hours:$minutes:$seconds';

  String currentLabel(String limitedTime, String daysUnit) {
    return '$limitedTime$days$daysUnit $hours:$minutes:$seconds';
  }
}

class _UnlockTask {
  final String name;
  final String amount;
  final bool completed;
  final String completedButtonName;
  final String uncompletedButtonName;
  final String path;
  final Map<String, dynamic>? params;

  const _UnlockTask({
    required this.name,
    required this.amount,
    required this.completed,
    required this.completedButtonName,
    required this.uncompletedButtonName,
    required this.path,
    required this.params,
  });

  String get buttonTitle =>
      completed ? completedButtonName : uncompletedButtonName;

  factory _UnlockTask.fromMap(Map<String, dynamic> map) {
    final route = _routeFromMap(map);
    return _UnlockTask(
      name: _stringValue(
        map['task_name'] ?? map['taskName'] ?? map['name'] ?? map['title'],
      ),
      amount: _stringValue(
        map['unlock_amount'] ?? map['unlockAmount'],
        fallback: '--',
      ),
      completed: map['is_completed'] == true || map['isCompleted'] == true,
      completedButtonName: _stringValue(
        map['completed_button_name'] ?? map['completedButtonName'],
        fallback: '已完成',
      ),
      uncompletedButtonName: _stringValue(
        map['uncompleted_button_name'] ?? map['uncompletedButtonName'],
        fallback: '--',
      ),
      path: route.path,
      params: route.params,
    );
  }
}

List<_UnlockTask> _tasks(Map<String, dynamic> payload) {
  final raw = payload['tasks'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => _UnlockTask.fromMap(Map<String, dynamic>.from(e)))
      .take(3)
      .toList();
}

List<String> _symbols(Map<String, dynamic> payload) {
  final out = <String>[];
  for (final key in ['symbol1', 'symbol2', 'symbol3']) {
    final value = _stringValue(payload[key]).trim();
    if (value.isNotEmpty) out.add(value);
  }
  if (out.isNotEmpty) return out;

  final raw = payload['symbols'];
  if (raw is List) {
    final sorted =
        raw
            .whereType<Map>()
            .map((e) {
              final map = Map<String, dynamic>.from(e);
              final sym = _stringValue(map['symbol']).trim();
              final amt =
                  num.tryParse(
                    '${map['settlement_per_unit_amount'] ?? map['settlementPerUnitAmount'] ?? 0}',
                  ) ??
                  0;
              return (sym, amt);
            })
            .where((e) => e.$1.isNotEmpty)
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    return sorted.take(3).map((e) => e.$1).toList();
  }
  return out;
}

double _newbieProgressRatio(int completedCount, int totalCount) {
  final segments = totalCount > 1 ? totalCount - 1 : 1;
  return (completedCount / segments).clamp(0, 1).toDouble();
}

({String path, Map<String, dynamic>? params}) _activityRoute(
  Map<String, dynamic> payload, {
  String? fallbackLink,
}) {
  final route = _routeFromMap(payload);
  if (route.path.isNotEmpty) return route;

  final link = _stringValue(
    payload['activity_url'] ??
        payload['activityUrl'] ??
        payload['link'] ??
        fallbackLink,
  ).trim();
  if (link.isEmpty) return (path: '', params: null);
  return (path: '/web', params: {'link': link});
}

({String path, Map<String, dynamic>? params}) _routeFromMap(
  Map<String, dynamic> map,
) {
  final routerModel =
      map['router_model'] ?? map['routerModel'] ?? map['router'];
  if (routerModel is Map) {
    final raw = Map<String, dynamic>.from(routerModel);
    final path = _stringValue(
      raw['path'] ?? raw['router'] ?? raw['url'],
    ).trim();
    final params = raw['params'];
    return (
      path: path,
      params: params is Map ? Map<String, dynamic>.from(params) : null,
    );
  }

  final path = _stringValue(map['path'] ?? map['router']).trim();
  if (path.isNotEmpty) {
    final params = map['params'];
    return (
      path: path,
      params: params is Map ? Map<String, dynamic>.from(params) : null,
    );
  }

  final link = _stringValue(map['link']).trim();
  if (link.isNotEmpty) return (path: '/web', params: {'link': link});
  return (path: '', params: null);
}

int _readCountdown(Map<String, dynamic> payload) {
  final raw = payload['count_down'] ?? payload['countDown'];
  return _intValue(raw).clamp(0, 1 << 30);
}

int _intValue(dynamic raw) {
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw') ?? 0;
}

String _stringValue(dynamic raw, {String fallback = ''}) {
  final value = raw?.toString() ?? '';
  return value.isEmpty ? fallback : value;
}

String _twoDigits(int value) => value >= 10 ? '$value' : '0$value';

String _fallbackTitle(Map<String, dynamic> payload) {
  return _intValue(payload['stage']) == 0 ? '新人奖励' : '正在解锁';
}

String _fallbackTitleKey(Map<String, dynamic> payload) {
  return _intValue(payload['stage']) == 0 ? 'newcomer_rewards' : 'unlocking';
}

bool _isDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}
