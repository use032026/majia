import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'st_load_animation_view.dart';

/// 列表内嵌 WebView（无 Scaffold），对齐 iOS `STWebCardView` 卡片形态
class EmbedWebContent extends StatefulWidget {
  final String url;
  final ValueListenable<bool>? pageVisibleListenable;

  const EmbedWebContent({
    super.key,
    required this.url,
    this.pageVisibleListenable,
  });

  @override
  State<EmbedWebContent> createState() => _EmbedWebContentState();
}

class _EmbedWebContentState extends State<EmbedWebContent> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _pageLoaded = false;

  @override
  void initState() {
    super.initState();
    widget.pageVisibleListenable?.addListener(_onPageVisibilityChanged);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) {
            setState(() {
              _loading = false;
              _pageLoaded = true;
            });
            _injectTheme();
            if (widget.pageVisibleListenable?.value ?? true) {
              _sendLifecycle('pageWillAppear');
            }
          },
          onWebResourceError: (e) {
            debugPrint('EmbedWebContent error: $e');
          },
        ),
      )
      ..addJavaScriptChannel(
        'STBridge',
        onMessageReceived: (m) => debugPrint('STBridge: ${m.message}'),
      );

    final uri = Uri.tryParse(widget.url);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      _controller.loadRequest(uri);
    }
  }

  @override
  void didUpdateWidget(covariant EmbedWebContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageVisibleListenable != widget.pageVisibleListenable) {
      oldWidget.pageVisibleListenable?.removeListener(_onPageVisibilityChanged);
      widget.pageVisibleListenable?.addListener(_onPageVisibilityChanged);
    }
    if (oldWidget.url != widget.url) {
      final uri = Uri.tryParse(widget.url);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        _pageLoaded = false;
        _controller.loadRequest(uri);
      }
    }
  }

  @override
  void dispose() {
    widget.pageVisibleListenable?.removeListener(_onPageVisibilityChanged);
    super.dispose();
  }

  void _onPageVisibilityChanged() {
    if (!_pageLoaded) return;
    final visible = widget.pageVisibleListenable?.value ?? true;
    _sendLifecycle(visible ? 'pageWillAppear' : 'pageWillDisappear');
  }

  void _sendLifecycle(String method) {
    _controller.runJavaScript(
      "typeof window.$method === 'function' && window.$method()",
    );
  }

  void _injectTheme() {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _controller.runJavaScript('''
      if (window.STThemeChange) { window.STThemeChange(${isDark ? 'true' : 'false'}); }
      if (document.body) document.body.classList.toggle('dark-mode', ${isDark ? 'true' : 'false'});
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '无效的 H5 链接',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const ColoredBox(
            color: Color(0x0F000000),
            child: Center(child: STLoadAnimationView()),
          ),
      ],
    );
  }
}
