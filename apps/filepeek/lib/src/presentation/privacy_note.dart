import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _privacyPolicyChannel = MethodChannel('com.fylto.lite/privacy_policy');

Uri privacyPolicyUri({required bool chinese}) =>
    Uri.https('fylto1.com', '/privacy.html', {'lang': chinese ? 'zh' : 'en'});

class PrivacyNoteDialog extends StatefulWidget {
  const PrivacyNoteDialog({super.key, required this.zh});

  final bool zh;

  @override
  State<PrivacyNoteDialog> createState() => _PrivacyNoteDialogState();
}

class _PrivacyNoteDialogState extends State<PrivacyNoteDialog> {
  bool _opening = false;
  bool _openFailed = false;

  String t(String cn, String en) => widget.zh ? cn : en;

  Future<void> _openPolicy() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    bool opened;
    try {
      final uri = privacyPolicyUri(chinese: widget.zh);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        opened =
            await _privacyPolicyChannel.invokeMethod<bool>(
              'openPrivacyPolicy',
              {'url': uri.toString(), 'chinese': widget.zh},
            ) ??
            false;
      } else {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _openFailed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(t('隐私说明', 'Privacy note')),
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_openFailed) ...[
              Text(
                t(
                  '无法打开网页。请重试，或在浏览器访问：',
                  'Unable to open the page. Try again or visit this address in your browser:',
                ),
              ),
              SelectableText(privacyPolicyUri(chinese: widget.zh).toString()),
              const SizedBox(height: 16),
            ],
            Text(
              t(
                '文件只在本机检查，不发送至开发者服务器。只有你主动导出时，处理副本或报告才交给系统分享目标。系统文件提供方及设备备份可能另有处理规则。临时导出文件会在下次启动时清理。\n\n运营主体：独立开发者\n支持与隐私联系邮箱：ashcar1986@icloud.com\n隐私政策生效日期：2026-10-21\n\n查看完整隐私政策需要联网，不会附带所选文件或检查报告。',
                'Files are inspected on this device and are not sent to a developer server. A working copy or report reaches a share destination only when you export it. File providers and device backups may have their own handling. Temporary exports are cleared at the next launch.\n\nOperator: Independent developer\nSupport and privacy contact: ashcar1986@icloud.com\nPrivacy policy effective date: 2026-10-21\n\nViewing the full privacy policy requires an internet connection. Selected files and reports are not included in the request.',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: _opening ? null : _openPolicy,
        child: Text(
          _opening ? t('正在打开…', 'Opening…') : t('完整隐私政策', 'Privacy policy'),
        ),
      ),
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: Text(t('关闭', 'Close')),
      ),
    ],
  );
}
