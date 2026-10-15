import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_toast.dart';

/// 入金「复制收款信息」页
/// 对齐 iOS `STWalletDepositCodeViewController`（线下转账类渠道展示码/账号）
/// 对齐 Figma APP 白标 2.0：白色卡片 + 标签/值分行 + 复制按钮
class DepositReferencePage extends ConsumerStatefulWidget {
  /// 展示文案：label -> value（如 收款银行、账号、附言）
  final Map<String, String> fields;

  const DepositReferencePage({super.key, required this.fields});

  static const _fallbackText = {
    'charge': '充值',
    'charge_reference_tip': '请按以下信息完成转账，转账完成后请耐心等待到账。',
    'copy': '复制',
    'copy_toast_tip': '已复制',
    'complete': '我已完成转账',
  };

  @override
  ConsumerState<DepositReferencePage> createState() =>
      _DepositReferencePageState();
}

class _DepositReferencePageState extends ConsumerState<DepositReferencePage> {
  Map<String, String> _localizedText = DepositReferencePage._fallbackText;
  String? _localizedLanguageCode;

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = DepositReferencePage._fallbackText;
    localizations.textMap(DepositReferencePage._fallbackText).then((text) {
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
        _localizedText[key] ?? DepositReferencePage._fallbackText[key] ?? key;

    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        backgroundColor: context.adaptiveSurfacePrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          t('charge'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: context.adaptiveTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.adaptiveIsDark
                  ? const Color(0xFF2F2A24)
                  : const Color(0xFFFFF4E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFFFF7913),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t('charge_reference_tip'),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.adaptiveTextTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: context.adaptiveCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: List.generate(widget.fields.entries.length * 2 - 1, (
                index,
              ) {
                if (index.isOdd) {
                  return Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: context.adaptiveDivider,
                  );
                }
                final entry = widget.fields.entries.elementAt(index ~/ 2);
                return _buildFieldRow(context, entry.key, entry.value, t);
              }),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B57A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(t('complete')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(
    BuildContext context,
    String label,
    String value,
    String Function(String key) t,
  ) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  STToast.show(context, '${t('copy_toast_tip')} $label');
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text(t('copy')),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00B57A),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
