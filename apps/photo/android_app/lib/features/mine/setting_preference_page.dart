import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/ios_language_catalog.dart';
import '../../core/config/card_tool.dart';
import '../../core/config/theme_service.dart';
import '../../core/models/user_state.dart';
import '../../core/models/app_language_option.dart';
import '../../core/providers/available_languages_provider.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/router/st_router.dart';
import '../../core/services/app_locale_service.dart';
import '../../core/services/user_preference_controller.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../core/utils/timezone_util.dart';
import 'mine_settings_appearance.dart';

/// 对齐 iOS `STPreferenceSetViewController` + `STMineCommonCell`（`STMineModule_PreferenceSet`）：
/// - 语言摘要：与 `-[STBundle languageName]` 一致，优先用接口 `languages` 里与当前 code 匹配的 `name`
/// - 时区摘要：与 `timeZoneShow` 一致，展示为 `UTC±HH:00`
/// - 子页返回：`STLanguageSetViewController` / `STTimeZoneSetViewController` 走根重建时由路由处理
class SettingPreferencePage extends ConsumerStatefulWidget {
  const SettingPreferencePage({super.key});

  @override
  ConsumerState<SettingPreferencePage> createState() =>
      _SettingPreferencePageState();
}

class _SettingPreferencePageState extends ConsumerState<SettingPreferencePage> {
  String _languageLabel = '简体中文';
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  /// 与 iOS `STPreferenceSetItemView` 选中勾 `st_mine_checked` 及全局设置绿一致（#34C759）
  static const Color _kSelectionGreen = Color(0xFF34C759);

  static const Map<String, String> _fallbackText = {
    'favorite_settings': '偏好设置',
    'app_theme': '主题',
    'rise_fall_color': '涨跌颜色',
    'red_rise_green_fall': '红涨绿跌',
    'red_fall_green_rise': '绿涨红跌',
    'more_setting': '更多设置',
    'one_click_closing_position': '一键平仓',
    'system_language': '系统语言',
    'system_time_zone': '系统时区',
  };

  @override
  void initState() {
    super.initState();
    _loadLanguageDisplay();
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

  Future<void> _loadLanguageDisplay() async {
    final code = await UserPreferencePrefs.readAppLanguage();
    final canon = IosLanguageCatalog.canonicalize(code);
    final savedName = await UserPreferencePrefs.readAppLanguageName();
    final options = ref.read(availableLanguagesProvider);

    var optionLabel = '';
    for (final item in options) {
      if (item.code == canon) {
        optionLabel = item.label;
        break;
      }
    }
    final fallbackLabel = optionLabel.isNotEmpty ? optionLabel : savedName;
    final label = IosLanguageCatalog.displayLabelForUiLanguage(
      canon,
      currentLanguageCode: _languageCode ?? canon,
      fallbackLabel: fallbackLabel,
    );

    if (!mounted) return;
    setState(() => _languageLabel = label);
  }

  /// 从子页返回或被动收到语言变更时刷新「系统语言」摘要（对齐 iOS viewWillAppear 刷新）
  Future<void> _refreshLanguageSummary() => _loadLanguageDisplay();

  @override
  Widget build(BuildContext context) {
    ref.listen<Locale>(appLocaleProvider, (prev, next) {
      if (prev == next) return;
      Future.microtask(() {
        if (mounted) _loadLanguageDisplay();
      });
    });

    ref.listen<List<AppLanguageOption>>(availableLanguagesProvider, (_, __) {
      Future.microtask(() {
        if (mounted) _loadLanguageDisplay();
      });
    });

    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(userStateProvider);
    final prefs = ref.read(userPreferenceControllerProvider);

    return Scaffold(
      backgroundColor: context.mineSettingsPageBg,
      appBar: AppBar(
        backgroundColor: context.mineSettingsNavBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _t('favorite_settings'),
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
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildSectionHeader(context, _t('app_theme')),
          _buildThemeCards(context, themeMode, prefs),
          const SizedBox(height: 24),
          _buildSectionHeader(context, _t('rise_fall_color')),
          _buildRiseFallCards(context, user.riseAndFallType, prefs),
          const SizedBox(height: 24),
          _buildSectionHeader(context, _t('more_setting')),
          _buildGroup(context, [
            _SwitchRow(
              label: _t('one_click_closing_position'),
              value: user.oneKeyClose,
              onChanged: (v) => prefs.setOneKeyClose(v),
            ),
            _buildArrowRow(
              context,
              label: _t('system_language'),
              trailing: _languageLabel,
              onTap: () async {
                await ref
                    .read(stRouterProvider)
                    .openPage(context, '/mine/setting_language');
                if (!mounted) return;
                await _refreshLanguageSummary();
              },
            ),
            _buildArrowRow(
              context,
              label: _t('system_time_zone'),
              trailing: TimezoneUtil.toIosUtcOffsetLabel(user.selectedTimeZone),
              onTap: () async {
                await ref
                    .read(stRouterProvider)
                    .openPage(context, '/mine/setting_timezone');
                if (!mounted) return;
                await _refreshLanguageSummary();
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: context.mineSettingsSectionTitle,
        ),
      ),
    );
  }

  Widget _buildThemeCards(
    BuildContext context,
    ThemeMode current,
    UserPreferenceController prefs,
  ) {
    final items = [
      _ThemeItem(label: 'Light', mode: ThemeMode.light),
      _ThemeItem(label: 'Dark', mode: ThemeMode.dark),
      _ThemeItem(label: 'Auto', mode: ThemeMode.system),
    ];
    return Row(
      children: items.map((item) {
        final isSel = current == item.mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => prefs.setThemeMode(item.mode),
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: item.mode == ThemeMode.dark
                      ? const Color(0xFF1A1A1A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? _kSelectionGreen
                        : context.mineSettingsDivider,
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _themePreview(item.mode, isSel),
                            const SizedBox(height: 8),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: item.mode == ThemeMode.dark
                                    ? const Color(0xFFB0B0B0)
                                    : const Color(0xFF000000),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSel) _selectedBadge(),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _themePreview(ThemeMode mode, bool isSelected) {
    switch (mode) {
      case ThemeMode.light:
        return Container(
          width: 48,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFECECEC)),
          ),
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E0E0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        );
      case ThemeMode.dark:
        return Container(
          width: 48,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF555555),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF555555),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF555555),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        );
      case ThemeMode.system:
        return Container(
          width: 48,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF34C759),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.brightness_auto_rounded,
            size: 22,
            color: Colors.white,
          ),
        );
    }
  }

  Widget _buildRiseFallCards(
    BuildContext context,
    int current,
    UserPreferenceController prefs,
  ) {
    // 与 CardTool.priceColor 一致：0=绿涨红跌，1=红涨绿跌
    final items = [
      _RiseFallItem(
        label: _t('red_rise_green_fall'),
        type: RiseAndFallType.riseRed,
        upColor: CardTool.fallColor, // 红
        downColor: CardTool.riseColor, // 绿
      ),
      _RiseFallItem(
        label: _t('red_fall_green_rise'),
        type: RiseAndFallType.riseGreen,
        upColor: CardTool.riseColor, // 绿
        downColor: CardTool.fallColor, // 红
      ),
    ];
    return Row(
      children: items.map((item) {
        final isSel = current == item.type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => prefs.setRiseAndFallType(item.type),
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: context.mineSettingsGroupBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? _kSelectionGreen
                        : context.mineSettingsDivider,
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _arrowBlock(item.upColor, true),
                                const SizedBox(width: 8),
                                _arrowBlock(item.downColor, false),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: context.mineSettingsTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSel) _selectedBadge(),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _selectedBadge() {
    return const Positioned(
      top: 6,
      right: 6,
      child: Icon(Icons.check_rounded, size: 22, color: _kSelectionGreen),
    );
  }

  Widget _arrowBlock(Color color, bool isUp) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isUp ? Icons.arrow_upward : Icons.arrow_downward,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _buildGroup(BuildContext context, List<Widget> children) {
    return Container(
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
    );
  }

  Widget _buildArrowRow(
    BuildContext context, {
    required String label,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 0,
                fit: FlexFit.loose,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: context.mineSettingsTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        trailing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: context.mineSettingsTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.mineSettingsTextSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeItem {
  final String label;
  final ThemeMode mode;
  _ThemeItem({required this.label, required this.mode});
}

class _RiseFallItem {
  final String label;
  final int type;
  final Color upColor;
  final Color downColor;
  _RiseFallItem({
    required this.label,
    required this.type,
    required this.upColor,
    required this.downColor,
  });
}

class _SwitchRow extends StatelessWidget {
  static const Color _kSelectionGreen = Color(0xFF34C759);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

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
            activeTrackColor: _kSelectionGreen,
          )
        : Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _kSelectionGreen;
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: context.mineSettingsTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            toggle,
          ],
        ),
      ),
    );
  }
}
