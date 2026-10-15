import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/router/st_router.dart';
import '../../core/router/customer_service_route.dart';
import '../../core/network/st_service.dart';
import '../../core/models/user_state.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/services/ios_logout_flow.dart';
import '../../core/services/version_update_service.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/st_network_image.dart';
import '../../shared/widgets/st_toast.dart';
import 'mine_settings_appearance.dart';

/// 设置页面
/// 对齐 iOS STSetViewController + Figma APP 白标 2.0 设置页截图
///
/// 特点：
/// - 列表项无左侧 icon（与截图一致）
/// - 已登录/未登录仅影响「退出登录」按钮显示
/// - 缓存：Flutter 侧统计网络图片磁盘缓存和历史临时目录缓存大小
/// - 清理：对齐 `STSetViewController clearAppCache`（图片内存/磁盘缓存 + Web 站点数据类清理）
/// - 版本行：与 iOS `STMineType_Update` ——有更新为绿字 12pt，无更新灰字；无新版本时点击无反馈
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _cacheSize = '0B';
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  static const List<String> _legacyImageCacheDirectoryNames = [
    'libCachedImageData',
    'flutter_cache_manager',
  ];

  static const Map<String, String> _fallbackText = {
    'setting': '设置',
    'notification_settings': '通知设置',
    'favorite_settings': '偏好设置',
    'account_security': '账户安全',
    'online_custom': '在线客服',
    'clean_cache': '清理缓存',
    'version_update': '版本更新',
    'new_version_tip': '发现新版本',
    'is_latest_version': '已是最新版本',
    'abount': '关于',
    'login_out': '退出登录',
    'logout_successful': '退出登录成功',
    'clear_sucess': '缓存已清除',
    'flutter_prompt_clear_cache_confirm': '确定要清除缓存吗？',
    'flutter_prompt_logout_confirm': '确定要退出登录吗？',
  };

  @override
  void initState() {
    super.initState();
    _calcCacheSize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalizedTextsIfNeeded();
    // 页面重新可见时刷新缓存大小（对齐 iOS viewWillAppear → reloadData）
    _calcCacheSize();
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

  Future<void> _calcCacheSize() async {
    try {
      final candidates = await _collectCacheDirectories();
      double totalSize = (await STNetworkImage.diskCache.sizeInBytes())
          .toDouble();

      for (final dir in candidates) {
        totalSize += await _calcDirSize(dir);
      }

      if (!mounted) return;
      setState(
        () => _cacheSize = _formatCacheSizeLikeIos(totalSize.toDouble()),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _cacheSize = '0B');
      }
    }
  }

  Future<List<Directory>> _collectCacheDirectories() async {
    final tempDir = await getTemporaryDirectory();
    final dirs = <Directory>[];
    final candidates = _legacyImageCacheDirectoryNames
        .map((name) => Directory('${tempDir.path}/$name'))
        .toList();

    for (final dir in candidates) {
      if (dir.existsSync()) {
        dirs.add(dir);
      }
    }

    return dirs.toSet().toList();
  }

  Future<double> _calcDirSize(Directory dir) async {
    double size = 0;
    try {
      if (dir.existsSync()) {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (_) {}
    return size;
  }

  /// 与 iOS `-[STMineCommonCell getCacheNumber]` 一致：`SDImageCache` 总量按 B → KB → MB 换算（两位小数）
  String _formatCacheSizeLikeIos(double bytes) {
    if (bytes <= 0) return '0B';
    var totalNum = bytes;
    if (totalNum > 1024) {
      totalNum = totalNum / 1024;
      var totalStr = '${totalNum.toStringAsFixed(2)} KB';
      if (totalNum > 1024) {
        totalNum = totalNum / 1024;
        totalStr = '${totalNum.toStringAsFixed(2)} MB';
      }
      return totalStr;
    }
    return '${totalNum.toStringAsFixed(2)} B';
  }

  Future<void> _clearCache() async {
    try {
      setState(() => _cacheSize = '0B');
      final tempDir = await getTemporaryDirectory();
      for (final name in _legacyImageCacheDirectoryNames) {
        await _clearDirectoryIfExists(Directory('${tempDir.path}/$name'));
      }
      STNetworkImage.runtimeMemoryCache.clear();
      STNetworkImage.runtimeMemoryCache.clearLiveImages();
      await STNetworkImage.clearDiskCache();

      try {
        await WebViewController().clearCache();
        await WebViewController().clearLocalStorage();
        await WebViewCookieManager().clearCookies();
      } catch (_) {}
      if (mounted) {
        STToast.show(context, _t('clear_sucess'));
      }
      await _calcCacheSize();
    } catch (_) {}
  }

  Future<void> _clearDirectoryIfExists(Directory dir) async {
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _openUpdateIfNeeded() async {
    final user = ref.read(userStateProvider);
    if (!user.hasNewVersion || user.version.trim().isEmpty) {
      return;
    }

    if (!mounted) return;
    final stService = ref.read(stServiceProvider);
    final response = <String, dynamic>{
      'code': 0,
      'data': {
        'app_update_info': {
          'has_update': true,
          'force_update': false,
          'version': user.version.trim(),
          'update_desc': user.updateDesc,
          'download_url': user.downloadUrl,
          'update_cycle_interval': 0,
        },
      },
    };

    await ref
        .read(versionUpdateServiceProvider)
        .checkVersionUpdate(
          context: context,
          stService: stService,
          prefetchedResponse: response,
          isFromSettings: true,
          respectUpdateCycle: false,
          sendUpdateNotify: false,
        );
  }

  Future<void> _openCustomerService() async {
    await CustomerServiceRoute.open(context, ref);
  }

  Future<String> _iosText(String key, String fallback) async {
    return stLocalizationsOfContext(context, ref).text(key, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    // 与 iOS 一致：仅在有有效会话时展示「退出登录」
    final showLogout = userState.hasActiveSession;

    return Scaffold(
      backgroundColor: context.mineSettingsPageBg,
      appBar: AppBar(
        backgroundColor: context.mineSettingsNavBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _t('setting'),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 32),
        children: [
          // ========== Group 0: 偏好 ==========
          _buildGroup([
            _SettingRow(
              label: _t('notification_settings'),
              onTap: () => ref
                  .read(stRouterProvider)
                  .openPage(context, '/mine/setting_notification'),
            ),
            _SettingRow(
              label: _t('favorite_settings'),
              onTap: () => ref
                  .read(stRouterProvider)
                  .openPage(context, '/mine/setting_preference'),
            ),
          ]),
          const SizedBox(height: 11),

          // ========== Group 1: 安全 ==========
          _buildGroup([
            _SettingRow(
              label: _t('account_security'),
              onTap: () => ref
                  .read(stRouterProvider)
                  .openPage(context, '/mine/accountSafe'),
            ),
          ]),
          const SizedBox(height: 11),

          // ========== Group 2: 客服 ==========
          _buildGroup([
            _SettingRow(
              label: _t('online_custom'),
              onTap: _openCustomerService,
            ),
          ]),
          const SizedBox(height: 11),

          // ========== Group 3: 关于 ==========
          _buildGroup([
            _SettingRow(
              label: _t('clean_cache'),
              trailingValue: _cacheSize,
              onTap: _showClearCacheDialog,
            ),
            _SettingRow(
              label: _t('version_update'),
              trailingValue: userState.hasNewVersion
                  ? _t('new_version_tip')
                  : _t('is_latest_version'),
              trailingColor: userState.hasNewVersion
                  ? const Color(0xFF4DCB73)
                  : null,
              trailingFontSize: 12,
              onTap: _openUpdateIfNeeded,
            ),
            _SettingRow(
              label: _t('abount'),
              onTap: () =>
                  ref.read(stRouterProvider).openPage(context, '/mine/about'),
            ),
          ]),
          const SizedBox(height: 29),

          // ========== 退出登录 ==========
          if (showLogout) _buildLogoutButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.mineSettingsGroupBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: List.generate(children.length * 2 - 1, (index) {
            if (index.isOdd) {
              return Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: context.mineSettingsDivider,
              );
            }
            return children[index ~/ 2];
          }),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Builder(
      builder: (context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _showLogoutDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.mineSettingsGroupBg,
            foregroundColor: const Color(0xFFF95959),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(_t('login_out')),
        ),
      ),
    );
  }

  Future<void> _showClearCacheDialog() async {
    final titleColor = context.mineSettingsTextPrimary;
    final messageColor = context.mineSettingsTextTertiary;
    final title = await _iosText('clean_cache', '清除缓存');
    final message = await _iosText(
      'flutter_prompt_clear_cache_confirm',
      _fallbackText['flutter_prompt_clear_cache_confirm']!,
    );
    final cancel = await _iosText('cancel', '取消');
    final confirm = await _iosText('confirm', '确定');
    if (!mounted) return;

    showIosCommonAlertDialog(
      context: context,
      title: title,
      message: message,
      showCancel: true,
      showConfirm: true,
      cancelText: cancel,
      confirmText: confirm,
      backgroundColor: context.mineSettingsGroupBg,
      dividerColor: context.mineSettingsDivider,
      titleStyle: TextStyle(
        color: titleColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      messageStyle: TextStyle(color: messageColor, fontSize: 16),
      cancelTextColor: context.mineSettingsTextSecondary,
      confirmTextColor: const Color(0xFFF95959),
      onConfirm: _clearCache,
    );
  }

  Future<void> _showLogoutDialog() async {
    final title = await _iosText('login_out', '退出登录');
    final message = await _iosText(
      'flutter_prompt_logout_confirm',
      _fallbackText['flutter_prompt_logout_confirm']!,
    );
    final cancel = await _iosText('cancel', '取消');
    final confirm = await _iosText('confirm', '确定');
    if (!mounted) return;

    showIosCommonAlertDialog(
      context: context,
      title: title,
      message: message,
      showCancel: true,
      showConfirm: true,
      cancelText: cancel,
      confirmText: confirm,
      backgroundColor: context.mineSettingsGroupBg,
      dividerColor: context.mineSettingsDivider,
      titleStyle: TextStyle(
        color: context.mineSettingsTextPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      messageStyle: TextStyle(
        color: context.mineSettingsTextTertiary,
        fontSize: 16,
      ),
      cancelTextColor: context.mineSettingsTextSecondary,
      confirmTextColor: const Color(0xFFF95959),
      onConfirm: () async {
        await performIosAlignedLogout(ref);
        if (!mounted) return;
        await ref.read(stRouterProvider).openPage(context, '/mine');
        if (!mounted) return;
        STToast.show(context, _t('logout_successful'));
      },
    );
  }
}

/// 无 icon 设置列表项（对齐 iOS `STMineModule_Set` + `trailArrowLbl` 右对齐）
class _SettingRow extends StatelessWidget {
  final String label;
  final String? trailingValue;
  final Color? trailingColor;
  final double trailingFontSize;
  final VoidCallback onTap;

  const _SettingRow({
    required this.label,
    this.trailingValue,
    this.trailingColor,
    this.trailingFontSize = 15,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trail = trailingColor ?? context.mineSettingsTextSecondary;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 0,
                fit: FlexFit.loose,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: context.mineSettingsTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (trailingValue != null)
                      Flexible(
                        child: Text(
                          trailingValue!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: trailingFontSize,
                            fontWeight: FontWeight.w400,
                            color: trail,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.mineSettingsTextSecondary,
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
}
