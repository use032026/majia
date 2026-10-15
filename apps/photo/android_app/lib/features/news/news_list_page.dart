import 'package:flutter/material.dart';
import 'package:jufu/core/theme/context_adaptive_colors.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:jufu/shared/widgets/st_network_image.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

/// 资讯列表页面
/// 对齐 iOS `STTabNewsViewController`：复合 Tab 内嵌时不重复 AppBar，点击进详情。
class NewsListPage extends ConsumerStatefulWidget {
  final bool embedded;

  const NewsListPage({super.key, this.embedded = false});

  @override
  ConsumerState<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends ConsumerState<NewsListPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _newsList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || _newsList.isEmpty;
    setState(() {
      _isLoading = shouldShowLoading;
      if (shouldShowLoading) {
        _errorMessage = null;
      }
    });

    try {
      final stService = ref.read(stServiceProvider);
      final list = await stService.getNewsList(limit: 20);
      if (mounted) {
        setState(() {
          _newsList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (shouldShowLoading) {
          setState(() {
            _errorMessage = stUserVisibleErrorMessage(e);
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildSurface(
      _isLoading
          ? const Center(child: STLoadAnimationView())
          : _errorMessage != null
          ? _buildErrorView()
          : _buildContent(),
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: context.adaptiveSurfacePrimary,
      appBar: AppBar(
        title: const STLocalizedTextByKey('information', fallback: '资讯'),
      ),
      body: body,
    );
  }

  Widget _buildSurface(Widget child) {
    return Material(
      key: const Key('news-list-root'),
      color: context.adaptiveSurfacePrimary,
      child: SizedBox.expand(child: child),
    );
  }

  Widget _buildErrorView() {
    final errorColor = Theme.of(context).colorScheme.error;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: errorColor),
          const SizedBox(height: 12),
          STLocalizedTextByKey(
            'dkplayer_error_message',
            fallback: _errorMessage!,
            style: TextStyle(color: errorColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const STLocalizedTextByKey('dkplayer_retry', fallback: '重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_newsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: context.adaptiveTextHint,
            ),
            const SizedBox(height: 16),
            STLocalizedTextByKey(
              'no_news',
              fallback: '暂无资讯',
              style: TextStyle(
                fontSize: 16,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return STPullRefresh(
      onRefresh: () => _loadData(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _newsList.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: context.adaptiveDivider),
        itemBuilder: (context, index) {
          final item = _newsList[index] as Map<String, dynamic>;
          final title = item['title']?.toString() ?? '';
          final summary =
              item['summary']?.toString() ?? item['content']?.toString() ?? '';
          final date =
              item['create_time']?.toString() ?? item['date']?.toString() ?? '';
          final imageUrl =
              item['image']?.toString() ?? item['thumbnail']?.toString() ?? '';
          final id = item['id']?.toString() ?? '';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 4,
            ),
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: context.adaptiveTextPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  if (date.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adaptiveTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            leading: imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: STNetworkImage(
                      imageUrl: imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholderBuilder: (_) => ColoredBox(
                        color: context.adaptiveMutedBlock,
                        child: const SizedBox(width: 60, height: 60),
                      ),
                    ),
                  )
                : null,
            onTap: id.isEmpty
                ? null
                : () => context.push('/news/detail?id=$id'),
          );
        },
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.length >= 10) {
      return dateStr.substring(0, 10);
    }
    return dateStr;
  }
}
