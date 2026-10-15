import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/router/customer_service_route.dart';
import '../../core/models/user_state.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/router/policy_link_route.dart';
import '../../core/router/st_router.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import 'mine_settings_appearance.dart';

/// 关于我们
/// 对齐 iOS `STAboutViewController`：Logo、版本、公司简介、联系我们、用户协议、隐私政策
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  static const Map<String, String> _fallbackText = {
    'about_us': '关于我们',
    'version': '版本',
    'official_net': '公司简介',
    'connect_us': '联系我们',
    'agreement_label': '用户协议',
    'privacy': '隐私政策',
    'flutter_prompt_address_not_configured': '{title}地址未配置',
  };

  String _version = '';
  String _appName = '';
  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

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

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _appName = info.appName;
      });
    }
  }

  void _openWeb(String url, {bool isNeedNavigationBar = false}) {
    ref
        .read(stRouterProvider)
        .openPage(
          context,
          '/web',
          params: {
            'link': url,
            if (isNeedNavigationBar) 'isNeedNavigationBar': true,
          },
        );
  }

  void _openValidWeb(String url, {bool isNeedNavigationBar = false}) {
    if (url.trim().isEmpty) return;
    _openWeb(url, isNeedNavigationBar: isNeedNavigationBar);
  }

  Future<void> _openPolicy({required bool privacy}) async {
    final title = privacy ? _t('privacy') : _t('agreement_label');
    final opened = await PolicyLinkRoute.open(
      context,
      ref,
      privacy: privacy,
      title: title,
    );
    if (!opened && mounted) {
      showStLocalizedToastByKey(
        context,
        'flutter_prompt_address_not_configured',
        fallback: _fallbackText['flutter_prompt_address_not_configured'],
        replacements: {'title': title},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userStateProvider);
    final model = userState.h5AddressModel ?? const STH5AddressModel();
    final isB = userState.isB;

    return Scaffold(
      backgroundColor: context.mineSettingsPageBg,
      appBar: AppBar(
        backgroundColor: context.mineSettingsNavBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _t('about_us'),
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
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          // Logo / 名称 / 版本
          Center(
            child: Column(
              children: [
                Container(
                  key: const ValueKey('about-app-icon'),
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/app_icon/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _appName.isEmpty ? ' ' : _appName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.mineSettingsTextTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _version.isEmpty ? ' ' : '${_t('version')} $_version',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.mineSettingsIsDark
                        ? const Color(0xFF6E727D)
                        : const Color(0xFF707773),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 64),
          // 列表卡片
          Container(
            decoration: BoxDecoration(
              color: context.mineSettingsGroupBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _AboutRow(
                  label: _t('official_net'),
                  onTap: () => _openValidWeb(
                    isB ? model.officialWebsiteBUrl : model.officialWebsiteAUrl,
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.mineSettingsDivider,
                ),
                _AboutRow(
                  label: _t('connect_us'),
                  onTap: () => CustomerServiceRoute.open(
                    context,
                    ref,
                    action: _t('connect_us'),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.mineSettingsDivider,
                ),
                _AboutRow(
                  label: _t('agreement_label'),
                  onTap: () => _openPolicy(privacy: false),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.mineSettingsDivider,
                ),
                _AboutRow(
                  label: _t('privacy'),
                  onTap: () => _openPolicy(privacy: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AboutRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: context.mineSettingsTextPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.mineSettingsTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
