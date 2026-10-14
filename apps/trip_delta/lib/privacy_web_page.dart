import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'strings.dart';

const _sharedPolicyUrl = String.fromEnvironment('TRIP_DELTA_PRIVACY_URL');
const _zhPolicyUrl = String.fromEnvironment('TRIP_DELTA_PRIVACY_URL_ZH');
const _enPolicyUrl = String.fromEnvironment('TRIP_DELTA_PRIVACY_URL_EN');
const _defaultPolicyUrl = 'https://gotripdelta.com/privacy.html';

Uri? parsePrivacyPolicyUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

Uri? configuredPrivacyPolicyUrl(bool chinese) {
  final localizedOverride = chinese ? _zhPolicyUrl : _enPolicyUrl;
  return parsePrivacyPolicyUrl(
    localizedOverride.isNotEmpty
        ? localizedOverride
        : _sharedPolicyUrl.isNotEmpty
        ? _sharedPolicyUrl
        : '$_defaultPolicyUrl?lang=${chinese ? 'zh' : 'en'}',
  );
}

abstract class PrivacyPageBrowser {
  Future<void> initialize(
    Uri url, {
    required VoidCallback onFinished,
    required VoidCallback onFailure,
  });

  Future<void> load(Uri url);
  Widget view();
}

class _WebViewPrivacyBrowser implements PrivacyPageBrowser {
  final WebViewController _controller = WebViewController();

  @override
  Future<void> initialize(
    Uri url, {
    required VoidCallback onFinished,
    required VoidCallback onFailure,
  }) async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) => onFinished(),
        onWebResourceError: (error) {
          if (error.isForMainFrame == true &&
              (error.url == null || error.url == url.toString())) {
            onFailure();
          }
        },
        onHttpError: (error) {
          if (error.request?.uri == url &&
              (error.response?.statusCode ?? 0) >= 400) {
            onFailure();
          }
        },
      ),
    );
  }

  @override
  Future<void> load(Uri url) => _controller.loadRequest(url);

  @override
  Widget view() => WebViewWidget(controller: _controller);
}

typedef PrivacyBrowserFactory = PrivacyPageBrowser Function();

enum _PrivacyPagePhase { loading, online, local }

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({
    super.key,
    required this.l,
    this.policyUrl,
    this.browserFactory,
  });

  final L l;
  final Uri? policyUrl;
  final PrivacyBrowserFactory? browserFactory;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen>
    with WidgetsBindingObserver {
  late final Uri? _policyUrl;
  PrivacyPageBrowser? _browser;
  _PrivacyPagePhase _phase = _PrivacyPagePhase.local;
  Timer? _loadTimeout;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _policyUrl = widget.policyUrl ?? configuredPrivacyPolicyUrl(widget.l.zh);
    WidgetsBinding.instance.addObserver(this);
    if (_policyUrl != null) _startRemote(notify: false);
  }

  @override
  void dispose() {
    ++_loadId;
    _loadTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _phase == _PrivacyPagePhase.local) {
      _retryOnline();
    }
  }

  void _startRemote({bool notify = true}) {
    final url = _policyUrl;
    if (url == null) return;
    final browser = widget.browserFactory?.call() ?? _WebViewPrivacyBrowser();
    final loadId = ++_loadId;
    void apply() {
      _browser = browser;
      _phase = _PrivacyPagePhase.loading;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    _loadTimeout?.cancel();
    _loadTimeout = Timer(
      const Duration(seconds: 20),
      () => _showLocalSummary(loadId),
    );
    unawaited(_loadRemote(browser, url, loadId));
  }

  Future<void> _loadRemote(
    PrivacyPageBrowser browser,
    Uri url,
    int loadId,
  ) async {
    try {
      await browser.initialize(
        url,
        onFinished: () => _showOnline(loadId),
        onFailure: () => _showLocalSummary(loadId),
      );
      if (!mounted || loadId != _loadId) return;
      await browser.load(url);
    } catch (_) {
      _showLocalSummary(loadId);
    }
  }

  void _showOnline(int loadId) {
    if (!mounted || loadId != _loadId || _phase != _PrivacyPagePhase.loading) {
      return;
    }
    _loadTimeout?.cancel();
    setState(() => _phase = _PrivacyPagePhase.online);
  }

  void _showLocalSummary(int loadId) {
    if (!mounted || loadId != _loadId || _phase == _PrivacyPagePhase.local) {
      return;
    }
    _loadTimeout?.cancel();
    setState(() => _phase = _PrivacyPagePhase.local);
  }

  void _retryOnline() {
    if (_phase != _PrivacyPagePhase.local || _policyUrl == null) return;
    _startRemote();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return Scaffold(
      appBar: AppBar(title: Text(l('privacy'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _phase == _PrivacyPagePhase.local
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _policyUrl == null
                                ? Icons.info_outline
                                : Icons.wifi_off_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l(
                              _policyUrl == null
                                  ? 'privacyOnlinePending'
                                  : 'privacyOnlineUnavailable',
                            ),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (_policyUrl != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              key: const Key('privacy_retry_online'),
                              onPressed: _retryOnline,
                              icon: const Icon(Icons.refresh),
                              label: Text(l('privacyRetryOnline')),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l('privacyLocalSummary'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l('privacyBody'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],
                )
              : Column(
                  children: [
                    if (_phase == _PrivacyPagePhase.loading) ...[
                      const LinearProgressIndicator(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l('privacyLoading')),
                      ),
                    ],
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey(_loadId),
                        child: _browser!.view(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
