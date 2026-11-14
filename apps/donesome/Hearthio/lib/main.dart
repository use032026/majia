import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoButton,
        CupertinoIcons,
        CupertinoPicker,
        CupertinoTheme,
        CupertinoThemeData,
        showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stmini_flutter/stmini_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'app/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'l10n/catalog_l10n.dart';
import 'l10n/l10n.dart';
import 'l10n/maintenance_l10n.dart';
import 'models/care_item.dart';
import 'models/care_space.dart';
import 'models/maintenance_completion.dart';
import 'models/maintenance_calendar.dart';
import 'models/maintenance_lifecycle.dart';
import 'models/maintenance_notification.dart';
import 'models/maintenance_plan.dart';
import 'models/maintenance_record.dart';
import 'models/maintenance_status.dart';
import 'models/maintenance_task.dart';
import 'models/maintenance_template.dart';
import 'feature_intro_page.dart';
import 'privacy_policy_page.dart';
import 'services/care_backup_codec.dart';
import 'services/care_repository.dart';
import 'services/maintenance_execution_controller.dart';
import 'services/maintenance_history_controller.dart';
import 'services/system_permission_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_alert.dart';
import 'widgets/app_back_button.dart';
import 'widgets/app_date_picker.dart';
import 'widgets/app_safe_area.dart';
import 'widgets/app_toast.dart';
import 'widgets/maintenance_plan_editor.dart';
import 'widgets/maintenance_execution_page.dart';
import 'widgets/maintenance_lifecycle_section.dart';
import 'widgets/maintenance_task_card.dart';
import 'widgets/maintenance_report_page.dart';
import 'widgets/system_permission_alert.dart';
import 'widgets/three_finger_long_press_region.dart';

export 'models/care_item.dart';
export 'models/care_space.dart';
export 'models/maintenance_completion.dart';
export 'models/maintenance_calendar.dart';
export 'models/maintenance_lifecycle.dart';
export 'models/maintenance_notification.dart';
export 'models/maintenance_plan.dart';
export 'models/maintenance_record.dart';
export 'models/maintenance_report.dart';
export 'models/maintenance_status.dart';
export 'models/maintenance_task.dart';
export 'models/maintenance_template.dart';
export 'services/care_backup_codec.dart';
export 'services/care_repository.dart';
export 'services/maintenance_execution_controller.dart';
export 'services/maintenance_history_controller.dart';
export 'services/system_permission_service.dart';
export 'widgets/app_alert.dart';
export 'widgets/app_back_button.dart';
export 'widgets/app_date_picker.dart';
export 'widgets/app_toast.dart';
export 'widgets/maintenance_plan_editor.dart';
export 'widgets/maintenance_execution_page.dart';
export 'widgets/maintenance_lifecycle_section.dart';
export 'widgets/maintenance_record_editor.dart';
export 'widgets/maintenance_report_page.dart';
export 'widgets/maintenance_task_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HearthioApp());
}

Future<void> _configureDeviceTimeZone() async {
  tz.initializeTimeZones();
  try {
    final deviceZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceZone.identifier));
  } catch (_) {
    // The framework defaults to UTC only if the device's zone is unavailable.
  }
}

Future<void>? _timeZoneReady;
Future<void> _ensureDeviceTimeZone() =>
    _timeZoneReady ??= _configureDeviceTimeZone();

Future<void> _refreshDeviceTimeZone() {
  final refresh = _configureDeviceTimeZone();
  _timeZoneReady = refresh;
  return refresh;
}

const _kifxMiniDownloadUrl =
    'https://site.761242.com/maple/v1/static/'
    '20260908_018ee521a82c8c4edb72c8d9f2a2b18157.zip';
const _kifxMiniVersion = '2.0.0';
const _kifxHostPackageName = 'com.Hearthio.lite';
const _kifxMiniAutoOpenPreferenceKey = 'kifx_mini_auto_open';

final _kifxMiniLink = Uri(
  scheme: 'mini',
  host: 'kifx',
  queryParameters: const {
    'downloadUrl': _kifxMiniDownloadUrl,
    'currentVersion': _kifxMiniVersion,
    'minSupportVersion': _kifxMiniVersion,
    'miniName': 'KIFX',
    'miniNameEn': 'KIFX',
  },
).toString();

Future<void> _launchKifxMini() async {
  await StminiFlutter.initialize(
    bridgeContext: const {'packageName': _kifxHostPackageName},
  );
  await StminiFlutter.openMini(_kifxMiniLink);
}

class HearthioApp extends StatefulWidget {
  const HearthioApp({super.key, this.localeController});

  final AppLocaleController? localeController;

  @override
  State<HearthioApp> createState() => _HearthioAppState();
}

class _HearthioAppState extends State<HearthioApp> {
  late AppLocaleController _localeController;
  late bool _ownsLocaleController;

  @override
  void initState() {
    super.initState();
    _setLocaleController(widget.localeController);
  }

  @override
  void didUpdateWidget(HearthioApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController == widget.localeController) return;
    if (_ownsLocaleController) _localeController.dispose();
    _setLocaleController(widget.localeController);
  }

  void _setLocaleController(AppLocaleController? controller) {
    _ownsLocaleController = controller == null;
    _localeController = controller ?? AppLocaleController();
    if (_ownsLocaleController) unawaited(_localeController.load());
  }

  @override
  void dispose() {
    if (_ownsLocaleController) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _localeController,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _localeController.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (preferred, _) =>
          resolveSupportedAppLocale(preferred),
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: HearthioTheme.light,
      darkTheme: HearthioTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) => AppLocaleScope(
        controller: _localeController,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const AppEntry(),
    ),
  );
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool? _onboardingSeen;
  bool _kifxAutoOpenScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    var kifxAutoOpenEnabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
      kifxAutoOpenEnabled =
          prefs.getBool(_kifxMiniAutoOpenPreferenceKey) ?? false;
    } catch (_) {
      _onboardingSeen = false;
    }
    if (!mounted) return;
    setState(() {});
    if (_onboardingSeen! && kifxAutoOpenEnabled) {
      _scheduleKifxAutoOpen();
    }
  }

  void _scheduleKifxAutoOpen() {
    if (_kifxAutoOpenScheduled) return;
    _kifxAutoOpenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || Theme.of(context).platform != TargetPlatform.iOS) return;
      try {
        await _launchKifxMini();
      } catch (_) {
        if (mounted) {
          AppToast.show(
            context,
            context.l10n.kifxMiniOpenFailed,
            style: AppToastStyle.error,
          );
        }
      }
    });
  }

  Future<void> _finishOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_seen', true);
    } catch (_) {
      // The walkthrough can safely be shown again if local storage is absent.
    }
    if (mounted) setState(() => _onboardingSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingSeen == null) {
      return Scaffold(backgroundColor: context.palette.canvas);
    }
    return _onboardingSeen!
        ? const HomePage()
        : OnboardingPage(onFinished: _finishOnboarding);
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});
  final Future<void> Function() onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  static const _images = [
    'assets/onboarding/archive.png',
    'assets/onboarding/proof.png',
    'assets/onboarding/calendar.png',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page == _images.length - 1) {
      await widget.onFinished();
    } else {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      (title: l10n.onboardingArchiveTitle, body: l10n.onboardingArchiveBody),
      (title: l10n.onboardingEvidenceTitle, body: l10n.onboardingEvidenceBody),
      (title: l10n.onboardingReminderTitle, body: l10n.onboardingReminderBody),
    ];
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onFinished,
                child: Text(
                  l10n.onboardingSkip,
                  style: TextStyle(color: context.palette.muted),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
                    child: Column(
                      children: [
                        Expanded(
                          child: RepaintBoundary(
                            child: Image.asset(
                              _images[index],
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.low,
                              cacheWidth: 1000,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.palette.ink,
                            fontSize: 26,
                            letterSpacing: -.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.palette.muted,
                            height: 1.5,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _page == index ? 23 : 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _page == index
                              ? context.palette.primary
                              : context.palette.disabled,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(
                      _page == pages.length - 1
                          ? l10n.onboardingStart
                          : l10n.onboardingNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BreezeSurface extends StatelessWidget {
  const BreezeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? context.palette.paper,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: context.palette.border),
    ),
    child: child,
  );
}

class BreezeHeader extends StatelessWidget {
  const BreezeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.palette.ink,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: TextStyle(color: context.palette.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class AppBottomDock extends StatelessWidget {
  const AppBottomDock({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home_rounded, context.l10n.homeTab),
      (
        Icons.grid_view_rounded,
        Icons.inventory_2_rounded,
        context.l10n.itemsTab,
      ),
      (
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        context.l10n.scheduleTab,
      ),
      (
        Icons.auto_graph_rounded,
        Icons.auto_graph_rounded,
        context.l10n.reportTab,
      ),
      (Icons.tune_rounded, Icons.tune_rounded, context.l10n.settingsTab),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.paper,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final active = selected == index;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('bottom-tab-$index'),
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: active ? context.palette.mist : Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active ? item.$2 : item.$1,
                          size: 20,
                          color: active
                              ? context.palette.primary
                              : context.palette.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: active
                                ? context.palette.primary
                                : context.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class AddItemButton extends StatelessWidget {
  const AddItemButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.primary,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: context.palette.onPrimary),
            const SizedBox(width: 7),
            Text(
              context.l10n.addItem,
              style: TextStyle(
                color: context.palette.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final effectiveTone = enabled
        ? tone ?? context.palette.primary
        : context.palette.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveTone.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: effectiveTone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? context.palette.ink
                            : context.palette.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled
                    ? context.palette.muted
                    : context.palette.muted.withValues(alpha: .45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoSourceRow extends StatelessWidget {
  const PhotoSourceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.source,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final ImageSource source;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.pop(context, source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.palette.mist,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: context.palette.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.palette.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: context.palette.muted,
              size: 15,
            ),
          ],
        ),
      ),
    ),
  );
}

enum NotificationAccess { notDetermined, enabled, denied, unavailable }

typedef CareNotificationScheduler =
    Future<void> Function(CareItem item, CareItem? previous);
typedef CareNotificationAccessResolver = Future<NotificationAccess> Function();
typedef CareBackupPicker = Future<String?> Function();
typedef CareDocumentsDirectoryProvider = Future<Directory> Function();
typedef CareImagePicker = Future<XFile?> Function(ImageSource source);

Future<XFile?> _pickCareImage(ImageSource source) => ImagePicker().pickImage(
  source: source,
  imageQuality: 82,
  maxWidth: 1800,
  requestFullMetadata: false,
);

Future<String?> _pickCareBackup() async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['zip'],
  );
  return picked?.files.single.path;
}

int notificationIdForPlan(String itemId, String planId) {
  var hash = 0x811C9DC5;
  // Length-prefix both components so identities such as ("a:b", "c") and
  // ("a", "b:c") can never collapse into the same pre-hash input.
  final identity = '${itemId.length}:$itemId${planId.length}:$planId';
  for (final codeUnit in identity.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final value = hash & 0x7FFFFFFF;
  return value == 0 ? 1 : value;
}

int _care002NotificationIdForPlan(String itemId, String planId) {
  var hash = 0x811C9DC5;
  for (final codeUnit in '$itemId:$planId'.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final value = hash & 0x7FFFFFFF;
  return value == 0 ? 1 : value;
}

NotificationAccess notificationAccessFrom({
  required bool notificationsEnabled,
  required bool permissionPrompted,
}) {
  if (notificationsEnabled) return NotificationAccess.enabled;
  return permissionPrompted
      ? NotificationAccess.denied
      : NotificationAccess.notDetermined;
}

Future<bool> _showNotificationPrimer(BuildContext context) async =>
    await showAppAlert<bool>(
      context,
      title: context.l10n.notificationPrimerTitle,
      message: context.l10n.notificationPrimerMessage,
      actions: [
        AppAlertAction(label: context.l10n.notificationNotNow, result: false),
        AppAlertAction(
          label: context.l10n.notificationEnable,
          result: true,
          isDefaultAction: true,
        ),
      ],
    ) ??
    false;

String _localizedDate(BuildContext context, DateTime? date) => date == null
    ? context.l10n.dateNotSet
    : context.l10n.dateYmd(date.year, date.month, date.day);

String? _nonNegativeNumber(BuildContext context, String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final number = double.tryParse(text);
  if (number == null || !number.isFinite || number < 0) {
    return context.l10n.validationNonNegativeAmount;
  }
  return null;
}

Future<void> _deferMaintenanceTask(
  BuildContext context,
  CareStore store,
  MaintenanceTask task,
) async {
  final today = maintenanceDateOnly(DateTime.now());
  final tomorrow = addMaintenanceDays(today, 1);
  final deferredUntil = await showModalBottomSheet<DateTime>(
    context: context,
    builder: (sheet) => SingleChildScrollView(
      padding: appSafeScrollPadding(
        sheet,
        const EdgeInsets.fromLTRB(20, 16, 20, 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sheet.l10n.deferTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            sheet.l10n.deferTaskDescription(
              _itemDisplayName(sheet, task.item),
              sheet.l10n.maintenancePlanTitleLabel(task.plan.title),
              _localizedDate(sheet, task.dueDate),
            ),
            style: TextStyle(color: sheet.palette.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const Key('defer-until-tomorrow'),
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(sheet.l10n.tomorrow),
            subtitle: Text(_localizedDate(sheet, tomorrow)),
            onTap: () => Navigator.pop(sheet, tomorrow),
          ),
          ListTile(
            key: const Key('defer-until-three-days'),
            leading: const Icon(Icons.calendar_view_day_outlined),
            title: Text(sheet.l10n.inThreeDays),
            subtitle: Text(_localizedDate(sheet, addMaintenanceDays(today, 3))),
            onTap: () => Navigator.pop(sheet, addMaintenanceDays(today, 3)),
          ),
          ListTile(
            key: const Key('defer-until-next-week'),
            leading: const Icon(Icons.date_range_outlined),
            title: Text(sheet.l10n.nextWeek),
            subtitle: Text(_localizedDate(sheet, addMaintenanceDays(today, 7))),
            onTap: () => Navigator.pop(sheet, addMaintenanceDays(today, 7)),
          ),
          ListTile(
            key: const Key('defer-until-custom'),
            leading: const Icon(Icons.edit_calendar_outlined),
            title: Text(sheet.l10n.customDate),
            onTap: () async {
              final selected = await showAppDatePicker(
                context: sheet,
                initialDate: tomorrow,
                firstDate: tomorrow,
                lastDate: DateTime(2100, 12, 31),
              );
              if (selected != null && sheet.mounted) {
                Navigator.pop(sheet, selected);
              }
            },
          ),
        ],
      ),
    ),
  );
  if (deferredUntil == null || !context.mounted) return;
  try {
    await store.deferPlan(task.item, task.plan.id, deferredUntil);
  } catch (_) {
    if (context.mounted) {
      AppToast.show(
        context,
        context.l10n.deferFailed,
        style: AppToastStyle.error,
      );
    }
  }
}

Future<bool?> _startMaintenanceTask(
  BuildContext context,
  MaintenanceExecutionController controller,
  MaintenanceTask task, {
  bool openLifecycleAfterCompletion = true,
}) async {
  final completed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          MaintenanceExecutionPage(controller: controller, task: task),
    ),
  );
  if (completed != true ||
      !openLifecycleAfterCompletion ||
      controller is! CareStore ||
      !context.mounted) {
    return completed;
  }
  CareItem? latestItem;
  for (final item in controller.items) {
    if (item.id == task.item.id) {
      latestItem = item;
      break;
    }
  }
  if (latestItem == null || !context.mounted) return completed;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => DetailPage(store: controller, item: latestItem!),
    ),
  );
  return completed;
}

class CareStore extends ChangeNotifier
    implements MaintenanceExecutionController, MaintenanceHistoryController {
  static const _exampleItemId = 'sample-filter';
  static const _examplePlanId = 'sample-filter-plan';

  CareStore({
    CareRepository? repository,
    CareNotificationScheduler? notificationScheduler,
    CareNotificationAccessResolver? notificationAccessResolver,
    CareBackupPicker? backupPicker,
    CareDocumentsDirectoryProvider? documentsDirectoryProvider,
    SystemPermissionGuard? systemPermissions,
    CareImagePicker? imagePicker,
  }) : _repository = repository,
       _notificationScheduler = notificationScheduler,
       _notificationAccessResolver = notificationAccessResolver,
       _backupPicker = backupPicker ?? _pickCareBackup,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _systemPermissions =
           systemPermissions ??
           const SystemPermissionGuard(MethodChannelSystemPermissionGateway()),
       _imagePicker = imagePicker ?? _pickCareImage;

  final _notifications = FlutterLocalNotificationsPlugin();
  AppLocalizations _localizations = lookupAppLocalizations(
    resolveSupportedAppLocale(null),
  );
  bool _receivedAppLocalizations = false;
  Future<void>? _notificationsReady;
  Future<void> _notificationMutationTail = Future.value();
  Future<void> _persistenceTail = Future.value();
  CareRepository? _repository;
  final CareNotificationScheduler? _notificationScheduler;
  final CareNotificationAccessResolver? _notificationAccessResolver;
  final CareBackupPicker _backupPicker;
  final CareDocumentsDirectoryProvider _documentsDirectoryProvider;
  final SystemPermissionGuard _systemPermissions;
  final CareImagePicker _imagePicker;
  final Map<String, Future<MaintenanceCompletionResult>> _completionOperations =
      {};
  Future<bool>? _restoreOperation;
  final List<String> _pendingNotificationPayloads = [];
  Future<void> _dataMutationTail = Future.value();
  bool _writesBlocked = false;
  List<CareItem> items = [];
  List<CareSpace> spaces = [];
  bool loaded = false;
  String? loadError;

  bool get isDataReadOnly => _writesBlocked;
  bool get isRestoringBackup => _restoreOperation != null;

  void updateLocalizations(AppLocalizations value) {
    _receivedAppLocalizations = true;
    if (_localizations.localeName == value.localeName) return;
    _localizations = value;
    if (loaded) unawaited(_rescheduleRemindersIfAuthorized());
  }

  Future<void> _resolveInitialLocalizations() async {
    if (_receivedAppLocalizations) return;
    final mode = await AppLocaleController.readSavedMode();
    _localizations = lookupAppLocalizations(resolveAppLocaleForMode(mode));
  }

  CareSpace? spaceById(String? id) {
    if (id == null) return null;
    for (final space in spaces) {
      if (space.id == id) return space;
    }
    return null;
  }

  String? spaceNameFor(CareItem item) => spaceById(item.spaceId)?.name;

  String locationLabelFor(CareItem item, [AppLocalizations? localizations]) {
    final l10n = localizations ?? _localizations;
    final space = spaceById(item.spaceId);
    final room = space == null ? '' : l10n.spaceNameLabel(space).trim();
    final detail = item.locationDetail.trim();
    if (room.isNotEmpty && detail.isNotEmpty) return '$room · $detail';
    if (room.isNotEmpty) return room;
    if (detail.isNotEmpty) {
      return '${l10n.unassignedSpace} · $detail';
    }
    final fallback = item.location.trim();
    final fallbackType = knownCareSpaceType(fallback);
    return fallbackType == null ? fallback : l10n.spaceTypeLabel(fallbackType);
  }

  List<CareItem> itemsInSpace(String? spaceId) => items
      .where(
        (item) => spaceId == null
            ? spaceById(item.spaceId) == null
            : item.spaceId == spaceId,
      )
      .toList(growable: false);

  bool get hasPendingNotificationNavigation =>
      _pendingNotificationPayloads.isNotEmpty;

  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    _pendingNotificationPayloads.add(payload);
    notifyListeners();
  }

  MaintenanceNotificationResolution? takeNotificationNavigation() {
    if (!loaded || _pendingNotificationPayloads.isEmpty) return null;
    final payload = _pendingNotificationPayloads.removeAt(0);
    return resolveMaintenanceNotification(payload, items);
  }

  void dismissLoadError() {
    if (loadError == null) return;
    loadError = null;
    notifyListeners();
  }

  Future<CareRepository> _openRepository() async =>
      _repository ??= await CareRepository.open();

  Future<void> _ensureNotificationsReady() =>
      _notificationsReady ??= _initializeNotifications().catchError((_) {});

  Future<void> load() => _serializeDataMutation(_load);

  Future<void> _load() async {
    try {
      await _resolveInitialLocalizations();
      final repository = await _openRepository();
      final result = await repository.load(
        initialItems: [_newExampleItem(_localizations)],
      );
      items = [...result.items];
      spaces = [...result.spaces];
      loadError = null;
      _writesBlocked = false;
      final replacedExamples = _replaceLegacyExamples();
      final normalizedFacts = _normalizeMaintenanceFactsIn(items);
      final migratedLocations = migrateLegacyItemLocations(
        items,
        existingSpaces: spaces,
      );
      final linkedLocations =
          migratedLocations.spaces.length != spaces.length ||
          migratedLocations.items.indexed.any(
            (entry) => !identical(entry.$2, items[entry.$1]),
          );
      items = [...migratedLocations.items];
      spaces = [...migratedLocations.spaces];
      if (replacedExamples || normalizedFacts || linkedLocations) {
        await _persist();
      }
    } catch (_) {
      // Keep the app usable while making it explicit that the unreadable
      // snapshot was preserved and must not be replaced by an empty list.
      items = [];
      spaces = [];
      loadError = '本地档案读取失败，原数据仍保留在设备上，当前编辑已暂停。请勿卸载应用，可重启或从有效备份恢复。';
      _writesBlocked = true;
    }
    loaded = true;
    notifyListeners();
    if (!_writesBlocked) {
      // Upgrades can replace one legacy reminder with several plan-specific
      // reminders. Refresh silently only when access already exists; loading
      // data must never trigger the system permission prompt.
      unawaited(_rescheduleRemindersIfAuthorized());
    }
  }

  Future<void> save(CareItem item) => _serializeDataMutation(() => _save(item));

  Future<void> _save(CareItem item) async {
    _ensureWritable();
    final nextItems = [...items];
    final index = nextItems.indexWhere((entry) => entry.id == item.id);
    CareItem? previous;
    final removedPhotos = <String>[];
    if (index == -1) {
      nextItems.add(item);
    } else {
      previous = nextItems[index];
      final nextPhotos = _photoPathsForItem(item).toSet();
      removedPhotos.addAll(
        _photoPathsForItem(
          previous,
        ).where((path) => !nextPhotos.contains(path)),
      );
      nextItems[index] = item;
    }
    await _writeItems(nextItems);
    items = nextItems;
    notifyListeners();
    _deleteUnreferencedPhotos(removedPhotos, retainedBy: nextItems);
    // A notification failure must never turn a persisted edit into failure.
    unawaited(_scheduleSafely(item, previous: previous));
  }

  void _ensureWritable() {
    if (_writesBlocked) {
      throw const FileSystemException(
        'Care data is read-only after load failure',
      );
    }
  }

  Future<void> _writeItems(List<CareItem> nextItems) =>
      _writeData(nextItems, spaces);

  Future<void> _writeData(
    List<CareItem> nextItems,
    List<CareSpace> nextSpaces,
  ) {
    final snapshot = CareDataEnvelope(
      items: nextItems,
      spaces: nextSpaces,
    ).encode();
    final write = _persistenceTail.then((_) async {
      final repository = await _openRepository();
      await repository.writeEncodedSnapshot(snapshot);
    });
    _persistenceTail = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return write;
  }

  Future<CareSpace> saveSpace(CareSpace space) =>
      _serializeDataMutation(() => _saveSpace(space));

  Future<CareSpace> _saveSpace(CareSpace space) async {
    _ensureWritable();
    final normalized = CareSpace(
      id: space.id,
      type: space.type.trim(),
      name: space.name.trim(),
    );
    if (normalized.name.isEmpty) throw const FormatException('空间名称不能为空');
    if (spaces.any(
      (candidate) =>
          candidate.id != normalized.id &&
          careSpaceNamesAreDuplicate(candidate, normalized),
    )) {
      throw DuplicateSpaceNameException(normalized.name);
    }
    final nextSpaces = [...spaces];
    final index = nextSpaces.indexWhere((entry) => entry.id == normalized.id);
    if (index == -1) {
      nextSpaces.add(normalized);
    } else {
      nextSpaces[index] = normalized;
    }
    await _writeData(items, nextSpaces);
    spaces = nextSpaces;
    notifyListeners();
    return normalized;
  }

  Future<void> removeSpace(String spaceId, {String? replacementSpaceId}) =>
      _serializeDataMutation(
        () => _removeSpace(spaceId, replacementSpaceId: replacementSpaceId),
      );

  Future<void> _removeSpace(
    String spaceId, {
    String? replacementSpaceId,
  }) async {
    _ensureWritable();
    if (spaceId == replacementSpaceId) {
      throw const FormatException('不能迁移到正在删除的空间');
    }
    final target = spaceById(replacementSpaceId);
    if (replacementSpaceId != null && target == null) {
      throw const FormatException('迁移目标空间不存在');
    }
    final nextSpaces = spaces.where((space) => space.id != spaceId).toList();
    if (nextSpaces.length == spaces.length) return;
    final nextItems = items
        .map((item) {
          if (item.spaceId != spaceId) return item;
          final detail = item.locationDetail.trim();
          final fallback = target == null
              ? detail
              : [
                  target.name,
                  detail,
                ].where((value) => value.isNotEmpty).join(' · ');
          return item.copyWith(
            spaceId: replacementSpaceId,
            clearSpaceId: replacementSpaceId == null,
            location: fallback,
          );
        })
        .toList(growable: false);
    await _writeData(nextItems, nextSpaces);
    items = nextItems;
    spaces = nextSpaces;
    notifyListeners();
  }

  Future<void> _deletePhoto(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      /* no-op */
    }
  }

  Future<void> remove(CareItem item) =>
      _serializeDataMutation(() => _remove(item.id));

  Future<void> _remove(String itemId) async {
    _ensureWritable();
    final index = items.indexWhere((entry) => entry.id == itemId);
    if (index == -1) return;
    final removed = items[index];
    final nextItems = [...items]..removeAt(index);
    await _writeItems(nextItems);
    items = nextItems;
    notifyListeners();
    _deleteUnreferencedPhotos(
      _photoPathsForItem(removed),
      retainedBy: nextItems,
    );
    unawaited(_cancelItemNotificationsSafely(removed));
  }

  bool get hasExampleData => items.any((item) => item.isSample);

  Future<bool> shouldOfferNotificationPrimer() async {
    if (await notificationAccess() != NotificationAccess.notDetermined) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('notification_primer_seen') ?? false);
  }

  Future<void> markNotificationPrimerSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_primer_seen', true);
  }

  Future<void> deleteExampleData() =>
      _serializeDataMutation(_deleteExampleData);

  Future<void> _deleteExampleData() async {
    _ensureWritable();
    final examples = items.where((item) => item.isSample).toList();
    if (examples.isEmpty) return;
    final nextItems = items.where((item) => !item.isSample).toList();
    await _writeItems(nextItems);
    items = nextItems;
    notifyListeners();
    for (final item in examples) {
      _deleteUnreferencedPhotos(
        _photoPathsForItem(item),
        retainedBy: nextItems,
      );
      unawaited(_cancelItemNotificationsSafely(item));
    }
  }

  Future<void> resetExampleData() => _serializeDataMutation(_resetExampleData);

  Future<void> _resetExampleData() async {
    _ensureWritable();
    final examples = items.where((item) => item.isSample).toList();
    final replacement = _newExampleItem(_localizations);
    final nextItems = items.where((item) => !item.isSample).toList()
      ..insert(0, replacement);
    final migrated = migrateLegacyItemLocations(
      nextItems,
      existingSpaces: spaces,
    );
    await _writeData(migrated.items, migrated.spaces);
    items = [...migrated.items];
    spaces = [...migrated.spaces];
    notifyListeners();
    for (final item in examples) {
      _deleteUnreferencedPhotos(
        _photoPathsForItem(item),
        retainedBy: nextItems,
      );
      unawaited(_cancelItemNotificationsSafely(item));
    }
    await _scheduleSafely(replacement);
  }

  Future<void> addRecord(CareItem item, MaintenanceRecord record) {
    final records = [...item.records, record]
      ..sort((a, b) => b.date.compareTo(a.date));
    final planIndex = item.plans.indexWhere((plan) => plan.id == record.planId);
    if (planIndex == -1) {
      return save(item.copyWith(records: records));
    }
    final plans = [...item.plans];
    plans[planIndex] = plans[planIndex].completedAt(record.date);
    return save(item.copyWith(records: records, plans: plans));
  }

  @override
  Future<CareItem> updateMaintenanceRecord(
    String itemId,
    MaintenanceRecord record,
  ) => _serializeDataMutation(() => _updateMaintenanceRecord(itemId, record));

  Future<CareItem> _updateMaintenanceRecord(
    String itemId,
    MaintenanceRecord record,
  ) async {
    final itemIndex = items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      throw const MaintenanceHistoryException('找不到这件物品，记录未修改。');
    }
    final current = items[itemIndex];
    final recordIndex = current.records.indexWhere(
      (candidate) => candidate.id == record.id,
    );
    if (recordIndex == -1) {
      throw const MaintenanceHistoryException('这条维护记录已不存在。');
    }
    final previousRecord = current.records[recordIndex];
    if (record.planId != previousRecord.planId) {
      throw const MaintenanceHistoryException('维护记录不能改到其他保养计划。');
    }
    final normalized = record.copyWith(
      completedAt: maintenanceDateOnly(record.completedAt),
      materialName: record.materialName.trim(),
      note: record.note.trim(),
      kind: previousRecord.kind,
    );
    _validateHistoryRecord(normalized);
    final records = [...current.records]..[recordIndex] = normalized;
    _sortMaintenanceRecords(records);
    final changed = recalculateMaintenancePlanFromRecords(
      current.copyWith(records: records),
      previousRecord.planId,
    );
    final removedPhotos = previousRecord.photos
        .where((path) => !normalized.photos.contains(path))
        .toList(growable: false);
    return _persistMaintenanceHistoryChange(
      itemIndex: itemIndex,
      previous: current,
      changed: changed,
      affectedPlanId: previousRecord.planId,
      removedPhotos: removedPhotos,
    );
  }

  @override
  Future<CareItem> deleteMaintenanceRecord(String itemId, String recordId) =>
      _serializeDataMutation(() => _deleteMaintenanceRecord(itemId, recordId));

  Future<CareItem> _deleteMaintenanceRecord(
    String itemId,
    String recordId,
  ) async {
    final itemIndex = items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      throw const MaintenanceHistoryException('找不到这件物品，记录未删除。');
    }
    final current = items[itemIndex];
    final recordIndex = current.records.indexWhere(
      (record) => record.id == recordId,
    );
    if (recordIndex == -1) {
      throw const MaintenanceHistoryException('这条维护记录已不存在。');
    }
    final removed = current.records[recordIndex];
    final records = [...current.records]..removeAt(recordIndex);
    _sortMaintenanceRecords(records);
    final changed = recalculateMaintenancePlanFromRecords(
      current.copyWith(records: records),
      removed.planId,
      fallbackDueDate: removed.plannedDueDate,
    );
    return _persistMaintenanceHistoryChange(
      itemIndex: itemIndex,
      previous: current,
      changed: changed,
      affectedPlanId: removed.planId,
      removedPhotos: removed.photos,
    );
  }

  Future<CareItem> _persistMaintenanceHistoryChange({
    required int itemIndex,
    required CareItem previous,
    required CareItem changed,
    required String? affectedPlanId,
    required Iterable<String> removedPhotos,
  }) async {
    if (_writesBlocked) {
      throw const MaintenanceHistoryException('本地档案当前为只读状态，无法修改维护记录。');
    }
    final nextItems = [...items]..[itemIndex] = changed;
    try {
      await _writeItems(nextItems);
    } catch (_) {
      throw const MaintenanceHistoryException('维护记录保存失败，原数据未改变，请重试。');
    }

    items = nextItems;
    notifyListeners();
    _deleteUnreferencedPhotos(removedPhotos, retainedBy: nextItems);
    if (affectedPlanId != null) {
      await _tryScheduleCompletion(changed, previous: previous);
    }
    return changed;
  }

  void _validateHistoryRecord(MaintenanceRecord record) {
    if (record.id.trim().isEmpty || record.id.length > 180) {
      throw const MaintenanceHistoryException('维护记录标识无效。');
    }
    if (!record.cost.isFinite || record.cost < 0) {
      throw const MaintenanceHistoryException('维护费用必须为大于或等于 0 的有限数。');
    }
    final completedAt = maintenanceDateOnly(record.completedAt);
    final today = maintenanceDateOnly(DateTime.now());
    if (completedAt.isBefore(DateTime(2000)) || completedAt.isAfter(today)) {
      throw const MaintenanceHistoryException('完成日期需在 2000 年至今天之间。');
    }
  }

  void _sortMaintenanceRecords(List<MaintenanceRecord> records) {
    records.sort((a, b) {
      final dateOrder = b.completedAt.compareTo(a.completedAt);
      if (dateOrder != 0) return dateOrder;
      return a.id.compareTo(b.id);
    });
  }

  @override
  Future<MaintenanceCompletionResult> completeMaintenance(
    MaintenanceCompletionDraft draft,
  ) {
    final operationKey = '${draft.itemId}:${draft.planId}:${draft.operationId}';
    final running = _completionOperations[operationKey];
    if (running != null) return running;
    final future = _serializeDataMutation(() => _completeMaintenance(draft));
    _completionOperations[operationKey] = future;
    future.then<void>(
      (_) {
        if (identical(_completionOperations[operationKey], future)) {
          _completionOperations.remove(operationKey);
        }
      },
      onError: (Object _, StackTrace __) {
        if (identical(_completionOperations[operationKey], future)) {
          _completionOperations.remove(operationKey);
        }
      },
    );
    return future;
  }

  Future<T> _serializeDataMutation<T>(Future<T> Function() operation) {
    final result = _dataMutationTail.then((_) => operation());
    _dataMutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<MaintenanceCompletionResult> _completeMaintenance(
    MaintenanceCompletionDraft draft,
  ) async {
    if (_writesBlocked) {
      throw const MaintenanceCompletionException('本地档案当前为只读状态，无法完成保养。');
    }
    final itemIndex = items.indexWhere((item) => item.id == draft.itemId);
    if (itemIndex == -1) {
      throw const MaintenanceCompletionException('找不到需要保养的物品。');
    }
    final current = items[itemIndex];
    final planIndex = current.plans.indexWhere(
      (plan) => plan.id == draft.planId,
    );
    if (planIndex == -1 ||
        current.plans[planIndex].archived ||
        !current.plans[planIndex].enabled) {
      throw const MaintenanceCompletionException('保养计划已不存在或已归档。');
    }
    final plan = current.plans[planIndex];
    final existingIndex = current.records.indexWhere(
      (record) => record.id == draft.recordId,
    );
    if (existingIndex != -1) {
      final notificationScheduled = await _tryScheduleCompletion(current);
      return MaintenanceCompletionResult(
        item: current,
        plan: plan,
        record: current.records[existingIndex],
        notificationScheduled: notificationScheduled,
        alreadyCompleted: true,
      );
    }

    validateMaintenanceCompletion(draft, plan);
    final completedPlan = plan.completedAt(draft.completedAt);
    final record = MaintenanceRecord(
      id: draft.recordId,
      planId: plan.id,
      completedAt: draft.completedAt,
      plannedDueDate: plan.dueDate,
      kind: plan.title,
      cost: draft.cost,
      materialName: draft.materialName.trim(),
      note: draft.note.trim(),
      completedStepIds: draft.completedStepIds,
      stepSnapshots: captureMaintenanceStepSnapshots(
        plan,
        draft.completedStepIds,
      ),
      beforePhotos: draft.beforePhotos,
      afterPhotos: draft.afterPhotos,
    );
    final plans = [...current.plans]..[planIndex] = completedPlan;
    final records = [...current.records, record]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final completedItem = current.copyWith(plans: plans, records: records);
    final nextItems = [...items]..[itemIndex] = completedItem;

    try {
      await _writeItems(nextItems);
    } catch (_) {
      throw const MaintenanceCompletionException('本次保养保存失败，数据未更新。请检查设备存储后重试。');
    }

    items = nextItems;
    notifyListeners();
    final notificationScheduled = await _tryScheduleCompletion(
      completedItem,
      previous: current,
    );
    return MaintenanceCompletionResult(
      item: completedItem,
      plan: completedPlan,
      record: record,
      notificationScheduled: notificationScheduled,
    );
  }

  Future<bool> _tryScheduleCompletion(
    CareItem item, {
    CareItem? previous,
  }) async {
    try {
      return await _serializeNotificationMutation(() async {
        if ((_notificationScheduler == null ||
                _notificationAccessResolver != null) &&
            await notificationAccess() != NotificationAccess.enabled) {
          return false;
        }
        await _scheduleItem(item, previous: previous);
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> deferPlan(
    CareItem item,
    String planId,
    DateTime deferredUntil,
  ) => _serializeDataMutation(() => _deferPlan(item.id, planId, deferredUntil));

  Future<void> _deferPlan(
    String itemId,
    String planId,
    DateTime deferredUntil,
  ) {
    final targetDate = maintenanceDateOnly(deferredUntil);
    final today = maintenanceDateOnly(DateTime.now());
    if (!targetDate.isAfter(today)) {
      throw ArgumentError.value(
        deferredUntil,
        'deferredUntil',
        'Reminder deferral must be after today',
      );
    }
    final itemIndex = items.indexWhere((entry) => entry.id == itemId);
    if (itemIndex == -1) {
      throw StateError('Cannot defer a plan for an unknown item');
    }
    final current = items[itemIndex];
    final planIndex = current.plans.indexWhere((plan) => plan.id == planId);
    if (planIndex == -1) {
      throw StateError('Cannot defer an unknown maintenance plan');
    }
    final plans = [...current.plans];
    plans[planIndex] = plans[planIndex].deferredTo(targetDate);
    return _save(current.copyWith(plans: plans));
  }

  @override
  Future<PhotoImportResult> importPhoto(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        const permission = SystemPermissionKind.camera;
        final permissionState = await _systemPermissions.ensure(permission);
        if (!permissionState.isGranted) {
          return PhotoImportResult.permissionBlocked(
            permission,
            permissionState,
          );
        }
      }
      final picked = await _imagePicker(source);
      // A null result means the user dismissed the system picker. It is not a
      // permission failure and must not show an alarming error message.
      if (picked == null) return const PhotoImportResult.cancelled();
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory('${root.path}/item-photos');
      await folder.create(recursive: true);
      final target = File(
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(picked.path).copy(target.path);
      return PhotoImportResult.success(target.path);
    } catch (_) {
      return const PhotoImportResult.failed();
    }
  }

  @override
  Future<void> discardImportedPhoto(String path) => _deletePhoto(path);

  Future<void> exportCSV(BuildContext context) async {
    final l10n = context.l10n;
    String cell(String text) => '"${text.replaceAll('"', '""')}"';
    final rows = <String>[
      [
        l10n.csvHeaderName,
        l10n.csvHeaderCategory,
        l10n.csvHeaderLocation,
        l10n.csvHeaderBrand,
        l10n.csvHeaderModel,
        l10n.csvHeaderPurchaseDate,
        l10n.csvHeaderWarrantyEnd,
        l10n.csvHeaderNextMaintenance,
        l10n.csvHeaderPurchasePrice,
        l10n.csvHeaderCurrentValue,
        l10n.csvHeaderMaintenanceRecords,
        l10n.csvHeaderTotalMaintenanceCost,
        l10n.csvHeaderNotes,
      ].map(cell).join(','),
    ];
    for (final item in items) {
      rows.add(
        [
          l10n.itemNameLabel(
            id: item.id,
            isSample: item.isSample,
            name: item.name,
          ),
          l10n.itemCategoryLabel(item.category),
          locationLabelFor(item, l10n),
          item.brand,
          item.model,
          item.purchaseDate == null ? '' : l10n.formatDate(item.purchaseDate!),
          item.warrantyDate == null ? '' : l10n.formatDate(item.warrantyDate!),
          item.nextCareDate == null ? '' : l10n.formatDate(item.nextCareDate!),
          item.purchasePrice?.toStringAsFixed(2) ?? '',
          item.currentValue?.toStringAsFixed(2) ?? '',
          item.records.length.toString(),
          item.records
              .fold<double>(0, (sum, record) => sum + record.cost)
              .toStringAsFixed(2),
          l10n.itemNotesLabel(
            id: item.id,
            isSample: item.isSample,
            notes: item.notes,
          ),
        ].map(cell).join(','),
      );
    }
    // iOS's share sheet can fail to resolve non-ASCII cache URLs on some
    // devices. Keep the temporary export in Documents with a stable ASCII
    // name; the share-sheet title remains localized for the user.
    final root = await getApplicationDocumentsDirectory();
    final exports = Directory('${root.path}/exports');
    await exports.create(recursive: true);
    final file = File('${exports.path}/laurus-export.csv');
    await file.writeAsString('\uFEFF${rows.join('\n')}');
    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], title: l10n.csvExportShareTitle),
      );
    }
  }

  Future<void> exportBackup(BuildContext context) async {
    try {
      final photoBytes = <String, List<int>>{};
      for (final path in _allPhotoPaths()) {
        final file = File(path);
        if (await file.exists()) photoBytes[path] = await file.readAsBytes();
      }
      final bytes = CareBackupCodec.encode(
        items: items,
        spaces: spaces,
        photoBytesByPath: photoBytes,
      );
      final file = File(
        '${(await getTemporaryDirectory()).path}/LAURUS-backup.zip',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], title: 'LAURUS backup'),
        );
      }
    } on CareBackupException {
      if (context.mounted) {
        AppToast.show(
          context,
          context.l10n.backupExportFailed,
          style: AppToastStyle.error,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.show(
          context,
          context.l10n.backupExportFailed,
          style: AppToastStyle.error,
        );
      }
    }
  }

  Future<bool> needsRestoreGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool('restore_backup_guide_seen') ?? false);
    } catch (_) {
      // Showing the guide again is always safer than skipping it.
      return true;
    }
  }

  Future<void> markRestoreGuideSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('restore_backup_guide_seen', true);
    } catch (_) {
      /* guide will be shown again next time */
    }
  }

  Future<bool> restoreBackup() {
    final running = _restoreOperation;
    if (running != null) return running;

    final completer = Completer<bool>();
    final future = completer.future;
    _restoreOperation = future;
    notifyListeners();
    Future<bool>.sync(_restoreBackup).then<void>(
      (value) {
        completer.complete(value);
        _finishRestoreOperation(future);
      },
      onError: (Object error, StackTrace stackTrace) {
        completer.completeError(error, stackTrace);
        _finishRestoreOperation(future);
      },
    );
    return future;
  }

  void _finishRestoreOperation(Future<bool> future) {
    if (!identical(_restoreOperation, future)) return;
    _restoreOperation = null;
    notifyListeners();
  }

  Future<bool> _restoreBackup() async {
    Directory? stagedImages;
    var restoreCommitted = false;
    try {
      final source = await _backupPicker();
      if (source == null) return false;
      final sourceFile = File(source);
      if (await sourceFile.length() > CareBackupCodec.maxArchiveBytes) {
        return false;
      }
      final backupBytes = BytesBuilder(copy: false);
      await for (final chunk in sourceFile.openRead(
        0,
        CareBackupCodec.maxArchiveBytes + 1,
      )) {
        backupBytes.add(chunk);
      }
      final decoded = CareBackupCodec.decode(backupBytes.takeBytes());
      final root = await _documentsDirectoryProvider();
      stagedImages = Directory(
        '${root.path}/item-photos/restore-${DateTime.now().microsecondsSinceEpoch}',
      );
      await stagedImages.create(recursive: true);
      final restoredPhotoPaths = <String, String>{};
      for (final entry in decoded.photos.entries) {
        final name = entry.key.substring('photos/'.length);
        final destination = File('${stagedImages.path}/$name');
        await destination.writeAsBytes(entry.value, flush: true);
        restoredPhotoPaths[entry.key] = destination.path;
      }
      var restored = decoded.items
          .map((item) => _withRestoredPhotoPaths(item, restoredPhotoPaths))
          .toList();
      _replaceLegacyExamplesIn(restored);
      _normalizeMaintenanceFactsIn(restored);
      final migratedLocations = migrateLegacyItemLocations(
        restored,
        existingSpaces: decoded.spaces,
      );
      restored = [...migratedLocations.items];
      await _deleteUnreferencedPhotosNow(
        restoredPhotoPaths.values,
        retainedBy: restored,
      );

      await _serializeDataMutation(() async {
        final previousItems = [...items];
        final previousPhotoPaths = <String>{
          for (final item in previousItems) ..._photoPathsForItem(item),
        };

        // Join the same ordered write path as every other data mutation. Only
        // publish the restored list after its complete snapshot is durable.
        await _writeData(restored, migratedLocations.spaces);
        items = restored;
        spaces = [...migratedLocations.spaces];
        loadError = null;
        _writesBlocked = false;
        restoreCommitted = true;
        notifyListeners();

        await _deleteUnreferencedPhotosNow(
          previousPhotoPaths,
          retainedBy: restored,
        );
        for (final oldItem in previousItems) {
          unawaited(_cancelItemNotificationsSafely(oldItem));
        }
        for (final item in restored) {
          unawaited(_scheduleSafely(item));
        }
      });
      return true;
    } catch (_) {
      if (restoreCommitted) return true;
      if (stagedImages != null) {
        await _deleteDirectorySafely(stagedImages);
      }
      return false;
    }
  }

  Future<NotificationAccess> notificationAccess() async {
    final override = _notificationAccessResolver;
    if (override != null) return override();
    try {
      await _ensureNotificationsReady();
      final prefs = await SharedPreferences.getInstance();
      final permissionPrompted =
          prefs.getBool('notification_permission_prompted') ?? false;
      if (Platform.isIOS) {
        final ios = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (ios == null) return NotificationAccess.unavailable;
        final permissions = await ios.checkPermissions();
        return notificationAccessFrom(
          notificationsEnabled:
              permissions?.isAlertEnabled == true ||
              permissions?.isProvisionalEnabled == true,
          permissionPrompted: permissionPrompted,
        );
      }
      if (Platform.isAndroid) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (android == null) return NotificationAccess.unavailable;
        return notificationAccessFrom(
          notificationsEnabled: await android.areNotificationsEnabled() == true,
          permissionPrompted: permissionPrompted,
        );
      }
      return NotificationAccess.unavailable;
    } catch (_) {
      return NotificationAccess.unavailable;
    }
  }

  Future<NotificationAccess> requestNotifications() async {
    try {
      final before = await notificationAccess();
      if (before == NotificationAccess.enabled) {
        _scheduleAllReminders();
        return before;
      }
      if (before == NotificationAccess.denied) return before;
      await _ensureNotificationsReady();
      final bool? granted;
      if (Platform.isIOS) {
        final ios = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (ios == null) return NotificationAccess.unavailable;
        granted = await ios.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
      } else if (Platform.isAndroid) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (android == null) return NotificationAccess.unavailable;
        granted = await android.requestNotificationsPermission();
      } else {
        return NotificationAccess.unavailable;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_permission_prompted', true);
      final after = granted == true
          ? NotificationAccess.enabled
          : NotificationAccess.denied;
      if (after == NotificationAccess.enabled) {
        _scheduleAllReminders();
      }
      return after;
    } catch (_) {
      return NotificationAccess.unavailable;
    }
  }

  void _scheduleAllReminders() {
    for (final item in items) {
      unawaited(_scheduleSafely(item));
    }
  }

  Future<void> _rescheduleRemindersIfAuthorized() async {
    if (await notificationAccess() == NotificationAccess.enabled) {
      _scheduleAllReminders();
    }
  }

  Future<void> refreshRemindersForAppResume() async {
    try {
      await _serializeDataMutation(() async {
        final nextItems = [...items];
        if (!_normalizeMaintenanceFactsIn(nextItems)) return;
        await _writeItems(nextItems);
        items = nextItems;
        notifyListeners();
      });
    } catch (_) {
      // Scheduling still ignores expired deferrals even when disk cleanup has
      // to wait for a later successful write.
    }
    await _refreshDeviceTimeZone();
    await _rescheduleRemindersIfAuthorized();
  }

  Future<bool> sendTestNotification() async {
    try {
      if (await notificationAccess() != NotificationAccess.enabled) {
        return false;
      }
      await _ensureDeviceTimeZone();
      await _notifications.zonedSchedule(
        id: 900001,
        title: _localizations.testNotificationTitle,
        body: _localizations.testNotificationBody,
        scheduledDate: tz.TZDateTime.now(
          tz.local,
        ).add(const Duration(seconds: 5)),
        notificationDetails: NotificationDetails(
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'care_reminders',
            _localizations.notificationChannelName,
            channelDescription: _localizations.notificationChannelDescription,
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist() async {
    final repository = await _openRepository();
    await repository.save(items, spaces: spaces);
  }

  Future<void> _initializeNotifications() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        handleNotificationPayload(response.payload);
      },
    );
    try {
      final launchDetails = await _notifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        handleNotificationPayload(launchDetails?.notificationResponse?.payload);
      }
    } catch (_) {
      // Live notification taps remain available even if launch details cannot
      // be read on an unsupported platform.
    }
  }

  Future<void> _schedule(CareItem item, {CareItem? previous}) async {
    await _ensureNotificationsReady();
    await _ensureDeviceTimeZone();
    // Remove the pre-CARE-002 item-level notification and every previous plan
    // id before installing the current independent plan reminders.
    await _notifications.cancel(id: item.id.hashCode);
    for (final plan in previous?.plans ?? const <MaintenancePlan>[]) {
      await _notifications.cancel(id: notificationIdForPlan(item.id, plan.id));
      await _notifications.cancel(
        id: _care002NotificationIdForPlan(item.id, plan.id),
      );
    }
    for (final plan in item.plans) {
      await _notifications.cancel(id: notificationIdForPlan(item.id, plan.id));
      await _notifications.cancel(
        id: _care002NotificationIdForPlan(item.id, plan.id),
      );
    }
    for (final plan in item.plans.where(
      (plan) => plan.enabled && !plan.archived,
    )) {
      await _schedulePlan(item, plan);
    }
  }

  Future<void> _schedulePlan(CareItem item, MaintenancePlan plan) async {
    final due = plan.dueDate;
    final reminderDate = maintenanceReminderDateForPlan(plan);
    if (due == null || reminderDate == null) return;
    final now = tz.TZDateTime.now(tz.local);
    if (!shouldScheduleMaintenanceNotification(plan, now: now)) {
      return;
    }

    final planned = tz.TZDateTime.from(
      DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 9),
      tz.local,
    );
    // Do not silently skip an item which is already in its three-day window.
    // Scheduling a few seconds later makes the reminder useful immediately.
    final scheduled = planned.isAfter(now)
        ? planned
        : now.add(const Duration(seconds: 5));
    await _notifications.zonedSchedule(
      id: notificationIdForPlan(item.id, plan.id),
      title: _localizations.maintenancePlanTitleLabel(plan.title),
      body: _localizations.maintenanceNotificationBody(
        _localizations.itemNameLabel(
          id: item.id,
          isSample: item.isSample,
          name: item.name,
        ),
        _localizations.formatDate(due),
      ),
      payload: MaintenanceNotificationPayload(
        itemId: item.id,
        planId: plan.id,
      ).encode(),
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          'care_reminders',
          _localizations.notificationChannelName,
          channelDescription: _localizations.notificationChannelDescription,
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _scheduleSafely(CareItem item, {CareItem? previous}) async {
    try {
      await _serializeNotificationMutation(() async {
        if ((_notificationScheduler == null ||
                _notificationAccessResolver != null) &&
            await notificationAccess() != NotificationAccess.enabled) {
          return;
        }
        await _scheduleItem(item, previous: previous);
      });
    } catch (_) {
      /* saving remains available offline */
    }
  }

  Future<T> _serializeNotificationMutation<T>(Future<T> Function() operation) {
    final result = _notificationMutationTail.then((_) => operation());
    _notificationMutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _scheduleItem(CareItem item, {CareItem? previous}) {
    final override = _notificationScheduler;
    return override == null
        ? _schedule(item, previous: previous)
        : override(item, previous);
  }

  Future<void> _cancelItemNotificationsSafely(CareItem item) async {
    try {
      await _serializeNotificationMutation(() async {
        await _ensureNotificationsReady();
        await _notifications.cancel(id: item.id.hashCode);
        for (final plan in item.plans) {
          await _notifications.cancel(
            id: notificationIdForPlan(item.id, plan.id),
          );
          await _notifications.cancel(
            id: _care002NotificationIdForPlan(item.id, plan.id),
          );
        }
      });
    } catch (_) {
      /* notification state never blocks item changes */
    }
  }

  Iterable<String> _allPhotoPaths() sync* {
    final seen = <String>{};
    for (final item in items) {
      for (final path in item.photos) {
        if (seen.add(path)) yield path;
      }
      for (final record in item.records) {
        for (final path in record.photos) {
          if (seen.add(path)) yield path;
        }
      }
    }
  }

  Iterable<String> _photoPathsForItem(CareItem item) sync* {
    yield* item.photos;
    for (final record in item.records) {
      yield* record.photos;
    }
  }

  void _deleteUnreferencedPhotos(
    Iterable<String> candidates, {
    required Iterable<CareItem> retainedBy,
  }) {
    final retainedPhotoPaths = <String>{
      for (final item in retainedBy) ..._photoPathsForItem(item),
    };
    for (final path in candidates.toSet()) {
      if (!retainedPhotoPaths.contains(path)) {
        unawaited(_deletePhoto(path));
      }
    }
  }

  Future<void> _deleteUnreferencedPhotosNow(
    Iterable<String> candidates, {
    required Iterable<CareItem> retainedBy,
  }) async {
    final retainedPhotoPaths = <String>{
      for (final item in retainedBy) ..._photoPathsForItem(item),
    };
    final emptyDirectoryCandidates = <String>{};
    for (final path in candidates.toSet()) {
      if (retainedPhotoPaths.contains(path)) continue;
      emptyDirectoryCandidates.add(File(path).parent.path);
      await _deletePhoto(path);
    }
    for (final path in emptyDirectoryCandidates) {
      final directory = Directory(path);
      final normalized = path.replaceAll('\\', '/');
      if (!normalized.split('/').last.startsWith('restore-')) continue;
      try {
        if (await directory.exists() &&
            await directory.list(followLinks: false).isEmpty) {
          await directory.delete();
        }
      } catch (_) {
        /* best-effort cleanup after a durable restore */
      }
    }
  }

  Future<void> _deleteDirectorySafely(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      /* a failed cleanup must not hide the restore result */
    }
  }

  CareItem _withRestoredPhotoPaths(
    CareItem item,
    Map<String, String> restoredPhotoPaths,
  ) => item.copyWith(
    photos: item.photos
        .where(restoredPhotoPaths.containsKey)
        .map((path) => restoredPhotoPaths[path]!)
        .toList(growable: false),
    records: item.records
        .map(
          (record) => record.copyWith(
            beforePhotos: record.beforePhotos
                .where(restoredPhotoPaths.containsKey)
                .map((path) => restoredPhotoPaths[path]!)
                .toList(growable: false),
            afterPhotos: record.afterPhotos
                .where(restoredPhotoPaths.containsKey)
                .map((path) => restoredPhotoPaths[path]!)
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
  );

  bool _replaceLegacyExamples() => _replaceLegacyExamplesIn(items);

  bool _normalizeMaintenanceFactsIn(List<CareItem> target) {
    var changed = false;
    final today = maintenanceDateOnly(DateTime.now());
    for (var index = 0; index < target.length; index++) {
      var item = freezeMaintenanceHistorySnapshots(target[index]);
      final plans = item.plans
          .map(
            (plan) => enrichMaintenanceTemplateStepDescriptions(
              clearExpiredMaintenanceDeferral(plan, now: today),
            ),
          )
          .toList(growable: false);
      final plansChanged = List.generate(
        plans.length,
        (planIndex) => !identical(plans[planIndex], item.plans[planIndex]),
      ).any((value) => value);
      if (plansChanged) item = item.copyWith(plans: plans);
      if (!identical(item, target[index])) {
        target[index] = item;
        changed = true;
      }
    }
    return changed;
  }

  bool _replaceLegacyExamplesIn(List<CareItem> target) {
    final firstLegacyIndex = target.indexWhere(_shouldReplaceLegacyExample);
    if (firstLegacyIndex == -1) return false;
    final hasPreservedExample = target.any(
      (item) =>
          item.id == _exampleItemId &&
          item.isSample &&
          !_shouldReplaceLegacyExample(item),
    );
    target.removeWhere(_shouldReplaceLegacyExample);
    final insertIndex = firstLegacyIndex > target.length
        ? target.length
        : firstLegacyIndex;
    if (!hasPreservedExample) {
      target.insert(insertIndex, _newExampleItem(_localizations));
    }
    return true;
  }

  static bool _shouldReplaceLegacyExample(CareItem item) {
    if (item.id == 'sample-ac') return true;
    if (item.id != _exampleItemId) return false;
    if (!item.isSample) return true;
    if (item.records.isNotEmpty) return false;
    return !item.plans.any((plan) => plan.id == _examplePlanId);
  }

  static CareItem _newExampleItem(AppLocalizations localizations) {
    final today = maintenanceDateOnly(DateTime.now());
    final template = maintenanceTemplates.firstWhere(
      (candidate) => candidate.id == 'water-purifier-filter',
    );
    final localizedTemplate = localizations.localizedTemplate(template);
    return CareItem(
      id: _exampleItemId,
      name: localizations.sampleItemName,
      category: canonicalItemCategory(localizations.categoryFiltersConsumables),
      location: localizations.spaceTypeKitchen,
      brand: '',
      model: '',
      notes: localizations.sampleItemNotes,
      photos: const [],
      plans: [
        localizedTemplate.createPlan(
          planId: _examplePlanId,
          referenceDate: addMaintenanceDays(today, -template.intervalDays),
        ),
      ],
      isSample: true,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.store});

  final CareStore? store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final CareStore store;
  late final bool _ownsStore;
  bool _notificationNavigationScheduled = false;
  bool _notificationNavigationInFlight = false;
  int tab = 0;
  InventoryLanding _inventoryLanding = InventoryLanding.allItems;
  int _inventoryNavigationVersion = 0;
  MaintenanceReportScope _reportScope =
      MaintenanceReportScope.trailingTwelveMonths;
  int _reportNavigationVersion = 0;

  @override
  void initState() {
    super.initState();
    store = widget.store ?? CareStore();
    _ownsStore = widget.store == null;
    WidgetsBinding.instance.addObserver(this);
    if (!store.loaded) unawaited(store.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(store.refreshRemindersForAppResume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsStore) store.dispose();
    super.dispose();
  }

  void _scheduleNotificationNavigation() {
    if (!store.loaded ||
        !store.hasPendingNotificationNavigation ||
        _notificationNavigationScheduled ||
        _notificationNavigationInFlight) {
      return;
    }
    _notificationNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationNavigationScheduled = false;
      unawaited(_openPendingNotification());
    });
  }

  Future<void> _openPendingNotification() async {
    if (!mounted || _notificationNavigationInFlight) return;
    final resolution = store.takeNotificationNavigation();
    if (resolution == null) return;
    _notificationNavigationInFlight = true;
    try {
      final task = resolution.task;
      if (resolution.type == MaintenanceNotificationResolutionType.ready &&
          task != null) {
        await _startMaintenanceTask(context, store, task);
        return;
      }
      setState(() => tab = 2);
      final message = switch (resolution.type) {
        MaintenanceNotificationResolutionType.itemUnavailable =>
          context.l10n.notificationItemUnavailable,
        MaintenanceNotificationResolutionType.planUnavailable =>
          context.l10n.notificationPlanUnavailable,
        MaintenanceNotificationResolutionType.malformed =>
          context.l10n.notificationMalformed,
        MaintenanceNotificationResolutionType.ready => '',
      };
      AppToast.show(context, message);
    } finally {
      _notificationNavigationInFlight = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      store.updateLocalizations(context.l10n);
      if (!store.loaded) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(key: Key('care-data-loading')),
          ),
        );
      }
      _scheduleNotificationNavigation();
      void openItemEditor() {
        Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => EditorPage(store: store)),
        );
      }

      void openItemById(String itemId) {
        CareItem? item;
        for (final candidate in store.items) {
          if (candidate.id == itemId) {
            item = candidate;
            break;
          }
        }
        if (item == null) return;
        final selectedItem = item;
        Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(store: store, item: selectedItem),
          ),
        );
      }

      void openInventory(InventoryLanding landing) {
        setState(() {
          _inventoryLanding = landing;
          _inventoryNavigationVersion++;
          tab = 1;
        });
      }

      void openCurrentYearReport() {
        setState(() {
          _reportScope = MaintenanceReportScope.currentYear;
          _reportNavigationVersion++;
          tab = 3;
        });
      }

      void openSpaces() {
        Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => SpacePage(store: store)),
        );
      }

      final pages = [
        Dashboard(
          store: store,
          onAdd: openItemEditor,
          onOpenSchedule: () => setState(() => tab = 2),
          onOpenItems: () => openInventory(InventoryLanding.allItems),
          onOpenSpaces: openSpaces,
          onOpenAnnualCost: openCurrentYearReport,
          onOpenAssets: () => openInventory(InventoryLanding.assets),
        ),
        InventoryPage(
          store: store,
          onAdd: openItemEditor,
          initialLanding: _inventoryLanding,
          navigationVersion: _inventoryNavigationVersion,
        ),
        SchedulePage(store: store),
        MaintenanceReportPage(
          items: store.items,
          initialScope: _reportScope,
          navigationVersion: _reportNavigationVersion,
          onOpenItem: openItemById,
        ),
        SettingsPage(store: store),
      ];
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (store.loadError != null)
                MaterialBanner(
                  content: Text(context.l10n.archiveLoadFailed),
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: context.palette.warning,
                  ),
                  actions: [
                    TextButton(
                      onPressed: store.dismissLoadError,
                      child: Text(context.l10n.gotIt),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(index: tab, children: pages),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomDock(
          selected: tab,
          onSelect: (v) => setState(() => tab = v),
        ),
      );
    },
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.store,
    this.onAdd,
    this.onOpenSchedule,
    this.onOpenItems,
    this.onOpenSpaces,
    this.onOpenAnnualCost,
    this.onOpenAssets,
    this.now,
  });

  final CareStore store;
  final VoidCallback? onAdd;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenItems;
  final VoidCallback? onOpenSpaces;
  final VoidCallback? onOpenAnnualCost;
  final VoidCallback? onOpenAssets;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = maintenanceDateOnly(now ?? DateTime.now());
    final year = today.year;
    final annualCost = store.items
        .expand((item) => item.records)
        .where((record) => record.date.year == year)
        .fold<double>(0, (sum, record) => sum + record.cost);
    final assetValue = store.items.fold<double>(
      0,
      (sum, item) => sum + (item.currentValue ?? item.purchasePrice ?? 0),
    );
    final tasks = maintenanceTasksForItems(store.items, now: today);
    final attentionCount = tasks
        .where(
          (task) =>
              task.status.dueState == MaintenanceTaskState.overdue ||
              task.status.dueState == MaintenanceTaskState.dueToday ||
              task.status.dueState == MaintenanceTaskState.dueSoon,
        )
        .length;
    final nextTask = tasks.isEmpty ? null : tasks.first;

    void openAddFlow() {
      if (onAdd != null) {
        onAdd!();
        return;
      }
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => EditorPage(store: store)),
      );
    }

    return CustomScrollView(
      key: const PageStorageKey('dashboard-scroll'),
      cacheExtent: 0,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          sliver: SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DashboardHeader(today: today, onAdd: openAddFlow),
                  const SizedBox(height: 12),
                  _DashboardTodayHero(
                    attentionCount: attentionCount,
                    onOpenSchedule: onOpenSchedule,
                  ),
                  const SizedBox(height: 20),
                  _DashboardSectionTitle(
                    title: context.l10n.dashboardNextMaintenance,
                  ),
                  const SizedBox(height: 4),
                  if (nextTask == null)
                    MaintenanceTaskEmptyState(onCreate: openAddFlow)
                  else
                    _DashboardNextTask(
                      task: nextTask,
                      onStart: () =>
                          _startMaintenanceTask(context, store, nextTask),
                      onDefer: () =>
                          _deferMaintenanceTask(context, store, nextTask),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.dashboardHouseholdOverview,
                    style: TextStyle(
                      color: context.palette.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DashboardHouseholdOverview(
                    itemCount: store.items.length,
                    roomCount: store.spaces.length,
                    annualCost: annualCost,
                    assetValue: assetValue,
                    onOpenItems: onOpenItems,
                    onOpenSpaces: onOpenSpaces,
                    onOpenAnnualCost: onOpenAnnualCost,
                    onOpenAssets: onOpenAssets,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.today, required this.onAdd});

  final DateTime today;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboardTitle,
              style: TextStyle(
                color: context.palette.ink,
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _dashboardDate(context, today),
              style: TextStyle(
                color: context.palette.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
      Semantics(
        button: true,
        label: context.l10n.addItem,
        child: Material(
          color: context.palette.mist,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('dashboard-add-item'),
            onTap: onAdd,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.add_rounded,
                color: context.palette.primary,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _DashboardTodayHero extends StatelessWidget {
  const _DashboardTodayHero({
    required this.attentionCount,
    required this.onOpenSchedule,
  });

  final int attentionCount;
  final VoidCallback? onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final title = attentionCount == 0
        ? context.l10n.dashboardNoDueTasks
        : context.l10n.dashboardAttentionCount(attentionCount);
    final subtitle = attentionCount == 0
        ? context.l10n.dashboardAllOnTrack
        : context.l10n.dashboardStartWithUrgent;
    return Container(
      key: const Key('dashboard-today-hero'),
      width: double.infinity,
      height: 172,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.palette.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -16,
            width: 218,
            height: 164,
            child: ExcludeSemantics(
              child: Opacity(
                opacity: .22,
                child: Image.asset(
                  'assets/home/dashboard-room-line.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                  color: context.palette.mist,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: context.palette.softSurface,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.dashboardToday,
                        style: TextStyle(
                          color: context.palette.softSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.onPrimary,
                        fontSize: 25,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.palette.mist, fontSize: 14),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('dashboard-open-schedule'),
                    onPressed: onOpenSchedule,
                    style: TextButton.styleFrom(
                      foregroundColor: context.palette.onPrimary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    label: Text(
                      context.l10n.dashboardViewSchedule,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: context.palette.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.2,
        ),
      ),
      const SizedBox(height: 10),
      Divider(height: 1, color: context.palette.border),
    ],
  );
}

class _DashboardNextTask extends StatelessWidget {
  const _DashboardNextTask({
    required this.task,
    required this.onStart,
    required this.onDefer,
  });

  final MaintenanceTask task;
  final VoidCallback onStart;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    final status = task.status;
    final tone = _dashboardTaskTone(context, status.dueState);
    return Container(
      key: ValueKey('maintenance-task-${task.item.id}-${task.plan.id}'),
      constraints: const BoxConstraints(minHeight: 206),
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 5,
            bottom: 7,
            child: SizedBox(
              width: 10,
              child: Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: context.palette.border,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.palette.handle,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 31),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dashboardTaskTiming(context, status),
                  style: TextStyle(
                    color: tone,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: context.palette.mist,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _dashboardTaskIcon(context, task),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _itemDisplayName(context, task.item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.palette.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.l10n.maintenancePlanTitleLabel(
                              task.plan.title,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.palette.muted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                color: context.palette.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  status.hasActiveDeferral
                                      ? context.l10n.dashboardOriginalDueDate(
                                          _localizedDate(context, task.dueDate),
                                        )
                                      : _localizedDate(context, task.dueDate),
                                  key: ValueKey(
                                    'maintenance-task-due-${task.id}',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.palette.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (status.hasActiveDeferral) ...[
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.dashboardDeferredStatus(
                                _localizedDate(context, status.deferredUntil),
                                context.l10n.maintenanceStateLabel(
                                  status.dueState,
                                ),
                              ),
                              key: ValueKey(
                                'maintenance-task-deferral-${task.id}',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.mist,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              context.l10n.maintenanceStateLabel(status.state),
                              style: TextStyle(
                                color: context.palette.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton.icon(
                        key: ValueKey('start-maintenance-task-${task.id}'),
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(context.l10n.startMaintenance),
                      ),
                      const SizedBox(height: 1),
                      TextButton(
                        key: ValueKey('defer-maintenance-task-${task.id}'),
                        onPressed: onDefer,
                        style: TextButton.styleFrom(
                          foregroundColor: context.palette.primary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          status.hasActiveDeferral
                              ? context.l10n.editDeferredReminder
                              : context.l10n.deferReminder,
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
    );
  }
}

class _DashboardHouseholdOverview extends StatelessWidget {
  const _DashboardHouseholdOverview({
    required this.itemCount,
    required this.roomCount,
    required this.annualCost,
    required this.assetValue,
    this.onOpenItems,
    this.onOpenSpaces,
    this.onOpenAnnualCost,
    this.onOpenAssets,
  });

  final int itemCount;
  final int roomCount;
  final double annualCost;
  final double assetValue;
  final VoidCallback? onOpenItems;
  final VoidCallback? onOpenSpaces;
  final VoidCallback? onOpenAnnualCost;
  final VoidCallback? onOpenAssets;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final facts = [
      _DashboardFact(
        key: const Key('dashboard-fact-items'),
        icon: Icons.inventory_2_outlined,
        label: context.l10n.dashboardItems,
        value: '$itemCount',
        semanticsLabel: context.l10n.dashboardItemsSemantic(itemCount),
        onTap: onOpenItems,
      ),
      _DashboardFact(
        key: const Key('dashboard-fact-spaces'),
        icon: Icons.chair_outlined,
        label: context.l10n.dashboardSpaces,
        value: '$roomCount',
        semanticsLabel: context.l10n.dashboardSpacesSemantic(roomCount),
        onTap: onOpenSpaces,
      ),
      _DashboardFact(
        key: const Key('dashboard-fact-annual-cost'),
        icon: Icons.paid_outlined,
        label: context.l10n.dashboardThisYearMaintenance,
        value: '¥${annualCost.toStringAsFixed(0)}',
        semanticsLabel: context.l10n.dashboardAnnualCostSemantic(
          annualCost.toStringAsFixed(0),
        ),
        onTap: onOpenAnnualCost,
      ),
      _DashboardFact(
        key: const Key('dashboard-fact-assets'),
        icon: Icons.home_outlined,
        label: context.l10n.dashboardAssets,
        value: '¥${assetValue.toStringAsFixed(0)}',
        semanticsLabel: context.l10n.dashboardAssetsSemantic(
          assetValue.toStringAsFixed(0),
        ),
        onTap: onOpenAssets,
      ),
    ];
    Widget factRow(int start) => Row(
      children: [
        Expanded(child: facts[start]),
        const _DashboardFactDivider(),
        Expanded(child: facts[start + 1]),
      ],
    );
    return Container(
      key: const Key('dashboard-household-overview'),
      constraints: BoxConstraints(minHeight: largeText ? 178 : 96),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      decoration: BoxDecoration(
        color: context.palette.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.border),
      ),
      child: largeText
          ? Column(
              children: [
                factRow(0),
                Divider(height: 1, color: context.palette.divider),
                factRow(2),
              ],
            )
          : Row(
              children: [
                for (var index = 0; index < facts.length; index++) ...[
                  Expanded(child: facts[index]),
                  if (index != facts.length - 1) const _DashboardFactDivider(),
                ],
              ],
            ),
    );
  }
}

class _DashboardFact extends StatelessWidget {
  const _DashboardFact({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.semanticsLabel,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: context.palette.muted, size: 20),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.palette.muted, fontSize: 10),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    color: context.palette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Icon(
                Icons.chevron_right_rounded,
                color: context.palette.muted,
                size: 13,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashboardFactDivider extends StatelessWidget {
  const _DashboardFactDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: VerticalDivider(width: 1, color: context.palette.divider),
  );
}

String _dashboardDate(BuildContext context, DateTime value) {
  final weekdays = [
    context.l10n.weekdayMonday,
    context.l10n.weekdayTuesday,
    context.l10n.weekdayWednesday,
    context.l10n.weekdayThursday,
    context.l10n.weekdayFriday,
    context.l10n.weekdaySaturday,
    context.l10n.weekdaySunday,
  ];
  return context.l10n.dashboardDate(
    context.l10n.dateMonthDay(value.month, value.day),
    weekdays[value.weekday - 1],
  );
}

String _dashboardTaskTiming(
  BuildContext context,
  MaintenancePlanStatus status,
) {
  final days = status.daysUntilDue;
  if (days == null) return context.l10n.dashboardTimingDateUnset;
  if (days < 0) return context.l10n.dashboardTimingOverdue(-days);
  if (days == 0) return context.l10n.dashboardTimingDueToday;
  return context.l10n.dashboardTimingDueInDays(days);
}

Color _dashboardTaskTone(BuildContext context, MaintenanceTaskState state) =>
    switch (state) {
      MaintenanceTaskState.overdue => context.palette.danger,
      MaintenanceTaskState.dueToday => context.palette.warning,
      MaintenanceTaskState.dueSoon => context.palette.accent,
      MaintenanceTaskState.deferred => context.palette.deferred,
      MaintenanceTaskState.planned => context.palette.accent,
      MaintenanceTaskState.completed => context.palette.success,
      MaintenanceTaskState.disabled => context.palette.muted,
    };

Widget _dashboardTaskIcon(BuildContext context, MaintenanceTask task) {
  final searchable = '${task.item.name}${task.item.category}${task.plan.title}';
  if (searchable.contains('净水') ||
      searchable.contains('滤芯') ||
      searchable.toLowerCase().contains('water purifier') ||
      searchable.toLowerCase().contains('filter')) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Image.asset(
        'assets/home/dashboard-purifier-icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
  return Icon(
    Icons.home_repair_service_outlined,
    color: context.palette.primary,
    size: 27,
  );
}

class MaintenanceTaskEmptyState extends StatelessWidget {
  const MaintenanceTaskEmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('dashboard-empty-maintenance-state'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      color: context.palette.paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.palette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: context.palette.mist,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      Icons.calendar_month_outlined,
                      size: 27,
                      color: context.palette.primary,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 7,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: context.palette.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.emptyMaintenanceTitle,
                    style: TextStyle(
                      color: context.palette.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.emptyMaintenanceSubtitle,
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('create-first-maintenance-plan'),
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: Text(
              context.l10n.createMaintenancePlan,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

enum InventoryLanding { allItems, assets }

class SpacePage extends StatelessWidget {
  const SpacePage({super.key, required this.store});

  final CareStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final unassigned = store.itemsInSpace(null);
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: Text(context.l10n.spacesTitle),
          leading: AppBackButton(onPressed: () => Navigator.pop(context)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: IconButton.filledTonal(
                key: const Key('add-space'),
                tooltip: context.l10n.addSpace,
                onPressed: () => _openSpaceEditor(context, store),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
        body: store.spaces.isEmpty && unassigned.isEmpty
            ? _SpaceEmptyState(onAdd: () => _openSpaceEditor(context, store))
            : ListView(
                key: const PageStorageKey('space-list'),
                padding: appSafeScrollPadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                    child: Text(
                      context.l10n.spacesDescription,
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                  for (final space in store.spaces) ...[
                    _SpaceCard(
                      space: space,
                      itemCount: store.itemsInSpace(space.id).length,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SpaceDetailPage(store: store, spaceId: space.id),
                        ),
                      ),
                      onEdit: () =>
                          _openSpaceEditor(context, store, existing: space),
                      onDelete: () => _deleteSpace(context, store, space),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (unassigned.isNotEmpty)
                    _SpaceCard(
                      key: const Key('unassigned-space'),
                      itemCount: unassigned.length,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SpaceDetailPage.unassigned(store: store),
                        ),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

class _SpaceEmptyState extends StatelessWidget {
  const _SpaceEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.palette.mist,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chair_outlined,
              color: context.palette.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.spacesEmptyTitle,
            style: TextStyle(
              color: context.palette.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            context.l10n.spacesEmptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('add-first-space'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.addSpace),
          ),
        ],
      ),
    ),
  );
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({
    super.key,
    this.space,
    required this.itemCount,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final CareSpace? space;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = space == null
        ? context.l10n.unassignedSpace
        : context.l10n.spaceNameLabel(space!);
    final type = space == null
        ? context.l10n.awaitingClassification
        : context.l10n.spaceTypeLabel(space!.type);
    return Material(
      key: space == null ? null : ValueKey('space-${space!.id}'),
      color: context.palette.paper,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: context.palette.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: context.palette.mist,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  _iconForSpaceType(space?.type),
                  color: context.palette.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: context.palette.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.spaceItemCount(type, itemCount),
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (space != null)
                PopupMenuButton<String>(
                  tooltip: context.l10n.manageSpace,
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.l10n.renameSpace),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.deleteSpace),
                    ),
                  ],
                )
              else
                Icon(Icons.chevron_right_rounded, color: context.palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class SpaceDetailPage extends StatelessWidget {
  const SpaceDetailPage({super.key, required this.store, required this.spaceId})
    : unassigned = false;

  const SpaceDetailPage.unassigned({super.key, required this.store})
    : spaceId = null,
      unassigned = true;

  final CareStore store;
  final String? spaceId;
  final bool unassigned;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final space = store.spaceById(spaceId);
      final title = unassigned
          ? context.l10n.unassignedSpace
          : space == null
          ? context.l10n.spaceDeleted
          : context.l10n.spaceNameLabel(space);
      final items = store.itemsInSpace(unassigned ? null : spaceId);
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: Text(title),
          leading: AppBackButton(onPressed: () => Navigator.pop(context)),
          actions: [
            if (unassigned || space != null)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: IconButton.filledTonal(
                  key: const Key('add-item-from-space'),
                  tooltip: context.l10n.addItemToSpace,
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditorPage(
                        store: store,
                        initialSpaceId: unassigned ? null : spaceId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
          ],
        ),
        body: items.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  text: unassigned
                      ? context.l10n.noUnassignedItems
                      : context.l10n.spaceHasNoItems,
                ),
              )
            : ListView.separated(
                key: const PageStorageKey('space-item-list'),
                padding: appSafeScrollPadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return BreezeSurface(
                    padding: EdgeInsets.zero,
                    radius: 20,
                    child: ItemCard(
                      key: ValueKey('space-item-${item.id}'),
                      item: item,
                      locationLabel: store.locationLabelFor(item, context.l10n),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPage(store: store, item: item),
                        ),
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}

class AddSpacePage extends StatefulWidget {
  const AddSpacePage({super.key, required this.store, this.existing});

  final CareStore store;
  final CareSpace? existing;

  @override
  State<AddSpacePage> createState() => _AddSpacePageState();
}

class _AddSpacePageState extends State<AddSpacePage> {
  late String type = widget.existing?.type ?? careSpaceTypeTemplates.first;
  late final TextEditingController name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  bool saving = false;
  bool _defaultNameInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultNameInitialized) return;
    final existing = widget.existing;
    if (existing == null || careSpaceUsesDefaultName(existing)) {
      name.text = context.l10n.spaceTypeLabel(type);
    }
    _defaultNameInitialized = true;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 72,
      title: Text(
        widget.existing == null
            ? context.l10n.addSpace
            : context.l10n.editSpace,
      ),
      leading: AppBackButton(onPressed: () => Navigator.pop(context)),
    ),
    body: ListView(
      padding: appSafeScrollPadding(context, const EdgeInsets.all(20)),
      children: [
        Text(
          context.l10n.spaceType,
          style: TextStyle(
            color: context.palette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final option in careSpaceTypeTemplates)
              ChoiceChip(
                key: ValueKey('space-type-$option'),
                label: Text(context.l10n.spaceTypeLabel(option)),
                avatar: Icon(_iconForSpaceType(option), size: 18),
                selected: type == option,
                onSelected: (_) => setState(() {
                  final oldType = type;
                  type = option;
                  if (name.text.trim().isEmpty ||
                      name.text.trim() == oldType ||
                      name.text.trim() ==
                          context.l10n.spaceTypeLabel(oldType)) {
                    name.text = context.l10n.spaceTypeLabel(option);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('space-name'),
          controller: name,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: context.l10n.spaceActualName,
            hintText: context.l10n.spaceNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.spaceNameHelper,
          style: TextStyle(color: context.palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('save-space'),
          onPressed: saving ? null : _save,
          child: Text(
            widget.existing == null
                ? context.l10n.addSpace
                : context.l10n.saveChanges,
          ),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    final normalized = name.text.trim();
    if (normalized.isEmpty || saving) {
      if (normalized.isEmpty) {
        AppToast.show(
          context,
          context.l10n.spaceNameRequired,
          style: AppToastStyle.error,
        );
      }
      return;
    }
    setState(() => saving = true);
    try {
      final saved = await widget.store.saveSpace(
        CareSpace(
          id:
              widget.existing?.id ??
              'space-${DateTime.now().microsecondsSinceEpoch}',
          type: type,
          name: normalized,
        ),
      );
      if (mounted) Navigator.pop(context, saved);
    } on DuplicateSpaceNameException {
      if (mounted) {
        AppToast.show(context, context.l10n.spaceNameAlreadyExists);
        setState(() => saving = false);
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.spaceSaveFailed,
          style: AppToastStyle.error,
        );
        setState(() => saving = false);
      }
    }
  }
}

const _unassignedSpaceSelection = '__unassigned__';

class SelectSpacePage extends StatelessWidget {
  const SelectSpacePage({super.key, required this.store, this.selectedSpaceId});

  final CareStore store;
  final String? selectedSpaceId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(context.l10n.selectSpace),
        leading: AppBackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton.filledTonal(
              key: const Key('add-space-from-selector'),
              tooltip: context.l10n.addSpace,
              onPressed: () async {
                final created = await _openSpaceEditor(context, store);
                if (created != null && context.mounted) {
                  Navigator.pop(context, created.id);
                }
              },
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: appSafeScrollPadding(context, const EdgeInsets.all(16)),
        children: [
          _SpaceSelectionTile(
            key: const Key('select-unassigned-space'),
            icon: Icons.not_listed_location_outlined,
            name: context.l10n.unassignedSpace,
            subtitle: context.l10n.organizeLater,
            selected: selectedSpaceId == null,
            onTap: () => Navigator.pop(context, _unassignedSpaceSelection),
          ),
          const SizedBox(height: 8),
          for (final space in store.spaces) ...[
            _SpaceSelectionTile(
              key: ValueKey('select-space-${space.id}'),
              icon: _iconForSpaceType(space.type),
              name: context.l10n.spaceNameLabel(space),
              subtitle: context.l10n.spaceItemCount(
                context.l10n.spaceTypeLabel(space.type),
                store.itemsInSpace(space.id).length,
              ),
              selected: selectedSpaceId == space.id,
              onTap: () => Navigator.pop(context, space.id),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}

class _SpaceSelectionTile extends StatelessWidget {
  const _SpaceSelectionTile({
    super.key,
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.palette.mist : context.palette.paper,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? context.palette.primary : context.palette.border,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: context.palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.palette.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: context.palette.primary)
            else
              Icon(Icons.chevron_right_rounded, color: context.palette.muted),
          ],
        ),
      ),
    ),
  );
}

Future<CareSpace?> _openSpaceEditor(
  BuildContext context,
  CareStore store, {
  CareSpace? existing,
}) => Navigator.push<CareSpace>(
  context,
  MaterialPageRoute(
    builder: (_) => AddSpacePage(store: store, existing: existing),
  ),
);

Future<void> _deleteSpace(
  BuildContext context,
  CareStore store,
  CareSpace space,
) async {
  final affected = store.itemsInSpace(space.id);
  final spaceName = context.l10n.spaceNameLabel(space);
  String? replacement;
  if (affected.isEmpty) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteSpaceTitle),
        content: Text(context.l10n.deleteEmptySpaceMessage(spaceName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  } else {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.l10n.relocateSpaceItemsTitle(affected.length),
                style: TextStyle(
                  color: sheetContext.palette.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                sheetContext.l10n.relocateSpaceItemsMessage(spaceName),
                style: TextStyle(
                  color: sheetContext.palette.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.not_listed_location_outlined),
                title: Text(sheetContext.l10n.setUnassignedSpace),
                onTap: () =>
                    Navigator.pop(sheetContext, _unassignedSpaceSelection),
              ),
              for (final target in store.spaces.where(
                (entry) => entry.id != space.id,
              ))
                ListTile(
                  leading: Icon(_iconForSpaceType(target.type)),
                  title: Text(
                    sheetContext.l10n.moveToSpace(
                      sheetContext.l10n.spaceNameLabel(target),
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, target.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    replacement = selected == _unassignedSpaceSelection ? null : selected;
  }
  try {
    await store.removeSpace(space.id, replacementSpaceId: replacement);
  } catch (_) {
    if (context.mounted) {
      AppToast.show(
        context,
        context.l10n.spaceDeleteFailed,
        style: AppToastStyle.error,
      );
    }
  }
}

IconData _iconForSpaceType(String? type) => switch (type) {
  '客厅' => Icons.chair_outlined,
  '卧室' => Icons.bed_outlined,
  '厨房' => Icons.kitchen_outlined,
  '卫生间' => Icons.bathtub_outlined,
  '阳台' => Icons.deck_outlined,
  '书房' => Icons.menu_book_outlined,
  '餐厅' => Icons.dining_outlined,
  '储物间' => Icons.inventory_2_outlined,
  '玄关' => Icons.door_front_door_outlined,
  _ => Icons.home_work_outlined,
};

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.store,
    required this.onAdd,
    this.initialLanding = InventoryLanding.allItems,
    this.navigationVersion = 0,
  });

  final CareStore store;
  final VoidCallback onAdd;
  final InventoryLanding initialLanding;
  final int navigationVersion;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

enum _InventoryFilter { all, planned, needsSetup }

enum _InventorySort { name, nextCareDate }

class _InventoryPageState extends State<InventoryPage> {
  final searchController = TextEditingController();
  String query = '';
  _InventoryFilter filter = _InventoryFilter.all;
  _InventorySort sort = _InventorySort.name;
  late InventoryLanding landing = widget.initialLanding;

  bool _hasPlan(CareItem item) => item.nextCareDate != null;

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationVersion != widget.navigationVersion) {
      landing = widget.initialLanding;
      if (landing == InventoryLanding.allItems) _resetToAllItems();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (landing == InventoryLanding.assets) {
      return _AssetValuationView(
        store: widget.store,
        onShowItems: () => setState(() {
          landing = InventoryLanding.allItems;
          _resetToAllItems();
        }),
      );
    }
    final plannedCount = widget.store.items.where(_hasPlan).length;
    final needsSetupCount = widget.store.items.length - plannedCount;
    final filtered =
        widget.store.items
            .where(
              (item) =>
                  (item.name.contains(query) ||
                      _itemDisplayName(context, item).contains(query) ||
                      widget.store.locationLabelFor(item).contains(query) ||
                      item.category.contains(query) ||
                      context.l10n
                          .itemCategoryLabel(item.category)
                          .toLowerCase()
                          .contains(query.toLowerCase())) &&
                  switch (filter) {
                    _InventoryFilter.all => true,
                    _InventoryFilter.planned => _hasPlan(item),
                    _InventoryFilter.needsSetup => !_hasPlan(item),
                  },
            )
            .toList()
          ..sort(_compareItems);

    return Column(
      children: [
        _InventoryHeader(onAdd: widget.onAdd),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 56,
            child: TextField(
              key: const Key('inventory-search'),
              controller: searchController,
              onChanged: (value) => setState(() => query = value.trim()),
              style: TextStyle(color: context.palette.ink, fontSize: 16),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.palette.primary,
                  size: 25,
                ),
                hintText: context.l10n.inventorySearchHint,
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('inventory-clear-search'),
                        tooltip: context.l10n.clearSearch,
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        icon: Icon(
                          Icons.cancel_rounded,
                          color: context.palette.muted,
                          size: 19,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _InventoryFilterBar(
            selected: filter,
            totalCount: widget.store.items.length,
            plannedCount: plannedCount,
            needsSetupCount: needsSetupCount,
            onSelected: (value) => setState(() => filter = value),
          ),
        ),
        const SizedBox(height: 17),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  switch (filter) {
                    _InventoryFilter.all => context.l10n.inventoryAllItems,
                    _InventoryFilter.planned =>
                      context.l10n.inventoryPlannedItems,
                    _InventoryFilter.needsSetup =>
                      context.l10n.inventoryNeedsSetupItems,
                  },
                  style: TextStyle(
                    color: context.palette.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              _InventorySortButton(
                label: sort == _InventorySort.name
                    ? context.l10n.sortByName
                    : context.l10n.sortByTime,
                onTap: _selectSort,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.palette.paper,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.palette.border),
              ),
              child: filtered.isEmpty
                  ? _InventoryEmptyState(
                      hasAnyItems: widget.store.items.isNotEmpty,
                      onAdd: widget.onAdd,
                    )
                  : ListView.separated(
                      key: const PageStorageKey('inventory-list'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: context.palette.border,
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        void openItem() => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetailPage(store: widget.store, item: item),
                          ),
                        );
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            if (!await _confirmDelete(context, item)) {
                              return false;
                            }
                            try {
                              await widget.store.remove(item);
                              return true;
                            } catch (_) {
                              if (context.mounted) {
                                AppToast.show(
                                  context,
                                  context.l10n.itemDeleteFailed,
                                  style: AppToastStyle.error,
                                );
                              }
                              return false;
                            }
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 22),
                            color: context.palette.danger,
                            child: Icon(
                              Icons.delete,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                          child: ItemCard(
                            key: ValueKey('inventory-item-${item.id}'),
                            item: item,
                            locationLabel: widget.store.locationLabelFor(
                              item,
                              context.l10n,
                            ),
                            onTap: openItem,
                            onPlanTap: _hasPlan(item) ? null : openItem,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _resetToAllItems() {
    searchController.clear();
    query = '';
    filter = _InventoryFilter.all;
  }

  int _compareItems(CareItem left, CareItem right) {
    if (sort == _InventorySort.name) {
      return _compareDisplayNames(left.name, right.name);
    }
    final leftDate = left.nextCareDate;
    final rightDate = right.nextCareDate;
    if (leftDate == null && rightDate == null) {
      return _compareDisplayNames(left.name, right.name);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    final result = leftDate.compareTo(rightDate);
    return result == 0 ? _compareDisplayNames(left.name, right.name) : result;
  }

  int _compareDisplayNames(String left, String right) {
    bool beginsWithDigit(String value) {
      if (value.isEmpty) return false;
      final first = value.codeUnitAt(0);
      return first >= 0x30 && first <= 0x39;
    }

    final leftBeginsWithDigit = beginsWithDigit(left);
    final rightBeginsWithDigit = beginsWithDigit(right);
    if (leftBeginsWithDigit != rightBeginsWithDigit) {
      return leftBeginsWithDigit ? 1 : -1;
    }
    return left.compareTo(right);
  }

  Future<void> _selectSort() async {
    final selected = await showModalBottomSheet<_InventorySort>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheet.l10n.itemSortTitle,
                style: TextStyle(
                  color: sheet.palette.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _InventorySortOption(
                key: const Key('inventory-sort-name'),
                icon: Icons.sort_by_alpha_rounded,
                label: sheet.l10n.sortByName,
                selected: sort == _InventorySort.name,
                onTap: () => Navigator.pop(sheet, _InventorySort.name),
              ),
              _InventorySortOption(
                key: const Key('inventory-sort-date'),
                icon: Icons.event_rounded,
                label: sheet.l10n.sortByNextMaintenance,
                selected: sort == _InventorySort.nextCareDate,
                onTap: () => Navigator.pop(sheet, _InventorySort.nextCareDate),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => sort = selected);
  }

  Future<bool> _confirmDelete(BuildContext context, CareItem item) async =>
      await showAppAlert<bool>(
        context,
        title: context.l10n.deleteItemTitle,
        message: context.l10n.deleteItemMessage(
          _itemDisplayName(context, item),
        ),
        actions: [
          AppAlertAction(label: context.l10n.commonCancel, result: false),
          AppAlertAction(
            label: context.l10n.commonDelete,
            result: true,
            tone: AppAlertActionTone.destructive,
          ),
        ],
      ) ??
      false;
}

class _AssetValuationView extends StatelessWidget {
  const _AssetValuationView({required this.store, required this.onShowItems});

  final CareStore store;
  final VoidCallback onShowItems;

  @override
  Widget build(BuildContext context) {
    final valuedItems = [...store.items]
      ..sort((left, right) {
        final leftValue = left.currentValue ?? left.purchasePrice ?? 0;
        final rightValue = right.currentValue ?? right.purchasePrice ?? 0;
        final valueOrder = rightValue.compareTo(leftValue);
        return valueOrder == 0 ? left.name.compareTo(right.name) : valueOrder;
      });
    final total = valuedItems.fold<double>(
      0,
      (sum, item) => sum + (item.currentValue ?? item.purchasePrice ?? 0),
    );
    final missingCount = valuedItems
        .where(
          (item) => item.currentValue == null && item.purchasePrice == null,
        )
        .length;
    return Column(
      key: const Key('asset-valuation-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.assetValuationTitle,
                      style: TextStyle(
                        color: context.palette.ink,
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      context.l10n.assetValuationSubtitle,
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: const Key('asset-show-all-items'),
                onPressed: onShowItems,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(context.l10n.allItems),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BreezeSurface(
            color: context.palette.mist,
            radius: 22,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.householdTotalValuation,
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '¥${total.toStringAsFixed(0)}',
                        key: const Key('asset-total-value'),
                        style: TextStyle(
                          color: context.palette.primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.paper,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    context.l10n.assetMissingCount(missingCount),
                    key: const Key('asset-missing-count'),
                    style: TextStyle(
                      color: missingCount == 0
                          ? context.palette.primary
                          : context.palette.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            context.l10n.itemValuationDetails,
            style: TextStyle(
              color: context.palette.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: valuedItems.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.home_outlined,
                    text: context.l10n.assetNoItems,
                  ),
                )
              : ListView.separated(
                  key: const PageStorageKey('asset-valuation-list'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: valuedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = valuedItems[index];
                    final value = item.currentValue ?? item.purchasePrice;
                    final source = item.currentValue != null
                        ? context.l10n.assetCurrentValue
                        : item.purchasePrice != null
                        ? context.l10n.assetPurchasePriceFallback
                        : context.l10n.assetValueMissing;
                    return Material(
                      key: ValueKey('asset-item-${item.id}'),
                      color: context.palette.paper,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetailPage(store: store, item: item),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: context.palette.mist,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  _iconForItem(item),
                                  color: context.palette.primary,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _itemDisplayName(context, item),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.palette.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      source,
                                      style: TextStyle(
                                        color: context.palette.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                value == null
                                    ? context.l10n.assetAddValue
                                    : '¥${value.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: value == null
                                      ? context.palette.accent
                                      : context.palette.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: context.palette.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 25, 20, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.inventoryTitle,
                style: TextStyle(
                  color: context.palette.ink,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                context.l10n.inventorySubtitle,
                style: TextStyle(
                  color: context.palette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: context.l10n.addItem,
          child: Material(
            color: context.palette.primary,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('inventory-add-item'),
              onTap: onAdd,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.add_rounded,
                  color: context.palette.onPrimary,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _InventoryFilterBar extends StatelessWidget {
  const _InventoryFilterBar({
    required this.selected,
    required this.totalCount,
    required this.plannedCount,
    required this.needsSetupCount,
    required this.onSelected,
  });

  final _InventoryFilter selected;
  final int totalCount;
  final int plannedCount;
  final int needsSetupCount;
  final ValueChanged<_InventoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (_InventoryFilter.all, context.l10n.inventoryFilterAll(totalCount)),
      (
        _InventoryFilter.planned,
        context.l10n.inventoryFilterPlanned(plannedCount),
      ),
      (
        _InventoryFilter.needsSetup,
        context.l10n.inventoryFilterNeedsSetup(needsSetupCount),
      ),
    ];
    return Container(
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.palette.paper,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.palette.border,
              ),
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == entries[index].$1,
                child: Material(
                  color: selected == entries[index].$1
                      ? context.palette.primary
                      : Colors.transparent,
                  child: InkWell(
                    key: ValueKey('inventory-filter-${entries[index].$1.name}'),
                    onTap: () => onSelected(entries[index].$1),
                    child: Center(
                      child: Text(
                        entries[index].$2,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected == entries[index].$1
                              ? context.palette.onPrimary
                              : context.palette.muted,
                          fontSize: 14,
                          fontWeight: selected == entries[index].$1
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InventorySortButton extends StatelessWidget {
  const _InventorySortButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.sortMethodSemantic(label),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('inventory-sort'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.palette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: context.palette.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InventorySortOption extends StatelessWidget {
  const _InventorySortOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.palette.mist : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: context.palette.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: context.palette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: context.palette.primary,
                size: 22,
              ),
          ],
        ),
      ),
    ),
  );
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({required this.hasAnyItems, required this.onAdd});

  final bool hasAnyItems;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: context.palette.mist,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: context.palette.primary,
              size: 27,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasAnyItems
                ? context.l10n.inventoryNoMatches
                : context.l10n.inventoryEmpty,
            style: TextStyle(
              color: context.palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasAnyItems
                ? context.l10n.inventoryAdjustSearch
                : context.l10n.inventoryStartFirstItem,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.muted, fontSize: 13),
          ),
          if (!hasAnyItems) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              key: const Key('inventory-empty-add-item'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(context.l10n.addItem),
            ),
          ],
        ],
      ),
    ),
  );
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.store});
  final CareStore store;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selectedDay = today;
  }

  void _moveMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selectedDay = DateTime(_month.year, _month.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = maintenanceTasksForItems(widget.store.items);
    if (tasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BreezeHeader(
            title: context.l10n.scheduleTitle,
            subtitle: context.l10n.scheduleEmptySubtitle,
          ),
          Expanded(
            child: MaintenanceTaskEmptyState(
              onCreate: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditorPage(store: widget.store),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final byDay = <DateTime, List<MaintenanceTask>>{};
    for (final task in tasks) {
      final day = maintenanceDateOnly(task.dueDate);
      (byDay[day] ??= []).add(task);
    }
    final selectedTasks = byDay[_selectedDay] ?? <MaintenanceTask>[];
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: BreezeHeader(
            title: context.l10n.scheduleTitle,
            subtitle: context.l10n.scheduleSubtitle,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _MonthCalendar(
              month: _month,
              selectedDay: _selectedDay,
              scheduledDays: byDay,
              onPrevious: () => _moveMonth(-1),
              onNext: () => _moveMonth(1),
              onSelectDay: (day) => setState(() => _selectedDay = day),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.scheduleSelectedDateTitle(
                      context.l10n.dateMonthDay(
                        _selectedDay.month,
                        _selectedDay.day,
                      ),
                    ),
                    style: TextStyle(
                      color: context.palette.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  selectedTasks.isEmpty
                      ? context.l10n.scheduleNone
                      : context.l10n.scheduleTaskCount(selectedTasks.length),
                  style: TextStyle(color: context.palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (selectedTasks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
              child: BreezeSurface(
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: context.palette.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.scheduleDayEmpty,
                        style: TextStyle(color: context.palette.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: selectedTasks.length,
            itemBuilder: (context, index) {
              final task = selectedTasks[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MaintenanceTaskCard(
                  task: task,
                  onStart: () =>
                      _startMaintenanceTask(context, widget.store, task),
                  onDefer: () =>
                      _deferMaintenanceTask(context, widget.store, task),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDay,
    required this.scheduledDays,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Map<DateTime, List<MaintenanceTask>> scheduledDays;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmptyCells = firstDay.weekday - DateTime.monday;
    final cellCount = ((leadingEmptyCells + daysInMonth + 6) ~/ 7) * 7;
    final weekdays = [
      context.l10n.weekdayMonday,
      context.l10n.weekdayTuesday,
      context.l10n.weekdayWednesday,
      context.l10n.weekdayThursday,
      context.l10n.weekdayFriday,
      context.l10n.weekdaySaturday,
      context.l10n.weekdaySunday,
    ];
    final today = DateUtils.dateOnly(DateTime.now());
    return BreezeSurface(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              _monthButton(context, Icons.chevron_left_rounded, onPrevious),
              Expanded(
                child: Text(
                  context.l10n.calendarMonthYear(month.year, month.month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.palette.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              _monthButton(context, Icons.chevron_right_rounded, onNext),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekdays.indexed
                .map(
                  (entry) => Expanded(
                    child: Center(
                      child: Text(
                        entry.$2,
                        style: TextStyle(
                          color: entry.$1 >= 5
                              ? context.palette.accent
                              : context.palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmptyCells + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(month.year, month.month, dayNumber);
              final itemCount = scheduledDays[day]?.length ?? 0;
              final selected = DateUtils.isSameDay(day, selectedDay);
              final isToday = DateUtils.isSameDay(day, today);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey(
                    'calendar-day-${day.year}-${day.month}-${day.day}',
                  ),
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => onSelectDay(day),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? context.palette.primary
                            : (isToday
                                  ? context.palette.mist
                                  : Colors.transparent),
                        borderRadius: BorderRadius.circular(15),
                        border: isToday && !selected
                            ? Border.all(
                                color: context.palette.primary.withValues(
                                  alpha: .35,
                                ),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: selected
                                  ? context.palette.onPrimary
                                  : context.palette.ink,
                              fontWeight: selected || isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 4,
                            child: itemCount == 0
                                ? null
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      itemCount.clamp(1, 3).toInt(),
                                      (_) => Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? context.palette.warningSurface
                                              : context.palette.accent,
                                          shape: BoxShape.circle,
                                        ),
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
            },
          ),
        ],
      ),
    );
  }

  Widget _monthButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.palette.mist,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: context.palette.primary),
      ),
    ),
  );
}

class AssetLedgerPage extends StatelessWidget {
  const AssetLedgerPage({super.key, required this.store});
  final CareStore store;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final entries = <(CareItem, MaintenanceRecord)>[];
    for (final item in store.items) {
      for (final record in item.records) {
        entries.add((item, record));
      }
    }
    entries.sort((a, b) => b.$2.date.compareTo(a.$2.date));
    final annualCost = entries
        .where((entry) => entry.$2.date.year == year)
        .fold<double>(0, (sum, entry) => sum + entry.$2.cost);
    final assetValue = store.items.fold<double>(
      0,
      (sum, item) => sum + (item.currentValue ?? item.purchasePrice ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BreezeHeader(
                title: context.l10n.ledgerTitle,
                subtitle: context.l10n.ledgerSubtitle,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _summary(
                          context,
                          context.l10n.ledgerAnnualHoldingCost(year),
                          '¥${annualCost.toStringAsFixed(0)}',
                          context.palette.accent,
                        ),
                        const SizedBox(width: 10),
                        _summary(
                          context,
                          context.l10n.assetValuationTitle,
                          '¥${assetValue.toStringAsFixed(0)}',
                          context.palette.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.ledgerCostHistory,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: context.palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  text: context.l10n.ledgerEmpty,
                )
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return BreezeSurface(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: context.palette.accent.withValues(
                                alpha: .14,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: context.palette.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.maintenancePlanTitleLabel(
                                    entry.$2.kind,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: context.palette.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  context.l10n.ledgerRecordSummary(
                                    entry.$1.name,
                                    _localizedDate(context, entry.$2.date),
                                    entry.$2.note.isEmpty
                                        ? ''
                                        : context.l10n.ledgerNoteSuffix(
                                            entry.$2.note,
                                          ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.$2.cost == 0
                                ? '—'
                                : '¥${entry.$2.cost.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: context.palette.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _summary(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) => Expanded(
    child: BreezeSurface(
      color: color.withValues(alpha: .10),
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final CareStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _remindersEnabled = false;
  bool _restoreInProgress = false;
  bool _kifxOpening = false;

  CareStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshReminderStatus());
  }

  Future<void> _refreshReminderStatus() async {
    final access = await store.notificationAccess();
    if (mounted) {
      setState(() => _remindersEnabled = access == NotificationAccess.enabled);
    }
  }

  Future<void> _handleReminderTap() async {
    final current = await store.notificationAccess();
    if (!mounted) return;
    if (current == NotificationAccess.enabled) {
      await _showReminderTools();
      return;
    }
    if (current == NotificationAccess.denied) {
      await _showNotificationSettingsGuide();
      return;
    }
    if (current == NotificationAccess.unavailable) {
      await showSystemPermissionAlert(
        context,
        permission: SystemPermissionKind.notifications,
        state: SystemPermissionState.unavailable,
      );
      return;
    }
    final proceed = await _showNotificationPrimer(context);
    if (!proceed || !mounted) return;
    await store.markNotificationPrimerSeen();
    final access = await store.requestNotifications();
    if (!mounted) return;
    if (access == NotificationAccess.enabled) {
      setState(() => _remindersEnabled = true);
      AppToast.show(
        context,
        context.l10n.remindersEnabledToast,
        style: AppToastStyle.success,
      );
      return;
    }
    if (access == NotificationAccess.denied) {
      await _showNotificationSettingsGuide();
      return;
    }
    await showSystemPermissionAlert(
      context,
      permission: SystemPermissionKind.notifications,
      state: SystemPermissionState.unavailable,
    );
  }

  Future<void> _showNotificationSettingsGuide() async {
    await showSystemPermissionAlert(
      context,
      permission: SystemPermissionKind.notifications,
      state: SystemPermissionState.denied,
    );
  }

  Future<void> _showReminderTools() async {
    final scheduledTasks = maintenanceTasksForItems(store.items).length;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sheet.l10n.remindersEnabledTitle,
                style: TextStyle(
                  color: sheet.palette.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                scheduledTasks == 0
                    ? sheet.l10n.remindersNoScheduledPlans
                    : sheet.l10n.remindersScheduledPlans(scheduledTasks),
                style: TextStyle(color: sheet.palette.muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('reminder-tools-test'),
                onPressed: () async {
                  final sent = await store.sendTestNotification();
                  if (sheet.mounted) Navigator.pop(sheet);
                  if (!mounted) return;
                  if (sent) {
                    AppToast.show(
                      context,
                      context.l10n.testReminderScheduled,
                      style: AppToastStyle.success,
                    );
                    return;
                  }
                  final access = await store.notificationAccess();
                  if (!mounted) return;
                  if (access == NotificationAccess.denied) {
                    await _showNotificationSettingsGuide();
                  } else if (access == NotificationAccess.unavailable) {
                    await showSystemPermissionAlert(
                      context,
                      permission: SystemPermissionKind.notifications,
                      state: SystemPermissionState.unavailable,
                    );
                  } else {
                    AppToast.show(
                      context,
                      context.l10n.testReminderFailed,
                      style: AppToastStyle.error,
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(sheet.l10n.sendTestReminder),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('reminder-tools-settings'),
                onPressed: () async {
                  final opened = await launchUrl(
                    Uri.parse('app-settings:'),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && sheet.mounted) {
                    AppToast.show(
                      sheet,
                      sheet.l10n.notificationSettingsManual,
                      style: AppToastStyle.error,
                    );
                  }
                },
                child: Text(sheet.l10n.openSystemNotificationSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker() async {
    final controller = AppLocaleScope.maybeOf(context);
    if (controller == null) return;
    final selected = await showModalBottomSheet<AppLanguageMode>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final l10n = sheet.l10n;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.languageTitle,
                  style: TextStyle(
                    color: sheet.palette.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _LanguageOption(
                  key: const Key('language-system'),
                  label: l10n.systemLanguage,
                  selected: controller.mode == AppLanguageMode.system,
                  onTap: () => Navigator.pop(sheet, AppLanguageMode.system),
                ),
                _LanguageOption(
                  key: const Key('language-zh'),
                  label: l10n.simplifiedChinese,
                  selected:
                      controller.mode == AppLanguageMode.simplifiedChinese,
                  onTap: () =>
                      Navigator.pop(sheet, AppLanguageMode.simplifiedChinese),
                ),
                _LanguageOption(
                  key: const Key('language-en'),
                  label: l10n.english,
                  selected: controller.mode == AppLanguageMode.english,
                  onTap: () => Navigator.pop(sheet, AppLanguageMode.english),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) await controller.setMode(selected);
  }

  Future<void> _openKifxMini() async {
    if (_kifxOpening) return;
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      AppToast.show(
        context,
        context.l10n.kifxMiniUnavailable,
        style: AppToastStyle.error,
      );
      return;
    }

    setState(() => _kifxOpening = true);
    try {
      await _launchKifxMini();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kifxMiniAutoOpenPreferenceKey, true);
      } catch (_) {
        // Opening succeeded; a storage failure should not report it as failed.
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.kifxMiniOpenFailed,
          style: AppToastStyle.error,
        );
      }
    } finally {
      if (mounted) setState(() => _kifxOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeController = AppLocaleScope.maybeOf(context);
    final languageLabel = switch (localeController?.mode) {
      AppLanguageMode.system => l10n.systemLanguage,
      AppLanguageMode.simplifiedChinese => l10n.simplifiedChinese,
      AppLanguageMode.english => l10n.english,
      null => l10n.systemLanguage,
    };
    final content = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),
      children: [
        BreezeHeader(
          title: l10n.settingsTitle,
          subtitle: l10n.settingsSubtitle,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.generalSection,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.palette.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BreezeSurface(
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.language_rounded,
                  title: l10n.languageTitle,
                  subtitle: '$languageLabel · ${l10n.languageSettingSubtitle}',
                  onTap: localeController == null ? null : _showLanguagePicker,
                ),
                Divider(height: 1, color: context.palette.divider),
                SettingRow(
                  key: const Key('settings-feature-intro'),
                  icon: Icons.auto_stories_outlined,
                  title: l10n.featureIntroTitle,
                  subtitle: l10n.featureIntroSettingsSubtitle,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const FeatureIntroPage()),
                  ),
                ),
                // Divider(height: 1, color: context.palette.divider),
                // SettingRow(
                //   key: const Key('settings-kifx-mini'),
                //   icon: Icons.widgets_outlined,
                //   title: l10n.kifxMiniTitle,
                //   subtitle: l10n.kifxMiniSubtitle,
                //   onTap: _kifxOpening ? null : _openKifxMini,
                // ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.dataAndRemindersSection,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.palette.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BreezeSurface(
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.notifications_active_outlined,
                  title: _remindersEnabled
                      ? l10n.remindersAndTesting
                      : l10n.enableMaintenanceReminders,
                  subtitle: _remindersEnabled
                      ? l10n.remindersEnabledSubtitle
                      : l10n.remindersDisabledSubtitle,
                  onTap: _handleReminderTap,
                ),
                Divider(height: 1, color: context.palette.divider),
                SettingRow(
                  icon: Icons.ios_share_outlined,
                  title: l10n.exportLocalData,
                  subtitle: l10n.exportLocalDataSubtitle,
                  onTap: () => store.exportCSV(context),
                ),
                Divider(height: 1, color: context.palette.divider),
                SettingRow(
                  icon: Icons.backup_outlined,
                  title: l10n.fullBackup,
                  subtitle: l10n.fullBackupSubtitle,
                  onTap: () => store.exportBackup(context),
                ),
                Divider(height: 1, color: context.palette.divider),
                SettingRow(
                  icon: Icons.restore_page_outlined,
                  title: l10n.restoreBackup,
                  subtitle: _restoreInProgress
                      ? l10n.restoreInProgress
                      : l10n.restoreBackupSubtitle,
                  onTap: _restoreInProgress || store.isRestoringBackup
                      ? null
                      : () => _restoreFromBackup(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.privacySection,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.palette.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BreezeSurface(
            child: SettingRow(
              icon: Icons.privacy_tip_outlined,
              title: l10n.privacyPolicyTitle,
              subtitle: l10n.privacyPolicySubtitle,
              onTap: () async {
                final remoteUrl = privacyPolicyUrlForLocale(
                  Localizations.localeOf(context),
                );
                if (Platform.isIOS) {
                  await StminiFlutter.openWeb(
                    remoteUrl,
                    title: l10n.privacyPolicyTitle,
                  );
                  return;
                }
                if (!context.mounted) return;
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PrivacyPolicyPage(remoteUrl: remoteUrl),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
    return ThreeFingerLongPressRegion(
      onLongPress: () => unawaited(_openKifxMini()),
      child: content,
    );
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    if (_restoreInProgress || store.isRestoringBackup) return;
    setState(() => _restoreInProgress = true);
    try {
      final firstTime = await store.needsRestoreGuide();
      if (!context.mounted) return;
      final proceed = await showAppAlert<bool>(
        context,
        title: firstTime
            ? context.l10n.restoreGuideTitle
            : context.l10n.restoreConfirmTitle,
        message: firstTime
            ? context.l10n.restoreGuideMessage
            : context.l10n.restoreConfirmMessage,
        actions: [
          AppAlertAction(label: context.l10n.restoreNotNow, result: false),
          AppAlertAction(
            label: context.l10n.chooseBackupFile,
            result: true,
            isDefaultAction: true,
          ),
        ],
      );
      if (proceed != true) return;
      if (firstTime) unawaited(store.markRestoreGuideSeen());
      final ok = await store.restoreBackup();
      if (context.mounted) {
        AppToast.show(
          context,
          ok ? context.l10n.restoreSuccess : context.l10n.restoreInvalid,
          style: ok ? AppToastStyle.success : AppToastStyle.error,
        );
      }
    } finally {
      if (mounted) setState(() => _restoreInProgress = false);
    }
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: selected
        ? Icon(Icons.check_rounded, color: context.palette.primary)
        : null,
    onTap: onTap,
  );
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onPlanTap,
    this.locationLabel,
  });

  final CareItem item;
  final VoidCallback onTap;
  final VoidCallback? onPlanTap;
  final String? locationLabel;

  @override
  Widget build(BuildContext context) {
    final planned = item.nextCareDate != null;
    return RepaintBoundary(
      child: Material(
        color: context.palette.paper,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.palette.mist,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _iconForItem(item),
                    color: context.palette.primary,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _itemDisplayName(context, item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.palette.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          context.l10n.itemCategoryLabel(item.category),
                          (locationLabel ?? item.location).isEmpty
                              ? context.l10n.unassignedSpace
                              : locationLabel ?? item.location,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 13,
                        ),
                      ),
                      if (!planned) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.itemNoMaintenanceReminder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.palette.subtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 116),
                  child: planned
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.palette.mist,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.l10n.itemPlanned,
                                style: TextStyle(
                                  color: context.palette.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              context.l10n.itemNextMaintenance(
                                _localizedDate(context, item.nextCareDate),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      : Semantics(
                          button: true,
                          label: context.l10n.setPlanForItemSemantic(
                            _itemDisplayName(context, item),
                          ),
                          child: InkWell(
                            key: ValueKey('inventory-set-plan-${item.id}'),
                            onTap: onPlanTap,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                              child: Text(
                                context.l10n.setPlan,
                                maxLines: 1,
                                style: TextStyle(
                                  color: context.palette.warning,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 7),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: context.palette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _itemDisplayName(BuildContext context, CareItem item) => context.l10n
    .itemNameLabel(id: item.id, isSample: item.isSample, name: item.name);

IconData _iconForItem(CareItem item) {
  if (item.name.contains('洗衣机')) {
    return Icons.local_laundry_service_outlined;
  }
  return _iconFor(item.category);
}

IconData _iconFor(String category) {
  switch (canonicalItemCategory(category)) {
    case '家用电器':
      return Icons.kitchen_outlined;
    case '滤芯与耗材':
      return Icons.water_drop_outlined;
    case '家具':
      return Icons.chair_outlined;
    case '厨房用品':
      return Icons.soup_kitchen_outlined;
    case '个人与卫浴':
      return Icons.bathtub_outlined;
    case '织物与床品':
      return Icons.bed_outlined;
    case '清洁与收纳':
      return Icons.cleaning_services_outlined;
    case '小物品与工具':
      return Icons.handyman_outlined;
    case '医疗保健':
      return Icons.medical_services_outlined;
    case '文件证件':
      return Icons.folder_outlined;
    case '装饰与兴趣':
      return Icons.palette_outlined;
    case '车辆与出行':
      return Icons.directions_car_outlined;
    case '宠物用品':
      return Icons.pets_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: BreezeSurface(
      color: context.palette.paper,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.palette.mist,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: context.palette.primary),
          ),
          const SizedBox(height: 15),
          Text(text, style: TextStyle(color: context.palette.muted)),
        ],
      ),
    ),
  );
}

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.store, required this.item});
  final CareStore store;
  final CareItem item;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  CareStore get store => widget.store;

  CareItem get item {
    for (final current in store.items) {
      if (current.id == widget.item.id) return current;
    }
    return widget.item;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => _buildPage(context),
  );

  Widget _buildPage(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 72,
      title: Text(_itemDisplayName(context, item)),
      leading: AppBackButton(onPressed: () => Navigator.pop(context)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: context.palette.mist,
              foregroundColor: context.palette.primary,
            ),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditorPage(store: store, item: item),
                ),
              );
            },
          ),
        ),
      ],
    ),
    body: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: appSafeScrollPadding(context, const EdgeInsets.all(20)),
      children: [
        MaintenanceLifecycleOverview(item: item),
        if (item.photos.isNotEmpty)
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: item.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(item.photos[i]),
                  width: 150,
                  height: 110,
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 150,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
          ),
        if (item.photos.isNotEmpty) const SizedBox(height: 18),
        _plansSection(),
        _section(context.l10n.itemInformation, [
          (
            context.l10n.itemCategory,
            context.l10n.itemCategoryLabel(item.category),
          ),
          (
            context.l10n.itemLocation,
            store.locationLabelFor(item, context.l10n),
          ),
          (context.l10n.itemBrand, item.brand),
          (context.l10n.itemModel, item.model),
          (
            context.l10n.itemPurchaseDate,
            _localizedDate(context, item.purchaseDate),
          ),
          (
            context.l10n.itemWarrantyEnd,
            _localizedDate(context, item.warrantyDate),
          ),
          (
            context.l10n.itemPurchasePrice,
            item.purchasePrice == null
                ? context.l10n.dateNotSet
                : '¥${item.purchasePrice!.toStringAsFixed(0)}',
          ),
          (
            context.l10n.itemCurrentValue,
            item.currentValue == null
                ? context.l10n.dateNotSet
                : '¥${item.currentValue!.toStringAsFixed(0)}',
          ),
        ]),
        if (item.notes.isNotEmpty)
          _section(context.l10n.itemNotes, [
            (
              context.l10n.itemDescription,
              context.l10n.itemNotesLabel(
                id: item.id,
                isSample: item.isSample,
                notes: item.notes,
              ),
            ),
          ]),
        MaintenanceLifecycleTimeline(item: item, controller: store),
        FilledButton.icon(
          key: const Key('start-maintenance-from-detail'),
          icon: const Icon(Icons.add_task_outlined),
          label: Text(context.l10n.startOneMaintenance),
          onPressed: () => _startMaintenance(context),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: context.palette.danger,
          ),
          icon: const Icon(Icons.delete_outline),
          label: Text(context.l10n.deleteThisItem),
          onPressed: () async {
            try {
              await store.remove(item);
              if (context.mounted) Navigator.pop(context);
            } catch (_) {
              if (context.mounted) {
                AppToast.show(
                  context,
                  context.l10n.itemDeleteFailed,
                  style: AppToastStyle.error,
                );
              }
            }
          },
        ),
      ],
    ),
  );

  Widget _section(String title, List<(String, String)> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 8),
        BreezeSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(rows.length, (index) {
              final row = rows[index];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.$1,
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            row.$2,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: context.palette.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < rows.length - 1)
                    Divider(height: 1, color: context.palette.divider),
                ],
              );
            }),
          ),
        ),
      ],
    ),
  );

  Future<void> _openPlanSetup() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditorPage(store: store, item: item, focusMaintenancePlans: true),
      ),
    );
  }

  Widget _plansSection() {
    final visiblePlans = item.plans.where((plan) => !plan.archived).toList()
      ..sort((a, b) {
        final aDate = a.dueDate ?? DateTime(9999);
        final bDate = b.dueDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });
    final archivedCount = item.plans.where((plan) => plan.archived).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        key: const Key('detail-maintenance-plans'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.detailMaintenancePlans,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              if (archivedCount > 0)
                Text(
                  context.l10n.detailArchivedPlans(archivedCount),
                  style: TextStyle(color: context.palette.muted, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (visiblePlans.isEmpty)
            BreezeSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.detailNoVisiblePlans,
                    style: TextStyle(color: context.palette.muted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: const Key('detail-set-maintenance-plan'),
                      onPressed: _openPlanSetup,
                      icon: const Icon(Icons.event_repeat_rounded),
                      label: Text(context.l10n.setPlan),
                    ),
                  ),
                ],
              ),
            )
          else
            BreezeSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: List.generate(visiblePlans.length, (index) {
                  final plan = visiblePlans[index];
                  final status = MaintenancePlanStatus.evaluate(plan);
                  return Column(
                    key: ValueKey('detail-plan-${plan.id}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              plan.enabled
                                  ? Icons.event_available_outlined
                                  : Icons.event_busy_outlined,
                              color: context.palette.primary,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.maintenancePlanTitleLabel(
                                      plan.title,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: context.palette.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context.l10n.detailPlanSchedule(
                                      context.l10n.maintenanceStateLabel(
                                        status.state,
                                      ),
                                      plan.intervalDays,
                                      plan.reminderLeadDays,
                                    ),
                                    key: ValueKey(
                                      'detail-plan-status-${plan.id}',
                                    ),
                                    style: TextStyle(
                                      color: context.palette.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.l10n.detailPlanDueSummary(
                                      _localizedDate(context, plan.dueDate),
                                      context.l10n.maintenanceTimingLabel(
                                        status,
                                      ),
                                      plan.checklist.length,
                                    ),
                                    style: TextStyle(
                                      color: context.palette.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (status.hasActiveDeferral) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      context.l10n.dashboardDeferredStatus(
                                        _localizedDate(
                                          context,
                                          status.deferredUntil,
                                        ),
                                        context.l10n.maintenanceStateLabel(
                                          status.dueState,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: context.palette.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < visiblePlans.length - 1)
                        Divider(height: 1, color: context.palette.divider),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startMaintenance(BuildContext context) async {
    final availablePlans = item.plans
        .where((plan) => plan.enabled && !plan.archived && plan.dueDate != null)
        .toList();
    if (availablePlans.isEmpty) {
      AppToast.show(context, context.l10n.planRequiredBeforeMaintenance);
      return;
    }
    MaintenancePlan? selectedPlan;
    if (availablePlans.length == 1) {
      selectedPlan = availablePlans.single;
    } else {
      selectedPlan = await showModalBottomSheet<MaintenancePlan>(
        context: context,
        builder: (sheet) => ListView(
          shrinkWrap: true,
          padding: appSafeScrollPadding(
            sheet,
            const EdgeInsets.fromLTRB(20, 14, 20, 24),
          ),
          children: [
            Text(
              sheet.l10n.chooseMaintenanceTask,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final plan in availablePlans)
              ListTile(
                key: ValueKey('start-detail-plan-${plan.id}'),
                title: Text(sheet.l10n.maintenancePlanTitleLabel(plan.title)),
                subtitle: Text(
                  sheet.l10n.dashboardOriginalDueDate(
                    _localizedDate(sheet, plan.dueDate),
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded),
                onTap: () => Navigator.pop(sheet, plan),
              ),
          ],
        ),
      );
    }
    if (selectedPlan == null || !context.mounted) return;
    final task = MaintenanceTask(
      item: item,
      plan: selectedPlan,
      status: MaintenancePlanStatus.evaluate(selectedPlan),
    );
    await _startMaintenanceTask(
      context,
      store,
      task,
      openLifecycleAfterCompletion: false,
    );
  }
}

class _ItemPreset {
  const _ItemPreset(this.name, [this.icon]);

  final String name;
  final IconData? icon;
}

class _ItemCatalogCategory {
  const _ItemCatalogCategory(this.name, this.icon, this.items);

  final String name;
  final IconData icon;
  final List<_ItemPreset> items;
}

const _itemCatalog = <_ItemCatalogCategory>[
  _ItemCatalogCategory('家具', Icons.chair_outlined, [
    _ItemPreset('沙发'),
    _ItemPreset('床'),
    _ItemPreset('茶几'),
    _ItemPreset('电视柜'),
    _ItemPreset('餐桌'),
    _ItemPreset('餐椅'),
    _ItemPreset('衣柜'),
    _ItemPreset('书桌'),
    _ItemPreset('鞋柜'),
    _ItemPreset('其他家具', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('家用电器', Icons.kitchen_outlined, [
    _ItemPreset('冰箱', Icons.kitchen_outlined),
    _ItemPreset('洗衣机', Icons.local_laundry_service_outlined),
    _ItemPreset('空调', Icons.air_outlined),
    _ItemPreset('电视', Icons.tv_outlined),
    _ItemPreset('油烟机', Icons.wind_power_outlined),
    _ItemPreset('电饭煲', Icons.rice_bowl_outlined),
    _ItemPreset('吸尘器', Icons.cleaning_services_outlined),
    _ItemPreset('扫地机器人', Icons.smart_toy_outlined),
    _ItemPreset('净水器', Icons.water_drop_outlined),
    _ItemPreset('热水器', Icons.hot_tub_outlined),
    _ItemPreset('其他家电', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('厨房用品', Icons.soup_kitchen_outlined, [
    _ItemPreset('炒锅'),
    _ItemPreset('汤锅'),
    _ItemPreset('碗碟'),
    _ItemPreset('筷子'),
    _ItemPreset('刀具'),
    _ItemPreset('砧板'),
    _ItemPreset('保鲜盒'),
    _ItemPreset('调料罐'),
    _ItemPreset('其他厨房用品', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('个人与卫浴', Icons.bathtub_outlined, [
    _ItemPreset('牙刷'),
    _ItemPreset('毛巾'),
    _ItemPreset('沐浴用品'),
    _ItemPreset('洗发用品'),
    _ItemPreset('马桶'),
    _ItemPreset('洗手盆'),
    _ItemPreset('浴帘'),
    _ItemPreset('其他卫浴用品', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('织物与床品', Icons.bed_outlined, [
    _ItemPreset('床单'),
    _ItemPreset('被套'),
    _ItemPreset('被子'),
    _ItemPreset('枕头'),
    _ItemPreset('凉席'),
    _ItemPreset('蚊帐'),
    _ItemPreset('衣物'),
    _ItemPreset('鞋子'),
    _ItemPreset('包包'),
    _ItemPreset('配饰'),
    _ItemPreset('其他织物', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('清洁与收纳', Icons.cleaning_services_outlined, [
    _ItemPreset('扫帚'),
    _ItemPreset('拖把'),
    _ItemPreset('洗洁精'),
    _ItemPreset('洗衣液'),
    _ItemPreset('垃圾桶'),
    _ItemPreset('收纳箱'),
    _ItemPreset('衣架'),
    _ItemPreset('其他清洁用品', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('小物品与工具', Icons.handyman_outlined, [
    _ItemPreset('文具'),
    _ItemPreset('充电线'),
    _ItemPreset('充电宝'),
    _ItemPreset('螺丝刀'),
    _ItemPreset('扳手'),
    _ItemPreset('胶带'),
    _ItemPreset('电池'),
    _ItemPreset('其他工具', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('医疗保健', Icons.medical_services_outlined, [
    _ItemPreset('常用药品'),
    _ItemPreset('保健品'),
    _ItemPreset('体温计'),
    _ItemPreset('血压计'),
    _ItemPreset('创可贴'),
    _ItemPreset('其他医疗用品', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('文件证件', Icons.folder_outlined, [
    _ItemPreset('身份证'),
    _ItemPreset('户口本'),
    _ItemPreset('房产证'),
    _ItemPreset('合同'),
    _ItemPreset('票据'),
    _ItemPreset('证书'),
    _ItemPreset('其他文件', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('装饰与兴趣', Icons.palette_outlined, [
    _ItemPreset('挂画'),
    _ItemPreset('花瓶'),
    _ItemPreset('香薰'),
    _ItemPreset('绿植'),
    _ItemPreset('运动器材'),
    _ItemPreset('书法绘画工具'),
    _ItemPreset('其他兴趣用品', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('滤芯与耗材', Icons.filter_alt_outlined, [
    _ItemPreset('净水器滤芯'),
    _ItemPreset('空调滤网'),
    _ItemPreset('空气净化器滤芯'),
    _ItemPreset('吸尘器尘袋'),
    _ItemPreset('其他耗材', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('车辆与出行', Icons.directions_car_outlined, [
    _ItemPreset('汽车'),
    _ItemPreset('电动车'),
    _ItemPreset('自行车'),
    _ItemPreset('头盔'),
    _ItemPreset('行车记录仪'),
    _ItemPreset('其他出行物品', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('宠物用品', Icons.pets_outlined, [
    _ItemPreset('猫砂盆'),
    _ItemPreset('宠物饮水机'),
    _ItemPreset('宠物喂食器'),
    _ItemPreset('宠物笼'),
    _ItemPreset('其他宠物用品', Icons.more_horiz_rounded),
  ]),
  _ItemCatalogCategory('其他物品', Icons.more_horiz_rounded, [
    _ItemPreset('其他物品', Icons.inventory_2_outlined),
  ]),
];

const _commonItemNames = ['冰箱', '空调', '洗衣机', '净水器', '扫地机器人'];

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.store,
    this.item,
    this.initialSpaceId,
    this.focusMaintenancePlans = false,
  });
  final CareStore store;
  final CareItem? item;
  final String? initialSpaceId;
  final bool focusMaintenancePlans;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final form = GlobalKey<FormState>();
  final _maintenancePlansKey = GlobalKey();
  late final TextEditingController name,
      customName,
      search,
      location,
      brand,
      model,
      notes,
      purchasePrice,
      currentValue;
  late String category;
  DateTime? purchase, warranty;
  late List<String> photos;
  late List<MaintenancePlan> plans;
  final _newPhotoPaths = <String>{};
  final _expandedCategories = <String>{'家用电器'};
  bool _saved = false;
  bool _allowSupplementPop = false;
  bool _showSupplement = false;
  bool _advancedExpanded = false;
  bool _brandModelExpanded = false;
  bool _initialPlanFocusScheduled = false;
  String? _selectedPresetName;
  IconData _selectedPresetIcon = Icons.inventory_2_outlined;
  String? _selectedSpaceId;
  late final List<String> categories = _itemCatalog
      .map((entry) => entry.name)
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    final x = widget.item;
    name = TextEditingController(text: x?.name);
    customName = TextEditingController();
    search = TextEditingController();
    _selectedSpaceId = x?.spaceId ?? widget.initialSpaceId;
    location = TextEditingController(
      text: x == null
          ? ''
          : x.spaceId == null
          ? x.location
          : x.locationDetail,
    );
    brand = TextEditingController(text: x?.brand);
    model = TextEditingController(text: x?.model);
    notes = TextEditingController(text: x?.notes);
    purchasePrice = TextEditingController(
      text: x?.purchasePrice?.toStringAsFixed(0),
    );
    currentValue = TextEditingController(
      text: x?.currentValue?.toStringAsFixed(0),
    );
    category = canonicalItemCategory(x?.category ?? categories.first);
    if (!categories.contains(category)) categories.add(category);
    purchase = x?.purchaseDate;
    warranty = x?.warrantyDate;
    photos = [...?x?.photos];
    plans = [...?x?.plans];
  }

  @override
  void dispose() {
    if (!_saved) {
      for (final path in _newPhotoPaths) {
        unawaited(widget.store._deletePhoto(path));
      }
    }
    for (final c in [
      name,
      customName,
      search,
      location,
      brand,
      model,
      notes,
      purchasePrice,
      currentValue,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.focusMaintenancePlans ||
        widget.item == null ||
        _initialPlanFocusScheduled) {
      return;
    }
    _initialPlanFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planContext = _maintenancePlansKey.currentContext;
      if (!mounted || planContext == null) return;
      Scrollable.ensureVisible(
        planContext,
        alignment: .12,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item != null) return _buildLegacyEditor();
    return _showSupplement ? _buildSupplementPage() : _buildSelectionPage();
  }

  Widget _buildLegacyEditor() => Scaffold(
    appBar: AppBar(
      toolbarHeight: 72,
      title: Text(context.l10n.editItemTitle),
      leading: AppBackButton(onPressed: () => Navigator.pop(context)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: FilledButton(
            key: const Key('save-care-item'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(context.l10n.commonSave),
          ),
        ),
      ],
    ),
    body: Form(
      key: form,
      child: ListView(
        key: const PageStorageKey('item-editor-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: appSafeScrollPadding(context, const EdgeInsets.all(20)),
        children: [
          _field(name, context.l10n.itemNameRequiredLabel, required: true),
          _category(),
          _spaceSelectorField(),
          const SizedBox(height: 12),
          _field(location, context.l10n.specificLocationOptional),
          _field(brand, context.l10n.itemBrand),
          _field(model, context.l10n.itemModel),
          const SizedBox(height: 4),
          Text(
            context.l10n.assetInformation,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 10),
          _field(
            purchasePrice,
            context.l10n.purchasePriceCny,
            type: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => _nonNegativeNumber(context, value),
          ),
          _field(
            currentValue,
            context.l10n.currentValueCny,
            type: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => _nonNegativeNumber(context, value),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.dateInformation,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          _dateTile(
            context.l10n.itemPurchaseDate,
            purchase,
            (d) => setState(() => purchase = d),
          ),
          _dateTile(
            context.l10n.itemWarrantyEnd,
            warranty,
            (d) => setState(() => warranty = d),
          ),
          const SizedBox(height: 10),
          MaintenancePlansEditorSection(
            key: _maintenancePlansKey,
            plans: plans,
            records: widget.item?.records ?? const [],
            onChanged: (value) => setState(() => plans = value),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.documentPhotos,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          _photos(),
          const SizedBox(height: 16),
          _field(notes, context.l10n.itemNotes, maxLines: 4),
          const SizedBox(height: 80),
        ],
      ),
    ),
  );

  Widget _buildSelectionPage() => Scaffold(
    appBar: AppBar(
      toolbarHeight: 76,
      title: Text(context.l10n.chooseItemTitle),
      leading: AppBackButton(onPressed: () => Navigator.pop(context)),
    ),
    body: ListView(
      key: const PageStorageKey('item-selection-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: appSafeScrollPadding(
        context,
        const EdgeInsets.fromLTRB(20, 4, 20, 36),
      ),
      children: [
        TextField(
          key: const Key('item-search'),
          controller: search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.l10n.searchCategoriesOrItems,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _stepIndicator(1),
        const SizedBox(height: 26),
        if (search.text.trim().isNotEmpty)
          _searchResults()
        else ...[
          Text(
            context.l10n.commonItems,
            style: TextStyle(
              color: context.palette.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _commonItems(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Divider(height: 1, color: context.palette.divider),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.allCategories,
                  style: TextStyle(
                    color: context.palette.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('toggle-all-item-categories'),
                onPressed: _toggleAllCategories,
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  _expandedCategories.length == _itemCatalog.length
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(
                  _expandedCategories.length == _itemCatalog.length
                      ? context.l10n.collapseAll
                      : context.l10n.expandAll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _categoryDirectory(),
        ],
      ],
    ),
  );

  Widget _buildSupplementPage() => PopScope(
    canPop: _allowSupplementPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _returnToSelection();
    },
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        centerTitle: true,
        title: Text(context.l10n.supplementInformation),
        leading: AppBackButton(onPressed: _returnToSelection),
      ),
      body: Form(
        key: form,
        child: ListView(
          key: const PageStorageKey('item-supplement-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _stepIndicator(2),
            const SizedBox(height: 24),
            _selectedItemSummary(),
            const SizedBox(height: 28),
            Text(
              context.l10n.optionalInformation,
              style: TextStyle(
                color: context.palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _optionalInfoGroup(),
            const SizedBox(height: 16),
            _advancedInfoGroup(),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: appSafeScrollPadding(
          context,
          _advancedExpanded
              ? const EdgeInsets.fromLTRB(20, 6, 20, 8)
              : const EdgeInsets.fromLTRB(20, 10, 20, 12),
        ),
        child: _advancedExpanded
            ? Row(
                key: const Key('compact-item-actions'),
                children: [
                  TextButton(
                    key: const Key('save-care-item-later'),
                    onPressed: _save,
                    child: Text(context.l10n.finishLater),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const Key('save-care-item'),
                        onPressed: _save,
                        child: Text(context.l10n.finishAdding),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                key: const Key('full-item-actions'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('save-care-item'),
                      onPressed: _save,
                      child: Text(context.l10n.finishAdding),
                    ),
                  ),
                  TextButton(
                    key: const Key('save-care-item-later'),
                    onPressed: _save,
                    child: Text(context.l10n.finishLater),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _stepIndicator(int activeStep) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _stepDot(1, context.l10n.chooseItemTitle, activeStep == 1),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          '·',
          style: TextStyle(color: context.palette.muted, fontSize: 20),
        ),
      ),
      _stepDot(2, context.l10n.supplementInformation, activeStep == 2),
    ],
  );

  Widget _stepDot(int number, String label, bool active) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.palette.primary : context.palette.mist,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: active ? context.palette.onPrimary : context.palette.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: active ? context.palette.ink : context.palette.muted,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ],
  );

  Widget _commonItems() => SizedBox(
    height: 104,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _commonItemNames.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final match = _findPreset(_commonItemNames[index])!;
        return SizedBox(
          width: 64,
          child: InkWell(
            key: ValueKey('common-item-${match.item.name}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => _selectPreset(match.category, match.item),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: context.palette.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Icon(
                    match.item.icon ?? match.category.icon,
                    color: context.palette.primary,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.l10n.itemPresetLabel(match.item.name),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.palette.ink),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _categoryDirectory() => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BreezeSurface(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < _itemCatalog.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.palette.divider),
            _categorySection(_itemCatalog[index]),
          ],
        ],
      ),
    ),
  );

  Widget _categorySection(_ItemCatalogCategory itemCategory) {
    final expanded = _expandedCategories.contains(itemCategory.name);
    return Column(
      children: [
        InkWell(
          key: ValueKey('item-category-${itemCategory.name}'),
          onTap: () => setState(() {
            expanded
                ? _expandedCategories.remove(itemCategory.name)
                : _expandedCategories.add(itemCategory.name);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(
                  itemCategory.icon,
                  color: context.palette.primary,
                  size: 25,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.l10n.itemCategoryLabel(itemCategory.name),
                    style: TextStyle(
                      color: context.palette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: expanded ? 24 : 15,
                  color: context.palette.muted,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            color: context.palette.mist.withValues(alpha: .62),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in itemCategory.items)
                      SizedBox(
                        width: width,
                        height: 58,
                        child: OutlinedButton(
                          key: ValueKey(
                            'catalog-item-${itemCategory.name}-${item.name}',
                          ),
                          onPressed: () => _selectPreset(itemCategory, item),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: context.palette.paper,
                            foregroundColor: context.palette.ink,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            context.l10n.itemPresetLabel(item.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _searchResults() {
    final query = search.text.trim();
    final matches = <({_ItemCatalogCategory category, _ItemPreset item})>[];
    for (final itemCategory in _itemCatalog) {
      for (final item in itemCategory.items) {
        if (itemCategory.name.contains(query) ||
            item.name.contains(query) ||
            context.l10n
                .itemCategoryLabel(itemCategory.name)
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            context.l10n
                .itemPresetLabel(item.name)
                .toLowerCase()
                .contains(query.toLowerCase())) {
          matches.add((category: itemCategory, item: item));
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          matches.isEmpty
              ? context.l10n.searchNoItems
              : context.l10n.searchResults,
          style: TextStyle(
            color: context.palette.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (matches.isEmpty)
          BreezeSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.addCustomItemHint(query)),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('add-custom-search-item'),
                  onPressed: () {
                    final other = _itemCatalog.last;
                    _selectPreset(other, other.items.single, custom: query);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.l10n.addOtherItem),
                ),
              ],
            ),
          )
        else
          BreezeSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < matches.length; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: context.palette.divider),
                  ListTile(
                    key: ValueKey(
                      'search-item-${matches[index].category.name}-${matches[index].item.name}',
                    ),
                    leading: Icon(
                      matches[index].item.icon ?? matches[index].category.icon,
                      color: context.palette.primary,
                    ),
                    title: Text(
                      context.l10n.itemPresetLabel(matches[index].item.name),
                    ),
                    subtitle: Text(
                      context.l10n.itemCategoryLabel(
                        matches[index].category.name,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () => _selectPreset(
                      matches[index].category,
                      matches[index].item,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _selectedItemSummary() => BreezeSurface(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.palette.mist,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _selectedPresetIcon,
            size: 31,
            color: context.palette.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.itemPresetLabel(_selectedPresetName ?? ''),
                style: TextStyle(
                  color: context.palette.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.itemCategoryLabel(category),
                style: TextStyle(color: context.palette.muted),
              ),
            ],
          ),
        ),
        TextButton(
          key: const Key('change-selected-item'),
          onPressed: _returnToSelection,
          child: Text(context.l10n.changeSelection),
        ),
      ],
    ),
  );

  Widget _optionalInfoGroup() => BreezeSurface(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        _inlineField(
          customName,
          context.l10n.customItemNameLabel,
          context.l10n.customItemNameHint,
          const Key('custom-item-name'),
        ),
        Divider(height: 1, color: context.palette.divider),
        _spaceSelectorRow(),
        Divider(height: 1, color: context.palette.divider),
        _inlineField(
          location,
          context.l10n.specificLocationOptional,
          context.l10n.specificLocationHint,
          const Key('item-location'),
        ),
        Divider(height: 1, color: context.palette.divider),
        InkWell(
          key: const Key('toggle-brand-model'),
          onTap: () => setState(() {
            _brandModelExpanded = !_brandModelExpanded;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.brandAndModel,
                    style: TextStyle(color: context.palette.ink, fontSize: 16),
                  ),
                ),
                Text(
                  [
                        brand.text,
                        model.text,
                      ].where((x) => x.isNotEmpty).join(' · ').isEmpty
                      ? context.l10n.canAddLater
                      : [
                          brand.text,
                          model.text,
                        ].where((x) => x.isNotEmpty).join(' · '),
                  style: TextStyle(color: context.palette.muted, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Icon(
                  _brandModelExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: context.palette.muted,
                  size: _brandModelExpanded ? 22 : 14,
                ),
              ],
            ),
          ),
        ),
        if (_brandModelExpanded) ...[
          Divider(height: 1, color: context.palette.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(brand, context.l10n.itemBrand)),
              const SizedBox(width: 10),
              Expanded(child: _field(model, context.l10n.itemModel)),
            ],
          ),
        ],
      ],
    ),
  );

  String get _selectedSpaceName {
    final space = widget.store.spaceById(_selectedSpaceId);
    return space == null
        ? context.l10n.unassignedSpace
        : context.l10n.spaceNameLabel(space);
  }

  Widget _spaceSelectorField() => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Semantics(
      button: true,
      label: context.l10n.selectSpace,
      value: _selectedSpaceName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('item-space-selector'),
          borderRadius: BorderRadius.circular(4),
          onTap: _selectSpace,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: context.l10n.spaceFieldLabel,
              border: const OutlineInputBorder(),
            ),
            child: Row(
              children: [
                Expanded(child: Text(_selectedSpaceName)),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 17,
                  color: context.palette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _spaceSelectorRow() => InkWell(
    key: const Key('item-space-selector'),
    onTap: _selectSpace,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 17),
      child: Row(
        children: [
          Text(
            context.l10n.spaceFieldLabel,
            style: TextStyle(color: context.palette.ink, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedSpaceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(color: context.palette.muted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 7),
          Icon(
            CupertinoIcons.chevron_right,
            color: context.palette.muted,
            size: 16,
          ),
        ],
      ),
    ),
  );

  Future<void> _selectSpace() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectSpacePage(
          store: widget.store,
          selectedSpaceId: _selectedSpaceId,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedSpaceId = selected == _unassignedSpaceSelection
          ? null
          : selected;
    });
  }

  Widget _inlineField(
    TextEditingController controller,
    String label,
    String hint,
    Key key,
  ) => TextFormField(
    key: key,
    controller: controller,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ),
  );

  Widget _advancedInfoGroup() => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BreezeSurface(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(
        children: [
          InkWell(
            key: const Key('toggle-advanced-item-details'),
            onTap: () => setState(() {
              _advancedExpanded = !_advancedExpanded;
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.advancedItemInformation,
                          style: TextStyle(
                            color: context.palette.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.l10n.fillWhenNeeded,
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _advancedExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.palette.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_advancedExpanded) ...[
            Divider(height: 1, color: context.palette.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(
                    purchasePrice,
                    context.l10n.purchasePriceCny,
                    type: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => _nonNegativeNumber(context, value),
                  ),
                  _field(
                    currentValue,
                    context.l10n.currentValueCny,
                    type: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => _nonNegativeNumber(context, value),
                  ),
                  _dateTile(
                    context.l10n.itemPurchaseDate,
                    purchase,
                    (d) => setState(() => purchase = d),
                  ),
                  _dateTile(
                    context.l10n.itemWarrantyEnd,
                    warranty,
                    (d) => setState(() => warranty = d),
                  ),
                  const SizedBox(height: 6),
                  MaintenancePlansEditorSection(
                    plans: plans,
                    records: widget.item?.records ?? const [],
                    onChanged: (value) => setState(() => plans = value),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.documentPhotos,
                    style: TextStyle(
                      color: context.palette.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _photos(),
                  const SizedBox(height: 16),
                  _field(notes, context.l10n.itemNotes, maxLines: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  ({_ItemCatalogCategory category, _ItemPreset item})? _findPreset(
    String name,
  ) {
    for (final itemCategory in _itemCatalog) {
      for (final item in itemCategory.items) {
        if (item.name == name) return (category: itemCategory, item: item);
      }
    }
    return null;
  }

  void _selectPreset(
    _ItemCatalogCategory itemCategory,
    _ItemPreset item, {
    String? custom,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      category = itemCategory.name;
      _selectedPresetName = item.name;
      _selectedPresetIcon = item.icon ?? itemCategory.icon;
      customName.text = custom ?? '';
      name.text = context.l10n.itemPresetLabel(item.name);
      _showSupplement = true;
      _allowSupplementPop = false;
      _advancedExpanded = false;
      _brandModelExpanded = false;
    });
  }

  void _returnToSelection() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _showSupplement = false);
  }

  void _toggleAllCategories() {
    setState(() {
      if (_expandedCategories.length == _itemCatalog.length) {
        _expandedCategories.clear();
      } else {
        _expandedCategories
          ..clear()
          ..addAll(_itemCatalog.map((entry) => entry.name));
      }
    });
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? type,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return context.l10n.itemNameRequired;
        }
        return validator?.call(value);
      },
    ),
  );
  Widget _category() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      button: true,
      label: context.l10n.chooseCategory,
      value: context.l10n.itemCategoryLabel(category),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('edit-item-category-field'),
          borderRadius: BorderRadius.circular(16),
          onTap: _selectCategory,
          child: InputDecorator(
            isEmpty: false,
            decoration: InputDecoration(
              labelText: context.l10n.itemCategory,
              border: const OutlineInputBorder(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.itemCategoryLabel(category),
                    key: const Key('edit-item-category-value'),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 17,
                  color: context.palette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _selectCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final initialIndex = categories.indexOf(category);
    var draftCategory = category;
    final scrollController = FixedExtentScrollController(
      initialItem: initialIndex < 0 ? 0 : initialIndex,
    );

    try {
      final selected = await showCupertinoModalPopup<String>(
        context: context,
        barrierColor: context.palette.scrim,
        semanticsDismissible: true,
        builder: (sheetContext) => CupertinoTheme(
          data: CupertinoThemeData(
            brightness: sheetContext.palette.brightness,
            primaryColor: sheetContext.palette.primary,
            scaffoldBackgroundColor: sheetContext.palette.paper,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: sheetContext.palette.ink,
              fontSize: 17,
              decoration: TextDecoration.none,
            ),
            child: Container(
              key: const Key('edit-item-category-sheet'),
              height: 356,
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(sheetContext).bottom,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: sheetContext.palette.paper,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 9),
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: sheetContext.palette.handle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: CupertinoButton(
                            key: const Key('cancel-edit-item-category'),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text(sheetContext.l10n.commonCancel),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            sheetContext.l10n.chooseCategory,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sheetContext.palette.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 84,
                          child: CupertinoButton(
                            key: const Key('confirm-edit-item-category'),
                            padding: EdgeInsets.zero,
                            onPressed: () =>
                                Navigator.pop(sheetContext, draftCategory),
                            child: Text(
                              sheetContext.l10n.commonDone,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: sheetContext.palette.border),
                  Expanded(
                    child: CupertinoPicker(
                      key: const Key('edit-item-category-picker'),
                      scrollController: scrollController,
                      itemExtent: 46,
                      diameterRatio: 1.25,
                      magnification: 1.04,
                      useMagnifier: true,
                      backgroundColor: sheetContext.palette.paper,
                      onSelectedItemChanged: (index) {
                        draftCategory = categories[index];
                      },
                      children: [
                        for (final option in categories)
                          Center(
                            child: Text(
                              sheetContext.l10n.itemCategoryLabel(option),
                              style: TextStyle(
                                color: sheetContext.palette.ink,
                                fontSize: 20,
                                letterSpacing: -0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (selected != null && selected != category && mounted) {
        setState(() => category = selected);
      }
    } finally {
      scrollController.dispose();
    }
  }

  Widget _photos() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ...photos.map(
        (p) => Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(p),
                width: 82,
                height: 82,
                fit: BoxFit.cover,
                cacheWidth: 164,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 82,
                  height: 82,
                  child: Icon(Icons.broken_image),
                ),
              ),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: context.palette.raised,
                ),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () {
                  setState(() => photos.remove(p));
                  if (_newPhotoPaths.remove(p)) {
                    unawaited(widget.store._deletePhoto(p));
                  }
                },
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      ),
      InkWell(
        onTap: _addPhoto,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            border: Border.all(color: context.palette.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_a_photo_outlined),
        ),
      ),
    ],
  );
  Widget _dateTile(String label, DateTime? date, ValueChanged<DateTime?> set) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: BreezeSurface(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.palette.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _localizedDate(context, date),
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (date != null)
                    IconButton(
                      onPressed: () => set(null),
                      icon: const Icon(Icons.clear),
                    ),
                  IconButton(
                    onPressed: () async {
                      final result = await showAppDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: date ?? DateTime.now(),
                      );
                      if (result != null) set(result);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                child: Text(
                  sheet.l10n.addDocumentPhoto,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: sheet.palette.ink,
                  ),
                ),
              ),
              BreezeSurface(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    PhotoSourceRow(
                      icon: Icons.photo_camera_outlined,
                      title: sheet.l10n.takePhoto,
                      subtitle: sheet.l10n.photoCameraSubtitle,
                      source: ImageSource.camera,
                    ),
                    Divider(height: 1, color: sheet.palette.divider),
                    PhotoSourceRow(
                      icon: Icons.photo_library_outlined,
                      title: sheet.l10n.chooseFromPhotos,
                      subtitle: sheet.l10n.photoLibrarySubtitle,
                      source: ImageSource.gallery,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final result = await widget.store.importPhoto(source);
    if (!mounted) {
      if (result.path case final path?) {
        await widget.store.discardImportedPhoto(path);
      }
      return;
    }
    if (result.path != null) {
      setState(() {
        photos.add(result.path!);
        _newPhotoPaths.add(result.path!);
      });
    } else if (result.permission case final permission?) {
      await showSystemPermissionAlert(
        context,
        permission: permission,
        state: result.permissionState!,
      );
    } else if (result.error) {
      AppToast.show(
        context,
        source == ImageSource.camera
            ? context.l10n.cameraOpenFailed
            : context.l10n.photoReadFailed,
        style: AppToastStyle.error,
      );
    }
  }

  Future<void> _save() async {
    if (widget.item == null && _selectedPresetName == null) return;
    if (widget.item == null) {
      final hiddenAdvancedError =
          _nonNegativeNumber(context, purchasePrice.text) ??
          _nonNegativeNumber(context, currentValue.text);
      if (hiddenAdvancedError != null) {
        setState(() => _advancedExpanded = true);
        AppToast.show(context, hiddenAdvancedError, style: AppToastStyle.error);
        return;
      }
    }
    if (!(form.currentState?.validate() ?? false)) return;
    final resolvedName = widget.item == null
        ? (customName.text.trim().isEmpty
              ? context.l10n.itemPresetLabel(_selectedPresetName!)
              : customName.text.trim())
        : name.text.trim();
    final selectedSpace = widget.store.spaceById(_selectedSpaceId);
    final locationDetail = location.text.trim();
    final locationFallback = [
      if (selectedSpace != null) selectedSpace.name,
      if (locationDetail.isNotEmpty) locationDetail,
    ].join(' · ');
    final item =
        (widget.item ??
                CareItem(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: '',
                  category: category,
                  location: '',
                  brand: '',
                  model: '',
                  notes: '',
                  photos: [],
                ))
            .copyWith(
              name: resolvedName,
              category: category,
              location: locationFallback,
              spaceId: selectedSpace?.id,
              clearSpaceId: selectedSpace == null,
              locationDetail: locationDetail,
              brand: brand.text.trim(),
              model: model.text.trim(),
              notes: notes.text.trim(),
              photos: photos,
              plans: plans,
              purchaseDate: purchase,
              warrantyDate: warranty,
              purchasePrice: double.tryParse(purchasePrice.text.trim()),
              currentValue: double.tryParse(currentValue.text.trim()),
              clearPurchasePrice: purchasePrice.text.trim().isEmpty,
              clearCurrentValue: currentValue.text.trim().isEmpty,
              clearPurchaseDate: purchase == null,
              clearWarrantyDate: warranty == null,
            );
    try {
      await widget.store.save(item);
      _saved = true;
      await _offerNotificationFor(item);
      if (mounted) {
        setState(() => _allowSupplementPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.itemSaveFailed,
          style: AppToastStyle.error,
        );
      }
    }
  }

  Future<void> _offerNotificationFor(CareItem item) async {
    try {
      if (item.nextCareDate == null || !mounted) return;
      if (!await widget.store.shouldOfferNotificationPrimer() || !mounted) {
        return;
      }
      await widget.store.markNotificationPrimerSeen();
      if (!mounted) return;
      final proceed = await _showNotificationPrimer(context);
      if (!proceed || !mounted) return;
      final access = await widget.store.requestNotifications();
      if (!mounted) return;
      if (access == NotificationAccess.denied) {
        await showSystemPermissionAlert(
          context,
          permission: SystemPermissionKind.notifications,
          state: SystemPermissionState.denied,
        );
      } else if (access == NotificationAccess.unavailable) {
        await showSystemPermissionAlert(
          context,
          permission: SystemPermissionKind.notifications,
          state: SystemPermissionState.unavailable,
        );
      } else {
        final message = access == NotificationAccess.enabled
            ? context.l10n.remindersEnabledTitle
            : context.l10n.notificationsNotEnabled;
        AppToast.show(
          context,
          message,
          style: access == NotificationAccess.enabled
              ? AppToastStyle.success
              : AppToastStyle.info,
        );
      }
    } catch (_) {
      // Notification setup must never turn a successful item save into failure.
    }
  }
}
