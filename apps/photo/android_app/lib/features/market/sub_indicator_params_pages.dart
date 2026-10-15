import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import 'chart_indicator_prefs.dart';

/// 副图指标参数子页（对齐 iOS 分组 + 分条编辑）
const _kIosSettingsBg = Color(0xFFF2F2F7);

Color _settingsBg(BuildContext context) =>
    context.adaptiveIsDark ? context.adaptivePageGrey : _kIosSettingsBg;

int? _parsePositiveInt(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final v = int.tryParse(t);
  if (v == null || v < 1 || v > 500) return null;
  return v;
}

/// 三列参数（MACD、KDJ）
class TripleParamDetailPage extends StatefulWidget {
  const TripleParamDetailPage({
    super.key,
    required this.title,
    required this.displaySummary,
    required this.rowLabels,
    required this.initialSerialized,
    required this.fallback,
    required this.onSave,
  });

  final String title;
  final String displaySummary;
  final List<String> rowLabels;
  final String initialSerialized;
  final (int, int, int) fallback;
  final Future<void> Function(String serialized) onSave;

  @override
  State<TripleParamDetailPage> createState() => _TripleParamDetailPageState();
}

class _TripleParamDetailPageState extends State<TripleParamDetailPage> {
  late final TextEditingController _a;
  late final TextEditingController _b;
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    final t = ChartIndicatorPrefs.parseTriple(
      widget.initialSerialized,
      widget.fallback,
    );
    _a = TextEditingController(text: '${t.$1}');
    _b = TextEditingController(text: '${t.$2}');
    _c = TextEditingController(text: '${t.$3}');
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final va = _parsePositiveInt(_a.text);
    final vb = _parsePositiveInt(_b.text);
    final vc = _parsePositiveInt(_c.text);
    if (va == null || vb == null || vc == null) {
      showStLocalizedPrompt(context, '请输入 1～500 的正整数');
      return;
    }
    final s = '$va,$vb,$vc';
    await widget.onSave(s);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.rowLabels;
    final bg = _settingsBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: context.adaptiveTextPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: const Color(0xFF007AFF),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text(
              '保存',
              style: TextStyle(
                fontSize: 17,
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '当前：${widget.displaySummary}',
            style: TextStyle(
              fontSize: 13,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: context.adaptiveCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _NumericRow(
                  label: labels[0],
                  controller: _a,
                  showDivider: true,
                ),
                _NumericRow(
                  label: labels[1],
                  controller: _b,
                  showDivider: true,
                ),
                _NumericRow(
                  label: labels[2],
                  controller: _c,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单一周期参数（RSI、DMI）
class SingleParamDetailPage extends StatefulWidget {
  const SingleParamDetailPage({
    super.key,
    required this.title,
    required this.displaySummary,
    required this.fieldLabel,
    required this.initialSerialized,
    required this.fallback,
    required this.onSave,
  });

  final String title;
  final String displaySummary;
  final String fieldLabel;
  final String initialSerialized;
  final int fallback;
  final Future<void> Function(String serialized) onSave;

  @override
  State<SingleParamDetailPage> createState() => _SingleParamDetailPageState();
}

class _SingleParamDetailPageState extends State<SingleParamDetailPage> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    final v = ChartIndicatorPrefs.parseSinglePeriod(
      widget.initialSerialized,
      widget.fallback,
    );
    _c = TextEditingController(text: '$v');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final va = _parsePositiveInt(_c.text);
    if (va == null) {
      showStLocalizedPrompt(context, '请输入 1～500 的正整数');
      return;
    }
    final s = '$va';
    await widget.onSave(s);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _settingsBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: context.adaptiveTextPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: const Color(0xFF007AFF),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text(
              '保存',
              style: TextStyle(
                fontSize: 17,
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '当前：${widget.displaySummary}',
            style: TextStyle(
              fontSize: 13,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: context.adaptiveCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _NumericRow(
              label: widget.fieldLabel,
              controller: _c,
              showDivider: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumericRow extends StatelessWidget {
  const _NumericRow({
    required this.label,
    required this.controller,
    required this.showDivider,
  });

  final String label;
  final TextEditingController controller;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '—',
                  ),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 0.5, color: context.adaptiveHairline),
      ],
    );
  }
}
