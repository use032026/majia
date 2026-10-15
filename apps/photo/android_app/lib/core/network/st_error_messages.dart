import 'package:dio/dio.dart';

final String stDefaultLoadErrorText = '加载失败，请稍后重试';
final String stDefaultActionErrorText = '操作失败，请稍后重试';
final String stTimeoutErrorText = '请求超时，请先检查网络环境，然后在设置页切换可用线路';
final String stConnectionErrorText = '网络异常，请检查网络连接';
final String stServerErrorText = '服务暂时不可用，请稍后再试';

String stUserVisibleErrorMessage(Object? error, {String? fallback}) {
  final effectiveFallback = fallback ?? stDefaultLoadErrorText;
  if (error == null) return effectiveFallback;
  if (error is DioException) {
    return _messageForDioException(error, effectiveFallback);
  }
  return stSanitizeUserVisibleText(
    error.toString(),
    fallback: effectiveFallback,
  );
}

String stSanitizeUserVisibleText(String message, {String? fallback}) {
  final effectiveFallback = fallback ?? stDefaultActionErrorText;
  final text = message.trim();
  if (text.isEmpty) return effectiveFallback;

  const exceptionPrefix = 'Exception: ';
  if (text.startsWith(exceptionPrefix)) {
    return stSanitizeUserVisibleText(
      text.substring(exceptionPrefix.length),
      fallback: effectiveFallback,
    );
  }

  final dioMatch = RegExp(
    r'dio(?:exception|error)',
    caseSensitive: false,
  ).firstMatch(text);
  if (dioMatch != null) {
    final dioIndex = dioMatch.start;
    final prefix = text
        .substring(0, dioIndex)
        .replaceFirst(RegExp(r'[\s:：]+$'), '')
        .trim();
    final sanitized = _messageForDioText(
      text.substring(dioIndex),
      effectiveFallback,
    );
    return prefix.isEmpty ? sanitized : '$prefix：$sanitized';
  }

  if (_looksLikeDioInternals(text)) {
    return _messageForDioText(text, effectiveFallback);
  }

  return text;
}

String _messageForDioException(DioException error, String fallback) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return stTimeoutErrorText;
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return stConnectionErrorText;
    case DioExceptionType.badResponse:
      final responseMessage = _responseMessage(error.response?.data);
      if (responseMessage != null) {
        return stSanitizeUserVisibleText(responseMessage, fallback: fallback);
      }
      final statusCode = error.response?.statusCode;
      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return stServerErrorText;
      }
      return fallback;
    case DioExceptionType.cancel:
      return fallback;
    case DioExceptionType.unknown:
      return _looksLikeDioInternals(error.message ?? '')
          ? _messageForDioText(error.message!, fallback)
          : fallback;
  }
}

String _messageForDioText(String text, String fallback) {
  final lower = text.toLowerCase();
  if (lower.contains('timeout') ||
      lower.contains('receivetimeout') ||
      lower.contains('sendtimeout') ||
      lower.contains('connectiontimeout')) {
    return stTimeoutErrorText;
  }
  if (lower.contains('connection error') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('bad certificate')) {
    return stConnectionErrorText;
  }
  if (lower.contains('503') || lower.contains('502') || lower.contains('504')) {
    return stServerErrorText;
  }
  return fallback;
}

bool _looksLikeDioInternals(String text) {
  final lower = text.toLowerCase();
  return lower.contains('requestoptions.') ||
      lower.contains('receivetimeout') ||
      lower.contains('connecttimeout') ||
      lower.contains('sendtimeout') ||
      lower.contains('the request took longer') ||
      lower.contains('dioexception') ||
      lower.contains('dioerror');
}

String? _responseMessage(Object? data) {
  if (data is Map) {
    final message = data['message'] ?? data['msg'] ?? data['error'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString().trim();
    }
  }
  return null;
}
