import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../report/report_service.dart';
import 'app_theme.dart';
import 'widgets/common.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static Future<void> open(BuildContext context) async {
    final locale = AppLocalizations.resolve(Localizations.localeOf(context));
    final url = Uri.https('jovfx1.com', '/privacy.html', {
      'lang': locale.languageCode,
    });
    if (await _openInBrowser(url) || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  static Future<bool> _openInBrowser(Uri url) async {
    try {
      return await ReportService.channel.invokeMethod<bool>(
            'openPrivacyPolicy',
            {'url': url.toString()},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('privacy-policy-screen'),
      appBar: AppBar(title: const LText('隐私政策')),
      body: SelectionArea(
        child: ListView(
          key: const Key('privacy-policy-content'),
          padding: AppInsets.scrollable(context, left: 20, top: 12, right: 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.appColors.softSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: context.appColors.brand,
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  LText(
                    '隐私概览',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: context.appColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LText(
                    'JOVFX 是一款本地优先的照片记录工具。本政策说明本版本如何处理你在使用过程中提供的内容。',
                    style: TextStyle(
                      color: context.appColors.muted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LText(
                    '最后更新：2026 年 11 月 17 日',
                    style: TextStyle(
                      color: context.appColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _PolicySection(
              title: '我们处理的信息',
              paragraphs: [
                '你主动输入的项目名称、地址、记录人、联系人、说明、负责人和期限。',
                '你通过相机拍摄或从系统相册选择的照片，以及添加的方框、箭头和文字标注。',
              ],
            ),
            const _PolicySection(
              title: '本地存储与传输',
              paragraphs: [
                '上述内容默认保存在本设备的应用沙盒中。本版本不提供账号、云同步、广告或分析服务，开发者服务器不会接收这些内容。',
              ],
            ),
            const _PolicySection(
              title: '系统权限',
              paragraphs: ['只有在你选择拍照或导入照片时，App 才会调用系统相机或照片选择器。如果系统提示授权，你可以拒绝。'],
            ),
            const _PolicySection(
              title: '分享与备份',
              paragraphs: [
                'PDF 和本地备份均在设备上生成。只有当你主动使用系统分享面板时，文件才会发送给你选择的接收方或服务。',
                '文件导出应用后，由你选择的存储位置或第三方服务按照其隐私政策处理。',
              ],
            ),
            const _PolicySection(
              title: '保留与删除',
              paragraphs: [
                '本地内容会保留到你删除项目、恢复其他备份或卸载应用。删除项目会同步删除其记录和应用管理的照片副本。',
                '已导出的 PDF、备份或已分享的副本不在本应用控制范围内，需要由你在对应位置另行删除。',
              ],
            ),
            const _PolicySection(
              title: '第三方服务',
              paragraphs: [
                '本版本使用 Flutter 和设备提供的相机、照片选择、文件预览及分享功能，不包含广告或用户行为分析 SDK。',
                '打开线上隐私政策时，系统浏览器会访问 JOVFX 官网。浏览器与网站托管服务可能处理连接信息。',
              ],
            ),
            const _PolicySection(
              title: '政策更新与联系',
              paragraphs: [
                '如果功能或数据处理方式发生变化，我们会更新本政策。',
                '运营主体为独立开发者。若有隐私问题，请联系 PadonSolmonson469@outlook.com。',
              ],
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.title,
    required this.paragraphs,
    this.showDivider = true,
  });

  final String title;
  final List<String> paragraphs;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LText(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.appColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final paragraph in paragraphs) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.appColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LText(
                  paragraph,
                  style: TextStyle(
                    color: context.appColors.muted,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (showDivider) ...[
          const SizedBox(height: 8),
          Divider(color: context.appColors.line),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
