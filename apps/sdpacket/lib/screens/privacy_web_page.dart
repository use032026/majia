import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app.dart';
import '../config/app_links.dart';

class PrivacyWebPage extends StatefulWidget {
  const PrivacyWebPage({super.key, required this.languageCode});

  final String languageCode;

  @override
  State<PrivacyWebPage> createState() => _PrivacyWebPageState();
}

class _PrivacyWebPageState extends State<PrivacyWebPage>
    with WidgetsBindingObserver {
  late WebViewController _controller;
  bool _loadingOnline = true;
  bool _showingLocalSummary = false;
  int _loadId = 0;

  Uri get _privacyUri =>
      Uri.parse(AppLinks.privacyPolicyUrlFor(widget.languageCode));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController();
    unawaited(_loadOnline(_controller, ++_loadId));
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
    if (_loadingOnline || !_showingLocalSummary) return;
    final controller = WebViewController();
    final loadId = ++_loadId;
    setState(() {
      _controller = controller;
      _loadingOnline = true;
      _showingLocalSummary = false;
    });
    unawaited(_loadOnline(controller, loadId));
  }

  Future<void> _loadOnline(WebViewController controller, int loadId) async {
    final uri = _privacyUri;
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted && loadId == _loadId && !_showingLocalSummary) {
              setState(() => _loadingOnline = false);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true &&
                (error.url == null || error.url == uri.toString())) {
              _showLocalSummary(loadId);
            }
          },
          onHttpError: (error) {
            if (error.request?.uri == uri &&
                (error.response?.statusCode ?? 0) >= 400) {
              _showLocalSummary(loadId);
            }
          },
        ),
      );
      await controller.loadRequest(uri);
    } catch (_) {
      _showLocalSummary(loadId);
    }
  }

  void _showLocalSummary(int loadId) {
    if (!mounted || loadId != _loadId || _showingLocalSummary) return;
    setState(() {
      _loadingOnline = false;
      _showingLocalSummary = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.privacy)),
      body: _showingLocalSummary
          ? ListView(
              key: const Key('privacy-local-summary'),
              padding: const EdgeInsets.all(20),
              children: [
                Text(context.l10n.localPrivacyFallback),
                const SizedBox(height: 20),
                Text(context.l10n.privacyBody),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('privacy-retry-online'),
                    onPressed: _retryOnline,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retryOnlinePrivacy),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                if (_loadingOnline) const LinearProgressIndicator(),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(_loadId),
                    child: WebViewWidget(
                      key: const Key('privacy-webview'),
                      controller: _controller,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
