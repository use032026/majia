import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/app_localizations.dart';
import '../app/privacy_policy_config.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({this.url = privacyPolicyUrl, super.key});

  final String url;

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool _initialized = false;
  bool _initializing = false;
  Uri? _uri;
  WebViewController? _controller;
  String? _mainFrameUrl;
  int _progress = 0;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _uri = privacyPolicyUri(url: widget.url, useChinese: context.s.isChinese);
    if (_uri != null) unawaited(_initializeController());
  }

  Future<void> _initializeController() async {
    if (_initializing) return;
    _initializing = true;
    setState(() {
      _failed = false;
      _progress = 0;
    });
    final background = Theme.of(context).colorScheme.surface;
    try {
      final controller = WebViewController();
      await controller.setBackgroundColor(background);
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _mainFrameUrl = url;
              _progress = 0;
              _failed = false;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != false) _showError();
          },
          onHttpError: (error) {
            final failedUrl = error.request?.uri.toString();
            if (failedUrl == null || failedUrl == _mainFrameUrl) _showError();
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri?.scheme == 'https'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await _loadPolicy();
    } on Object {
      _showError();
    } finally {
      _initializing = false;
    }
  }

  Future<void> _loadPolicy() async {
    final controller = _controller;
    final uri = _uri;
    if (controller == null || uri == null) return;
    setState(() {
      _failed = false;
      _progress = 0;
      _mainFrameUrl = uri.toString();
    });
    try {
      await controller.loadRequest(uri);
    } on Object {
      _showError();
    }
  }

  void _showError() {
    if (mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      key: const Key('privacy-policy-page'),
      appBar: AppBar(title: Text(context.s.get('privacy'))),
      body: SafeArea(
        top: false,
        child: _uri == null || _failed
            ? _PrivacyPolicyFallback(
                unavailable: _uri == null,
                onRetry: _uri == null
                    ? null
                    : () => controller == null
                          ? _initializeController()
                          : _loadPolicy(),
              )
            : controller == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_progress < 100)
                    LinearProgressIndicator(value: _progress / 100),
                  Expanded(child: WebViewWidget(controller: controller)),
                ],
              ),
      ),
    );
  }
}

class _PrivacyPolicyFallback extends StatelessWidget {
  const _PrivacyPolicyFallback({required this.unavailable, this.onRetry});

  final bool unavailable;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const Key('privacy-policy-fallback'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              Icons.shield_outlined,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.s.get(
              unavailable ? 'privacyUnavailable' : 'privacyLoadFailed',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('privacy-policy-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.s.get('privacyRetry')),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            context.s.get('privacyLocalData'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.s.get('privacyBody'),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}
