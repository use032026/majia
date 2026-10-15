import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 钱包 / 资金流水详情（Figma：`2175-76400` 流水详细）
class WalletFlowDetailPage extends StatefulWidget {
  final Map<String, dynamic> raw;

  const WalletFlowDetailPage({super.key, required this.raw});

  @override
  State<WalletFlowDetailPage> createState() => _WalletFlowDetailPageState();

  static const _fallbackText = {
    'flow_detail': '流水详细',
    'project': '项目',
    'change_before_balance': '变动前余额',
    'income': '收入',
    'expenditure': '支出',
    'change_after_balance': '变动后余额',
    'flow_num': '流水号',
    'time': '时间',
  };

  static String _fmt(dynamic n) {
    if (n == null) return '—';
    final s = n.toString().trim();
    if (s.isEmpty) return '—';
    final d = double.tryParse(s);
    if (d != null) return d.toStringAsFixed(2);
    return s;
  }

  /// 对齐稿：单独展示「收入 / 支出」两行，无金额的一侧为 `--`。
  static ({String income, String expense}) _splitIncomeExpense({
    required int? changeType,
    required double parsed,
    required dynamic amountVal,
    required bool isTransAccountFlow,
  }) {
    String incomeRow = '--';
    String expenseRow = '--';

    if (isTransAccountFlow) {
      incomeRow = _fmt(amountVal);
      expenseRow = '--';
      return (
        income: incomeRow.replaceAll('—', '--'),
        expense: expenseRow.replaceAll('—', '--'),
      );
    }

    void fromSign() {
      if (parsed > 0) {
        incomeRow = _fmt(parsed);
        expenseRow = '--';
      } else if (parsed < 0) {
        incomeRow = '--';
        expenseRow = _fmt(-parsed);
      } else {
        incomeRow = '--';
        expenseRow = '--';
      }
    }

    if (changeType != null) {
      if (changeType == 0) {
        incomeRow = _fmt(parsed);
        expenseRow = '--';
      } else if (parsed != 0) {
        incomeRow = '--';
        expenseRow = _fmt(parsed.abs());
      } else {
        incomeRow = '--';
        expenseRow = '--';
      }
    } else {
      fromSign();
    }

    return (
      income: incomeRow.replaceAll('—', '--'),
      expense: expenseRow.replaceAll('—', '--'),
    );
  }

  static String _time(dynamic secOrMs) {
    if (secOrMs == null) return '—';
    if (secOrMs is String) {
      final d = DateTime.tryParse(secOrMs);
      if (d != null) return DateFormat('yyyy-MM-dd HH:mm:ss').format(d);
      final asInt = int.tryParse(secOrMs);
      if (asInt != null) return _time(asInt);
      return secOrMs;
    }
    final n = (secOrMs as num).toInt();
    final t = n > 2000000000 ? n ~/ 1000 : n;
    if (t <= 0) return '$secOrMs';
    final dt = DateTime.fromMillisecondsSinceEpoch(t * 1000);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  static STLocalizations _resolveLocalizations(BuildContext context) {
    try {
      final bundle = ProviderScope.containerOf(
        context,
      ).read(iosLanguageBundleProvider);
      return STLocalizations.ofContext(context, bundle: bundle);
    } catch (_) {
      return STLocalizations.ofContext(context);
    }
  }
}

class _WalletFlowDetailPageState extends State<WalletFlowDetailPage> {
  Map<String, String> _localizedText = WalletFlowDetailPage._fallbackText;
  String? _localizedLanguageCode;

  @override
  void initState() {
    super.initState();
    _localizedText = WalletFlowDetailPage._fallbackText;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLocalizedText();
  }

  void _ensureLocalizedText() {
    final localizations = WalletFlowDetailPage._resolveLocalizations(context);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = WalletFlowDetailPage._fallbackText;
    localizations.textMap(WalletFlowDetailPage._fallbackText).then((text) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = text;
      });
    });
  }

  Widget _kv(BuildContext context, String k, Widget vWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            k,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.1,
              color: context.adaptiveTextSecondary,
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: vWidget),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();

    final raw = widget.raw;
    final isTransAccountFlow =
        raw.containsKey('fund_flow_type') ||
        raw.containsKey('fundFlowType') ||
        raw.containsKey('transaction_time') ||
        raw.containsKey('transactionTime') ||
        raw.containsKey('order_no');
    final project =
        raw['chang_method_str']?.toString() ??
        raw['changMethodStr']?.toString() ??
        raw['fund_flow_type_str']?.toString() ??
        raw['fundFlowTypeStr']?.toString() ??
        raw['type']?.toString() ??
        '—';

    final changeType = raw['change_type'] is int
        ? raw['change_type'] as int
        : int.tryParse('${raw['change_type'] ?? raw['changeType'] ?? ''}');
    final amountVal =
        raw['change_amount'] ?? raw['changeAmount'] ?? raw['amount'];
    final parsed = amountVal is num
        ? amountVal.toDouble()
        : double.tryParse('$amountVal') ?? 0;

    final flowSplit = WalletFlowDetailPage._splitIncomeExpense(
      changeType: changeType,
      parsed: parsed,
      amountVal: amountVal,
      isTransAccountFlow: isTransAccountFlow,
    );
    final incomeStr = flowSplit.income;
    final expenseStr = flowSplit.expense;

    final before =
        raw['balance'] ?? raw['balance_before'] ?? raw['balanceBefore'];
    final after =
        raw['after_balance'] ??
        raw['afterBalance'] ??
        raw['balance_after'] ??
        raw['balanceAfter'];

    final flowNo =
        raw['order_id']?.toString() ??
        raw['orderId']?.toString() ??
        raw['order_no']?.toString() ??
        raw['order_num']?.toString() ??
        raw['orderNum']?.toString() ??
        raw['serial_no']?.toString() ??
        raw['serialNum']?.toString() ??
        '—';
    final flowPretty = flowNo == '—' ? flowNo : flowNo;

    final timeRaw =
        raw['order_time'] ??
        raw['orderTime'] ??
        raw['created_at'] ??
        raw['transaction_time'] ??
        raw['transactionTime'];
    final valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: context.adaptiveTextPrimary,
      height: 1.1,
    );

    String t(String key) =>
        _localizedText[key] ?? WalletFlowDetailPage._fallbackText[key] ?? key;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: context.adaptiveTextPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
        title: Text(
          t('flow_detail'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: context.adaptiveTextPrimary,
          ),
        ),
      ),
      backgroundColor: context.adaptivePageGrey,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15.5, 8, 15.5, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(15, 18, 15, 16),
            decoration: BoxDecoration(
              color: context.adaptiveCard,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _kv(
                  context,
                  t('project'),
                  Text(project, textAlign: TextAlign.right, style: valueStyle),
                ),
                _kv(
                  context,
                  t('change_before_balance'),
                  Text(
                    WalletFlowDetailPage._fmt(before),
                    textAlign: TextAlign.right,
                    style: valueStyle,
                  ),
                ),
                _kv(
                  context,
                  t('income'),
                  Text(
                    incomeStr,
                    textAlign: TextAlign.right,
                    style: valueStyle,
                  ),
                ),
                _kv(
                  context,
                  t('expenditure'),
                  Text(
                    expenseStr,
                    textAlign: TextAlign.right,
                    style: valueStyle,
                  ),
                ),
                _kv(
                  context,
                  t('change_after_balance'),
                  Text(
                    WalletFlowDetailPage._fmt(after),
                    textAlign: TextAlign.right,
                    style: valueStyle,
                  ),
                ),
                _kv(
                  context,
                  t('flow_num'),
                  Text(
                    flowPretty,
                    textAlign: TextAlign.right,
                    style: valueStyle,
                  ),
                ),
                _kv(
                  context,
                  t('time'),
                  Text(
                    WalletFlowDetailPage._time(timeRaw),
                    textAlign: TextAlign.right,
                    style: valueStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
