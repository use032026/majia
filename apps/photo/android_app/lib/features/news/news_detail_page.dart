import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jufu/core/theme/context_adaptive_colors.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

/// 资讯详情（PageRouter `/news/detail`）
/// 对齐 iOS `STTabNewsDetailViewController` + `requestNewsDetailWithParams`
class NewsDetailPage extends ConsumerStatefulWidget {
  final String newsId;

  const NewsDetailPage({super.key, required this.newsId});

  @override
  ConsumerState<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends ConsumerState<NewsDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.newsId.isEmpty) {
      setState(() {
        _loading = false;
        _error = '加载失败';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(stServiceProvider);
      final data = await svc.getNewsDetail(id: widget.newsId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        if (data == null) _error = '加载失败';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = stUserVisibleErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adaptiveSurfacePrimary,
      appBar: AppBar(
        title: const STLocalizedTextByKey(
          'flutter_router_news_detail',
          fallback: '资讯详情',
        ),
      ),
      body: Material(
        key: const Key('news-detail-root'),
        color: context.adaptiveSurfacePrimary,
        child: SizedBox.expand(
          child: _loading
              ? const Center(child: STLoadAnimationView())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      STLocalizedTextByKey(
                        'dkplayer_error_message',
                        fallback: _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.adaptiveTextPrimary),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: const STLocalizedTextByKey(
                          'dkplayer_retry',
                          fallback: '重试',
                        ),
                      ),
                    ],
                  ),
                )
              : _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final d = _data!;
    final title = d['title']?.toString() ?? '';
    final content = d['content']?.toString() ?? d['summary']?.toString() ?? '';
    final time =
        d['publish_time']?.toString() ??
        d['create_time']?.toString() ??
        d['date']?.toString() ??
        '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: context.adaptiveTextPrimary,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: context.adaptiveTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
