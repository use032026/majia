part of 'app.dart';

class _PrivacyPolicyPage extends StatelessWidget {
  const _PrivacyPolicyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.6,
    );
    return Scaffold(
      key: const ValueKey('privacy.policy'),
      appBar: AppBar(title: Text(_text(context, '隐私政策', 'Privacy Policy'))),
      body: SelectionArea(
        child: _SupportingBody(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SupportingIcon(CupertinoIcons.lock_shield),
                    const SizedBox(height: 12),
                    _SupportingHeading(
                      _text(context, '隐私概览', 'Privacy overview'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(
                        context,
                        'ISDFX 在本机生成并复现合成证件号测试用例。请勿在输入或导入文件中包含真实证件号或其他个人信息。',
                        'ISDFX generates and replays synthetic document-number cases on your device. Keep real identifiers and other personal information out of inputs and imported files.',
                      ),
                      style: bodyStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(
                        context,
                        '2026 年 11 月 26 日生效',
                        'Effective November 26, 2026',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            for (final (titleZh, titleEn, bodyZh, bodyEn)
                in _privacySections) ...[
              const SizedBox(height: 20),
              _SupportingHeading(_text(context, titleZh, titleEn)),
              const SizedBox(height: 6),
              Text(_text(context, bodyZh, bodyEn), style: bodyStyle),
            ],
          ],
        ),
      ),
    );
  }
}

const _privacySections = [
  (
    '信息与本地存储',
    'Information and local storage',
    '应用在设备上处理所选参数、复现种子和您选定的 JSON 用例包。生成结果和逐项检查留在当前会话，语言、外观及引导状态保存为本地偏好。使用应用无需账号。',
    'The app processes selected parameters, the replay seed, and the JSON package you choose on your device. Results and rule checks stay in the current session. Language, appearance, and onboarding status are stored as local preferences. No account is required.',
  ),
  (
    '设备访问与分享',
    'Device access and sharing',
    '应用使用系统文件选择器读取您选定的 JSON，并在您主动复制时使用剪贴板。导出用例包通过系统分享面板交给您选择的接收方。生成与复现不请求相机、麦克风、位置、通讯录、相册或通知权限。',
    'The app uses the system file picker to read the JSON file you select and the clipboard when you copy. You choose where to send exported packages using the system share sheet. Generation and replay do not request camera, microphone, location, contacts, photo library, or notification access.',
  ),
  (
    '网络与第三方服务',
    'Network and third-party services',
    '生成与复现不依赖 ISDFX 服务器。应用未接入云同步、广告、跟踪、分析或 AI 服务。打开公开规则来源和官网隐私政策时会调用外部应用，其服务及目标网站按各自政策处理访问。',
    'Generation and replay do not rely on an ISDFX server. The app does not include cloud sync, advertising, tracking, analytics, or AI services. Public rule sources and the online policy open in an external app. The destination and the external app handle the visit under their own policies.',
  ),
  (
    '保留、删除与备份',
    'Retention, deletion, and backups',
    '导出文件临时保存在应用内，应用不设固定清理时间，操作系统可清理它们。清除应用数据或删除应用可移除本地偏好和临时文件。另存、复制或分享的内容需在对应位置管理。Android 应用配置关闭了应用备份，设备间迁移仍受系统管理。iOS 可按系统设置备份符合条件的应用数据。',
    'Exports are written to temporary app files. The app sets no fixed deletion time, and the operating system may clear them. Clearing app data or deleting the app removes local preferences and temporary files. Manage saved, copied, or shared content at its destination. Android app backup is disabled in the app configuration, and device transfers are controlled by the OS. On iOS, eligible app data may be backed up according to system settings.',
  ),
  (
    '儿童隐私',
    "Children's privacy",
    'ISDFX 面向软件开发与质量测试，不设账号或年龄采集表单。请勿在测试用例中填写儿童的真实信息。',
    'ISDFX is designed for software development and quality assurance. It has no account or age collection form. Keep real information about children out of test cases.',
  ),
  (
    '政策更新与联系',
    'Policy updates and contact',
    'ISDFX 由独立开发者运营。更新以官网公布的隐私政策为准。如有隐私问题或请求，请联系 GerardBooher3020@outlook.com。',
    'ISDFX is operated by an independent developer. Updates appear in the online privacy policy. For questions or requests, contact GerardBooher3020@outlook.com.',
  ),
];
