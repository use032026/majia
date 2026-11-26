part of 'app.dart';

class _GeneratedResults extends StatelessWidget {
  const _GeneratedResults({
    super.key,
    required this.batch,
    required this.visible,
    required this.busy,
    required this.onShowMore,
    required this.onCopy,
    required this.onExport,
  });

  final FixtureBatch batch;
  final int visible;
  final bool busy;
  final VoidCallback onShowMore;
  final ValueChanged<String> onCopy;
  final ValueChanged<BuildContext> onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = FixtureEngine.profile(batch.profileId);
    final count = batch.cases.length;
    final scenario = batch.config['mode'] == 'positive'
        ? _text(context, '规则正例', 'Rule-positive')
        : _text(context, '定向反例', 'Targeted negative');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    _text(context, '生成结果', 'Results'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _chinese(context) ? profile.nameZh : profile.nameEn,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _text(
                    context,
                    '$count 条 · $scenario',
                    '$count ${count == 1 ? 'case' : 'cases'} · $scenario',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _text(
                    context,
                    '规则版本 ${batch.meta['profileVersion']}',
                    'Rule version ${batch.meta['profileVersion']}',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(
                    context,
                    '复现种子 ${batch.config['seed']}',
                    'Replay seed ${batch.config['seed']}',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('copy.all'),
                      onPressed: busy
                          ? null
                          : () => onCopy(
                              batch.cases
                                  .map((entry) => entry.value)
                                  .join('\n'),
                            ),
                      icon: const Icon(CupertinoIcons.doc_on_doc, size: 17),
                      label: Text(_text(context, '复制全部号码', 'Copy all numbers')),
                    ),
                    Builder(
                      builder: (buttonContext) => FilledButton.icon(
                        key: const ValueKey('export.package'),
                        onPressed: busy ? null : () => onExport(buttonContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                        ),
                        icon: const Icon(CupertinoIcons.share, size: 17),
                        label: Text(_text(context, '导出用例包', 'Export package')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (var index = 0; index < math.min(visible, count); index++) ...[
          const SizedBox(height: 10),
          _GeneratedCase(
            item: batch.cases[index],
            index: index,
            onCopy: () => onCopy(batch.cases[index].value),
          ),
        ],
        if (visible < count) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey('cases.more'),
            onPressed: onShowMore,
            child: Text(_text(context, '显示更多（5条）', 'Show more (5 cases)')),
          ),
        ],
      ],
    );
  }
}

class _GeneratedCase extends StatelessWidget {
  const _GeneratedCase({
    required this.item,
    required this.index,
    required this.onCopy,
  });

  final FixtureCase item;
  final int index;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failureNames = item.checks
        .where((check) => item.expectedFailureIds.contains(check.id))
        .map((check) => _chinese(context) ? check.labelZh : check.labelEn);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text(context, '用例 ${index + 1}', 'Case ${index + 1}'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onCopy,
                  tooltip: _text(context, '复制号码', 'Copy number'),
                  icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                ),
              ],
            ),
            SelectableText(
              item.value,
              key: ValueKey('case.value.$index'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (item.expectedFailureIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "${_text(context, '预期不通过', 'Expected failure')}: ${failureNames.join(' · ')}",
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            ExpansionTile(
              key: ValueKey('case.expand.$index'),
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: Text(
                _text(context, '查看逐项检查', 'Inspect rule checks'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              children: [
                for (final check in item.checks) _CheckResult(check: check),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckResult extends StatelessWidget {
  const _CheckResult({required this.check});

  final RuleCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, status, color) = switch (check.status) {
      'pass' => (
        CupertinoIcons.checkmark_circle,
        _text(context, '通过', 'Pass'),
        theme.brightness == Brightness.dark
            ? const Color(0xff94d6aa)
            : const Color(0xff22643e),
      ),
      'fail' => (
        CupertinoIcons.xmark_circle,
        _text(context, '未通过', 'Fail'),
        scheme.error,
      ),
      _ => (
        CupertinoIcons.question_circle,
        _text(context, '未知', 'Unknown'),
        scheme.onSurfaceVariant,
      ),
    };
    final label = Text(
      _chinese(context) ? check.labelZh : check.labelEn,
      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
    );
    final indicator = Wrap(
      spacing: 5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, color: color, size: 15),
        Text(
          status,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth < 220 ||
                MediaQuery.textScalerOf(context).scale(12) > 17
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, const SizedBox(height: 4), indicator],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  indicator,
                ],
              ),
      ),
    );
  }
}
