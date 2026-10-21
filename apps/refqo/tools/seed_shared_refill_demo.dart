import 'dart:io';

import 'package:refqo/domain.dart';
import 'package:refqo/storage.dart';

// Stop Refqo on the QA simulator first. This appends one marked demo group,
// preserves the existing library/preferences and uses the normal atomic save.
Future<void> main(List<String> args) async {
  if (args.length != 1 || !await Directory(args.single).exists()) {
    stderr.writeln(
      'Usage: dart run tools/seed_shared_refill_demo.dart '
      '<simulator app-support-directory>',
    );
    exitCode = 64;
    return;
  }
  final repository = FileRepository(Directory(args.single));
  final original = await repository.load();
  const supplyId = 'refqo_demo_shared_c42_v1';
  const livingId = 'refqo_demo_living_purifier_v1';
  const studyId = 'refqo_demo_study_purifier_v1';
  if (original.supplies.any((s) => s.id == supplyId)) {
    stdout.writeln('The marked demo already exists; no data changed.');
    return;
  }
  if (original.slots.any((s) => s.id == livingId || s.id == studyId)) {
    throw StateError('Partial demo exists; refusing to overwrite records.');
  }
  final now = DateTime.now();
  var seeded = addSupply(
    original,
    const Supply(
      id: supplyId,
      name: '演示 · C42 活性炭滤芯',
      code: 'DEMO-C42 / 120 × 80 mm',
      notes:
          '演示数据：客厅与书房净化器共用一份备件库存。'
          '示例型号和周期不代表真实适配或更换建议。',
    ),
  );
  for (final item in [
    (livingId, '演示 · 客厅净化器', 25),
    (studyId, '演示 · 书房净化器', 18),
  ]) {
    seeded = addSlot(
      seeded,
      Slot(
        id: item.$1,
        supplyId: supplyId,
        name: item.$2,
        intervalDays: 30,
        lastChanged: DateTime(now.year, now.month, now.day - item.$3),
        verified: true,
      ),
    );
  }
  seeded = receiveSupply(seeded, supplyId, 1, now).copyWith(onboarded: true);
  SupplyForecast plan(AppData data) =>
      forecast(data, now, 30).singleWhere((p) => p.supply.id == supplyId);
  final before = plan(seeded);
  final replaced = replaceSlot(seeded, livingId, now);
  final after = plan(replaced);
  if (before.demand != 2 ||
      before.stock != 1 ||
      before.gap != 1 ||
      after.demand != 2 ||
      after.stock != 0 ||
      after.gap != 2 ||
      encodeAppData(undoLast(replaced)) != encodeAppData(seeded)) {
    throw StateError('Demo forecast/undo invariants failed; nothing saved.');
  }
  await repository.save(seeded);
  stdout.writeln(
    'Demo appended: 2 appliances share 1 supply; 30-day demand 2, stock 1, '
    'purchase gap 1. Replacement: stock 0, gap 2. Undo: stock 1, gap 1.',
  );
}
