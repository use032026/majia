import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._preferences)
    : _languageCode = _preferences.getString(_languageKey);

  static const _languageKey = 'language_code';
  final SharedPreferences _preferences;
  String? _languageCode;

  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);
  String? get languageCode => _languageCode;

  Future<void> setLanguage(String? languageCode) async {
    _languageCode = languageCode;
    if (languageCode == null) {
      await _preferences.remove(_languageKey);
    } else {
      await _preferences.setString(_languageKey, languageCode);
    }
    notifyListeners();
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()!.notifier!;
}

extension AppLocalization on BuildContext {
  bool get isChinese {
    final selected = AppSettingsScope.of(this).languageCode;
    return (selected ?? Localizations.localeOf(this).languageCode)
            .toLowerCase() ==
        'zh';
  }

  String l(String english) =>
      isChinese ? (AppStrings.chinese[english] ?? english) : english;
}

abstract final class AppStrings {
  static const chinese = <String, String>{
    'Jufu': 'Jufu',
    'A refined finish for every photo': '为每一张照片留下精致余韵',
    'Reset': '重置',
    'Choose Photo': '选照片',
    'Replace Photo': '换照片',
    'Make the moment yours': '让照片留住当下',
    'Add a personal watermark and a soft effect,\nthen save a version made for you.':
        '添加一句水印和一层轻盈效果，\n再保存一张只属于你的照片。',
    'Choose from Photos': '从相册选一张',
    'Swipe left to edit the watermark': '向左滑动，设置水印',
    'Swipe left to adjust the crop': '向左滑动，调整裁剪',
    'Swipe right to edit the watermark': '向右滑动，返回水印设置',
    'Crop Photo': '裁剪照片',
    'Reset Position': '重置位置',
    'Crop Ratio': '裁剪比例',
    'Zoom': '缩放比例',
    'Drag to compose; pinch to zoom and sync the crop scale.':
        '单指拖动调整构图；双指缩放会同步更新裁剪范围。',
    'Photo Effects': '轻盈效果',
    'Monochrome': '灰白效果',
    'Soft, low-saturation monochrome': '柔和低饱和的黑白质感',
    'Brightness': '画面亮度',
    'Effect Strength': '效果强度',
    'Press and hold the photo to compare.': '长按照片，即可对比原图。',
    'Text Watermark': '文字水印',
    'Enter a watermark': '写一句水印',
    'Shine in your own way': '今天也要闪闪发光',
    'Text Color': '文字颜色',
    'Text Size': '文字大小',
    'Text Opacity': '文字透明度',
    'Long press and drag the watermark to position it.': '长按并拖动水印，可以放到喜欢的位置。',
    'Saving…': '正在保存…',
    'Save to Photos': '保存到相册',
    'Saved to Photos': '已保存到相册',
    'Couldn’t save. Check Photo Library permission.': '无法保存，请检查相册权限。',
    'Original': '原图',
    'Lilac': '浅紫',
    'Warm': '暖阳',
    'Film': '胶片',
    'Cinema': '电影',
    'Dusk': '暮紫',
    'Golden': '金辉',
    'Noir': '黑金',
    'Mist': '雾蓝',
    'Mono': '灰白',
    'Settings': '设置',
    'Language': '语言',
    'Follow System': '跟随系统',
    'English': 'English',
    'Simplified Chinese': '简体中文',
    'About': '关于',
    'Version': '版本',
    'Privacy Policy': '隐私政策',
    'Terms of Use': '用户协议',
    'Open in browser': '在浏览器中打开',
    'Couldn’t open this page.': '无法打开此页面。',
    'Couldn’t save mode. Try again.': '无法保存模式，请重试。',
  };
}

abstract final class LegalLinks {
  static Uri privacy(String languageCode) =>
      _page('privacy.html', languageCode);

  static Uri terms(String languageCode) => _page('terms.html', languageCode);

  static Uri _page(String path, String languageCode) =>
      Uri.https('lunelleglobal.com', '/$path', {'lang': languageCode});
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onOpenTrade});

  final Future<void> Function() onOpenTrade;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final legalLanguage = context.isChinese ? 'zh' : 'en';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FC),
      appBar: AppBar(
        title: Text(context.l('Settings')),
        backgroundColor: const Color(0xFFF8F5FC),
        foregroundColor: const Color(0xFF2B2232),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _sectionTitle(context.l('Language')),
          const SizedBox(height: 8),
          _card(
            context,
            RadioGroup<String?>(
              groupValue: settings.languageCode,
              onChanged: settings.setLanguage,
              child: Column(
                children: [
                  _languageTile(settings, null, context.l('Follow System')),
                  const Divider(height: 1, color: Color(0xFFE8E1F0)),
                  _languageTile(settings, 'en', 'English'),
                  const Divider(height: 1, color: Color(0xFFE8E1F0)),
                  _languageTile(
                    settings,
                    'zh',
                    context.l('Simplified Chinese'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context.l('About')),
          const SizedBox(height: 8),
          _card(
            context,
            Column(
              children: [
                VersionHoldTrigger(
                  onActivated: onOpenTrade,
                  child: ListTile(
                    title: Text(context.l('Version')),
                    trailing: const Text(
                      '1.0.0',
                      style: TextStyle(color: Color(0xFF66576F)),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8E1F0)),
                _linkTile(
                  context,
                  context.l('Privacy Policy'),
                  LegalLinks.privacy(legalLanguage),
                ),
                const Divider(height: 1, color: Color(0xFFE8E1F0)),
                _linkTile(
                  context,
                  context.l('Terms of Use'),
                  LegalLinks.terms(legalLanguage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String value) => Text(
    value,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: Color(0xFF66576F),
    ),
  );

  Widget _card(BuildContext context, Widget child) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDFF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8E1F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A42304F),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );

  Widget _languageTile(
    AppSettingsController settings,
    String? value,
    String title,
  ) {
    final selected = settings.languageCode == value;
    return RadioListTile<String?>(
      value: value,
      activeColor: const Color(0xFF725286),
      selected: selected,
      tileColor: selected ? const Color(0xFFF3EDFA) : Colors.transparent,
      selectedTileColor: const Color(0xFFF3EDFA),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? const Color(0xFF2B2232) : const Color(0xFF66576F),
        ),
      ),
    );
  }

  Widget _linkTile(BuildContext context, String title, Uri url) => ListTile(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      size: 24,
      color: Color(0xFF8D7C9B),
    ),
    onTap: () async {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l('Couldn’t open this page.'))),
        );
      }
    },
  );
}

class VersionHoldTrigger extends StatefulWidget {
  const VersionHoldTrigger({
    super.key,
    required this.onActivated,
    required this.child,
  });

  final Future<void> Function() onActivated;
  final Widget child;

  @override
  State<VersionHoldTrigger> createState() => _VersionHoldTriggerState();
}

class _VersionHoldTriggerState extends State<VersionHoldTrigger> {
  static const _holdDuration = Duration(seconds: 5);
  static const _maxMovement = 24.0;

  final Map<int, Offset> _touches = {};
  Timer? _holdTimer;
  bool _rejected = false;
  bool _activated = false;

  void _startHold() {
    _holdTimer = Timer(_holdDuration, () {
      if (!mounted || _touches.length != 1 || _rejected || _activated) return;
      _activated = true;
      _activate();
    });
  }

  void _rejectHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _rejected = true;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activated || event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.position;
    if (_touches.length == 1 && !_rejected) {
      _startHold();
    } else if (_touches.length > 1) {
      _rejectHold();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _touches[event.pointer];
    if (start == null || _rejected || _activated) return;
    if ((event.position - start).distance > _maxMovement) _rejectHold();
  }

  void _onPointerEnd(int pointer) {
    if (!_touches.containsKey(pointer)) return;
    if (_holdTimer != null) _rejectHold();
    _touches.remove(pointer);
    if (_touches.isEmpty) _rejected = false;
  }

  void _onPointerCancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _touches.clear();
    _rejected = false;
  }

  Future<void> _activate() async {
    _holdTimer = null;
    try {
      await widget.onActivated();
    } catch (_) {
      if (!mounted) return;
      _activated = false;
      _rejected = _touches.isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l('Couldn’t save mode. Try again.'))),
      );
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: (event) => _onPointerEnd(event.pointer),
    onPointerCancel: (_) => _onPointerCancel(),
    child: widget.child,
  );
}
