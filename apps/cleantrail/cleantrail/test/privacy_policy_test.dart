import 'package:cleantrail/app/app_localizations.dart';
import 'package:cleantrail/app/privacy_policy_config.dart';
import 'package:cleantrail/ui/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  late _RecordingWebViewPlatform platform;

  setUp(() {
    platform = _RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  test('privacy URL is empty by default and rejects invalid addresses', () {
    expect(privacyPolicyUrl, isEmpty);
    for (final value in [
      '',
      '   ',
      'not-a-url',
      'http://policy.example/privacy',
      'javascript:alert(1)',
      'https://',
      'https://user:secret@policy.example/privacy',
      'https://policy.example/a b',
    ]) {
      expect(privacyPolicyUri(url: value, useChinese: false), isNull);
    }
  });

  test('policy language preserves existing query values and fragment', () {
    const value =
        'https://policy.example/privacy?source=app&tag=a&tag=b&lang=fr#data';
    final chinese = privacyPolicyUri(url: value, useChinese: true)!;
    expect(chinese.queryParameters['lang'], 'zh');
    expect(chinese.queryParameters['source'], 'app');
    expect(chinese.queryParametersAll['tag'], ['a', 'b']);
    expect(chinese.fragment, 'data');
    expect(
      privacyPolicyUri(url: value, useChinese: false)!.queryParameters['lang'],
      'en',
    );
  });

  testWidgets('empty and invalid URLs never create a native WebView', (
    tester,
  ) async {
    for (final value in ['', 'not-a-url']) {
      await tester.pumpWidget(_app(value, key: ValueKey(value)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacy-policy-fallback')), findsOneWidget);
      expect(find.byKey(const Key('privacy-policy-retry')), findsNothing);
      expect(platform.controllerCreations, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('configured policy opens in-app with the current language', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app('https://policy.example/privacy?source=app', chinese: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('隐私与数据'), findsOneWidget);
    expect(find.byKey(const Key('recorded-web-document')), findsOneWidget);
    expect(
      platform.controller.requests.single.toString(),
      'https://policy.example/privacy?source=app&lang=zh',
    );
    expect(
      await platform.delegate.onNavigation!(
        const NavigationRequest(
          url: 'mailto:support@example.org',
          isMainFrame: true,
        ),
      ),
      NavigationDecision.prevent,
    );
  });

  testWidgets('main document failure remains visible until a retry succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(_app('https://policy.example/privacy'));
    await tester.pumpAndSettle();
    platform.delegate.onResourceError!(
      const WebResourceError(
        errorCode: -1009,
        description: 'Offline',
        isForMainFrame: true,
      ),
    );
    platform.delegate.onFinished!('https://policy.example/privacy?lang=en');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy-policy-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('privacy-policy-retry')));
    await tester.pumpAndSettle();
    expect(platform.controller.requests, hasLength(2));
    expect(
      platform.controller.requests.first,
      platform.controller.requests.last,
    );
    expect(find.byKey(const Key('privacy-policy-fallback')), findsNothing);
    expect(find.byKey(const Key('recorded-web-document')), findsOneWidget);
  });

  testWidgets('subresource errors do not replace a readable policy', (
    tester,
  ) async {
    await tester.pumpWidget(_app('https://policy.example/privacy'));
    await tester.pumpAndSettle();
    platform.delegate.onResourceError!(
      const WebResourceError(
        errorCode: -1,
        description: 'Missing image',
        isForMainFrame: false,
      ),
    );
    platform.delegate.onHttpError!(
      HttpResponseError(
        request: WebResourceRequest(
          uri: Uri.parse('https://policy.example/icon.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy-policy-fallback')), findsNothing);
    platform.delegate.onHttpError!(
      HttpResponseError(
        request: WebResourceRequest(uri: platform.controller.requests.single),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy-policy-retry')), findsOneWidget);
  });
}

Widget _app(String url, {bool chinese = false, Key? key}) => MaterialApp(
  key: key,
  locale: Locale(chinese ? 'zh' : 'en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: PrivacyPolicyPage(url: url),
);

class _RecordingWebViewPlatform extends WebViewPlatform {
  int controllerCreations = 0;
  late _RecordingController controller;
  late _RecordingDelegate delegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    controllerCreations++;
    return controller = _RecordingController(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _RecordingDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _RecordingWidget(params);
}

class _RecordingController extends PlatformWebViewController {
  _RecordingController(super.params) : super.implementation();

  final requests = <Uri>[];
  late _RecordingDelegate delegate;

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => delegate = handler as _RecordingDelegate;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
    delegate.onStarted?.call(params.uri.toString());
    delegate.onProgress?.call(100);
    delegate.onFinished?.call(params.uri.toString());
  }
}

class _RecordingDelegate extends PlatformNavigationDelegate {
  _RecordingDelegate(super.params) : super.implementation();

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

class _RecordingWidget extends PlatformWebViewWidget {
  _RecordingWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('recorded-web-document'));
}
