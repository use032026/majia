import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'domain.dart';
import 'editor.dart';
import 'storage.dart';

const paper = Color(0xFFFAF6F0);
const plum = Color(0xFF493447);
const peach = Color(0xFFE9AA77);
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 30)}';
String dateLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
Rect shareAnchor(RenderBox box) {
  final origin = box.localToGlobal(Offset.zero);
  return Rect.fromLTWH(
    origin.dx + box.size.width / 2,
    origin.dy + box.size.height / 2,
    1,
    1,
  );
}

Locale resolveLocale(Locale? locale) => locale?.languageCode == 'zh'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')
    : const Locale('en');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    RefqoApp(repository: FileRepository.lazy(getApplicationSupportDirectory)),
  );
}

class RefqoApp extends StatefulWidget {
  const RefqoApp({
    super.key,
    required this.repository,
    this.share,
    this.pickBackup,
    this.temporaryDirectory,
  });
  final Repository repository;
  final Future<ShareResult> Function(ShareParams)? share;
  final Future<XFile?> Function()? pickBackup;
  final Future<Directory> Function()? temporaryDirectory;
  @override
  State<RefqoApp> createState() => _RefqoAppState();
}

class _RefqoAppState extends State<RefqoApp> with WidgetsBindingObserver {
  AppData? data;
  Object? loadError;
  bool _working = false;
  bool _confirming = false;
  bool get busy => _working || _confirming;
  final changes = ValueNotifier<int>(0);
  final navigator = GlobalKey<NavigatorState>();
  Timer? _slowTimer;
  bool _slow = false;
  String? operationLabel;
  String? message;
  bool messageError = false;
  String? nextLabel;
  VoidCallback? nextAction;
  int tab = 0;
  int horizon = 30;
  bool replay = false;
  AppData? _forecastData;
  DateTime? _forecastDay;
  int? _forecastHorizon;
  List<SupplyForecast> _forecasts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    changes.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    changes.value++;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted && data?.language == null) update(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) update(() {});
  }

  bool get zh =>
      (data?.language ??
          resolveLocale(
            WidgetsBinding.instance.platformDispatcher.locale,
          ).languageCode) ==
      'zh';
  String t(String en, String cn) => zh ? cn : en;

  void notice(
    String text, {
    bool error = false,
    String? actionLabel,
    VoidCallback? action,
  }) {
    update(() {
      message = text;
      messageError = error;
      nextLabel = actionLabel;
      nextAction = action;
    });
  }

  Future<bool> runAction(
    String label,
    Future<void> Function() action, {
    String? Function()? success,
    String? actionLabel,
    VoidCallback? next,
    void Function(Object)? failure,
  }) async {
    if (busy) return false;
    update(() {
      _working = true;
      _slow = false;
      operationLabel = label;
      message = null;
      nextAction = null;
      nextLabel = null;
      messageError = false;
    });
    _slowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _working) update(() => _slow = true);
    });
    try {
      // Paint the acknowledgement before validation/encoding/file work begins.
      await WidgetsBinding.instance.endOfFrame;
      await action();
      if (mounted) {
        update(() {
          if (success != null) message = success();
          nextLabel = actionLabel;
          nextAction = next;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        update(() {
          messageError = true;
          message = errorText(e);
          failure?.call(e);
        });
      }
      return false;
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        update(() {
          _working = false;
          operationLabel = null;
          _slow = false;
        });
      }
    }
  }

  Future<void> load() async {
    await runAction(
      t('Loading library…', '正在读取资料…'),
      () async {
        final next = await widget.repository.load();
        if (widget.repository is FileRepository) {
          try {
            await cleanTemporaryBackups(await temporaryDirectory());
          } catch (_) {
            /* Explicit erasure retries cache cleanup. */
          }
        }
        if (mounted) {
          data = next;
          loadError = null;
        }
      },
      failure: (e) {
        loadError = e;
      },
    );
  }

  Future<bool> commit(
    AppData Function(AppData) operation, {
    String Function(AppData)? success,
    String? actionLabel,
    VoidCallback? next,
  }) async {
    if (data == null) return false;
    return runAction(
      t('Saving…', '正在保存…'),
      () async {
        final candidate = operation(data!);
        await widget.repository.save(candidate);
        if (mounted) data = candidate;
      },
      success: () => success?.call(data!) ?? t('Saved.', '已保存。'),
      actionLabel: actionLabel,
      next: next,
    );
  }

  String errorText(Object e) {
    final text = e.toString();
    if (text.contains('HISTORY_LOCKED')) {
      return t(
        'This record has ledger history. Undo its latest transactions before changing its link/date or removing it.',
        '此档案有流水。请到“流水”先撤销相关的最新记录，再删除或修改关联及日期。',
      );
    }
    if (text.contains('LINKED_APPLIANCES')) {
      return t(
        'Remove the linked appliances before deleting this supply.',
        '请先移除此耗材的关联设备，再删除耗材。',
      );
    }
    if (text.contains('FIT_UNCONFIRMED')) {
      return t(
        'Edit the appliance and confirm that this exact part fits.',
        '请编辑设备，核对此准确型号适配后再更换。',
      );
    }
    if (text.contains('CAPACITY')) {
      return t(
        'The library limit is reached (200 supplies, 500 appliances, 2000 entries). Export a backup before managing old records.',
        '资料库已达上限（200 种耗材、500 个设备或 2000 条流水）。请先导出备份，再整理旧记录。',
      );
    }
    if (text.contains('STOCK') ||
        text.contains('INSUFFICIENT') ||
        text.contains('supply.stock')) {
      return t(
        'Check stock: receive enough before replacing; total stock cannot exceed 99999.',
        '请检查库存：更换前先入库，累计库存不能超过 99999。',
      );
    }
    if (text.contains('INVALID_DATE')) {
      return t('Check the installation date.', '请检查安装日期。');
    }
    if (text.contains('RECOVERY_REQUIRED')) {
      return t(
        'The library needs recovery. Retry loading or restore a valid backup.',
        '资料库需要恢复，请重新读取或恢复有效备份。',
      );
    }
    return t(
      'Could not complete this change. Check values or storage, then retry.',
      '操作未完成，请检查输入或存储空间后重试。',
    );
  }

  Widget activity() => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          if (_confirming)
            const Icon(Icons.help_outline, size: 18)
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _slow
                  ? t(
                      'Still working. Please wait; no need to repeat the action.',
                      '仍在处理中，请稍候，无需重复操作。',
                    )
                  : operationLabel ??
                        t('Please confirm the dialog.', '请在弹窗中确认。'),
            ),
          ),
        ],
      ),
    ),
  );
  Widget feedback(BuildContext context) => Semantics(
    liveRegion: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 190),
      child: SingleChildScrollView(
        child: MaterialBanner(
          leading: Icon(
            messageError ? Icons.error_outline : Icons.check_circle_outline,
            color: messageError ? Theme.of(context).colorScheme.error : null,
          ),
          content: Text(message!),
          forceActionsBelow: true,
          actions: [
            if (nextAction != null && nextLabel != null)
              TextButton(
                onPressed: busy ? null : nextAction,
                child: Text(nextLabel!),
              ),
            TextButton(
              onPressed: () => update(() {
                message = null;
                nextAction = null;
                nextLabel = null;
              }),
              child: Text(t('Dismiss', '关闭')),
            ),
          ],
        ),
      ),
    ),
  );
  void goToTab(int value) => update(() {
    tab = value;
    message = null;
    nextLabel = null;
    nextAction = null;
  });
  void showTab(int value) {
    navigator.currentState?.popUntil((route) => route.isFirst);
    goToTab(value);
  }

  List<SupplyForecast> get plans {
    final day = calendarDay(DateTime.now());
    if (!identical(_forecastData, data) ||
        _forecastDay != day ||
        _forecastHorizon != horizon) {
      _forecasts = forecast(data!, day, horizon);
      _forecastData = data;
      _forecastDay = day;
      _forecastHorizon = horizon;
    }
    return _forecasts;
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: plum,
          brightness: brightness,
          primary: dark ? peach : plum,
          surface: dark ? const Color(0xFF211E24) : paper,
        ).copyWith(
          primaryContainer: dark
              ? const Color(0xFF4D3946)
              : const Color(0xFFF1D8C1),
          onPrimaryContainer: dark ? paper : plum,
          secondaryContainer: dark
              ? const Color(0xFF4D3946)
              : const Color(0xFFEEDCCD),
          surfaceContainerLow: dark
              ? const Color(0xFF2B252D)
              : const Color(0xFFF5EEE6),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      chipTheme: const ChipThemeData(showCheckmark: false),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 50)),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        fontFamily: 'sans-serif',
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      title: 'Refqo',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: data?.appearance == 'dark'
          ? ThemeMode.dark
          : data?.appearance == 'light'
          ? ThemeMode.light
          : ThemeMode.system,
      locale: data?.language == null ? null : Locale(data!.language!),
      supportedLocales: const [Locale('en'), Locale('zh', 'Hans')],
      localeResolutionCallback: (locale, _) => resolveLocale(locale),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) {
          if (loadError != null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Refqo')),
              body: Content(
                children: [
                  const Icon(CupertinoIcons.lock_shield, size: 60),
                  Text(
                    t('Your library needs attention', '资料库需要恢复'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    t(
                      'We could not read the saved library. Normal changes are locked to protect it. Retry or restore a valid Refqo backup.',
                      '无法读取已保存的资料。为保护数据，已暂停普通修改。请重试或恢复有效的 Refqo 备份。',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : load,
                    child: Text(t('Retry', '重试')),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => restore(context),
                    child: Text(t('Restore backup', '恢复备份')),
                  ),
                  if (widget.repository is FileRepository)
                    OutlinedButton(
                      onPressed: busy ? null : () => recoverPrevious(context),
                      child: Text(t('Preview local recovery copy', '预览本机上次副本')),
                    ),
                  if (busy) activity(),
                  if (message != null) feedback(context),
                ],
              ),
            );
          }
          if (data == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!data!.onboarded || replay) {
            return Onboarding(
              zh: zh,
              busy: busy,
              error: message,
              onDone: () async {
                if (replay) {
                  update(() => replay = false);
                } else {
                  await commit((d) => d.copyWith(onboarded: true));
                }
              },
            );
          }
          final titles = [
            t('Purchase plan', '补货计划'),
            t('Supply library', '耗材资料库'),
            t('Stock ledger', '库存流水'),
            t('Settings', '设置'),
          ];
          return Scaffold(
            appBar: AppBar(
              title: Text(titles[tab]),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: Text(
                      'Refqo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                if (busy) activity(),
                if (message != null) feedback(context),
                Expanded(
                  child: switch (tab) {
                    0 => plan(context),
                    1 => supplies(context),
                    2 => ledger(context),
                    _ => settings(context),
                  },
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: busy ? null : goToTab,
              destinations: [
                NavigationDestination(
                  enabled: !busy,
                  icon: const Icon(CupertinoIcons.bag),
                  label: t('Plan', '计划'),
                ),
                NavigationDestination(
                  enabled: !busy,
                  icon: const Icon(CupertinoIcons.cube_box),
                  label: t('Supplies', '耗材'),
                ),
                NavigationDestination(
                  enabled: !busy,
                  icon: const Icon(CupertinoIcons.clock),
                  label: t('Ledger', '流水'),
                ),
                NavigationDestination(
                  enabled: !busy,
                  icon: const Icon(CupertinoIcons.slider_horizontal_3),
                  label: t('Settings', '设置'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget plan(BuildContext context) {
    final plans = this.plans;
    final needs = plans.fold<int>(0, (sum, f) => sum + f.gap);
    return Content(
      key: const PageStorageKey('plan'),
      children: [
        Wrap(
          spacing: 8,
          children: [30, 60, 90]
              .map(
                (days) => ChoiceChip(
                  label: Text(t('$days days', '$days 天')),
                  selected: horizon == days,
                  onSelected: (_) => update(() => horizon = days),
                ),
              )
              .toList(),
        ),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('TO BUY · NEXT $horizon DAYS', '需补货 · 未来 $horizon 天'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$needs',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(t('units after shared stock', '件，已扣除共享库存')),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.bag_badge_plus, size: 42),
            ],
          ),
        ),
        if (data!.slots.isEmpty)
          EmptyState(
            icon: CupertinoIcons.square_stack_3d_up,
            title: t('Start with one refill', '从一种耗材开始'),
            body: t(
              'Add its exact part code, then link each appliance that uses it. Your purchase gap will appear here.',
              '添加准确型号，再关联使用它的设备，即可看到补货缺口。',
            ),
            action: data!.supplies.isEmpty
                ? t('Add a supply', '添加耗材')
                : t('Link an appliance', '关联设备'),
            onAction: busy
                ? null
                : () => data!.supplies.isEmpty
                      ? editSupply(context)
                      : openSupply(context, data!.supplies.first.id),
          ),
        if (data!.slots.isNotEmpty)
          Text(
            t('YOUR SUPPLY COVERAGE', '耗材覆盖情况'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        for (final f in plans.where((p) => p.slots.isNotEmpty))
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    f.supply.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    f.supply.code.isEmpty
                        ? t('No part code', '未填写型号')
                        : f.supply.code,
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: busy ? null : () => openSupply(context, f.supply.id),
                ),
                Text(
                  t(
                    '${f.demand} needed − ${f.stock} in stock = ${f.gap} to buy',
                    '需求 ${f.demand} − 库存 ${f.stock} = 补货 ${f.gap}',
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Divider(height: 24),
                for (final s in f.slots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${s.slot.name} · ${s.occurrences} × ${s.slot.units}${s.slot.verified ? '' : t(' · fit unverified', ' · 待核对适配')}',
                    ),
                  ),
              ],
            ),
          ),
        if (data!.slots.isNotEmpty)
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => shareText(context, shoppingText(plans)),
            icon: const Icon(CupertinoIcons.share),
            label: Text(t('Share purchase list', '分享采购清单')),
          ),
        Text(
          t(
            'Dates are planning estimates, not safety or lifespan advice. Check manufacturer instructions and part fit before use. This app does not send reminders.',
            '日期仅供计划参考，不代表安全或寿命建议。使用前请核对厂商说明与适配型号。本应用不发送提醒。',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String shoppingText(List<SupplyForecast> plans) => [
    'Refqo · ${t('Purchase plan', '采购计划')} · ${dateLabel(DateTime.now())} · $horizon ${t('days', '天')}',
    for (final p in plans.where((f) => f.gap > 0))
      '${p.supply.name}\n${t('Part', '型号')}: ${p.supply.code}\n${t('Buy', '购买')}: ${p.gap} | ${t('Need / Stock', '需求 / 库存')}: ${p.demand} / ${p.stock}\n${p.supply.notes}\n${p.slots.map((s) => '${s.slot.name}: ${s.slot.verified ? t('fit checked by user', '用户已核对适配') : t('VERIFY FIT', '请核对适配')}').join('\n')}',
    t(
      'Manually verify part fit and manufacturer guidance. No automatic compatibility checks.',
      '请人工核对型号适配与厂商说明。本应用不自动判断兼容性。',
    ),
  ].join('\n\n');
  Widget supplies(BuildContext context) => Content(
    key: const PageStorageKey('supplies'),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              t(
                '${data!.supplies.length} supplies',
                '${data!.supplies.length} 种耗材',
              ),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filled(
            onPressed: busy ? null : () => editSupply(context),
            tooltip: t('Add supply', '添加耗材'),
            icon: const Icon(CupertinoIcons.plus),
          ),
        ],
      ),
      Text(
        t(
          'Keep different part codes separate. Linking devices never makes parts interchangeable.',
          '不同型号请分别建档。关联设备不代表耗材可以互换。',
        ),
      ),
      if (data!.supplies.isEmpty)
        EmptyState(
          icon: CupertinoIcons.cube_box,
          title: t('Your shelf is empty', '资料库还是空的'),
          body: t(
            'Start with a filter, dust bag or cleaning refill you already use.',
            '从正在使用的滤芯、集尘袋或清洁替换件开始。',
          ),
          action: t('Add a supply', '添加耗材'),
          onAction: busy ? null : () => editSupply(context),
        ),
      for (final s in data!.supplies)
        Surface(
          child: InkWell(
            onTap: busy ? null : () => openSupply(context, s.id),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (s.code.isNotEmpty) Text(s.code),
                  const SizedBox(height: 12),
                  Text(
                    '${s.stock} ${t('in stock', '件库存')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${data!.slots.where((e) => e.supplyId == s.id).length} ${t('linked appliances', '个关联设备')}',
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
  Future<void> editSupply(BuildContext context, [Supply? supply]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupplyEditor(
          zh: zh,
          supply: supply,
          failureMessage: () => message,
          save: (name, code, notes) => commit(
            (d) => supply == null
                ? addSupply(
                    d,
                    Supply(id: newId(), name: name, code: code, notes: notes),
                  )
                : updateSupply(
                    d,
                    supply.copyWith(name: name, code: code, notes: notes),
                  ),
            success: (_) => t('Supply saved.', '耗材已保存。'),
            actionLabel: t('Link appliance', '关联设备'),
            next: () {
              final saved =
                  data!.supplies.where((s) => s.id == supply?.id).firstOrNull ??
                  data!.supplies.last;
              editSlot(navigator.currentState!.context, saved);
            },
          ),
        ),
      ),
    );
  }

  Future<void> openSupply(BuildContext context, String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListenableBuilder(
          listenable: changes,
          builder: (_, _) => StatefulBuilder(
            builder: (context, local) {
              final s = data!.supplies.where((s) => s.id == id).firstOrNull;
              if (s == null) {
                return Scaffold(
                  appBar: AppBar(
                    title: Text(t('Supply unavailable', '耗材已不存在')),
                  ),
                  body: Center(
                    child: Text(
                      t('Return to the supply library.', '请返回耗材资料库。'),
                    ),
                  ),
                );
              }
              Future<void> refresh(Future<void> Function() action) async {
                await action();
                if (context.mounted) {
                  local(() {});
                }
              }

              return PopScope(
                canPop: !_working,
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(s.name),
                    leading: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: _working
                          ? null
                          : () => Navigator.maybePop(context),
                      icon: const BackButtonIcon(),
                    ),
                  ),
                  body: Column(
                    children: [
                      if (busy) activity(),
                      if (message != null) feedback(context),
                      Expanded(
                        child: Content(
                          children: [
                            Text(
                              s.code.isEmpty
                                  ? t('No part code saved', '未记录型号')
                                  : s.code,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              s.notes.isEmpty
                                  ? t(
                                      'Add fit notes from the label or manufacturer.',
                                      '可从标签或厂商说明中添加适配备注。',
                                    )
                                  : s.notes,
                            ),
                            Surface(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t('Shared stock', '共享库存')),
                                        Text(
                                          '${s.stock}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.displaySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => refresh(
                                            () => receive(context, s),
                                          ),
                                    child: Text(t('Receive', '入库')),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => refresh(
                                          () => editSupply(context, s),
                                        ),
                                  icon: const Icon(CupertinoIcons.pencil),
                                  label: Text(t('Edit supply', '编辑耗材')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            refresh(() => editSlot(context, s)),
                                  icon: const Icon(CupertinoIcons.link),
                                  label: Text(t('Link appliance', '关联设备')),
                                ),
                              ],
                            ),
                            Text(
                              t('APPLIANCES USING THIS REFILL', '使用此耗材的设备'),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            for (final slot in data!.slots.where(
                              (e) => e.supplyId == id,
                            ))
                              Surface(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    Text(
                                      t(
                                        '${slot.units} unit(s) every ${slot.intervalDays} days',
                                        '每 ${slot.intervalDays} 天使用 ${slot.units} 件',
                                      ),
                                    ),
                                    Text(
                                      '${t('Last changed', '上次更换')}: ${dateLabel(slot.lastChanged)}',
                                    ),
                                    Text(
                                      '${t('Next due', '下次计划')}: ${dateLabel(DateTime(slot.lastChanged.year, slot.lastChanged.month, slot.lastChanged.day + slot.intervalDays))}',
                                    ),
                                    Text(
                                      slot.verified
                                          ? t('Fit checked by you', '你已核对适配')
                                          : t(
                                              'Verify fit before use',
                                              '使用前请核对适配',
                                            ),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        FilledButton(
                                          onPressed:
                                              busy ||
                                                  s.stock < slot.units ||
                                                  !slot.verified
                                              ? null
                                              : () => refresh(() async {
                                                  if (await confirm(
                                                    context,
                                                    t(
                                                      'Record replacement?',
                                                      '记录本次更换？',
                                                    ),
                                                    t(
                                                      'Deduct ${slot.units} unit(s) and start the next interval from today. You can undo the latest ledger entry.',
                                                      '扣减 ${slot.units} 件，下一周期从今天开始。可在流水中撤销最新记录。',
                                                    ),
                                                  )) {
                                                    await commit(
                                                      (d) => replaceSlot(
                                                        d,
                                                        slot.id,
                                                        DateTime.now(),
                                                      ),
                                                      success: (d) => t(
                                                        'Replacement recorded. Stock: ${d.supplies.firstWhere((s) => s.id == id).stock}.',
                                                        '更换已记录，当前库存 ${d.supplies.firstWhere((s) => s.id == id).stock} 件。',
                                                      ),
                                                      actionLabel: t(
                                                        'View ledger',
                                                        '查看流水',
                                                      ),
                                                      next: () {
                                                        showTab(2);
                                                      },
                                                    );
                                                  }
                                                }),
                                          child: Text(
                                            t('Replaced today', '今天已更换'),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => refresh(
                                                  () => editSlot(
                                                    context,
                                                    s,
                                                    slot,
                                                  ),
                                                ),
                                          child: Text(t('Edit', '编辑')),
                                        ),
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => refresh(() async {
                                                  if (await confirm(
                                                    context,
                                                    t(
                                                      'Remove appliance?',
                                                      '移除设备？',
                                                    ),
                                                    t(
                                                      'Ledger-linked records must be undone first.',
                                                      '有关联流水时需先撤销流水。',
                                                    ),
                                                    destructive: true,
                                                  )) {
                                                    await commit(
                                                      (d) => deleteSlot(
                                                        d,
                                                        slot.id,
                                                      ),
                                                      success: (_) => t(
                                                        'Appliance removed.',
                                                        '设备已移除。',
                                                      ),
                                                      actionLabel: t(
                                                        'View plan',
                                                        '查看计划',
                                                      ),
                                                      next: () {
                                                        showTab(0);
                                                      },
                                                    );
                                                  }
                                                }),
                                          child: Text(t('Remove', '移除')),
                                        ),
                                      ],
                                    ),
                                    if (!slot.verified)
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => editSlot(context, s, slot),
                                        child: Text(
                                          t(
                                            'Confirm fit in appliance details',
                                            '编辑设备并确认适配',
                                          ),
                                        ),
                                      ),
                                    if (s.stock < slot.units)
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => receive(context, s),
                                        child: Text(
                                          t(
                                            'Receive stock to enable replacement.',
                                            '库存不足，请先入库。',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (data!.slots
                                .where((e) => e.supplyId == id)
                                .isEmpty)
                              Text(
                                t(
                                  'Link an appliance to include this stock in planning.',
                                  '关联设备后，此耗材即可纳入计划。',
                                ),
                              ),
                            if (data!.events.any((e) => e.supplyId == id))
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        showTab(2);
                                      },
                                child: Text(
                                  t('Manage history in ledger', '到流水管理历史记录'),
                                ),
                              ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await confirm(
                                        context,
                                        t('Delete supply?', '删除耗材？'),
                                        t(
                                          'Unlink appliances and undo related ledger history first.',
                                          '请先移除关联设备并撤销相关流水。',
                                        ),
                                        destructive: true,
                                      )) {
                                        if (await commit(
                                              (d) => deleteSupply(d, id),
                                              success: (_) => t(
                                                'Supply deleted.',
                                                '耗材已删除。',
                                              ),
                                            ) &&
                                            context.mounted) {
                                          Navigator.pop(context);
                                        } else if (context.mounted) {
                                          local(() {});
                                        }
                                      }
                                    },
                              child: Text(t('Delete supply', '删除耗材')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> editSlot(
    BuildContext context,
    Supply supply, [
    Slot? slot,
  ]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SlotEditor(
          zh: zh,
          supply: supply,
          slot: slot,
          failureMessage: () => message,
          hasHistory:
              slot != null && data!.events.any((e) => e.slotId == slot.id),
          save: (name, interval, last, verified, units) => commit(
            (d) => slot == null
                ? addSlot(
                    d,
                    Slot(
                      id: newId(),
                      supplyId: supply.id,
                      name: name,
                      intervalDays: interval,
                      lastChanged: last,
                      verified: verified,
                      units: units,
                    ),
                  )
                : updateSlot(
                    d,
                    slot.copyWith(
                      name: name,
                      intervalDays: interval,
                      lastChanged: last,
                      verified: verified,
                      units: units,
                    ),
                  ),
            success: (_) =>
                t('Appliance saved. Purchase plan updated.', '设备已保存，补货计划已更新。'),
            actionLabel: t('View plan', '查看计划'),
            next: () {
              showTab(0);
            },
          ),
        ),
      ),
    );
  }

  Future<void> receive(BuildContext context, Supply supply) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiveEditor(
          zh: zh,
          name: supply.name,
          currentStock: data!.supplies
              .firstWhere((s) => s.id == supply.id)
              .stock,
          failureMessage: () => message,
          save: (units) => commit(
            (d) => receiveSupply(d, supply.id, units, DateTime.now()),
            success: (d) => t(
              'Received $units unit(s). Stock: ${d.supplies.firstWhere((s) => s.id == supply.id).stock}.',
              '已入库 $units 件，当前库存 ${d.supplies.firstWhere((s) => s.id == supply.id).stock} 件。',
            ),
            actionLabel: t('View ledger', '查看流水'),
            next: () {
              showTab(2);
            },
          ),
        ),
      ),
    );
  }

  Widget ledger(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final events = data!.events;
      return ListView.builder(
        key: const PageStorageKey('ledger'),
        padding: EdgeInsets.fromLTRB(
          math.max(20, (size.maxWidth - 720) / 2),
          12,
          math.max(20, (size.maxWidth - 720) / 2),
          math.max(24, MediaQuery.viewPaddingOf(context).bottom),
        ),
        itemCount: events.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t(
                      'Receipts add stock. Replacements deduct it. Undo starts with the latest entry.',
                      '入库增加库存，更换扣减库存；撤销从最新记录开始。',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (events.isEmpty)
                    EmptyState(
                      icon: CupertinoIcons.clock,
                      title: t('No stock changes yet', '还没有库存变动'),
                      body: t(
                        'Receive your first supplies to start the ledger.',
                        '首次入库后，流水会出现在这里。',
                      ),
                      action: t('View supplies', '查看耗材'),
                      onAction: () => goToTab(1),
                    ),
                  if (events.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                t('Undo latest entry?', '撤销最新记录？'),
                                t(
                                  'Restore stock and the previous installation date for this transaction.',
                                  '恢复此操作前的库存与更换日期。',
                                ),
                              )) {
                                await commit(
                                  undoLast,
                                  success: (_) => t(
                                    'Latest entry undone. Stock and installation date restored.',
                                    '已撤销最新流水，库存与安装日期已恢复。',
                                  ),
                                  actionLabel: t('View plan', '查看计划'),
                                  next: () => goToTab(0),
                                );
                              }
                            },
                      icon: const Icon(CupertinoIcons.arrow_uturn_left),
                      label: Text(t('Undo latest entry', '撤销最新记录')),
                    ),
                ],
              ),
            );
          }
          final e = events[events.length - index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Surface(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  e.type == LedgerType.receipt
                      ? CupertinoIcons.plus_circle
                      : CupertinoIcons.arrow_2_squarepath,
                ),
                title: Text(
                  '${e.supplyName} · ${e.type == LedgerType.receipt ? t('Received', '入库') : t('Replaced', '更换')}',
                ),
                subtitle: Text(
                  '${dateLabel(e.createdAt.toLocal())}${e.slotName == null ? '' : '\n${e.slotName}'}',
                ),
                trailing: Text(
                  '${e.type == LedgerType.receipt ? '+' : '−'}${e.units}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  Widget settings(BuildContext context) => Content(
    key: const PageStorageKey('settings'),
    children: [
      Text(t('Language', '语言'), style: Theme.of(context).textTheme.titleMedium),
      Wrap(
        spacing: 8,
        children: [null, 'en', 'zh']
            .map(
              (v) => ChoiceChip(
                label: Text(
                  v == null
                      ? t('System', '跟随系统')
                      : v == 'en'
                      ? 'English'
                      : '简体中文',
                ),
                selected: data!.language == v,
                onSelected: busy
                    ? null
                    : (_) => commit(
                        (d) =>
                            d.copyWith(language: v, clearLanguage: v == null),
                      ),
              ),
            )
            .toList(),
      ),
      Text(
        t('Appearance', '外观'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Wrap(
        spacing: 8,
        children: [null, 'light', 'dark']
            .map(
              (v) => ChoiceChip(
                label: Text(
                  v == null
                      ? t('System', '跟随系统')
                      : v == 'light'
                      ? t('Light', '浅色')
                      : t('Dark', '深色'),
                ),
                selected: data!.appearance == v,
                onSelected: busy
                    ? null
                    : (_) => commit(
                        (d) => d.copyWith(
                          appearance: v,
                          clearAppearance: v == null,
                        ),
                      ),
              ),
            )
            .toList(),
      ),
      const Divider(),
      settingRow(
        CupertinoIcons.arrow_up_doc,
        t('Export backup', '导出备份'),
        t('Full library as a portable JSON file', '完整资料库，JSON 格式'),
        busy ? null : () => backup(context),
      ),
      settingRow(
        CupertinoIcons.arrow_down_doc,
        t('Restore backup', '恢复备份'),
        t('Preview and replace this library', '预览后替换当前资料库'),
        busy ? null : () => restore(context),
      ),
      settingRow(
        CupertinoIcons.play_rectangle,
        t('Replay introduction', '重新查看引导'),
        t('Your library stays as it is', '保留当前资料库'),
        busy ? null : () => update(() => replay = true),
      ),
      ExpansionTile(
        key: const PageStorageKey('privacy-details'),
        title: Text(t('Privacy and planning limits', '隐私与使用边界')),
        tilePadding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Your home, your data', '家中资料，由你掌握'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  t(
                    'No account, ads, analytics or developer server. Your library is stored locally. System backups, file providers and destinations you choose when sharing may store data outside this device. Exported files are readable: share them carefully. Removing this app may remove its library; keep a backup.',
                    '无需账号，没有广告、统计或开发者服务器。资料保存在本机；系统备份、文件提供方和你选择的分享目标可能将资料存到设备外。导出文件为可读明文，请谨慎分享。卸载可能删除资料库，请保留备份。',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Planning only. No automatic compatibility, safety checks, notifications or product recommendations. Use manufacturer guidance. 1.0.0 (1)',
                    '仅供计划参考，不自动判断适配或安全性，不发送通知或推荐产品。请遵循厂商说明。1.0.0 (1)',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      TextButton(
        onPressed: busy
            ? null
            : () async {
                if (await confirm(
                  context,
                  t('Erase local library?', '清除本机资料库？'),
                  t(
                    'Delete supplies, appliances, ledger and recovery copies from this app. Exported and system backup copies are outside this action. This cannot be undone.',
                    '删除本应用中的耗材、设备、流水和恢复副本。已导出及系统备份的副本不在清除范围内。此操作无法撤销。',
                  ),
                  destructive: true,
                )) {
                  if (context.mounted) await eraseLibrary(context);
                }
              },
        child: Text(t('Erase local library', '清除本机资料库')),
      ),
    ],
  );
  Widget settingRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? action,
  ) => ListTile(
    enabled: action != null,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(CupertinoIcons.chevron_right),
    onTap: action,
  );
  Future<bool> confirm(
    BuildContext context,
    String title,
    String body, {
    bool destructive = false,
  }) async {
    if (_confirming || !context.mounted) return false;
    update(() => _confirming = true);
    bool confirmed = false;
    try {
      confirmed =
          await showCupertinoDialog<bool>(
            context: context,
            builder: (c) => CupertinoAlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(t('Cancel', '取消')),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: destructive,
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(t('Confirm', '确认')),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed && mounted) {
        notice(t('Cancelled. Your library is unchanged.', '已取消，资料库未改变。'));
      }
      return confirmed;
    } finally {
      if (mounted) update(() => _confirming = false);
    }
  }

  Future<Directory> temporaryDirectory() =>
      (widget.temporaryDirectory ?? getTemporaryDirectory)();
  Future<ShareResult> sendShare(ShareParams params) =>
      widget.share?.call(params) ?? SharePlus.instance.share(params);
  String shareResultText(
    ShareResult result, {
    bool backup = false,
  }) => switch (result.status) {
    ShareResultStatus.dismissed => t(
      'Sharing cancelled. Your library is unchanged.',
      '已取消分享，资料库未改变。',
    ),
    ShareResultStatus.success =>
      backup
          ? t(
              'Backup handed to the selected destination. Check it there before relying on it.',
              '备份已交给所选目标，请到目标位置确认文件可用。',
            )
          : t(
              'Purchase list handed to the selected destination.',
              '采购清单已交给所选目标。',
            ),
    _ => t(
      'Share sheet closed. Check the selected destination; completion could not be confirmed.',
      '分享面板已关闭，无法确认接收结果，请到目标位置检查。',
    ),
  };
  Future<void> shareText(BuildContext context, String text) async {
    await runAction(
      t('Opening share sheet…', '正在打开分享…'),
      () async {
        final box = context.findRenderObject() as RenderBox?;
        final result = await sendShare(
          ShareParams(
            text: text,
            sharePositionOrigin: box == null ? null : shareAnchor(box),
          ),
        );
        message = shareResultText(result);
      },
      failure: (_) {
        message = t('Sharing did not finish. Please retry.', '分享未完成，请重试。');
        nextLabel = t('Retry', '重试');
        nextAction = () => shareText(context, text);
      },
    );
  }

  Future<void> backup(BuildContext context) async {
    File? file;
    await runAction(
      t('Preparing backup…', '正在准备备份…'),
      () async {
        final dir = await temporaryDirectory();
        file = File(
          '${dir.path}/refqo-backup-${DateTime.now().microsecondsSinceEpoch}.json',
        );
        try {
          await file!.writeAsString(encodeAppData(data!), flush: true);
          if (!context.mounted) return;
          final box = context.findRenderObject() as RenderBox?;
          final result = await sendShare(
            ShareParams(
              files: [XFile(file!.path)],
              sharePositionOrigin: box == null ? null : shareAnchor(box),
            ),
          );
          message = shareResultText(result, backup: true);
        } finally {
          try {
            if (file != null && await file!.exists()) await file!.delete();
          } catch (_) {
            message =
                '${message ?? t('Backup sharing did not finish.', '备份分享未完成。')} ${t('Temporary copy cleanup is pending; restart the app or retry clearing local data.', '临时副本尚未清理，请重启应用或重试清除本机资料。')}';
            messageError = true;
          }
        }
      },
      failure: (_) {
        message = t(
          'Backup could not be shared. Your library is unchanged. Please retry.',
          '备份未能分享，资料库未改变，请重试。',
        );
        nextLabel = t('Retry', '重试');
        nextAction = () => backup(context);
      },
    );
  }

  Future<void> eraseLibrary(BuildContext context) async {
    final empty = AppData(
      onboarded: true,
      language: data!.language,
      appearance: data!.appearance,
    );
    await runAction(
      t('Clearing library…', '正在清除资料…'),
      () async {
        await widget.repository.erase(empty);
        if (mounted) data = empty;
        try {
          await cleanTemporaryBackups(await temporaryDirectory());
        } catch (e) {
          throw EraseCleanupException(empty, e);
        }
      },
      success: () => t(
        'Local library and owned recovery copies cleared.',
        '本机资料库及应用管理的恢复副本已清除。',
      ),
      actionLabel: t('Add a supply', '添加耗材'),
      next: () => editSupply(context),
      failure: (e) {
        if (e is EraseCleanupException) {
          data = e.committed;
          message = t(
            'Library cleared. Some old copies could not be removed. Retry cleanup.',
            '资料库已清除，部分旧副本尚未删除，请重试清理。',
          );
          nextLabel = t('Retry cleanup', '重试清理');
          nextAction = () => eraseLibrary(context);
        } else {
          message = t(
            'Could not clear the library. Check storage and retry.',
            '未能清除资料库，请检查存储空间后重试。',
          );
        }
      },
    );
  }

  Future<void> recoverPrevious(BuildContext context) async {
    if (widget.repository is! FileRepository) return;
    await runAction(
      t('Reading recovery copy…', '正在读取恢复副本…'),
      () async {
        final previous = await (widget.repository as FileRepository)
            .loadPrevious();
        if (!context.mounted) return;
        if (!await confirm(
          context,
          t('Restore local recovery copy?', '恢复本机上次副本？'),
          t(
            '${previous.supplies.length} supplies, ${previous.slots.length} appliances, ${previous.events.length} entries. This is the state before your last saved change. The unreadable file will be retained for recovery.',
            '${previous.supplies.length} 种耗材、${previous.slots.length} 个设备、${previous.events.length} 条流水。这是最近一次保存前的资料。无法读取的原文件将保留。',
          ),
        )) {
          return;
        }
        await widget.repository.restore(previous);
        if (mounted) {
          data = previous;
          loadError = null;
          message = t('Local recovery copy restored.', '已恢复本机上次副本。');
        }
      },
      failure: (_) {
        message = t(
          'Could not restore the local copy. Retry or select an exported backup.',
          '未能恢复本机副本，请重试或选择已导出的备份。',
        );
      },
    );
  }

  Future<void> restore(BuildContext context) async {
    await runAction(
      t('Reading backup…', '正在读取备份…'),
      () async {
        final file =
            await (widget.pickBackup?.call() ??
                openFile(
                  acceptedTypeGroups: [
                    const XTypeGroup(
                      label: 'Refqo JSON',
                      extensions: ['json'],
                      uniformTypeIdentifiers: ['public.json'],
                    ),
                  ],
                ));
        if (file == null) {
          message = t(
            'Import cancelled. Your library is unchanged.',
            '已取消导入，资料库未改变。',
          );
          return;
        }
        if (await file.length() > maxBackupBytes) {
          throw const FormatException('Too large');
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > maxBackupBytes) {
          throw const FormatException('Too large');
        }
        final imported = decodeAppData(utf8.decode(bytes));
        if (!context.mounted) return;
        if (!await confirm(
          context,
          t('Replace library?', '替换资料库？'),
          t(
            '${imported.supplies.length} supplies, ${imported.slots.length} appliances, ${imported.events.length} ledger entries. Current data will be replaced. Export a backup first if you need it.',
            '${imported.supplies.length} 种耗材、${imported.slots.length} 个设备、${imported.events.length} 条流水。将替换当前资料，请先按需导出备份。',
          ),
          destructive: true,
        )) {
          return;
        }
        final replacement = imported.copyWith(onboarded: true);
        await widget.repository.restore(replacement);
        if (mounted) {
          data = replacement;
          loadError = null;
          message = t(
            'Backup restored. ${replacement.supplies.length} supplies available.',
            '备份已恢复，共 ${replacement.supplies.length} 种耗材。',
          );
        }
      },
      failure: (_) {
        message = t(
          'Could not restore this backup. Use a valid Refqo JSON file (up to 2 MB) and retry.',
          '未能恢复此备份，请选择有效的 Refqo JSON 文件（最大 2 MB）后重试。',
        );
        nextLabel = t('Choose backup', '选择备份');
        nextAction = () => restore(context);
      },
    );
  }
}

class Content extends StatelessWidget {
  const Content({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        math.max(20, (size.maxWidth - 720) / 2),
        12,
        math.max(20, (size.maxWidth - 720) / 2),
        math.max(24, MediaQuery.viewPaddingOf(context).bottom),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children)
            Padding(padding: const EdgeInsets.only(bottom: 18), child: c),
        ],
      ),
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title, body;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: FilledButton(onPressed: onAction, child: Text(action!)),
          ),
      ],
    ),
  );
}

class RefillMark extends StatelessWidget {
  const RefillMark({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    height: 96,
    decoration: BoxDecoration(
      color: plum,
      borderRadius: BorderRadius.circular(26),
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset('assets/brand/refqo-1024.png'),
  );
}

class Onboarding extends StatelessWidget {
  const Onboarding({
    super.key,
    required this.zh,
    required this.busy,
    required this.onDone,
    this.error,
  });
  final bool zh, busy;
  final VoidCallback onDone;
  final String? error;
  @override
  Widget build(BuildContext context) {
    String t(String e, String c) => zh ? c : e;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refqo'),
        actions: [
          TextButton(
            onPressed: busy ? null : onDone,
            child: Text(t('Skip', '跳过')),
          ),
        ],
      ),
      body: Content(
        children: [
          const Align(alignment: Alignment.centerLeft, child: RefillMark()),
          Text(
            t('Buy enough.\nKeep less guesswork.', '买得够用，\n不再凭印象。'),
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            t(
              'A shared shelf for the refills your home runs on.',
              '把家中耗材的型号、库存和设备放到一起。',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('01  Match the part', '01  记清型号'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  t(
                    'Save exact codes and confirm fit yourself. Link every appliance using that refill.',
                    '记录准确型号并人工核对适配，再关联使用同款耗材的设备。',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t('02  Plan the next supply run', '02  提前算好补货'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  t(
                    'See 30, 60 or 90 days of demand after shared stock. Receive, replace and undo mistakes.',
                    '合并未来 30、60 或 90 天的用量，扣除共享库存；入库、更换和撤销都有记录。',
                  ),
                ),
              ],
            ),
          ),
          Text(
            t(
              'Works offline, without an account. You control exports. System backups and sharing destinations may use cloud storage.',
              '离线可用，无需账号，由你决定导出。系统备份和分享目标可能使用云端存储。',
            ),
          ),
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
          if (busy) const LinearProgressIndicator(),
          FilledButton(
            onPressed: busy ? null : onDone,
            child: Text(t('Build my refill shelf', '建立我的耗材库')),
          ),
        ],
      ),
    );
  }
}

class SupplyEditor extends StatefulWidget {
  const SupplyEditor({
    super.key,
    required this.zh,
    this.supply,
    required this.save,
    this.failureMessage,
  });
  final bool zh;
  final Supply? supply;
  final Future<bool> Function(String, String, String) save;
  final String? Function()? failureMessage;
  @override
  State<SupplyEditor> createState() => _SupplyEditorState();
}

class _SupplyEditorState extends EditorState<SupplyEditor> {
  late final name = TextEditingController(text: widget.supply?.name);
  late final code = TextEditingController(text: widget.supply?.code);
  late final notes = TextEditingController(text: widget.supply?.notes);
  @override
  void dispose() {
    name.dispose();
    code.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String e, String c) => widget.zh ? c : e;
    return editorScaffold(
      title: widget.supply == null
          ? t('Add supply', '添加耗材')
          : t('Edit supply', '编辑耗材'),
      zh: widget.zh,
      submitLabel: t('Save supply', '保存耗材'),
      onSubmit: () => submit(
        () =>
            widget.save(name.text.trim(), code.text.trim(), notes.text.trim()),
        widget.zh,
        failureMessage: widget.failureMessage,
      ),
      children: [
        Text(
          t('Use Receive to add spare stock after saving.', '保存后通过“入库”添加备件库存。'),
        ),
        field(name, t('Supply name', '耗材名称'), required: true),
        field(code, t('Part code / size', '型号 / 尺寸')),
        field(
          notes,
          t('Fit notes / buying notes', '适配 / 采购备注'),
          maxLength: 400,
          lines: 3,
        ),
      ],
    );
  }
}

class SlotEditor extends StatefulWidget {
  const SlotEditor({
    super.key,
    required this.zh,
    required this.supply,
    this.slot,
    required this.hasHistory,
    required this.save,
    this.failureMessage,
  });
  final bool zh, hasHistory;
  final Supply supply;
  final Slot? slot;
  final Future<bool> Function(String, int, DateTime, bool, int) save;
  final String? Function()? failureMessage;
  @override
  State<SlotEditor> createState() => _SlotEditorState();
}

class _SlotEditorState extends EditorState<SlotEditor> {
  late final name = TextEditingController(text: widget.slot?.name);
  late final interval = TextEditingController(
    text: '${widget.slot?.intervalDays ?? 90}',
  );
  late final units = TextEditingController(text: '${widget.slot?.units ?? 1}');
  late final last = TextEditingController(
    text: dateLabel(widget.slot?.lastChanged ?? DateTime.now()),
  );
  late bool verified = widget.slot?.verified ?? false;
  @override
  void dispose() {
    name.dispose();
    interval.dispose();
    units.dispose();
    last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String e, String c) => widget.zh ? c : e;
    String? number(String? s, int max) {
      final n = int.tryParse(s ?? '');
      return n == null || n < 1 || n > max
          ? t('Enter 1–$max', '请输入 1–$max')
          : null;
    }

    return editorScaffold(
      title: widget.slot == null
          ? t('Link appliance', '关联设备')
          : t('Edit appliance', '编辑设备'),
      zh: widget.zh,
      submitLabel: t('Save appliance', '保存设备'),
      onSubmit: () => submit(
        () => widget.save(
          name.text.trim(),
          int.parse(interval.text),
          DateTime.parse(last.text),
          verified,
          int.parse(units.text),
        ),
        widget.zh,
        failureMessage: widget.failureMessage,
      ),
      children: [
        Text(
          '${t('Uses', '使用耗材')}: ${widget.supply.name} · ${widget.supply.code}',
        ),
        field(name, t('Appliance / location', '设备 / 位置'), required: true),
        field(
          interval,
          t('Interval in days', '周期（天）'),
          maxLength: 4,
          keyboard: TextInputType.number,
          validator: (v) => number(v, 3650),
        ),
        Text(
          t(
            'Use the manufacturer interval. Initial values are not safety advice.',
            '周期请按厂商说明填写，初始数值不代表安全建议。',
          ),
        ),
        field(
          units,
          t('Units per replacement', '每次更换用量'),
          maxLength: 3,
          keyboard: TextInputType.number,
          validator: (v) => number(v, 100),
        ),
        field(
          last,
          t('Last changed · YYYY-MM-DD', '上次更换 · YYYY-MM-DD'),
          maxLength: 10,
          keyboard: TextInputType.datetime,
          readOnly: widget.hasHistory,
          validator: (v) {
            final d = DateTime.tryParse(v ?? '');
            return d == null ||
                    dateLabel(d) != v ||
                    calendarDay(d).isAfter(calendarDay(DateTime.now()))
                ? t('Enter a valid date, today or earlier', '请输入今天或更早的有效日期')
                : null;
          },
        ),
        if (widget.hasHistory)
          Text(
            t(
              'Undo the replacement in Ledger to change this protected date.',
              '日期由流水保护，撤销相关更换记录后可修改。',
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: verified,
          onChanged: saving ? null : (v) => setState(() => verified = v!),
          title: Text(t('I checked this part fits', '我已核对此型号适配')),
          subtitle: Text(
            t(
              'Your manual confirmation; no automatic fit check.',
              '人工确认记录，不是自动适配判断。',
            ),
          ),
        ),
      ],
    );
  }
}

class ReceiveEditor extends StatefulWidget {
  const ReceiveEditor({
    super.key,
    required this.zh,
    required this.name,
    required this.save,
    this.currentStock = 0,
    this.failureMessage,
  });
  final bool zh;
  final String name;
  final int currentStock;
  final Future<bool> Function(int) save;
  final String? Function()? failureMessage;
  @override
  State<ReceiveEditor> createState() => _ReceiveEditorState();
}

class _ReceiveEditorState extends EditorState<ReceiveEditor> {
  final quantity = TextEditingController(text: '1');
  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String e, String c) => widget.zh ? c : e;
    return editorScaffold(
      title: t('Receive stock', '耗材入库'),
      zh: widget.zh,
      submitLabel: t('Add to stock', '确认入库'),
      onSubmit: () => submit(
        () => widget.save(int.parse(quantity.text)),
        widget.zh,
        failureMessage: widget.failureMessage,
      ),
      children: [
        Text(widget.name, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          t(
            'Count usable spare units, not packs or installed units.',
            '填写可用备件件数，不是包装数；已安装的耗材不计入库存。',
          ),
        ),
        field(
          quantity,
          t('Units received', '入库件数'),
          maxLength: 5,
          keyboard: TextInputType.number,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 1 || n > 99999) {
              return t('Enter 1–99999', '请输入 1–99999');
            }
            if (widget.currentStock + n > 99999) {
              return t('Total stock cannot exceed 99999', '累计库存不能超过 99999');
            }
            return null;
          },
        ),
      ],
    );
  }
}
