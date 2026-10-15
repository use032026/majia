import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/st_localizations.dart';
import '../network/st_service.dart';
import '../router/customer_service_route.dart';
import '../../shared/widgets/st_toast.dart';

/// 版本更新信息模型
/// 对齐 iOS app_update_info JSON 字段。
class AppUpdateInfo {
  final bool hasUpdate;
  final String version;
  final String downloadUrl;
  final bool isForceUpdate;
  final String? updateDesc;
  final int updateCycleInterval;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.version,
    required this.downloadUrl,
    this.isForceUpdate = false,
    this.updateDesc,
    this.updateCycleInterval = 0,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      hasUpdate: _parseBool(json['has_update']),
      version: _parseString(json['version']) ?? '',
      downloadUrl: _parseString(json['download_url']) ?? '',
      isForceUpdate: _parseBool(json['force_update']),
      updateDesc:
          _parseString(json['update_desc']) ??
          _parseString(json['description']),
      updateCycleInterval: _parseInt(json['update_cycle_interval']),
    );
  }

  factory AppUpdateInfo.fromApiResponse(Map<String, dynamic> response) {
    final code = response['code'];
    if (code is num && code != 0) {
      return AppUpdateInfo.fromJson(<String, dynamic>{});
    }

    final dynamic data = response['data'];
    final Map<String, dynamic>? payload = _asMap(data);
    if (payload == null) {
      return AppUpdateInfo.fromJson(<String, dynamic>{});
    }

    final appUpdate =
        _asMap(payload['app_update_info']) ?? _asMap(payload['appUpdateInfo']);
    if (appUpdate != null) {
      return AppUpdateInfo.fromJson(appUpdate);
    }

    return AppUpdateInfo.fromJson(payload);
  }

  bool get isValidForDisplay {
    return hasUpdate && version.isNotEmpty;
  }

  static bool _parseBool(dynamic raw) {
    if (raw == null) {
      return false;
    }
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    final str = raw.toString().trim().toLowerCase();
    return str == '1' || str == 'true' || str == 'yes';
  }

  static int _parseInt(dynamic raw, {int fallback = 0}) {
    if (raw == null) return fallback;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim()) ?? fallback;
  }

  static String? _parseString(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isNotEmpty ? value : null;
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// 版本更新服务
/// 对齐 iOS:
/// - STRootViewController.requestVersionUpdate
/// - STSetViewController 的 STUpdateAlertView 调用
/// - STService+Launch.version-update-notify
class VersionUpdateService {
  static const Map<String, String> _dialogFallbackText = {
    'new_version': '发现新版本',
    'update_now': '立即更新',
    'update_later': '稍后更新',
    'change_line_footer_contact': '请联系客服',
  };

  /// 调试预览：绕过接口响应、频控和下载地址判断，直接展示更新弹窗样式。
  ///
  /// 用于对齐 iOS `STUpdateAlertView updateWithVersion:message:downloadUrl:hideCancel:`
  /// 的本地预览能力；release/profile 环境不展示。
  Future<void> showDebugPreview({
    required BuildContext context,
    required bool forceUpdate,
  }) async {
    if (!context.mounted) return;

    await _showUpdateDialog(
      context: context,
      info: AppUpdateInfo(
        hasUpdate: true,
        version: '9.9.9',
        downloadUrl: 'https://example.com/app',
        isForceUpdate: forceUpdate,
        updateDesc: '',
      ),
      hideCancel: forceUpdate,
      showCustomerService: forceUpdate,
    );
  }

  /// 检查并展示版本更新弹窗
  ///
  /// `prefetchedResponse` 用于启动阶段复用已拉取的版本接口响应（来自 startup_service）。
  /// `isFromSettings` 用于设置页“版本更新”入口：
  /// - 不做频控间隔控制
  /// - 不发 /version-update-notify
  Future<void> checkVersionUpdate({
    required BuildContext context,
    required STService stService,
    Map<String, dynamic>? prefetchedResponse,
    bool isFromSettings = false,
    bool sendUpdateNotify = true,
    bool respectUpdateCycle = true,
    String? customerServiceUrl,
    Future<void> Function()? onNeedUpdatePassword,
  }) async {
    final initialNavigator = _rootNavigator(context);
    try {
      final languageCode = stLanguageCodeOfContext(context);
      final response =
          prefetchedResponse ??
          await stService.checkVersion(
            system: 'IOS',
            localVersion: '',
            pkgId: stService.dio.pkgName,
            language: languageCode,
            channel: 'AppStore',
          );

      final updateInfo = AppUpdateInfo.fromApiResponse(response);
      if (!updateInfo.isValidForDisplay) {
        if (!isFromSettings) {
          await onNeedUpdatePassword?.call();
        }
        return;
      }

      if (updateInfo.isForceUpdate) {
        final navigator = initialNavigator ?? STToast.navigatorKey.currentState;
        if (navigator == null) return;
        await _runForceUpdateFlow(
          navigator: navigator,
          info: updateInfo,
          stService: stService,
          customerServiceUrl: customerServiceUrl,
          sendUpdateNotify: sendUpdateNotify,
        );
        return;
      }

      if (!isFromSettings && respectUpdateCycle) {
        final canShow = await _canShowWeakUpdate(updateInfo);
        if (!canShow) {
          await onNeedUpdatePassword?.call();
          return;
        }
        await _recordWeakUpdateShow(updateInfo);
      }

      if (!context.mounted) return;
      final action = await _showUpdateDialog(
        context: context,
        info: updateInfo,
        hideCancel: false,
        showCustomerService: false,
      );

      if (action == _UpdateDialogAction.customerService) {
        final location = CustomerServiceRoute.locationFromUrl(
          customerServiceUrl,
        );
        if (location != null && context.mounted) {
          await context.push(location);
        }
      } else if (action == _UpdateDialogAction.update) {
        await _openDownloadUrl(updateInfo.downloadUrl);
        if (sendUpdateNotify) {
          await stService.requestVersionUpdateNotify(
            updateVersion: updateInfo.version,
            pkgId: stService.dio.pkgName,
          );
        }
      } else if (action == _UpdateDialogAction.cancel) {
        await onNeedUpdatePassword?.call();
      }
    } catch (e) {
      debugPrint('📢 Version check dialog error: $e');
    }
  }

  Future<_UpdateDialogAction?> _showUpdateDialog({
    required BuildContext context,
    required AppUpdateInfo info,
    required bool hideCancel,
    required bool showCustomerService,
    bool hasCustomerServiceRoute = true,
  }) async {
    final navigator = _rootNavigator(context);
    if (navigator == null) return null;
    final localizedText = await STLocalizations.ofContext(
      navigator.context,
    ).textMap(_dialogFallbackText);
    if (!navigator.mounted) return null;

    return showGeneralDialog<_UpdateDialogAction>(
      context: navigator.context,
      barrierDismissible: false,
      barrierLabel: localizedText['new_version']!,
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.scale(
            scale: 0.96 + 0.04 * animation.value,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final width = MediaQuery.of(ctx).size.width;
        final dialogWidth = width > 360 ? 320.0 : width - 48;
        const contentColor = Color(0xFF60656D);
        const updateColor = Color(0xFF00B57A);
        const customerServiceBackground = Color(0xFFEEF4FF);
        final headerIconSize = dialogWidth * 0.48;

        Widget buildAction({
          required String label,
          required Color textColor,
          required Color? backgroundColor,
          required _UpdateDialogAction action,
          bool enabled = true,
        }) {
          return SizedBox(
            width: double.infinity,
            height: 40,
            child: InkWell(
              onTap: enabled ? () => Navigator.pop(ctx, action) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: dialogWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 30, 28, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              localizedText['new_version']!,
                              style: const TextStyle(
                                color: Color(0xFF303133),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (info.version.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'v${info.version}',
                                style: const TextStyle(
                                  color: contentColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          if ((info.updateDesc ?? '').isNotEmpty)
                            Text(
                              info.updateDesc!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: contentColor,
                                height: 1.4,
                              ),
                            ),
                          const SizedBox(height: 27),
                          if (hideCancel) ...[
                            if (showCustomerService)
                              buildAction(
                                label:
                                    localizedText['change_line_footer_contact']!,
                                textColor: updateColor,
                                backgroundColor: customerServiceBackground,
                                action: _UpdateDialogAction.customerService,
                                enabled: hasCustomerServiceRoute,
                              ),
                            if (showCustomerService) const SizedBox(height: 7),
                            buildAction(
                              label: localizedText['update_now']!,
                              textColor: Colors.white,
                              backgroundColor: updateColor,
                              action: _UpdateDialogAction.update,
                            ),
                            const SizedBox(height: 18),
                          ] else ...[
                            buildAction(
                              label: localizedText['update_now']!,
                              textColor: Colors.white,
                              backgroundColor: updateColor,
                              action: _UpdateDialogAction.update,
                            ),
                            const SizedBox(height: 7),
                            TextButton(
                              onPressed: () => Navigator.pop(
                                ctx,
                                _UpdateDialogAction.cancel,
                              ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                localizedText['update_later']!,
                                style: const TextStyle(
                                  color: Color(0xFF9A9DA2),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -63,
                    right: -15,
                    child: SizedBox(
                      width: headerIconSize,
                      height: headerIconSize * 473 / 480,
                      child: Image.asset(
                        'assets/images/st_version_update.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.system_update_alt,
                            color: Color(0xFF9FB4E6),
                            size: 20,
                          );
                        },
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

  Future<void> _runForceUpdateFlow({
    required NavigatorState navigator,
    required AppUpdateInfo info,
    required STService stService,
    required String? customerServiceUrl,
    required bool sendUpdateNotify,
  }) async {
    var resolvedCustomerServiceUrl = customerServiceUrl;
    final router = _maybeGoRouterOf(navigator.context);
    while (navigator.mounted) {
      final action = await _showUpdateDialogForNavigator(
        navigator: navigator,
        info: info,
        hideCancel: true,
        showCustomerService: true,
        hasCustomerServiceRoute: true,
      );

      if (action == _UpdateDialogAction.update) {
        await _openDownloadUrl(info.downloadUrl);
        if (sendUpdateNotify) {
          await stService.requestVersionUpdateNotify(
            updateVersion: info.version,
            pkgId: stService.dio.pkgName,
          );
        }
        return;
      }

      if (action != _UpdateDialogAction.customerService) {
        return;
      }

      var location = CustomerServiceRoute.locationFromUrl(
        resolvedCustomerServiceUrl,
      );
      if (location == null) {
        resolvedCustomerServiceUrl = await _fetchCustomerServiceUrl(stService);
        if (!navigator.mounted) return;
        location = CustomerServiceRoute.locationFromUrl(
          resolvedCustomerServiceUrl,
        );
      }
      if (location == null) continue;
      if (router == null) continue;

      await router.push(location);
      final stillNeedsUpdate = await _isCurrentVersionDifferentFrom(
        info.version,
      );
      if (!stillNeedsUpdate) return;
    }
  }

  GoRouter? _maybeGoRouterOf(BuildContext context) {
    try {
      return GoRouter.of(context);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchCustomerServiceUrl(STService stService) async {
    try {
      final data = await stService.getH5Addresses();
      final raw = data['customer_support_url'];
      final value = raw?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    } catch (e) {
      debugPrint('📢 Forced update customer service h5 config failed: $e');
      return null;
    }
  }

  Future<_UpdateDialogAction?> _showUpdateDialogForNavigator({
    required NavigatorState navigator,
    required AppUpdateInfo info,
    required bool hideCancel,
    required bool showCustomerService,
    bool hasCustomerServiceRoute = true,
  }) {
    return _showUpdateDialog(
      context: navigator.context,
      info: info,
      hideCancel: hideCancel,
      showCustomerService: showCustomerService,
      hasCustomerServiceRoute: hasCustomerServiceRoute,
    );
  }

  Future<bool> _isCurrentVersionDifferentFrom(String targetVersion) async {
    if (targetVersion.trim().isEmpty) return false;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version.trim() != targetVersion.trim();
    } catch (_) {
      return true;
    }
  }

  /// 判断是否需要显示可选更新弹窗
  /// 对齐 iOS: isNeedShowVersionUpdateWithUpdateCycle
  /// updateCycleInterval: 0=从不, -1=仅一次, 86400/259200/604800 秒间隔
  Future<bool> _canShowWeakUpdate(AppUpdateInfo info) async {
    final key = 'cms_last_STVersionUpdateAlert_${info.version}';
    final prefs = await SharedPreferences.getInstance();
    final lastShow = prefs.getInt(key);

    final now = DateTime.now().millisecondsSinceEpoch;

    switch (info.updateCycleInterval) {
      case 0:
        return false;
      case -1:
        return lastShow == null;
      case 86400:
        if (lastShow == null) return true;
        final elapsed = now - lastShow;
        return elapsed >= const Duration(days: 1).inMilliseconds;
      case 259200:
        if (lastShow == null) return true;
        final elapsed = now - lastShow;
        return elapsed >= const Duration(days: 3).inMilliseconds;
      case 604800:
        if (lastShow == null) return true;
        final elapsed = now - lastShow;
        return elapsed >= const Duration(days: 7).inMilliseconds;
      default:
        return false;
    }
  }

  /// 记录可选更新弹窗展示时间
  Future<void> _recordWeakUpdateShow(AppUpdateInfo info) async {
    final key = 'cms_last_STVersionUpdateAlert_${info.version}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _openDownloadUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

enum _UpdateDialogAction { update, customerService, cancel }

final versionUpdateServiceProvider = Provider<VersionUpdateService>((ref) {
  return VersionUpdateService();
});

NavigatorState? _rootNavigator(BuildContext fallback) {
  final root = STToast.navigatorKey.currentState;
  if (root != null && root.mounted) return root;
  final fallbackNavigator = Navigator.maybeOf(fallback, rootNavigator: true);
  if (fallbackNavigator != null && fallbackNavigator.mounted) {
    return fallbackNavigator;
  }
  return null;
}
