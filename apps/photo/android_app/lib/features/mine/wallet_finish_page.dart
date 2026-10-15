import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 钱包操作完成页（划转成功等）
/// 对齐 iOS `STWalletDepositFinishViewController` + `STWalletDepositCell`（`STWalletDepositType_Finish` 头部卡片）
enum WalletFinishKind { transfer, deposit, withdraw }

/// 对应 iOS `drawInfo` 里用于顶部完成卡片展示的字段（`action` / `title` / `drawCurrency` / `drawNum`）。
class WalletFinishDrawHeader {
  final String action;
  final String title;
  final String drawCurrency;
  final String drawNum;

  /// iOS Finish cell 用 `drawType`：银行卡图标 vs 电子钱包图标；划转场景默认银行卡样式。
  final bool bankStyleIcon;

  const WalletFinishDrawHeader({
    required this.action,
    required this.title,
    required this.drawCurrency,
    required this.drawNum,
    this.bankStyleIcon = true,
  });
}

class WalletFinishPage extends ConsumerStatefulWidget {
  final WalletFinishKind kind;
  final WalletFinishDrawHeader? drawHeader;

  /// Info 区：`Language-zh-Hans.json` 等平台文案对应的 label → value（已由上层格式化）
  final Map<String, String> rows;

  const WalletFinishPage({
    super.key,
    required this.kind,
    this.drawHeader,
    required this.rows,
  });

  static const _fallbackText = {
    'complete': '完成',
    'charge': '入金',
    'withdrawal': '出金',
  };

  @override
  ConsumerState<WalletFinishPage> createState() => _WalletFinishPageState();
}

class _WalletFinishPageState extends ConsumerState<WalletFinishPage> {
  Map<String, String> _localizedText = WalletFinishPage._fallbackText;
  String? _localizedLanguageCode;

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = WalletFinishPage._fallbackText;
    localizations.textMap(WalletFinishPage._fallbackText).then((text) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = stLocalizationsOfContext(context, ref);
    _ensureLocalizedText(localizations);
    String t(String key) =>
        _localizedText[key] ?? WalletFinishPage._fallbackText[key] ?? key;

    return Scaffold(
      appBar: AppBar(
        title: Text(_navTitle(t)),
        actions: [
          TextButton(
            onPressed: () => context.go('/mine/wallet'),
            child: Text(
              t('complete'),
              style: const TextStyle(color: Color(0xFF4DCB73), fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: context.adaptivePageGrey,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
        children: [
          if (widget.drawHeader != null) ...[
            _FinishHeroCard(header: widget.drawHeader!),
            const SizedBox(height: 16),
          ],
          ...widget.rows.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InfoTile(label: e.key, value: e.value),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS 完成页未单独设置 `navTitle`，列表内容由 Cell 展示；此处保留轻度提示。
  String _navTitle(String Function(String key) t) {
    switch (widget.kind) {
      case WalletFinishKind.transfer:
        return '';
      case WalletFinishKind.deposit:
        return t('charge');
      case WalletFinishKind.withdraw:
        return t('withdrawal');
    }
  }
}

/// 对齐 `STWalletDepositCell` `STWalletDepositType_Finish` 布局（图标 / 成功文案 / 副标题 / 大额数字）
class _FinishHeroCard extends StatelessWidget {
  final WalletFinishDrawHeader header;

  const _FinishHeroCard({required this.header});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          const SizedBox(height: 21),
          Icon(
            header.bankStyleIcon
                ? Icons.credit_card_rounded
                : Icons.account_balance_wallet_outlined,
            size: 48,
            color: context.adaptiveTextPrimary,
          ),
          const SizedBox(height: 19),
          Text(
            header.action,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1BCC83),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${header.title}(${header.drawCurrency})',
            style: TextStyle(
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                header.drawNum,
                style: TextStyle(
                  fontSize: 32,
                  color: context.adaptiveTextPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.5),
                child: Text(
                  header.drawCurrency,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 38),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: context.adaptiveTextPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
