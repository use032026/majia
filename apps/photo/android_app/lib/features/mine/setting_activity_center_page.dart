import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/context_adaptive_colors.dart';
import 'package:jufu/shared/widgets/st_localized_prompt.dart';

/// 活动中心
/// 对齐 Figma APP 白标 2.0：任务中心 / 活动列表入口
class SettingActivityCenterPage extends ConsumerStatefulWidget {
  const SettingActivityCenterPage({super.key});

  @override
  ConsumerState<SettingActivityCenterPage> createState() =>
      _SettingActivityCenterPageState();
}

class _SettingActivityCenterPageState
    extends ConsumerState<SettingActivityCenterPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adaptivePageGrey,
      appBar: AppBar(
        backgroundColor: context.adaptiveSurfacePrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '活动中心',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: context.adaptiveTextPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: context.adaptiveTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildGroup([
            _ActivityItem(
              icon: Icons.task_alt_outlined,
              label: stLocalizedTextFromZhHans(''),
              subtitle: stLocalizedTextFromZhHans(''),
              onTap: () => context.push('/taskcenter'),
            ),
            _ActivityItem(
              icon: Icons.card_giftcard_outlined,
              label: stLocalizedTextFromZhHans(''),
              subtitle: stLocalizedTextFromZhHans(''),
              onTap: () {},
            ),
            _ActivityItem(
              icon: Icons.emoji_events_outlined,
              label: stLocalizedTextFromZhHans(''),
              subtitle: stLocalizedTextFromZhHans(''),
              onTap: () {},
            ),
            _ActivityItem(
              icon: Icons.group_add_outlined,
              label: stLocalizedTextFromZhHans(''),
              subtitle: stLocalizedTextFromZhHans(''),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: context.adaptiveDivider,
            );
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActivityItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 74,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF00B57A), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.adaptiveTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
