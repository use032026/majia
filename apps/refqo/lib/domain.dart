import 'dart:convert';

const maxBackupBytes = 2 * 1024 * 1024;
const maxSupplies = 200;
const maxSlots = 500;
const maxEvents = 2000;
const schemaVersion = 1;

Never _fail(String code, String message) => throw StateError('$code: $message');

class Supply {
  const Supply({
    required this.id,
    required this.name,
    this.code = '',
    this.notes = '',
    this.stock = 0,
  });
  final String id;
  final String name;
  final String code;
  final String notes;
  final int stock;
  Supply copyWith({
    String? id,
    String? name,
    String? code,
    String? notes,
    int? stock,
  }) => Supply(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    notes: notes ?? this.notes,
    stock: stock ?? this.stock,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'notes': notes,
    'stock': stock,
  };
  factory Supply.fromJson(Object? value) {
    final map = _map(value, {'id', 'name', 'code', 'notes', 'stock'});
    return Supply(
      id: _string(map['id'], 'supply.id', 100, nonempty: true),
      name: _string(map['name'], 'supply.name', 160, nonempty: true),
      code: _string(map['code'], 'supply.code', 160),
      notes: _string(map['notes'], 'supply.notes', 2000),
      stock: _integer(map['stock'], 'supply.stock', 0, 99999),
    );
  }
}

class Slot {
  const Slot({
    required this.id,
    required this.supplyId,
    required this.name,
    required this.intervalDays,
    required this.lastChanged,
    this.verified = false,
    this.units = 1,
  });
  final String id;
  final String supplyId;
  final String name;
  final int intervalDays;
  final DateTime lastChanged;
  final bool verified;
  final int units;
  Slot copyWith({
    String? id,
    String? supplyId,
    String? name,
    int? intervalDays,
    DateTime? lastChanged,
    bool? verified,
    int? units,
  }) => Slot(
    id: id ?? this.id,
    supplyId: supplyId ?? this.supplyId,
    name: name ?? this.name,
    intervalDays: intervalDays ?? this.intervalDays,
    lastChanged: lastChanged ?? this.lastChanged,
    verified: verified ?? this.verified,
    units: units ?? this.units,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'supplyId': supplyId,
    'name': name,
    'intervalDays': intervalDays,
    'lastChanged': _dateString(lastChanged),
    'verified': verified,
    'units': units,
  };
  factory Slot.fromJson(Object? value) {
    final map = _map(value, {
      'id',
      'supplyId',
      'name',
      'intervalDays',
      'lastChanged',
      'verified',
      'units',
    });
    return Slot(
      id: _string(map['id'], 'slot.id', 100, nonempty: true),
      supplyId: _string(map['supplyId'], 'slot.supplyId', 100, nonempty: true),
      name: _string(map['name'], 'slot.name', 160, nonempty: true),
      intervalDays: _integer(map['intervalDays'], 'slot.intervalDays', 1, 3650),
      lastChanged: _parseDate(map['lastChanged']),
      verified: _boolean(map['verified'], 'slot.verified'),
      units: _integer(map['units'], 'slot.units', 1, 100),
    );
  }
}

enum LedgerType { receipt, replacement }

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.supplyId,
    required this.supplyName,
    required this.units,
    required this.createdAt,
    required this.beforeStock,
    required this.afterStock,
    this.slotId,
    this.slotName,
    this.previousLastChanged,
    this.lastChanged,
  });
  final String id;
  final LedgerType type;
  final String supplyId;
  final String supplyName;
  final int units;
  final DateTime createdAt;
  final int beforeStock;
  final int afterStock;
  final String? slotId;
  final String? slotName;
  final DateTime? previousLastChanged;
  final DateTime? lastChanged;
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'supplyId': supplyId,
    'supplyName': supplyName,
    'units': units,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'beforeStock': beforeStock,
    'afterStock': afterStock,
    'slotId': slotId,
    'slotName': slotName,
    'previousLastChanged': previousLastChanged == null
        ? null
        : _dateString(previousLastChanged!),
    'lastChanged': lastChanged == null ? null : _dateString(lastChanged!),
  };
  factory LedgerEntry.fromJson(Object? value) {
    final map = _map(value, {
      'id',
      'type',
      'supplyId',
      'supplyName',
      'units',
      'createdAt',
      'beforeStock',
      'afterStock',
      'slotId',
      'slotName',
      'previousLastChanged',
      'lastChanged',
    });
    final type = switch (map['type']) {
      'receipt' => LedgerType.receipt,
      'replacement' => LedgerType.replacement,
      _ => _fail('INVALID_EVENT', 'Unknown ledger type'),
    };
    return LedgerEntry(
      id: _string(map['id'], 'event.id', 100, nonempty: true),
      type: type,
      supplyId: _string(map['supplyId'], 'event.supplyId', 100, nonempty: true),
      supplyName: _string(
        map['supplyName'],
        'event.supplyName',
        160,
        nonempty: true,
      ),
      units: _integer(map['units'], 'event.units', 1, 99999),
      createdAt: _parseInstant(map['createdAt']),
      beforeStock: _integer(map['beforeStock'], 'event.beforeStock', 0, 99999),
      afterStock: _integer(map['afterStock'], 'event.afterStock', 0, 99999),
      slotId: _nullableString(map['slotId'], 'event.slotId', 100),
      slotName: _nullableString(map['slotName'], 'event.slotName', 160),
      previousLastChanged: map['previousLastChanged'] == null
          ? null
          : _parseDate(map['previousLastChanged']),
      lastChanged: map['lastChanged'] == null
          ? null
          : _parseDate(map['lastChanged']),
    );
  }
}

class AppData {
  AppData({
    List<Supply> supplies = const [],
    List<Slot> slots = const [],
    List<LedgerEntry> events = const [],
    this.onboarded = false,
    this.language,
    this.appearance,
  }) : supplies = List.unmodifiable(supplies),
       slots = List.unmodifiable(slots),
       events = List.unmodifiable(events);
  final List<Supply> supplies;
  final List<Slot> slots;
  final List<LedgerEntry> events;
  final bool onboarded;
  final String? language;
  final String? appearance;
  AppData copyWith({
    List<Supply>? supplies,
    List<Slot>? slots,
    List<LedgerEntry>? events,
    bool? onboarded,
    String? language,
    String? appearance,
    bool clearLanguage = false,
    bool clearAppearance = false,
  }) => AppData(
    supplies: supplies ?? this.supplies,
    slots: slots ?? this.slots,
    events: events ?? this.events,
    onboarded: onboarded ?? this.onboarded,
    language: clearLanguage ? null : language ?? this.language,
    appearance: clearAppearance ? null : appearance ?? this.appearance,
  );
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'supplies': supplies.map((s) => s.toJson()).toList(),
    'slots': slots.map((s) => s.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'onboarded': onboarded,
    'language': language,
    'appearance': appearance,
  };
  factory AppData.fromJson(Object? value) {
    final map = _map(value, {
      'schemaVersion',
      'supplies',
      'slots',
      'events',
      'onboarded',
      'language',
      'appearance',
    });
    _integer(
      map['schemaVersion'],
      'schemaVersion',
      schemaVersion,
      schemaVersion,
    );
    final data = AppData(
      supplies: _list(
        map['supplies'],
        'supplies',
        maxSupplies,
      ).map(Supply.fromJson).toList(),
      slots: _list(map['slots'], 'slots', maxSlots).map(Slot.fromJson).toList(),
      events: _list(
        map['events'],
        'events',
        maxEvents,
      ).map(LedgerEntry.fromJson).toList(),
      onboarded: _boolean(map['onboarded'], 'onboarded'),
      language: _choice(map['language'], 'language', {'en', 'zh'}),
      appearance: _choice(map['appearance'], 'appearance', {'light', 'dark'}),
    );
    validateAppData(data);
    return data;
  }
}

AppData decodeAppData(String source) {
  if (utf8.encode(source).length > maxBackupBytes) {
    _fail('FILE_TOO_LARGE', 'Backup exceeds 2 MB');
  }
  try {
    return AppData.fromJson(jsonDecode(source));
  } on FormatException {
    _fail('INVALID_JSON', 'Backup is not valid JSON');
  }
}

String encodeAppData(AppData data) {
  validateAppData(data);
  final text = jsonEncode(data.toJson());
  if (utf8.encode(text).length > maxBackupBytes) {
    _fail('FILE_TOO_LARGE', 'Backup exceeds 2 MB');
  }
  return text;
}

void validateAppData(AppData data) {
  if (data.supplies.length > maxSupplies ||
      data.slots.length > maxSlots ||
      data.events.length > maxEvents) {
    _fail('CAPACITY', 'Data exceeds collection limits');
  }
  _choice(data.language, 'language', {'en', 'zh'});
  _choice(data.appearance, 'appearance', {'light', 'dark'});
  final supplies = <String, Supply>{};
  for (final supply in data.supplies) {
    Supply.fromJson(supply.toJson());
    if (supplies.containsKey(supply.id)) {
      _fail('DUPLICATE_ID', 'Duplicate supply');
    }
    supplies[supply.id] = supply;
  }
  final slots = <String, Slot>{};
  for (final slot in data.slots) {
    Slot.fromJson(slot.toJson());
    if (slots.containsKey(slot.id)) _fail('DUPLICATE_ID', 'Duplicate slot');
    if (!supplies.containsKey(slot.supplyId)) {
      _fail('INVALID_REFERENCE', 'Slot supply is missing');
    }
    slots[slot.id] = slot;
  }
  final eventIds = <String>{};
  final lastStock = <String, int>{};
  final lastDate = <String, DateTime>{};
  for (final event in data.events) {
    LedgerEntry.fromJson(event.toJson());
    if (!eventIds.add(event.id)) _fail('DUPLICATE_ID', 'Duplicate event');
    if (!supplies.containsKey(event.supplyId)) {
      _fail('INVALID_REFERENCE', 'Event supply is missing');
    }
    if (lastStock.containsKey(event.supplyId) &&
        lastStock[event.supplyId] != event.beforeStock) {
      _fail('INVALID_LEDGER', 'Stock history is discontinuous');
    }
    if (event.type == LedgerType.receipt) {
      if (event.afterStock != event.beforeStock + event.units ||
          event.slotId != null ||
          event.slotName != null ||
          event.previousLastChanged != null ||
          event.lastChanged != null) {
        _fail('INVALID_LEDGER', 'Invalid receipt snapshot');
      }
    } else {
      final slot = slots[event.slotId];
      if (slot == null ||
          slot.supplyId != event.supplyId ||
          event.slotName == null ||
          event.previousLastChanged == null ||
          event.lastChanged == null ||
          event.units > 100 ||
          event.afterStock != event.beforeStock - event.units) {
        _fail('INVALID_LEDGER', 'Invalid replacement snapshot');
      }
      if (lastDate.containsKey(event.slotId) &&
          !_sameDay(lastDate[event.slotId]!, event.previousLastChanged!)) {
        _fail('INVALID_LEDGER', 'Replacement history is discontinuous');
      }
      lastDate[event.slotId!] = event.lastChanged!;
    }
    lastStock[event.supplyId] = event.afterStock;
  }
  for (final entry in lastStock.entries) {
    if (supplies[entry.key]!.stock != entry.value) {
      _fail('INVALID_LEDGER', 'Current stock differs from history');
    }
  }
  for (final entry in lastDate.entries) {
    if (!_sameDay(slots[entry.key]!.lastChanged, entry.value)) {
      _fail('INVALID_LEDGER', 'Current installation differs from history');
    }
  }
}

class ForecastSlot {
  const ForecastSlot({
    required this.slot,
    required this.occurrences,
    required this.firstDue,
    required this.overdue,
  });
  final Slot slot;
  final int occurrences;
  final DateTime firstDue;
  final bool overdue;
  int get demand => occurrences * slot.units;
}

class SupplyForecast {
  SupplyForecast({
    required this.supply,
    required this.demand,
    required List<ForecastSlot> slots,
  }) : slots = List.unmodifiable(slots);
  final Supply supply;
  final int demand;
  final List<ForecastSlot> slots;
  int get stock => supply.stock;
  int get gap => demand > stock ? demand - stock : 0;
  int get overdueCount => slots.where((s) => s.overdue).length;
}

/// Includes both today and the calendar day [horizonDays] days from today.
/// An overdue slot needs one set today, followed by its cadence from today.
List<SupplyForecast> forecast(AppData data, DateTime now, int horizonDays) {
  _integer(horizonDays, 'horizonDays', 0, 3650);
  validateAppData(data);
  final today = calendarDay(now);
  final end = today.add(Duration(days: horizonDays));
  return List.unmodifiable(
    data.supplies.map((supply) {
      final slots = data.slots.where((s) => s.supplyId == supply.id).map((
        slot,
      ) {
        final scheduled = calendarDay(
          slot.lastChanged,
        ).add(Duration(days: slot.intervalDays));
        final overdue = scheduled.isBefore(today);
        final first = overdue ? today : scheduled;
        final count = first.isAfter(end)
            ? 0
            : end.difference(first).inDays ~/ slot.intervalDays + 1;
        return ForecastSlot(
          slot: slot,
          occurrences: count,
          firstDue: first,
          overdue: overdue,
        );
      }).toList();
      return SupplyForecast(
        supply: supply,
        demand: slots.fold(0, (sum, slot) => sum + slot.demand),
        slots: slots,
      );
    }),
  );
}

DateTime calendarDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
bool _sameDay(DateTime a, DateTime b) => calendarDay(a) == calendarDay(b);
Supply _supply(AppData data, String id) =>
    data.supplies.where((s) => s.id == id).firstOrNull ??
    _fail('NOT_FOUND', 'Supply not found');
Slot _slot(AppData data, String id) =>
    data.slots.where((s) => s.id == id).firstOrNull ??
    _fail('NOT_FOUND', 'Slot not found');
AppData _checked(AppData data) {
  validateAppData(data);
  return data;
}

AppData addSupply(AppData data, Supply supply) =>
    _checked(data.copyWith(supplies: [...data.supplies, supply]));
AppData updateSupply(AppData data, Supply supply) {
  final current = _supply(data, supply.id);
  if (current.stock != supply.stock) {
    _fail('STOCK_LOCKED', 'Change stock through receipt or replacement');
  }
  return _checked(
    data.copyWith(
      supplies: [
        for (final item in data.supplies)
          if (item.id == supply.id) supply else item,
      ],
    ),
  );
}

AppData addSlot(AppData data, Slot slot) =>
    _checked(data.copyWith(slots: [...data.slots, slot]));
AppData updateSlot(AppData data, Slot slot) {
  final current = _slot(data, slot.id);
  if (data.events.any((e) => e.slotId == slot.id) &&
      (current.supplyId != slot.supplyId ||
          !_sameDay(current.lastChanged, slot.lastChanged))) {
    _fail(
      'HISTORY_LOCKED',
      'Recorded installations cannot be reassigned or redated',
    );
  }
  return _checked(
    data.copyWith(
      slots: [
        for (final item in data.slots)
          if (item.id == slot.id) slot else item,
      ],
    ),
  );
}

String _eventId(AppData data, DateTime now) {
  var suffix = data.events.length;
  var id = 'event_${now.microsecondsSinceEpoch}_$suffix';
  while (data.events.any((e) => e.id == id)) {
    suffix++;
    id = 'event_${now.microsecondsSinceEpoch}_$suffix';
  }
  return id;
}

AppData receiveSupply(AppData data, String supplyId, int units, DateTime now) {
  _integer(units, 'receipt.units', 1, 99999);
  final supply = _supply(data, supplyId);
  final nextStock = supply.stock + units;
  _integer(nextStock, 'supply.stock', 0, 99999);
  final event = LedgerEntry(
    id: _eventId(data, now),
    type: LedgerType.receipt,
    supplyId: supply.id,
    supplyName: supply.name,
    units: units,
    createdAt: now,
    beforeStock: supply.stock,
    afterStock: nextStock,
  );
  return _checked(
    data.copyWith(
      supplies: [
        for (final item in data.supplies)
          if (item.id == supply.id) supply.copyWith(stock: nextStock) else item,
      ],
      events: [...data.events, event],
    ),
  );
}

AppData replaceSlot(AppData data, String slotId, DateTime now) {
  final slot = _slot(data, slotId);
  final supply = _supply(data, slot.supplyId);
  if (!slot.verified) {
    _fail('FIT_UNCONFIRMED', 'Confirm manual compatibility before replacing');
  }
  if (calendarDay(now).isBefore(calendarDay(slot.lastChanged))) {
    _fail('INVALID_DATE', 'Replacement cannot precede installation');
  }
  if (supply.stock < slot.units) {
    _fail('INSUFFICIENT_STOCK', 'Stock is below the required quantity');
  }
  final nextStock = supply.stock - slot.units;
  final nextDate = calendarDay(now);
  final event = LedgerEntry(
    id: _eventId(data, now),
    type: LedgerType.replacement,
    supplyId: supply.id,
    supplyName: supply.name,
    units: slot.units,
    createdAt: now,
    beforeStock: supply.stock,
    afterStock: nextStock,
    slotId: slot.id,
    slotName: slot.name,
    previousLastChanged: calendarDay(slot.lastChanged),
    lastChanged: nextDate,
  );
  return _checked(
    data.copyWith(
      supplies: [
        for (final item in data.supplies)
          if (item.id == supply.id) supply.copyWith(stock: nextStock) else item,
      ],
      slots: [
        for (final item in data.slots)
          if (item.id == slot.id)
            slot.copyWith(lastChanged: nextDate)
          else
            item,
      ],
      events: [...data.events, event],
    ),
  );
}

AppData undoLast(AppData data) {
  if (data.events.isEmpty) _fail('NO_HISTORY', 'There is no event to undo');
  validateAppData(data);
  final event = data.events.last;
  final supply = _supply(data, event.supplyId);
  return _checked(
    data.copyWith(
      supplies: [
        for (final item in data.supplies)
          if (item.id == supply.id)
            supply.copyWith(stock: event.beforeStock)
          else
            item,
      ],
      slots: [
        for (final item in data.slots)
          if (item.id == event.slotId)
            item.copyWith(lastChanged: event.previousLastChanged!)
          else
            item,
      ],
      events: data.events.sublist(0, data.events.length - 1),
    ),
  );
}

AppData deleteSlot(AppData data, String slotId) {
  _slot(data, slotId);
  if (data.events.any((e) => e.slotId == slotId)) {
    _fail(
      'HISTORY_LOCKED',
      'Undo related replacements before deleting this appliance',
    );
  }
  return _checked(
    data.copyWith(slots: data.slots.where((s) => s.id != slotId).toList()),
  );
}

AppData deleteSupply(AppData data, String supplyId) {
  _supply(data, supplyId);
  if (data.slots.any((s) => s.supplyId == supplyId)) {
    _fail('LINKED_APPLIANCES', 'Remove linked appliances first');
  }
  if (data.events.any((e) => e.supplyId == supplyId)) {
    _fail('HISTORY_LOCKED', 'Undo related events before deleting this supply');
  }
  return _checked(
    data.copyWith(
      supplies: data.supplies.where((s) => s.id != supplyId).toList(),
    ),
  );
}

Map<String, Object?> _map(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      value.keys.any((key) => !keys.contains(key))) {
    _fail('INVALID_SCHEMA', 'Unexpected or missing object fields');
  }
  return value;
}

List<Object?> _list(Object? value, String name, int max) {
  if (value is! List || value.length > max) {
    _fail('INVALID_SCHEMA', '$name must be a bounded array');
  }
  return value;
}

String _string(Object? value, String name, int max, {bool nonempty = false}) {
  if (value is! String ||
      value.length > max ||
      (nonempty && value.trim().isEmpty) ||
      value.contains('\u0000')) {
    _fail('INVALID_VALUE', '$name has an invalid text value');
  }
  return value;
}

String? _nullableString(Object? value, String name, int max) =>
    value == null ? null : _string(value, name, max, nonempty: true);
int _integer(Object? value, String name, int min, int max) {
  if (value is! int || value < min || value > max) {
    _fail('INVALID_VALUE', '$name must be an integer from $min to $max');
  }
  return value;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) _fail('INVALID_VALUE', '$name must be boolean');
  return value;
}

String? _choice(Object? value, String name, Set<String> values) {
  if (value == null) return null;
  if (value is! String || !values.contains(value)) {
    _fail('INVALID_VALUE', '$name is unsupported');
  }
  return value;
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime _parseDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    _fail('INVALID_DATE', 'Expected a calendar date');
  }
  final result = DateTime.tryParse('${value}T00:00:00.000Z');
  if (result == null || result.year < 1 || _dateString(result) != value) {
    _fail('INVALID_DATE', 'Invalid calendar date');
  }
  return result;
}

DateTime _parseInstant(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
      ).hasMatch(value)) {
    _fail('INVALID_DATE', 'Expected a UTC timestamp');
  }
  _parseDate(value.substring(0, 10));
  final result = DateTime.tryParse(value);
  if (result == null ||
      int.parse(value.substring(11, 13)) > 23 ||
      int.parse(value.substring(14, 16)) > 59 ||
      int.parse(value.substring(17, 19)) > 59) {
    _fail('INVALID_DATE', 'Invalid timestamp');
  }
  return result;
}
