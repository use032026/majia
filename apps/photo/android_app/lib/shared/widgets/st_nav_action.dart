import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/card_tool.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/router/router_guard.dart';
import '../../core/theme/context_adaptive_colors.dart';

typedef StNavRouteOpener =
    Future<void> Function(String path, Map<String, dynamic>? params);

/// 顶栏 CMS 操作按钮：单路由跳转或下拉菜单（对齐 iOS `STPopMenu` + `openRouterWithActionItem:`）
Future<void> handleStNavAction(
  BuildContext context,
  ActionItem action, {
  RenderBox? anchor,
  StNavRouteOpener? openRoute,
}) async {
  if (action.menuItems.isNotEmpty) {
    await _showStNavPopMenu(
      context,
      action.menuItems,
      anchor: anchor,
      openRoute: openRoute,
    );
    return;
  }
  await _openStNavAction(context, action, openRoute: openRoute);
}

Future<void> _openStNavAction(
  BuildContext context,
  ActionItem action, {
  StNavRouteOpener? openRoute,
}) async {
  final perm = action.routerPermission ?? '';
  if (perm.isNotEmpty) {
    final r = await RouterGuard.checkPermission(action.router ?? '/', {
      'permission': perm,
    });
    if (!context.mounted) return;
    if (r != null) {
      await _openStNavRoute(context, r, {
        'permission': perm,
      }, openRoute: openRoute);
      return;
    }
  }
  if (!context.mounted) return;

  final route = action.router?.trim() ?? '';
  if (route.isNotEmpty) {
    final params = <String, dynamic>{};
    final link = action.link ?? (action.params?['link'] as String?);
    if (link != null && link.isNotEmpty) params['link'] = link;
    if (perm.isNotEmpty) params['permission'] = perm;
    await _openStNavRoute(
      context,
      route,
      params.isEmpty ? null : params,
      openRoute: openRoute,
    );
    return;
  }

  final link = action.link ?? (action.params?['link'] as String?);
  if (link != null && link.isNotEmpty) {
    await _openStNavRoute(context, '/web', {
      'link': link,
      if (perm.isNotEmpty) 'permission': perm,
    }, openRoute: openRoute);
  }
}

Future<void> _openStNavRoute(
  BuildContext context,
  String route,
  Map<String, dynamic>? params, {
  StNavRouteOpener? openRoute,
}) async {
  if (openRoute != null) {
    await openRoute(route, params);
    return;
  }
  if (!context.mounted) return;
  if (params == null || params.isEmpty) {
    context.push(route);
    return;
  }
  final uri = Uri.parse(route);
  final merged = <String, String>{
    ...uri.queryParameters,
    for (final entry in params.entries) entry.key: '${entry.value}',
  };
  context.push(uri.replace(queryParameters: merged).toString());
}

Future<void> _showStNavPopMenu(
  BuildContext context,
  List<ActionItem> items, {
  RenderBox? anchor,
  StNavRouteOpener? openRoute,
}) async {
  if (items.isEmpty || !context.mounted) return;

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  final box = anchor ?? context.findRenderObject() as RenderBox?;
  if (overlay == null || box == null) {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              ListTile(
                title: Text(item.title ?? ''),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openStNavAction(context, item, openRoute: openRoute);
                },
              ),
          ],
        ),
      ),
    );
    return;
  }

  final target = box.localToGlobal(Offset.zero, ancestor: overlay);
  final size = box.size;
  const menuWidth = 145.0;
  final left = (target.dx + size.width - menuWidth + 12).clamp(
    8.0,
    overlay.size.width - menuWidth - 8,
  );
  final top = target.dy + size.height + 10;

  await showMenu<ActionItem>(
    context: context,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    position: RelativeRect.fromLTRB(left, top, left + menuWidth, top),
    items: [
      for (final item in items)
        PopupMenuItem<ActionItem>(
          value: item,
          height: 40,
          child: Text(
            item.title ?? '',
            style: TextStyle(
              fontSize: (item.titleFont ?? 14).toDouble(),
              color:
                  CardTool.parseAdaptiveHexColor(
                    context,
                    item.titleColor,
                    category: CardTool.iosDarkModeTextColorKey,
                  ) ??
                  context.adaptiveTextPrimary,
              fontWeight: _navFontWeight(item.titleWeight),
            ),
          ),
        ),
    ],
  ).then((picked) async {
    if (picked != null && context.mounted) {
      await _openStNavAction(context, picked, openRoute: openRoute);
    }
  });
}

FontWeight _navFontWeight(String? w) {
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
