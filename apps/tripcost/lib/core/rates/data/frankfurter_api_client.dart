import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:trip_cost/core/rates/data/frankfurter_dtos.dart';

enum FrankfurterErrorCode {
  invalidRequest,
  notFound,
  unavailable,
  timeout,
  network,
  malformedResponse,
  unexpectedStatus,
}

final class FrankfurterApiException implements Exception {
  const FrankfurterApiException(this.code, {this.statusCode});

  final FrankfurterErrorCode code;
  final int? statusCode;

  @override
  String toString() => 'FrankfurterApiException($code, status: $statusCode)';
}

final class FrankfurterHttpResponse {
  const FrankfurterHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract interface class FrankfurterHttpTransport {
  Future<FrankfurterHttpResponse> get(Uri uri, {required Duration timeout});
}

final class IoFrankfurterHttpTransport implements FrankfurterHttpTransport {
  IoFrankfurterHttpTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<FrankfurterHttpResponse> get(
    Uri uri, {
    required Duration timeout,
  }) async {
    try {
      final request = await _client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'RhinoSmart/1.0 Frankfurter-v2-client',
      );
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return FrankfurterHttpResponse(
        statusCode: response.statusCode,
        body: body,
      );
    } on TimeoutException {
      throw const FrankfurterApiException(FrankfurterErrorCode.timeout);
    } on SocketException {
      throw const FrankfurterApiException(FrankfurterErrorCode.network);
    } on HttpException {
      throw const FrankfurterApiException(FrankfurterErrorCode.network);
    }
  }
}

abstract interface class FrankfurterRatesGateway {
  Future<List<FrankfurterCurrencyDto>> getCurrencies();

  Future<List<FrankfurterRateDto>> getRates({
    required String baseCurrencyCode,
    required Iterable<String> quoteCurrencyCodes,
    DateTime? date,
  });

  Future<FrankfurterRateDto> getRate({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
    DateTime? date,
  });
}

typedef FrankfurterLogSink = void Function(String message);

final class FrankfurterApiClient implements FrankfurterRatesGateway {
  FrankfurterApiClient({
    FrankfurterHttpTransport? transport,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 10),
    FrankfurterLogSink? log,
  }) : _transport = transport ?? IoFrankfurterHttpTransport(),
       _baseUri = baseUri ?? Uri.parse('https://api.frankfurter.dev/v2/'),
       _log = log;

  final FrankfurterHttpTransport _transport;
  final Uri _baseUri;
  final Duration timeout;
  final FrankfurterLogSink? _log;
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  @override
  Future<List<FrankfurterCurrencyDto>> getCurrencies() {
    final uri = _resolve('currencies');
    return _deduplicate<List<FrankfurterCurrencyDto>>(
      'currencies:${uri.toString()}',
      () async =>
          _decodeList(await _getJson(uri), FrankfurterCurrencyDto.fromJson),
    );
  }

  @override
  Future<List<FrankfurterRateDto>> getRates({
    required String baseCurrencyCode,
    required Iterable<String> quoteCurrencyCodes,
    DateTime? date,
  }) {
    final base = _currencyCode(baseCurrencyCode);
    final quotes =
        quoteCurrencyCodes.map(_currencyCode).toSet().toList(growable: false)
          ..sort();
    if (quotes.isEmpty) {
      throw const FormatException('At least one quote currency is required.');
    }
    final parameters = <String, String>{
      'base': base,
      'quotes': quotes.join(','),
      if (date != null) 'date': _formatDate(date),
    };
    final uri = _resolve('rates').replace(queryParameters: parameters);
    return _deduplicate<List<FrankfurterRateDto>>(
      'rates:${uri.toString()}',
      () async => _decodeList(await _getJson(uri), FrankfurterRateDto.fromJson),
    );
  }

  @override
  Future<FrankfurterRateDto> getRate({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
    DateTime? date,
  }) {
    final base = _currencyCode(baseCurrencyCode);
    final quote = _currencyCode(quoteCurrencyCode);
    final uri = _resolve('rate/$base/$quote').replace(
      queryParameters: date == null
          ? null
          : <String, String>{'date': _formatDate(date)},
    );
    return _deduplicate<FrankfurterRateDto>(
      'rate:${uri.toString()}',
      () async => FrankfurterRateDto.fromJson(_asObject(await _getJson(uri))),
    );
  }

  Future<Object?> _getJson(Uri uri) async {
    FrankfurterHttpResponse response;
    try {
      response = await _transport.get(uri, timeout: timeout);
    } on FrankfurterApiException {
      rethrow;
    } on TimeoutException {
      throw const FrankfurterApiException(FrankfurterErrorCode.timeout);
    } on Exception {
      throw const FrankfurterApiException(FrankfurterErrorCode.network);
    }
    _log?.call(
      'Frankfurter GET ${uri.scheme}://${uri.authority}${uri.path} '
      'status=${response.statusCode}',
    );
    if (response.statusCode != HttpStatus.ok) {
      throw FrankfurterApiException(switch (response.statusCode) {
        HttpStatus.unprocessableEntity => FrankfurterErrorCode.invalidRequest,
        HttpStatus.notFound => FrankfurterErrorCode.notFound,
        HttpStatus.serviceUnavailable => FrankfurterErrorCode.unavailable,
        _ => FrankfurterErrorCode.unexpectedStatus,
      }, statusCode: response.statusCode);
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const FrankfurterApiException(
        FrankfurterErrorCode.malformedResponse,
      );
    }
  }

  List<T> _decodeList<T>(
    Object? value,
    T Function(Map<String, Object?> json) decode,
  ) {
    if (value is! List<Object?>) {
      throw const FrankfurterApiException(
        FrankfurterErrorCode.malformedResponse,
      );
    }
    try {
      return <T>[for (final item in value) decode(_asObject(item))];
    } on FormatException {
      throw const FrankfurterApiException(
        FrankfurterErrorCode.malformedResponse,
      );
    }
  }

  Map<String, Object?> _asObject(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FrankfurterApiException(
        FrankfurterErrorCode.malformedResponse,
      );
    }
    return value;
  }

  Future<T> _deduplicate<T>(String key, Future<T> Function() operation) {
    final existing = _inFlight[key];
    if (existing != null) {
      return existing.then((value) => value as T);
    }
    final future = operation();
    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });
  }

  Uri _resolve(String path) => _baseUri.resolve(path);
}

String _currencyCode(String value) {
  final normalized = value.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
    throw FormatException('Invalid ISO 4217 code: $value');
  }
  return normalized;
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
