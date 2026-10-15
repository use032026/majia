import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

Future<void> showTradeNoLimitSheet({
  required BuildContext context,
  String title = '暂时无法开仓',
  bool noLimit = false,
  TradeLevelChangeData? levelData,
  VoidCallback? onContactSupport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (_) {
      if (levelData != null) {
        return TradeUserLevelChangeSheet(data: levelData.raw);
      }
      if (noLimit) {
        return TradeNoLimitSheet.noLimit(onContactSupport: onContactSupport);
      }
      return TradeNoLimitSheet(
        title: title,
        onContactSupport: onContactSupport,
      );
    },
  );
}

class TradeNoLimitSheet extends StatefulWidget {
  const TradeNoLimitSheet({
    super.key,
    this.title = '暂时无法开仓',
    this.showContactAction = false,
    this.onConfirm,
    this.onContactSupport,
  });

  const TradeNoLimitSheet.noLimit({
    super.key,
    this.onConfirm,
    this.onContactSupport,
  }) : title = '暂时无法使用该功能',
       showContactAction = true;

  final String title;
  final bool showContactAction;
  final VoidCallback? onConfirm;
  final VoidCallback? onContactSupport;

  static const defaultTitle = '暂时无法开仓';
  static const noLimitTitle = '暂时无法使用该功能';

  @override
  State<TradeNoLimitSheet> createState() => _TradeNoLimitSheetState();
}

class _TradeNoLimitSheetState extends State<TradeNoLimitSheet> {
  static const _fallbacks = {
    'trade_temp_unable': TradeNoLimitSheet.defaultTitle,
    'not_enable_trade': TradeNoLimitSheet.noLimitTitle,
    'account_level_adjust_tip1': '您的账户正等待等级调整',
    'account_level_adjust_tip2': '✓ 可平仓 ✗ 不可开仓',
    'account_level_adjust_tip3': '平仓后自动调整等级，即可恢复交易',
    'i_see': '知道了',
    'contact_customer_service': '联系客服',
  };

  Map<String, String> _labels = _fallbacks;
  String? _languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    _loadLabels(languageCode);
  }

  Future<void> _loadLabels(String languageCode) async {
    final labels = await STLocalizations.ofContext(context).textMap(_fallbacks);
    if (!mounted || _languageCode != languageCode) return;
    setState(() => _labels = labels);
  }

  String get _title {
    if (widget.title == TradeNoLimitSheet.defaultTitle) {
      return _labels['trade_temp_unable'] ?? TradeNoLimitSheet.defaultTitle;
    }
    if (widget.title == TradeNoLimitSheet.noLimitTitle) {
      return _labels['not_enable_trade'] ?? TradeNoLimitSheet.noLimitTitle;
    }
    return widget.title;
  }

  @override
  Widget build(BuildContext context) {
    final tips = [
      _labels['account_level_adjust_tip1'] ?? '您的账户正等待等级调整',
      _labels['account_level_adjust_tip2'] ?? '✓ 可平仓 ✗ 不可开仓',
      _labels['account_level_adjust_tip3'] ?? '平仓后自动调整等级，即可恢复交易',
    ];

    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('trade_no_limit_sheet_shell'),
        decoration: BoxDecoration(
          color: context.adaptiveCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        ),
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      'assets/images/st_mine_close_gary.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final tip in tips) ...[
              Text(
                tip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.adaptiveTextTertiary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 14),
            if (widget.showContactAction) ...[
              _SheetButton(
                label: _labels['i_see'] ?? '知道了',
                backgroundColor: const Color(0xFF00B57A),
                foregroundColor: Colors.white,
                onPressed: () {
                  widget.onConfirm?.call();
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(height: 10),
              _SheetButton(
                label: _labels['contact_customer_service'] ?? '联系客服',
                backgroundColor: context.adaptiveMutedBlock,
                foregroundColor: context.adaptiveTextPrimary,
                onPressed: () {
                  widget.onContactSupport?.call();
                  Navigator.of(context).maybePop();
                },
              ),
            ] else
              _SheetButton(
                label: _labels['i_see'] ?? '知道了',
                backgroundColor: const Color(0xFF00B57A),
                foregroundColor: Colors.white,
                onPressed: () {
                  widget.onConfirm?.call();
                  Navigator.of(context).maybePop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class TradeUserLevelChangeSheet extends StatefulWidget {
  const TradeUserLevelChangeSheet({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<TradeUserLevelChangeSheet> createState() =>
      _TradeUserLevelChangeSheetState();
}

class _TradeUserLevelChangeSheetState extends State<TradeUserLevelChangeSheet> {
  static const _fallbacks = {
    'account_level_adjust_tip1': '您的账户正等待等级调整',
    'account_level_adjust_tip3': '平仓后自动调整等级，即可恢复交易',
    'i_see': '知道了',
    'user_upgrade_down_1': '等级调整提醒',
    'user_upgrade_down_2': '等级调整：',
    'user_upgrade_down_3': '变更原因：',
    'user_upgrade_down_4': '可继续交易，开仓权限已禁用，平仓后自动调整等级',
    'user_upgrade_up_1': '恭喜！即将升级为',
    'user_upgrade_up_2': '升级尊享权益：',
    'user_upgrade_up_2_a': '✔ 更优的点差',
    'user_upgrade_up_2_b': '✔ 更低的手续费',
    'user_upgrade_up_2_c': '✔ 专属客服支持',
    'user_upgrade_up_3': '可继续交易，平仓后自动升级',
    'user_upgrade_current_position_ios': '当前有%@笔持仓',
    'account_2': '账户',
    'not_reached': '未达到',
    'level_standard': '等级标准',
    'last_1_days': '近1日',
    'last_7_days': '近7日',
    'last_30_days': '近30日',
    'last_90_days': '近90日',
    'last_180_days': '近180日',
    'last_365_days': '近365日',
    'level_deposit': '入金',
    'level_net_deposit': '净入金',
    'level_closing_positions': '平仓手数',
    'level_registrations': '邀请好友数',
    'manual_adjust': '手动调整',
    'as_of_now': '截至当前',
  };

  Map<String, String> _labels = _fallbacks;
  String? _languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = stLanguageCodeOfContext(context);
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    _loadLabels(languageCode);
  }

  Future<void> _loadLabels(String languageCode) async {
    final labels = await STLocalizations.ofContext(context).textMap(_fallbacks);
    if (!mounted || _languageCode != languageCode) return;
    setState(() => _labels = labels);
  }

  @override
  Widget build(BuildContext context) {
    final direction =
        '${widget.data['pending_change_level_direction'] ?? 'UP'}';
    final current = _asMap(widget.data['current_level']);
    final pending = _asMap(widget.data['pending_level']);
    final currentName = '${current['name'] ?? ''}';
    final pendingName = '${pending['name'] ?? ''}';
    final duration = '${current['duration'] ?? ''}';
    final positionCount = _positionCount(widget.data);
    final tips = direction == 'DOWN'
        ? <String>[
            '${_labels['user_upgrade_down_2'] ?? '等级调整：'}$currentName -> $pendingName',
            _labels['user_upgrade_down_3'] ?? '变更原因：',
            _reasonText(
              duration,
              widget.data['change_level_reason'],
              currentName,
              _labels,
            ),
            _formatIosTemplate(
              _labels['user_upgrade_current_position_ios'] ?? '当前有%@笔持仓',
              '$positionCount',
            ),
            _labels['user_upgrade_down_4'] ?? '可继续交易，开仓权限已禁用，平仓后自动调整等级',
          ]
        : <String>[
            _labels['user_upgrade_up_2'] ?? '升级尊享权益：',
            _labels['user_upgrade_up_2_a'] ?? '✔ 更优的点差',
            _labels['user_upgrade_up_2_b'] ?? '✔ 更低的手续费',
            _labels['user_upgrade_up_2_c'] ?? '✔ 专属客服支持',
            _formatIosTemplate(
              _labels['user_upgrade_current_position_ios'] ?? '当前有%@笔持仓',
              '$positionCount',
            ),
            _labels['user_upgrade_up_3'] ?? '等级调整后可获得更高交易权限',
          ];

    return _TradeSheetShell(
      title: direction == 'DOWN'
          ? (_labels['user_upgrade_down_1'] ?? '等级调整提醒')
          : '${_labels['user_upgrade_up_1'] ?? '恭喜！即将升级为'}$pendingName',
      children: [
        const SizedBox(height: 30),
        for (final tip in tips) ...[
          Text(
            tip,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              color: context.adaptiveTextTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
        ],
        const SizedBox(height: 30),
        _SheetButton(
          label: _labels['i_see'] ?? '知道了',
          backgroundColor: const Color(0xFF00B57A),
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static int _positionCount(Map<String, dynamic> data) {
    final raw = data['position_count'] ?? data['positionCount'];
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  static String _reasonText(
    String duration,
    Object? reasons,
    String level,
    Map<String, String> labels,
  ) {
    final actions = (reasons is List ? reasons : const [])
        .map((e) => e is Map ? '${e['action'] ?? ''}' : '')
        .map((action) => _actionName(action, labels))
        .where((e) => e.isNotEmpty)
        .join('、');
    if (actions == (labels['manual_adjust'] ?? '手动调整')) return actions;
    return '${_durationText(duration, labels)}'
        '${labels['account_2'] ?? '账户'}'
        '$actions'
        '${labels['not_reached'] ?? '未达到'}'
        '$level'
        '${labels['level_standard'] ?? '等级标准'}';
  }

  static String _durationText(String duration, Map<String, String> labels) {
    switch (duration) {
      case 'DAY':
        return labels['last_1_days'] ?? '近1日';
      case 'WEEK':
        return labels['last_7_days'] ?? '近7日';
      case 'MONTH':
        return labels['last_30_days'] ?? '近30日';
      case 'QUARTER':
        return labels['last_90_days'] ?? '近90日';
      case 'HALF':
        return labels['last_180_days'] ?? '近180日';
      case 'YEAR':
        return labels['last_365_days'] ?? '近365日';
      case 'AS_OF_YESTERDAY':
      case 'AS_OF_NOW':
      default:
        return labels['as_of_now'] ?? '截至当前';
    }
  }

  static String _actionName(String action, Map<String, String> labels) {
    switch (action) {
      case 'DEPOSIT':
        return labels['level_deposit'] ?? '入金';
      case 'NET_DEPOSIT':
        return labels['level_net_deposit'] ?? '净入金';
      case 'NUMBER_OF_CLOSURES':
        return labels['level_closing_positions'] ?? '平仓手数';
      case 'REGISTER_COUNT':
        return labels['level_registrations'] ?? '邀请好友数';
      case 'MANUAL_ADJUSTMENT':
        return labels['manual_adjust'] ?? '手动调整';
      default:
        return '';
    }
  }

  static String _formatIosTemplate(String template, String value) {
    if (template.contains('%@')) return template.replaceAll('%@', value);
    if (template.contains('%s')) return template.replaceAll('%s', value);
    return '$template$value';
  }
}

class TradeLevelChangeData {
  const TradeLevelChangeData(this.raw);

  final Map<String, dynamic> raw;
}

class _TradeSheetShell extends StatelessWidget {
  const _TradeSheetShell({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('trade_no_limit_sheet_shell'),
        decoration: BoxDecoration(
          color: context.adaptiveCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        ),
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      'assets/images/st_mine_close_gary.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
