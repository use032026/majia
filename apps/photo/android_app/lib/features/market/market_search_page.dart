import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/card_tool.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/models/user_state.dart';
import '../../core/providers/app_events.dart';
import '../../core/network/st_service.dart';
import '../../core/models/market_product_model.dart';
import '../../shared/widgets/st_base_scaffold.dart';
import '../../shared/widgets/st_load_animation_view.dart';
import '../../shared/widgets/market_pair_icons.dart';

/// 行情搜索页面
/// 完整对齐 iOS [STMarketSearchController] + [STMarketSearchHotView] + [STMarketSearchCell]：
/// - 搜索栏（灰底圆角，即时触发，无防抖，对齐 UIControlEventEditingChanged）
/// - 空输入：热门品种视图（getHotSymbols）
/// - 有输入有结果：搜索结果列表
/// - 有输入无结果：空态「查无记录」
/// - 收藏按钮：即时 API 调用 + 状态切换（对齐 iOS collectAction）
/// - 滚动时收起键盘（scrollViewDidScroll resignFirstResponder）
/// - 行点击跳转品种详情
class MarketSearchPage extends ConsumerStatefulWidget {
  const MarketSearchPage({super.key});

  @override
  ConsumerState<MarketSearchPage> createState() => _MarketSearchPageState();
}

class _MarketSearchPageState extends ConsumerState<MarketSearchPage> {
  static const Map<String, String> _fallbackText = {
    'search': '搜索',
    'finish': '完成',
    'search_stock_group': '搜索品种...',
    'hot': '热门',
    'no_record': '暂无记录',
  };

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  List<MarketProductModel> _hotItems = [];
  List<MarketProductModel> _results = [];

  // 本地收藏状态（对齐 iOS collectBtn.selected = model.is_watch_list）
  // key = symbol，value = isInWatchlist
  final Map<String, bool> _watchlistState = {};

  bool _loadingHot = false;
  bool _loadingSearch = false;
  bool _hasSearched = false;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  // ── 颜色常量 ──────────────────────────────────────
  static const Color _kGreen = Color(0xFF4DCB73);
  static const Color _kGrey = Color(0xFF9A9DA2);
  static const Color _kSearchBg = Color(0xFFF7F7F7);
  static const Color _kSep = Color(0xFFEEEEEE);
  static const Color _kFlat = Color(0xFF949494);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    // 滚动时收起键盘（对齐 iOS scrollViewDidScroll resignFirstResponder）
    _scrollCtrl.addListener(() {
      if (_focus.hasFocus) _focus.unfocus();
    });
    _loadHot();
    // 延迟请求焦点，避免键盘在过渡动画中弹出
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── 数据请求 ──────────────────────────────────────

  /// 对齐 iOS STMarketSearchHotView.requestHot
  Future<void> _loadHot() async {
    setState(() => _loadingHot = true);
    try {
      final raw = await ref
          .read(stServiceProvider)
          .getHotSymbols(needPoints: false);
      if (mounted) {
        setState(() {
          _hotItems = raw
              .map(
                (e) => MarketProductModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
          // iOS `STMarketSearchCell.setModel` 每次都用
          // `model.is_watch_list` 刷新按钮选中态。
          for (final m in _hotItems) {
            _watchlistState[m.symbol] = m.inOptional;
          }
        });
      }
    } catch (e) {
      debugPrint('MarketSearchPage: hot load failed: $e');
    }
    if (mounted) setState(() => _loadingHot = false);
  }

  /// 对齐 iOS requestSearch（无防抖，immediate on text change）
  Future<void> _requestSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() => _loadingSearch = true);
    try {
      final raw = await ref
          .read(stServiceProvider)
          .searchSymbols(keyword.trim(), needPoints: false);
      if (mounted) {
        setState(() {
          _results = raw
              .map(
                (e) => MarketProductModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
          _hasSearched = true;
          for (final m in _results) {
            _watchlistState[m.symbol] = m.inOptional;
          }
        });
      }
    } catch (e) {
      debugPrint('MarketSearchPage: search failed: $e');
      if (mounted) setState(() => _hasSearched = true);
    }
    if (mounted) setState(() => _loadingSearch = false);
  }

  // ── 事件处理 ──────────────────────────────────────

  /// 对齐 iOS textChanged
  void _onTextChanged() {
    final kw = _ctrl.text;
    if (kw.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
    } else {
      _requestSearch(kw);
    }
    setState(() {}); // 更新清空按钮状态
  }

  void _clearSearch() {
    _ctrl.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
    });
    _focus.requestFocus();
  }

  void _ensureLocalizedText(STLocalizations localizations) {
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    localizations.textMap(_fallbackText).then((value) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() {
        _localizedText = value;
      });
    });
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  /// 对齐 iOS collectAction → requestAddOptions / requestDeleteOption
  Future<void> _toggleWatchlist(MarketProductModel item) async {
    final symbol = item.symbol;
    final current = _watchlistState[symbol] ?? false;
    // 乐观更新
    setState(() => _watchlistState[symbol] = !current);
    try {
      final svc = ref.read(stServiceProvider);
      if (current) {
        await svc.removeFromWatchlist([symbol]);
      } else {
        await svc.addToWatchlist([symbol]);
      }
      notifyWatchlistChanged(ref);
    } catch (e) {
      // 回滚
      if (mounted) setState(() => _watchlistState[symbol] = current);
      debugPrint('MarketSearchPage: watchlist toggle failed: $e');
    }
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final riseFall = ref.watch(
      userStateProvider.select((s) => s.riseAndFallType),
    );
    CardTool.setRiseAndFallType(riseFall);
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    return STBaseScaffold(
      showNavigationBar: true,
      centerTitle: true,
      title: _t('search'),
      keyboardFocusNodes: [_focus],
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Colors.black,
        ),
        onPressed: () => context.popOrGoRoot(),
      ),
      actions: [
        TextButton(
          onPressed: () => context.popOrGoRoot(),
          child: Text(
            _t('finish'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kGreen,
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 对齐 iOS STMarketTextField：灰底圆角 24，搜索图标 + 占位 + 清空
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _kSearchBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(
              Icons.search_rounded,
              size: 21,
              color: Color(0xFFB0B3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: const TextStyle(fontSize: 14, color: Colors.black),
                decoration: InputDecoration(
                  hintText: _t('search_stock_group'),
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFD9D9D9),
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _requestSearch,
              ),
            ),
            if (_ctrl.text.isNotEmpty)
              GestureDetector(
                onTap: _clearSearch,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 20,
                    color: Color(0xFFB0B3B8),
                  ),
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final kw = _ctrl.text.trim();

    // 无输入 → 热门（对齐 iOS hotView.hidden = NO）
    if (kw.isEmpty) return _buildHotSection();

    // 搜索中
    if (_loadingSearch) {
      return const Center(child: STLoadAnimationView());
    }

    // 有结果
    if (_results.isNotEmpty) {
      return _buildResultList(_results);
    }

    // 无结果空态（对齐 iOS loadStateView STLoadStateViewEmptyRecordStyle）
    if (_hasSearched) return _buildEmptyState();

    return const SizedBox.shrink();
  }

  /// 对齐 iOS STMarketSearchHotView：热门标题 + 火焰图标 + 列表
  Widget _buildHotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _t('hot'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1023),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: Color(0xFFFF6B35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        if (_loadingHot)
          const Expanded(child: Center(child: STLoadAnimationView()))
        else
          Expanded(child: _buildResultList(_hotItems)),
      ],
    );
  }

  Widget _buildResultList(List<MarketProductModel> items) {
    return ListView.separated(
      controller: _scrollCtrl,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Container(color: _kSep, height: 0.5),
      ),
      itemBuilder: (ctx, i) => _SearchResultRow(
        model: items[i],
        inWatchlist: _watchlistState[items[i].symbol] ?? false,
        onToggleWatchlist: () => _toggleWatchlist(items[i]),
        onTap: () => context.push(
          '/market/detail?symbol=${Uri.encodeComponent(items[i].symbol)}',
        ),
        kUp: CardTool.priceColor(1),
        kDown: CardTool.priceColor(-1),
        kFlat: _kFlat,
        kGreen: _kGreen,
        kGrey: _kGrey,
      ),
    );
  }

  /// 对齐 iOS loadStateView STLoadStateViewEmptyRecordStyle
  Widget _buildEmptyState() {
    return Column(
      children: [
        const Spacer(),
        const Icon(
          Icons.manage_search_rounded,
          size: 72,
          color: Color(0xFFE0E0E0),
        ),
        const SizedBox(height: 12),
        Text(
          _t('no_record'),
          style: const TextStyle(fontSize: 11, color: Color(0xFF949494)),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

// ── 搜索结果行 ─────────────────────────────────────────────────────────────────

/// 对齐 iOS STMarketSearchCell（中文模式布局，height 56）：
/// - titleLab (Bold 14pt)：top 15
/// - icon1 + icon2 + subTitleLab：title 下方
/// - priceLab：centerY，在 rateLab 左侧
/// - rateLab (71×26, radius 5)：白字，涨绿跌红平灰
/// - collectBtn (♥)：trailing 15，centerY
class _SearchResultRow extends StatelessWidget {
  final MarketProductModel model;
  final bool inWatchlist;
  final VoidCallback onToggleWatchlist;
  final VoidCallback onTap;
  final Color kUp, kDown, kFlat, kGreen, kGrey;

  const _SearchResultRow({
    required this.model,
    required this.inWatchlist,
    required this.onToggleWatchlist,
    required this.onTap,
    required this.kUp,
    required this.kDown,
    required this.kFlat,
    required this.kGreen,
    required this.kGrey,
  });

  @override
  Widget build(BuildContext context) {
    final pct = model.changePercent;
    final badgeColor = pct > 0 ? kUp : (pct < 0 ? kDown : kFlat);
    final hasSubTitle = model.subTitle != null && model.subTitle!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 品种信息（对齐 iOS 中文模式：name 在上，icons+subtitle 在下）
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name.isNotEmpty ? model.name : model.symbol,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasSubTitle) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          MarketPairIcons(
                            isSingleIcon: model.isSingleIcon,
                            icon: model.icon,
                            currencyBaseIcon: model.currencyBaseIcon,
                            currencyProfitIcon: model.currencyProfitIcon,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              model.subTitle!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: kGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else if (!model.isSingleIcon) ...[
                      const SizedBox(height: 3),
                      MarketPairIcons(
                        isSingleIcon: false,
                        icon: model.icon,
                        currencyBaseIcon: model.currencyBaseIcon,
                        currencyProfitIcon: model.currencyProfitIcon,
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ),
              // 价格（对齐 iOS priceLab：Medium 14pt）
              Text(
                model.price.toStringAsFixed(model.precision),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(width: 10),
              // 涨跌幅（对齐 iOS rateLab：71×26 radius 5 白字）
              Container(
                width: 71,
                height: 26,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  model.changePercentString,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 收藏按钮（对齐 iOS collectBtn：空心/实心 ♥）
              GestureDetector(
                onTap: onToggleWatchlist,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 32,
                  height: 40,
                  child: Center(
                    child: Icon(
                      inWatchlist
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: inWatchlist ? kGreen : const Color(0xFFD0D0D0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
