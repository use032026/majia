import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/theme/context_adaptive_colors.dart';

/// 消息中心
/// 对齐 Figma APP 白标 2.0：消息列表 / 消息详情 / 空态
class MessageCenterPage extends ConsumerStatefulWidget {
  const MessageCenterPage({super.key});

  @override
  ConsumerState<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends ConsumerState<MessageCenterPage>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _fallbackText = {
    'message_center': '消息中心',
    'system_notification': '系统通知',
    'trade_notification': '交易通知',
    'activity_notification': '活动通知',
    'no_system_notification': '暂无系统通知',
    'no_trade_notification': '暂无交易通知',
    'no_activity_notification': '暂无活动通知',
    'no_message': '暂无消息',
  };

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ref.watch(stLocalizationsProvider);
    return FutureBuilder<Map<String, String>>(
      future: localizations.textMap(_fallbackText),
      initialData: _fallbackText,
      builder: (context, snapshot) {
        final text = snapshot.data ?? _fallbackText;
        String t(String key) => text[key] ?? _fallbackText[key] ?? key;

        return Scaffold(
          backgroundColor: context.adaptivePageGrey,
          appBar: AppBar(
            backgroundColor: context.adaptiveSurfacePrimary,
            elevation: 0,
            centerTitle: true,
            title: Text(
              t('message_center'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFF00B57A),
              unselectedLabelColor: context.adaptiveTextSecondary,
              indicatorColor: const Color(0xFF00B57A),
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              tabs: [
                Tab(text: t('system_notification')),
                Tab(text: t('trade_notification')),
                Tab(text: t('activity_notification')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _MessageList(emptyDescription: t('no_system_notification')),
              _MessageList(emptyDescription: t('no_trade_notification')),
              _MessageList(emptyDescription: t('no_activity_notification')),
            ],
          ),
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.emptyDescription});

  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    // 占位数据（对接真实 API 后替换）
    final items = <Map<String, String>>[];

    if (items.isEmpty) {
      return _EmptyView(description: emptyDescription);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: context.adaptiveDivider,
      ),
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          tileColor: context.adaptiveCard,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications_none,
              color: Color(0xFF00B57A),
            ),
          ),
          title: Text(
            item['title'] ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.adaptiveTextPrimary,
            ),
          ),
          subtitle: Text(
            item['time'] ?? '',
            style: TextStyle(
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            size: 20,
            color: context.adaptiveTextSecondary,
          ),
          onTap: () {},
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: context.adaptiveTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
