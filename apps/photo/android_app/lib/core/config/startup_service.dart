import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'brand_config.dart';
import 'config_data_manager.dart';
import 'phone_verification_runtime.dart';
import '../constants/ios_language_catalog.dart';
import '../network/st_service.dart';
import '../network/st_dio.dart';
import '../network/device_id_manager.dart';
import '../models/h5_address_payload.dart';
import '../models/user_state.dart';
import '../services/apple_credential_launch_guard.dart';
import '../providers/available_languages_provider.dart';
import '../providers/country_manager_provider.dart';
import '../services/app_locale_service.dart';
import '../services/startup_device_registrar.dart';
import '../services/startup_line_bootstrapper.dart';
import '../services/user_preference_prefs.dart';

bool _isLoggedInOnAnotherDevice(Object error) {
  return error is STBusinessResponseException &&
      error.isLoggedInOnAnotherDevice;
}

@visibleForTesting
String startupVersionLanguageForIos({
  required String savedLanguageCode,
  required Locale platformLocale,
}) {
  final saved = savedLanguageCode.trim();
  if (saved.isNotEmpty) {
    return IosLanguageCatalog.canonicalize(saved);
  }
  return UserPreferencePrefs.defaultAppLanguageForPlatformLocale(
    platformLocale,
  );
}

/// 启动流程服务
/// 对齐 iOS STRootViewController 启动逻辑
///
/// 启动后写入 ConfigDataManager，驱动 TabShell 渲染
class StartupService {
  final STService? stService;
  final BrandConfig brand;
  final ConfigDataManager configDataManager;
  final StartupDeviceRegistrar deviceRegistrar;
  final StartupLineBootstrapper lineBootstrapper;

  StartupService({
    this.stService,
    BrandConfig? brand,
    required this.configDataManager,
    StartupDeviceRegistrar? deviceRegistrar,
    StartupLineBootstrapper? lineBootstrapper,
  }) : brand = brand ?? BrandConfig.jufu(),
       deviceRegistrar = deviceRegistrar ?? const StartupDeviceRegistrar(),
       lineBootstrapper = lineBootstrapper ?? const StartupLineBootstrapper();

  /// 完整启动流程（传入 [ref]：恢复持久化会话、匿名登录后同步 UserState）
  Future<StartupResult> start(Ref ref) async {
    try {
      // 0. 初始化设备 ID + 包信息（对齐 iOS: NSBundle mainBundle + AppDeviceIdTool）
      // 对齐 iOS: 先加载持久化设备 UUID（X-Request-Id 来源），再获取包信息
      final deviceId = await DeviceIdManager.getDeviceId();
      debugPrint('📱 Device ID: $deviceId');

      PackageInfo packageInfo;
      try {
        packageInfo = await PackageInfo.fromPlatform();
      } catch (_) {
        // 测试环境可能获取不到
        packageInfo = PackageInfo(
          appName: 'jufu',
          packageName: 'com.jufu.lite.test',
          version: '1.0.0',
          buildNumber: '1',
          buildSignature: '',
        );
      }

      final savedLang = IosLanguageCatalog.canonicalize(
        await UserPreferencePrefs.readAppLanguage(),
      );

      // 设置动态请求头（对齐 iOS STVersionTwoRequest.requestRequireParams）
      // 在发起任何 API 请求前完成，确保后续请求携带正确值
      if (stService != null) {
        stService!.dio.setRequestId(deviceId);
        stService!.dio.setAppVersion(packageInfo.version);
        // X-Version / systemVersion — 暂时保持硬编码 fallback 值
        // X-Device-Model — 暂时保持硬编码 fallback 值
        stService!.dio.setLanguage(savedLang);
        debugPrint(
          '📱 Headers set: appVersion=${packageInfo.version}, language=$savedLang, deviceId=$deviceId',
        );
        await deviceRegistrar.registerIfPossible(stService!);
      }

      await ref.read(userStateProvider.notifier).restoreLocalPreferences();

      // 1. 加载品牌配置
      BrandConfig currentBrand = brand;

      // 1.5 读取动态主题字典（对齐 iOS: STStartViewController.getTheme -> STAPPStartThemeKey）
      if (stService != null) {
        try {
          final themePayload = await stService!.getStartupThemeConfig();
          if (themePayload != null && themePayload.isNotEmpty) {
            final themeData = _normalizeStartupThemePayload(themePayload);
            final currentThemeName =
                themePayload['current_theme'] ??
                themePayload['STAPPStartCurrentThemeKey'] ??
                themePayload['currentThemeKey'];
            if (themeData.isNotEmpty ||
                (currentThemeName is String &&
                    currentThemeName.trim().isNotEmpty)) {
              currentBrand = currentBrand.withStartupThemeData(
                startupThemeData: themeData.isNotEmpty
                    ? themeData
                    : currentBrand.startupThemeData,
                currentThemeKey:
                    currentThemeName is String &&
                        currentThemeName.trim().isNotEmpty
                    ? currentThemeName
                    : null,
              );
            }
          }
        } catch (e) {
          if (!_isMissingOptionalStartupThemeConfig(e)) {
            debugPrint('⚠️ Failed to load startup theme config: $e');
          }
        }
      }

      // 2–3. 会话恢复或匿名登录；版本检查与用户信息预热并行（对齐 iOS 时序上仍需在 app config 前有 versionData，
      //      此处与会话请求并行，再在步骤 4 前保证已完成）。
      //    已登录：token →（并行）user/info + bootstrap + checkVersion
      //    未登录：匿名登录 → login →（并行）同上
      bool isLoggedIn = false;
      bool versionCheckAttempted = false;
      Map<String, dynamic>? versionData;
      Map<String, dynamic>? versionRawResponse;

      Future<void> runVersionCheck() async {
        if (stService == null) return;
        versionCheckAttempted = true;
        try {
          final locale = PlatformDispatcher.instance.locale;
          final raw = await lineBootstrapper.run(
            stage: StartupLineBootstrapStage.versionCheck,
            request: () => stService!.checkVersion(
              system: 'IOS',
              localVersion: packageInfo.version,
              pkgId: stService!.dio.pkgName,
              language: startupVersionLanguageForIos(
                savedLanguageCode: savedLang,
                platformLocale: locale,
              ),
              channel: 'AppStore',
            ),
          );
          versionRawResponse = raw;
          final inner = raw['data'];
          versionData = inner is Map<String, dynamic> ? inner : raw;
        } catch (e) {
          debugPrint('⚠️ Version check failed');
        }
      }

      if (stService != null) {
        final userNotifier = ref.read(userStateProvider.notifier);
        final restored = await userNotifier.restoreLogin();

        if (restored) {
          final tok = ref.read(userStateProvider).token;
          if (tok.isNotEmpty) {
            stService!.dio.setAuthToken(tok);
            isLoggedIn = true;
            debugPrint('✅ Restored persisted session');
            try {
              unawaited(userNotifier.bootstrapLoggedInSession(stService!));
              await Future.wait([
                userNotifier.refreshProfileAfterLogin(stService!),
                runVersionCheck(),
              ]);
              try {
                final profile = await stService!.getUserProfile();
                final d = profile['data'];
                if (d is Map<String, dynamic>) {
                  await syncCountryManagerFromProfile(
                    ref.read(countryManagerProvider.notifier),
                    userId: ref.read(userStateProvider).userId,
                    countryKey: UserState.pickString(d, ['country']),
                  );
                }
              } catch (_) {}
            } catch (e) {
              debugPrint('⚠️ Post-restore user bootstrap failed: $e');
            }
          }
        }

        if (!isLoggedIn) {
          try {
            final response = await lineBootstrapper.run(
              stage: StartupLineBootstrapStage.anonymousLogin,
              request: stService!.anonymousLogin,
            );
            debugPrint('Anonymous login response code: ${response['code']}');

            final anonCode = response['code'];
            if (anonCode is num && anonCode != 0) {
              debugPrint('Anonymous login rejected code=$anonCode');
            } else {
              final data = response['data'];
              if (data is Map<String, dynamic>) {
                final token = data['token'] as String?;
                if (token != null && token.isNotEmpty) {
                  stService!.dio.setAuthToken(token);
                  isLoggedIn = true;
                  debugPrint('Anonymous auth token set on Dio');
                  try {
                    await userNotifier.establishAnonymousSession(
                      Map<String, dynamic>.from(data),
                    );
                    await runVersionCheck();
                  } catch (e) {
                    debugPrint('Anonymous session UserState sync failed: $e');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('ℹ️ Anonymous login failed: $e');
          }
        }

        if (isLoggedIn) {
          try {
            await ref.read(appLocaleProvider.notifier).reloadFromPrefs();
          } catch (e) {
            debugPrint('⚠️ reload app locale from prefs failed: $e');
          }
        }
      }

      // 未拿到会话时仍需版本检查（供后续 app config / A-B）
      if (stService != null &&
          versionRawResponse == null &&
          !versionCheckAttempted) {
        await runVersionCheck();
      }

      // 4. 拉取应用配置（此时 isB/andC/bLan 已就绪，ConfigDataManager 可以在解析时使用）
      // 对齐 iOS: STStartViewController -> requestAppConfigInfoWithCompletion
      Map<String, dynamic>? appConfig;
      if (stService != null) {
        Future<Map<String, dynamic>?> requestAppConfig() {
          return lineBootstrapper.run(
            stage: StartupLineBootstrapStage.appConfig,
            request: () =>
                stService!.getAppConfig(brandCode: currentBrand.brandKey),
          );
        }

        Future<void> applyAppConfig(
          Map<String, dynamic> config, {
          required String source,
        }) async {
          debugPrint(
            'AppSatrt - TabbarConfig ${tabBarConfigDebugSummary(config, source)}',
          );
          configDataManager.parseAppConfig(config);
          await configDataManager.saveAppConfigToCache(config);
          debugPrint(
            '✅ ConfigDataManager initialized: ${configDataManager.tabs.length} tabs',
          );
        }

        Future<Map<String, dynamic>?> loadCachedAppConfig({
          required String source,
        }) async {
          final cached = await configDataManager.loadAppConfigFromCache();
          if (cached != null) {
            debugPrint(
              'AppSatrt - TabbarConfig ${tabBarConfigDebugSummary(cached, source)}',
            );
            configDataManager.parseAppConfig(cached);
            debugPrint(
              '✅ ConfigDataManager initialized from cache: ${configDataManager.tabs.length} tabs',
            );
          }
          return cached;
        }

        Future<void> recoverFromOtherDeviceLogin() async {
          debugPrint(
            '⚠️ App config hit other-device login; clearing session and retrying',
          );
          await ref.read(userStateProvider.notifier).logout();
          stService!.dio.setAuthToken(null);
          isLoggedIn = false;
          try {
            final response = await lineBootstrapper.run(
              stage: StartupLineBootstrapStage.anonymousLogin,
              request: stService!.anonymousLogin,
            );
            final anonCode = response['code'];
            final data = response['data'];
            if ((anonCode == null || anonCode == 0) &&
                data is Map<String, dynamic>) {
              final token = data['token'] as String?;
              if (token != null && token.isNotEmpty) {
                stService!.dio.setAuthToken(token);
              }
              await ref
                  .read(userStateProvider.notifier)
                  .establishAnonymousSession(data);
            }
          } catch (e) {
            debugPrint('ℹ️ Anonymous login after forced logout failed: $e');
          }
        }

        try {
          appConfig = await requestAppConfig();
          if (appConfig != null) {
            await applyAppConfig(appConfig, source: 'remote_response');
          }
        } catch (e) {
          if (_isLoggedInOnAnotherDevice(e)) {
            await recoverFromOtherDeviceLogin();
            try {
              appConfig = await requestAppConfig();
              if (appConfig != null) {
                await applyAppConfig(appConfig, source: 'remote_response');
              }
            } catch (retryError) {
              debugPrint(
                '⚠️ Retry app config after forced logout failed: $retryError',
              );
            }
            appConfig ??= await loadCachedAppConfig(
              source: 'request_cache_fallback',
            );
            if (appConfig == null) {
              debugPrint('⚠️ Get app config failed after forced logout');
            }
          } else {
            debugPrint('⚠️ Get app config failed, trying cache: $e');
            appConfig = await loadCachedAppConfig(
              source: 'request_cache_fallback',
            );
          }
        }
      }

      // 5–8. 与主流程无先后依赖的请求并行，避免弱网下多次 15s 超时串联卡住启动页
      Map<String, dynamic>? h5AddressData;
      final configH5AddressData = normalizeH5AddressPayload(
        configDataManager.h5Config,
      );
      final shouldSupplementH5Address = _shouldSupplementH5Address(
        configH5AddressData,
      );
      if (configH5AddressData.isNotEmpty) {
        h5AddressData = configH5AddressData;
      }
      if (stService != null) {
        await Future.wait([
          () async {
            if (!shouldSupplementH5Address) return;
            try {
              final remoteH5AddressData = await stService!.getH5Addresses();
              if (remoteH5AddressData.isNotEmpty) {
                configDataManager.mergeH5AddressData(remoteH5AddressData);
                h5AddressData = normalizeH5AddressPayload(
                  configDataManager.h5Config,
                );
                debugPrint('✅ H5 addresses loaded and merged');
              }
            } catch (e) {
              debugPrint('⚠️ Get H5 addresses failed: $e');
            }
          }(),
          () async {
            try {
              await ref.read(countryManagerProvider.notifier).ensureLoaded();
            } catch (e) {
              debugPrint('⚠️ Get country list failed: $e');
            }
          }(),
          () async {
            try {
              final raw = await stService!.getPhoneVerificationMethod();
              ref
                  .read(phoneVerificationRuntimeProvider.notifier)
                  .applyResponse(raw);
            } catch (e) {
              debugPrint('⚠️ getPhoneVerificationMethod failed: $e');
            }
          }(),
          () async {
            try {
              final rawLang = await stService!.getAvailableLanguages();
              ref
                  .read(availableLanguagesProvider.notifier)
                  .applyFromRawResponse(rawLang);
            } catch (e) {
              debugPrint('⚠️ Get available languages failed: $e');
            }
          }(),
          () async {
            try {
              final user = ref.read(userStateProvider);
              await stService!.requestRiskReport(
                isLoggedIn: user.isLogin,
                userId: user.userId,
              );
            } catch (e) {
              debugPrint('⚠️ Risk report request failed: $e');
            }
          }(),
        ]);
      }

      // 9. Apple ID 凭据状态（对齐 AppleAuthManager.checkCredentialState）
      await checkAppleCredentialOnColdStart(ref);

      return StartupResult(
        brand: currentBrand,
        isLoggedIn: isLoggedIn,
        configLoaded: appConfig != null,
        appConfig: appConfig,
        versionData: versionData,
        versionRawResponse: versionRawResponse,
        h5AddressData: h5AddressData,
      );
    } catch (e) {
      debugPrint('❌ Startup failed: $e');
      return StartupResult(
        brand: brand,
        isLoggedIn: false,
        configLoaded: false,
      );
    }
  }

  Map<String, String> _asStringMap(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value == null || key.isEmpty) {
        continue;
      }
      result[key.trim()] = value.toString();
    }
    return result;
  }

  Map<String, Map<String, Map<String, String>>> _normalizeStartupThemePayload(
    Map<String, dynamic> payload,
  ) {
    final result = <String, Map<String, Map<String, String>>>{};

    payload.forEach((rawThemeName, rawThemeValue) {
      if (rawThemeName.trim().isEmpty) return;
      final themeName = rawThemeName.trim();
      if (rawThemeValue == null) return;

      final normalizedTheme = <String, Map<String, String>>{};

      if (themeName.contains('_theme')) {
        final normalizedValue = _asStringMap(rawThemeValue);
        if (normalizedValue.isNotEmpty) {
          normalizedTheme['theme'] = normalizedValue;
          result[themeName] = normalizedTheme;
        }
        return;
      }

      if (rawThemeValue is! Map) {
        return;
      }

      for (final e in rawThemeValue.entries) {
        final category = e.key;
        final values = e.value;
        if (category is! String || category.trim().isEmpty || values == null) {
          continue;
        }
        final categoryName = category.trim();
        final map = _asStringMap(values);
        if (map.isNotEmpty) {
          normalizedTheme[categoryName] = map;
        }
      }

      if (normalizedTheme.isNotEmpty) {
        result[themeName] = normalizedTheme;
      }
    });

    return result;
  }
}

bool _shouldSupplementH5Address(Map<String, dynamic> configH5AddressData) {
  if (configH5AddressData.isEmpty) return true;
  return !_hasH5AddressValue(configH5AddressData, [
        'user_agreement_url',
        'agreement_url',
      ]) ||
      !_hasH5AddressValue(configH5AddressData, [
        'privacy_policy_url',
        'privacy_url',
      ]);
}

bool _hasH5AddressValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return true;
    }
  }
  return false;
}

bool _isMissingOptionalStartupThemeConfig(Object error) {
  return error is DioException && error.response?.statusCode == 404;
}

class StartupResult {
  final BrandConfig brand;
  final bool isLoggedIn;
  final bool configLoaded;
  final Map<String, dynamic>? appConfig;
  final Map<String, dynamic>? versionData; // response.data（A/B 值）
  final Map<String, dynamic>?
  versionRawResponse; // 完整响应（code+data，给 version dialog 用）
  final Map<String, dynamic>? h5AddressData;

  StartupResult({
    required this.brand,
    required this.isLoggedIn,
    required this.configLoaded,
    this.appConfig,
    this.versionData,
    this.versionRawResponse,
    this.h5AddressData,
  });
}

/// Riverpod Provider
final startupServiceProvider = Provider<StartupService>((ref) {
  final dio = ref.watch(stDioProvider);
  final service = STService(dio);
  final configMgr = ref.read(configDataManagerProvider);
  return StartupService(
    stService: service,
    configDataManager: configMgr,
    deviceRegistrar: ref.watch(startupDeviceRegistrarProvider),
    lineBootstrapper: ref.watch(startupLineBootstrapperProvider),
  );
});

final startupFutureProvider = FutureProvider<StartupResult>((ref) async {
  final service = ref.read(startupServiceProvider);
  final result = await service.start(ref);

  // 将 A/B 面信息写入 UserState（对齐 iOS: app_update_info 中的 isB/andC/bLan）
  if (result.versionData != null) {
    ref.read(userStateProvider.notifier).updateABTest(result.versionData!);
    ref
        .read(userStateProvider.notifier)
        .updateVersionUpdateInfo(result.versionData!);
  }

  // 将 H5 地址写入 UserState（对齐 iOS: STH5AddressModel）
  if (result.h5AddressData != null && result.h5AddressData!.isNotEmpty) {
    ref.read(userStateProvider.notifier).updateH5Address(result.h5AddressData!);
  }

  return result;
});
