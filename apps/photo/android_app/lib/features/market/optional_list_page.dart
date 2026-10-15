import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/models/market_product_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/providers/app_events.dart';
import '../../shared/widgets/card_factory.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_load_animation_view.dart';
import 'category_market_list_page.dart';
import 'market_list_ui_prefs.dart';
import 'optional_recommend_batch.dart';

/// 自选（发现 Tab `/optional` 或行情 Tab 内嵌）
/// 对齐 iOS `STOptionalListView`：
/// - 已登录有数据 → Figma 添加后列表（名称 / 最新价 / 24H）
/// - 未登录或无数据 → 推荐宫格（对齐 `STOptionalEmptyView` + `Selfmarket1CardView`）
/// 数据请求对齐 iOS `Cards/selfmarket_1/.../Selfmarket1CardView.m`：
/// 已登录 `get_symbol_watch_list` need_points=1，若空再 `get_watch_symbol` need_points=0；
/// 未登录仅 `get_watch_symbol` need_points=0。
class OptionalListPage extends ConsumerStatefulWidget {
  final String? title;

  /// 为 true 时不包 Scaffold（嵌在 [MarketTabShellPage] 内）
  final bool embedded;

  const OptionalListPage({super.key, this.title, this.embedded = false});

  @override
  ConsumerState<OptionalListPage> createState() => _OptionalListPageState();
}

class _OptionalListPageState extends ConsumerState<OptionalListPage>
    with AutomaticKeepAliveClientMixin {
  static const Map<String, String> _fallbackText = {
    'optional': '自选',
    'custom_recommendations': '自选推荐',
    'next_batch': '换一批',
    'one_touch_add_optional': '一键添加',
    'add_stock_null_tips': '您的自选列表是空的，快去添加感兴趣的品种吧。',
    'column_name': '名称',
    'column_last_price': '最新价',
    'column_24h_change': '24H',
  };
  static const Set<String> _watchlistHeaderKeys = {
    'column_name',
    'column_last_price',
    'column_24h_change',
  };

  @override
  bool get wantKeepAlive => widget.embedded;

  List<MarketProductModel> _items = [];
  bool _loading = true;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  /// 推荐宫格多选（Figma `3600:880`）
  final Set<String> _selectedRecommendSymbols = {};
  bool _submittingBatch = false;

  /// 与 iOS `STOptionalEmptyView` 换一批算法一致（按 symbol_group 轮播）
  final OptionalRecommendBatch _recommendBatch = OptionalRecommendBatch();

  int _gridReloadNonce = 0;
  MarketSortColumn _sortColumn = MarketSortColumn.changePercent;
  String _sortOrder = MarketListUiPrefs.sortDefault;

  static const Color _kAppBarActionIcon = Color(0xFF343434);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(stServiceProvider);
      final loggedIn = ref.read(userStateProvider).isLogin;
      final mgr = ref.read(configDataManagerProvider);
      final list = await CardFactory.loadMarketTabSelfProducts(
        service: service,
        configMgr: mgr,
        isLoggedIn: loggedIn,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _gridReloadNonce = 0;
        _selectedRecommendSymbols.clear();
        _syncRecommendBatchFromItems();
      });
    } catch (e) {
      debugPrint('OptionalListPage load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    Future.wait<MapEntry<String, String>>(
      _fallbackText.entries.map((entry) async {
        final key = entry.key;
        final fallback = entry.value;
        final value = _watchlistHeaderKeys.contains(key)
            ? await _localizedMarketColumnText(
                localizations,
                key,
                fallback: fallback,
              )
            : await localizations.text(key, fallback: fallback);
        return MapEntry(key, value);
      }),
    ).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = Map<String, String>.fromEntries(entries);
      });
    });
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  Future<String> _localizedMarketColumnText(
    STLocalizations localizations,
    String key, {
    required String fallback,
  }) async {
    for (final cardName in const ['selfmarket_2', 'categorymarket_2']) {
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

  /// 自选列表顺序对齐 iOS `STOptionalListView`：保持接口顺序，不参与 `listRiseFallSort`。
  List<MarketProductModel> _sortedForWatchlist(List<MarketProductModel> opted) {
    return sortMarketInstrumentItems(
      List<MarketProductModel>.from(opted),
      sortColumn: _sortColumn,
      sortOrder: _sortOrder,
    );
  }

  void _cycleSort(MarketSortColumn column) {
    final next = _sortColumn == column
        ? MarketListUiPrefs.cycleSortOrder(_sortOrder)
        : MarketListUiPrefs.sortDesce;
    setState(() {
      _sortColumn = column;
      _sortOrder = next;
    });
  }

  /// 与 [MarketTabShellPage] 顶栏一致：编辑在左、搜索在右、间距 10、22pt / `#343434`
  Widget _optionalAppBarActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? _kRecommendDarkText : _kAppBarActionIcon;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final changed = await context.push<bool>(
                '/market/watchlist_edit',
              );
              if (changed == true && mounted) {
                await _load();
              }
            },
            child: SizedBox(
              width: 44,
              height: 48,
              child: Center(
                child: Icon(Icons.edit_outlined, size: 22, color: iconColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/market/search'),
            child: SizedBox(
              width: 44,
              height: 48,
              child: Center(
                child: Icon(Icons.search_rounded, size: 22, color: iconColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 添加后列表（Figma 1:1727 / 1:3199） ====================

  // ==================== 列表视图 ====================

  Widget _buildListView(List<MarketProductModel> ordered) {
    return STPullRefresh(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        primary: !widget.embedded,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (int i = 0; i < ordered.length; i++)
            FigmaMarketInstrumentRow(
              product: ordered[i],
              onTap: () => context.push(
                '/market/detail?symbol=${Uri.encodeComponent(ordered[i].symbol)}',
              ),
            ),
        ],
      ),
    );
  }

  // ==================== 空视图 / 推荐宫格（对齐 iOS STOptionalEmptyView） ====================

  List<MarketProductModel> _recommendGridPool(
    List<MarketProductModel> ordered,
  ) {
    final loggedIn = ref.read(userStateProvider).isLogin;
    return loggedIn ? ordered.where((p) => !p.inOptional).toList() : ordered;
  }

  void _syncRecommendBatchFromItems() {
    _recommendBatch.resetWithPool(_recommendGridPool(_items));
    _selectAllVisibleRecommend();
  }

  void _selectAllVisibleRecommend() {
    _selectedRecommendSymbols
      ..clear()
      ..addAll(_recommendBatch.visible.map((p) => p.symbol));
  }

  void _onChangeBatch() {
    if (!_recommendBatch.canChangeBatch) return;
    setState(() {
      _recommendBatch.changeBatch();
      _selectAllVisibleRecommend();
      _gridReloadNonce++;
    });
  }

  Future<void> _onAddBatchRecommend(List<MarketProductModel> visible) async {
    if (_submittingBatch) return;
    final loggedIn = ref.read(userStateProvider).isLogin;
    if (!loggedIn) {
      if (mounted) context.push('/login');
      return;
    }
    final poolSyms = visible.map((p) => p.symbol).toSet();
    final picked = _selectedRecommendSymbols.where(poolSyms.contains).toList();
    if (picked.isEmpty) {
      if (mounted) {
        showStLocalizedToastByKey(
          context,
          'flutter_prompt_watchlist_select_to_add',
          fallback: '请选择要添加的品种',
        );
      }
      return;
    }
    setState(() => _submittingBatch = true);
    try {
      await ref.read(stServiceProvider).addToWatchlist(picked);
      if (!mounted) return;
      setState(() => _selectedRecommendSymbols.clear());
      notifyWatchlistChanged(ref);
      await _load();
      if (mounted) {
        showStLocalizedToastByKey(context, 'add_success', fallback: '添加成功');
      }
    } catch (e) {
      if (mounted) {
        showStLocalizedErrorToast(context, '添加失败', e, separator: '：');
      }
    } finally {
      if (mounted) setState(() => _submittingBatch = false);
    }
  }

  List<MarketProductModel> _visibleGridItems() => _recommendBatch.visible;

  bool _hasRecommendSelection(List<MarketProductModel> visible) {
    final syms = visible.map((p) => p.symbol).toSet();
    return _selectedRecommendSymbols.any(syms.contains);
  }

  Widget _recommendCard(MarketProductModel p) {
    final selected = _selectedRecommendSymbols.contains(p.symbol);

    return OptionalRecommendGridTile(
      product: p,
      selected: selected,
      onToggle: () {
        setState(() {
          if (selected) {
            _selectedRecommendSymbols.remove(p.symbol);
          } else {
            _selectedRecommendSymbols.add(p.symbol);
          }
        });
      },
      onOpen: () => context.push(
        '/market/detail?symbol=${Uri.encodeComponent(p.symbol)}',
      ),
    );
  }

  Widget _buildRecommendGrid(List<MarketProductModel> gridPool) {
    final visible = _visibleGridItems();
    final canChangeBatch = _recommendBatch.canChangeBatch;
    final hasSelection = _hasRecommendSelection(visible);
    final titleTop = widget.embedded ? 17.0 : 12.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? _kRecommendDarkPageBg : _kRecommendLightPageBg;
    final textPrimary = isDark ? _kRecommendDarkText : _kRecommendLightText;
    final textMuted = isDark ? _kRecommendDarkMuted : _kRecommendLightMuted;

    /// 与宫格一致；勿再用外层 [Expanded]，否则宫格与按钮之间被撑出大块空白。
    const double hPad = 16;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: pageBg,
      child: STPullRefresh(
        onRefresh: _load,
        child: CustomScrollView(
          primary: !widget.embedded,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, titleTop, hPad, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('custom_recommendations'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 24 / 14,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canChangeBatch ? _onChangeBatch : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 11,
                            color: canChangeBatch
                                ? textMuted
                                : textMuted.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _t('next_batch'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 20 / 14,
                              color: canChangeBatch
                                  ? textMuted
                                  : textMuted.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (visible.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      _t('add_stock_null_tips'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                sliver: SliverGrid(
                  key: ValueKey<String>(
                    'opt_grid_${visible.map((p) => p.symbol).join(',')}_$_gridReloadNonce',
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: OptionalRecommendGridTile.heightFor(
                      context,
                    ),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _recommendCard(visible[i]),
                    childCount: visible.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(66, 112, 66, 12 + bottomInset),
                child: SizedBox(
                  height: 42,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRecommendCta,
                      disabledBackgroundColor: const Color(
                        0xFF00B57A,
                      ).withValues(alpha: 0.3),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed:
                        (_submittingBatch || visible.isEmpty || !hasSelection)
                        ? null
                        : () => _onAddBatchRecommend(visible),
                    child: _submittingBatch
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _t('one_touch_add_optional'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 主构建 ====================

  Widget _buildBody(List<MarketProductModel> ordered) {
    if (_loading && _items.isEmpty) {
      return const Center(child: STLoadAnimationView());
    }

    final loggedIn = ref.read(userStateProvider).isLogin;
    final opted = ordered.where((p) => p.inOptional).toList();
    final useListMode = loggedIn && opted.isNotEmpty;

    // 未登录：推荐宫格；已登录但自选为空：仅展示「非自选」推荐（Figma `3600:880`）
    if (!loggedIn || !useListMode) {
      final gridPool = _recommendGridPool(ordered);
      return _buildRecommendGrid(gridPool);
    }

    // 有自选数据：列表（Figma `1:1727` / `1:3199` 添加后样式）
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? _kRecommendDarkPageBg : _kRecommendLightPageBg,
      child: Column(
        children: [
          MarketInstrumentListHeader(
            nameText: _t('column_name'),
            lastPriceText: _t('column_last_price'),
            changeText: _t('column_24h_change'),
            sortColumn: _sortColumn,
            sortOrder: _sortOrder,
            onSort: _cycleSort,
          ),
          Expanded(child: _buildListView(_sortedForWatchlist(opted))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));

    ref.listen<bool>(userStateProvider.select((s) => s.isLogin), (prev, next) {
      if (prev != null && prev != next) {
        _load();
      }
    });
    ref.listen(loginSuccessProvider, (prev, next) {
      if (prev != next) {
        _load();
      }
    });
    ref.listen(selfMarketListRefreshTickProvider, (prev, next) {
      if (prev != next) {
        _load();
      }
    });

    ref.watch(userStateProvider.select((s) => s.riseAndFallType));
    CardTool.setRiseAndFallType(ref.read(userStateProvider).riseAndFallType);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? _kRecommendDarkPageBg : _kRecommendLightPageBg;

    final mgr = ref.watch(configDataManagerProvider);
    final ordered = _items.map((p) {
      final i = mgr.productIndexForSymbol(p.symbol);
      if (i >= 0 && i < mgr.productList.length) {
        final cached = mgr.productList[i];
        // iOS `STOptionalListView` decides list/empty state from the latest
        // option-list response itself. Keep global quote/presentation data,
        // but do not let a stale cached `inOptional` flag hide a newly added
        // watchlist item.
        return cached.copyWith(inOptional: p.inOptional);
      }
      return p;
    }).toList();

    if (widget.embedded) {
      return _buildBody(ordered);
    }
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: pageBg,
        foregroundColor: isDark ? _kRecommendDarkText : _kRecommendLightText,
        title: Text(widget.title ?? _t('optional')),
        actions: [_optionalAppBarActions()],
      ),
      body: _buildBody(ordered),
    );
  }
}

const Color _kRecommendLightPageBg = Colors.white;
const Color _kRecommendDarkPageBg = Color(0xFF18191A);
const Color _kRecommendLightCard = Color(0xFFF7F7F7);
const Color _kRecommendDarkCard = Color(0xFF212229);
const Color _kRecommendDarkBorder = Color(0xFF2F3340);
const Color _kRecommendLightText = Color(0xFF000000);
const Color _kRecommendDarkText = Color(0xFFEDF1F8);
const Color _kRecommendLightMuted = Color(0xFF9A9DA2);
const Color _kRecommendDarkMuted = Color(0xFF6E727D);
const Color _kRecommendCta = Color(0xFF00B57A);

class OptionalRecommendGridTile extends StatelessWidget {
  static double heightFor(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleHeight = textScaler.scale(14) * (20 / 14);
    final nameHeight = textScaler.scale(12) * (15 / 12);
    final requiredHeight = (16 + titleHeight + 2 + nameHeight + 16 + 2)
        .ceilToDouble();
    return requiredHeight > 80 ? requiredHeight : 80;
  }

  final MarketProductModel product;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const OptionalRecommendGridTile({
    super.key,
    required this.product,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kRecommendDarkCard : _kRecommendLightCard;
    final textColor = isDark ? _kRecommendDarkText : _kRecommendLightText;
    final mutedColor = isDark ? _kRecommendDarkMuted : _kRecommendLightMuted;
    final radius = BorderRadius.circular(8);

    return SizedBox(
      height: heightFor(context),
      child: Material(
        color: cardColor,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: radius,
            border: isDark ? Border.all(color: _kRecommendDarkBorder) : null,
          ),
          child: InkWell(
            onTap: onToggle,
            onLongPress: onOpen,
            child: Stack(
              children: [
                Positioned.fill(
                  right: 44,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          CardTool.hqSymbolTitleLine(
                            product.symbol,
                            product.name,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 20 / 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 15 / 12,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 31,
                  child: _OptionalRecommendCheckbox(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionalRecommendCheckbox extends StatelessWidget {
  final bool selected;

  const _OptionalRecommendCheckbox({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: selected
            ? null
            : Border.all(color: const Color(0xFFECECEC), width: 1),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.black)
          : null,
    );
  }
}
