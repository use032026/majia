import 'care_item.dart';
import 'maintenance_calendar.dart';
import 'maintenance_record.dart';
import 'maintenance_status.dart';
import 'maintenance_task.dart';

class MaintenanceCostBreakdown {
  const MaintenanceCostBreakdown({
    required this.id,
    required this.label,
    required this.amount,
  });

  final String id;
  final String label;
  final double amount;
}

class MaintenanceReportRecord {
  const MaintenanceReportRecord({
    required this.itemId,
    required this.itemName,
    required this.record,
  });

  final String itemId;
  final String itemName;
  final MaintenanceRecord record;
}

class MaintenanceReportSnapshot {
  const MaintenanceReportSnapshot({
    required this.today,
    required this.currentMonthStart,
    required this.nextMonthStart,
    required this.trailingYearStart,
    required this.trailingYearEnd,
    required this.currentYearStart,
    required this.currentYearEnd,
    required this.nextThirtyDaysEnd,
    required this.completedThisMonth,
    required this.currentOverdueCount,
    required this.cumulativeOverdueDays,
    required this.dueNextThirtyDays,
    required this.costLastTwelveMonths,
    required this.costCurrentYear,
    required this.onTimeCompletionCount,
    required this.eligibleCompletionCount,
    required this.excludedCompletionCount,
    required this.totalRecordCount,
    required this.ignoredCostRecordCount,
    required this.ignoredCurrentYearCostRecordCount,
    required this.costsByItem,
    required this.costsByCategory,
    required this.currentYearCostsByItem,
    required this.currentYearCostsByCategory,
    required this.currentYearRecords,
    required this.recentRecords,
  });

  factory MaintenanceReportSnapshot.fromItems(
    List<CareItem> items, {
    DateTime? now,
  }) {
    final today = maintenanceDateOnly(now ?? DateTime.now());
    final currentMonthStart = DateTime(today.year, today.month);
    final nextMonthStart = DateTime(today.year, today.month + 1);
    final trailingYearStart = DateTime(today.year, today.month - 11);
    final trailingYearEnd = nextMonthStart;
    final currentYearStart = DateTime(today.year);
    final currentYearEnd = DateTime(today.year + 1);
    final nextThirtyDaysEnd = addMaintenanceDays(today, 30);
    final tasks = maintenanceTasksForItems(items, now: today);
    final records = <MaintenanceReportRecord>[];

    for (final item in items) {
      for (final record in item.records) {
        records.add(
          MaintenanceReportRecord(
            itemId: item.id,
            itemName: item.name,
            record: record,
          ),
        );
      }
    }
    records.sort((a, b) {
      final dateOrder = b.record.completedAt.compareTo(a.record.completedAt);
      if (dateOrder != 0) return dateOrder;
      final itemOrder = a.itemName.compareTo(b.itemName);
      if (itemOrder != 0) return itemOrder;
      return a.record.id.compareTo(b.record.id);
    });

    final trailingRecords = records
        .where((entry) {
          final completedAt = maintenanceDateOnly(entry.record.completedAt);
          return !completedAt.isBefore(trailingYearStart) &&
              completedAt.isBefore(trailingYearEnd);
        })
        .toList(growable: false);
    final currentYearRecords = records
        .where((entry) {
          final completedAt = maintenanceDateOnly(entry.record.completedAt);
          return !completedAt.isBefore(currentYearStart) &&
              completedAt.isBefore(currentYearEnd);
        })
        .toList(growable: false);
    final itemById = {for (final item in items) item.id: item};
    final itemCosts = <String, double>{};
    final categoryCosts = <String, double>{};
    var costLastTwelveMonths = 0.0;
    var ignoredCostRecordCount = 0;
    var onTimeCompletionCount = 0;
    var eligibleCompletionCount = 0;
    var excludedCompletionCount = 0;
    final currentYearItemCosts = <String, double>{};
    final currentYearCategoryCosts = <String, double>{};
    var costCurrentYear = 0.0;
    var ignoredCurrentYearCostRecordCount = 0;

    for (final entry in trailingRecords) {
      final record = entry.record;
      final cost = record.cost;
      if (cost.isFinite && cost >= 0) {
        costLastTwelveMonths += cost;
        itemCosts.update(
          entry.itemId,
          (value) => value + cost,
          ifAbsent: () => cost,
        );
        final category = _reportCategory(itemById[entry.itemId]?.category);
        categoryCosts.update(
          category,
          (value) => value + cost,
          ifAbsent: () => cost,
        );
      } else {
        ignoredCostRecordCount++;
      }

      final plannedDueDate = record.plannedDueDate;
      if (plannedDueDate == null) {
        excludedCompletionCount++;
        continue;
      }
      eligibleCompletionCount++;
      if (!maintenanceDateOnly(
        record.completedAt,
      ).isAfter(maintenanceDateOnly(plannedDueDate))) {
        onTimeCompletionCount++;
      }
    }

    for (final entry in currentYearRecords) {
      final cost = entry.record.cost;
      if (!cost.isFinite || cost < 0) {
        ignoredCurrentYearCostRecordCount++;
        continue;
      }
      costCurrentYear += cost;
      currentYearItemCosts.update(
        entry.itemId,
        (value) => value + cost,
        ifAbsent: () => cost,
      );
      final category = _reportCategory(itemById[entry.itemId]?.category);
      currentYearCategoryCosts.update(
        category,
        (value) => value + cost,
        ifAbsent: () => cost,
      );
    }

    var currentOverdueCount = 0;
    var cumulativeOverdueDays = 0;
    for (final task in tasks) {
      if (task.status.dueState != MaintenanceTaskState.overdue) continue;
      currentOverdueCount++;
      final daysUntilDue = task.status.daysUntilDue ?? 0;
      cumulativeOverdueDays += daysUntilDue < 0 ? -daysUntilDue : 0;
    }
    final dueNextThirtyDays = tasks.where((task) {
      final dueDate = maintenanceDateOnly(task.dueDate);
      return !dueDate.isBefore(today) && dueDate.isBefore(nextThirtyDaysEnd);
    }).length;
    final completedThisMonth = records.where((entry) {
      final completedAt = maintenanceDateOnly(entry.record.completedAt);
      return !completedAt.isBefore(currentMonthStart) &&
          completedAt.isBefore(nextMonthStart);
    }).length;

    return MaintenanceReportSnapshot(
      today: today,
      currentMonthStart: currentMonthStart,
      nextMonthStart: nextMonthStart,
      trailingYearStart: trailingYearStart,
      trailingYearEnd: trailingYearEnd,
      currentYearStart: currentYearStart,
      currentYearEnd: currentYearEnd,
      nextThirtyDaysEnd: nextThirtyDaysEnd,
      completedThisMonth: completedThisMonth,
      currentOverdueCount: currentOverdueCount,
      cumulativeOverdueDays: cumulativeOverdueDays,
      dueNextThirtyDays: dueNextThirtyDays,
      costLastTwelveMonths: costLastTwelveMonths,
      costCurrentYear: costCurrentYear,
      onTimeCompletionCount: onTimeCompletionCount,
      eligibleCompletionCount: eligibleCompletionCount,
      excludedCompletionCount: excludedCompletionCount,
      totalRecordCount: records.length,
      ignoredCostRecordCount: ignoredCostRecordCount,
      ignoredCurrentYearCostRecordCount: ignoredCurrentYearCostRecordCount,
      costsByItem: _itemBreakdown(itemCosts, itemById),
      costsByCategory: _categoryBreakdown(categoryCosts),
      currentYearCostsByItem: _itemBreakdown(currentYearItemCosts, itemById),
      currentYearCostsByCategory: _categoryBreakdown(currentYearCategoryCosts),
      currentYearRecords: List.unmodifiable(currentYearRecords),
      recentRecords: List.unmodifiable(records),
    );
  }

  final DateTime today;
  final DateTime currentMonthStart;
  final DateTime nextMonthStart;
  final DateTime trailingYearStart;
  final DateTime trailingYearEnd;
  final DateTime currentYearStart;
  final DateTime currentYearEnd;
  final DateTime nextThirtyDaysEnd;
  final int completedThisMonth;
  final int currentOverdueCount;
  final int cumulativeOverdueDays;
  final int dueNextThirtyDays;
  final double costLastTwelveMonths;
  final double costCurrentYear;
  final int onTimeCompletionCount;
  final int eligibleCompletionCount;
  final int excludedCompletionCount;
  final int totalRecordCount;
  final int ignoredCostRecordCount;
  final int ignoredCurrentYearCostRecordCount;
  final List<MaintenanceCostBreakdown> costsByItem;
  final List<MaintenanceCostBreakdown> costsByCategory;
  final List<MaintenanceCostBreakdown> currentYearCostsByItem;
  final List<MaintenanceCostBreakdown> currentYearCostsByCategory;
  final List<MaintenanceReportRecord> currentYearRecords;
  final List<MaintenanceReportRecord> recentRecords;

  double? get onTimeCompletionRate => eligibleCompletionCount == 0
      ? null
      : onTimeCompletionCount / eligibleCompletionCount;
}

List<MaintenanceCostBreakdown> _itemBreakdown(
  Map<String, double> costs,
  Map<String, CareItem> itemById,
) => _sortedBreakdown(
  costs.entries
      .where((entry) => entry.value > 0)
      .map(
        (entry) => MaintenanceCostBreakdown(
          id: entry.key,
          label: itemById[entry.key]?.name.trim().isNotEmpty == true
              ? itemById[entry.key]!.name.trim()
              : '未命名物品',
          amount: entry.value,
        ),
      ),
);

List<MaintenanceCostBreakdown> _categoryBreakdown(Map<String, double> costs) =>
    _sortedBreakdown(
      costs.entries
          .where((entry) => entry.value > 0)
          .map(
            (entry) => MaintenanceCostBreakdown(
              id: entry.key,
              label: entry.key,
              amount: entry.value,
            ),
          ),
    );

List<MaintenanceCostBreakdown> _sortedBreakdown(
  Iterable<MaintenanceCostBreakdown> values,
) {
  final result = values.toList()
    ..sort((a, b) {
      final amountOrder = b.amount.compareTo(a.amount);
      if (amountOrder != 0) return amountOrder;
      final labelOrder = a.label.compareTo(b.label);
      if (labelOrder != 0) return labelOrder;
      return a.id.compareTo(b.id);
    });
  return List.unmodifiable(result);
}

String _reportCategory(String? category) {
  final normalized = category?.trim() ?? '';
  return normalized.isEmpty ? '未分类' : normalized;
}
