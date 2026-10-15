import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/st_localizations.dart';
import '../../features/mine/mine_margin_sheets.dart';
import '../models/user_state.dart';

/// 对齐 iOS `STConfigCardHandler cardPopHandler:` 中的 `/action/popview*` 路由
class CardActionHandlers {
  CardActionHandlers._();

  static Future<bool> handlePopViewRoute(
    BuildContext context,
    Ref ref,
    String path,
    Map<String, dynamic> params,
  ) async {
    final lower = path.toLowerCase();

    if (lower == '/action/popviewmarginlevel') {
      await _showMarginLevelHelp(context, ref);
      return true;
    }

    if (lower == '/action/popviewvipinfo') {
      await _showVipUpgradeInfo(context, params);
      return true;
    }

    return false;
  }

  static Future<void> _showMarginLevelHelp(
    BuildContext context,
    Ref ref,
  ) async {
    final user = ref.read(userStateProvider);
    if (!user.isLogin) return;

    final accounts = user.accountAry;
    if (accounts.isEmpty) return;

    final txAccount = user.transactionAccount;
    STAccountModel? active;
    for (final a in accounts) {
      if (a.accountId == txAccount) {
        active = a;
        break;
      }
    }
    active ??= accounts.first;

    final mlStr = active.marginLevel;
    final append = user.appendMarginLevel.isNotEmpty
        ? user.appendMarginLevel
        : '50';
    final close = user.closeMarginLevel.isNotEmpty
        ? user.closeMarginLevel
        : '30';
    final safe = (double.tryParse(append) ?? 50) + 50;

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MarginLevelHelpSheet(
        marginLevel: mlStr,
        appendMarginLevel: append,
        closeMarginLevel: close,
        onDetail: () {
          Navigator.of(context).pop();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MarginLevelDetailSheet(
              appendMarginLevel: append,
              closeMarginLevel: close,
              safeMarginLevel: safe.toStringAsFixed(0),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showVipUpgradeInfo(
    BuildContext context,
    Map<String, dynamic> params,
  ) async {
    final text = await STLocalizations.ofContext(context).textMap(const {
      'upgrade_confidition': '升级条件',
      'upgrade_confidition_1': '满足任一条件即可',
      'upgrade_confidition_2': '两项均需达标',
      'upgrade_confidition_3': '需满足所有条件',
      'vip_i_know': '我知道了',
      'flutter_vip_upgrade_progress': '当前进度 {progress}%',
      'flutter_vip_upgrade_empty': '暂无更多升级条件说明',
    });
    final requirement = params['requirement'];
    final progress = params['progress'];
    final progressPct = progress is num
        ? (progress * 100).toStringAsFixed(1)
        : (double.tryParse('$progress') != null
              ? (double.parse('$progress') * 100).toStringAsFixed(1)
              : '0');

    final lines = <String>[];
    if (requirement is Map) {
      final logic = (requirement['logic'] as String? ?? '').toUpperCase();
      final andList = requirement['requirements'] as List? ?? [];
      final orList = requirement['requirements_or'] as List? ?? [];
      final requirementTitle = switch (logic) {
        'AND' when andList.isNotEmpty && orList.isNotEmpty =>
          text['upgrade_confidition_3']!,
        'AND' => text['upgrade_confidition_2']!,
        _ => text['upgrade_confidition_1']!,
      };
      lines.add(requirementTitle);
      for (final group in [andList, orList]) {
        for (final item in group) {
          if (item is Map) {
            final label = '${item['name'] ?? item['title'] ?? ''}'.trim();
            if (label.isNotEmpty) {
              lines.add('• $label');
            }
          }
        }
      }
    }

    final confirmText = text['vip_i_know']!;
    final progressText = text['flutter_vip_upgrade_progress']!.replaceAll(
      '{progress}',
      progressPct,
    );
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text['upgrade_confidition']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                progressText,
                style: const TextStyle(fontSize: 14, color: Color(0xFF60656D)),
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...lines.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(t, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ] else
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    text['flutter_vip_upgrade_empty']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9A9DA2),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(confirmText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
