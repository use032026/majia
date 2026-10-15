import 'package:flutter/material.dart';

import '../../core/theme/context_adaptive_colors.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

/// 保证金水平说明（对齐 iOS STWalletBondHelpView / Flutter `MinePage` 弹层）
class MarginLevelHelpSheet extends StatelessWidget {
  final String marginLevel;
  final String appendMarginLevel;
  final String closeMarginLevel;
  final VoidCallback onDetail;

  const MarginLevelHelpSheet({
    super.key,
    required this.marginLevel,
    required this.appendMarginLevel,
    required this.closeMarginLevel,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final pageBg = context.adaptivePageGrey;
    final primaryText = context.adaptiveTextPrimary;
    final tertiaryText = context.adaptiveTextTertiary;
    final mlStr = marginLevel.replaceAll('%', '').trim();
    final dMarginLevel = double.tryParse(mlStr) ?? 0;
    final appendVal = double.tryParse(appendMarginLevel) ?? 50;
    final closeVal = double.tryParse(closeMarginLevel) ?? 30;

    late final String statusText;
    late final Color statusColor;
    late final String statusImage;
    late final String remindText;

    if (dMarginLevel > 0 && dMarginLevel < closeVal) {
      statusText = '平仓';
      statusColor = const Color(0xFFD91A17);
      statusImage = 'st_margin_level_close';
      remindText = '您的账户已触发强制平仓条件，系统将自动平仓以控制风险，请及时追加保证金。';
    } else if (dMarginLevel >= closeVal &&
        dMarginLevel < (closeVal + appendVal)) {
      statusText = '危险';
      statusColor = const Color(0xFFF95959);
      statusImage = 'st_margin_level_dangerous';
      remindText = '您的账户风险较高，可能随时触发强制平仓，请立即追加保证金或减仓。';
    } else if (dMarginLevel >= (closeVal + appendVal) &&
        dMarginLevel < (closeVal + appendVal + 50)) {
      statusText = '预警';
      statusColor = const Color(0xFFF2793E);
      statusImage = 'st_margin_level_warning';
      remindText = '您的账户资金开始紧张，建议关注持仓风险，适时追加保证金。';
    } else {
      statusText = '安全';
      statusColor = const Color(0xFF4DCB73);
      statusImage = 'st_margin_level_safe';
      remindText = '您的账户资金充足，交易风险较低，可正常进行交易操作。';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: pageBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '保证金水平说明',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      _buildStatusGauge(
                        context,
                        statusImage,
                        appendVal,
                        closeVal,
                        dMarginLevel,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '当前状态',
                        style: TextStyle(fontSize: 10, color: tertiaryText),
                      ),
                      const SizedBox(height: 16),
                      _buildRemindCard(context, remindText),
                      const SizedBox(height: 10),
                      _buildFaqCard(context, closeVal),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: pageBg,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onDetail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B57A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(stLocalizedTextFromZhHans('查看详情')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusGauge(
    BuildContext context,
    String imageName,
    double appendVal,
    double closeVal,
    double currentVal,
  ) {
    final primaryText = context.adaptiveTextPrimary;
    final secondaryText = context.adaptiveTextSecondary;
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/$imageName.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                color: context.adaptiveIconPillBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.speed,
                size: 48,
                color: Color(0xFF00B57A),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 16,
            child: Text(
              '追加 ${appendVal.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: secondaryText),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 16,
            child: Text(
              '平仓 ${closeVal.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Color(0xFFD91A17)),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Text(
              '${currentVal.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindCard(BuildContext context, String remindText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '温馨提示',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remindText,
            style: TextStyle(
              fontSize: 13,
              color: context.adaptiveTextTertiary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard(BuildContext context, double closeVal) {
    final items = [
      ('什么是保证金水平？', '保证金水平 = 净值 / 已用保证金 × 100%，反映账户当前的风险程度。'),
      ('什么是追加保证金？', '当保证金水平低于追加线时，系统将发出追加保证金通知，请及时补充资金。'),
      (
        '什么是强制平仓？',
        '当保证金水平低于 ${closeVal.toStringAsFixed(0)}% 时，系统将自动对持仓进行强制平仓以控制风险。',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '常见问题',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    e.$2,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adaptiveTextTertiary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 保证金水平详情
class MarginLevelDetailSheet extends StatelessWidget {
  final String appendMarginLevel;
  final String closeMarginLevel;
  final String safeMarginLevel;

  const MarginLevelDetailSheet({
    super.key,
    required this.appendMarginLevel,
    required this.closeMarginLevel,
    required this.safeMarginLevel,
  });

  @override
  Widget build(BuildContext context) {
    final pageBg = context.adaptivePageGrey;
    final primaryText = context.adaptiveTextPrimary;
    final secondaryText = context.adaptiveTextSecondary;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: pageBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '保证金水平详情',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _buildDetailItem(
                        context,
                        '追加保证金水平',
                        '$appendMarginLevel%',
                        const Color(0xFFF2793E),
                      ),
                      const SizedBox(height: 10),
                      _buildDetailItem(
                        context,
                        '强制平仓水平',
                        '$closeMarginLevel%',
                        const Color(0xFFD91A17),
                      ),
                      const SizedBox(height: 10),
                      _buildDetailItem(
                        context,
                        '安全保证金水平',
                        '$safeMarginLevel%',
                        const Color(0xFF4DCB73),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '以上数值仅供参考，实际以账户实时数据为准。如有疑问请联系客服。',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: context.adaptiveTextTertiary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
