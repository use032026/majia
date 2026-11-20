import 'care_item.dart';
import 'maintenance_calendar.dart';
import 'maintenance_plan.dart';
import 'maintenance_record.dart';
import 'maintenance_status.dart';
import 'maintenance_task.dart';

class MaintenanceLifecycleSnapshot {
  const MaintenanceLifecycleSnapshot({
    required this.usageDays,
    required this.completionCount,
    required this.totalCost,
    required this.nextTask,
    required this.overdueCount,
  });

  factory MaintenanceLifecycleSnapshot.fromItem(
    CareItem item, {
    DateTime? now,
  }) {
    final today = maintenanceDateOnly(now ?? DateTime.now());
    final purchaseDate = item.purchaseDate == null
        ? null
        : maintenanceDateOnly(item.purchaseDate!);
    final usageDays = purchaseDate == null || purchaseDate.isAfter(today)
        ? null
        : maintenanceDayDifference(today, purchaseDate);
    final tasks = maintenanceTasksForItems([item], now: today);
    return MaintenanceLifecycleSnapshot(
      usageDays: usageDays,
      completionCount: item.records.length,
      totalCost: item.records.fold<double>(
        0,
        (total, record) => total + record.cost,
      ),
      nextTask: tasks.isEmpty ? null : tasks.first,
      overdueCount: tasks
          .where((task) => task.status.dueState == MaintenanceTaskState.overdue)
          .length,
    );
  }

  final int? usageDays;
  final int completionCount;
  final double totalCost;
  final MaintenanceTask? nextTask;
  final int overdueCount;
}

enum MaintenanceTimelineEntryType { record, purchase }

class MaintenanceTimelineEntry {
  const MaintenanceTimelineEntry._({
    required this.type,
    required this.date,
    required this.record,
  });

  factory MaintenanceTimelineEntry.record(MaintenanceRecord record) =>
      MaintenanceTimelineEntry._(
        type: MaintenanceTimelineEntryType.record,
        date: record.completedAt,
        record: record,
      );

  factory MaintenanceTimelineEntry.purchase(DateTime date) =>
      MaintenanceTimelineEntry._(
        type: MaintenanceTimelineEntryType.purchase,
        date: date,
        record: null,
      );

  final MaintenanceTimelineEntryType type;
  final DateTime date;
  final MaintenanceRecord? record;
}

List<MaintenanceTimelineEntry> maintenanceTimelineForItem(CareItem item) {
  final entries = <MaintenanceTimelineEntry>[
    ...item.records.map(MaintenanceTimelineEntry.record),
    if (item.purchaseDate != null)
      MaintenanceTimelineEntry.purchase(item.purchaseDate!),
  ];
  entries.sort((a, b) {
    final dateOrder = b.date.compareTo(a.date);
    if (dateOrder != 0) return dateOrder;
    final typeOrder = a.type.index.compareTo(b.type.index);
    if (typeOrder != 0) return typeOrder;
    return (a.record?.id ?? '').compareTo(b.record?.id ?? '');
  });
  return List.unmodifiable(entries);
}

CareItem recalculateMaintenancePlanFromRecords(
  CareItem item,
  String? planId, {
  DateTime? fallbackDueDate,
}) {
  if (planId == null) return item;
  final planIndex = item.plans.indexWhere((plan) => plan.id == planId);
  if (planIndex == -1) return item;

  MaintenanceRecord? latestRecord;
  for (final record in item.records) {
    if (record.planId != planId) continue;
    if (latestRecord == null ||
        record.completedAt.isAfter(latestRecord.completedAt) ||
        (record.completedAt.isAtSameMomentAs(latestRecord.completedAt) &&
            record.id.compareTo(latestRecord.id) < 0)) {
      latestRecord = record;
    }
  }
  final plan = item.plans[planIndex];
  final plans = [...item.plans];
  if (latestRecord == null) {
    final normalizedFallback = fallbackDueDate == null
        ? null
        : maintenanceDateOnly(fallbackDueDate);
    final changed =
        plan.lastCompletedAt != null ||
        plan.dueDate != normalizedFallback ||
        plan.deferredUntil != null;
    plans[planIndex] = plan.copyWith(
      clearLastCompletedAt: true,
      dueDate: normalizedFallback,
      clearDueDate: normalizedFallback == null,
      clearDeferredUntil: changed,
    );
    return item.copyWith(plans: plans);
  }

  final lastCompletedAt = maintenanceDateOnly(latestRecord.completedAt);
  final dueDate = addMaintenanceDays(lastCompletedAt, plan.intervalDays);
  final scheduleChanged =
      plan.lastCompletedAt == null ||
      maintenanceDateOnly(plan.lastCompletedAt!) != lastCompletedAt ||
      plan.dueDate == null ||
      maintenanceDateOnly(plan.dueDate!) != dueDate;
  plans[planIndex] = plan.copyWith(
    lastCompletedAt: lastCompletedAt,
    dueDate: dueDate,
    clearDeferredUntil: scheduleChanged,
  );
  return item.copyWith(plans: plans);
}

CareItem freezeMaintenanceHistorySnapshots(CareItem item) {
  var changed = false;
  final records = item.records
      .map((record) {
        if (record.stepSnapshots != null) return record;
        MaintenancePlan? plan;
        for (final candidate in item.plans) {
          if (candidate.id == record.planId) {
            plan = candidate;
            break;
          }
        }
        changed = true;
        return record.copyWith(
          stepSnapshots: captureMaintenanceStepSnapshots(
            plan,
            record.completedStepIds,
          ),
        );
      })
      .toList(growable: false);
  return changed ? item.copyWith(records: records) : item;
}
