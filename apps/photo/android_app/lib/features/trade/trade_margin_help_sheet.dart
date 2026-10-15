import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_toast.dart';

/// 对齐 iOS `ParentViewController -th_parent_presentMarginLevelHelp` +
/// `STWalletBondHelpView` + `-th_parent_presentMarginLevelDetail`。
abstract final class TradeMarginHelpSheet {
  static const Color kBrandBlue = Color(0xFF00B57A);
  static const Color _safe = Color(0xFF4DCB73);
  static const Color _warning = Color(0xFFF2793E);
  static const Color _danger = Color(0xFFF95959);
  static const Color _close = Color(0xFFD91A17);

  static const Map<String, String> _fallbackText = {
    'please_pre_login': '请先登录',
    'margin_description': '保证金水平',
    'margin_level_tips': '保证金水平(%)=账户净值/已用保证金',
    'margin_level_current_status': '当前状态',
    'margin_level_status_detail': '查看详情>',
    'margin_level_i_understand': '我明白了',
    'margin_level_question_first': '什么情况下会强制平仓？',
    'margin_level_answer_first':
        '当您的保证金水平低于 50% 时，为保护您的账户免受更大损失，系统将开始自动平掉您的部分或全部仓位。',
    'margin_level_question_second': '强制平仓是怎样执行的？',
    'margin_level_answer_second': '系统会从您当前亏损最大的持仓开始逐个平仓，直到您保证金水平恢复到安全线以上。',
    'margin_level_question_third': '如何避免被强制平仓？',
    'margin_level_answer_third':
        '1. 补充资金：这是最直接的方式，可以迅速提升您的保证金水平。\n'
        '2. 主动减仓：优先平掉部分亏损的仓位，释放保证金。\n'
        '3. 设置止损：为您的每个持仓设置止损，从源头控制单笔亏损。\n'
        '4. 保持警惕：在市场波动剧烈时，请务必密切关注您的保证金水平。',
    'margin_level_safe': '安全',
    'margin_level_warning': '预警',
    'margin_level_dangerous': '危险',
    'margin_level_close': '强制平仓',
    'margin_level_status_safe_desc': '保证金水平充足，账户安全',
    'margin_level_status_warning_desc': '保证金水平偏低，建议关注',
    'margin_level_status_dangerous_desc': '接近强平线，请立即处理！',
    'margin_level_status_close_desc': '系统正在强制平仓！',
    'margin_level_detail_title': '风险状态说明',
    'margin_level_detail_safe_desc': '您的保证金充足，账户风险低。这是一个相对理想和健康的账户状态。',
    'margin_level_detail_warning_desc': '您的保证金缓冲正在减少，请开始关注市场波动，考虑调整仓位或设置止损。',
    'margin_level_detail_dangerous_desc':
        '您的账户已低于维持保证金要求 (100%)！账户已触发追加保证金通知，请立即补充资金或主动减仓，否则将面临被强制平仓的直接风险。',
    'margin_level_detail_close_desc':
        '您的账户已触发强制平仓！系统正在或将立即自动平掉您的部分或全部仓位，以防止更大亏损。此操作不可逆。',
  };

  static double? _parseMarginPercent(String raw) {
    if (raw.isEmpty || raw == '--') return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static Future<void> showHelp(
    BuildContext context,
    WidgetRef ref, {
    required String marginLevelDisplay,
  }) async {
    final localizations = STLocalizations.ofContext(context);
    if (!ref.read(userStateProvider).isLogin) {
      final message = await localizations.text(
        'please_pre_login',
        fallback: _fallbackText['please_pre_login'],
      );
      if (!context.mounted) return;
      STToast.show(context, message);
      return;
    }
    final text = await localizations.textMap(_fallbackText);

    final appendStr = ref.read(userStateProvider).appendMarginLevel;
    final closeStr = ref.read(userStateProvider).closeMarginLevel;
    final append = double.tryParse(appendStr) ?? 50;
    final close = double.tryParse(closeStr) ?? 50;
    final v = _parseMarginPercent(marginLevelDisplay);

    final status = _resolveStatus(v, close: close, append: append, text: text);

    final closePctLabel =
        '${closeStr == '' || closeStr == '--' ? close.toStringAsFixed(0) : closeStr}%';

    final faq = <({String q, String a})>[
      (
        q: text['margin_level_question_first']!,
        a: text['margin_level_answer_first']!.replaceAll(
          RegExp(r'\d+%'),
          closePctLabel,
        ),
      ),
      (
        q: text['margin_level_question_second']!,
        a: text['margin_level_answer_second']!,
      ),
      (
        q: text['margin_level_question_third']!,
        a: text['margin_level_answer_third']!,
      ),
    ];

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        key: const ValueKey('trade_margin_help_sheet_shell'),
        decoration: BoxDecoration(
          color: ctx.adaptivePageGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          maxChildSize: 0.94,
          minChildSize: 0.45,
          builder: (_, scrollCtl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        text['margin_description']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: ctx.adaptiveTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: ctx.adaptiveTextTertiary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  text['margin_level_tips']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: ctx.adaptiveTextTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  controller: scrollCtl,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  children: [
                    _GaugeCard(
                      append: append,
                      close: close,
                      statusLabel: status.label,
                      currentStatusLabel: text['margin_level_current_status']!,
                      statusColor: status.color,
                      dotAngle: status.dotAngle,
                    ),
                    const SizedBox(height: 10),
                    _SummaryCard(
                      message: status.remind,
                      detailText: text['margin_level_status_detail']!,
                      onDetail: () {
                        Navigator.pop(ctx);
                        showDetail(context, ref);
                      },
                    ),
                    const SizedBox(height: 10),
                    _FaqCard(items: faq),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrandBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      text['margin_level_i_understand']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  static _MarginStatus _resolveStatus(
    double? v, {
    required double close,
    required double append,
    required Map<String, String> text,
  }) {
    final dangerousUpper = close + append;
    final warningUpper = dangerousUpper + 50;

    if (v != null && v > 0 && v < close) {
      return _MarginStatus(
        label: text['margin_level_close']!,
        color: _close,
        remind: text['margin_level_status_close_desc']!,
        dotAngle: math.pi * 0.92,
      );
    }
    if (v != null && v >= close && v < dangerousUpper) {
      return _MarginStatus(
        label: text['margin_level_dangerous']!,
        color: _danger,
        remind: text['margin_level_status_dangerous_desc']!,
        dotAngle: math.pi * 0.78,
      );
    }
    if (v != null && v >= dangerousUpper && v < warningUpper) {
      return _MarginStatus(
        label: text['margin_level_warning']!,
        color: _warning,
        remind: text['margin_level_status_warning_desc']!,
        dotAngle: math.pi * 0.55,
      );
    }
    return _MarginStatus(
      label: text['margin_level_safe']!,
      color: _safe,
      remind: text['margin_level_status_safe_desc']!,
      dotAngle: math.pi * 0.22,
    );
  }

  static Future<void> showDetail(BuildContext context, WidgetRef ref) async {
    final text = await STLocalizations.ofContext(
      context,
    ).textMap(_fallbackText);
    final appendStr = ref.read(userStateProvider).appendMarginLevel;
    final closeStr = ref.read(userStateProvider).closeMarginLevel;
    final append = double.tryParse(appendStr) ?? 50;
    final safeLine = append + 50;

    final tiers = [
      (
        title:
            '${text['margin_level_safe']}（${text['margin_description']} ≥ ${safeLine.toStringAsFixed(0)}%）',
        detail: text['margin_level_detail_safe_desc']!,
        color: _safe,
      ),
      (
        title:
            '${text['margin_level_warning']}（$appendStr% ≤ ${text['margin_description']} < ${safeLine.toStringAsFixed(0)}%）',
        detail: text['margin_level_detail_warning_desc']!,
        color: _warning,
      ),
      (
        title:
            '${text['margin_level_dangerous']}（$closeStr% ≤ ${text['margin_description']} < $appendStr%）',
        detail: text['margin_level_detail_dangerous_desc']!.replaceAll(
          RegExp(r'\d+%'),
          '$appendStr%',
        ),
        color: _danger,
      ),
      (
        title:
            '${text['margin_level_close']}（${text['margin_description']} < $closeStr%）',
        detail: text['margin_level_detail_close_desc']!,
        color: _close,
      ),
    ];

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        key: const ValueKey('trade_margin_help_detail_sheet_shell'),
        decoration: BoxDecoration(
          color: ctx.adaptivePageGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      text['margin_level_detail_title']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ctx.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: ctx.adaptiveTextTertiary),
                  ),
                ],
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tiers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final t = tiers[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ctx.adaptiveCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 48,
                            decoration: BoxDecoration(
                              color: t.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ctx.adaptiveTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.detail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: ctx.adaptiveTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarginStatus {
  _MarginStatus({
    required this.label,
    required this.color,
    required this.remind,
    required this.dotAngle,
  });
  final String label;
  final Color color;
  final String remind;
  final double dotAngle;
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.append,
    required this.close,
    required this.statusLabel,
    required this.currentStatusLabel,
    required this.statusColor,
    required this.dotAngle,
  });

  final double append;
  final double close;
  final String statusLabel;
  final String currentStatusLabel;
  final Color statusColor;
  final double dotAngle;

  @override
  Widget build(BuildContext context) {
    final safeMark = append + 50;
    return Column(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: CustomPaint(
            painter: _SemiGaugePainter(dotAngle: dotAngle, accent: statusColor),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        safeMark.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adaptiveTextSecondary,
                        ),
                      ),
                    ),
                    Text(
                      append.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: Text(
                        close.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adaptiveTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                Text(
                  currentStatusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SemiGaugePainter extends CustomPainter {
  _SemiGaugePainter({required this.dotAngle, required this.accent});

  final double dotAngle;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.28,
      size.width * 0.84,
      size.height * 0.72,
    );
    final center = Offset(rect.center.dx, rect.bottom);
    final radius = rect.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFFE8F5EF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    final gradPaint = Paint()
      ..shader = SweepGradient(
        startAngle: math.pi,
        endAngle: math.pi * 2,
        colors: const [Color(0xFF4DCB73), Color(0xFFB8EBC8), Color(0xFF4DCB73)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      gradPaint,
    );

    final dotR = Offset(
      center.dx + radius * math.cos(dotAngle),
      center.dy + radius * math.sin(dotAngle),
    );
    canvas.drawCircle(dotR, 8, Paint()..color = accent);
    canvas.drawCircle(
      dotR,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter oldDelegate) =>
      oldDelegate.dotAngle != dotAngle || oldDelegate.accent != accent;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.message,
    required this.detailText,
    required this.onDetail,
  });

  final String message;
  final String detailText;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('trade_margin_help_summary_card'),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: context.adaptiveTextPrimary,
            ),
          ),
          TextButton(
            onPressed: onDetail,
            child: Text(
              detailText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TradeMarginHelpSheet.kBrandBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.items});

  final List<({String q, String a})> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: TradeMarginHelpSheet.kBrandBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].q,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.adaptiveTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items[i].a,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
