import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../domain/fixture_engine.dart';
import '../services/app_settings.dart';
import '../services/platform_services.dart';
import 'widgets/address_picker.dart';

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
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff215b4b),
      brightness: brightness,
      primary: dark ? const Color(0xffc0dda4) : const Color(0xff215b4b),
      surface: dark ? const Color(0xff1c2821) : Colors.white,
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: dark
          ? const Color(0xff131b18)
          : const Color(0xfff6f7f5),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xff131b18)
            : const Color(0xfff6f7f5),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
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
      title: 'ID Fixture',
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
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xff215b4b),
      borderRadius: BorderRadius.circular(size * .27),
    ),
    child: ExcludeSemantics(
      child: Text(
        '[1]',
        style: TextStyle(
          color: const Color(0xffd8edb6),
          fontFamily: 'monospace',
          fontSize: size * .44,
          fontWeight: FontWeight.w600,
        ),
        textScaler: TextScaler.noScaling,
      ),
    ),
  );
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.settings, this.replay = false});
  final AppSettings settings;
  final bool replay;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  int _page = 0;
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.replay) {
        Navigator.pop(context);
      } else {
        await widget.settings.completeOnboarding();
      }
    } catch (error) {
      if (!mounted) return;
      await _notice(
        context,
        title: _text(context, '无法保存引导状态', 'Could not save setup'),
        message: _errorText(context, error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = math.max(24.0, MediaQuery.viewPaddingOf(context).bottom);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.replay,
        actions: [
          TextButton(
            key: const ValueKey('onboarding.skip'),
            onPressed: _saving ? null : _finish,
            child: Text(_text(context, '跳过', 'Skip')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(28, 16, 28, bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 16 - bottom),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Mark(size: 76),
                const SizedBox(height: 36),
                Text(
                  'ID FIXTURE / 0${_page + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.6,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _page == 0
                      ? _text(
                          context,
                          '测试号码，\n也要有上下文。',
                          'Test numbers,\nwith context.',
                        )
                      : _text(
                          context,
                          '把一次测试，\n变成可复现的用例。',
                          'Keep the context.\nReplay the test.',
                        ),
                  style: const TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _page == 0
                      ? _text(
                          context,
                          '按国家、证件与已支持的规则，在本地生成测试样例。每个结果都会说明检查范围与未知项。',
                          'Choose a country, document and supported rule. Generate locally, then inspect what was checked and what remains unknown.',
                        )
                      : _text(
                          context,
                          '导出用例包，保留参数和规则版本；再次打开，重新计算同一组结果。无需账号，也不上传号码。',
                          'Export a test package with its parameters and rule versions. Open it later to recalculate the same results. No account or number uploads.',
                        ),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),
                _ScopeNote(compact: true),
                const SizedBox(height: 32),
                Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Container(
                        width: i == _page ? 24 : 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: ValueKey(
                      _page == 0 ? 'onboarding.next' : 'onboarding.complete',
                    ),
                    onPressed: _saving
                        ? null
                        : _page == 0
                        ? () => setState(() => _page = 1)
                        : _finish,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _page == 0
                            ? _text(context, '继续', 'Continue')
                            : _text(context, '开始使用', 'Get started'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

  String _checkName(RuleCheck check) =>
      _chinese(context) ? check.labelZh : check.labelEn;

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
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        OutlinedButton(
          key: key,
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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

  Widget _configuration() {
    final scheme = Theme.of(context).colorScheme;
    final address = _profile.addressCodes.where((a) => a.code == _address);
    return _Panel(
      title: _text(context, '配置用例', 'Configure cases'),
      step: '01',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(_text(context, '国家 / 地区', 'Country / region')),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final country in ['CN', 'US', 'VN'])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: country == 'VN' ? 0 : 8),
                    child: _CountryButton(
                      key: ValueKey('country.$country'),
                      code: country,
                      label: switch (country) {
                        'CN' => _text(context, '中国', 'China'),
                        'US' => _text(context, '美国', 'United States'),
                        _ => _text(context, '越南', 'Vietnam'),
                      },
                      selected: _country == country,
                      onTap: () => _countryChanged(country),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
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
            const SizedBox(height: 20),
          ],
          _selection(
            key: const ValueKey('document.select'),
            label: _text(context, '本工具支持的证件', 'Documents supported here'),
            value: _name(_profile),
            onTap: _busy ? null : _pickDocument,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              _chinese(context) ? _profile.coverageZh : _profile.coverageEn,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
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
          const SizedBox(height: 20),
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const ValueKey('form.error'),
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('generate.button'),
            onPressed: _profile.enabled && !_busy ? _generate : null,
            icon: const Icon(CupertinoIcons.arrow_right, size: 18),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _profile.enabled
                    ? _text(context, '生成测试用例', 'Generate test cases')
                    : _text(context, '现行规则待核实', 'Current rules pending review'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _case(FixtureCase item, int index) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'CASE ${(index + 1).toString().padLeft(3, '0')}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  _Tag(
                    _batch!.config['mode'] == 'positive'
                        ? _text(context, '规则正例', 'Rule-positive')
                        : _text(context, '定向反例', 'Targeted negative'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      item.value,
                      key: ValueKey('case.value.$index'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copy(item.value),
                    tooltip: _text(context, '复制号码', 'Copy number'),
                    icon: const Icon(CupertinoIcons.doc_on_doc, size: 19),
                  ),
                ],
              ),
              if (item.expectedFailureIds.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${_text(context, '预期不通过', 'Expected failure')}: ${item.checks.where((c) => item.expectedFailureIds.contains(c.id)).map(_checkName).join(' · ')}',
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('case.expand.$index'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 5),
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    _text(context, '查看逐项检查', 'Inspect rule checks'),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    for (final check in item.checks)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _checkName(check),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              switch (check.status) {
                                'pass' => _text(context, '通过', 'Pass'),
                                'fail' => _text(context, '未通过', 'Fail'),
                                _ => _text(context, '未知', 'Unknown'),
                              },
                              style: TextStyle(
                                fontSize: 12,
                                color: check.status == 'pass'
                                    ? scheme.primary
                                    : check.status == 'fail'
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
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

  Widget _results() {
    final batch = _batch;
    return _Panel(
      key: _resultKey,
      title: _text(context, '生成结果', 'Results'),
      step: '02',
      child: batch == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Text(
                    '[ 018 ]',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 35,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _text(context, '下一组测试，从这里开始', 'Your next test starts here'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _text(
                      context,
                      '生成后查看逐项检查，也可以打开用例包复现已有测试。',
                      'Generate and inspect rule checks, or open a package to replay a previous test.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _name(FixtureEngine.profile(batch.profileId)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${batch.meta['profileVersion']}\n${_text(context, '种子', 'Seed')}: ${batch.config['seed']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 14),
                _Tag(
                  '${_text(context, '已生成', 'Generated')} · ${batch.cases.length}',
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < math.min(_visible, batch.cases.length); i++)
                  _case(batch.cases[i], i),
                if (_visible < batch.cases.length)
                  TextButton(
                    key: const ValueKey('cases.more'),
                    onPressed: () => setState(() => _visible += 5),
                    child: Text(
                      _text(context, '显示更多（5条）', 'Show more (5 cases)'),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('copy.all'),
                      onPressed: _busy
                          ? null
                          : () => _copy(
                              batch.cases.map((c) => c.value).join('\n'),
                            ),
                      child: Text(_text(context, '复制全部号码', 'Copy all numbers')),
                    ),
                    Builder(
                      builder: (buttonContext) => FilledButton.icon(
                        key: const ValueKey('export.package'),
                        onPressed: _busy ? null : () => _export(buttonContext),
                        icon: const Icon(CupertinoIcons.share, size: 18),
                        label: Text(_text(context, '导出用例包', 'Export package')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _text(
                    context,
                    'JSON包保留规则版本、参数和预期检查。可在系统分享中存到文件，供下次复现。',
                    'The JSON package keeps versions, parameters and expected checks. Save it through the system share sheet for later replay.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(24.0, MediaQuery.viewPaddingOf(context).bottom);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            _Mark(size: 30),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'ID Fixture',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
            icon: const Icon(CupertinoIcons.list_bullet, size: 23),
          ),
          IconButton(
            key: const ValueKey('settings.open'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _SettingsPage(settings: widget.settings),
              ),
            ),
            tooltip: _text(context, '偏好设置', 'Preferences'),
            icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 23),
          ),
          const SizedBox(width: 7),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 22, 20, bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TEST DATA, WITH CONTEXT.',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    context,
                    '让每一组测试号码，\n都有据可循。',
                    'Test numbers,\nwith a traceable basis.',
                  ),
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.4,
                    letterSpacing: -.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  _text(
                    context,
                    '本地生成 · 无需账号 · 规则可追溯',
                    'Local generation · No account · Traceable rules',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
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
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('package.open'),
                    onPressed: _busy ? null : _import,
                    icon: const Icon(CupertinoIcons.folder_open, size: 18),
                    label: Text(_text(context, '打开用例包', 'Open test package')),
                  ),
                ),
                const SizedBox(height: 22),
                _configuration(),
                const SizedBox(height: 20),
                _results(),
                const SizedBox(height: 22),
                const _ScopeNote(),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  key: const ValueKey('rule.current'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _RuleDetail(
                        profile: _profile,
                        services: widget.services,
                      ),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.doc_text_search, size: 19),
                  label: Text(
                    _text(
                      context,
                      '查看当前规则与来源',
                      'View current rule and sources',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _text(
                    context,
                    '不上传号码，不连接实名核验服务。',
                    'No number uploads or identity-verification services.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: .08) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Text(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.title,
    required this.step,
    required this.child,
  });
  final String title;
  final String step;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(
                step,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Padding(padding: const EdgeInsets.all(20), child: child),
      ],
    ),
  );
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

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
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

class _RulesPage extends StatelessWidget {
  const _RulesPage({required this.services});
  final PlatformServices services;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_text(context, '规则目录', 'Rule catalog'))),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        math.max(24, MediaQuery.viewPaddingOf(context).bottom),
      ),
      children: [
        Text(
          _text(
            context,
            '每个档案独立说明来源、版本和支持范围。未知项不会被当成通过。',
            'Each profile records its sources, version and scope. Unknown checks never become passes.',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        for (final profile in FixtureEngine.profiles.where(
          (entry) => !entry.archived,
        )) ...[
          Card(
            child: ListTile(
              key: ValueKey('rule.${profile.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              title: Text(_chinese(context) ? profile.nameZh : profile.nameEn),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _chinese(context) ? profile.coverageZh : profile.coverageEn,
                ),
              ),
              trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _RuleDetail(profile: profile, services: services),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Text(
          _text(
            context,
            '旧版本 · 仅供已有用例包复现',
            'Archived versions · for existing packages',
          ),
        ),
        for (final profile in FixtureEngine.profiles.where(
          (entry) => entry.archived,
        ))
          ListTile(
            key: ValueKey('rule.${profile.id}'),
            title: Text(_chinese(context) ? profile.nameZh : profile.nameEn),
            subtitle: Text(profile.version),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    _RuleDetail(profile: profile, services: services),
              ),
            ),
          ),
      ],
    ),
  );
}

class _RuleDetail extends StatelessWidget {
  const _RuleDetail({required this.profile, required this.services});
  final RuleProfile profile;
  final PlatformServices services;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_text(context, '规则与来源', 'Rule and sources'))),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        math.max(24, MediaQuery.viewPaddingOf(context).bottom),
      ),
      children: [
        _Tag(profile.country),
        const SizedBox(height: 15),
        Text(
          _chinese(context) ? profile.nameZh : profile.nameEn,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SelectableText(
          profile.version,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _chinese(context) ? profile.coverageZh : profile.coverageEn,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 16),
        Text(
          _chinese(context) ? profile.limitationsZh : profile.limitationsEn,
          style: TextStyle(
            height: 1.7,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        const _ScopeNote(),
        const SizedBox(height: 30),
        Text(
          _text(context, '公开来源', 'Public sources'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final source in profile.sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () async {
                try {
                  await services.openSource(source.url);
                } catch (error) {
                  if (!context.mounted) return;
                  await _notice(
                    context,
                    title: _text(context, '无法打开来源', 'Could not open source'),
                    message: _errorText(context, error),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(source.title)),
                    const SizedBox(width: 10),
                    const Icon(CupertinoIcons.arrow_up_right, size: 17),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          _text(
            context,
            '资料核验日期：${['cn-id', 'hk-id', 'mo-id', 'tw-id', 'vn-id'].contains(profile.id) ? '2026-11-05' : '2026-11-04'}。打开外部来源需要联网，本地生成不需要。',
            'Sources reviewed: ${['cn-id', 'hk-id', 'mo-id', 'tw-id', 'vn-id'].contains(profile.id) ? '2026-11-05' : '2026-11-04'}. External source pages need a connection; local generation does not.',
          ),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.settings});
  final AppSettings settings;

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      await _notice(
        context,
        title: _text(context, '无法保存偏好', 'Could not save preference'),
        message: _errorText(context, error),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(_text(context, '偏好设置', 'Preferences'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          math.max(24, MediaQuery.viewPaddingOf(context).bottom),
        ),
        children: [
          Text(
            _text(
              context,
              '默认跟随系统，只保存明确选择的偏好。不保留号码历史；导出时会产生由系统缓存管理的临时副本。',
              'Follows your system by default. Only explicit preferences are stored. Results are not kept as history; export creates a temporary copy managed by the system cache.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          if (settings.storageWarning) ...[
            const SizedBox(height: 15),
            Text(
              _text(
                context,
                '本地偏好暂不可用，当前选择可能无法在重启后保留。',
                'Local preferences are unavailable. Current choices may not survive a restart.',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('settings.language'),
                  title: Text(_text(context, '界面语言', 'Interface language')),
                  subtitle: Text(
                    settings.locale?.languageCode == 'zh'
                        ? '简体中文'
                        : settings.locale?.languageCode == 'en'
                        ? 'English'
                        : _text(context, '跟随系统', 'Follow system'),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_down, size: 15),
                  onTap: () async {
                    final selected = await _choose(
                      context,
                      title: _text(context, '界面语言', 'Interface language'),
                      options: [
                        ('system', _text(context, '跟随系统', 'Follow system')),
                        ('zh', '简体中文'),
                        ('en', 'English'),
                      ],
                    );
                    if (!context.mounted || selected == null) return;
                    await _save(
                      context,
                      () => settings.setLanguage(
                        selected == 'system' ? null : selected,
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  key: const ValueKey('settings.theme'),
                  title: Text(_text(context, '外观', 'Appearance')),
                  subtitle: Text(switch (settings.themeMode) {
                    ThemeMode.light => _text(context, '浅色', 'Light'),
                    ThemeMode.dark => _text(context, '深色', 'Dark'),
                    _ => _text(context, '跟随系统', 'Follow system'),
                  }),
                  trailing: const Icon(CupertinoIcons.chevron_down, size: 15),
                  onTap: () async {
                    final selected = await _choose(
                      context,
                      title: _text(context, '外观', 'Appearance'),
                      options: [
                        ('system', _text(context, '跟随系统', 'Follow system')),
                        ('light', _text(context, '浅色', 'Light')),
                        ('dark', _text(context, '深色', 'Dark')),
                      ],
                    );
                    if (!context.mounted || selected == null) return;
                    await _save(
                      context,
                      () => settings.setThemeMode(
                        ThemeMode.values.firstWhere(
                          (mode) => mode.name == selected,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              key: const ValueKey('settings.replay'),
              title: Text(_text(context, '重新查看使用引导', 'Replay introduction')),
              subtitle: Text(
                _text(context, '不改变已完成状态', 'Keeps your completed state'),
              ),
              trailing: const Icon(CupertinoIcons.arrow_up_right, size: 17),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _Onboarding(settings: settings, replay: true),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _ScopeNote(),
          const SizedBox(height: 28),
          Text(
            'ID FIXTURE · 1.1.0\nLOCAL TEST WORKBENCH',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              height: 1.8,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
