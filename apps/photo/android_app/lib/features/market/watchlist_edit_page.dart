import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/providers/app_events.dart';
import '../../core/network/st_service.dart';
import '../../core/models/market_product_model.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/market_pair_icons.dart';
import '../../shared/widgets/st_toast.dart';

/// 自选编辑页
/// 完整对齐 iOS [STEditOptionController] + [STEditOptionalCell]：
/// - 多选模式（类 UITableView editing = YES）
/// - 置顶：行内按钮，移到第 0 位
/// - 拖拽排序：ReorderableListView
/// - 删除所选：API removeFromWatchlist → 重新拉取
/// - 完成：API sortWatchlist（当前顺序）→ pop
class WatchlistEditPage extends ConsumerStatefulWidget {
  const WatchlistEditPage({super.key});

  @override
  ConsumerState<WatchlistEditPage> createState() => _WatchlistEditPageState();
}

class _WatchlistEditPageState extends ConsumerState<WatchlistEditPage> {
  static const Map<String, String> _fallbackText = {
    'edit_options': '编辑自选',
    'complete': '完成',
    'product': '产品',
    'top': '置顶',
    'drag': '拖动',
    'all_selected': '全选',
    'remove': '移除',
    'add_stock_null_tips': '暂无自选品种',
    'requestfail': '数据加载失败',
  };

  List<SelfMarketProductModel> _items = [];
  // 已选品种（symbol 为 key，对齐 iOS model.isselected）
  final Set<String> _selected = {};
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  // ── 颜色常量 ──────────────────────────────────────
  static const Color _kBlue = Color(0xFF00B57A);
  static const Color _kRed = Color(0xFFF95959);

  @override
  void initState() {
    super.initState();
    _requestData();
  }

  // ── 数据请求 ──────────────────────────────────────

  /// 对齐 iOS requestData → STService.requestOptionListWithNeedPoints
  Future<void> _requestData() async {
    setState(() => _isLoading = true);
    try {
      final raw = await ref.read(stServiceProvider).getOptionList();
      if (mounted) {
        setState(() {
          _items = raw
              .map(
                (e) =>
                    SelfMarketProductModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
          // 保留仍在列表中的已选状态
          _selected.retainWhere((s) => _items.any((m) => m.symbol == s));
        });
      }
    } catch (e) {
      debugPrint('WatchlistEditPage: load failed: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// 对齐 iOS requestDeleteOption → STService.requestDeleteOptions → reload
  Future<void> _requestDelete() async {
    if (_selected.isEmpty) return;
    final symbols = _selected.toList();
    setState(() => _isLoading = true);
    try {
      await ref.read(stServiceProvider).removeFromWatchlist(symbols);
      _selected.clear();
      notifyWatchlistChanged(ref);
      await _requestData();
    } catch (e) {
      debugPrint('WatchlistEditPage: delete failed: $e');
      if (mounted) {
        STToast.show(
          context,
          stUserVisibleErrorMessage(e, fallback: _t('requestfail')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// 对齐 iOS finishAction → requestSortOption → pop
  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      final symbols = _items.map((m) => m.symbol).toList();
      await ref.read(stServiceProvider).sortWatchlist(symbols);
      notifyWatchlistChanged(ref);
      if (mounted) context.pop(true); // pop(true) 通知调用方刷新
    } catch (e) {
      debugPrint('WatchlistEditPage: sort failed: $e');
      if (mounted) {
        STToast.show(
          context,
          stUserVisibleErrorMessage(e, fallback: _t('requestfail')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  // ── 选择逻辑 ─────────────────────────────────────

  /// 对齐 iOS didSelectRowAtIndexPath / didDeselectRowAtIndexPath
  void _toggleSelect(String symbol) {
    setState(() {
      if (_selected.contains(symbol)) {
        _selected.remove(symbol);
      } else {
        _selected.add(symbol);
      }
    });
  }

  bool get _allSelected =>
      _items.isNotEmpty && _selected.length == _items.length;

  /// 对齐 iOS selectedAction
  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(_items.map((m) => m.symbol));
      }
    });
  }

  // ── 操作 ─────────────────────────────────────────

  /// 对齐 iOS toTopBlock：移到第 0 位
  void _moveToTop(String symbol) {
    setState(() {
      final idx = _items.indexWhere((m) => m.symbol == symbol);
      if (idx <= 0) return;
      final item = _items.removeAt(idx);
      _items.insert(0, item);
    });
  }

  /// ReorderableListView.onReorder
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
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

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(stLocalizationsOfContext(context, ref));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      backgroundColor: context.adaptiveSurfacePrimary,
      appBar: AppBar(
        backgroundColor: context.adaptiveSurfacePrimary,
        foregroundColor: context.adaptiveTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: context.adaptiveIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.adaptiveTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _t('edit_options'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: context.adaptiveTextPrimary,
          ),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kBlue,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _finish,
                  child: Text(
                    _t('complete'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF4DCB73),
                    ),
                  ),
                ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: context.adaptiveHairline, height: 0.5),
        ),
      ),
      body: Column(
        children: [
          _buildColumnHeader(),
          Container(color: context.adaptiveHairline, height: 0.5),
          Expanded(child: _buildList()),
          _buildBottomBar(bottomInset, hasSelection),
        ],
      ),
    );
  }

  /// 对齐 iOS headerView：产品 / 置顶 / 拖动
  Widget _buildColumnHeader() {
    return SizedBox(
      height: 35,
      child: Row(
        children: [
          const SizedBox(width: 45),
          Text(
            _t('product'),
            style: TextStyle(
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            _t('top'),
            style: TextStyle(
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(width: 60),
          Text(
            _t('drag'),
            style: TextStyle(
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: STLoadAnimationView());
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _t('add_stock_null_tips'),
          style: TextStyle(fontSize: 14, color: context.adaptiveTextSecondary),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: _items.length,
      buildDefaultDragHandles: false,
      onReorder: _onReorder,
      proxyDecorator: (child, _, __) => Material(
        color: context.adaptiveCard,
        elevation: 6,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(4),
        child: child,
      ),
      itemBuilder: (ctx, i) {
        final m = _items[i];
        return _WatchlistRow(
          key: ValueKey(m.symbol),
          model: m,
          selected: _selected.contains(m.symbol),
          index: i,
          onTap: () => _toggleSelect(m.symbol),
          onTop: () => _moveToTop(m.symbol),
        );
      },
    );
  }

  /// 对齐 iOS bottomView：全选 + 删除按钮
  Widget _buildBottomBar(double bottomInset, bool hasSelection) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(color: context.adaptiveHairline, height: 0.5),
        Padding(
          padding: EdgeInsets.fromLTRB(
            15,
            0,
            15,
            bottomInset > 0 ? bottomInset : 12,
          ),
          child: SizedBox(
            height: 57,
            child: Row(
              children: [
                // 全选 （对齐 iOS selectedBtn + allSelectedLab）
                GestureDetector(
                  onTap: _toggleSelectAll,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      _CheckCircle(selected: _allSelected),
                      const SizedBox(width: 8),
                      Text(
                        _t('all_selected'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.adaptiveTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 移除按钮（对齐 iOS deleteBtn：#F95959 enabled / #F6F6F6 disabled）
                GestureDetector(
                  onTap: hasSelection ? _requestDelete : null,
                  child: Container(
                    width: 71,
                    height: 29,
                    decoration: BoxDecoration(
                      color: hasSelection
                          ? _kRed
                          : context.adaptivePlaceholderSurface,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color: hasSelection
                              ? Colors.white
                              : context.adaptiveTextHint,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _t('remove'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: hasSelection
                                ? Colors.white
                                : context.adaptiveTextHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Row widget ────────────────────────────────────────────────────────────────

/// 对齐 iOS STEditOptionalCell（中文模式布局）：
/// [checkbox] | [name\n[icon1][icon2][subtitle]] | [置顶] | [drag]
class _WatchlistRow extends StatelessWidget {
  final SelfMarketProductModel model;
  final bool selected;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onTop;

  const _WatchlistRow({
    super.key,
    required this.model,
    required this.selected,
    required this.index,
    required this.onTap,
    required this.onTop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 57,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 多选框（对齐 iOS UITableViewCellEditControl 自定义图标）
              GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 57,
                  child: Center(child: _CheckCircle(selected: selected)),
                ),
              ),
              // 品种信息（对齐 iOS 中文模式：name 在上，icons+subtitle 在下）
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name.isNotEmpty ? model.name : model.symbol,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.adaptiveTextPrimary,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (model.subTitle != null &&
                        model.subTitle!.isNotEmpty) ...[
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
                                color: context.adaptiveTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 置顶按钮（对齐 iOS toTopBtn，trailing offset -100）
              GestureDetector(
                onTap: onTop,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 57,
                  child: Center(
                    child: Icon(
                      Icons.vertical_align_top_rounded,
                      size: 20,
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
                ),
              ),
              // 拖拽手柄（对齐 iOS UITableViewCellReorderControl，trailing 64pt）
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 44,
                  height: 57,
                  child: Center(
                    child: Icon(
                      Icons.drag_handle_rounded,
                      size: 22,
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Container(color: context.adaptiveHairline, height: 0.5),
        ),
      ],
    );
  }
}

// ── 共享组件 ──────────────────────────────────────────────────────────────────

/// 圆形选择框（对齐 iOS st_market_optional_normal / st_market_optional_selected）
class _CheckCircle extends StatelessWidget {
  final bool selected;
  const _CheckCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF4DCB73) : Colors.transparent,
        border: Border.all(
          color: selected ? const Color(0xFF4DCB73) : const Color(0xFFD9D9D9),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
          : null,
    );
  }
}
