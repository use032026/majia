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

class _PrivacyWebPageState extends State<PrivacyWebPage>
    with WidgetsBindingObserver {
  static const String _privacyUrlEn =
      'https://wowsteady.com/privacy.html?lang=en';
  static const String _privacyUrlZh =
      'https://wowsteady.com/privacy.html?lang=zh';

  late WebViewController _webViewController;
  bool _showingLocalSummary = false;
  bool _loadingRemote = true;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPrivacyPage(_webViewController, ++_loadId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showingLocalSummary) {
      _retryOnline();
    }
  }

  void _retryOnline() {
    if (_loadingRemote || !_showingLocalSummary) return;
    final controller = WebViewController();
    final loadId = ++_loadId;
    setState(() {
      _webViewController = controller;
      _showingLocalSummary = false;
      _loadingRemote = true;
    });
    unawaited(_loadPrivacyPage(controller, loadId));
  }

  Future<void> _loadPrivacyPage(
    WebViewController controller,
    int loadId,
  ) async {
    final officialUrl = Uri.parse(
      widget.copy.isZh ? _privacyUrlZh : _privacyUrlEn,
    );
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted && loadId == _loadId && !_showingLocalSummary) {
              setState(() => _loadingRemote = false);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true &&
                (error.url == null || error.url == officialUrl.toString())) {
              unawaited(_loadLocalSummary(controller, loadId));
            }
          },
          onHttpError: (error) {
            if (error.request?.uri == officialUrl &&
                (error.response?.statusCode ?? 0) >= 400) {
              unawaited(_loadLocalSummary(controller, loadId));
            }
          },
        ),
      );
      await controller.loadRequest(officialUrl);
    } catch (_) {
      await _loadLocalSummary(controller, loadId);
    }
  }

  Future<void> _loadLocalSummary(
    WebViewController controller,
    int loadId,
  ) async {
    if (!mounted || loadId != _loadId || _showingLocalSummary) return;
    setState(() {
      _showingLocalSummary = true;
      _loadingRemote = false;
    });
    await controller.setJavaScriptMode(JavaScriptMode.disabled);
    await controller.loadHtmlString(_localPrivacyHtml(widget.copy));
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
      body: Column(
        children: [
          if (_showingLocalSummary)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.copy.t(
                      '在线隐私协议暂时无法加载，以下仅为本地摘要。',
                      'The online privacy policy is unavailable. This is a local summary only.',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('privacyRetryOnline'),
                      onPressed: _retryOnline,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        widget.copy.t('重新加载在线协议', 'Retry online policy'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_loadingRemote) const LinearProgressIndicator(),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_loadId),
              child: WebViewWidget(
                key: const Key('privacyWebView'),
                controller: _webViewController,
              ),
            ),
          ),
        ],
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
