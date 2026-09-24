import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/experiment_math.dart';
import '../domain/models.dart';
import '../l10n/app_strings.dart';
import 'app_theme.dart';

class ExperimentView extends StatelessWidget {
  const ExperimentView({
    required this.lesson,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final Lesson lesson;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final content = switch (lesson.kind) {
      LessonKind.axis => _AxisExperiment(
        lesson: lesson,
        value: value,
        onChanged: onChanged,
      ),
      LessonKind.correlation => _CorrelationExperiment(
        lesson: lesson,
        value: value,
        onChanged: onChanged,
      ),
      LessonKind.sample => _SampleExperiment(
        lesson: lesson,
        value: value,
        onChanged: onChanged,
      ),
      LessonKind.risk => _RiskExperiment(
        lesson: lesson,
        value: value,
        onChanged: onChanged,
      ),
    };
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.48,
        duration: const Duration(milliseconds: 180),
        child: content,
      ),
    );
  }
}

class _AxisExperiment extends StatelessWidget {
  const _AxisExperiment({
    required this.lesson,
    required this.value,
    required this.onChanged,
  });

  final Lesson lesson;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final low = lesson.values[0];
    final high = lesson.values[1];
    final maximum = lesson.axisMaximum ?? 100.0;
    final amplification = ExperimentMath.visibleDifferenceRatio(
      lowValue: low,
      highValue: high,
      axisMinimum: value.clamp(0, low - 0.1),
      axisMaximum: maximum,
    );
    final summary = strings.text(
      '柱 A 为 ${low.toStringAsFixed(0)}，柱 B 为 ${high.toStringAsFixed(0)}，纵轴起点 ${value.toStringAsFixed(0)}。当前视觉差异约为完整比例的 ${amplification.toStringAsFixed(1)} 倍。',
      'Bar A is ${low.toStringAsFixed(0)}, bar B is ${high.toStringAsFixed(0)}, and the baseline is ${value.toStringAsFixed(0)}. The visible gap is about ${amplification.toStringAsFixed(1)} times the full-scale gap.',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: summary,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 210,
              child: CustomPaint(
                painter: _BarChartPainter(
                  values: lesson.values,
                  minimum: value,
                  maximum: maximum,
                  color: Theme.of(context).colorScheme.primary,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                  textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        Text(
          strings.text(
            '纵轴起点 ${value.toStringAsFixed(0)} · 视觉放大 ${amplification.toStringAsFixed(1)}×',
            'Baseline ${value.toStringAsFixed(0)} · visual amplification ${amplification.toStringAsFixed(1)}×',
          ),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          key: const Key('axis-slider'),
          value: value,
          min: lesson.minParameter,
          max: lesson.maxParameter,
          divisions: (lesson.maxParameter - lesson.minParameter).round(),
          label: value.toStringAsFixed(0),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CorrelationExperiment extends StatelessWidget {
  const _CorrelationExperiment({
    required this.lesson,
    required this.value,
    required this.onChanged,
  });

  final Lesson lesson;
  final double value;
  final ValueChanged<double> onChanged;

  List<math.Point<double>> get _allPoints {
    final result = <math.Point<double>>[];
    for (var index = 0; index < lesson.values.length; index += 2) {
      result.add(math.Point(lesson.values[index], lesson.values[index + 1]));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final includeLast = value >= 0.5;
    final isCausationLesson =
        lesson.mode == ExperimentMode.correlationCausation;
    final all = _allPoints;
    final points = isCausationLesson
        ? all
        : includeLast
        ? all
        : all.sublist(0, all.length - 1);
    final coefficient = ExperimentMath.correlation(points);
    final summary = strings.text(
      '散点图包含 ${points.length} 个点，相关系数 ${coefficient.toStringAsFixed(2)}。',
      'Scatter plot with ${points.length} points and correlation ${coefficient.toStringAsFixed(2)}.',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: summary,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 210,
              child: CustomPaint(
                painter: _ScatterPainter(
                  points: points,
                  color: Theme.of(context).colorScheme.secondary,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                strings.text(
                  '相关系数 r = ${coefficient.toStringAsFixed(2)}',
                  'Correlation r = ${coefficient.toStringAsFixed(2)}',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Switch.adaptive(
              key: const Key('outlier-switch'),
              value: includeLast,
              onChanged: (selected) => onChanged(selected ? 1 : 0),
            ),
          ],
        ),
        Text(
          strings.text(
            isCausationLesson
                ? includeLast
                      ? '补充可能的第三变量：气温'
                      : '只看两项指标'
                : includeLast
                ? '包含高杠杆点'
                : '排除最后一个高杠杆点',
            isCausationLesson
                ? includeLast
                      ? 'Possible third variable added: temperature'
                      : 'Only the two measures are shown'
                : includeLast
                ? 'High-leverage point included'
                : 'High-leverage point excluded',
          ),
        ),
        if (isCausationLesson && includeLast)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              strings.text(
                '气温同时影响冷饮需求和游泳人数；相关线本身没有消失。',
                'Temperature affects both demand and swimmer count; the correlation itself does not disappear.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _SampleExperiment extends StatelessWidget {
  const _SampleExperiment({
    required this.lesson,
    required this.value,
    required this.onChanged,
  });

  final Lesson lesson;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final rate = ExperimentMath.weightedRate(
      firstRate: lesson.values[0],
      secondRate: lesson.values[1],
      firstWeight: value,
    );
    final firstCount = (value * 20).round();
    final summary = strings.text(
      '20 人样本中第一组约 $firstCount 人，估计结果 ${(rate * 100).round()}%。',
      'In a sample of 20, about $firstCount come from group one; the estimate is ${(rate * 100).round()}%.',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: summary,
          child: ExcludeSemantics(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(20, (index) {
                final isFirst = index < firstCount;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isFirst
                        ? AppTheme.amber
                        : AppTheme.mint.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    isFirst ? Icons.bolt_rounded : Icons.person_outline_rounded,
                    size: 17,
                    color: AppTheme.ink,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          strings.text(
            '第一组占比 ${(value * 100).round()}% · 样本估计 ${(rate * 100).round()}%',
            'Group-one share ${(value * 100).round()}% · estimate ${(rate * 100).round()}%',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          key: const Key('sample-slider'),
          value: value,
          min: lesson.minParameter,
          max: lesson.maxParameter,
          divisions: 18,
          label: '${(value * 100).round()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RiskExperiment extends StatelessWidget {
  const _RiskExperiment({
    required this.lesson,
    required this.value,
    required this.onChanged,
  });

  final Lesson lesson;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final foreground = Theme.of(context).colorScheme.onPrimaryContainer;
    final mode = value.round().clamp(0, 2);
    final baseline = lesson.values[0];
    final observed = lesson.values[1];
    final isFrequencyLesson = lesson.mode == ExperimentMode.riskFrequency;
    final reduction = ExperimentMath.relativeRiskReduction(
      baseline: baseline,
      observed: observed,
    );
    final display = isFrequencyLesson
        ? switch (mode) {
            0 => '5%',
            1 => '5 / 100',
            _ => '1 / 20',
          }
        : switch (mode) {
            0 => '${(reduction * 100).round()}%',
            1 => '${((baseline - observed) * 100).toStringAsFixed(0)} / 100',
            _ => '2 → 1 / 100',
          };
    final modeName = isFrequencyLesson
        ? switch (mode) {
            0 => strings.text('百分比', 'Percentage'),
            1 => strings.text('每百人', 'Per hundred'),
            _ => strings.text('自然频率', 'Natural frequency'),
          }
        : switch (mode) {
            0 => strings.text('相对变化', 'Relative'),
            1 => strings.text('绝对变化', 'Absolute'),
            _ => strings.text('自然频率', 'Natural frequency'),
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: '$modeName $display',
          child: Container(
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  modeName,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: foreground),
                ),
                const SizedBox(height: 8),
                Text(
                  display,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isFrequencyLesson
                      ? strings.text(
                          '相同人群 · 相同时间范围 · 相同概率',
                          'Same population · timeframe · probability',
                        )
                      : strings.text(
                          '基线 ${(baseline * 100).round()} / 100 · 观察值 ${(observed * 100).round()} / 100',
                          'Baseline ${(baseline * 100).round()} in 100 · observed ${(observed * 100).round()} in 100',
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: foreground),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          key: const Key('risk-format'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 0,
              label: Text(
                isFrequencyLesson
                    ? strings.text('百分比', 'Percent')
                    : strings.text('相对', 'Relative'),
              ),
            ),
            ButtonSegment(
              value: 1,
              label: Text(
                isFrequencyLesson
                    ? strings.text('每百人', 'Per 100')
                    : strings.text('绝对', 'Absolute'),
              ),
            ),
            ButtonSegment(
              value: 2,
              label: Text(strings.text('频率', 'Frequency')),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) =>
              onChanged(selection.single.toDouble()),
        ),
      ],
    );
  }
}

class EvidenceComparison extends StatelessWidget {
  const EvidenceComparison({required this.lesson, super.key});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.comparisonTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          lesson.correctVerdict == Verdict.fair
              ? strings.unchangedFairData
              : strings.unchangedData,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final initial = _EvidenceSnapshot(
              key: const Key('comparison-initial'),
              lesson: lesson,
              parameter: lesson.initialParameter,
              label: strings.initialView,
              emphasized: false,
            );
            final fair = _EvidenceSnapshot(
              key: const Key('comparison-fair'),
              lesson: lesson,
              parameter: lesson.fairParameter,
              label: lesson.correctVerdict == Verdict.fair
                  ? strings.equivalentFairView
                  : strings.fairView,
              emphasized: true,
            );
            if (constraints.maxWidth >= 540) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: initial),
                  const SizedBox(width: 12),
                  Expanded(child: fair),
                ],
              );
            }
            return Column(
              children: [initial, const SizedBox(height: 10), fair],
            );
          },
        ),
      ],
    );
  }
}

class _EvidenceSnapshot extends StatelessWidget {
  const _EvidenceSnapshot({
    required this.lesson,
    required this.parameter,
    required this.label,
    required this.emphasized,
    super.key,
  });

  final Lesson lesson;
  final double parameter;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = emphasized
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: emphasized ? scheme.secondary : scheme.outlineVariant,
          width: emphasized ? 2 : 1,
        ),
      ),
      child: IconTheme(
        data: IconThemeData(color: foreground),
        child: DefaultTextStyle(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    emphasized
                        ? Icons.balance_rounded
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _snapshotBody(context, foreground),
            ],
          ),
        ),
      ),
    );
  }

  Widget _snapshotBody(BuildContext context, Color foreground) {
    return switch (lesson.kind) {
      LessonKind.axis => _axisSnapshot(context, foreground),
      LessonKind.correlation => _correlationSnapshot(context, foreground),
      LessonKind.sample => _sampleSnapshot(context, foreground),
      LessonKind.risk => _riskSnapshot(context, foreground),
    };
  }

  Widget _axisSnapshot(BuildContext context, Color foreground) {
    final strings = AppStrings(Localizations.localeOf(context));
    final maximum = lesson.axisMaximum ?? 100.0;
    final amplification = ExperimentMath.visibleDifferenceRatio(
      lowValue: lesson.values[0],
      highValue: lesson.values[1],
      axisMinimum: parameter,
      axisMaximum: maximum,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _BarChartPainter(
              values: lesson.values,
              minimum: parameter,
              maximum: maximum,
              color: emphasized
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
              gridColor: Theme.of(context).colorScheme.outlineVariant,
              textColor: foreground,
            ),
          ),
        ),
        Text(
          strings.text(
            '范围 ${parameter.toStringAsFixed(0)}–${maximum.toStringAsFixed(0)} u · 放大 ${amplification.toStringAsFixed(1)}×',
            'Range ${parameter.toStringAsFixed(0)}–${maximum.toStringAsFixed(0)} u · ${amplification.toStringAsFixed(1)}×',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _correlationSnapshot(BuildContext context, Color foreground) {
    final strings = AppStrings(Localizations.localeOf(context));
    final all = <math.Point<double>>[];
    for (var index = 0; index < lesson.values.length; index += 2) {
      all.add(math.Point(lesson.values[index], lesson.values[index + 1]));
    }
    final isCausation = lesson.mode == ExperimentMode.correlationCausation;
    final showContext = parameter >= 0.5;
    final points = isCausation || showContext
        ? all
        : all.sublist(0, all.length - 1);
    final coefficient = ExperimentMath.correlation(points);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _ScatterPainter(
              points: points,
              color: Theme.of(context).colorScheme.secondary,
              gridColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        Text(
          isCausation
              ? strings.text(
                  showContext
                      ? 'r = ${coefficient.toStringAsFixed(2)} · 第三变量：气温'
                      : 'r = ${coefficient.toStringAsFixed(2)} · 只看两个指标',
                  showContext
                      ? 'r = ${coefficient.toStringAsFixed(2)} · third factor: temperature'
                      : 'r = ${coefficient.toStringAsFixed(2)} · two measures only',
                )
              : strings.text(
                  '样本点 ${points.length} · r = ${coefficient.toStringAsFixed(2)}',
                  '${points.length} points · r = ${coefficient.toStringAsFixed(2)}',
                ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _sampleSnapshot(BuildContext context, Color foreground) {
    final strings = AppStrings(Localizations.localeOf(context));
    final rate = ExperimentMath.weightedRate(
      firstRate: lesson.values[0],
      secondRate: lesson.values[1],
      firstWeight: parameter,
    );
    return Column(
      children: [
        Text(
          '${(rate * 100).round()}%',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          strings.text(
            '第一组占比 ${(parameter * 100).round()}%',
            'Group-one share ${(parameter * 100).round()}%',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _riskSnapshot(BuildContext context, Color foreground) {
    final strings = AppStrings(Localizations.localeOf(context));
    final isFrequency = lesson.mode == ExperimentMode.riskFrequency;
    final mode = parameter.round();
    final display = isFrequency
        ? switch (mode) {
            0 => '5%',
            1 => '5 / 100',
            _ => '1 / 20',
          }
        : switch (mode) {
            0 => '50%',
            1 => '1 / 100',
            _ => '2 → 1 / 100',
          };
    return Column(
      children: [
        Text(
          display,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          isFrequency
              ? strings.text('同一概率与时间范围', 'Same chance and timeframe')
              : strings.text('相对值加上绝对基线', 'Relative claim plus baseline'),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.minimum,
    required this.maximum,
    required this.color,
    required this.gridColor,
    required this.textColor,
  });

  final List<double> values;
  final double minimum;
  final double maximum;
  final Color color;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 54.0;
    const bottom = 30.0;
    const top = 12.0;
    final chartHeight = size.height - bottom - top;
    final range = math.max(0.1, maximum - minimum);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final y = top + chartHeight * index / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
    }
    _paintLabel(canvas, '${maximum.toStringAsFixed(0)} u', Offset(0, top - 2));
    _paintLabel(
      canvas,
      '${minimum.toStringAsFixed(0)} u',
      Offset(0, top + chartHeight - 12),
    );
    final barPaint = Paint()..color = color;
    final width = math.min(76.0, (size.width - left) / 4);
    for (var index = 0; index < values.length; index++) {
      final normalized = ((values[index] - minimum) / range).clamp(0.0, 1.0);
      final height = chartHeight * normalized;
      final center = left + (size.width - left) * (index + 1) / 3;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center - width / 2,
          top + chartHeight - height,
          width,
          height,
        ),
        const Radius.circular(10),
      );
      canvas.drawRRect(rect, barPaint);
      final painter = TextPainter(
        text: TextSpan(
          text:
              '${String.fromCharCode(65 + index)}  ${values[index].toStringAsFixed(0)}',
          style: TextStyle(color: textColor, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(center - painter.width / 2, size.height - 21),
      );
    }
  }

  void _paintLabel(Canvas canvas, String label, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.minimum != minimum ||
      oldDelegate.maximum != maximum ||
      oldDelegate.color != color;
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter({
    required this.points,
    required this.color,
    required this.gridColor,
  });

  final List<math.Point<double>> points;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final position = index / 4;
      canvas.drawLine(
        Offset(16, 12 + position * (size.height - 28)),
        Offset(size.width - 8, 12 + position * (size.height - 28)),
        gridPaint,
      );
    }
    final minX = points.map((point) => point.x).reduce(math.min);
    final maxX = points.map((point) => point.x).reduce(math.max);
    final minY = points.map((point) => point.y).reduce(math.min);
    final maxY = points.map((point) => point.y).reduce(math.max);
    final pointPaint = Paint()..color = color;
    for (final point in points) {
      final x =
          18 +
          (point.x - minX) / math.max(0.1, maxX - minX) * (size.width - 34);
      final y =
          size.height -
          18 -
          (point.y - minY) / math.max(0.1, maxY - minY) * (size.height - 36);
      canvas.drawCircle(Offset(x, y), 6, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter oldDelegate) =>
      oldDelegate.points.length != points.length || oldDelegate.color != color;
}
