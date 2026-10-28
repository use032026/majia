import 'package:cleantrail/app/app_localizations.dart';
import 'package:cleantrail/app/privacy_policy_config.dart';
import 'package:cleantrail/ui/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/recording_webview_platform.dart';

void main() {
  late RecordingWebViewPlatform platform;

  setUp(() {
    platform = RecordingWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  test('privacy URL defaults to the published policy in both languages', () {
    expect(privacyPolicyUrl, 'https://astfx1.com/privacy.html');
    expect(
      privacyPolicyUri(useChinese: true).toString(),
      'https://astfx1.com/privacy.html?lang=zh',
    );
    expect(
      privacyPolicyUri(useChinese: false).toString(),
      'https://astfx1.com/privacy.html?lang=en',
    );
  });

  test('privacy URL rejects empty and invalid addresses', () {
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
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    for (final value in ['', 'not-a-url']) {
      await tester.pumpWidget(_app(value, key: ValueKey(value)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacy-policy-fallback')), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byKey(const Key('privacy-policy-retry')), findsNothing);
      expect(platform.controllerCreations, 0);
      expect(tester.takeException(), isNull);
    }
  });

  for (final chinese in [false, true]) {
    testWidgets(
      'default policy opens in-app in ${chinese ? 'Chinese' : 'English'}',
      (tester) async {
        await tester.pumpWidget(_app(null, chinese: chinese));
        await tester.pumpAndSettle();
        expect(find.text(chinese ? '隐私与数据' : 'Privacy & data'), findsOneWidget);
        expect(find.byKey(const Key('recorded-web-document')), findsOneWidget);
        expect(find.byKey(const Key('privacy-policy-fallback')), findsNothing);
        expect(
          platform.controller.requests.single.toString(),
          'https://astfx1.com/privacy.html?lang=${chinese ? 'zh' : 'en'}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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

Widget _app(String? url, {bool chinese = false, Key? key}) => MaterialApp(
  key: key,
  locale: Locale(chinese ? 'zh' : 'en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: url == null ? const PrivacyPolicyPage() : PrivacyPolicyPage(url: url),
);
