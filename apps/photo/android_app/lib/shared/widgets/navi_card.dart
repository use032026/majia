import 'package:flutter/material.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'card_factory.dart';
import 'base_card.dart';

/// 导航菜单卡片 (nav_1)
/// 对齐 iOS Navi1CardView：横向滚动图标 + 标题导航条
///
/// 服务端配置:
///   cardDetail.items[]: { icon, title, router, link }
///   每项显示 40x40 图标 + 标题，横向可滚动
class NaviCard extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const NaviCard({super.key, required super.cardData, this.onNavigate});

  @override
  Widget buildCardContent(BuildContext context) {
    final detail = cardData.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) => e as Map<String, dynamic>).toList();

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: items.isEmpty
          ? Center(
              child: Text(cardData.title ?? '导航菜单',
                  style: TextStyle(color: context.adaptiveTextHint, fontSize: 13)),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final iconUrl = item['icon'] as String?;
                final title = item['title'] as String? ?? '';
                final route = CardFactory.extractItemRoute(item);

                return GestureDetector(
                  onTap: () {
                    if (route.path.isNotEmpty) {
                      onNavigate?.call(route.path, route.params);
                    }
                  },
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: iconUrl != null && iconUrl.isNotEmpty
                              ? Image.network(
                                  iconUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholderIcon(context),
                                )
                              : _placeholderIcon(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _placeholderIcon(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.adaptiveIconPillBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.apps, size: 20, color: context.adaptiveTextHint),
    );
  }
}

/// Tab 导航卡片 (tabnav_1)
/// 对齐 iOS TabNavi1CardView：分段式 Tab 切换导航
///
/// 服务端配置:
///   cardDetail.items[]: { icon, title, router, link }
///   显示为一行分段按钮，类似 SegmentedControl
class TabNaviCard extends BaseCard {
  final CardNavigateCallback? onNavigate;

  const TabNaviCard({super.key, required super.cardData, this.onNavigate});

  @override
  Widget buildCardContent(BuildContext context) {
    final detail = cardData.cardDetail;
    final rawItems = detail?['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) => e as Map<String, dynamic>).toList();

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Center(
          child: Text(cardData.title ?? 'Tab 导航',
              style: TextStyle(color: context.adaptiveTextHint)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final title = item['title'] as String? ?? '';
          final iconUrl = item['icon'] as String?;
          final route = CardFactory.extractItemRoute(item);
          final isLast = index == items.length - 1;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (route.path.isNotEmpty) {
                  onNavigate?.call(route.path, route.params);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: isLast
                        ? BorderSide.none
                        : BorderSide(color: context.adaptiveHairline),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconUrl != null && iconUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            iconUrl,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.circle, size: 24,
                                color: context.adaptiveTextHint),
                          ),
                        ),
                      ),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
