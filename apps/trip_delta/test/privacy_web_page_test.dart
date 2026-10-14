import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_delta/privacy_web_page.dart';
import 'package:trip_delta/strings.dart';

void main() {
  test('online policy accepts only HTTPS addresses', () {
    expect(parsePrivacyPolicyUrl(''), isNull);
    expect(parsePrivacyPolicyUrl('http://example.com/privacy'), isNull);
    expect(
      parsePrivacyPolicyUrl('https://example.com/privacy')?.host,
      'example.com',
    );
  });

  test('published policy URL follows the selected language', () {
    expect(
      configuredPrivacyPolicyUrl(true).toString(),
      'https://gotripdelta.com/privacy.html?lang=zh',
    );
    expect(
      configuredPrivacyPolicyUrl(false).toString(),
      'https://gotripdelta.com/privacy.html?lang=en',
    );
  });

  testWidgets('published Chinese policy keeps a local summary if offline', (
    tester,
  ) async {
    final browser = FakePrivacyBrowser(1);
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(l: const L(true), browserFactory: () => browser),
      ),
    );
    await tester.pump();
    expect(
      browser.loadedUrl.toString(),
      'https://gotripdelta.com/privacy.html?lang=zh',
    );
    browser.fail!();
    await tester.pump();
    expect(find.textContaining('在线隐私政策暂时无法加载'), findsOneWidget);
    expect(find.text('本地数据说明'), findsOneWidget);
    expect(find.byKey(const Key('privacy_retry_online')), findsOneWidget);
  });

  testWidgets('offline fallback retries with a fresh browser', (tester) async {
    final browsers = <FakePrivacyBrowser>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(
          l: const L(false),
          policyUrl: Uri.parse('https://example.com/privacy'),
          browserFactory: () {
            final browser = FakePrivacyBrowser(browsers.length + 1);
            browsers.add(browser);
            return browser;
          },
        ),
      ),
    );
    await tester.pump();
    expect(browsers.length, 1);
    expect(browsers.first.loadedUrl.toString(), 'https://example.com/privacy');
    browsers.first.fail!();
    await tester.pump();
    expect(
      find.textContaining('online privacy policy is unavailable'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('privacy_retry_online')), findsOneWidget);

    await tester.tap(find.byKey(const Key('privacy_retry_online')));
    await tester.pump();
    expect(browsers.length, 2);
    expect(find.text('Loading online privacy policy…'), findsOneWidget);
    browsers.first.finish!();
    await tester.pump();
    expect(find.text('Loading online privacy policy…'), findsOneWidget);
    browsers.last.finish!();
    await tester.pump();
    expect(find.text('Loading online privacy policy…'), findsNothing);
    expect(find.text('browser-2'), findsOneWidget);
  });

  testWidgets('returning from network settings retries local fallback', (
    tester,
  ) async {
    final browsers = <FakePrivacyBrowser>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(
          l: const L(false),
          policyUrl: Uri.parse('https://example.com/privacy'),
          browserFactory: () {
            final browser = FakePrivacyBrowser(browsers.length + 1);
            browsers.add(browser);
            return browser;
          },
        ),
      ),
    );
    await tester.pump();
    browsers.first.fail!();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(browsers.length, 2);
    expect(find.text('Loading online privacy policy…'), findsOneWidget);
  });

  testWidgets('main document error replaces an earlier finish callback', (
    tester,
  ) async {
    late FakePrivacyBrowser browser;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(
          l: const L(false),
          policyUrl: Uri.parse('https://example.com/privacy'),
          browserFactory: () => browser = FakePrivacyBrowser(1),
        ),
      ),
    );
    await tester.pump();
    browser.finish!();
    await tester.pump();
    browser.fail!();
    await tester.pump();
    expect(find.byKey(const Key('privacy_retry_online')), findsOneWidget);
  });
}

class FakePrivacyBrowser implements PrivacyPageBrowser {
  FakePrivacyBrowser(this.id);

  final int id;
  VoidCallback? finish;
  VoidCallback? fail;
  Uri? loadedUrl;

  @override
  Future<void> initialize(
    Uri url, {
    required VoidCallback onFinished,
    required VoidCallback onFailure,
  }) async {
    finish = onFinished;
    fail = onFailure;
  }

  @override
  Future<void> load(Uri url) async {
    loadedUrl = url;
  }

  @override
  Widget view() => Center(child: Text('browser-$id'));
}
