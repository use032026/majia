import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class RecordingWebViewPlatform extends WebViewPlatform {
  int controllerCreations = 0;
  late RecordingWebViewController controller;
  late RecordingWebViewDelegate delegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    controllerCreations++;
    return controller = RecordingWebViewController(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = RecordingWebViewDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => RecordingWebViewWidget(params);
}

class RecordingWebViewController extends PlatformWebViewController {
  RecordingWebViewController(super.params) : super.implementation();

  final requests = <Uri>[];
  late RecordingWebViewDelegate delegate;

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => delegate = handler as RecordingWebViewDelegate;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
    delegate.onStarted?.call(params.uri.toString());
    delegate.onProgress?.call(100);
    delegate.onFinished?.call(params.uri.toString());
  }
}

class RecordingWebViewDelegate extends PlatformNavigationDelegate {
  RecordingWebViewDelegate(super.params) : super.implementation();

  PageEventCallback? onStarted;
  PageEventCallback? onFinished;
  ProgressCallback? onProgress;
  WebResourceErrorCallback? onResourceError;
  HttpResponseErrorCallback? onHttpError;
  NavigationRequestCallback? onNavigation;

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async =>
      onStarted = callback;

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      onFinished = callback;

  @override
  Future<void> setOnProgress(ProgressCallback callback) async =>
      onProgress = callback;

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      onResourceError = callback;

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async =>
      onHttpError = callback;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async => onNavigation = callback;
}

class RecordingWebViewWidget extends PlatformWebViewWidget {
  RecordingWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('recorded-web-document'));
}
