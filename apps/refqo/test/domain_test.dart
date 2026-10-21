import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:refqo/domain.dart';

final day = DateTime.utc(2026, 1, 11);
AppData household({int stock = 3, bool verified = true, int units = 2}) =>
    AppData(
      supplies: [Supply(id: 'filter', name: 'Carbon refill', stock: stock)],
      slots: [
        Slot(
          id: 'kitchen',
          supplyId: 'filter',
          name: 'Kitchen purifier',
          intervalDays: 10,
          lastChanged: DateTime.utc(2026, 1, 1),
          verified: verified,
          units: units,
        ),
      ],
    );

void main() {
  group('calendar demand and shared stock', () {
    test(
      'inclusive horizon multiplies occurrences by units and deducts shared stock once',
      () {
        final data = household().copyWith(
          slots: [
            ...household().slots,
            Slot(
              id: 'bedroom',
              supplyId: 'filter',
              name: 'Bedroom',
              intervalDays: 20,
              lastChanged: DateTime.utc(2026, 1, 1),
              verified: true,
            ),
          ],
        );
        final result = forecast(data, day, 20).single;
        expect(result.slots.map((s) => s.occurrences), [3, 1]);
        expect(result.demand, 7);
        expect(result.stock, 3);
        expect(result.gap, 4);
        expect(data.supplies.single.stock, 3);
      },
    );
    test('overdue is one immediate set then cadence restarts today', () {
      final result = forecast(household(), DateTime.utc(2026, 2, 1), 20).single;
      expect(result.demand, 6);
      expect(result.overdueCount, 1);
      expect(result.slots.single.firstDue, DateTime.utc(2026, 2, 1));
    });
    test(
      'today, before horizon, leap date, and local midnight ignore time-of-day',
      () {
        expect(forecast(household(), day, 0).single.demand, 2);
        expect(
          forecast(household(), DateTime.utc(2026, 1, 10), 0).single.demand,
          0,
        );
        final data = household(units: 1).copyWith(
          slots: [
            household(units: 1).slots.single.copyWith(
              intervalDays: 1,
              lastChanged: DateTime(2024, 2, 28, 23, 59),
            ),
          ],
        );
        expect(forecast(data, DateTime(2024, 2, 29, 0, 1), 1).single.demand, 2);
        final dst = data.copyWith(
          slots: [
            data.slots.single.copyWith(
              lastChanged: DateTime(2026, 3, 7, 23, 59),
            ),
          ],
        );
        expect(forecast(dst, DateTime(2026, 3, 8, 0, 1), 1).single.demand, 2);
      },
    );
    test(
      'unlinked stock produces no purchase gap and invalid horizons reject',
      () {
        expect(
          forecast(household().copyWith(slots: []), day, 30).single.gap,
          0,
        );
        expect(() => forecast(household(), day, -1), throwsStateError);
      },
    );
  });

  group('immutable receipt, installation and undo', () {
    test(
      'receipt then replacement update stock, date and forecast; both undo exactly',
      () {
        final original = household(stock: 0);
        final received = receiveSupply(original, 'filter', 5, day);
        final replaced = replaceSlot(received, 'kitchen', day);
        expect(original.supplies.single.stock, 0);
        expect(received.supplies.single.stock, 5);
        expect(replaced.supplies.single.stock, 3);
        expect(replaced.slots.single.lastChanged, day);
        expect(replaced.events.last.units, 2);
        expect(replaced.events.last.slotName, 'Kitchen purifier');
        expect(forecast(replaced, day, 0).single.demand, 0);
        expect(encodeAppData(undoLast(replaced)), encodeAppData(received));
        expect(
          encodeAppData(undoLast(undoLast(replaced))),
          encodeAppData(original),
        );
        expect(
          () => original.supplies.add(const Supply(id: 'x', name: 'x')),
          throwsUnsupportedError,
        );
      },
    );
    test(
      'stock, confirmation and replacement date blocks leave original untouched',
      () {
        expect(
          () => replaceSlot(household(stock: 0), 'kitchen', day),
          throwsStateError,
        );
        expect(
          () => replaceSlot(household(verified: false), 'kitchen', day),
          throwsStateError,
        );
        expect(
          () => replaceSlot(household(), 'kitchen', DateTime.utc(2025, 12, 31)),
          throwsStateError,
        );
        expect(
          () => receiveSupply(household(stock: 99999), 'filter', 1, day),
          throwsStateError,
        );
        expect(
          () => receiveSupply(household(), 'filter', 0, day),
          throwsStateError,
        );
        expect(() => undoLast(household()), throwsStateError);
      },
    );
    test(
      'names and cadence edits retain ledger snapshots and lossless undo',
      () {
        var data = replaceSlot(household(), 'kitchen', day);
        data = updateSupply(
          data,
          data.supplies.single.copyWith(name: 'Renamed'),
        );
        data = updateSlot(
          data,
          data.slots.single.copyWith(
            name: 'New name',
            units: 1,
            intervalDays: 30,
          ),
        );
        expect(data.events.single.supplyName, 'Carbon refill');
        expect(data.events.single.slotName, 'Kitchen purifier');
        data = undoLast(data);
        expect(data.supplies.single.stock, 3);
        expect(data.slots.single.units, 1);
        expect(data.slots.single.name, 'New name');
        expect(data.slots.single.lastChanged, DateTime.utc(2026, 1, 1));
      },
    );
    test(
      'history cannot be deleted, reassigned, redated or directly change stock',
      () {
        final data = replaceSlot(household(), 'kitchen', day);
        expect(() => deleteSlot(data, 'kitchen'), throwsStateError);
        expect(() => deleteSupply(data, 'filter'), throwsStateError);
        expect(
          () => updateSupply(data, data.supplies.single.copyWith(stock: 5)),
          throwsStateError,
        );
        expect(
          () => updateSlot(
            data,
            data.slots.single.copyWith(
              lastChanged: day.add(const Duration(days: 1)),
            ),
          ),
          throwsStateError,
        );
        final undone = undoLast(data);
        expect(
          deleteSupply(deleteSlot(undone, 'kitchen'), 'filter').supplies,
          isEmpty,
        );
      },
    );
    test('duplicate IDs, invalid references, units and bounds reject', () {
      final data = household();
      expect(() => addSupply(data, data.supplies.single), throwsStateError);
      expect(
        () => addSlot(
          data,
          data.slots.single.copyWith(id: 'other', supplyId: 'missing'),
        ),
        throwsStateError,
      );
      for (final invalid in [0, 101]) {
        expect(
          () => updateSlot(data, data.slots.single.copyWith(units: invalid)),
          throwsStateError,
        );
      }
      expect(
        () => updateSlot(data, data.slots.single.copyWith(intervalDays: 3651)),
        throwsStateError,
      );
      expect(
        () => addSupply(data, const Supply(id: 'x', name: '  ')),
        throwsStateError,
      );
      expect(() => deleteSupply(data, 'missing'), throwsStateError);
    });
  });

  group('bounded backup schema', () {
    test('round trip preserves preferences, snapshots and calendar dates', () {
      final data = replaceSlot(
        receiveSupply(household(), 'filter', 5, day),
        'kitchen',
        day,
      ).copyWith(onboarded: true, language: 'zh', appearance: 'dark');
      expect(
        encodeAppData(decodeAppData(encodeAppData(data))),
        encodeAppData(data),
      );
      expect(
        data.copyWith(clearLanguage: true, clearAppearance: true).language,
        isNull,
      );
      expect(
        data.copyWith(clearLanguage: true, clearAppearance: true).appearance,
        isNull,
      );
    });
    test(
      'malformed, unknown, missing, wrong typed and oversize data reject',
      () {
        expect(() => decodeAppData('{'), throwsStateError);
        final json = household().toJson();
        expect(
          () => AppData.fromJson({...json, 'extra': true}),
          throwsStateError,
        );
        expect(
          () => AppData.fromJson({...json}..remove('events')),
          throwsStateError,
        );
        expect(
          () => AppData.fromJson({...json, 'onboarded': 'true'}),
          throwsStateError,
        );
        expect(
          () => AppData.fromJson({...json, 'schemaVersion': 2}),
          throwsStateError,
        );
        expect(
          () => AppData.fromJson({...json, 'language': 'fr'}),
          throwsStateError,
        );
        expect(
          () => decodeAppData(' ' * (maxBackupBytes + 1)),
          throwsStateError,
        );
        expect(
          () => decodeAppData('中' * (maxBackupBytes ~/ 3 + 1)),
          throwsStateError,
        );
      },
    );
    test(
      'invalid calendar dates, dangling references and tampered snapshots reject',
      () {
        final data = household();
        final json = data.toJson();
        final slot = data.slots.single.toJson();
        expect(
          () => AppData.fromJson({
            ...json,
            'slots': [
              {...slot, 'lastChanged': '2026-02-30'},
            ],
          }),
          throwsStateError,
        );
        expect(
          () => AppData.fromJson({
            ...json,
            'slots': [
              {...slot, 'units': 1.5},
            ],
          }),
          throwsStateError,
        );
        expect(
          () => AppData.fromJson({...json, 'supplies': []}),
          throwsStateError,
        );
        final replaced = replaceSlot(data, 'kitchen', day).toJson();
        final events = replaced['events']! as List;
        expect(
          () => AppData.fromJson({
            ...replaced,
            'events': [
              {...events.single as Map<String, Object?>, 'beforeStock': 90},
            ],
          }),
          throwsStateError,
        );
        final changed =
            jsonDecode(encodeAppData(receiveSupply(data, 'filter', 1, day)))
                as Map<String, dynamic>;
        (changed['supplies'] as List).single['stock'] = 10;
        expect(() => AppData.fromJson(changed), throwsStateError);
      },
    );
    test('all collection caps are enforced without trimming', () {
      final json = AppData().toJson();
      expect(
        () => AppData.fromJson({
          ...json,
          'supplies': List.generate(
            maxSupplies + 1,
            (i) => Supply(id: '$i', name: '$i').toJson(),
          ),
        }),
        throwsStateError,
      );
      expect(
        () =>
            AppData.fromJson({...json, 'slots': List.filled(maxSlots + 1, {})}),
        throwsStateError,
      );
      expect(
        () => AppData.fromJson({
          ...json,
          'events': List.filled(maxEvents + 1, {}),
        }),
        throwsStateError,
      );
    });
  });
}
