import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef AuthCaptchaDialogLauncher =
    Future<Map<String, dynamic>?> Function(
      BuildContext context, {
      required String url,
      required String baseHost,
      String captchaApiKey,
      Map<String, dynamic> bridgeUserInfo,
    });

final authCaptchaDialogProvider = Provider<AuthCaptchaDialogLauncher>((ref) {
  return showAuthCaptchaDialog;
});

/// 图形验证码弹窗（对齐 iOS `STWebPopView` + `codeVerifSucc`）
Future<Map<String, dynamic>?> showAuthCaptchaDialog(
  BuildContext context, {
  required String url,
  required String baseHost,
  String captchaApiKey = '',
  Map<String, dynamic> bridgeUserInfo = const {},
}) async {
  if (url.trim().isEmpty) return null;
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierColor: const Color(0x4D000000),
    barrierDismissible: false,
    builder: (ctx) => _AuthCaptchaDialog(
      url: url.trim(),
      baseHost: baseHost.trim(),
      captchaApiKey: captchaApiKey.trim(),
      bridgeUserInfo: bridgeUserInfo,
    ),
  );
}

class _AuthCaptchaDialog extends StatefulWidget {
  const _AuthCaptchaDialog({
    required this.url,
    required this.baseHost,
    required this.captchaApiKey,
    required this.bridgeUserInfo,
  });

  final String url;
  final String baseHost;
  final String captchaApiKey;
  final Map<String, dynamic> bridgeUserInfo;

  @override
  State<_AuthCaptchaDialog> createState() => _AuthCaptchaDialogState();
}

class _AuthCaptchaDialogState extends State<_AuthCaptchaDialog> {
  static const _codeverifyAssetRoot = 'assets/local_mini/codeverify';
  static const _codeverifyFiles = [
    'assets/index.js',
    'assets/style.css',
    'favicon-dark.svg',
    'favicon.ico',
    'favicon.svg',
    'index.html',
    'polymer/env.js',
    'polymer/env/env.js',
    'pwa-192x192.png',
    'pwa-512x512.png',
    'robots.txt',
    'safari-pinned-tab.svg',
    'sitemap.xml',
  ];

  late final WebViewController _controller;
  bool _loading = true;
  bool _loadingLocalCodeverify = false;
  bool _didFallbackToLocalCodeverify = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[AuthCaptcha] onPageStarted: $url');
            _installWebKitPostMessageJsonWrap();
          },
          onPageFinished: (url) {
            debugPrint('[AuthCaptcha] onPageFinished: $url');
            if (mounted) setState(() => _loading = false);
            _logPageDiagnostics();
          },
          onProgress: (progress) {
            if (progress >= 100 && mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            debugPrint(
              '[AuthCaptcha] resource error: ${error.errorCode} '
              '${error.errorType} isMain=${error.isForMainFrame} '
              'url=${error.url} ${error.description}',
            );
            if (_fallbackToLocalCodeverifyIfNeeded(error)) return;
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..addJavaScriptChannel(
        'CMSScriptMessageChannel',
        onMessageReceived: (m) => _onBridge(m.message),
      )
      ..addJavaScriptChannel(
        'jsFunction',
        onMessageReceived: (m) => _onBridge(m.message),
      )
      ..addJavaScriptChannel(
        'STBridge',
        onMessageReceived: (m) => _onBridge(m.message),
      );
    if (kDebugMode) {
      _controller.setOnConsoleMessage((msg) {
        debugPrint('[AuthCaptcha console][${msg.level}] ${msg.message}');
      });
    }
    _installWebKitPostMessageJsonWrap();
    _loadInitialPage();
  }

  Future<void> _loadInitialPage() async {
    if (widget.url.startsWith('localMini://codeverify')) {
      await _loadLocalCodeverify();
      return;
    }
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _loadLocalCodeverify() async {
    _loadingLocalCodeverify = true;
    final file = await _prepareLocalCodeverify();
    await _controller.loadFile(file.path);
  }

  bool _fallbackToLocalCodeverifyIfNeeded(WebResourceError error) {
    final isMainFrame = error.isForMainFrame ?? true;
    final isSslFailure =
        error.errorCode == -1200 ||
        error.errorType == WebResourceErrorType.failedSslHandshake ||
        error.description.toLowerCase().contains('ssl');
    if (!isMainFrame ||
        _loadingLocalCodeverify ||
        _didFallbackToLocalCodeverify ||
        !isSslFailure) {
      return false;
    }

    _didFallbackToLocalCodeverify = true;
    if (mounted) setState(() => _loading = true);
    () async {
      try {
        debugPrint(
          '[AuthCaptcha] remote captcha SSL failed, fallback to localMini://codeverify',
        );
        await _loadLocalCodeverify();
      } catch (e) {
        debugPrint('[AuthCaptcha] local codeverify fallback failed: $e');
        if (mounted) setState(() => _loading = false);
      }
    }();
    return true;
  }

  Future<File> _prepareLocalCodeverify() async {
    final root = Directory(
      '${(await getTemporaryDirectory()).path}/local_mini/codeverify',
    );
    for (final relativePath in _codeverifyFiles) {
      final assetKey = '$_codeverifyAssetRoot/$relativePath';
      final target = File('${root.path}/$relativePath');
      await target.parent.create(recursive: true);
      final bytes = await rootBundle.load(assetKey);
      await target.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    return File('${root.path}/index.html');
  }

  Future<void> _installWebKitPostMessageJsonWrap() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    const script = r'''
(function () {
  var handlers = window.webkit && window.webkit.messageHandlers;
  if (!handlers) return;
  ['CMSScriptMessageChannel', 'jsFunction', 'STBridge'].forEach(function (name) {
    var h = handlers[name];
    if (!h || h.__stJsonWrapped) return;
    var orig = h.postMessage.bind(h);
    h.postMessage = function (body) {
      if (typeof body === 'string') return orig(body);
      try { return orig(JSON.stringify(body)); } catch (e) { return orig(String(body)); }
    };
    h.__stJsonWrapped = true;
  });
})();
''';
    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('[AuthCaptcha] postMessage JSON wrap failed: $e');
    }
  }

  Future<void> _logPageDiagnostics() async {
    try {
      final ready = await _controller.runJavaScriptReturningResult(
        'document.readyState',
      );
      final appLen = await _controller.runJavaScriptReturningResult(
        "document.getElementById('app')?.innerHTML?.length ?? -1",
      );
      final scripts = await _controller.runJavaScriptReturningResult(
        'document.scripts.length',
      );
      final hasBridge = await _controller.runJavaScriptReturningResult(
        '!!(window.webkit && window.webkit.messageHandlers && '
        'window.webkit.messageHandlers.CMSScriptMessageChannel)',
      );
      final hasCallback = await _controller.runJavaScriptReturningResult(
        'typeof window.CMSCallJsMessage === "function"',
      );
      debugPrint(
        '[AuthCaptcha] readyState=$ready appInnerLen=$appLen '
        'scriptCount=$scripts hasBridge=$hasBridge '
        'hasCallback=$hasCallback baseHost=${widget.baseHost}',
      );
    } catch (e) {
      debugPrint('[AuthCaptcha] diagnostics failed: $e');
    }
  }

  void _onBridge(String raw) {
    debugPrint('[AuthCaptcha] bridge: $raw');
    Map<String, dynamic>? msg;
    try {
      final d = jsonDecode(raw);
      if (d is Map) msg = Map<String, dynamic>.from(d);
    } catch (_) {
      return;
    }
    if (msg == null) return;

    final method =
        (msg['method'] as String? ?? msg['funcType'] as String? ?? '').trim();
    if (method == 'getConfig') {
      _sendBridgeCallback(
        method: method,
        methodId: _methodIdFrom(msg),
        code: '1',
        data: {
          'isChild': '0',
          'baseHost': widget.baseHost,
          'captchaApiKey': widget.captchaApiKey,
          'channel': 'AppStore',
        },
      );
      return;
    }

    if (method == 'getUserInfo') {
      _sendBridgeCallback(
        method: method,
        methodId: _methodIdFrom(msg),
        code: '1',
        data: widget.bridgeUserInfo,
      );
      return;
    }

    if (method == 'getToken') {
      _sendBridgeCallback(
        method: method,
        methodId: _methodIdFrom(msg),
        code: '1',
        data: '${widget.bridgeUserInfo['token'] ?? ''}',
      );
      return;
    }

    if (method == 'close') {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (method != 'codeVerifSucc') return;

    Map<String, dynamic> params = {};
    final p = msg['params'] ?? msg['parm'] ?? msg['param'];
    if (p is Map) {
      params = Map<String, dynamic>.from(p);
    } else if (p is String && p.isNotEmpty) {
      try {
        final d = jsonDecode(p);
        if (d is Map) params = Map<String, dynamic>.from(d);
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pop(context, params);
  }

  String _methodIdFrom(Map<String, dynamic> msg) {
    final p = msg['params'] ?? msg['parm'] ?? msg['param'];
    if (p is Map) return '${p['methodId'] ?? ''}';
    if (p is String && p.isNotEmpty) {
      try {
        final d = jsonDecode(p);
        if (d is Map) return '${d['methodId'] ?? ''}';
      } catch (_) {}
    }
    return '';
  }

  Future<void> _sendBridgeCallback({
    required String method,
    required String methodId,
    required String code,
    required Object? data,
  }) async {
    final payload = jsonEncode({
      'code': code,
      'method': method,
      if (methodId.isNotEmpty) 'methodId': methodId,
      'data': data,
    });
    await _controller.runJavaScript('CMSCallJsMessage($payload)');
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final dialogW = w - 100;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 50),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: dialogW,
                child: WebViewWidget(controller: _controller),
              ),
            ),
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
