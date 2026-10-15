import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/config/brand_config.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_service.dart';
import '../../shared/widgets/st_webview.dart';

/// 动态 H5 页面
/// 根据 key 从 getH5Addresses() 接口获取真实 H5 地址
class DynamicH5Page extends ConsumerStatefulWidget {
  final String keyName; // 'deposit', 'draw', 'transfer' 等
  final String title;

  const DynamicH5Page({super.key, required this.keyName, required this.title});

  @override
  ConsumerState<DynamicH5Page> createState() => _DynamicH5PageState();
}

class _DynamicH5PageState extends ConsumerState<DynamicH5Page> {
  static const Map<String, String> _fallbackText = {
    'requestfail': '数据加载失败',
    'dkplayer_retry': '重试',
  };

  String? url;
  bool isLoading = true;
  bool hasLoadError = false;
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final nextCode = stLanguageCodeOfContext(context);
    if (_languageCode == nextCode && _localized.isNotEmpty) return;
    _languageCode = nextCode;

    final token = ++_languageLoadToken;
    loadStLocalizedTextMap(context, ref, _fallbackText).then((entries) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  Future<void> _loadUrl() async {
    setState(() {
      isLoading = true;
      hasLoadError = false;
    });
    try {
      final service = ref.read(stServiceProvider);
      final h5Map = await service.getH5Addresses();
      final base = BrandConfig.jufu().h5BaseUrlForBuildMode;
      final rawKey = h5Map[widget.keyName];
      String? fromServer;
      if (rawKey is String && rawKey.trim().isNotEmpty) {
        fromServer = rawKey.trim();
      }
      final dynamicUrl = fromServer ?? '$base/${widget.keyName}';
      setState(() {
        url = dynamicUrl;
        isLoading = false;
        hasLoadError = false;
      });
    } catch (_) {
      setState(() {
        url = null;
        isLoading = false;
        hasLoadError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: STLoadAnimationView()),
      );
    }

    if (hasLoadError || url == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_t('requestfail')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUrl,
                child: Text(_t('dkplayer_retry')),
              ),
            ],
          ),
        ),
      );
    }

    return STWebView(url: url!, title: widget.title);
  }
}
