import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/models/user_state.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/device_id_manager.dart';
import '../../core/services/app_locale_service.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'st_localized_prompt.dart' show STLocalizedText;
import 'st_load_animation_view.dart';
import 'st_toast.dart';

const Map<String, String> _webViewFallbackText = {
  'copy_link': '复制链接',
  'copy_toast_tip': '已复制到剪贴板',
  'dkplayer_error_message': '加载失败',
  'open_in_browser': '',
  'refresh': '刷新',
  'user_homepage': '',
  'wechat_open_hint': '',
};

// ─────────────────────────────────────────────
// 枚举 / 配置
// ─────────────────────────────────────────────

/// 对齐 iOS `STWebMode`
enum STWebMode {
  /// 普通 H5（http/https）
  h5,

  /// 在线小程序（miniprogram://）
  onlineMini,

  /// 本地小程序（localMini://）
  localMini,
}

/// URL 前缀常量（对齐 iOS `STH5Prefix` / `STMiniPrefix`）
class _Prefix {
  static const miniOnline = 'miniprogram://';
  static const miniLocal = 'localMini://';
}

/// 整合了 iOS `STWebConfig` 和 `STWebOpenHandler` 路由解析逻辑的 Flutter 配置对象。
/// 可通过 [STWebConfig.fromUrl] 自动识别模式。
class STWebConfig {
  final String url;
  final STWebMode mode;
  final String miniName;
  final String? path;

  /// H5：仅「路由/宿主」下发的键值参与 [mergeIosStyleH5LoadUrl]；**不包含** H5 链接地址栏上原有的 query。
  final Map<String, String> params;
  final String? title;

  /// 对齐 iOS `shouldShowNavigationBar()`：**默认 false**。
  /// 只有 URL 参数 `isNeedNavigationBar=1/true/yes` 才返回 true。
  final bool showNavigationBar;

  /// 内嵌模式：不包 Scaffold/AppBar，用于卡片内嵌
  final bool embedded;

  const STWebConfig({
    required this.url,
    this.mode = STWebMode.h5,
    this.miniName = '',
    this.path,
    this.params = const {},
    this.title,
    this.showNavigationBar = false, // ← 对齐 iOS 默认 false
    this.embedded = false,
  });

  /// 对齐 iOS `STWebOpenHandler.openWeb`
  factory STWebConfig.fromUrl(
    String rawUrl, {
    String? title,
    Map<String, String>? extraParams,
    bool embedded = false,
  }) {
    if (rawUrl.startsWith(_Prefix.miniOnline)) {
      final rest = rawUrl.replaceFirst(_Prefix.miniOnline, '');
      final (name, path, params) = _parseMiniUrl(rest);
      final merged = {...?params, ...?extraParams};
      // Mini 模式下 isNeedNavigationBar 控制的是胶囊栏，默认 true（有胶囊）
      final isNeedNav = _parseBool(merged['isNeedNavigationBar']) ?? true;
      return STWebConfig(
        url: '${_Prefix.miniOnline}$rest',
        mode: STWebMode.onlineMini,
        miniName: name,
        path: merged.remove('path') ?? path,
        params: merged,
        title: title,
        showNavigationBar: isNeedNav,
        embedded: embedded,
      );
    }

    if (rawUrl.startsWith(_Prefix.miniLocal)) {
      final rest = rawUrl.replaceFirst(_Prefix.miniLocal, '');
      final (name, path, params) = _parseMiniUrl(rest);
      final merged = {...?params, ...?extraParams};
      final isNeedNav = _parseBool(merged['isNeedNavigationBar']) ?? true;
      return STWebConfig(
        url: '${_Prefix.miniLocal}$rest',
        mode: STWebMode.localMini,
        miniName: name,
        path: merged.remove('path') ?? path,
        params: merged,
        title: title,
        showNavigationBar: isNeedNav,
        embedded: embedded,
      );
    }

    // H5 默认 —— 对齐 iOS shouldShowNavigationBar() 默认 false
    final uri = Uri.tryParse(rawUrl);
    final urlParams = Map<String, String>.from(uri?.queryParameters ?? {});
    final routeOnly = Map<String, String>.from(extraParams ?? {});
    // 导航栏开关：地址栏 query 与宿主传入参数合并后读取
    final mergedForUi = {...urlParams, ...routeOnly};
    final isNeedNav = _parseBool(mergedForUi['isNeedNavigationBar']) ?? false;
    // [params] 仅含宿主/路由层字段，参与 iOS 式二段 URL 合并；不要把 H5 地址栏自有 query
    // 塞进来，否则 mergeIosStyleH5LoadUrl 会再追加整段 link=… 导致白屏或签名校验失败。
    return STWebConfig(
      url: rawUrl,
      mode: STWebMode.h5,
      params: routeOnly,
      title: title,
      showNavigationBar: isNeedNav,
      embedded: embedded,
    );
  }

  static (String name, String? path, Map<String, String>? params) _parseMiniUrl(
    String url,
  ) {
    final idx = url.indexOf('?');
    if (idx == -1) return (url, null, null);
    final name = url.substring(0, idx);
    final queryStr = url.substring(idx + 1);
    final qp = Uri.splitQueryString(queryStr);
    final path = qp['path'];
    final rest = Map<String, String>.from(qp)..remove('path');
    return (name, path, rest.isEmpty ? null : rest);
  }

  static bool? _parseBool(String? value) {
    if (value == null) return null;
    final v = value.toLowerCase();
    if (v == '1' || v == 'true' || v == 'yes') return true;
    if (v == '0' || v == 'false' || v == 'no') return false;
    return null;
  }

  /// 对齐 iOS `NSString+Tool.addQueryParametersWithParameters:`（同 key 后者覆盖前者）。
  /// Hash SPA（`#/…`）把参数追加到 fragment query，而不是 `#` 前的主 URL query。
  static String appendParamsToUrl(String url, Map<String, String> params) {
    if (params.isEmpty) return url;
    final components = Uri.tryParse(url);
    if (components == null) return url;

    final fragment = components.fragment;
    if (fragment.isNotEmpty && fragment.contains('/')) {
      var fragPath = fragment;
      final fragQuery = <String, String>{};
      final qIdx = fragment.indexOf('?');
      if (qIdx != -1) {
        fragPath = fragment.substring(0, qIdx);
        fragQuery.addAll(Uri.splitQueryString(fragment.substring(qIdx + 1)));
      }
      fragQuery.addAll(params);
      final newFragment = fragQuery.isEmpty
          ? fragPath
          : '$fragPath?${Uri(queryParameters: fragQuery).query}';
      return components
          .replace(queryParameters: const {})
          .replace(fragment: newFragment)
          .toString();
    }

    final qp = Map<String, String>.from(components.queryParameters);
    qp.addAll(params);
    return components.replace(queryParameters: qp).toString();
  }

  /// 对齐 iOS `STBaseWebViewController.setRouterParams:`：去掉 link/permission/isNeedNavigationBar 后再合并。
  static String mergeIosStyleH5LoadUrl(
    String httpLink,
    Map<String, String> params,
  ) {
    if (params.isEmpty) return httpLink;
    final cleaned = Map<String, String>.from(params)
      ..remove('link')
      ..remove('permission')
      ..remove('isNeedNavigationBar');
    if (cleaned.isEmpty) return httpLink;
    return appendParamsToUrl(httpLink, cleaned);
  }

  /// 路由打开 H5：仅将 [routeQueryExtras]（如 `/web?...` 上除 link 外的 query）写入 [params]，
  /// 用于 [mergeIosStyleH5LoadUrl]。**不要**把 `link` 地址栏自带的 query 放进 [params]，
  /// 否则会对活动页/邀请链接等已带长 query 的 URL 做错误二段合并导致白屏。
  factory STWebConfig.h5FromRouter({
    required String link,
    Map<String, String>? routeQueryExtras,
    String? explicitTitle,
    bool navigationBarFallback = false,
  }) {
    final uri = Uri.tryParse(link);
    final fromLink = Map<String, String>.from(uri?.queryParameters ?? {});
    final routeOnly = Map<String, String>.from(routeQueryExtras ?? {});
    final mergedForUi = {...fromLink, ...routeOnly};
    final showNav =
        _parseBool(mergedForUi['isNeedNavigationBar']) ?? navigationBarFallback;
    return STWebConfig(
      url: link,
      mode: STWebMode.h5,
      params: routeOnly,
      title: explicitTitle,
      showNavigationBar: showNav,
    );
  }

  /// 在线/本地 Mini 的 CDN 伪装 URL 上不携带宿主路由专用字段
  static Map<String, String> miniCdnQueryFromParams(
    Map<String, String> params,
  ) {
    const strip = {'link', 'permission', 'isReplace', 'title', 'nav', 'isOnce'};
    final q = Map<String, String>.from(params);
    for (final k in strip) {
      q.remove(k);
    }
    return q;
  }

  static String localMiniAssetKey(String name) {
    return 'assets/local_mini/$name/index.html';
  }

  static String? localMiniRouteFragment({
    required String? path,
    required Map<String, String> params,
  }) {
    var fragmentPath = path?.trim() ?? '';
    if (fragmentPath.isEmpty) return null;
    if (fragmentPath.startsWith('#')) {
      fragmentPath = fragmentPath.substring(1);
    }
    if (!fragmentPath.startsWith('/')) {
      fragmentPath = '/$fragmentPath';
    }
    final query = Map<String, String>.from(params)
      ..remove('link')
      ..remove('path');
    if (query.isEmpty) return fragmentPath;
    return '$fragmentPath?${Uri(queryParameters: query).query}';
  }
}

// ─────────────────────────────────────────────
// 主 Widget
// ─────────────────────────────────────────────

/// 整合 iOS 两套 WebView 体系（STBaseWebViewController + STMini）的统一 Flutter 容器。
///
/// **修复项（对齐 iOS 实际行为）：**
/// - [STWebConfig.showNavigationBar] 默认 `false`（iOS `shouldShowNavigationBar()` 默认 false）
/// - `jsClosePage` / `close` 使用 GoRouter `context.pop()` 正确关闭页面
/// - 非 embedded：`PopScope` 兜底系统返回；起始边窄条侧滑对齐 iOS `interactivePopGesture`
/// - H5 bridge 注入 `window.STBridgeReady` 标记，兼容老版检测方式
/// - 新增 H5 funcType：`jsSetTitle` / `jsHideNavBar` / `jsShowNavBar` /
///   `jsCopyText` / `jsPushBuildinApp` / `jsPushVideo` / `jsPushDoc` 等全量对齐
/// - 新增 STMini method：`navigateBack` / `getSystemInfo` / `getToken` /
///   `vibrate` / `navigateBack` / `hideNavBar` / `showNavBar` /
///   `setNavigationBarColor` / `showLoading` / `hideLoading` / `scanCode` /
///   `getClipboardData` / `previewImage` / `downloadFile` 等
class STUnifiedWebView extends ConsumerStatefulWidget {
  final STWebConfig config;
  final bool visible;

  const STUnifiedWebView({
    super.key,
    required this.config,
    this.visible = true,
  });

  @override
  ConsumerState<STUnifiedWebView> createState() => _STUnifiedWebViewState();
}

class _STUnifiedWebViewState extends ConsumerState<STUnifiedWebView>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _controllerReady = false;
  bool _pendingLoad = false;
  bool _isLoading = true;
  bool _isAppForeground = true;
  String? _loadError;
  String? _pendingLocalMiniInitialFragment;
  String _appBarTitle = '';
  bool _navBarVisible = true; // 运行时可被 jsHideNavBar/jsShowNavBar 动态控制
  Color? _navBarColorOverride;
  Brightness? _lastThemeBrightness;

  // ── 对齐 iOS backActionIsHooked + canGoBack 状态 ──────────────────────────
  /// 对齐 iOS `backActionIsHooked`：H5 可通过 jsHookNaviBackBtn 拦截原生返回按钮，
  /// 此时 _nativeBackAction 会先把事件回调给 H5，再由 H5 决定是否关闭。
  bool _backActionIsHooked = false;

  /// WebView 内部是否可以后退（对应 iOS `canGoBack` callback，用于显示额外关闭按钮）
  bool _webCanGoBack = false;

  /// 对齐 iOS `jsTopBackHome` + STBaseWebViewController：下一次点原生返回时一路 pop（navigation popToRoot）
  bool _popToRootOnNextNativeBack = false;

  STWebConfig get _cfg => widget.config;
  bool get _isMini => _cfg.mode != STWebMode.h5;
  Color get _webShellColor => context.adaptiveSurfacePrimary;
  Color get _webTextColor => context.adaptiveTextPrimary;
  Color get _webSecondaryTextColor => context.adaptiveTextSecondary;
  Color get _webDividerColor => context.adaptiveDivider;
  Color get _webPillColor => context.adaptiveIconPillBg;
  Color get _effectiveNavBarColor => _navBarColorOverride ?? _webShellColor;
  SystemUiOverlayStyle get _webOverlayStyle {
    if (context.adaptiveIsDark) {
      return SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
      );
    }
    return SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
    );
  }

  // ── 生命周期 ──────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appBarTitle = _cfg.title?.trim() ?? '';
    _navBarVisible = _cfg.showNavigationBar;
    _initController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastThemeBrightness != null && _lastThemeBrightness != brightness) {
      _notifyTheme();
      _controller?.setBackgroundColor(_webShellColor);
    }
    _lastThemeBrightness = brightness;
  }

  @override
  void didUpdateWidget(covariant STUnifiedWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // URL 或路由参数变更时重新加载（对齐 iOS：`openH5` 会随 params 重写最终加载 URL）
    final urlChanged =
        oldWidget.config.url != widget.config.url &&
        widget.config.url.isNotEmpty;
    final paramsChanged = !mapEquals(
      oldWidget.config.params,
      widget.config.params,
    );
    if ((urlChanged || paramsChanged) && _controller != null) {
      final next = _resolveUrl();
      debugPrint('[WebView] config changed → reload: $next');
      setState(() {
        _loadError = null;
        _isLoading = true;
      });
      _scheduleLoad(() => _loadUrl(next));
    }
    if (oldWidget.visible != widget.visible && _controllerReady) {
      _sendLifecycleMessage(
        widget.visible ? 'pageWillAppear' : 'pageWillDisAppear',
      );
    }
    // showNavigationBar 变更时更新状态
    if (oldWidget.config.showNavigationBar != widget.config.showNavigationBar) {
      setState(() => _navBarVisible = widget.config.showNavigationBar);
    }
  }

  @override
  void dispose() {
    _runJs('document.documentElement && document.documentElement.remove();');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isAppForeground) {
      _isAppForeground = true;
      if (widget.visible) {
        _sendLifecycleMessage('pageWillAppear');
      }
    } else if (state == AppLifecycleState.paused) {
      _isAppForeground = false;
      if (widget.visible) {
        _sendLifecycleMessage('pageWillDisAppear');
      }
    }
  }

  // ── 控制器构建 ──────────────────────────────

  Future<void> _initController() async {
    late final PlatformWebViewControllerCreationParams params;
    if (!kIsWeb && WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    // Flutter iOS PlatformView 用透明底易白屏；scrollView 设壳层底色保证 SPA 未渲染前也不透
    await controller.setBackgroundColor(_webShellColor);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (!mounted) return;
          debugPrint('[WebView] onPageStarted: $url');
          setState(() {
            _isLoading = true;
            _loadError = null;
          });
          final c = _controller;
          if (c != null) _installWebKitPostMessageJsonWrap(c);
        },
        onPageFinished: (url) {
          if (!mounted) return;
          debugPrint('[WebView] onPageFinished: $url');
          setState(() {
            _isLoading = false;
            _loadError = null;
          });
          _onPageLoaded();
          _updateCanGoBack();
          if (kDebugMode) _logPageDiagnostics();
        },
        onProgress: (_) {},
        onWebResourceError: (e) {
          debugPrint(
            '[WebView] resource error: type=${e.errorType} code=${e.errorCode} '
            'desc=${e.description} url=${e.url} mainFrame=${e.isForMainFrame}',
          );
          if (e.errorType == WebResourceErrorType.webContentProcessTerminated) {
            debugPrint('[WebView] WKWebView process terminated → reload');
            _controller?.reload();
            return;
          }
          if (e.isForMainFrame == true && mounted) {
            setState(() {
              _isLoading = false;
              _loadError = e.description.isNotEmpty ? e.description : null;
            });
            if (e.description.isEmpty) {
              _localizedText('dkplayer_error_message', fallback: '').then((
                text,
              ) {
                if (!mounted) return;
                setState(() => _loadError = '$text (${e.errorCode})');
              });
            }
          }
        },
        onHttpError: (e) {
          debugPrint(
            '[WebView] http error: status=${e.response?.statusCode} url=${e.request?.uri}',
          );
        },
        onNavigationRequest: _shouldAllowNavigation,
        onUrlChange: (_) => _updateCanGoBack(),
      ),
    );
    // 必须 await：channel 会在 documentStart 注入 handler，未完成就 load 会导致 H5 白屏
    await controller.addJavaScriptChannel(
      'jsFunction',
      onMessageReceived: (msg) => _handleH5Bridge(msg.message),
    );
    await controller.addJavaScriptChannel(
      'STBridge',
      onMessageReceived: (msg) => _handleH5Bridge(msg.message),
    );
    await controller.addJavaScriptChannel(
      '__mcJssdkBridge',
      onMessageReceived: (msg) => _handleMcJssdkBridge(msg.message),
    );
    await controller.addJavaScriptChannel(
      'CMSScriptMessageChannel',
      onMessageReceived: (msg) => _handleMiniApi(msg.message),
    );
    await controller.addJavaScriptChannel(
      'STMiniApi',
      onMessageReceived: (msg) => _handleMiniApi(msg.message),
    );
    await controller.addJavaScriptChannel(
      'originFunction',
      onMessageReceived: (msg) => _handleH5Bridge(msg.message),
    );
    await controller.addJavaScriptChannel(
      'pageLoaded',
      onMessageReceived: (_) {
        debugPrint('[WebView] H5 pageLoaded');
        if (mounted) setState(() => _isLoading = false);
      },
    );

    await _configurePlatformController(controller);
    await _installWebKitPostMessageJsonWrap(controller);

    if (!mounted) return;
    setState(() {
      _controller = controller;
      _controllerReady = true;
      _pendingLoad = true;
    });
  }

  /// 等 WebViewWidget 挂上树后再 load；iOS PlatformView 再多等一帧，避免白屏。
  void _scheduleLoad(VoidCallback load) {
    void runLoad() {
      if (!mounted) return;
      load();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        WidgetsBinding.instance.addPostFrameCallback((_) => runLoad());
      } else {
        runLoad();
      }
    });
  }

  /// 对齐 iOS `NSString+Tool.configWebViewUA` 后缀。
  Future<String> _mediacloudUaSuffix() async {
    final pkg = await PackageInfo.fromPlatform();
    final version = '(${pkg.packageName} ${pkg.version})';
    return '; GdyBridgeWebView; mediacloudclient$version; mediacloudclientv3$version';
  }

  /// 对齐 iOS `STWebView.makeSubviews`：读取 WKWebView 默认 UA 再追加 bridge 后缀。
  Future<String> _buildUserAgent(WebViewController controller) async {
    final suffix = await _mediacloudUaSuffix();
    final platform = controller.platform;
    if (!kIsWeb && platform is WebKitWebViewController) {
      try {
        final defaultUa = await platform.getUserAgent();
        if (defaultUa != null && defaultUa.trim().isNotEmpty) {
          return '${defaultUa.trim()}$suffix';
        }
      } catch (e) {
        debugPrint('[WebView] getUserAgent failed: $e');
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const base =
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      return '$base$suffix';
    }
    return 'Mozilla/5.0$suffix';
  }

  Future<void> _configurePlatformController(
    WebViewController controller,
  ) async {
    final ua = await _buildUserAgent(controller);
    debugPrint('[WebView] userAgent: $ua');
    final platform = controller.platform;
    if (platform is WebKitWebViewController) {
      await platform.setUserAgent(ua);
      await platform.setAllowsBackForwardNavigationGestures(true);
      await platform.setBackgroundColor(_webShellColor);
      await platform.enableZoom(true);
      if (kDebugMode) {
        var inspectable = false;
        try {
          await platform.setInspectable(true);
          inspectable = true;
        } on PlatformException catch (e) {
          // iOS < 16.4 不支持 inspectable，不应阻断 WebView 初始化
          debugPrint('[WebView] setInspectable skipped: ${e.message}');
        }
        // console 劫持会在 documentStart 注入脚本，低版本 iOS 仅在 inspectable 可用时开启
        if (inspectable) {
          try {
            await platform.setOnConsoleMessage((msg) {
              debugPrint('[WebView console][${msg.level}] ${msg.message}');
            });
          } on PlatformException catch (e) {
            debugPrint('[WebView] setOnConsoleMessage skipped: ${e.message}');
          }
        }
      }
    } else if (platform is AndroidWebViewController) {
      await platform.setUserAgent(ua);
    }
  }

  /// iOS WKWebView 对 `postMessage(object)` 会用 `.toString()` 传到 Dart（非 JSON），
  /// 在首屏脚本运行前包一层 `JSON.stringify`。
  Future<void> _installWebKitPostMessageJsonWrap(
    WebViewController controller,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    const script = r'''
(function () {
  var handlers = window.webkit && window.webkit.messageHandlers;
  if (!handlers) return;
  [
    'CMSScriptMessageChannel', 'jsFunction', 'STBridge',
    '__mcJssdkBridge', 'STMiniApi', 'originFunction', 'pageLoaded'
  ].forEach(function (name) {
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
      await controller.runJavaScript(script);
    } catch (e) {
      debugPrint('[WebView] postMessage JSON wrap failed: $e');
    }
  }

  Future<void> _loadUrl(String resolved) async {
    final controller = _controller;
    if (controller == null) return;
    debugPrint('[WebView] load: $resolved');
    if (resolved.startsWith('asset://')) {
      final assetPayload = resolved.substring('asset://'.length);
      final hashIndex = assetPayload.indexOf('#');
      final assetKey = hashIndex == -1
          ? assetPayload
          : assetPayload.substring(0, hashIndex);
      _pendingLocalMiniInitialFragment = hashIndex == -1
          ? null
          : assetPayload.substring(hashIndex + 1);
      await controller.loadFlutterAsset(assetKey);
      return;
    }
    final u = Uri.tryParse(resolved);
    if (u == null) return;
    // 对齐 iOS：UA 仅走 customUserAgent，不在 loadRequest header 里重复设置
    await controller.loadRequest(u);
  }

  Future<void> _logPageDiagnostics() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final ready = await controller.runJavaScriptReturningResult(
        'document.readyState',
      );
      final appHtml = await controller.runJavaScriptReturningResult(
        "document.getElementById('app')?.innerHTML?.length ?? -1",
      );
      final hasConfig = await controller.runJavaScriptReturningResult(
        'typeof window.__APP_CONFIG__ !== "undefined"',
      );
      debugPrint(
        '[WebView] readyState=$ready appInnerLen=$appHtml hasAppConfig=$hasConfig',
      );
    } catch (e) {
      debugPrint('[WebView] diagnostics failed: $e');
    }
  }

  void _loadInitialUrl() {
    _loadUrl(_resolveUrl());
  }

  String _resolveUrl() {
    if (!_isMini) {
      return STWebConfig.mergeIosStyleH5LoadUrl(_cfg.url, _cfg.params);
    }
    if (_cfg.mode == STWebMode.localMini) {
      final assetKey = STWebConfig.localMiniAssetKey(_cfg.miniName);
      final fragment = STWebConfig.localMiniRouteFragment(
        path: _cfg.path,
        params: _cfg.params,
      );
      if (fragment == null || fragment.isEmpty) {
        return 'asset://$assetKey';
      }
      return 'asset://$assetKey#$fragment';
    }
    final name = _cfg.miniName;
    String base = 'https://mini.jufu.com/$name';
    if (_cfg.path != null && _cfg.path!.isNotEmpty) {
      final p = _cfg.path!.startsWith('/') ? _cfg.path! : '/${_cfg.path!}';
      base = '$base$p';
    }
    final qClean = STWebConfig.miniCdnQueryFromParams(_cfg.params);
    if (qClean.isNotEmpty) {
      final uri = Uri.parse(base);
      final updated = uri.replace(
        queryParameters: {...uri.queryParameters, ...qClean},
      );
      return updated.toString();
    }
    return base;
  }

  NavigationDecision _shouldAllowNavigation(NavigationRequest req) {
    final url = req.url;
    if (url.startsWith('file://') ||
        url.startsWith('about:') ||
        url.startsWith('data:') ||
        url.startsWith('blob:')) {
      return NavigationDecision.navigate;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _launchExternalUrl(url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  // ── 页面加载完成 ──────────────────────────────

  void _onPageLoaded() {
    _injectBridgeShim();
    _applyLocalMiniInitialRoute();
    _notifyTheme();
    _refreshTitle();
    if (widget.visible) {
      _sendLifecycleMessage('pageWillAppear');
    }
    // SPA 延迟设置 title
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _refreshTitle();
    });
  }

  void _applyLocalMiniInitialRoute() {
    if (_cfg.mode != STWebMode.localMini) return;
    final fragment = _pendingLocalMiniInitialFragment;
    if (fragment == null || fragment.isEmpty) return;
    final targetHash = '#$fragment';
    _runJs('''
(function () {
  var targetHash = ${jsonEncode(targetHash)};
  if (window.location.hash !== targetHash) {
    window.location.replace(window.location.href.split('#')[0] + targetHash);
  }
})();
''');
  }

  /// 注入 JS shim，对齐 iOS STWebView 注入的桥接脚本。
  ///
  /// Flutter 的 `addJavaScriptChannel('jsFunction')` 已经让
  /// `window.webkit.messageHandlers.jsFunction`（iOS）和 `window.jsFunction`（双端）可用，
  /// 此处额外兼容其他调用形式：
  ///   window.webkit.messageHandlers.jsFunction.postMessage(json)  ← iOS H5 原生调用
  ///   window.jsFunction.postMessage(json)                         ← Flutter 注入
  ///   window.STBridge.postMessage(json)                           ← 旧版 H5
  ///   window.cms.callNative(json)                                 ← 部分活动页
  Future<void> _injectBridgeShim() async {
    const shim = r"""
(function(){
  if(window.__STBridgeShimInjected) return;
  window.__STBridgeShimInjected = true;
  window.STBridgeReady = true;

  // 核心发消息函数：优先 jsFunction（与 iOS 同名频道，双端均已注入）
  function _sendH5Msg(msg) {
    var s = (typeof msg === 'string') ? msg : JSON.stringify(msg);
    if (window.jsFunction && typeof window.jsFunction.postMessage === 'function') {
      window.jsFunction.postMessage(s);
    } else if (window.STBridge && typeof window.STBridge.postMessage === 'function') {
      window.STBridge.postMessage(s);
    }
  }

  // window.STBridge 兼容层（旧版 H5 调用形式）
  if (!window.STBridge || typeof window.STBridge.postMessage !== 'function') {
    window.STBridge = { postMessage: _sendH5Msg };
  }

  // window.cms.callNative 兼容层
  if (!window.cms) { window.cms = {}; }
  window.cms.callNative = _sendH5Msg;

})();
""";
    await _runJs(shim);
  }

  Future<void> _refreshTitle() async {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    String? t;
    try {
      t = await controller.getTitle();
    } catch (_) {}
    t = t?.trim();
    if (t == null || t.isEmpty) {
      try {
        final r = await controller.runJavaScriptReturningResult(
          'document.title',
        );
        final s = (r is String)
            ? r.replaceAll('"', '').trim()
            : r.toString().trim();
        if (s.isNotEmpty) t = s;
      } catch (_) {}
    }
    if (!mounted) return;
    if (t != null && t.isNotEmpty) {
      setState(() => _appBarTitle = t!);
    } else if (_cfg.title?.isNotEmpty == true) {
      setState(() => _appBarTitle = _cfg.title!);
    }
  }

  // ─────────────────────────────────────────────
  // 返回 / 关闭逻辑（完整对齐 iOS backAction / closeAction）
  // ─────────────────────────────────────────────

  /// 更新 WebView 内部是否可后退，对应 iOS `canGoBack` 回调。
  /// 用于在原生导航栏显示额外关闭按钮（×）。
  Future<void> _updateCanGoBack() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final can = await controller.canGoBack();
      if (mounted && can != _webCanGoBack) {
        setState(() => _webCanGoBack = can);
      }
    } catch (_) {}
  }

  /// 对齐 iOS `backAction`（原生导航栏返回按钮触发）：
  ///
  /// 1. H5 拦截了返回（`_backActionIsHooked`）→ 回调 H5 `hookNaviBackBtn`，不弹栈
  /// 2. 否则 → 直接 `context.pop()`（**不检查 WebView 历史**，与 iOS 一致）
  ///
  /// iOS 注释掉了 canGoBack 检查（`// [self.webView.webView goBack]`），
  /// 表明原生返回按钮始终关闭 ViewController，web 内部历史由 H5 自行管理。
  void _nativeBackAction() {
    if (!mounted) return;
    if (_backActionIsHooked) {
      // 对齐 iOS: CMSJsCallBack({"code":"1","method":"hookNaviBackBtn","data":{}})
      final payload = jsonEncode({
        'code': '1',
        'method': 'hookNaviBackBtn',
        'data': {},
      });
      _runJs('typeof CMSJsCallBack==="function"&&CMSJsCallBack($payload)');
      return;
    }
    // 对齐 iOS STBaseWebViewController：jsTopBackHome 后下一次原生返回 → popToRoot
    if (_popToRootOnNextNativeBack) {
      _popToRootOnNextNativeBack = false;
      while (context.canPop()) {
        context.pop();
      }
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// 强制关闭（对齐 iOS `closeAction` / `jsClosePage`）：
  /// 直接弹出，忽略 hookNaviBackBtn 和 WebView 历史。
  void _forceClosePage() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// 解析 H5 bridge 消息：标准 JSON 或 iOS NSDictionary `.toString()` 格式。
  Map<String, dynamic>? _parseBridgeMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '(null)') return null;

    try {
      final d = jsonDecode(trimmed);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}

    try {
      return Map<String, dynamic>.from(
        jsonDecode(_looseMapStringToJson(trimmed)) as Map,
      );
    } catch (_) {}

    return null;
  }

  /// `{method: getUserInfo, params: {methodId: x}}` → 合法 JSON 字符串
  String _looseMapStringToJson(String s) {
    var out = s.trim();
    for (var i = 0; i < 8; i++) {
      final prev = out;
      out = out.replaceAllMapped(
        RegExp(r'([{,]\s*)([a-zA-Z_][\w]*)(\s*:)'),
        (m) => '${m[1]}"${m[2]}"${m[3]}',
      );
      out = out.replaceAllMapped(
        RegExp(r'(:\s*)([a-zA-Z_][\w]*)(\s*[,}])'),
        (m) => '${m[1]}"${m[2]}"${m[3]}',
      );
      if (out == prev) break;
    }
    return out;
  }

  /// iOS `WKScriptMessage.body` 里 `parm` 可能是 Map 或 JSON 字符串
  Map<String, dynamic> _bridgeParmMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return {};
  }

  bool _truthy(dynamic v) =>
      v == true || v == 1 || v == '1' || v == 'true' || v == 'yes';

  /// 通过 GoRouter 打开 `/web`，与 iOS `STBaseWebViewController` + `configNavHidden` 对齐
  void _pushWebRoute(
    String link, {
    bool nativeNavBar = false,
    Map<String, dynamic>? bridgeDic,
  }) {
    if (!mounted || link.isEmpty) return;
    final replace = _truthy(bridgeDic?['isReplace']);
    final qp = <String, String>{'link': link, if (nativeNavBar) 'nav': '1'};
    final loc = Uri(path: '/web', queryParameters: qp).toString();
    if (replace) {
      context.pushReplacement(loc);
    } else {
      context.push(loc);
    }
  }

  void _pushConfiguredAgreement({required bool privacy}) {
    final h5 = ref.read(userStateProvider).h5AddressModel;
    final link = privacy
        ? h5?.privacyPolicyUrl.trim() ?? ''
        : h5?.userAgreementUrl.trim() ?? '';
    if (link.isNotEmpty) {
      _pushWebRoute(link, nativeNavBar: false);
    }
  }

  // ─────────────────────────────────────────────
  // JSBridge：体系一（H5 funcType 协议）
  // 完整对齐 iOS STWebView+JSMessage.m 全部 funcType
  // ─────────────────────────────────────────────

  void _handleH5Bridge(String raw) {
    debugPrint('[STBridge] ← $raw');
    final msg = _parseBridgeMessage(raw);
    if (msg == null) {
      debugPrint('[STBridge] 无法解析 JSON: $raw');
      return;
    }

    final funcType = (msg['funcType'] as String? ?? '').trim();
    final dic = _bridgeParmMap(msg['parm'] ?? msg['param']);
    final cbk = msg['__cbk__'] as String?;

    switch (funcType) {
      // ── 用户信息 ─────────────────────────────
      case 'jsGetUserInfo':
      case 'userGetInfo':
        _buildUserInfoPayload().then((data) {
          if (cbk != null && cbk.isNotEmpty) {
            _h5Callback(cbk, data);
          } else {
            _runJs(
              'typeof HtmlJsGetUserInfo === "function" && HtmlJsGetUserInfo(${jsonEncode(data)})',
            );
          }
        });

      // ── 设备信息 ─────────────────────────────
      case 'deviceGetInfo':
        _h5MediaCloudCallback(funcType, _buildDeviceInfoPayload());

      // ── 涨跌颜色（对齐 iOS STScriptMessageHandler getRiseColor）───────
      case 'getRiseColor':
        final payload = _riseColorBridgePayload();
        if (cbk != null && cbk.isNotEmpty) {
          _h5Callback(cbk, payload);
        } else {
          _h5AppCallback(funcType, payload);
        }

      // ── Token ────────────────────────────────
      case 'jsGetToken':
      case 'getToken':
        final user = ref.read(userStateProvider);
        final data = {
          'code': user.isLogin ? '0' : '-1',
          'data': {'token': user.token},
        };
        if (cbk != null && cbk.isNotEmpty) {
          _h5Callback(cbk, data);
        } else {
          _h5AppCallback(funcType, data);
        }

      // ── H5 拦截原生返回按钮（对齐 iOS backActionIsHooked）────────────────
      case 'jsHookNaviBackBtn':
        final hook = dic['hook'] ?? dic['enable'];
        _backActionIsHooked =
            hook == true || hook == 1 || hook == '1' || hook == 'true';

      // ── 关闭页面（强制关页，不退 Web 历史，对齐 iOS jsClosePage → backAction）──
      case 'jsClosePage':
        _forceClosePage();

      // ── 登录 ─────────────────────────────────
      case 'jsLogin':
      case 'userLogin':
        _requireLogin(
          onSuccess: () {
            _buildUserInfoPayload().then((data) {
              if (cbk != null && cbk.isNotEmpty) {
                _h5Callback(cbk, data);
              } else {
                _h5AppCallback(funcType, data);
              }
            });
          },
        );

      // ── 设置标题 ──────────────────────────────
      case 'jsSetTitle':
      case 'setNavBarTitle':
        final title = (dic['title'] ?? dic['name'] ?? '') as String;
        if (title.isNotEmpty && mounted) setState(() => _appBarTitle = title);

      // ── 显示/隐藏导航栏 ───────────────────────
      case 'jsHideNavBar':
        if (mounted) setState(() => _navBarVisible = false);

      case 'jsShowNavBar':
        if (mounted) setState(() => _navBarVisible = true);

      // ── 复制文本 ──────────────────────────────
      case 'jsCopyText':
        final text = (dic['text'] ?? dic['content'] ?? '') as String;
        if (text.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: text));
          _toastLocalized('copy_toast_tip', fallback: '');
        }

      // ── 跳转 H5 ──────────────────────────────
      // iOS STWebView+JSMessage：configNavHidden:NO → 显示原生导航栏
      case 'jsPushH5':
      case 'pushLinkViewController':
        final link = '${dic['link'] ?? dic['url'] ?? ''}'.trim();
        if (link.isNotEmpty && mounted) {
          _pushWebRoute(link, nativeNavBar: true, bridgeDic: dic);
        }

      // ── 跳转内置小程序 ────────────────────────
      case 'jsPushBuildinApp':
        final link = '${dic['link'] ?? dic['url'] ?? ''}'.trim();
        if (link.isNotEmpty && mounted) {
          final nav = _truthy(dic['nav']);
          if (link.startsWith(_Prefix.miniOnline) ||
              link.startsWith(_Prefix.miniLocal)) {
            final replace = _truthy(dic['isReplace']);
            final loc = '/mini?link=${Uri.encodeComponent(link)}';
            if (replace) {
              context.pushReplacement(loc);
            } else {
              context.push(loc);
            }
          } else {
            _pushWebRoute(link, nativeNavBar: nav, bridgeDic: dic);
          }
        }

      // ── 专题首页 / 列表 / 政情：无原生导航栏（iOS configNavHidden:YES）──
      case 'jsPushSpecial':
      case 'jsPushSpecialContentList':
      case 'jsPushPoliticalDetail':
        final link = '${dic['content_link'] ?? dic['link'] ?? dic['url'] ?? ''}'
            .trim();
        if (link.isNotEmpty && mounted) {
          _pushWebRoute(link, nativeNavBar: false, bridgeDic: dic);
        }

      // ── 直播详情：有原生导航栏，链接字段 liveDetailUrl ────────────────
      case 'jsPushLiveDetail':
        final link =
            '${dic['liveDetailUrl'] ?? dic['link'] ?? dic['url'] ?? ''}'.trim();
        if (link.isNotEmpty && mounted) {
          _pushWebRoute(link, nativeNavBar: true, bridgeDic: dic);
        }

      // ── 其它内容类型（iOS 多为空实现 / 详情壳）：无导航栏占位跳转 ───
      case 'jsPushVideo':
      case 'jsPushMpVideo':
      case 'jsPushDoc':
      case 'jsPushAudio':
      case 'jsPushGallery':
      case 'jsPushDocEditor':
      case 'jsPushCategoryList':
      case 'jsPushApplyForm':
        final link =
            '${dic['link'] ?? dic['url'] ?? dic['articleUrl'] ?? dic['content_link'] ?? ''}'
                .trim();
        if (link.isNotEmpty && mounted) {
          _pushWebRoute(link, nativeNavBar: false, bridgeDic: dic);
        }

      // ── 获取内容详情（直接回调）──────────────
      case 'jsGetVideoDetailInfo':
      case 'jsGetNoticeDetail':
        final data = {'code': '0', 'data': dic};
        if (cbk != null && cbk.isNotEmpty) _h5Callback(cbk, data);

      // ── 打开外部浏览器 ────────────────────────
      case 'jsOpenBrowser':
        final url = (dic['url'] ?? '') as String;
        if (url.isNotEmpty) _launchExternalUrl(url);

      // ── 返回首页 ──────────────────────────────
      case 'jsBackHome':
        if (mounted) {
          while (context.canPop()) {
            context.pop();
          }
        }

      // ── 分享 ─────────────────────────────────
      case 'jsShare':
      case 'jsSettingShare':
      case 'jsShareVideo':
      case 'jsShareSpecial':
        _handleShare(dic);

      // ── Toast ────────────────────────────────
      case 'jsToastMessage':
        final message = (dic['message'] ?? dic['text'] ?? '') as String;
        if (message.isNotEmpty) _toast(message);

      // ── 协议页 ────────────────────────────────
      case 'jsPushUserAgreement':
      case 'PushUserAgreement':
        _pushConfiguredAgreement(privacy: false);

      case 'jsPushPrivacyNotice':
      case 'PushPrivacyNotice':
        _pushConfiguredAgreement(privacy: true);

      // ── 用户主页 ──────────────────────────────
      case 'jsPushMpUser':
        final userId = (dic['user_id'] ?? dic['uid'] ?? '') as String;
        if (userId.isNotEmpty && mounted) {
          _localizedText('user_homepage', fallback: '').then((title) {
            if (!mounted) return;
            context.push(
              '/web?link=about:blank&title=${Uri.encodeComponent(title)}',
            );
          });
        }

      // ── 微信小程序（Flutter 端不支持）────────
      case 'jsPushWXMiniApp':
        _toastLocalized('wechat_open_hint', fallback: '');

      // ── 社交互动（打点 + 回调）───────────────
      case 'jsDiggVideo':
      case 'jsCollectVideo':
      case 'jsCollectSpecial':
      case 'jsStarMpUser':
        debugPrint('[STBridge] 社交互动: $funcType $dic');
        if (cbk != null && cbk.isNotEmpty) {
          _h5Callback(cbk, {'code': '0'});
        }

      // ── 邀请码下载 ────────────────────────────
      case 'jsDwonloadInviteCode':
        _handleShare(dic);

      // ── 下一篇内容 ────────────────────────────
      case 'jsToNextContent':
      // 由 web 端自身路由处理

      // ── 申请地区 ──────────────────────────────
      case 'jsApplyForArea':
      // no-op

      // ── mcSdk bridge ready ────────────────────
      case 'mcJssdkBridgeReady':
        _jsBridgeInvoke(cbk ?? '', success: true);

      // ── 以下为无需 native 干预的幂等事件 ──────
      case 'jsTopBackHome':
        _popToRootOnNextNativeBack = true;

      case 'jsContentHeight':
      case 'jsPushApplyState':
        break;

      default:
        debugPrint('[STBridge] 未处理的 funcType: $funcType');
        // 回调空成功，避免 web 端挂起
        if (cbk != null && cbk.isNotEmpty) {
          _h5Callback(cbk, {'code': '-1', 'msg': 'unsupported'});
        }
    }
  }

  // ─────────────────────────────────────────────
  // __mcJssdkBridge（对齐 iOS JsFunctionBridge / STJSBridgeModel）
  // ─────────────────────────────────────────────

  /// 对齐 iOS `jsBridgeWithMessage:` → STJSBridgeModel：
  /// `{ method, callback, params }` 格式（与 funcType 协议不同）。
  void _handleMcJssdkBridge(String raw) {
    debugPrint('[mcJssdkBridge] ← $raw');
    final parsed = _parseBridgeMessage(raw);
    if (parsed == null) return;
    final msg = parsed;
    final method = (msg['method'] as String? ?? '').trim();
    final callback = (msg['callback'] as String? ?? '');

    Map<String, dynamic> paramMap = {};
    final rawParams = msg['params'];
    if (rawParams is Map) {
      paramMap = Map<String, dynamic>.from(rawParams);
    } else if (rawParams is String && rawParams.trim().isNotEmpty) {
      try {
        final d = jsonDecode(rawParams);
        if (d is Map) paramMap = Map<String, dynamic>.from(d);
      } catch (_) {}
    }

    switch (method) {
      case 'getUserInfo':
        _buildUserInfoPayload().then((data) {
          if (callback.isNotEmpty) {
            _runJs(
              'typeof $callback==="function"&&$callback(${jsonEncode(data)})',
            );
          }
        });
        break;
      case 'login':
        _requireLogin(
          onSuccess: () {
            _buildUserInfoPayload().then((data) {
              if (callback.isNotEmpty) {
                _runJs(
                  'typeof $callback==="function"&&$callback(${jsonEncode(data)})',
                );
              }
            });
          },
        );
        break;
      case 'getRiseColor':
        if (callback.isNotEmpty) {
          _runJs(
            'typeof $callback==="function"&&$callback(${jsonEncode(_riseColorBridgePayload())})',
          );
        }
        break;
      case 'closePage':
        _forceClosePage();
        break;
      case 'openUrl':
        final url = (paramMap['url'] ?? '') as String;
        if (url.isNotEmpty) _launchExternalUrl(url);
        break;
      default:
        // 通过 mcJssdkBridge invoke 回调
        _jsBridgeInvoke(
          callback,
          success: false,
          data: {'msg': 'unsupported:$method'},
        );
    }
  }

  // ─────────────────────────────────────────────
  // JS API：体系二（STMini method 协议）
  // 完整对齐 iOS STWebApiManager.swift + 扩展方法
  // ─────────────────────────────────────────────

  void _handleMiniApi(String raw) {
    debugPrint('[STMiniApi] ← $raw');
    final msg = _parseBridgeMessage(raw);
    if (msg == null) {
      debugPrint('[STMiniApi] 无法解析 JSON: $raw');
      return;
    }

    final method = (msg['method'] as String? ?? '').trim();

    Map<String, dynamic> params = {};
    final rawParamsMini = msg['params'];
    if (rawParamsMini is Map) {
      params = Map<String, dynamic>.from(rawParamsMini);
    } else if (rawParamsMini is String && rawParamsMini.trim().isNotEmpty) {
      try {
        final d = jsonDecode(rawParamsMini);
        if (d is Map) params = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    final methodId = params['methodId']?.toString();

    switch (method) {
      // ── 关闭页面（强制关，不退历史）──────────
      case 'close':
        _forceClosePage();
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 历史回退（对齐 iOS：先回退 web 历史，无历史则 pop）───────────────
      case 'navigateBack':
        final controller = _controller;
        if (controller == null) break;
        controller.canGoBack().then((can) {
          if (can) {
            controller.goBack();
            _updateCanGoBack();
          } else {
            _nativeBackAction();
          }
        });
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 页面内跳转 ────────────────────────────
      case 'navigateTo':
        final url = (params['url'] as String? ?? '');
        if (url.isNotEmpty && mounted) {
          final replace = _truthy(params['isReplace']);
          void go(String loc) {
            if (replace) {
              context.pushReplacement(loc);
            } else {
              context.push(loc);
            }
          }

          if (url.startsWith('http')) {
            go(Uri(path: '/web', queryParameters: {'link': url}).toString());
          } else if (url.startsWith(_Prefix.miniOnline) ||
              url.startsWith(_Prefix.miniLocal)) {
            go(Uri(path: '/mini', queryParameters: {'link': url}).toString());
          }
        }
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 重新加载 ──────────────────────────────
      case 'reLaunch':
        _controller?.reload();
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 返回首页 ──────────────────────────────
      case 'switchTab':
        final index = (params['index'] as num?)?.toInt() ?? 0;
        debugPrint('[STMiniApi] switchTab index=$index');
        if (mounted) {
          while (context.canPop()) {
            context.pop();
          }
        }
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 登录 ─────────────────────────────────
      case 'login':
        _requireLogin(
          onSuccess: () {
            _replyUserInfo(method, methodId: methodId);
          },
        );

      // ── 用户信息（合作中心等 H5 启动时会 await，必须 code=1）──
      case 'getUserInfo':
        _replyUserInfo(method, methodId: methodId);
        break;

      // ── 涨跌颜色（对齐 iOS STScriptMessageHandler getRiseColor）───────
      case 'getRiseColor':
        _miniCallback(
          method,
          code: '1',
          data: _riseColorBridgeData(),
          methodId: methodId,
        );
        break;

      // ── 包名（axios 拦截器会调用）────────────────────────────
      case 'getPackageName':
        _replyPackageName(method, methodId: methodId);
        break;

      // ── Token ────────────────────────────────
      case 'getToken':
        final user = ref.read(userStateProvider);
        _miniCallback(
          method,
          code: user.hasAuthToken ? '1' : '0',
          data: user.token,
          methodId: methodId,
        );

      // ── Toast ─────────────────────────────────
      case 'showToast':
        final text = (params['title'] ?? params['message'] ?? '') as String;
        if (text.isNotEmpty) _toast(text);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 复制 ─────────────────────────────────
      case 'setClipboardData':
        final text = (params['data'] ?? '') as String;
        if (text.isNotEmpty) Clipboard.setData(ClipboardData(text: text));
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 读取剪切板 ────────────────────────────
      case 'getClipboardData':
        Clipboard.getData(Clipboard.kTextPlain).then((data) {
          _miniCallback(method, code: '0', data: {'data': data?.text ?? ''});
        });

      // ── 外部浏览器 ────────────────────────────
      case 'openUrl':
        final url = (params['url'] ?? '') as String;
        if (url.isNotEmpty) _launchExternalUrl(url);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 分享 ─────────────────────────────────
      case 'share':
        _handleShare(params);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 设置标题 ──────────────────────────────
      case 'setNavigationBarTitle':
        final title = (params['title'] ?? '') as String;
        if (title.isNotEmpty && mounted) setState(() => _appBarTitle = title);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 导航栏颜色 ────────────────────────────
      case 'setNavigationBarColor':
        final bg =
            (params['backgroundColor'] ?? params['frontColor'] ?? '') as String;
        if (bg.isNotEmpty && mounted) {
          final color = _parseHexColor(bg);
          if (color != null) setState(() => _navBarColorOverride = color);
        }
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 显示/隐藏导航栏 ───────────────────────
      case 'hideNavBar':
        if (mounted) setState(() => _navBarVisible = false);
        _miniCallback(method, code: '1', methodId: methodId);

      case 'showNavBar':
        if (mounted) setState(() => _navBarVisible = true);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 系统信息 ─────────────────────────────
      case 'getSystemInfo':
        _miniCallback(method, code: '0', data: _buildSystemInfoPayload());

      // ── 震动 ─────────────────────────────────
      case 'vibrate':
      case 'vibrateShort':
        HapticFeedback.mediumImpact();
        _miniCallback(method, code: '1', methodId: methodId);

      case 'vibrateLong':
        HapticFeedback.heavyImpact();
        _miniCallback(method, code: '1', methodId: methodId);

      // ── Loading ───────────────────────────────
      case 'showLoading':
        if (mounted) setState(() => _isLoading = true);
        _miniCallback(method, code: '1', methodId: methodId);

      case 'hideLoading':
        if (mounted) setState(() => _isLoading = false);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 扫码（Flutter 暂不支持，返回错误）───
      case 'scanCode':
        _miniCallback(method, code: '0', methodId: methodId, data: {'msg': ''});

      // ── 图片预览 ──────────────────────────────
      case 'previewImage':
        final url =
            (params['urls'] as List?)?.firstOrNull?.toString() ??
            (params['current'] ?? '') as String;
        if (url.isNotEmpty) _launchExternalUrl(url);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── 文件下载 ──────────────────────────────
      case 'downloadFile':
        final url = (params['url'] ?? '') as String;
        if (url.isNotEmpty) _launchExternalUrl(url);
        _miniCallback(method, code: '1', methodId: methodId);

      // ── Web Storage 透传（浏览器已自带，这里回调 ok）──
      case 'setStorage':
      case 'removeStorage':
        _miniCallback(method, code: '1', methodId: methodId);

      case 'getStorage':
        _miniCallback(method, code: '0', data: {'data': ''});

      // ── bridge ready ──────────────────────────
      case 'mcJssdkBridgeReady':
        _miniCallback(method, code: '1', methodId: methodId);

      default:
        debugPrint('[STMiniApi] 未处理的 method: $method');
        _miniCallback(method, code: '0', methodId: methodId, data: {'msg': ''});
    }
  }

  // ─────────────────────────────────────────────
  // 回调辅助（对齐 iOS 各回调格式）
  // ─────────────────────────────────────────────

  void _h5Callback(String fn, Map<String, dynamic> payload) {
    if (fn.isEmpty) return;
    _runJs('typeof $fn === "function" && $fn(${jsonEncode(payload)})');
  }

  void _h5AppCallback(String funcType, Map<String, dynamic> payload) {
    final map = {'funcType': funcType, 'code': 0, 'data': payload};
    _runJs(
      'typeof appCallBack === "function" && appCallBack(${jsonEncode(map)})',
    );
  }

  void _h5MediaCloudCallback(String funcType, Map<String, dynamic> data) {
    final map = {'data': data, 'method': funcType, 'errId': '0'};
    _runJs(
      'typeof window.mediaCloudCallback === "function" && window.mediaCloudCallback(${jsonEncode(map)})',
    );
  }

  Map<String, String> _riseColorBridgeData() {
    final type = ref.read(userStateProvider).riseAndFallType;
    return {'type': type == RiseAndFallType.riseRed ? '1' : '0'};
  }

  Map<String, dynamic> _riseColorBridgePayload() {
    return {'code': '1', 'data': _riseColorBridgeData()};
  }

  void _jsBridgeInvoke(
    String callBack, {
    required bool success,
    Map<String, dynamic>? data,
  }) {
    if (callBack.isEmpty) return;
    final payload = {'code': success ? '0' : '-1', 'data': data};
    _runJs(
      "window.mcSdk && typeof window.mcSdk.trigger === 'function' && window.mcSdk.trigger('$callBack','${jsonEncode(payload)}')",
    );
  }

  /// 对齐 iOS `STScriptMessageHandler.callBack:`：`code=1` 成功，`code=0` 失败。
  void _miniCallback(
    String method, {
    required String code,
    Object? data,
    String? methodId,
  }) {
    final map = <String, dynamic>{
      'method': method,
      'code': code,
      'data': data ?? {},
      if (methodId != null && methodId.isNotEmpty) 'methodId': methodId,
    };
    debugPrint('[STMiniApi] → CMSJsCallBack $map');
    _runJs(
      'typeof CMSJsCallBack === "function" && CMSJsCallBack(${jsonEncode(map)})',
    );
  }

  Future<void> _replyUserInfo(String method, {String? methodId}) async {
    final data = await _buildUserInfoPayload();
    _miniCallback(method, code: '1', data: data, methodId: methodId);
  }

  Future<void> _replyPackageName(String method, {String? methodId}) async {
    final pkg = await PackageInfo.fromPlatform();
    _miniCallback(
      method,
      code: '1',
      data: {'packageName': pkg.packageName},
      methodId: methodId,
    );
  }

  void _sendLifecycleMessage(String method, {Map<String, dynamic>? params}) {
    final map = {'method': method, 'params': params ?? {}};
    _runJs(
      'typeof CMSCallJsMessage === "function" && CMSCallJsMessage(${jsonEncode(map)})',
    );
    // H5 体系也需要同样的生命周期通知
    if (method == 'pageWillAppear') {
      _runJs(
        "typeof window.pageWillAppear === 'function' && window.pageWillAppear()",
      );
    } else if (method == 'pageWillDisAppear') {
      _runJs(
        "typeof window.pageWillDisAppear === 'function' && window.pageWillDisAppear()",
      );
    }
  }

  // ─────────────────────────────────────────────
  // 主题（深色模式）
  // ─────────────────────────────────────────────

  void _notifyTheme() {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modeStr = isDark ? 'dark' : 'light';
    _sendLifecycleMessage('darkModeChanged', params: {'mode': modeStr});
    _runJs("typeof HtmlSetLDMode === 'function' && HtmlSetLDMode('$modeStr')");
    _runJs(
      "typeof window.STThemeChange === 'function' && window.STThemeChange($isDark)",
    );
    _runJs(
      "document.body && document.body.classList.toggle('dark-mode', $isDark)",
    );
  }

  // ─────────────────────────────────────────────
  // 数据载荷
  // ─────────────────────────────────────────────

  /// 对齐 iOS `STScriptMessageInfoHelp.htmlJSFetchUserInfo` 扁平字段。
  Future<Map<String, dynamic>> _buildUserInfoPayload() async {
    final user = ref.read(userStateProvider);
    final locale = ref.read(appLocaleProvider);
    final languageCode = languageCodeFromLocale(locale);
    final deviceId = await DeviceIdManager.getDeviceId();
    final pkg = await PackageInfo.fromPlatform();
    final isDark = mounted && Theme.of(context).brightness == Brightness.dark;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    final map = <String, dynamic>{
      'ab': user.isB ? 'b' : 'a',
      'language_code': languageCode,
      'token': user.token,
      'device_id': deviceId,
      'device_type': isIos ? 'ios' : 'android',
      'dark_mode': isDark ? '1' : '0',
      'appVersion': pkg.version,
      'timeZone': user.selectedTimeZone,
      'funds_password_status': user.isBindFundPassword ? '1' : '0',
    };

    if (user.userId.isNotEmpty) {
      map['id'] = user.userId;
    }
    if (user.nickname.isNotEmpty) {
      map['nickName'] = user.nickname;
    }

    return map;
  }

  Map<String, dynamic> _buildDeviceInfoPayload() {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return {
      'os': isIos ? 'iOS' : 'Android',
      'type': isIos ? 'iPhone' : 'Android',
      'version': '18.0',
      'APPVersion': '1.0.0',
      'JSSDKVersion': '1.2.0',
      'appName': 'jufu',
      'brand': isIos ? 'Apple' : 'Android',
    };
  }

  Map<String, dynamic> _buildSystemInfoPayload() {
    if (!mounted) return _buildDeviceInfoPayload();
    final mq = MediaQuery.of(context);
    return {
      ..._buildDeviceInfoPayload(),
      'screenWidth': mq.size.width,
      'screenHeight': mq.size.height,
      'statusBarHeight': mq.padding.top,
      'safeAreaInsetBottom': mq.padding.bottom,
      'pixelRatio': mq.devicePixelRatio,
      'language': 'zh-CN',
      'fontSizeSetting': mq.textScaler.scale(14),
    };
  }

  // ─────────────────────────────────────────────
  // 导航与辅助
  // ─────────────────────────────────────────────

  void _requireLogin({required VoidCallback onSuccess}) {
    final user = ref.read(userStateProvider);
    if (user.isLogin) {
      onSuccess();
      return;
    }
    if (mounted) {
      context.push('/auth/login').then((_) {
        if (ref.read(userStateProvider).isLogin) onSuccess();
      });
    }
  }

  void _handleShare(Map<String, dynamic> dic) {
    debugPrint('[WebView] 分享请求: $dic');
    // TODO: 接入原生分享 Share.share(...)
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[WebView] launchUrl error: $e');
    }
  }

  Future<void> _runJs(String script) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      debugPrint('[WebView] runJavaScript error: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    STToast.show(context, msg);
  }

  Future<String> _localizedText(String key, {required String fallback}) {
    return STLocalizations.ofContext(context).text(key, fallback: fallback);
  }

  void _toastLocalized(String key, {required String fallback}) {
    _localizedText(key, fallback: fallback).then((text) {
      if (!mounted) return;
      _toast(text);
    });
  }

  Future<Map<String, String>> _localizedWebViewMenuText() {
    return STLocalizations.ofContext(context).textMap(_webViewFallbackText);
  }

  static Color? _parseHexColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      final value = int.parse(
        cleaned.length == 6 ? 'FF$cleaned' : cleaned,
        radix: 16,
      );
      return Color(value);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 构建 UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(userStateProvider.select(_userInfoSignature), (
      previous,
      next,
    ) {
      if (previous == null || previous == next) return;
      if (!widget.visible || !_controllerReady) return;
      _sendLifecycleMessage('updateUserInfo');
    });

    final webWidget = _buildWebStack();

    if (_cfg.embedded) return webWidget;

    // PopScope：系统返回走 onPop；屏幕边缘侧滑单独命中窄条，避免与 H5 横滑抢手势
    final withPop = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // 对齐 iOS：物理返回键同样触发 _nativeBackAction
        // ignore: use_build_context_synchronously
        _nativeBackAction();
      },
      child: _EdgeSwipeToPop(
        onPop: _nativeBackAction,
        child: _isMini
            ? _buildMiniScaffold(webWidget)
            : _buildH5Scaffold(webWidget),
      ),
    );

    return withPop;
  }

  static String _userInfoSignature(UserState state) {
    return [
      state.isLogin,
      state.userId,
      state.token,
      state.nickname,
      state.avatarUrl,
      state.isAuthed,
      state.phone,
      state.email,
    ].join('|');
  }

  Widget _buildWebStack() {
    if (!_controllerReady || _controller == null) {
      return _buildLoadingOverlay();
    }
    if (_pendingLoad) {
      _pendingLoad = false;
      _scheduleLoad(_loadInitialUrl);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading) _buildLoadingOverlay(),
        if (_loadError != null) _buildErrorOverlay(),
      ],
    );
  }

  Widget _buildErrorOverlay() {
    return ColoredBox(
      key: const ValueKey('st-web-error-overlay'),
      color: _webShellColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: _webSecondaryTextColor,
              ),
              const SizedBox(height: 16),
              Text(
                _loadError ?? '页面加载失败',
                textAlign: TextAlign.center,
                style: TextStyle(color: _webSecondaryTextColor, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _loadError = null;
                    _isLoading = true;
                  });
                  _controller?.reload();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: STLocalizedText('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── H5 Scaffold ──────────────────────────────

  Widget _buildH5Scaffold(Widget body) {
    // showNavigationBar 默认 false（iOS 行为）
    // 运行时可被 jsHideNavBar / jsShowNavBar 动态切换
    final showBar = _cfg.showNavigationBar && _navBarVisible;
    return Scaffold(
      backgroundColor: _webShellColor,
      appBar: showBar ? _buildH5AppBar() : null,
      body: ColoredBox(color: _webShellColor, child: body),
    );
  }

  AppBar _buildH5AppBar() {
    // 对齐 iOS cmsNav：
    // - 返回按钮 (←) 始终触发 _nativeBackAction（直接 pop，不退 web 历史）
    // - 当 WebView 有内部历史时（_webCanGoBack），在 leading 右侧额外显示关闭（×）按钮
    //   对应 iOS `[self.cmsNav hiddenWebCloseBtn:!ret]`
    return AppBar(
      backgroundColor: _effectiveNavBarColor,
      elevation: 0,
      systemOverlayStyle: _webOverlayStyle,
      centerTitle: true,
      leadingWidth: _webCanGoBack ? 88 : 56,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ← 返回按钮（始终 popViewController，对齐 iOS backAction）
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: _webTextColor,
            ),
            onPressed: _nativeBackAction,
            tooltip: '',
            padding: const EdgeInsets.symmetric(horizontal: 8),
            constraints: const BoxConstraints(minWidth: 40),
          ),
          // × 关闭按钮（仅当 WebView 有历史时显示，对齐 iOS hiddenWebCloseBtn）
          if (_webCanGoBack)
            GestureDetector(
              onTap: _forceClosePage,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _webPillColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.close, size: 16, color: _webTextColor),
              ),
            ),
        ],
      ),
      title: Text(
        _appBarTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _webTextColor,
        ),
      ),
      // iOS only installs a right-side H5 button when
      // STBaseWebViewController.isShare is explicitly enabled.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: _webDividerColor),
      ),
    );
  }

  // ── Mini Scaffold ────────────────────────────

  Widget _buildMiniScaffold(Widget body) {
    return Scaffold(
      backgroundColor: _webShellColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (_navBarVisible)
            Positioned(top: 0, left: 0, right: 0, child: _buildMiniNavBar()),
        ],
      ),
    );
  }

  Widget _buildMiniNavBar() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _webOverlayStyle,
      child: Container(
        key: const ValueKey('st-mini-nav-bar'),
        color: _effectiveNavBarColor,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 8,
          right: 8,
        ),
        height: MediaQuery.of(context).padding.top + 48,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: _webTextColor,
              ),
              onPressed: _nativeBackAction,
              tooltip: '',
            ),
            Expanded(
              child: Text(
                _appBarTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _webTextColor,
                ),
              ),
            ),
            _buildCapsuleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleButton() {
    return Container(
      key: const ValueKey('st-mini-capsule-button'),
      height: 32,
      decoration: BoxDecoration(
        color: _webPillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _webDividerColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _showMiniMoreSheet,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.more_horiz, size: 18, color: _webTextColor),
            ),
          ),
          Container(width: 0.5, height: 18, color: _webDividerColor),
          GestureDetector(
            onTap: _forceClosePage,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.close, size: 18, color: _webTextColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showMiniMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => FutureBuilder<Map<String, String>>(
        future: _localizedWebViewMenuText(),
        builder: (context, snapshot) {
          final labels = snapshot.data ?? _webViewFallbackText;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(labels['refresh'] ?? '刷新'),
                  onTap: () {
                    Navigator.pop(context);
                    _controller?.reload();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text(labels['copy_link'] ?? '复制链接'),
                  onTap: () {
                    Navigator.pop(context);
                    _controller?.currentUrl().then((url) {
                      if (url != null) {
                        Clipboard.setData(ClipboardData(text: url));
                        _toastLocalized('copy_toast_tip', fallback: '');
                      }
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_browser_rounded),
                  title: Text(labels['open_in_browser'] ?? '浏览器打开'),
                  onTap: () {
                    Navigator.pop(context);
                    _controller?.currentUrl().then((url) {
                      if (url != null) _launchExternalUrl(url);
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return IgnorePointer(
      child: ColoredBox(
        key: const ValueKey('st-web-loading-overlay'),
        color: _webShellColor,
        child: const SizedBox.expand(
          child: Center(child: STLoadAnimationView()),
        ),
      ),
    );
  }
}

/// 屏幕「返回方向」边缘窄条上的水平滑动手势，对齐 iOS 导航栏 interactive pop（不铺满全屏，减少与 Web 横滑冲突）。
class _EdgeSwipeToPop extends StatefulWidget {
  final Widget child;
  final VoidCallback onPop;

  const _EdgeSwipeToPop({required this.child, required this.onPop});

  @override
  State<_EdgeSwipeToPop> createState() => _EdgeSwipeToPopState();
}

class _EdgeSwipeToPopState extends State<_EdgeSwipeToPop> {
  static const double _edgeStripWidth = 28;

  double _accumulated = 0;

  void _reset() => _accumulated = 0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const w = _edgeStripWidth;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: rtl ? null : 0,
          right: rtl ? 0 : null,
          top: 0,
          bottom: 0,
          width: w,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _reset(),
            onHorizontalDragUpdate: (d) {
              if (rtl) {
                _accumulated -= d.delta.dx;
              } else {
                _accumulated += d.delta.dx;
              }
            },
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              final go = rtl
                  ? (_accumulated > 56 || v < -300)
                  : (_accumulated > 56 || v > 300);
              _reset();
              if (go) widget.onPop();
            },
            onHorizontalDragCancel: _reset,
          ),
        ),
      ],
    );
  }
}
