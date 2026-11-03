import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:trip_cost/core/domain/core_models.dart';
import 'package:trip_cost/core/domain/repositories.dart';

enum ExpenseExportFormat { csv, pdf }

final class ExpenseExportException implements Exception {
  const ExpenseExportException(this.code);

  static const String empty = 'empty';
  static const String tooLarge = 'too-large';
  static const String unavailable = 'unavailable';

  final String code;
}

abstract interface class DocumentPlatformGateway {
  Future<String> generatePdf(Map<String, Object?> document);

  Future<void> shareFiles(List<String> paths);

  Future<String?> pickBackupFile();
}

final class MethodChannelDocumentPlatformGateway
    implements DocumentPlatformGateway {
  const MethodChannelDocumentPlatformGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('trip_cost/documents');

  final MethodChannel _channel;

  @override
  Future<String> generatePdf(Map<String, Object?> document) async {
    final result = await _channel.invokeMethod<String>('generatePdf', document);
    if (result == null || result.isEmpty) {
      throw const ExpenseExportException(ExpenseExportException.unavailable);
    }
    return result;
  }

  @override
  Future<String?> pickBackupFile() =>
      _channel.invokeMethod<String>('pickBackupFile');

  @override
  Future<void> shareFiles(List<String> paths) => _channel.invokeMethod<void>(
    'shareFiles',
    <String, Object?>{'paths': paths},
  );
}

final class ExpenseExportService {
  ExpenseExportService({
    required ExpenseRepository expenseRepository,
    required DocumentPlatformGateway platformGateway,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
  }) : _expenseRepository = expenseRepository,
       _platformGateway = platformGateway,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const int maximumRows = 20000;

  final ExpenseRepository _expenseRepository;
  final DocumentPlatformGateway _platformGateway;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _clock;

  Future<File> createCsv({required String locale, String? tripId}) async {
    final rows = await _loadRows(tripId: tripId);
    final labels = ExpenseExportLabels.forLocale(locale);
    final contents = ExpenseCsvEncoder().encode(rows, labels: labels);
    final directory = await _temporaryDirectory();
    final file = File(path.join(directory.path, _filename('csv')));
    await file.writeAsBytes(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(contents)]);
    return file;
  }

  Future<File> createPdf({required String locale, String? tripId}) async {
    final rows = await _loadRows(tripId: tripId);
    final labels = ExpenseExportLabels.forLocale(locale);
    final dateLocale = locale.startsWith('zh') ? 'zh' : 'en';
    await initializeDateFormatting(dateLocale);
    final outputPath = await _platformGateway.generatePdf(<String, Object?>{
      'locale': locale.startsWith('zh') ? 'zh-Hans' : 'en',
      'filename': _filename('pdf'),
      'title': labels.title,
      'generatedAt': DateFormat.yMMMd(
        dateLocale,
      ).add_Hm().format(_clock().toLocal()),
      'labels': labels.toJson(),
      'rows': <Map<String, Object?>>[for (final row in rows) row.toJson()],
      'disclaimer': labels.disclaimer,
    });
    return File(outputPath);
  }

  Future<void> share(File file) =>
      _platformGateway.shareFiles(<String>[file.path]);

  Future<List<ExpenseExportRow>> _loadRows({String? tripId}) async {
    final expenses = tripId == null
        ? await _expenseRepository.listActive()
        : await _expenseRepository.listForTrip(tripId);
    if (expenses.isEmpty) {
      throw const ExpenseExportException(ExpenseExportException.empty);
    }
    if (expenses.length > maximumRows) {
      throw const ExpenseExportException(ExpenseExportException.tooLarge);
    }
    final sorted = expenses.toList()
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return <ExpenseExportRow>[
      for (final expense in sorted) ExpenseExportRow.fromExpense(expense),
    ];
  }

  String _filename(String extension) {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(_clock().toLocal());
    return 'rhinosmart-expenses-$stamp.$extension';
  }
}

final class ExpenseExportRow {
  const ExpenseExportRow({
    required this.occurredAt,
    required this.title,
    required this.category,
    required this.transactionAmount,
    required this.transactionCurrency,
    required this.homeCurrency,
    required this.rate,
    required this.rateDate,
    required this.rateSource,
    required this.estimatedAmount,
    required this.actualAmount,
    required this.entryType,
    required this.relatedExpenseId,
  });

  factory ExpenseExportRow.fromExpense(ExpenseModel expense) {
    return ExpenseExportRow(
      occurredAt: expense.occurredAt,
      title: expense.title,
      category: expense.category,
      transactionAmount: expense.transactionAmount.amount.toString(),
      transactionCurrency: expense.transactionAmount.currency.code,
      homeCurrency: expense.referenceAmount.currency.code,
      rate: expense.rateSnapshot.rate.toString(),
      rateDate: expense.rateSnapshot.sourceTimestamp,
      rateSource: expense.rateSnapshot.sourceName,
      estimatedAmount: expense.estimatedFinalAmount.amount.toString(),
      actualAmount: expense.actualFinalAmount?.amount.toString(),
      entryType: expense.entryType.name,
      relatedExpenseId: expense.relatedExpenseId,
    );
  }

  final DateTime occurredAt;
  final String title;
  final String category;
  final String transactionAmount;
  final String transactionCurrency;
  final String homeCurrency;
  final String rate;
  final DateTime rateDate;
  final String rateSource;
  final String estimatedAmount;
  final String? actualAmount;
  final String entryType;
  final String? relatedExpenseId;

  List<String> toCells() => <String>[
    occurredAt.toUtc().toIso8601String(),
    title,
    category,
    transactionAmount,
    transactionCurrency,
    homeCurrency,
    rate,
    rateDate.toUtc().toIso8601String().substring(0, 10),
    rateSource,
    estimatedAmount,
    actualAmount ?? '',
    entryType,
    relatedExpenseId ?? '',
  ];

  Map<String, Object?> toJson() => <String, Object?>{
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'title': title,
    'category': category,
    'transactionAmount': transactionAmount,
    'transactionCurrency': transactionCurrency,
    'homeCurrency': homeCurrency,
    'rate': rate,
    'rateDate': rateDate.toUtc().toIso8601String().substring(0, 10),
    'rateSource': rateSource,
    'estimatedAmount': estimatedAmount,
    'actualAmount': actualAmount,
    'entryType': entryType,
    'relatedExpenseId': relatedExpenseId,
  };
}

final class ExpenseCsvEncoder {
  const ExpenseCsvEncoder();

  String encode(
    List<ExpenseExportRow> rows, {
    required ExpenseExportLabels labels,
  }) {
    final buffer = StringBuffer()
      ..writeln(labels.csvHeaders.map((value) => _escape(value)).join(','));
    for (final row in rows) {
      buffer.writeln(
        row
            .toCells()
            .indexed
            .map(
              (entry) => _escape(
                entry.$2,
                protectFormula: const <int>{1, 2, 8}.contains(entry.$1),
              ),
            )
            .join(','),
      );
    }
    return buffer.toString().replaceAll('\n', '\r\n');
  }

  String _escape(String input, {bool protectFormula = false}) {
    var value = input;
    if (protectFormula && value.isNotEmpty && '=+-@'.contains(value[0])) {
      value = "'$value";
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}

final class ExpenseExportLabels {
  const ExpenseExportLabels({
    required this.title,
    required this.date,
    required this.item,
    required this.category,
    required this.originalAmount,
    required this.originalCurrency,
    required this.homeCurrency,
    required this.rate,
    required this.rateDate,
    required this.source,
    required this.estimated,
    required this.actual,
    required this.type,
    required this.relatedExpense,
    required this.disclaimer,
  });

  factory ExpenseExportLabels.forLocale(String locale) =>
      locale.startsWith('zh') ? _zh : _en;

  final String title;
  final String date;
  final String item;
  final String category;
  final String originalAmount;
  final String originalCurrency;
  final String homeCurrency;
  final String rate;
  final String rateDate;
  final String source;
  final String estimated;
  final String actual;
  final String type;
  final String relatedExpense;
  final String disclaimer;

  List<String> get csvHeaders => <String>[
    date,
    item,
    category,
    originalAmount,
    originalCurrency,
    homeCurrency,
    rate,
    rateDate,
    source,
    estimated,
    actual,
    type,
    relatedExpense,
  ];

  Map<String, Object?> toJson() => <String, Object?>{
    'date': date,
    'item': item,
    'category': category,
    'originalAmount': originalAmount,
    'originalCurrency': originalCurrency,
    'homeCurrency': homeCurrency,
    'rate': rate,
    'rateDate': rateDate,
    'source': source,
    'estimated': estimated,
    'actual': actual,
    'type': type,
    'relatedExpense': relatedExpense,
  };

  static const ExpenseExportLabels _en = ExpenseExportLabels(
    title: 'RhinoSmart expense export',
    date: 'Date',
    item: 'Item',
    category: 'Category',
    originalAmount: 'Original amount',
    originalCurrency: 'Original currency',
    homeCurrency: 'Home currency',
    rate: 'Exchange rate',
    rateDate: 'Rate date',
    source: 'Rate source',
    estimated: 'Estimated amount',
    actual: 'Actual amount',
    type: 'Entry type',
    relatedExpense: 'Related original ID',
    disclaimer:
        'Reference information only. Final posted amounts are determined by the merchant, payment provider, card network, and issuer.',
  );

  static const ExpenseExportLabels _zh = ExpenseExportLabels(
    title: 'RhinoSmart 消费导出',
    date: '消费日期',
    item: '商户或项目',
    category: '分类',
    originalAmount: '原币金额',
    originalCurrency: '原币',
    homeCurrency: '本位币',
    rate: '汇率',
    rateDate: '汇率日期',
    source: '汇率来源',
    estimated: '预计金额',
    actual: '实际入账金额',
    type: '记录类型',
    relatedExpense: '关联原交易 ID',
    disclaimer: '结果仅供参考。实际入账以商户、支付机构、卡组织和发卡行最终处理为准。',
  );
}
