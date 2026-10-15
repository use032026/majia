import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/ios_language_catalog.dart';
import '../../core/providers/available_languages_provider.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/services/user_preference_controller.dart';
import '../../core/services/user_preference_prefs.dart';
import '../../trade_app.dart';
import 'mine_settings_appearance.dart';

/// 数据源与 iOS `[STBundle requestLanguageList]` / `STLanguageSetViewController` 一致：`data.languages`，项为 `code`、`name`。
/// 切换后行为对齐 `requestReloadRootControllerCallback`：刷新根（`JufuAppState.reload` + `go('/')`）。
class SettingLanguagePage extends ConsumerStatefulWidget {
  const SettingLanguagePage({super.key});

  @override
  ConsumerState<SettingLanguagePage> createState() =>
      _SettingLanguagePageState();
}

class _SettingLanguagePageState extends ConsumerState<SettingLanguagePage> {
  /// iOS 「设置」勾选绿
  static const Color _kCheckGreen = Color(0xFF34C759);
  static const double _trailingAccessory = 28;
  static const Map<String, String> _fallbackText = {
    'language_set': '语言设置',
    'no_data': '暂无数据',
  };

  String _selectedCanon = 'zh-Hans';
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  @override
  void initState() {
    super.initState();
    _restoreSelection();
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

  Future<void> _restoreSelection() async {
    final raw = await UserPreferencePrefs.readAppLanguage();
    if (!mounted) return;
    setState(() {
      _selectedCanon = IosLanguageCatalog.canonicalize(raw);
    });
  }

  Future<void> _onTap(String code, String label) async {
    final canon = IosLanguageCatalog.canonicalize(code);
    if (canon == _selectedCanon) return;

    await ref
        .read(userPreferenceControllerProvider)
        .setLanguageCode(canon, name: label);

    if (!mounted) return;
    setState(() => _selectedCanon = canon);

    context.findAncestorStateOfType<JufuAppState>()?.reload();
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(availableLanguagesProvider);
    final currentLanguageCode = stLanguageCodeOfContext(context);

    return Scaffold(
      backgroundColor: context.mineSettingsFullPageBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.mineSettingsNavBarBg,
        foregroundColor: context.mineSettingsTextPrimary,
        centerTitle: true,
        title: Text(
          _t('language_set'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
            color: context.mineSettingsTextPrimary,
          ),
        ),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            splashRadius: 22,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: context.mineSettingsTextPrimary,
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: rows.isEmpty
          ? Center(
              child: Text(
                _t('no_data'),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  color: context.mineSettingsTextSecondary,
                ),
              ),
            )
          : ListView.builder(
              physics: const ClampingScrollPhysics(),
              itemCount: rows.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, i) {
                final row = rows[i];
                final code = row.code;
                final label = IosLanguageCatalog.displayLabelForUiLanguage(
                  code,
                  currentLanguageCode: currentLanguageCode,
                  fallbackLabel: row.label,
                );
                final sel =
                    _selectedCanon == IosLanguageCatalog.canonicalize(code);

                return Material(
                  color: context.mineSettingsFullPageBg,
                  child: InkWell(
                    splashFactory: InkRipple.splashFactory,
                    onTap: () => _onTap(code, label),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.22,
                                color: context.mineSettingsTextPrimary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: _trailingAccessory,
                            child: sel
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 24,
                                    color: _kCheckGreen,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
