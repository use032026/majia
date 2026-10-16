import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/privacy_policy_config.dart';
import '../l10n/app_strings.dart';
import 'page_safe_area.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({
    required this.languageCode,
    this.configuration = const PrivacyPolicyConfig(),
    super.key,
  });

  final String languageCode;
  final PrivacyPolicyConfig configuration;

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  WebViewController? _controller;
  late final Uri? _uri;
  Uri? _mainFrameUri;
  bool _failed = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _uri = widget.configuration.uriForLanguage(widget.languageCode);
    if (_uri != null) _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = _controller ?? WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              Uri.tryParse(request.url)?.scheme == 'https'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (url) {
            if (!mounted) return;
            _mainFrameUri = Uri.tryParse(url);
            setState(() {
              _progress = 0;
              _failed = false;
            });
          },
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onHttpError: (error) {
            if (mounted &&
                _mainFrameUri != null &&
                (error.request?.uri == _mainFrameUri ||
                    error.response?.uri == _mainFrameUri)) {
              setState(() => _failed = true);
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame != false) {
              setState(() => _failed = true);
            }
          },
        ),
      );
      await controller.loadRequest(_uri!);
      if (mounted) setState(() {});
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.privacyPolicy)),
      body: _uri == null || _failed
          ? PageSafeArea(
              builder: (context) => Center(
                child: SingleChildScrollView(
                  padding: pageScrollPadding(context, horizontal: 28, top: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _failed
                              ? Icons.wifi_off_rounded
                              : Icons.description_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _failed
                              ? strings.privacyLoadFailed
                              : strings.privacyUnpublished,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _failed
                              ? strings.privacyLoadFailedBody
                              : strings.privacyUnpublishedBody,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (_failed) ...[
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _failed = false;
                                _progress = 0;
                              });
                              _initialize();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(strings.retry),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          : SafeArea(
              child: Stack(
                children: [
                  if (_controller != null)
                    Positioned.fill(
                      child: WebViewWidget(controller: _controller!),
                    ),
                  if (_progress < 100)
                    LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress / 100,
                    ),
                ],
              ),
            ),
    );
  }
}
