import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jufu/core/localization/st_localizations.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/st_localized_prompt.dart';

import 'chart_indicator_prefs.dart';
import 'chart_prefs_keys.dart';

/// K 线图表设置页，对齐 iOS `STMarketSettingController`。
class ChartSettingsPage extends StatefulWidget {
  const ChartSettingsPage({super.key});

  @override
  State<ChartSettingsPage> createState() => _ChartSettingsPageState();
}

class _ChartSettingsPageState extends State<ChartSettingsPage> {
  static const Map<String, String> _fallbackText = {
    'kline_settings': '图表设置',
    'basic_settings': '基础设置',
    'grid_line': '网格线',
    'underline': '划线工具',
    'host_graph': '主图',
    'index': '指标',
    'supplementary_image': '副图',
    'index_settings': '指标设置',
    'main_image_indicators': '主图指标',
    'sub_graph_indicators': '副图指标',
    'restore_preset': '恢复默认',
    'complete': '完成',
    'daily_moving_average': '均线 (MA)',
  };

  bool _loading = true;
  bool _showGrid = false;
  bool _enableCrosshair = true;
  String _mainIndicator = 'MA';
  String _subIndicator = 'MACD';
  List<int> _maPeriods = _defaultPeriods;
  List<int> _emaPeriods = _defaultPeriods;
  List<bool> _maSelected = _defaultSelected;
  List<bool> _emaSelected = _defaultSelected;

  static const _primaryText = Color(0xFF000000);
  static const _rowText = Color(0xFF60656D);
  static const _valueText = Color(0xFF303030);
  static const _separator = Color(0xFFE5E5EA);
  static const _mutedIcon = Color(0xFFA9A9A9);
  static const _green = Color(0xFF4DCB73);
  static const _highlight = Color(0xFF00B57A);
  static const _defaultPeriods = [5, 10, 20, 30, 60, 120];
  static const _defaultSelected = [true, true, true, false, false, false];
  static const _mainSheetOptions = [
    _IndicatorOption(id: 'MA', label: 'MA'),
    _IndicatorOption(id: 'EMA', label: 'EMA'),
    _IndicatorOption(id: 'BOLL', label: 'BOOL'),
  ];
  static const _subSheetOptions = [
    _IndicatorOption(id: 'MACD', label: 'MACD'),
    _IndicatorOption(id: 'KDJ', label: 'KDJ'),
    _IndicatorOption(id: 'RSI', label: 'RSI'),
  ];
  Map<String, String> _localizedText = _fallbackText;
  String? _localizedLanguageCode;

  static Color _pageBgOf(BuildContext context) => context.adaptivePageGrey;
  static Color _controlBgOf(BuildContext context) => context.adaptiveCard;
  static Color _primaryTextOf(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveTextPrimary : _primaryText;
  static Color _rowTextOf(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveTextTertiary : _rowText;
  static Color _valueTextOf(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveTextPrimary : _valueText;
  static Color _secondaryTextOf(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveTextSecondary : _mutedIcon;
  static Color _separatorOf(BuildContext context) =>
      context.adaptiveIsDark ? context.adaptiveDivider : _separator;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final mainSub = ChartIndicatorPrefs.readMainSub(sp);
    final maAll = _readAllPeriods(
      sp,
      allKey: MarketChartPrefKeys.maAllPeriods,
      selectedKey: MarketChartPrefKeys.maPeriods,
    );
    final emaAll = _readAllPeriods(
      sp,
      allKey: MarketChartPrefKeys.emaAllPeriods,
      selectedKey: MarketChartPrefKeys.emaPeriods,
    );
    if (!mounted) return;
    setState(() {
      _showGrid = sp.getBool(MarketChartPrefKeys.showGrid) ?? false;
      _enableCrosshair = sp.getBool(MarketChartPrefKeys.crosshair) ?? true;
      _mainIndicator = mainSub.$1;
      _subIndicator = mainSub.$2;
      _maPeriods = maAll;
      _emaPeriods = emaAll;
      _maSelected = _readSelectedMask(
        sp,
        maskKey: MarketChartPrefKeys.maSelectedMask,
        allPeriods: maAll,
        selectedKey: MarketChartPrefKeys.maPeriods,
      );
      _emaSelected = _readSelectedMask(
        sp,
        maskKey: MarketChartPrefKeys.emaSelectedMask,
        allPeriods: emaAll,
        selectedKey: MarketChartPrefKeys.emaPeriods,
      );
      _loading = false;
    });
  }

  List<int> _readAllPeriods(
    SharedPreferences sp, {
    required String allKey,
    required String selectedKey,
  }) {
    final all = ChartIndicatorPrefs.parsePeriodList(
      sp.getString(allKey),
      const [],
    );
    if (all.length == 6) {
      return all.map((v) => v.clamp(1, 300).toInt()).toList();
    }

    final selected = ChartIndicatorPrefs.parsePeriodList(
      sp.getString(selectedKey),
      _defaultPeriods.take(3).toList(),
    );
    final merged = List<int>.from(_defaultPeriods);
    for (var i = 0; i < math.min(selected.length, 6); i++) {
      merged[i] = selected[i].clamp(1, 300).toInt();
    }
    return merged;
  }

  List<bool> _readSelectedMask(
    SharedPreferences sp, {
    required String maskKey,
    required List<int> allPeriods,
    required String selectedKey,
  }) {
    final rawMask = sp.getString(maskKey);
    if (rawMask != null) {
      final parts = rawMask.split(',');
      if (parts.length == 6) {
        return parts.map((v) => v.trim() == '1').toList(growable: false);
      }
    }

    final selected = ChartIndicatorPrefs.parsePeriodList(
      sp.getString(selectedKey),
      _defaultPeriods.take(3).toList(),
    );
    if (selected.isEmpty) return List<bool>.filled(6, false);

    final remaining = List<int>.from(selected);
    return [for (final p in allPeriods) remaining.remove(p)];
  }

  Future<void> _persistSwitch(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  Future<void> _persistIndicator(String key, String id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, id);
  }

  Future<void> _persistPeriodConfig({
    required bool isMa,
    required List<int> periods,
    required List<bool> selected,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final values = periods.map((v) => v.clamp(1, 300).toInt()).toList();
    final selectedSummary = _periodSummary(values, selected);
    await sp.setString(
      isMa
          ? MarketChartPrefKeys.maAllPeriods
          : MarketChartPrefKeys.emaAllPeriods,
      values.join(','),
    );
    await sp.setString(
      isMa
          ? MarketChartPrefKeys.maSelectedMask
          : MarketChartPrefKeys.emaSelectedMask,
      selected.map((v) => v ? '1' : '0').join(','),
    );
    await sp.setString(
      isMa ? MarketChartPrefKeys.maPeriods : MarketChartPrefKeys.emaPeriods,
      selectedSummary,
    );
    if (!mounted) return;
    setState(() {
      if (isMa) {
        _maPeriods = values;
        _maSelected = List<bool>.from(selected);
      } else {
        _emaPeriods = values;
        _emaSelected = List<bool>.from(selected);
      }
    });
  }

  Future<void> _restoreDefaults() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(MarketChartPrefKeys.chartStyle, 'candle');
    await sp.setBool(MarketChartPrefKeys.showGrid, false);
    await sp.setBool(MarketChartPrefKeys.crosshair, true);
    await sp.setString(MarketChartPrefKeys.mainIndicator, 'MA');
    await sp.setString(MarketChartPrefKeys.subIndicator, 'MACD');
    await sp.setString(
      MarketChartPrefKeys.maAllPeriods,
      _defaultPeriods.join(','),
    );
    await sp.setString(
      MarketChartPrefKeys.emaAllPeriods,
      _defaultPeriods.join(','),
    );
    await sp.setString(MarketChartPrefKeys.maSelectedMask, '1,1,1,0,0,0');
    await sp.setString(MarketChartPrefKeys.emaSelectedMask, '1,1,1,0,0,0');
    await sp.setString(MarketChartPrefKeys.maPeriods, '5,10,20');
    await sp.setString(MarketChartPrefKeys.emaPeriods, '5,10,20');
    await sp.setString(MarketChartPrefKeys.macdParams, '12,26,9');
    await sp.setString(MarketChartPrefKeys.kdjParams, '9,3,3');
    await sp.setString(MarketChartPrefKeys.rsiParams, '14');
    await sp.setString(MarketChartPrefKeys.dmiParams, '14');
    await _load();
  }

  static String _periodSummary(List<int> periods, List<bool> selected) {
    final values = <String>[];
    for (var i = 0; i < math.min(periods.length, selected.length); i++) {
      if (selected[i]) values.add('${periods[i]}');
    }
    return values.join(',');
  }

  void _ensureLocalizedText(BuildContext context) {
    final localizations = STLocalizations.ofContext(context);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _fallbackText;
    localizations.textMap(_fallbackText).then((text) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localizedText = text);
    });
  }

  String _t(String key) => _localizedText[key] ?? _fallbackText[key] ?? key;

  Future<void> _showIndicatorSheet({
    required String title,
    required List<_IndicatorOption> options,
    required String selectedId,
    required ValueChanged<String> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        final bottom = MediaQuery.paddingOf(context).bottom;
        final height = 289.0 + bottom;
        final pageBg = _pageBgOf(context);
        final controlBg = _controlBgOf(context);
        final primaryText = _primaryTextOf(context);
        return SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: pageBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Column(
                children: [
                  SizedBox(
                    height: 69,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 27,
                          top: 27,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 15,
                          top: 13,
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.close,
                                size: 22,
                                color: primaryText,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: controlBg,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < options.length; i++)
                            _IndicatorSheetRow(
                              label: options[i].label,
                              selected: options[i].id == selectedId,
                              showDivider: i < options.length - 1,
                              onTap: () {
                                Navigator.of(context).pop();
                                onSelected(options[i].id);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMaPage(bool isMa) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MaConfigPage(
          title: isMa ? 'MA' : 'EMA',
          initialPeriods: isMa ? _maPeriods : _emaPeriods,
          initialSelected: isMa ? _maSelected : _emaSelected,
          onSave: (periods, selected) => _persistPeriodConfig(
            isMa: isMa,
            periods: periods,
            selected: selected,
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(context);
    final pageBg = _pageBgOf(context);
    final controlBg = _controlBgOf(context);
    final primaryText = _primaryTextOf(context);
    final valueText = _valueTextOf(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: pageBg,
        body: const Center(child: STLoadAnimationView()),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _t('kline_settings'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: [
                  _SettingsSection(
                    title: _t('basic_settings'),
                    showTopLine: false,
                    children: [
                      _SwitchSettingRow(
                        title: _t('grid_line'),
                        value: _showGrid,
                        onChanged: (value) async {
                          setState(() => _showGrid = value);
                          await _persistSwitch(
                            MarketChartPrefKeys.showGrid,
                            value,
                          );
                        },
                      ),
                      _SwitchSettingRow(
                        title: _t('underline'),
                        value: _enableCrosshair,
                        onChanged: (value) async {
                          setState(() => _enableCrosshair = value);
                          await _persistSwitch(
                            MarketChartPrefKeys.crosshair,
                            value,
                          );
                        },
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: _t('host_graph'),
                    showTopLine: true,
                    children: [
                      _AlertSettingRow(
                        title: _t('index'),
                        value: _mainIndicator,
                        arrow: _AlertArrow.dropdown,
                        onTap: () => _showIndicatorSheet(
                          title: _t('main_image_indicators'),
                          options: _mainSheetOptions,
                          selectedId: _mainIndicator,
                          onSelected: (id) async {
                            setState(() => _mainIndicator = id);
                            await _persistIndicator(
                              MarketChartPrefKeys.mainIndicator,
                              id,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: _t('supplementary_image'),
                    showTopLine: true,
                    children: [
                      _AlertSettingRow(
                        title: _t('index'),
                        value: _subIndicator,
                        arrow: _AlertArrow.dropdown,
                        onTap: () => _showIndicatorSheet(
                          title: _t('sub_graph_indicators'),
                          options: _subSheetOptions,
                          selectedId: _subIndicator,
                          onSelected: (id) async {
                            setState(() => _subIndicator = id);
                            await _persistIndicator(
                              MarketChartPrefKeys.subIndicator,
                              id,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: _t('index_settings'),
                    showTopLine: true,
                    children: [
                      _AlertSettingRow(
                        title: 'MA',
                        value: _periodSummary(_maPeriods, _maSelected),
                        arrow: _AlertArrow.chevron,
                        onTap: () => _openMaPage(true),
                      ),
                      _AlertSettingRow(
                        title: 'EMA',
                        value: _periodSummary(_emaPeriods, _emaSelected),
                        arrow: _AlertArrow.chevron,
                        onTap: () => _openMaPage(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 23),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: controlBg,
                    foregroundColor: valueText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _restoreDefaults,
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(
                    _t('restore_preset'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.showTopLine,
    required this.children,
  });

  final String title;
  final bool showTopLine;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Stack(
            children: [
              if (showTopLine)
                Positioned(
                  left: 15,
                  right: 15,
                  top: 5,
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: _ChartSettingsPageState._separatorOf(context),
                  ),
                ),
              Positioned(
                left: 15,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _ChartSettingsPageState._valueTextOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SwitchSettingRow extends StatelessWidget {
  static const Color _kIosGreen = Color(0xFF34C759);

  const _SwitchSettingRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

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
              return context.adaptiveSwitchOffTrack;
            }),
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          );

    return SizedBox(
      height: 47,
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 15),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _ChartSettingsPageState._rowTextOf(context),
              ),
            ),
            const Spacer(),
            toggle,
          ],
        ),
      ),
    );
  }
}

enum _AlertArrow { dropdown, chevron }

class _AlertSettingRow extends StatelessWidget {
  const _AlertSettingRow({
    required this.title,
    required this.value,
    required this.arrow,
    required this.onTap,
  });

  final String title;
  final String value;
  final _AlertArrow arrow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final boxWidth = math.min(246.0, math.max(180.0, screenWidth - 30 - 62));
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 57,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _ChartSettingsPageState._rowTextOf(context),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: boxWidth,
                height: 43,
                decoration: BoxDecoration(
                  color: _ChartSettingsPageState._controlBgOf(context),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: _ChartSettingsPageState._valueTextOf(context),
                        ),
                      ),
                    ),
                    Icon(
                      arrow == _AlertArrow.dropdown
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      size: arrow == _AlertArrow.dropdown ? 22 : 24,
                      color: _ChartSettingsPageState._secondaryTextOf(context),
                    ),
                    const SizedBox(width: 5),
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

class _IndicatorSheetRow extends StatelessWidget {
  const _IndicatorSheetRow({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Positioned(
              left: 15,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _ChartSettingsPageState._primaryTextOf(context),
                  ),
                ),
              ),
            ),
            if (selected)
              const Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Icon(
                  Icons.check_rounded,
                  size: 22,
                  color: _ChartSettingsPageState._green,
                ),
              ),
            if (showDivider)
              Positioned(
                left: 15,
                right: 15,
                bottom: 0,
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: _ChartSettingsPageState._separatorOf(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MaConfigPage extends StatefulWidget {
  const _MaConfigPage({
    required this.title,
    required this.initialPeriods,
    required this.initialSelected,
    required this.onSave,
  });

  final String title;
  final List<int> initialPeriods;
  final List<bool> initialSelected;
  final Future<void> Function(List<int> periods, List<bool> selected) onSave;

  @override
  State<_MaConfigPage> createState() => _MaConfigPageState();
}

class _MaConfigPageState extends State<_MaConfigPage> {
  late List<int> _periods;
  late List<bool> _selected;
  late List<TextEditingController> _controllers;
  Map<String, String> _localizedText = _ChartSettingsPageState._fallbackText;
  String? _localizedLanguageCode;

  @override
  void initState() {
    super.initState();
    _periods = _sixInts(widget.initialPeriods);
    _selected = _sixBools(widget.initialSelected);
    _controllers = [
      for (final value in _periods) TextEditingController(text: '$value'),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  static List<int> _sixInts(List<int> source) {
    final out = List<int>.from(_ChartSettingsPageState._defaultPeriods);
    for (var i = 0; i < math.min(source.length, 6); i++) {
      out[i] = source[i].clamp(1, 300).toInt();
    }
    return out;
  }

  static List<bool> _sixBools(List<bool> source) {
    final out = List<bool>.from(_ChartSettingsPageState._defaultSelected);
    for (var i = 0; i < math.min(source.length, 6); i++) {
      out[i] = source[i];
    }
    return out;
  }

  void _resetDefaults() {
    setState(() {
      _periods = List<int>.from(_ChartSettingsPageState._defaultPeriods);
      _selected = List<bool>.from(_ChartSettingsPageState._defaultSelected);
      for (var i = 0; i < _controllers.length; i++) {
        _controllers[i].text = '${_periods[i]}';
      }
    });
  }

  void _setValue(int index, int value) {
    final next = value.clamp(1, 300).toInt();
    setState(() => _periods[index] = next);
    final text = '$next';
    if (_controllers[index].text != text) {
      _controllers[index].value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  Future<void> _finish() async {
    final values = <int>[];
    for (final controller in _controllers) {
      final parsed = int.tryParse(controller.text);
      if (parsed == null || parsed < 1 || parsed > 300) {
        showStLocalizedPrompt(context, '请输入 1～300 的整数');
        return;
      }
      values.add(parsed);
    }
    await widget.onSave(values, _selected);
    if (mounted) Navigator.of(context).pop();
  }

  void _ensureLocalizedText(BuildContext context) {
    final localizations = STLocalizations.ofContext(context);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    _localizedText = _ChartSettingsPageState._fallbackText;
    localizations.textMap(_ChartSettingsPageState._fallbackText).then((text) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localizedText = text);
    });
  }

  String _t(String key) =>
      _localizedText[key] ?? _ChartSettingsPageState._fallbackText[key] ?? key;

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText(context);
    final pageBg = _ChartSettingsPageState._pageBgOf(context);
    final controlBg = _ChartSettingsPageState._controlBgOf(context);
    final primaryText = _ChartSettingsPageState._primaryTextOf(context);
    final valueText = _ChartSettingsPageState._valueTextOf(context);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(
              _t('complete'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _ChartSettingsPageState._highlight,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 15),
                physics: const ClampingScrollPhysics(),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return _MaSettingRow(
                    selected: _selected[index],
                    controller: _controllers[index],
                    onSelected: () {
                      setState(() => _selected[index] = !_selected[index]);
                    },
                    onMinus: () => _setValue(index, _periods[index] - 1),
                    onPlus: () => _setValue(index, _periods[index] + 1),
                    onTextChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed < 1 || parsed > 300) return;
                      _periods[index] = parsed;
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 23),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: controlBg,
                    foregroundColor: valueText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _resetDefaults,
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(
                    _t('restore_preset'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaSettingRow extends StatelessWidget {
  const _MaSettingRow({
    required this.selected,
    required this.controller,
    required this.onSelected,
    required this.onMinus,
    required this.onPlus,
    required this.onTextChanged,
  });

  final bool selected;
  final TextEditingController controller;
  final VoidCallback onSelected;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 45,
            height: 56,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onSelected,
              icon: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: selected
                    ? _ChartSettingsPageState._green
                    : _ChartSettingsPageState._secondaryTextOf(context),
              ),
            ),
          ),
          STLocalizedText(
            '日均线',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _ChartSettingsPageState._valueTextOf(context),
            ),
          ),
          const Spacer(),
          Container(
            width: 162,
            height: 46,
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: _ChartSettingsPageState._controlBgOf(context),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                _StepperButton(icon: Icons.remove_rounded, onTap: onMinus),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _ChartSettingsPageState._primaryTextOf(context),
                    ),
                    onChanged: onTextChanged,
                  ),
                ),
                _StepperButton(icon: Icons.add_rounded, onTap: onPlus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 22,
          color: _ChartSettingsPageState._rowTextOf(context),
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _IndicatorOption {
  const _IndicatorOption({required this.id, required this.label});

  final String id;
  final String label;
}
