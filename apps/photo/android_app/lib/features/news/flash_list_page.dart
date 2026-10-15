import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jufu/core/localization/st_localizations.dart';
import 'package:jufu/core/services/ios_language_bundle.dart';
import 'package:jufu/core/theme/context_adaptive_colors.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/network/st_dio.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

/// 快讯列表（复合 Tab 子路由 `/flash`）
/// 对齐 MediaServiceClient：`STFlashViewController` / `STFlashNewsViewCell` / `STSectionHeader`
///（`Local/STFlash/classes/...`）：分组与合并、offset/limit/lang、section 高度与 footer、三色与展开链式。
class FlashListPage extends ConsumerStatefulWidget {
  final String? title;

  const FlashListPage({super.key, this.title});

  @override
  ConsumerState<FlashListPage> createState() => _FlashListPageState();
}

class _FlashItem {
  _FlashItem(this.raw);
  final Map<String, dynamic> raw;
  bool expanded = false;

  double get publishTimeSec => (raw['publish_time'] as num?)?.toDouble() ?? 0;
  String get stableKey {
    final id = raw['id'] ?? raw['flash_id'] ?? raw['news_id'];
    if (id != null && id.toString().isNotEmpty) return id.toString();
    return '${publishTimeSec}_${title.hashCode}_${content.hashCode}';
  }

  String get title => raw['title']?.toString() ?? '';
  String get content => raw['content']?.toString() ?? '';
}

class _FlashGroup {
  _FlashGroup(this.date, this.items);
  final String date;
  final List<_FlashItem> items;
}

class _FlashListPageState extends ConsumerState<FlashListPage> {
  static const int _limit = 20;

  final ScrollController _scrollController = ScrollController();

  List<_FlashGroup> _groups = [];
  int _page = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  DateTime? _lastLoadMoreAt;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(reset: true));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 240) return;
    final now = DateTime.now();
    if (_lastLoadMoreAt != null &&
        now.difference(_lastLoadMoreAt!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastLoadMoreAt = now;
    _loadMore();
  }

  String _lang() => ref.read(stDioProvider).currentLanguage;

  static String _publishDateKey(Map<String, dynamic> raw) {
    final sec = (raw['publish_time'] as num?)?.toDouble() ?? 0;
    final ms = (sec * 1000).round();
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static List<_FlashGroup> _groupModels(List<Map<String, dynamic>> list) {
    final Map<String, List<_FlashItem>> map = {};
    for (final r in list) {
      final key = _publishDateKey(r);
      map.putIfAbsent(key, () => []).add(_FlashItem(r));
    }
    final keys = map.keys.toList()..sort((b, a) => a.compareTo(b));
    return keys.map((k) => _FlashGroup(k, map[k]!)).toList();
  }

  void _mergeIncoming(List<_FlashGroup> incoming) {
    if (incoming.isEmpty) return;
    if (_groups.isEmpty) {
      _groups = List.from(incoming);
      return;
    }
    final firstNew = incoming.first;
    final lastOld = _groups.last;
    if (firstNew.date == lastOld.date) {
      final merged = [...lastOld.items, ...firstNew.items];
      _groups[_groups.length - 1] = _FlashGroup(lastOld.date, merged);
      _groups.addAll(incoming.skip(1));
    } else {
      _groups.addAll(incoming);
    }
  }

  Future<void> _refresh({bool reset = false}) async {
    // 对齐 iOS requestFristPageData：与尾部加载互斥，避免并发请求
    if (_loading || _loadingMore) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 0;
        _groups = [];
        _hasMore = true;
      }
    });

    try {
      final svc = ref.read(stServiceProvider);
      final offset = reset ? 0 : _page * _limit;
      final rawList = await svc.getFlashList(
        offset: offset,
        limit: _limit,
        lang: _lang(),
      );
      final maps = rawList.cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _groups = _groupModels(maps);
        } else {
          _mergeIncoming(_groupModels(maps));
        }
        _page = reset ? 1 : _page + 1;
        _hasMore = maps.length >= _limit;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = stUserVisibleErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final svc = ref.read(stServiceProvider);
      final offset = _page * _limit;
      final rawList = await svc.getFlashList(
        offset: offset,
        limit: _limit,
        lang: _lang(),
      );
      final maps = rawList.cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _mergeIncoming(_groupModels(maps));
        _page++;
        _hasMore = maps.length >= _limit;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  String _sectionTitle(String yyyyMmDd) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (yyyyMmDd == today) return '今天';
    try {
      final d = DateFormat('yyyy-MM-dd').parse(yyyyMmDd);
      return DateFormat('MM-dd').format(d);
    } catch (_) {
      return yyyyMmDd;
    }
  }

  String _timeLabel(double publishTimeSec) {
    final ms = (publishTimeSec * 1000).round();
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _FlashThemeColors.of(context);
    final languageCode = _lang();
    if (_loading && _groups.isEmpty && _error == null) {
      return _buildSurface(
        colors: colors,
        child: const Center(child: STLoadAnimationView()),
      );
    }
    if (_error != null && _groups.isEmpty) {
      return _buildSurface(
        colors: colors,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              STLocalizedTextByKey(
                'dkplayer_error_message',
                fallback: _error!,
                languageCode: languageCode,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.primaryText),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _refresh(reset: true),
                child: STLocalizedTextByKey(
                  'dkplayer_retry',
                  fallback: '重试',
                  languageCode: languageCode,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 对齐 iOS：无下拉 RefreshHeader（已注释），仅首段刷新按钮 + 底部 MJRefresh footer 式加载更多；
    // 去掉 RefreshIndicator，避免 overscroll 露出父级灰底形成「大面积灰色」。
    return _buildSurface(
      colors: colors,
      child: CustomScrollView(
        controller: _scrollController,
        clipBehavior: Clip.none,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          for (int gi = 0; gi < _groups.length; gi++) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: _sectionTitle(_groups[gi].date),
                languageCode: languageCode,
                showRefresh: gi == 0,
                onRefresh: gi == 0 ? () => _refresh(reset: true) : null,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, ri) {
                final group = _groups[gi];
                final item = group.items[ri];
                final isLast = ri == group.items.length - 1;
                return KeyedSubtree(
                  key: ValueKey('flash_${item.stableKey}'),
                  child: _FlashTimelineTile(
                    timeText: _timeLabel(item.publishTimeSec),
                    title: item.title,
                    content: item.content.isNotEmpty
                        ? item.content
                        : item.raw['sub_title']?.toString() ?? '',
                    expanded: item.expanded,
                    isLastRowInSection: isLast,
                    onToggleExpand: () =>
                        setState(() => item.expanded = !item.expanded),
                  ),
                );
              }, childCount: _groups[gi].items.length),
            ),
            // 对齐 iOS heightForFooterInSection: 6（分组间隔；最后一组也保留与 iOS 一致）
            const SliverToBoxAdapter(child: _FlashSectionGap()),
          ],
          if (_groups.isEmpty && !_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: STLocalizedTextByKey(
                  'no_news',
                  fallback: '暂无资讯',
                  languageCode: languageCode,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                    color: colors.secondaryText,
                  ),
                ),
              ),
            ),
          // 底部加载更多（对齐 STFlashViewController.cmsmj_footer），白底
          if (_groups.isNotEmpty)
            SliverToBoxAdapter(
              child: ColoredBox(
                color: colors.pageBackground,
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: _loadingMore
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : STLocalizedTextByKey(
                            _hasMore
                                ? 'pull_up_to_load_more'
                                : 'market_no_more',
                            fallback: _hasMore ? '上拉加载更多' : '没有更多数据了',
                            languageCode: languageCode,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              color: colors.secondaryText,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSurface({
    required _FlashThemeColors colors,
    required Widget child,
  }) {
    return SizedBox.expand(
      child: Material(
        key: const Key('flash-list-root'),
        color: colors.pageBackground,
        clipBehavior: Clip.none,
        child: child,
      ),
    );
  }
}

class _FlashSectionGap extends StatelessWidget {
  const _FlashSectionGap();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _FlashThemeColors.of(context).groupGap,
      child: const SizedBox(height: 6),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String languageCode;
  final bool showRefresh;
  final VoidCallback? onRefresh;

  const _SectionHeader({
    required this.title,
    required this.languageCode,
    required this.showRefresh,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _FlashThemeColors.of(context);
    return Container(
      key: const Key('flash-section-header'),
      height: 58,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      alignment: Alignment.centerLeft,
      color: colors.pageBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _FlashHeaderTitle(
            title: title,
            languageCode: languageCode,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.12,
              letterSpacing: 0,
              color: colors.headerText,
            ),
          ),
          const Spacer(),
          if (showRefresh && onRefresh != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                Icons.refresh,
                size: 20,
                color: colors.headerText.withValues(alpha: 0.32),
              ),
              onPressed: onRefresh,
              tooltip: '',
            ),
        ],
      ),
    );
  }
}

class _FlashHeaderTitle extends StatelessWidget {
  final String title;
  final String languageCode;
  final TextStyle style;

  const _FlashHeaderTitle({
    required this.title,
    required this.languageCode,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (title == '今天') {
      return STLocalizedTextByKey(
        'program_today',
        fallback: title,
        languageCode: languageCode,
        style: style,
      );
    }
    return Text(title, style: style);
  }
}

class _FlashTimelineTile extends StatelessWidget {
  final String timeText;
  final String title;
  final String content;
  final bool expanded;

  /// 对齐 `STFlashNewsViewCell` 末行虚线 bottom 较 contentView 上移 15。
  final bool isLastRowInSection;
  final VoidCallback onToggleExpand;

  const _FlashTimelineTile({
    required this.timeText,
    required this.title,
    required this.content,
    required this.expanded,
    required this.isLastRowInSection,
    required this.onToggleExpand,
  });

  /// 时间轴圆点：截图为绿色（与 iOS STFlashNewsViewCell 圆点色一致）
  static const Color _dotGreen = Color(0xFF34C759);

  static const double _dotSize = 9;
  static const double _dotToTimeGap = 10;

  /// 时间列固定宽 65（与 iOS timeLabel 约束一致）
  static const double _timeColW = 65;

  /// 正文区左缩进：与 iOS 时间列左缘对齐（圆点 9 + 间距 10）
  static const double _contentInset = _dotSize + _dotToTimeGap;

  /// 对齐 iOS 时间轴 timeLabel：约 12pt Regular，#9A9DA2
  static const TextStyle _timeStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF9A9DA2),
    height: 16 / 12,
  );

  /// 首行（圆点与时间）高度：与 iOS centerY 对齐后取 max(点高, 字高)，供虚线 top 计算。
  static double _firstRowHeight(TextScaler scaler, BuildContext context) {
    final tp = TextPainter(
      text: const TextSpan(text: '00:00', style: _timeStyle),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final textH = tp.height;
    return textH > _dotSize ? textH : _dotSize;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _FlashThemeColors.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final firstRowH = _firstRowHeight(scaler, context);
    final dotTop = (firstRowH - _dotSize) / 2;
    final dashTop = dotTop + _dotSize + 2;
    final dashBottomInset = isLastRowInSection ? 15.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _dotSize,
                    height: firstRowH,
                    child: Align(
                      alignment: Alignment.center,
                      // 有标题（重要快讯）→ 实心绿圆；无标题（普通快讯）→ 绿色描边空心圆
                      child: Container(
                        width: _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: title.isNotEmpty ? _dotGreen : null,
                          border: title.isEmpty
                              ? Border.all(color: _dotGreen, width: 1.5)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _dotToTimeGap),
                  SizedBox(
                    width: _timeColW,
                    child: Text(
                      timeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _timeStyle.copyWith(color: colors.timeText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: _contentInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.primaryText,
                          height: 20 / 14,
                        ),
                      ),
                    if (content.isNotEmpty) ...[
                      if (title.isNotEmpty) const SizedBox(height: 4),
                      _ExpandableSummary(
                        text: content,
                        expanded: expanded,
                        onToggle: onToggleExpand,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
          Positioned(
            left: _dotSize / 2 - 0.5,
            top: dashTop,
            bottom: dashBottomInset,
            width: 1,
            child: ColoredBox(color: colors.dashLine),
          ),
        ],
      ),
    );
  }
}

/// 与 iOS `STFlashNewsViewCell` + `YYLabel` 对齐（`configureSubtitleWithText` / `truncateAttributedString`）：
/// - **宽度**：`preferredMaxLayoutWidth` = 屏宽 − 左右 16 − 时间列 65 − 圆点与间距 19（与 `_FlashTimelineTile` 一致）。
/// - **折叠**：`numberOfLines = 3`；先对**纯正文** `YYTextLayout` 判 `rowCount > 3`；若成立，用 `maximumNumberOfRows = 3`
///   取 `visibleRange`，去掉末尾空格后 **`appendAttributedString([Format:@" %@", open])`**，展开词整段 `yy_setTextHighlight` 点击 → `numberOfLines = 0` + `toggleBlock`。
/// - **展开**：`numberOfLines = 0`，全文 + 空格 + `pack_up`，高亮区点击 → `numberOfLines = 3` + `toggleBlock`。
/// - **样式**：摘要/链式均为 iOS `STFontSize(12)`、`yy_lineSpacing` 4 → `height: (12+4)/12`；#60656D；链式 **`#00B57A`**。
/// - **Flutter 实现**：折叠态「展开」叠加在正文区域右下，不占排版宽度，避免内联「 展开」缩短前缀导致第 1～2 行换行被挤压；
///   展开态仍为全文 + 「 收起」内联链接。
class _ExpandableSummary extends StatefulWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandableSummary({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_ExpandableSummary> createState() => _ExpandableSummaryState();
}

class _ExpandableSummaryState extends State<_ExpandableSummary> {
  static const _summaryStrut = StrutStyle(
    fontSize: 12,
    height: (12 + 4) / 12,
    forceStrutHeight: true,
    leadingDistribution: TextLeadingDistribution.even,
  );

  TextStyle _baseStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    color: _FlashThemeColors.of(context).summaryText,
    height: (12 + 4) / 12,
  );

  TextStyle _linkTextStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: const Color(0xFF00B57A),
    height: (12 + 4) / 12,
  );

  late TapGestureRecognizer _tapCollapse;

  @override
  void initState() {
    super.initState();
    _tapCollapse = TapGestureRecognizer()..onTap = _onToggleChain;
  }

  @override
  void didUpdateWidget(covariant _ExpandableSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onToggle != widget.onToggle) {
      _tapCollapse.onTap = _onToggleChain;
    }
  }

  @override
  void dispose() {
    _tapCollapse.dispose();
    super.dispose();
  }

  void _onToggleChain() {
    widget.onToggle();
  }

  bool _exceedsThreeLines(
    BuildContext context,
    double maxWidth,
    TextScaler scaler,
    String content,
    TextStyle style,
  ) {
    if (content.trim().isEmpty) return false;
    final tp = TextPainter(
      text: TextSpan(text: content, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      strutStyle: _summaryStrut,
      locale: Localizations.localeOf(context),
    )..layout(maxWidth: maxWidth);
    // 对齐 iOS YYTextLayout.rowCount > 3。didExceedMaxLines 在部分中文换行
    // 与 strut 组合下会误判，直接计算完整布局行数更稳定。
    final over = tp.computeLineMetrics().length > 3;
    tp.dispose();
    return over;
  }

  /// 折叠态：正文按全宽排满三行（ellipsis），「展开」叠在右下，不参与排版，不影响上行换行。
  Widget _collapsedWithOverlayExpand({
    required BuildContext context,
    required double maxWidth,
    required TextScaler scaler,
    required String expandLabel,
    required TextStyle baseStyle,
    required TextStyle linkTextStyle,
  }) {
    final colors = _FlashThemeColors.of(context);
    final lineHeight = scaler.scale(12) * ((12 + 4) / 12);
    return SizedBox(
      width: maxWidth,
      // +4px：AnimatedSize 末帧容差 + 中文字形偶尔超出 strut 下沿。
      height: lineHeight * 3 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            widget.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: baseStyle,
            strutStyle: _summaryStrut,
            locale: Localizations.localeOf(context),
            textScaler: scaler,
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: GestureDetector(
              onTap: _onToggleChain,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: colors.pageBackground,
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  expandLabel,
                  style: linkTextStyle,
                  strutStyle: _summaryStrut,
                  locale: Localizations.localeOf(context),
                  textScaler: scaler,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final languageCode = stLanguageCodeOfContext(context);
    final baseStyle = _baseStyle(context);
    final linkTextStyle = _linkTextStyle(context);

    return FutureBuilder<_FlashActionLabels>(
      future: _FlashActionLabels.load(languageCode),
      builder: (context, snapshot) {
        final labels = snapshot.data;
        if (labels == null) {
          return Text(
            widget.text,
            style: baseStyle,
            strutStyle: _summaryStrut,
            locale: Localizations.localeOf(context),
            textScaler: scaler,
          );
        }
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: LayoutBuilder(
            builder: (context, constraints) {
              var maxWidth = constraints.maxWidth;
              if (!maxWidth.isFinite) {
                final sw = MediaQuery.sizeOf(context).width;
                // 与 `_FlashTimelineTile`：左右 16 + 正文左缩进 圆点+间距 19
                maxWidth = (sw - 16 - 16 - 19).clamp(1.0, sw);
              }
              if (maxWidth <= 0) {
                return Text(widget.text, style: baseStyle);
              }
              final needToggle = _exceedsThreeLines(
                context,
                maxWidth,
                scaler,
                widget.text,
                baseStyle,
              );

              if (!needToggle) {
                return Text(
                  widget.text,
                  style: baseStyle,
                  strutStyle: _summaryStrut,
                );
              }

              if (widget.expanded) {
                return Text.rich(
                  TextSpan(
                    style: baseStyle,
                    children: [
                      TextSpan(text: widget.text),
                      TextSpan(
                        text: ' ${labels.collapse}',
                        style: linkTextStyle,
                        recognizer: _tapCollapse,
                      ),
                    ],
                  ),
                  strutStyle: _summaryStrut,
                  locale: Localizations.localeOf(context),
                  textScaler: scaler,
                );
              }

              return _collapsedWithOverlayExpand(
                context: context,
                maxWidth: maxWidth,
                scaler: scaler,
                expandLabel: labels.expand,
                baseStyle: baseStyle,
                linkTextStyle: linkTextStyle,
              );
            },
          ),
        );
      },
    );
  }
}

class _FlashActionLabels {
  final String expand;
  final String collapse;

  const _FlashActionLabels({required this.expand, required this.collapse});

  static Future<_FlashActionLabels> load(String languageCode) async {
    final l10n = STLocalizations(
      bundle: IosLanguageBundle(),
      languageCode: languageCode,
    );
    final values = await Future.wait([
      l10n.text('open', fallback: '展开'),
      l10n.text('pack_up', fallback: '收起'),
    ]);
    return _FlashActionLabels(expand: values[0], collapse: values[1]);
  }
}

class _FlashThemeColors {
  const _FlashThemeColors({
    required this.pageBackground,
    required this.groupGap,
    required this.headerText,
    required this.primaryText,
    required this.summaryText,
    required this.secondaryText,
    required this.timeText,
    required this.dashLine,
  });

  final Color pageBackground;
  final Color groupGap;
  final Color headerText;
  final Color primaryText;
  final Color summaryText;
  final Color secondaryText;
  final Color timeText;
  final Color dashLine;

  static _FlashThemeColors of(BuildContext context) {
    return _FlashThemeColors(
      pageBackground: context.adaptiveSurfacePrimary,
      groupGap: context.adaptiveMutedBlock,
      headerText: context.adaptiveTextPrimary,
      primaryText: context.adaptiveTextPrimary,
      summaryText: context.adaptiveTextTertiary,
      secondaryText: context.adaptiveTextSecondary,
      timeText: context.adaptiveTextSecondary,
      dashLine: context.adaptiveDivider,
    );
  }
}
