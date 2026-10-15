import 'package:flutter/material.dart';

import '../../core/config/card_tool.dart';
import '../../core/models/tab_bar_item.dart';
import '../../shared/widgets/st_nav_action.dart';

/// CMS 顶栏 + 页面背景（对齐 iOS `STProjectListViewController.setBg` / `addNaviBar`）
class CardListPageChrome extends StatelessWidget {
  final TabBarItemData tab;
  final Widget child;
  final void Function(ActionItem action, RenderBox? anchor)? onNavAction;
  final Color? backgroundColor;

  const CardListPageChrome({
    super.key,
    required this.tab,
    required this.child,
    this.onNavAction,
    this.backgroundColor,
  });

  static const double navContentHeight = 44;

  /// 对齐 iOS `addNaviBar`：有 `nav_style` 即渲染顶栏（如 `nav_1`）
  static bool hasNavBar(NavInfo? nav) {
    if (nav == null) return false;
    final style = nav.navigationStyle ?? '';
    if (style.startsWith('nav_') || style.startsWith('tabnav_')) return true;
    return (nav.title?.isNotEmpty ?? false) ||
        (nav.icon?.isNotEmpty ?? false) ||
        (nav.actionItems?.isNotEmpty ?? false);
  }

  bool get _hasNavBar => hasNavBar(tab.navInfo);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgPaint =
        backgroundColor ??
        CardTool.parseAdaptiveHexColor(
          context,
          tab.bgColor != null && tab.bgColor!.isNotEmpty ? tab.bgColor : null,
          category: CardTool.iosDarkModeTotalBgColorKey,
        ) ??
        (isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : CardTool.iosPageBackgroundGrey);
    final bgUrl = isDark
        ? (tab.bgIconDark?.isNotEmpty == true ? tab.bgIconDark : tab.bgIcon)
        : tab.bgIcon;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ColoredBox(color: bgPaint)),
        if (bgUrl != null && bgUrl.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.network(
                bgUrl,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                width: MediaQuery.sizeOf(context).width,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hasNavBar) _buildNavBar(context, isDark),
            Expanded(child: child),
          ],
        ),
      ],
    );
  }

  /// 对齐 iOS `STNaviBarView`（`nav_1`）：状态栏 + 44 内容区，左 logo + 标题，右操作按钮
  Widget _buildNavBar(BuildContext context, bool isDark) {
    final nav = tab.navInfo!;
    final actions = nav.actionItems ?? const <ActionItem>[];
    final navKey = GlobalKey();

    final titleColor =
        _navTextColor(context, nav.titleColor) ??
        Theme.of(context).colorScheme.onSurface;
    final titleFont = (nav.titleFont ?? 15).toDouble();
    final iconUrl = isDark && (nav.iconDark?.isNotEmpty == true)
        ? nav.iconDark!
        : (nav.icon ?? '');

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: navContentHeight,
          child: Row(
            children: [
              const SizedBox(width: 15),
              if (iconUrl.isNotEmpty)
                Image.network(
                  iconUrl,
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 24),
                ),
              if (iconUrl.isNotEmpty && (nav.title?.isNotEmpty ?? false))
                const SizedBox(width: 1),
              if (nav.title?.isNotEmpty ?? false)
                Expanded(
                  child: Text(
                    nav.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFont,
                      fontWeight: _weight(nav.titleWeight),
                      color: titleColor,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (actions.isNotEmpty)
                Row(
                  key: navKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in _visibleActions(actions))
                      _CardListNavActionButton(
                        action: a,
                        isDark: isDark,
                        onPressed: () {
                          RenderBox? anchor;
                          final ctx = navKey.currentContext;
                          if (ctx != null) {
                            anchor = ctx.findRenderObject() as RenderBox?;
                          }
                          if (onNavAction != null) {
                            onNavAction!(a, anchor);
                          } else {
                            handleStNavAction(context, a, anchor: anchor);
                          }
                        },
                      ),
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Color? _navTextColor(BuildContext context, String? raw) {
    return CardTool.parseAdaptiveHexColor(
      context,
      raw,
      category: CardTool.iosDarkModeTextColorKey,
    );
  }

  List<ActionItem> _visibleActions(List<ActionItem> items) {
    if (items.length <= 2) return items;
    return items.take(2).toList();
  }

  FontWeight _weight(String? w) {
    switch (w?.toLowerCase()) {
      case 'bold':
        return FontWeight.w700;
      case 'medium':
        return FontWeight.w500;
      case 'semibold':
        return FontWeight.w600;
      default:
        return FontWeight.w400;
    }
  }
}

class _CardListNavActionButton extends StatelessWidget {
  final ActionItem action;
  final bool isDark;
  final VoidCallback onPressed;

  const _CardListNavActionButton({
    required this.action,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = action.style ?? 0;
    if (style == 1) {
      final fs = (action.titleFont ?? 14).toDouble();
      final c =
          _navTextColor(context, action.titleColor) ??
          Theme.of(context).colorScheme.onSurface;
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(34, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          action.title ?? '',
          style: TextStyle(
            fontSize: fs,
            color: c,
            fontWeight: _weight(action.titleWeight),
          ),
        ),
      );
    }
    final iconUrl = isDark && (action.iconDark?.isNotEmpty == true)
        ? action.iconDark!
        : (action.icon ?? '');
    if (iconUrl.isEmpty) {
      return const SizedBox(width: 34);
    }
    return IconButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
      icon: Image.network(
        iconUrl,
        width: 22,
        height: 22,
        errorBuilder: (_, __, ___) => const Icon(Icons.more_horiz, size: 22),
      ),
    );
  }

  Color? _navTextColor(BuildContext context, String? raw) {
    return CardTool.parseAdaptiveHexColor(
      context,
      raw,
      category: CardTool.iosDarkModeTextColorKey,
    );
  }

  FontWeight _weight(String? w) {
    switch (w?.toLowerCase()) {
      case 'bold':
        return FontWeight.w700;
      case 'medium':
        return FontWeight.w500;
      case 'semibold':
        return FontWeight.w600;
      default:
        return FontWeight.w400;
    }
  }
}
