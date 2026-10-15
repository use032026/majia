import '../../core/network/st_error_messages.dart';

abstract final class AuthApiHelpers {
  static const requestFailedFallback = '数据加载失败';

  static bool responseOk(Map<String, dynamic> raw) {
    final c = raw['code'];
    return c == 0 ||
        c == '0' ||
        c == 200 ||
        (c is num && (c == 0 || c == 200));
  }

  static void ensureOk(Map<String, dynamic> raw) {
    if (responseOk(raw)) return;
    throw Exception(raw['message']?.toString() ?? requestFailedFallback);
  }

  /// 展开业务 data（兼容根级混排 token）
  static Map<String, dynamic> unwrapLoginPayload(Map<String, dynamic> raw) {
    final inner = raw['data'];
    if (inner is Map<String, dynamic>) {
      return Map<String, dynamic>.from(inner);
    }
    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }
    return Map<String, dynamic>.from(raw);
  }

  static String userVisibleErrorSeed(Object error) {
    final message = stUserVisibleErrorMessage(
      error,
      fallback: requestFailedFallback,
    );
    if (message == stDefaultLoadErrorText ||
        message == stDefaultActionErrorText ||
        message == stConnectionErrorText ||
        message == stServerErrorText) {
      return requestFailedFallback;
    }
    return message;
  }
}
