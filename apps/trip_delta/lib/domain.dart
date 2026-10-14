import 'dart:math' as math;

enum TripStage { draft, active, completed }

enum BudgetCategory { stay, transport, food, experiences, other }

const supportedCurrencies = ['CNY', 'USD', 'EUR', 'JPY', 'GBP'];

int currencyDigits(String currency) => currency == 'JPY' ? 0 : 2;

int? parseMinor(String raw, String currency) {
  final value = raw.trim();
  final digits = currencyDigits(currency);
  final pattern = digits == 0
      ? RegExp(r'^\d{1,7}$')
      : RegExp(r'^\d{1,7}(?:\.\d{1,2})?$');
  if (!pattern.hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = int.parse(parts.first);
  final fraction = digits == 0
      ? 0
      : int.parse((parts.length == 2 ? parts[1] : '').padRight(2, '0'));
  final result = whole * (digits == 0 ? 1 : 100) + fraction;
  final maximum = 1000000 * (digits == 0 ? 1 : 100);
  return result <= maximum ? result : null;
}

double? parseRate(String raw) {
  final value = raw.trim();
  if (!RegExp(r'^\d{1,4}(?:\.\d{1,6})?$').hasMatch(value)) return null;
  final result = double.tryParse(value);
  if (result == null || result <= 0 || result > 1000) return null;
  return result;
}

int convertMinor({
  required int sourceMinor,
  required String sourceCurrency,
  required String baseCurrency,
  required double rate,
}) {
  if (sourceMinor < 0 || !rate.isFinite || rate <= 0) {
    throw ArgumentError('Invalid amount or rate');
  }
  if (sourceCurrency == baseCurrency) return sourceMinor;
  final sourceScale = math.pow(10, currencyDigits(sourceCurrency)).toInt();
  final baseScale = math.pow(10, currencyDigits(baseCurrency)).toInt();
  // Accepted rates have at most six decimal places. Convert to an integer
  // ratio before multiplication so half-cent boundaries round consistently.
  final rateMicros = (rate * 1000000).round();
  final numerator =
      BigInt.from(sourceMinor) *
      BigInt.from(rateMicros) *
      BigInt.from(baseScale);
  final denominator = BigInt.from(sourceScale * 1000000);
  return ((numerator * BigInt.two + denominator) ~/ (denominator * BigInt.two))
      .toInt();
}

String moneyText(int minor, String currency) {
  final negative = minor < 0 ? '-' : '';
  final absolute = minor.abs();
  if (currencyDigits(currency) == 0) return '$negative$currency $absolute';
  final whole = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  return '$negative$currency $whole.$cents';
}

T _enumByName<T extends Enum>(List<T> values, Object? name) {
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => throw FormatException('Invalid enum value: $name'),
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid object');
  }
  return value;
}

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.rate,
    required this.bookedMinor,
    required this.recordedAt,
    this.note = '',
    this.settledMinor,
    this.rateObservedAt,
  });

  final String id;
  final String title;
  final BudgetCategory category;
  final int amountMinor;
  final String currency;
  final double rate;
  final int bookedMinor;
  final DateTime recordedAt;
  final String note;
  final int? settledMinor;
  final DateTime? rateObservedAt;
  int get effectiveMinor => settledMinor ?? bookedMinor;
  bool get isEstimate => settledMinor == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'amountMinor': amountMinor,
    'currency': currency,
    'rate': rate,
    'bookedMinor': bookedMinor,
    'recordedAt': recordedAt.toIso8601String(),
    'note': note,
    'settledMinor': settledMinor,
    'rateObservedAt': rateObservedAt?.toIso8601String(),
  };

  factory Expense.fromJson(Object? value, {String? baseCurrency}) {
    final json = _object(value);
    final currency = json['currency'] as String;
    if (!supportedCurrencies.contains(currency)) {
      throw const FormatException('Currency');
    }
    final amount = json['amountMinor'] as int;
    final booked = json['bookedMinor'] as int;
    final rate = (json['rate'] as num).toDouble();
    final settled = json['settledMinor'] as int?;
    if (amount <= 0 ||
        booked <= 0 ||
        (settled != null && settled <= 0) ||
        !rate.isFinite ||
        rate <= 0) {
      throw const FormatException('Expense values');
    }
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      category: _enumByName(BudgetCategory.values, json['category']),
      amountMinor: amount,
      currency: currency,
      rate: rate,
      bookedMinor: booked,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      note: json['note'] as String? ?? '',
      settledMinor: settled ?? (currency == baseCurrency ? booked : null),
      rateObservedAt: json['rateObservedAt'] == null
          ? null
          : DateTime.parse(json['rateObservedAt'] as String),
    );
  }
}

class Trip {
  const Trip({
    required this.id,
    required this.title,
    required this.baseCurrency,
    required this.budgets,
    required this.stage,
    required this.createdAt,
    required this.expenses,
    this.startedAt,
    this.completedAt,
    this.reflection = '',
    this.destination = '',
    this.localCurrency,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String title;
  final String baseCurrency;
  final Map<BudgetCategory, int> budgets;
  final TripStage stage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<Expense> expenses;
  final String reflection;
  final String destination;
  final String? localCurrency;
  final DateTime? startDate;
  final DateTime? endDate;

  String get entryCurrency => localCurrency ?? baseCurrency;
  int get estimatedCount => expenses.where((item) => item.isEstimate).length;
  bool get canComplete => expenses.isNotEmpty && estimatedCount == 0;
  int get remainingMinor => plannedMinor - spentMinor;
  int daysRemaining(DateTime now) {
    if (startDate == null || endDate == null) return 0;
    final today = DateTime.utc(now.year, now.month, now.day);
    final first = DateTime.utc(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );
    final last = DateTime.utc(endDate!.year, endDate!.month, endDate!.day);
    final from = today.isAfter(first) ? today : first;
    return math.max(0, last.difference(from).inDays + 1);
  }

  int? dailyAvailableMinor(DateTime now) {
    final days = daysRemaining(now);
    return days == 0 ? null : math.max(0, remainingMinor) ~/ days;
  }

  int get plannedMinor => budgets.values.fold(0, (sum, amount) => sum + amount);
  int get spentMinor =>
      expenses.fold(0, (sum, item) => sum + item.effectiveMinor);
  int get deltaMinor => spentMinor - plannedMinor;
  int plannedFor(BudgetCategory category) => budgets[category] ?? 0;
  int spentFor(BudgetCategory category) => expenses
      .where((item) => item.category == category)
      .fold(0, (sum, item) => sum + item.effectiveMinor);
  int deltaFor(BudgetCategory category) =>
      spentFor(category) - plannedFor(category);

  Trip copyWith({
    String? title,
    String? baseCurrency,
    Map<BudgetCategory, int>? budgets,
    TripStage? stage,
    List<Expense>? expenses,
    DateTime? startedAt,
    DateTime? completedAt,
    String? reflection,
    String? destination,
    String? localCurrency,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartedAt = false,
  }) => Trip(
    id: id,
    title: title ?? this.title,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    budgets: budgets ?? this.budgets,
    stage: stage ?? this.stage,
    createdAt: createdAt,
    startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    expenses: expenses ?? this.expenses,
    reflection: reflection ?? this.reflection,
    destination: destination ?? this.destination,
    localCurrency: localCurrency ?? this.localCurrency,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'baseCurrency': baseCurrency,
    'budgets': {for (final item in budgets.entries) item.key.name: item.value},
    'stage': stage.name,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'reflection': reflection,
    'destination': destination,
    'localCurrency': localCurrency,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  factory Trip.fromJson(Object? value) {
    final json = _object(value);
    final currency = json['baseCurrency'] as String;
    if (!supportedCurrencies.contains(currency)) {
      throw const FormatException('Currency');
    }
    final rawBudgets = _object(json['budgets']);
    final budgets = {
      for (final category in BudgetCategory.values)
        category: rawBudgets[category.name] as int,
    };
    if (budgets.values.any((amount) => amount < 0)) {
      throw const FormatException('Negative budget');
    }
    final localCurrency = json['localCurrency'] as String?;
    if (localCurrency != null && !supportedCurrencies.contains(localCurrency)) {
      throw const FormatException('Local currency');
    }
    final startDate = json['startDate'] == null
        ? null
        : DateTime.parse(json['startDate'] as String);
    final endDate = json['endDate'] == null
        ? null
        : DateTime.parse(json['endDate'] as String);
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw const FormatException('Trip dates');
    }
    return Trip(
      id: json['id'] as String,
      title: json['title'] as String,
      baseCurrency: currency,
      budgets: budgets,
      stage: _enumByName(TripStage.values, json['stage']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      expenses: (json['expenses'] as List)
          .map((value) => Expense.fromJson(value, baseCurrency: currency))
          .toList(),
      reflection: json['reflection'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      localCurrency: localCurrency,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

enum ReviewBand {
  atMost30,
  atMost60,
  atMost90,
  atMost100,
  overAtMost50,
  overAtMost100,
  overMoreThan100,
}

ReviewBand? reviewBandFor(Trip trip) {
  if (!trip.canComplete || trip.plannedMinor <= 0) return null;
  final planned = trip.plannedMinor;
  final spent = trip.spentMinor;
  if (spent * 100 <= planned * 30) return ReviewBand.atMost30;
  if (spent * 100 <= planned * 60) return ReviewBand.atMost60;
  if (spent * 100 <= planned * 90) return ReviewBand.atMost90;
  if (spent <= planned) return ReviewBand.atMost100;
  final over = spent - planned;
  if (over * 100 <= planned * 50) return ReviewBand.overAtMost50;
  if (over <= planned) return ReviewBand.overAtMost100;
  return ReviewBand.overMoreThan100;
}

List<Expense> filterTripExpenses(
  Trip trip, {
  BudgetCategory? category,
  DateTime? startDate,
  DateTime? endDate,
}) {
  DateTime day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
  final first = startDate == null ? null : day(startDate);
  final last = endDate == null ? null : day(endDate);
  return trip.expenses.reversed.where((expense) {
    if (category != null && expense.category != category) return false;
    final date = day(expense.recordedAt);
    if (first != null && date.isBefore(first)) return false;
    if (last != null && date.isAfter(last)) return false;
    return true;
  }).toList();
}

class AppData {
  const AppData({this.trips = const [], this.language = 'auto'});
  final List<Trip> trips;
  final String language;

  AppData copyWith({List<Trip>? trips, String? language}) =>
      AppData(trips: trips ?? this.trips, language: language ?? this.language);

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'language': language,
    'trips': trips.map((trip) => trip.toJson()).toList(),
  };

  factory AppData.fromJson(Object? value) {
    final json = _object(value);
    if (json['schemaVersion'] != 1 && json['schemaVersion'] != 2) {
      throw const FormatException('Unsupported data version');
    }
    final language = json['language'] as String? ?? 'auto';
    if (!['auto', 'zh', 'en'].contains(language)) {
      throw const FormatException('Language');
    }
    return AppData(
      language: language,
      trips: (json['trips'] as List).map(Trip.fromJson).toList(),
    );
  }
}
