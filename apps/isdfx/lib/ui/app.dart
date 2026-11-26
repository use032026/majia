import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../domain/fixture_engine.dart';
import '../services/app_settings.dart';
import '../services/platform_services.dart';
import 'widgets/address_picker.dart';
import 'widgets/brand_mark.g.dart';

part 'privacy_policy_page.dart';
part 'supporting_pages.dart';
part 'workbench_results.dart';

const _brandName = 'ISDFX';
const _brandRed = Color(0xffd92432);
const _brandCharcoal = Color(0xff17191d);

bool _chinese(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh';

String _text(BuildContext context, String chinese, String english) =>
    _chinese(context) ? chinese : english;

String _errorText(BuildContext context, Object error) {
  final message = error is FormatException
      ? error.message.toString()
      : error.toString().replaceFirst(RegExp(r'^(Exception|StateError): '), '');
  final parts = message.split(' / ');
  return _chinese(context) ? parts.first : parts.last;
}

Future<void> _notice(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(_text(context, '知道了', 'OK')),
        ),
      ],
    ),
  );
}

Future<String?> _choose(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
}) => showCupertinoModalPopup<String>(
  context: context,
  builder: (sheetContext) => CupertinoActionSheet(
    title: Text(title),
    actions: [
      for (final option in options)
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, option.$1),
          child: Text(option.$2),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(sheetContext),
      child: Text(_text(context, '取消', 'Cancel')),
    ),
  ),
);

class IdFixtureApp extends StatelessWidget {
  const IdFixtureApp({
    super.key,
    required this.settings,
    required this.services,
  });

  final AppSettings settings;
  final PlatformServices services;

  static Locale resolveLocale(Locale? locale) {
    return resolveAppLocale(locale);
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? _brandCharcoal : const Color(0xfff8f7f7);
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandRed,
      brightness: brightness,
      primary: dark ? const Color(0xffffb3b6) : _brandRed,
      onPrimary: dark ? _brandCharcoal : Colors.white,
      surface: dark ? const Color(0xff23252a) : Colors.white,
      onSurface: dark ? const Color(0xfff5f4f5) : _brandCharcoal,
      onSurfaceVariant: dark
          ? const Color(0xffc2bfc5)
          : const Color(0xff5f5860),
      outline: dark ? const Color(0xff929098) : const Color(0xff827b82),
      outlineVariant: dark ? const Color(0xff414149) : const Color(0xffdfdbde),
      surfaceContainerLow: dark
          ? const Color(0xff2c2e34)
          : const Color(0xfff5f3f3),
      surfaceContainerHighest: dark
          ? const Color(0xff3c3d45)
          : const Color(0xffede9eb),
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primary.withValues(alpha: .11),
        checkmarkColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brandRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _brandName,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [
        Locale('en'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ],
      localeResolutionCallback: (locale, supportedLocales) =>
          resolveLocale(locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: Theme.of(context).colorScheme.primary,
        ),
        child: child!,
      ),
      home: _HomeGate(settings: settings, services: services),
    ),
  );
}

class _HomeGate extends StatelessWidget {
  const _HomeGate({required this.settings, required this.services});
  final AppSettings settings;
  final PlatformServices services;

  @override
  Widget build(BuildContext context) => settings.onboardingComplete
      ? _Workbench(settings: settings, services: services)
      : _Onboarding(settings: settings);
}

class _Mark extends StatelessWidget {
  const _Mark({this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) => paintIsdfxMark(canvas, size);

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}

class _Workbench extends StatefulWidget {
  const _Workbench({required this.settings, required this.services});
  final AppSettings settings;
  final PlatformServices services;

  @override
  State<_Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<_Workbench> {
  final _count = TextEditingController(text: '1');
  final _seed = TextEditingController(text: 'sample-01');
  final _prefix = TextEditingController(text: 'A');
  final _scroll = ScrollController();
  final _resultKey = GlobalKey();
  String _country = 'CN';
  String _profileId = 'cn-id';
  String _region = 'mainland';
  String _address = '110101';
  String _sex = 'any';
  String _mode = 'positive';
  DateTime _birthDate = DateTime(2000, 1, 1);
  bool _nySelected = false;
  bool _allowHistorical = false;
  bool _busy = false;
  String? _error;
  FixtureBatch? _batch;
  int _visible = 5;

  RuleProfile get _profile => FixtureEngine.profile(_profileId);

  @override
  void dispose() {
    _count.dispose();
    _seed.dispose();
    _prefix.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _invalidate() {
    setState(() {
      _batch = null;
      _error = null;
      _visible = 5;
    });
  }

  bool get _hasDate => ['cn-id', 'cn-id-demo', 'vn-id'].contains(_profileId);
  bool get _hasSex => _hasDate || _profileId == 'tw-id';

  void _resetProfile(String profileId) {
    _profileId = profileId;
    final profile = FixtureEngine.profile(profileId);
    _region = profile.region;
    _address =
        profile.addressCodes
            .where((entry) => entry.current)
            .firstOrNull
            ?.code ??
        '';
    _sex = 'any';
    _birthDate = DateTime(2000, 1, 1);
    _prefix.text = 'A';
    _nySelected = false;
    _allowHistorical = false;
    _mode = 'positive';
    _batch = null;
    _error = null;
    _visible = 5;
  }

  void _countryChanged(String value) {
    if (_country == value || _busy) return;
    setState(() {
      _country = value;
      _resetProfile(
        FixtureEngine.profiles
            .firstWhere(
              (profile) => profile.country == value && !profile.archived,
            )
            .id,
      );
    });
  }

  void _regionChanged(String value) {
    if (_region == value || _busy) return;
    setState(
      () => _resetProfile(
        FixtureEngine.profiles
            .firstWhere(
              (profile) =>
                  profile.country == 'CN' &&
                  profile.region == value &&
                  !profile.archived,
            )
            .id,
      ),
    );
  }

  String _name(RuleProfile profile) =>
      _chinese(context) ? profile.nameZh : profile.nameEn;

  String _modeName(String mode) => switch (mode) {
    'length' => _text(context, '长度错误', 'Wrong length'),
    'charset' => _text(context, '字符组成错误', 'Wrong character structure'),
    'checksum' => _text(context, '校验位错误', 'Wrong checksum'),
    _ => _text(context, '规则正例', 'Rule-positive'),
  };

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _config() {
    if (_profileId == 'us-ny-dmv' && !_nySelected) {
      throw FormatException(
        _text(context, '请先选择签发州。', 'Select the issuing state first.'),
      );
    }
    final count = int.tryParse(_count.text);
    if (count == null || count < 1 || count > 100) {
      throw FormatException(
        _text(
          context,
          '生成数量须为1—100之间的整数。',
          'Quantity must be an integer from 1 to 100.',
        ),
      );
    }
    final config = <String, dynamic>{
      'profileId': _profileId,
      'count': count,
      'seed': _seed.text,
      'mode': _mode,
    };
    if (_hasDate) {
      config.addAll({
        'birthDate': _dateString(_birthDate),
        'sex': _sex,
        'addressCode': _address,
      });
    }
    if (_profileId == 'vn-id') {
      config['currentProvinceAdminCode'] = _profile.addressCodes
          .firstWhere((entry) => entry.code == _address)
          .groupCode;
    }
    if (_profileId == 'tw-id') {
      config.addAll({
        'addressCode': _address,
        'sex': _sex,
        'allowHistorical': _allowHistorical,
      });
    }
    if (_profileId == 'hk-id') config['prefix'] = _prefix.text;
    return config;
  }

  void _showResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _resultKey.currentContext == null) return;
      Scrollable.ensureVisible(
        _resultKey.currentContext!,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    try {
      final result = FixtureEngine.generate(_config());
      setState(() {
        _batch = result;
        _error = null;
        _visible = 5;
      });
      _showResults();
    } catch (error) {
      setState(() => _error = _errorText(context, error));
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copy(String text) async {
    try {
      await widget.services.copyText(text);
      if (mounted) _snack(_text(context, '已复制', 'Copied'));
    } catch (error) {
      if (!mounted) return;
      await _notice(
        context,
        title: _text(context, '复制未完成', 'Copy did not complete'),
        message: _errorText(context, error),
      );
    }
  }

  Future<void> _export(BuildContext buttonContext) async {
    if (_batch == null || _busy) return;
    final render = buttonContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final origin = render.localToGlobal(Offset.zero) & render.size;
    setState(() => _busy = true);
    try {
      final json = const JsonEncoder.withIndent(
        '  ',
      ).convert(FixtureEngine.createPackage(_batch!));
      final result = await widget.services.sharePackage(
        json,
        filename: 'id-fixture-${_batch!.profileId}.json',
        origin: origin,
      );
      if (!mounted) return;
      if (result == ShareOutcome.unavailable) {
        _snack(
          _text(
            context,
            '系统未返回分享结果，当前用例已保留。',
            'The system did not report a sharing result. Your cases are unchanged.',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      await _notice(
        context,
        title: _text(context, '无法分享用例包', 'Could not share package'),
        message: _errorText(context, error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final file = await widget.services.openPackage();
      if (!mounted || file == null) return;
      final package = FixtureEngine.inspectPackage(file.text);
      final config = Map<String, dynamic>.from(package['config'] as Map);
      final profile = FixtureEngine.profile(package['profileId'] as String);
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(_text(context, '用例包预览', 'Package preview')),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name(profile)),
                  const SizedBox(height: 8),
                  Text('${_text(context, '条数', 'Cases')}: ${config['count']}'),
                  Text('${_text(context, '种子', 'Seed')}: ${config['seed']}'),
                  Text(
                    '${_text(context, '版本', 'Version')}: ${package['profileVersion']}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _text(
                      context,
                      '确认后按锁定规则重新计算，不执行文件内代码或下载规则。',
                      'Recalculate with locked rules. No file code is executed or rules downloaded.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_text(context, '取消', 'Cancel')),
            ),
            CupertinoDialogAction(
              key: const ValueKey('package.confirm'),
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_text(context, '确认复现', 'Confirm replay')),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final replay = FixtureEngine.replayPackage(package);
      if (!replay.matches) {
        await _notice(
          context,
          title: _text(context, '复现差异', 'Replay differences'),
          message: [
            _text(
              context,
              '重算与包内预期不一致，原工作台状态已保留。',
              'Recalculation differs from the package. Your workbench is unchanged.',
            ),
            for (final difference in replay.differences)
              'CASE ${(difference.index + 1).toString().padLeft(3, '0')}: ${_errorText(context, FormatException(difference.reason))}',
          ].join('\n\n'),
        );
        return;
      }
      final restored = replay.batch;
      final restoredConfig = restored.config;
      setState(() {
        _country = profile.country;
        _resetProfile(profile.id);
        _nySelected = profile.id == 'us-ny-dmv';
        _mode = restoredConfig['mode'] as String;
        _count.text = restoredConfig['count'].toString();
        _seed.text = restoredConfig['seed'] as String;
        if (_hasDate) {
          _birthDate = DateTime.parse(restoredConfig['birthDate'] as String);
          _sex = restoredConfig['sex'] as String;
          _address = restoredConfig['addressCode'] as String;
        }
        if (profile.id == 'tw-id') {
          _sex = restoredConfig['sex'] as String;
          _address = restoredConfig['addressCode'] as String;
          _allowHistorical = restoredConfig['allowHistorical'] as bool;
        }
        if (profile.id == 'hk-id') {
          _prefix.text = restoredConfig['prefix'] as String;
        }
        _batch = restored;
        _error = null;
        _visible = 5;
      });
      _showResults();
      _snack(
        _text(context, '已复现，结果与预期一致。', 'Replayed. Results match the package.'),
      );
    } catch (error) {
      if (!mounted) return;
      await _notice(
        context,
        title: _text(context, '无法打开用例包', 'Could not open package'),
        message:
            '${_errorText(context, error)}\n\n${_text(context, '请选择本应用导出的JSON包（最多1MB、100条）。原有参数与结果已保留。', 'Choose an exported JSON package (up to 1 MB and 100 cases). Your configuration and results are unchanged.')}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    var date = _birthDate;
    final selected = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (sheetContext) => Container(
        color: Theme.of(context).colorScheme.surface,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        height: 340 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(_text(context, '取消', 'Cancel')),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(sheetContext, date),
                  child: Text(_text(context, '完成', 'Done')),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _birthDate,
                minimumDate: DateTime(1900),
                maximumDate: _profileId == 'cn-id-demo'
                    ? DateTime(2025, 12, 31)
                    : DateTime(2026, 11, 5),
                onDateTimeChanged: (value) => date = value,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    _birthDate = selected;
    _invalidate();
  }

  Widget _selection({
    required Key key,
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        OutlinedButton(
          key: key,
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_down, size: 14),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _pickDocument() async {
    final selected = await _choose(
      context,
      title: _text(context, '本工具支持的证件', 'Documents supported here'),
      options: [
        for (final profile in FixtureEngine.profiles.where(
          (profile) =>
              profile.country == _country &&
              !profile.archived &&
              (_country != 'CN' || profile.region == _region),
        ))
          (profile.id, _name(profile)),
      ],
    );
    if (!mounted || selected == null || selected == _profileId) return;
    setState(() => _resetProfile(selected));
  }

  Future<void> _pickAddress() async {
    FocusScope.of(context).unfocus();
    final selected = await showAddressPicker(
      context,
      profile: _profile,
      selectedCode: _address,
    );
    if (!mounted || selected == null || selected == _address) return;
    _address = selected;
    if (_profileId == 'tw-id') {
      _allowHistorical = !_profile.addressCodes
          .firstWhere((entry) => entry.code == selected)
          .current;
    }
    _invalidate();
  }

  String _addressLabel(AddressCode address) {
    final name = _chinese(context) ? address.nameZh : address.nameEn;
    final group = _chinese(context) ? address.groupNameZh : address.groupNameEn;
    final parent = _chinese(context)
        ? address.parentNameZh
        : address.parentNameEn;
    final parts = <String>[];
    if (_profileId == 'cn-id') {
      parts.add(group);
      if (address.parentCode.isNotEmpty &&
          address.parentCode != address.groupCode) {
        parts.add(parent);
      }
    }
    if (_profileId == 'vn-id') parts.add(group);
    parts.add(name);
    parts.add(address.code);
    if (_profileId == 'tw-id' && !address.current) {
      parts.add(_text(context, '历史前缀', 'Historical prefix'));
    }
    return parts.where((entry) => entry.isNotEmpty).join(' · ');
  }

  Widget _documentSection() {
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      title: _text(context, '证件与地区', 'Document and region'),
      icon: CupertinoIcons.person_crop_rectangle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(_text(context, '国家', 'Country')),
          const SizedBox(height: 9),
          _CountrySelector(
            buttons: [
              for (final country in ['CN', 'US', 'VN'])
                _CountryButton(
                  key: ValueKey('country.$country'),
                  code: country,
                  label: switch (country) {
                    'CN' => _text(context, '中国', 'China'),
                    'US' => _text(context, '美国', 'United States'),
                    _ => _text(context, '越南', 'Vietnam'),
                  },
                  selected: _country == country,
                  onTap: _busy ? null : () => _countryChanged(country),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_country == 'CN') ...[
            _Label(_text(context, '区域', 'Region')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final region in ['mainland', 'HK', 'MO', 'TW'])
                  ChoiceChip(
                    key: ValueKey('region.$region'),
                    label: Text(switch (region) {
                      'mainland' => _text(context, '中国大陆', 'Chinese mainland'),
                      'HK' => _text(context, '中国香港', 'Hong Kong, China'),
                      'MO' => _text(context, '中国澳门', 'Macao, China'),
                      _ => _text(context, '中国台湾', 'Taiwan, China'),
                    }),
                    selected: _region == region,
                    onSelected: _busy ? null : (_) => _regionChanged(region),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _selection(
            key: const ValueKey('document.select'),
            label: _text(context, '证件类型', 'Document type'),
            value: _name(_profile),
            onTap: _busy ? null : _pickDocument,
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chinese(context) ? _profile.coverageZh : _profile.coverageEn,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                TextButton(
                  key: const ValueKey('rule.current'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _RuleDetail(
                        profile: _profile,
                        services: widget.services,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _text(context, '规则与来源', 'Rule and sources'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(CupertinoIcons.chevron_right, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parameterSection() {
    final scheme = Theme.of(context).colorScheme;
    final address = _profile.addressCodes.where(
      (entry) => entry.code == _address,
    );
    return _Panel(
      title: _text(context, '证件参数', 'Document parameters'),
      icon: CupertinoIcons.slider_horizontal_3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_profileId == 'us-ny-dmv')
            _selection(
              key: const ValueKey('state.select'),
              label: _text(context, '签发州', 'Issuing state'),
              value: _nySelected
                  ? _text(context, '纽约州 · New York', 'New York')
                  : _text(context, '请选择签发州', 'Select a state'),
              onTap: _busy
                  ? null
                  : () async {
                      final selected = await _choose(
                        context,
                        title: _text(context, '签发州', 'Issuing state'),
                        options: [
                          ('NY', _text(context, '纽约州 · New York', 'New York')),
                        ],
                      );
                      if (!mounted || selected == null) return;
                      _nySelected = true;
                      _invalidate();
                    },
            ),
          if (_profile.addressCodes.isNotEmpty) ...[
            _selection(
              key: const ValueKey('address.select'),
              label: _profileId == 'vn-id'
                  ? _text(
                      context,
                      '公开历史出生地编码',
                      'Published historical birthplace code',
                    )
                  : _text(context, '编码地区', 'Coding area'),
              value: address.isEmpty ? _address : _addressLabel(address.first),
              onTap: _busy ? null : _pickAddress,
            ),
          ],
          if (_hasDate) ...[
            _selection(
              key: const ValueKey('birthday.select'),
              label: _profileId == 'vn-id'
                  ? _text(
                      context,
                      '合成出生日期（仅编码年份）',
                      'Synthetic birth date (year encoded only)',
                    )
                  : _text(context, '合成出生日期', 'Synthetic birth date'),
              value: _dateString(_birthDate),
              onTap: _busy ? null : _pickDate,
            ),
          ],
          if (_hasSex) ...[
            _selection(
              key: const ValueKey('sex.select'),
              label: _text(context, '编码性别', 'Encoded sex'),
              value: switch (_sex) {
                'male' => _text(context, '男', 'Male'),
                'female' => _text(context, '女', 'Female'),
                _ => _text(context, '随机', 'Random'),
              },
              onTap: _busy
                  ? null
                  : () async {
                      final selected = await _choose(
                        context,
                        title: _text(context, '编码性别', 'Encoded sex'),
                        options: [
                          ('any', _text(context, '随机', 'Random')),
                          ('male', _text(context, '男', 'Male')),
                          ('female', _text(context, '女', 'Female')),
                        ],
                      );
                      if (!mounted || selected == null) return;
                      _sex = selected;
                      _invalidate();
                    },
            ),
          ],
          if (_profileId == 'hk-id') ...[
            TextField(
              key: const ValueKey('prefix.input'),
              controller: _prefix,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: _text(context, '字母前缀', 'Letter prefix'),
                helperText: _text(
                  context,
                  '输入1或2个大写英文字母，例如A或AB。',
                  'Enter one or two uppercase letters, for example A or AB.',
                ),
                helperMaxLines: 3,
              ),
              onChanged: (_) => _invalidate(),
            ),
            const SizedBox(height: 20),
          ],
          if (_profile.archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                _text(
                  context,
                  '已恢复旧版北京3地区演示规则。继续生成与导出会保留旧版本；切换区域或国家后使用当前规则。',
                  'Restored the archived three-area Beijing demo. Generation and export retain its version. Changing region or country uses current rules.',
                ),
                key: const ValueKey('profile.archived'),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _generationSection() => _Panel(
    title: _text(context, '生成设置', 'Generation settings'),
    icon: CupertinoIcons.square_stack,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(_text(context, '测试场景', 'Test scenario')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('scenario.positive'),
              label: Text(_text(context, '规则正例', 'Rule-positive')),
              selected: _mode == 'positive',
              onSelected: !_profile.enabled || _busy
                  ? null
                  : (_) {
                      _mode = 'positive';
                      _invalidate();
                    },
            ),
            ChoiceChip(
              key: const ValueKey('scenario.negative'),
              label: Text(_text(context, '定向反例', 'Targeted negative')),
              selected: _mode != 'positive',
              onSelected: !_profile.enabled || _busy
                  ? null
                  : (_) {
                      _mode = 'length';
                      _invalidate();
                    },
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_mode != 'positive' && _profile.enabled)
          _selection(
            key: const ValueKey('mutation.select'),
            label: _text(context, '预期不通过的规则', 'Expected failing rule'),
            value: _modeName(_mode),
            onTap: _busy
                ? null
                : () async {
                    final selected = await _choose(
                      context,
                      title: _text(
                        context,
                        '预期不通过的规则',
                        'Expected failing rule',
                      ),
                      options: [
                        for (final mode in _profile.modes.where(
                          (m) => m != 'positive',
                        ))
                          (mode, _modeName(mode)),
                      ],
                    );
                    if (!mounted || selected == null) return;
                    _mode = selected;
                    _invalidate();
                  },
          ),
        TextField(
          key: const ValueKey('count.input'),
          controller: _count,
          enabled: !_busy && _profile.enabled,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: _text(context, '生成数量', 'Quantity'),
            helperText: _text(
              context,
              '1—100条；仅批内去重',
              '1–100 cases; unique within this batch only',
            ),
            helperMaxLines: 3,
          ),
          onChanged: (_) => _invalidate(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('seed.input'),
          controller: _seed,
          enabled: !_busy && _profile.enabled,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 64,
          decoration: InputDecoration(
            labelText: _text(context, '复现种子', 'Replay seed'),
            helperText: _text(
              context,
              '保留原字符，相同版本下可复现。',
              'Preserved verbatim for same-version replay.',
            ),
            helperMaxLines: 3,
          ),
          onChanged: (_) => _invalidate(),
        ),
      ],
    ),
  );

  bool get _hasDocumentParameters =>
      _profileId == 'us-ny-dmv' ||
      _profileId == 'hk-id' ||
      _profile.addressCodes.isNotEmpty ||
      _hasDate ||
      _hasSex ||
      _profile.archived;

  Widget _workbenchHeader() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = Text(
      _text(context, '证件测试工作台', 'Test workbench'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 25,
        fontWeight: FontWeight.w700,
        height: 1.18,
        letterSpacing: -.45,
      ),
    );
    final import = OutlinedButton.icon(
      key: const ValueKey('package.open'),
      onPressed: _busy ? null : _import,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        backgroundColor: Colors.white.withValues(alpha: .07),
        side: BorderSide(color: Colors.white.withValues(alpha: .22)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: const Icon(CupertinoIcons.folder_open, size: 17),
      label: Text(_text(context, '打开用例包', 'Open package')),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xff282a30) : _brandCharcoal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 305 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stacked)
                  title
                else
                  Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 8),
                      import,
                    ],
                  ),
                const SizedBox(height: 7),
                Text(
                  _text(
                    context,
                    '按公开规则在本机生成可复现的证件号码。',
                    'Generate reproducible test numbers from published rules, on device.',
                  ),
                  style: const TextStyle(
                    color: Color(0xffd8d6db),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (stacked) ...[const SizedBox(height: 12), import],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _generateBar() {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 9, 18, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const ValueKey('form.error'),
                          style: TextStyle(color: scheme.error, height: 1.35),
                        ),
                      ),
                    ),
                  FilledButton(
                    key: const ValueKey('generate.button'),
                    onPressed: _profile.enabled && !_busy ? _generate : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _profile.enabled
                                  ? _text(
                                      context,
                                      '生成测试用例',
                                      'Generate test cases',
                                    )
                                  : _text(
                                      context,
                                      '现行规则待核实',
                                      'Current rules pending review',
                                    ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (_profile.enabled) ...[
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.arrow_right, size: 17),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final batch = _batch;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Row(
          children: [
            _Mark(size: 30),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                _brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('rules.open'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _RulesPage(services: widget.services),
              ),
            ),
            tooltip: _text(context, '规则目录', 'Rule catalog'),
            icon: const Icon(CupertinoIcons.book, size: 21),
          ),
          IconButton(
            key: const ValueKey('settings.open'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _SettingsPage(
                  settings: widget.settings,
                  services: widget.services,
                ),
              ),
            ),
            tooltip: _text(context, '偏好设置', 'Preferences'),
            icon: const Icon(CupertinoIcons.gear_alt, size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _workbenchHeader(),
                          const SizedBox(height: 14),
                          if (widget.settings.storageWarning) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _text(
                                  context,
                                  '本地偏好暂不可用，当前会话可继续使用。重启后可能需要重新选择。',
                                  'Local preferences are unavailable. You can continue for this session; choices may need to be made again after restart.',
                                ),
                                key: const ValueKey('storage.warning'),
                                style: TextStyle(
                                  color: scheme.error,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _documentSection(),
                          if (_hasDocumentParameters) ...[
                            const SizedBox(height: 12),
                            _parameterSection(),
                          ],
                          const SizedBox(height: 12),
                          _generationSection(),
                          if (batch != null) ...[
                            const SizedBox(height: 20),
                            _GeneratedResults(
                              key: _resultKey,
                              batch: batch,
                              visible: _visible,
                              busy: _busy,
                              onShowMore: () => setState(() => _visible += 5),
                              onCopy: _copy,
                              onExport: _export,
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: _ScopeNote(compact: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (constraints.maxHeight >= 230 ||
                  MediaQuery.viewInsetsOf(context).bottom == 0)
                _generateBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({required this.buttons});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 215 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: buttons,
              );
            }
            return Row(
              children: [for (final button in buttons) Expanded(child: button)],
            );
          },
        ),
      ),
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({
    super.key,
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: .45)
                    : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: scheme.primary, size: 17),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _ScopeNote extends StatelessWidget {
  const _ScopeNote({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          CupertinoIcons.info_circle,
          size: 17,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(
                  context,
                  '格式通过，不等于真实身份有效',
                  'Format checks do not verify identity',
                ),
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _text(
                  context,
                  '仅用于软件测试。合成号码可能与真实号码重合；实际签发、归属与有效状态未知。',
                  'For software tests only. Synthetic numbers may overlap issued values. Issuance, ownership and validity remain unknown.',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
