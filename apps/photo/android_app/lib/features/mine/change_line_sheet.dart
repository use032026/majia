import 'package:flutter/material.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

class ChangeLineNode {
  const ChangeLineNode({
    required this.name,
    required this.host,
    this.latencyMs,
  });

  final String name;
  final String host;
  final int? latencyMs;
}

Future<ChangeLineNode?> showChangeLineSheet({
  required BuildContext context,
  required List<ChangeLineNode> nodes,
  String selectedHost = '',
  VoidCallback? onRefresh,
  VoidCallback? onContactSupport,
}) {
  return showModalBottomSheet<ChangeLineNode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (sheetContext) => ChangeLineSheet(
      nodes: nodes,
      selectedHost: selectedHost,
      onRefresh: onRefresh,
      onContactSupport: onContactSupport,
      onSelected: (node) => Navigator.of(sheetContext).pop(node),
    ),
  );
}

class ChangeLineSheet extends StatefulWidget {
  const ChangeLineSheet({
    super.key,
    required this.nodes,
    required this.selectedHost,
    this.onRefresh,
    this.onContactSupport,
    this.onSelected,
  });

  final List<ChangeLineNode> nodes;
  final String selectedHost;
  final VoidCallback? onRefresh;
  final VoidCallback? onContactSupport;
  final ValueChanged<ChangeLineNode>? onSelected;

  @override
  State<ChangeLineSheet> createState() => _ChangeLineSheetState();
}

class _ChangeLineSheetState extends State<ChangeLineSheet> {
  static const Map<String, String> _fallbackText = {
    'change_line_pick_node': '请选择以下线路节点',
    'change_line_footer_line1': '如果在访问页面时出现加载时间过长，页面打不开等情况问题',
    'change_line_footer_line2': '请使用本页面进行切换线路自助排除故障，',
    'change_line_footer_line3_prefix': '若依旧无法解决，',
    'change_line_footer_contact': '请联系客服',
    'flutter_change_line_empty': '暂无可用线路',
  };

  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final localizations = STLocalizations.ofContext(context);
    final languageCode = localizations.languageCode;
    if (_languageCode == languageCode && _localized.isNotEmpty) return;
    _languageCode = languageCode;

    final token = ++_languageLoadToken;
    localizations.textMap(_fallbackText).then((entries) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final rowCount = widget.nodes.isEmpty ? 1 : widget.nodes.length;
    final tableHeight = (rowCount * 48.0).clamp(48.0, 260.0);
    final cardBg = context.adaptiveCard;
    final tertiaryText = context.adaptiveTextTertiary;
    final secondaryText = context.adaptiveTextSecondary;
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('change_line_sheet_shell'),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _t('change_line_pick_node'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tertiaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('change_line_refresh_button'),
                    onPressed: widget.onRefresh,
                    icon: Image.asset(
                      'assets/images/st_mine_changeline_refresh.png',
                      width: 20,
                      height: 20,
                    ),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: tableHeight,
              child: widget.nodes.isEmpty
                  ? Center(
                      child: Text(
                        _t('flutter_change_line_empty'),
                        style: TextStyle(fontSize: 14, color: secondaryText),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: widget.nodes.length > 5
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      itemCount: widget.nodes.length,
                      itemBuilder: (context, index) {
                        final node = widget.nodes[index];
                        return _ChangeLineRow(
                          key: ValueKey('change_line_row_$index'),
                          node: node,
                          selected: node.host == widget.selectedHost,
                          selectedKey: ValueKey('change_line_selected_$index'),
                          onTap: () => widget.onSelected?.call(node),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    _t('change_line_footer_line1'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _t('change_line_footer_line2'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _t('change_line_footer_line3_prefix'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: secondaryText,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onContactSupport,
                        child: Text(
                          _t('change_line_footer_contact'),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Color(0xFF00B57A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeLineRow extends StatelessWidget {
  const _ChangeLineRow({
    super.key,
    required this.node,
    required this.selected,
    required this.selectedKey,
    required this.onTap,
  });

  final ChangeLineNode node;
  final bool selected;
  final Key selectedKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryText = context.adaptiveTextPrimary;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: primaryText),
                ),
              ),
              Text(
                node.latencyMs == null ? '--ms' : '${node.latencyMs}ms',
                style: TextStyle(
                  fontSize: 12,
                  color: _latencyColor(node.latencyMs),
                ),
              ),
              const SizedBox(width: 12),
              if (selected)
                Image.asset(
                  'assets/images/st_mine_checked_sec.png',
                  key: selectedKey,
                  width: 27,
                  height: 27,
                )
              else
                Image.asset(
                  'assets/images/st_mine_unchecked.png',
                  width: 27,
                  height: 27,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _latencyColor(int? latency) {
    if (latency == null) return const Color(0xFF9A9DA2);
    if (latency <= 80) return const Color(0xFF1BCC83);
    if (latency <= 180) return const Color(0xFFFF9F2D);
    return const Color(0xFFF95959);
  }
}
