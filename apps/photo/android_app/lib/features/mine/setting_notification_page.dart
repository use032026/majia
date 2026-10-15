import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/st_localizations.dart';
import 'mine_settings_appearance.dart';

/// 对齐 iOS `STNotifiSetViewController` + `STNotifiSettingManager.m`（分组与默认值）；
/// 开关关闭态对齐系统 UISwitch（浅灰轨道）。
class SettingNotificationPage extends ConsumerStatefulWidget {
  const SettingNotificationPage({super.key});

  @override
  ConsumerState<SettingNotificationPage> createState() =>
      _SettingNotificationPageState();
}

class _SettingNotificationPageState
    extends ConsumerState<SettingNotificationPage> {
  bool _allowNotify = true;
  bool _orderDeal = true;
  bool _forceClose = true;
  bool _marginWarning = true;
  bool _marketAlert = true;
  bool _importantNotice = true;
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  static const Map<String, String> _fallbackText = {
    'notification_settings': '通知设置',
    'transaction_related': '交易相关',
    'other_notifications': '其他通知',
    'allow_notifications': '允许通知',
    'order_transaction_reminder': '订单成交提醒',
    'mandatory_liquidation_reminder': '强制平仓提醒',
    'margin_warning': '保证金预警',
    'market_reminder': '行情提醒',
    'important_announcement': '重要公告',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
  }

  void _loadLocalizedTextsIfNeeded() {
    final nextCode = stLanguageCodeOfContext(context);
    if (_languageCode == nextCode && _localized.isNotEmpty) return;
    _languageCode = nextCode;

    final token = ++_languageLoadToken;
    loadStLocalizedTextMap(context, ref, _fallbackText).then((entries) {
      if (!mounted || token != _languageLoadToken) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  Future<void> _loadAll() async {
    final mgr = NotificationSettingManager();
    _allowNotify = await mgr.allowNotify;
    _orderDeal = await mgr.orderDeal;
    _forceClose = await mgr.forceClose;
    _marginWarning = await mgr.marginWarning;
    _marketAlert = await mgr.marketAlert;
    _importantNotice = await mgr.importantNotice;
    if (mounted) setState(() {});
  }

  Future<void> _toggle(_NotifyKey key, bool value) async {
    final mgr = NotificationSettingManager();
    switch (key) {
      case _NotifyKey.allowNotify:
        await mgr.setAllowNotify(value);
        setState(() => _allowNotify = value);
        break;
      case _NotifyKey.orderDeal:
        await mgr.setOrderDeal(value);
        setState(() => _orderDeal = value);
        break;
      case _NotifyKey.forceClose:
        await mgr.setForceClose(value);
        setState(() => _forceClose = value);
        break;
      case _NotifyKey.marginWarning:
        await mgr.setMarginWarning(value);
        setState(() => _marginWarning = value);
        break;
      case _NotifyKey.marketAlert:
        await mgr.setMarketAlert(value);
        setState(() => _marketAlert = value);
        break;
      case _NotifyKey.importantNotice:
        await mgr.setImportantNotice(value);
        setState(() => _importantNotice = value);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mineSettingsPageBg,
      appBar: AppBar(
        backgroundColor: context.mineSettingsNavBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _t('notification_settings'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: context.mineSettingsTextPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: context.mineSettingsTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Section 0: 通知设置
          _buildSectionHeader(_t('notification_settings'), topPad: 12),
          _buildGroup([
            _SwitchRow(
              label: _t('allow_notifications'),
              value: _allowNotify,
              onChanged: (v) => _toggle(_NotifyKey.allowNotify, v),
            ),
          ]),
          // Section 1: 交易相关
          _buildSectionHeader(_t('transaction_related'), topPad: 19),
          _buildGroup([
            _SwitchRow(
              label: _t('order_transaction_reminder'),
              value: _orderDeal,
              onChanged: (v) => _toggle(_NotifyKey.orderDeal, v),
            ),
            _SwitchRow(
              label: _t('mandatory_liquidation_reminder'),
              value: _forceClose,
              onChanged: (v) => _toggle(_NotifyKey.forceClose, v),
            ),
            _SwitchRow(
              label: _t('margin_warning'),
              value: _marginWarning,
              onChanged: (v) => _toggle(_NotifyKey.marginWarning, v),
            ),
          ]),
          // Section 2: 其他通知
          _buildSectionHeader(_t('other_notifications'), topPad: 19),
          _buildGroup([
            _SwitchRow(
              label: _t('market_reminder'),
              value: _marketAlert,
              onChanged: (v) => _toggle(_NotifyKey.marketAlert, v),
            ),
            _SwitchRow(
              label: _t('important_announcement'),
              value: _importantNotice,
              onChanged: (v) => _toggle(_NotifyKey.importantNotice, v),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {double topPad = 20}) {
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(4, topPad, 0, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.mineSettingsSectionTitle,
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.mineSettingsGroupBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: List.generate(children.length * 2 - 1, (index) {
            if (index.isOdd) {
              return Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: context.mineSettingsDivider,
              );
            }
            return children[index ~/ 2];
          }),
        ),
      ),
    );
  }
}

enum _NotifyKey {
  allowNotify,
  orderDeal,
  forceClose,
  marginWarning,
  marketAlert,
  importantNotice,
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  static const Color _kIosGreen = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useCupertino =
        !kIsWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);

    final toggle = useCupertino
        ? CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: _kIosGreen,
          )
        : Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _kIosGreen;
              }
              return context.mineSettingsSwitchOffTrack;
            }),
            thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          );

    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.mineSettingsTextPrimary,
                ),
              ),
            ),
            toggle,
          ],
        ),
      ),
    );
  }
}

// ==================== NotificationSettingManager ====================
/// 对齐 iOS `STNotifiSettingManager.m`：`kCmsNotifiSetting*`；
/// Flutter 早期 `kNotifi*` 仍可读并双向同步写入。
class NotificationSettingManager {
  static const _iosAllowNotify = 'kCmsNotifiSettingYytzKey';
  static const _iosOrderDeal = 'kCmsNotifiSettingDdcjtxKey';
  static const _iosForceClose = 'kCmsNotifiSettingQzpctxKey';
  static const _iosMarginWarning = 'kCmsNotifiSettingBzjyjKey';
  static const _iosMarketAlert = 'kCmsNotifiSettingHqtxKey';
  static const _iosImportantNotice = 'kCmsNotifiSettingZyggKey';

  static const _legacyAllowNotify = 'kNotifiAllowNotify';
  static const _legacyOrderDeal = 'kNotifiOrderDeal';
  static const _legacyForceClose = 'kNotifiForceClose';
  static const _legacyMarginWarning = 'kNotifiMarginWarning';
  static const _legacyMarketAlert = 'kNotifiMarketAlert';
  static const _legacyImportantNotice = 'kNotifiImportantNotice';

  Future<bool> _read(String iosKey, String legacyKey) async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey(iosKey)) {
      return p.getBool(iosKey)!;
    }
    if (p.containsKey(legacyKey)) {
      final v = p.getBool(legacyKey)!;
      await p.setBool(iosKey, v);
      return v;
    }
    const kDefault = true;
    await p.setBool(iosKey, kDefault);
    await p.setBool(legacyKey, kDefault);
    return kDefault;
  }

  Future<void> _write(String iosKey, String legacyKey, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(iosKey, value);
    await p.setBool(legacyKey, value);
  }

  Future<bool> get allowNotify => _read(_iosAllowNotify, _legacyAllowNotify);
  Future<void> setAllowNotify(bool v) =>
      _write(_iosAllowNotify, _legacyAllowNotify, v);

  Future<bool> get orderDeal => _read(_iosOrderDeal, _legacyOrderDeal);
  Future<void> setOrderDeal(bool v) =>
      _write(_iosOrderDeal, _legacyOrderDeal, v);

  Future<bool> get forceClose => _read(_iosForceClose, _legacyForceClose);
  Future<void> setForceClose(bool v) =>
      _write(_iosForceClose, _legacyForceClose, v);

  Future<bool> get marginWarning =>
      _read(_iosMarginWarning, _legacyMarginWarning);
  Future<void> setMarginWarning(bool v) =>
      _write(_iosMarginWarning, _legacyMarginWarning, v);

  Future<bool> get marketAlert => _read(_iosMarketAlert, _legacyMarketAlert);
  Future<void> setMarketAlert(bool v) =>
      _write(_iosMarketAlert, _legacyMarketAlert, v);

  Future<bool> get importantNotice =>
      _read(_iosImportantNotice, _legacyImportantNotice);
  Future<void> setImportantNotice(bool v) =>
      _write(_iosImportantNotice, _legacyImportantNotice, v);
}
