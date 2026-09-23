import 'package:flutter/cupertino.dart';

final class TripSummaryCategoryRow {
  const TripSummaryCategoryRow({required this.label, required this.amount});

  final String label;
  final String amount;
}

final class TripSummaryCardData {
  const TripSummaryCardData({
    required this.brand,
    required this.summaryLabel,
    required this.tripName,
    required this.destinations,
    required this.dateRange,
    required this.budgetLabel,
    required this.budget,
    required this.spentLabel,
    required this.spent,
    required this.remainingLabel,
    required this.remaining,
    required this.dailyRemainingLabel,
    required this.dailyRemaining,
    required this.dayProgressLabel,
    required this.dayProgress,
    required this.categoriesLabel,
    required this.categories,
    required this.generatedAt,
    required this.disclaimer,
  });

  final String brand;
  final String summaryLabel;
  final String tripName;
  final String destinations;
  final String dateRange;
  final String budgetLabel;
  final String budget;
  final String spentLabel;
  final String spent;
  final String remainingLabel;
  final String remaining;
  final String dailyRemainingLabel;
  final String dailyRemaining;
  final String dayProgressLabel;
  final String dayProgress;
  final String categoriesLabel;
  final List<TripSummaryCategoryRow> categories;
  final String generatedAt;
  final String disclaimer;
}

class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({required this.data, super.key});

  final TripSummaryCardData data;

  static const Color _ink = Color(0xFF10243E);
  static const Color _muted = Color(0xFF65758B);
  static const Color _accent = Color(0xFF2D7AFF);
  static const Color _softBlue = Color(0xFFEAF2FF);
  static const Color _line = Color(0xFFDDE5EF);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('trip-summary-card'),
      width: double.infinity,
      color: const Color(0xFFFFFFFF),
      padding: const EdgeInsets.all(24),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          height: 1.25,
          decoration: TextDecoration.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.airplane,
                    color: Color(0xFFFFFFFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      data.brand,
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      data.summaryLabel,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              data.tripName,
              style: const TextStyle(
                color: _ink,
                fontSize: 28,
                height: 1.12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.destinations,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.dateRange,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: const BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _SummaryMetric(
                          label: data.budgetLabel,
                          value: data.budget,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryMetric(
                          label: data.spentLabel,
                          value: data.spent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _SummaryMetric(
                          label: data.remainingLabel,
                          value: data.remaining,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryMetric(
                          label: data.dailyRemainingLabel,
                          value: data.dailyRemaining,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _LabelValueRow(
              label: data.dayProgressLabel,
              value: data.dayProgress,
            ),
            if (data.categories.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Container(height: 1, color: _line),
              const SizedBox(height: 18),
              Text(
                data.categoriesLabel,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final category in data.categories)
                _LabelValueRow(label: category.label, value: category.amount),
            ],
            const SizedBox(height: 22),
            Container(height: 1, color: _line),
            const SizedBox(height: 14),
            Text(
              data.generatedAt,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              data.disclaimer,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(color: TripSummaryCard._muted, fontSize: 12),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: TripSummaryCard._ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: TripSummaryCard._muted),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: TripSummaryCard._ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
