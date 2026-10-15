import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/config/config_data_manager.dart';
import '../../core/config/card_tool.dart';
import '../../core/theme/context_adaptive_colors.dart';
import 'embed_web_content.dart';
import 'st_mini_view.dart';

/// 卡片基类
/// 对齐 iOS `STBaseCardView`（圆角、可选边框 `CardSize_Border`、`bgColor` 透明则白底卡片）
abstract class BaseCard extends StatelessWidget {
  final ConfigCardItemData cardData;

  /// 紧贴 CMS 顶栏的首卡（如 banner）：去掉额外 top inset，对齐 iOS scrollView 首卡间距
  final bool compactTop;

  const BaseCard({super.key, required this.cardData, this.compactTop = false});

  @protected
  Color cardSurface(BuildContext context) {
    final fromConfig = CardTool.parseAdaptiveHexColor(
      context,
      cardData.bgColor,
      category: CardTool.iosDarkModeChildBgColorKey,
    );
    if (fromConfig != null) return fromConfig;
    return context.adaptiveCard;
  }

  @protected
  Widget buildCardShell(BuildContext context, Widget child) {
    return Consumer(
      builder: (context, ref, _) {
        final configMgr = ref.watch(configDataManagerProvider);
        final corner = configMgr.cardCorner;
        final horGap = configMgr.cardHorGap;
        final verGap = configMgr.cardVerGap;
        final borderW = configMgr.cardBorder;

        final theme = Theme.of(context);
        final bg = cardSurface(context);
        final border = borderW > 0
            ? Border.all(
                color: theme.dividerColor.withValues(alpha: 0.35),
                width: borderW,
              )
            : null;

        return Container(
          margin: EdgeInsets.fromLTRB(
            horGap,
            compactTop ? 0 : verGap,
            horGap,
            verGap,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(corner),
            border: border,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(corner),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!cardData.isShow) return const SizedBox.shrink();
    return buildCardShell(context, buildCardContent(context));
  }

  Widget buildCardContent(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// H5 Web 卡片（内嵌 WebView），对齐 iOS `STWebCardView`
class WebCard extends BaseCard {
  final ValueListenable<bool>? pageVisibleListenable;

  const WebCard({
    super.key,
    required super.cardData,
    super.compactTop,
    this.pageVisibleListenable,
  });

  static String resolveUrl(ConfigCardItemData card) {
    final d = card.cardDetail;
    return (card.link?.trim().isNotEmpty == true ? card.link!.trim() : null) ??
        (d?['url'] as String?)?.trim() ??
        (d?['link'] as String?)?.trim() ??
        '';
  }

  @override
  Widget buildCardContent(BuildContext context) {
    final url = resolveUrl(cardData);
    final mq = MediaQuery.sizeOf(context).width;
    final ratio = cardData.aspectRatio ?? (16 / 9); // 默认横向比例，避免过高
    final h = (mq - 32) / ratio.clamp(0.5, 4.0);

    if (url.isEmpty) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            'H5 卡片未配置链接',
            style: TextStyle(fontSize: 13, color: context.adaptiveTextTertiary),
          ),
        ),
      );
    }

    return SizedBox(
      height: h.clamp(120.0, 560.0),
      width: double.infinity,
      child: EmbedWebContent(
        url: url,
        pageVisibleListenable: pageVisibleListenable,
      ),
    );
  }
}

/// Mini（online）卡片内嵌容器，对齐 iOS Mini 卡片
class MiniEmbedCard extends BaseCard {
  const MiniEmbedCard({super.key, required super.cardData, super.compactTop});

  static String resolveLink(ConfigCardItemData card) {
    final d = card.cardDetail;
    return (card.link?.trim().isNotEmpty == true ? card.link!.trim() : null) ??
        (d?['link'] as String?)?.trim() ??
        '';
  }

  static String resolvePath(ConfigCardItemData card) {
    final d = card.cardDetail;
    return (d?['path'] as String?)?.trim() ?? '';
  }

  @override
  Widget buildCardContent(BuildContext context) {
    final link = resolveLink(cardData);
    final path = resolvePath(cardData);
    final mq = MediaQuery.sizeOf(context).width;
    final ratio = cardData.aspectRatio ?? (16 / 9);
    final h = (mq - 32) / ratio.clamp(0.5, 4.0);

    if (link.isEmpty) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            'Mini 卡片未配置链接',
            style: TextStyle(fontSize: 13, color: context.adaptiveTextTertiary),
          ),
        ),
      );
    }

    return SizedBox(
      height: h.clamp(120.0, 560.0),
      width: double.infinity,
      child: STMiniView(link: link, path: path, embedded: true),
    );
  }
}
