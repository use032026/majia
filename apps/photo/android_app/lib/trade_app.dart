import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'core/config/brand_config.dart';
import 'core/config/startup_service.dart';
import 'core/config/theme_service.dart';
import 'core/services/app_locale_service.dart';
import 'core/services/app_lifecycle_version_refresher.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/ios_language_catalog.dart';
import 'core/providers/available_languages_provider.dart';
import 'core/providers/country_manager_provider.dart';
import 'core/router/app_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'core/services/ct_timer_helper.dart';
import 'core/models/user_state.dart';
import 'core/services/version_update_service.dart';
import 'core/network/st_service.dart';
import 'core/debug/debug_log_filter.dart';
import 'features/startup/startup_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runAppWithLogFilter(() => runApp(buildTradeAppRoot()));
}

Widget buildTradeAppRoot() {
  installDebugLogFilter();

  if (!kIsWeb && WebViewPlatform.instance is WebKitWebViewPlatform) {
    WebViewPlatform.instance = WebKitWebViewPlatform();
  }

  if (!kWebViewLogsOnly) {
    final brand = BrandConfig.jufu();
    final buildMode = BrandConfig.currentBuildMode;
    final compileMode = switch (buildMode) {
      AppBuildMode.release => 'Release',
      AppBuildMode.profile => 'Profile',
      AppBuildMode.debug => 'Debug',
    };
    final dioPkg = brand.packageNameForBuildMode;
    debugPrint('══════════════════════════════════════');
    debugPrint('Flutter 启动 | 编译模式: $compileMode');
    debugPrint('API Debug   : ${brand.apiDomainDebug}');
    debugPrint('API Profile : ${brand.apiDomainProfile}');
    debugPrint('API Release : ${brand.apiDomainRelease}');
    debugPrint('当前 API 基址: ${brand.apiBaseUrlForBuildMode}/violet');
    debugPrint('H5 Debug    : ${brand.h5DomainDebug}');
    debugPrint('H5 Profile  : ${brand.h5DomainProfile}');
    debugPrint('H5 Release  : ${brand.h5DomainRelease}');
    debugPrint('当前 H5 根  : ${brand.h5BaseUrlForBuildMode}');
    debugPrint('当前 dioPkg： $dioPkg');
    debugPrint('══════════════════════════════════════');
  }

  return const ProviderScope(child: JufuApp());
}

class JufuApp extends ConsumerStatefulWidget {
  const JufuApp({super.key});

  @override
  ConsumerState<JufuApp> createState() => JufuAppState();
}

class JufuAppState extends ConsumerState<JufuApp> with WidgetsBindingObserver {
  final AppLifecycleVersionRefresher _resumeVersionRefresher =
      AppLifecycleVersionRefresher();
  late final CTTimerHelper _ctTimerHelper;
  int _rootGeneration = 0;

  /// 切换语言后重建整个应用 UI（对齐 iOS STRouterManager.requestReloadRootControllerCallback）
  void reload() {
    if (mounted) {
      setState(() => _rootGeneration += 1);
    }
  }

  void _startKernelRouteTimer() {
    _ctTimerHelper.start(
      AppRouter.router,
      isLoggedIn: () => ref.read(userStateProvider).isLogin,
    );
  }

  @override
  void initState() {
    super.initState();
    _ctTimerHelper = ref.read(ctTimerHelperProvider);
    _startKernelRouteTimer();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final p = await PackageInfo.fromPlatform();
        debugPrint(
          '📦 安装包名: ${p.packageName}  version=${p.version} (${p.buildNumber})',
        );
      } catch (e) {
        debugPrint('📦 PackageInfo 读取失败: $e');
      }
    });
  }

  @override
  void dispose() {
    if (_ctTimerHelper.isRunning) {
      _ctTimerHelper.stop();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumeVersionRefresher.didChangeAppLifecycleState(
      state,
      context: context,
      stService: ref.read(stServiceProvider),
      versionUpdateService: ref.read(versionUpdateServiceProvider),
      customerServiceUrl: ref
          .read(userStateProvider)
          .h5AddressModel
          ?.customerSupportUrl,
      onNeedUpdatePassword: _goNeedUpdatePasswordIfNeeded,
    );
  }

  Future<void> _goNeedUpdatePasswordIfNeeded() async {
    if (!mounted) return;
    final user = ref.read(userStateProvider);
    if (user.needUpdatePassword && user.isExplicitlyLoggedIn) {
      context.go('/mine/change_login_password');
    }
  }

  /// 启动完成后检查版本更新弹窗（对齐 iOS: STRootViewController.requestVersionUpdate）
  /// 版本更新 API 在 startup_service 中已调用（用于 A/B 值），
  /// 此处复用其响应数据，避免重复 API 调用。
  Future<void> _checkVersionUpdateAfterStartup(StartupResult result) async {
    if (result.versionRawResponse == null) return;
    try {
      final stService = ref.read(stServiceProvider);
      if (!mounted) return;
      final versionService = ref.read(versionUpdateServiceProvider);
      final userState = ref.read(userStateProvider);
      await versionService.checkVersionUpdate(
        context: context,
        stService: stService,
        prefetchedResponse: result.versionRawResponse,
        customerServiceUrl: userState.h5AddressModel?.customerSupportUrl,
        onNeedUpdatePassword: _goNeedUpdatePasswordIfNeeded,
      );
    } catch (e) {
      debugPrint('📢 Version update check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final rootGeneration = _rootGeneration;

    return StartupGate(
      key: ValueKey('jufu-root-$rootGeneration'),
      locale: locale,
      themeMode: themeMode,
      onStartupReady: _checkVersionUpdateAfterStartup,
      appBuilder: (context, result) {
        final brand = result.brand;

        ref.watch(countrySessionBindingProvider);

        final apiLangOptions = ref.watch(availableLanguagesProvider);
        final supportedLocales = <Locale>{
          ...IosLanguageCatalog.supportedMaterialLocales(),
          ...apiLangOptions.map(
            (o) => IosLanguageCatalog.localeFromCode(o.code),
          ),
        }.toList();

        return MaterialApp.router(
          key: ValueKey('jufu-material-$rootGeneration'),
          title: brand.appNameZh,
          theme: AppTheme.light(brand),
          darkTheme: AppTheme.dark(brand),
          themeMode: themeMode, // 使用持久化的主题模式
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
          // 本地文本走 iOS JSON 语言包；这里只保留 Flutter 系统组件本地化。
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedLocales,
          locale: locale,
        );
      },
    );
  }
}
