import 'dart:convert';

import 'package:stmini_flutter/stmini_flutter.dart';

typedef OpenOnlineWebPage =
    Future<void> Function(
      Uri uri, {
      String? title,
      required bool showNavigationBar,
    });

/// 只处理在线 H5 交给宿主的页面与会话请求；通用存储和用户资料由插件处理。
final class OnlineWebBridge {
  OnlineWebBridge({
    required this.homeUri,
    required this.openPage,
    required this.closePage,
    required this.notifySessionChanged,
  });

  final Uri homeUri;
  final OpenOnlineWebPage openPage;
  final Future<void> Function() closePage;
  final Future<int> Function(String reason) notifySessionChanged;

  Future<Map<String, dynamic>> handle(WebBridgeRequest request) async {
    if (!_isHttpsOrigin(request.origin)) {
      return _failure('网页来源无效');
    }

    final params = request.params;
    try {
      switch (request.method) {
        case 'applog':
          // 诊断消息无需回传内容，但必须完成 H5 的回调。
          return _success();
        case 'close':
          await closePage();
          return _success();
        case 'web_notifySessionChanged':
          final rawReason = params['reason']?.toString().trim() ?? '';
          final notified = await notifySessionChanged(
            rawReason.isEmpty ? 'sessionChanged' : rawReason,
          );
          return _success({'notified': notified});
        case 'open':
          return params['router'] == '/web'
              ? await _openExternalPage(params)
              : await _openInternalRoute(params);
        default:
          return _failure('网页请求不受支持');
      }
    } on Object {
      return _failure('宿主处理网页请求失败');
    }
  }

  Future<Map<String, dynamic>> _openExternalPage(
    Map<String, dynamic> params,
  ) async {
    final rawUrl = params['link']?.toString().trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return _failure('网页地址无效');
    }
    await openPage(
      uri,
      title: params['title']?.toString(),
      showNavigationBar: _showNavigationBar(params['isNeedNavigationBar']),
    );
    return _success();
  }

  Future<Map<String, dynamic>> _openInternalRoute(
    Map<String, dynamic> params,
  ) async {
    final router = params['router'];
    if (router is! String ||
        !router.startsWith('/') ||
        router.startsWith('//') ||
        router == '/web') {
      return _failure('网页路由无效');
    }

    final routeParams = Map<String, dynamic>.from(params)..remove('methodId');
    if (router == '/login' || router == '/mine/login') {
      routeParams['isBack'] = '1';
    }
    final encoded = base64Url
        .encode(utf8.encode(jsonEncode(routeParams)))
        .replaceAll('=', '');
    final routeUri = homeUri.replace(
      fragment:
          '/?__mini_child=1&__mini_route_child=1&__mini_open_route=$encoded',
    );
    await openPage(routeUri, showNavigationBar: false);
    return _success();
  }

  static bool _isHttpsOrigin(String origin) {
    final uri = Uri.tryParse(origin);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.path.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static bool _showNavigationBar(Object? value) =>
      switch (value?.toString().trim().toLowerCase()) {
        '1' || 'true' || 'yes' => true,
        _ => false,
      };

  static Map<String, dynamic> _success([Map<String, dynamic>? data]) => {
    'code': '1',
    'data': data ?? <String, dynamic>{},
  };

  static Map<String, dynamic> _failure(String message) => {
    'code': '0',
    'data': {'msg': message},
  };
}
