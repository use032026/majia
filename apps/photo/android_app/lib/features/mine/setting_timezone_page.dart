import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_state.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/services/user_preference_controller.dart';
import '../../core/utils/timezone_util.dart';
import '../../trade_app.dart';
import 'mine_settings_appearance.dart';

/// 对齐 iOS `STTimeZoneSetViewController` + `STUserInfoManger.timeZoneShowAry`：
/// 自 UTC+12:00 递减至 UTC−12:00（25 行）；存盘串为 `UTC±HH:00`。
/// 选定后走 `requestReloadRootControllerCallback` 同级别行为：重建根 UI（`reload` + `go('/')`）。
class SettingTimezonePage extends ConsumerStatefulWidget {
  const SettingTimezonePage({super.key});

  static const double _trailingAccessoryWidth = 28;

  static final List<_TimezoneRowModel> _rows = List<_TimezoneRowModel>.generate(
    25,
    (i) {
      final hour = 12 - i;
      return _TimezoneRowModel(
        code: TimezoneUtil.iosUtcCodeFromHourOffset(hour),
      );
    },
  );

  @override
  ConsumerState<SettingTimezonePage> createState() =>
      _SettingTimezonePageState();
}

class _SettingTimezonePageState extends ConsumerState<SettingTimezonePage> {
  static const Map<String, String> _fallbackText = {'time_zone': '时区设置'};

  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

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

  @override
  Widget build(BuildContext context) {
    final selectedTz = ref.watch(
      userStateProvider.select((s) => s.selectedTimeZone),
    );

    return Scaffold(
      backgroundColor: context.mineSettingsPageBg,
      appBar: AppBar(
        backgroundColor: context.mineSettingsNavBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _t('time_zone'),
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
      body: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: SettingTimezonePage._rows.length,
        itemBuilder: (context, i) {
          final row = SettingTimezonePage._rows[i];
          final isSelected = TimezoneUtil.utcOffsetsEquivalent(
            row.code,
            selectedTz,
          );

          return Material(
            color: context.mineSettingsGroupBg,
            child: InkWell(
              onTap: () async {
                if (TimezoneUtil.utcOffsetsEquivalent(row.code, selectedTz)) {
                  return;
                }
                await ref
                    .read(userPreferenceControllerProvider)
                    .setTimezone(row.code);

                if (!context.mounted) return;
                context.findAncestorStateOfType<JufuAppState>()?.reload();
                if (!context.mounted) return;
                context.go('/');
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 53),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 17,
                    right: 14,
                    top: 15,
                    bottom: 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          row.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            color: context.mineSettingsTextPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: SettingTimezonePage._trailingAccessoryWidth,
                        height: 24,
                        child: isSelected
                            ? Image.asset(
                                'assets/images/st_mine_checked_sec.png',
                                width: 24,
                                height: 24,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimezoneRowModel {
  final String code;

  const _TimezoneRowModel({required this.code});
}
