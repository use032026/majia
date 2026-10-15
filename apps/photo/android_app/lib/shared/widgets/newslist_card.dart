import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/news_item_model.dart';
import '../../core/models/user_state.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/utils/timezone_util.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'card_factory.dart';

/// 新闻资讯卡片
///
/// iOS: Card_Style_NewsList = @"newslist_"，变体 newslist_1 ~ newslist_4
/// 数据来源: requestNewsListWithParams:@{@"limit":@4} → response[@"data"][@"list"]
/// 每个 item: { id, title, sub_title, pic_url, publish_time }
/// 跳转: item → /news/detail?id=xxx, "更多" → /news
class NewslistCard extends ConsumerStatefulWidget {
  final ConfigCardItemData cardData;
  final CardNavigateCallback? onNavigate;
  final List<NewsItemModel>? items;

  const NewslistCard({
    super.key,
    required this.cardData,
    this.onNavigate,
    this.items,
  });

  @override
  ConsumerState<NewslistCard> createState() => _NewslistCardState();

  static DateTime _timeInZone(int timestampSec, String timezone) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      timestampSec * 1000,
      isUtc: true,
    );
    return TimezoneUtil.dateTimeInSelectedTimeZone(utc, timezone);
  }

  static String _formatDate(
    int timestampSec,
    String timezone, {
    required String separator,
  }) {
    if (timestampSec <= 0) return '';
    final t = _timeInZone(timestampSec, timezone);
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y$separator$m$separator$d';
  }

  static String _prettyCount(int count) {
    return NumberFormat.decimalPattern('en_US').format(count);
  }

  static String _compactCount(int count, String tenThousandUnit) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}$tenThousandUnit';
    }
    return '$count';
  }
}

class _NewslistCardState extends ConsumerState<NewslistCard> {
  static const Map<String, String> _fallbackText = {
    'information': '资讯',
    'more': '更多',
    'no_data': '暂无数据',
    'views': '阅读',
    'date_just': '刚刚',
    'date_minutes_ago': '%d分钟前',
    'date_hours_ago': '%d小时前',
    'date_days_ago': '%d天前',
    'ten_thousand': '万',
  };

  static const Map<String, String> _cardFallbackText = {
    'information': '资讯',
    'more': '更多',
    'views': '阅读',
    'date_just': '刚刚',
    'date_minutes_ago': '%d分钟前',
    'date_hours_ago': '%d小时前',
    'date_days_ago': '%d天前',
  };

  static const Map<String, String> _globalFallbackText = {'no_data': '暂无数据'};

  Map<String, String> _localizedText = _fallbackText;
  String? _localizedResourceKey;

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    final resourceKey = '$languageCode:${widget.cardData.cardStyle}';
    if (_localizedResourceKey == resourceKey) return;
    _localizedResourceKey = resourceKey;
    _localizedText = _fallbackText;
    Future.wait([
      ..._cardFallbackText.entries.map((entry) async {
        final value = await _localizedCardText(
          localizations,
          entry.key,
          fallback: entry.value,
        );
        return MapEntry(entry.key, value);
      }),
      ..._globalFallbackText.entries.map((entry) async {
        final value = await localizations.text(
          entry.key,
          fallback: entry.value,
        );
        return MapEntry(entry.key, value);
      }),
    ]).then((entries) {
      if (!mounted || _localizedResourceKey != resourceKey) return;
      setState(() {
        _localizedText = Map<String, String>.fromEntries(entries);
      });
    });
  }

  Future<String> _localizedCardText(
    STLocalizations localizations,
    String key, {
    required String fallback,
  }) async {
    final cardNames = <String>[
      widget.cardData.cardStyle,
      'newslist_2',
      'newslist_3',
      'newslist_4',
      'newslist_1',
    ];
    for (final cardName in cardNames.toSet()) {
      final value = await localizations.cardText(
        cardName,
        key,
        fallback: fallback,
      );
      if (value != fallback || localizations.languageCode.startsWith('zh')) {
        return value;
      }
    }
    return fallback;
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  String _formatWithNumber(String pattern, int value) {
    return pattern
        .replaceFirst('%d', value.toString())
        .replaceFirst('%1\$d', value.toString());
  }

  String _formatReadText(int count) {
    return '${NewslistCard._prettyCount(count)} ${_t('views')}';
  }

  String _formatCompactCount(int count) {
    return NewslistCard._compactCount(count, _t('ten_thousand'));
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    final detail = widget.cardData.cardDetail;
    final newsItems = widget.items ?? _parseItems(detail);

    final configMgr = ref.watch(configDataManagerProvider);
    final corner = configMgr.cardCorner;
    final horGap = configMgr.cardHorGap;
    final verGap = configMgr.cardVerGap;
    final timezone = ref.watch(
      userStateProvider.select((s) => s.selectedTimeZone),
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horGap, vertical: verGap),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(corner),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.adaptiveIsDark ? 0.35 : 0.05,
            ),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildVariant(context, newsItems, timezone),
    );
  }

  Widget _buildVariant(
    BuildContext context,
    List<NewsItemModel> newsItems,
    String timezone,
  ) {
    switch (widget.cardData.cardStyle) {
      case 'newslist_2':
        return _buildNewslist2(context, newsItems, timezone);
      case 'newslist_3':
        return _buildNewslist3(context, newsItems, timezone);
      case 'newslist_4':
        return _buildNewslist4(context, newsItems, timezone);
      default:

        /// newslist_1
        return _buildDefaultList(context, newsItems, timezone);
    }
  }

  Widget _buildDefaultList(
    BuildContext context,
    List<NewsItemModel> newsItems,
    String timezone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          context,
          left: 16,
          right: 8,
          titleSize: 18,
          withArrow: true,
        ),
        const SizedBox(height: 8),
        if (newsItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                _t('no_data'),
                style: TextStyle(
                  color: context.adaptiveTextTertiary,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...newsItems.map(
            (item) => _buildDefaultNewsItem(item, context, timezone),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildNewslist2(
    BuildContext context,
    List<NewsItemModel> newsItems,
    String timezone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        for (final item in newsItems)
          _buildNewslist2Row(context, item, timezone),
      ],
    );
  }

  Widget _buildNewslist2Row(
    BuildContext context,
    NewsItemModel item,
    String timezone,
  ) {
    return InkWell(
      onTap: () => _openItem(item),
      child: SizedBox(
        height: 96,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 8,
              width: 80,
              height: 80,
              child: _NewsImage(url: item.picUrl, radius: 10),
            ),
            Positioned(
              left: 104,
              right: 12,
              top: 8,
              height: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: context.adaptiveTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatRelativeTime(item.publishTime, timezone),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              color: context.adaptiveTextSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 25),
                        Text(
                          _formatReadText(367),
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewslist3(
    BuildContext context,
    List<NewsItemModel> newsItems,
    String timezone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        for (var i = 0; i < newsItems.length; i++)
          i == 0
              ? _buildNewslist3Hero(context, newsItems[i], timezone)
              : _buildNewslist3Small(context, newsItems[i], timezone),
      ],
    );
  }

  Widget _buildNewslist3Hero(
    BuildContext context,
    NewsItemModel item,
    String timezone,
  ) {
    return InkWell(
      onTap: () => _openItem(item),
      child: SizedBox(
        height: 252,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _NewsImage(url: item.picUrl, radius: 6),
                    ),
                    Positioned(
                      left: 12,
                      top: 8,
                      child: _TagPill(
                        text: _t('information'),
                        backgroundColor: const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _MetaRow(
                date: NewslistCard._formatDate(
                  item.publishTime,
                  timezone,
                  separator: '-',
                ),
                readText: _formatReadText(0),
                showEye: true,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: context.adaptiveIsDark
                    ? context.adaptiveDivider
                    : const Color(0xFFE5E5E5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewslist3Small(
    BuildContext context,
    NewsItemModel item,
    String timezone,
  ) {
    return InkWell(
      onTap: () => _openItem(item),
      child: SizedBox(
        height: 97,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 8,
              width: 80,
              height: 80,
              child: _NewsImage(url: item.picUrl, radius: 4),
            ),
            Positioned(
              left: 104,
              right: 12,
              top: 8,
              height: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  _MetaRow(
                    date: NewslistCard._formatDate(
                      item.publishTime,
                      timezone,
                      separator: '-',
                    ),
                    readText: _formatReadText(0),
                    showEye: false,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: Divider(
                height: 1,
                thickness: 1,
                color: context.adaptiveIsDark
                    ? context.adaptiveDivider
                    : const Color(0xFFE5E5E5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewslist4(
    BuildContext context,
    List<NewsItemModel> newsItems,
    String timezone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        SizedBox(
          height: 259,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: newsItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = newsItems[index];
              return _Newslist4Tile(
                item: item,
                timezone: timezone,
                tagText: _t('information'),
                readText: _formatCompactCount(0),
                onTap: () => _openItem(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    double left = 12,
    double right = 12,
    double titleSize = 16,
    bool withArrow = false,
  }) {
    final title = widget.cardData.title?.trim().isNotEmpty == true
        ? widget.cardData.title!.trim()
        : _t('information');
    return Padding(
      padding: EdgeInsets.fromLTRB(left, 12, right, 0),
      child: SizedBox(
        height: 19,
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w500,
                height: 19 / titleSize,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => widget.onNavigate?.call('/news', null),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t('more'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 19 / 12,
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
                  if (withArrow) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: context.adaptiveTextTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultNewsItem(
    NewsItemModel item,
    BuildContext context,
    String timezone,
  ) {
    return InkWell(
      onTap: () => _openItem(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.picUrl.isNotEmpty)
              SizedBox(
                width: 80,
                height: 60,
                child: _NewsImage(url: item.picUrl, radius: 4),
              ),
            if (item.picUrl.isNotEmpty) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  if (item.subTitle.isNotEmpty || item.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subTitle.isNotEmpty ? item.subTitle : item.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ],
                  if (item.publishTime > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      TimezoneUtil.formatTimestamp(item.publishTime, timezone),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openItem(NewsItemModel item) {
    widget.onNavigate?.call('/news/detail', {'id': item.id.toString()});
  }

  String _formatRelativeTime(int timestampSec, String timezone) {
    if (timestampSec <= 0) return '';
    final elapsed =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - timestampSec;
    if (elapsed < 60) return _t('date_just');
    if (elapsed < 3600) {
      return _formatWithNumber(_t('date_minutes_ago'), elapsed ~/ 60);
    }
    if (elapsed < 86400) {
      return _formatWithNumber(_t('date_hours_ago'), elapsed ~/ 3600);
    }
    if (elapsed < 2592000) {
      return _formatWithNumber(_t('date_days_ago'), elapsed ~/ 86400);
    }
    return NewslistCard._formatDate(timestampSec, timezone, separator: '/');
  }

  /// 从 cardDetail.payload 解析 items（离线 fallback）
  List<NewsItemModel> _parseItems(Map<String, dynamic>? detail) {
    if (detail == null) return [];
    final rawItems = detail['items'] as List<dynamic>?;
    if (rawItems == null) return [];
    return rawItems
        .map((e) => NewsItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class _NewsImage extends StatelessWidget {
  final String url;
  final double radius;

  const _NewsImage({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: context.adaptivePlaceholderSurface,
        child: url.isEmpty
            ? Icon(Icons.image_outlined, color: context.adaptiveTextHint)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.image_outlined, color: context.adaptiveTextHint),
              ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String text;
  final Color backgroundColor;

  const _TagPill({required this.text, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, height: 1, color: Colors.white),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String date;
  final String readText;
  final bool showEye;

  const _MetaRow({
    required this.date,
    required this.readText,
    required this.showEye,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          SizedBox(width: showEye ? 12 : 8),
          if (showEye) ...[
            Icon(
              Icons.visibility_outlined,
              size: 14,
              color: context.adaptiveTextSecondary,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              readText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Newslist4Tile extends StatelessWidget {
  final NewsItemModel item;
  final String timezone;
  final String tagText;
  final String readText;
  final VoidCallback onTap;

  const _Newslist4Tile({
    required this.item,
    required this.timezone,
    required this.tagText,
    required this.readText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 259,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: context.adaptiveCard,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: 13,
                height: 144,
                child: _NewsImage(url: item.picUrl, radius: 8),
              ),
              Positioned(
                left: 20,
                top: 171,
                child: _TagPill(
                  text: tagText,
                  backgroundColor: const Color(0xFF00B57A),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 203,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                height: 16,
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: context.adaptiveTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      NewslistCard._formatDate(
                        item.publishTime,
                        timezone,
                        separator: '-',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: context.adaptiveTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      readText,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
