import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'copy.dart';

class PrivacyWebPage extends StatefulWidget {
  const PrivacyWebPage({super.key, required this.copy});

  final AppCopy copy;

  @override
  State<PrivacyWebPage> createState() => _PrivacyWebPageState();
}

class _PrivacyWebPageState extends State<PrivacyWebPage> {
  static const String _privacyUrlEn =
      'https://wowsteady.com/privacy.html?lang=en';
  static const String _privacyUrlZh =
      'https://wowsteady.com/privacy.html?lang=zh';

  late final WebViewController _webViewController;
  bool _showingLocalSummary = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController();
    unawaited(_loadPrivacyPage());
  }

  Future<void> _loadPrivacyPage() async {
    final officialUrl = Uri.parse(
      widget.copy.isZh ? _privacyUrlZh : _privacyUrlEn,
    );
    await _webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webViewController.setNavigationDelegate(
      NavigationDelegate(
        onWebResourceError: (error) {
          if (error.isForMainFrame == true &&
              (error.url == null || error.url == officialUrl.toString())) {
            unawaited(_loadLocalSummary());
          }
        },
        onHttpError: (error) {
          if (error.request?.uri == officialUrl &&
              (error.response?.statusCode ?? 0) >= 400) {
            unawaited(_loadLocalSummary());
          }
        },
      ),
    );
    try {
      await _webViewController.loadRequest(officialUrl);
    } catch (_) {
      await _loadLocalSummary();
    }
  }

  Future<void> _loadLocalSummary() async {
    if (!mounted || _showingLocalSummary) return;
    _showingLocalSummary = true;
    await _webViewController.setJavaScriptMode(JavaScriptMode.disabled);
    await _webViewController.loadHtmlString(_localPrivacyHtml(widget.copy));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('privacyPageBackButton'),
          tooltip: widget.copy.t('返回设置', 'Back to Settings'),
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.copy.privacy),
      ),
      body: WebViewWidget(
        key: const Key('privacyWebView'),
        controller: _webViewController,
      ),
    );
  }
}

String _localPrivacyHtml(AppCopy copy) {
  final escape = const HtmlEscape();
  String safe(String value) => escape.convert(value);
  final language = copy.isZh ? 'zh-CN' : 'en';
  final title = safe(copy.privacy);
  final eyebrow = safe(copy.t('当前版本说明', 'CURRENT VERSION'));
  final introduction = safe(
    copy.t(
      '了解你在实验册中写下的内容如何保存。',
      'How the content you write in this journal is stored.',
    ),
  );
  final storageTitle = safe(copy.t('记录与存储', 'Records and storage'));
  final storageBody = safe(copy.privacyBody);
  final deletionTitle = safe(copy.t('管理你的记录', 'Manage your records'));
  final deletionBody = safe(
    copy.t(
      '你可以在设置中删除全部本地数据。删除后，应用内无法恢复这些记录。',
      'You can delete all local data in Settings. The app cannot restore those records afterward.',
    ),
  );
  return '''
<!doctype html>
<html lang="$language">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body { margin: 0; background: #f7f1e6; color: #17201d;
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; }
    main { max-width: 700px; margin: 0 auto; padding: 32px 22px 64px; }
    .eyebrow { color: #184c40; font-size: 12px; font-weight: 800; letter-spacing: 1.4px; }
    h1 { margin: 10px 0 8px; font-size: 34px; line-height: 1.2; letter-spacing: -0.6px; }
    .intro { margin: 0 0 24px; color: #53615c; font-size: 16px; line-height: 1.65; }
    section { margin: 0 0 12px; padding: 22px; background: #fffbf4;
      border: 1px solid #ded7ca; border-radius: 20px; }
    h2 { margin: 0 0 12px; font-size: 19px; }
    p { margin: 0; font-size: 16px; line-height: 1.75; overflow-wrap: anywhere; }
    @media (prefers-color-scheme: dark) {
      body { background: #111a18; color: #edf4f0; }
      .eyebrow { color: #8cd4be; }
      .intro { color: #b9c8c1; }
      section { background: #1a2623; border-color: #34453e; }
    }
  </style>
</head>
<body>
  <main>
    <div class="eyebrow">$eyebrow</div>
    <h1>$title</h1>
    <p class="intro">$introduction</p>
    <section><h2>$storageTitle</h2><p>$storageBody</p></section>
    <section><h2>$deletionTitle</h2><p>$deletionBody</p></section>
  </main>
</body>
</html>
''';
}
