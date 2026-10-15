import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_observer.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'st_keyboard_actions.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

/// iOS 对齐基线：
/// - 默认白色背景
/// - 提供与 `STBaseViewController` 对齐的返回兜底动作（优先 pop，否者回到 `/`）
/// - 支持自定义返回/关闭按钮和右侧动作
/// - 提供点击收起键盘的行为对齐 `touchesBegan`
class STBaseScaffold extends StatelessWidget {
  const STBaseScaffold({
    super.key,
    required this.body,
    this.showNavigationBar = false,
    this.title,
    this.leading,
    this.onBack,
    this.showClose = false,
    this.onClose,
    this.actions,
    this.backgroundColor,
    this.barColor,
    this.dismissKeyboardOnTap = true,
    this.keyboardFocusNodes = const [],
    this.scrollUnderElevation = 0,
    this.centerTitle = false,
  });

  /// 页面内容
  final Widget body;

  /// 是否展示导航栏（默认不展示，等价 iOS `cmsNav` 隐藏）
  final bool showNavigationBar;

  /// 导航标题
  final String? title;

  /// 自定义左侧按钮；不传时默认使用返回按钮（若提供 [onBack]）
  final Widget? leading;

  /// 默认返回行为（`context.canPop` 则 pop，否则 `go('/')`）
  final VoidCallback? onBack;

  /// 是否展示关闭按钮
  final bool showClose;

  /// 关闭按钮点击；默认与 onBack 一致
  final VoidCallback? onClose;

  /// 右侧动作列表
  final List<Widget>? actions;

  /// 背景色
  final Color? backgroundColor;

  /// AppBar 颜色
  final Color? barColor;

  /// 点击空白区域是否收起键盘
  final bool dismissKeyboardOnTap;

  /// 输入页需要键盘工具条管理的焦点列表，顺序等价 iOS subviews 顺序。
  final List<FocusNode> keyboardFocusNodes;

  /// AppBar 下滑透传样式
  final double scrollUnderElevation;

  /// 标题是否居中
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = backgroundColor ?? context.adaptiveSurfacePrimary;
    final bar = barColor ?? background;
    final appBarIconColor = context.adaptiveTextPrimary;
    final overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final managedBody = keyboardFocusNodes.isEmpty
        ? body
        : STKeyboardActions(focusNodes: keyboardFocusNodes, child: body);

    final fallbackActions = <Widget>[];
    if (showClose) {
      fallbackActions.add(
        IconButton(
          icon: Icon(Icons.close, color: appBarIconColor, size: 20),
          onPressed: onClose ?? () => context.popOrGoRoot(),
          tooltip: stLocalizedTextFromZhHans('关闭'),
        ),
      );
    }
    if (actions != null) {
      fallbackActions.addAll(actions!);
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: dismissKeyboardOnTap
          ? (event) => dismissCurrentKeyboardFocus(
              pointerGlobalPosition: event.position,
            )
          : null,
      child: Scaffold(
        backgroundColor: background,
        appBar: showNavigationBar
            ? AppBar(
                backgroundColor: bar,
                elevation: 0,
                scrolledUnderElevation: scrollUnderElevation,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 44,
                centerTitle: centerTitle,
                systemOverlayStyle: overlayStyle,
                titleSpacing: title == null ? 0 : null,
                title: title == null
                    ? null
                    : Text(
                        title!,
                        style: TextStyle(
                          color: appBarIconColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                automaticallyImplyLeading: false,
                leading:
                    leading ??
                    (onBack == null
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: appBarIconColor,
                              size: 20,
                            ),
                            onPressed: onBack,
                            tooltip: stLocalizedTextFromZhHans('返回'),
                          )),
                actions: fallbackActions,
              )
            : null,
        body: managedBody,
      ),
    );
  }
}

extension STBaseNavigation on BuildContext {
  /// 对齐 `STBaseViewController.backAction`：
  /// 有栈先 pop，无栈则返回首页。
  void popOrGoRoot() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}
