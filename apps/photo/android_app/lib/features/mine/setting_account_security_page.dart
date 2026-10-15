import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/user_state.dart';
import '../../core/localization/st_localizations.dart';
import '../../core/router/st_router.dart';
import 'mine_settings_appearance.dart';

/// 账户安全
/// 对齐 iOS `STAccountSafeViewController` + 截图
class SettingAccountSecurityPage extends ConsumerStatefulWidget {
  const SettingAccountSecurityPage({super.key});

  @override
  ConsumerState<SettingAccountSecurityPage> createState() =>
      _SettingAccountSecurityPageState();
}

class _SettingAccountSecurityPageState
    extends ConsumerState<SettingAccountSecurityPage> {
  static const Map<String, String> _fallbackText = {
    'account_security': '账户安全',
    'account_security_tip': '多重防护，保障您的账户安全。',
    'bind_mobile': '绑定手机',
    'bind_email': '绑定邮箱',
    'set_sum_password': '设置资金密码',
    'set_login_password': '设置登录密码',
    'close_account': '注销账户',
    'bind': '已绑定',
    'go_bind': '立即绑定',
    'to_complete': '去完成',
    'modify': '修改',
  };

  String? _languageCode;
  int _languageLoadToken = 0;
  Map<String, String> _localized = const {};

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userStateProvider);

    return Scaffold(
      backgroundColor: context.mineSettingsPageBg,
      appBar: AppBar(
        backgroundColor: context.mineSettingsNavBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _t('account_security'),
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // 顶部图标 + 提示
          _buildHeader(context),
          const SizedBox(height: 24),
          // 组1: 绑定手机 / 绑定邮箱
          _buildGroup(context, [
            _SecurityItem(
              icon: Icons.phone_android_outlined,
              label: _t('bind_mobile'),
              statusText: user.isBindPhone ? _t('bind') : null,
              actionText: user.isBindPhone ? null : _t('go_bind'),
              onTap: () => _onBindPhone(context, ref),
            ),
            _SecurityItem(
              icon: Icons.email_outlined,
              label: _t('bind_email'),
              statusText: user.isBindEmail ? _t('bind') : null,
              actionText: user.isBindEmail ? null : _t('go_bind'),
              onTap: () => _onBindEmail(context, ref),
            ),
          ]),
          const SizedBox(height: 12),
          // 组2: 设置资金密码（仅 A 面）
          if (!user.isB)
            _buildGroup(context, [
              _SecurityItem(
                icon: Icons.lock_outline,
                label: _t('set_sum_password'),
                actionText: user.isBindFundPassword
                    ? _t('modify')
                    : _t('to_complete'),
                onTap: () => _onFundPassword(context, ref),
              ),
            ]),
          if (!user.isB) const SizedBox(height: 12),
          // 组3: 设置登录密码
          _buildGroup(context, [
            _SecurityItem(
              icon: Icons.lock_outline,
              label: _t('set_login_password'),
              actionText: user.isBindPassword
                  ? _t('modify')
                  : _t('to_complete'),
              onTap: () => _onLoginPassword(context, ref),
            ),
          ]),
          // B 面额外: 注销账户
          if (user.isB) ...[
            const SizedBox(height: 12),
            _buildGroup(context, [
              _SecurityItem(
                icon: null,
                label: _t('close_account'),
                rowTapEnabled: true,
                onTap: () => _onCloseAccount(context, ref),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.verified_user,
          size: 64,
          color: const Color(0xFF00B57A).withValues(alpha: 0.85),
        ),
        const SizedBox(height: 12),
        Text(
          _t('account_security_tip'),
          style: TextStyle(
            fontSize: 13,
            color: context.mineSettingsTextTertiary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGroup(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.mineSettingsGroupBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: context.mineSettingsDivider,
            );
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  void _onBindPhone(BuildContext context, WidgetRef ref) {
    ref.read(stRouterProvider).openPage(context, '/mine/bind_phone');
  }

  void _onBindEmail(BuildContext context, WidgetRef ref) {
    ref.read(stRouterProvider).openPage(context, '/mine/bind_email');
  }

  void _onFundPassword(BuildContext context, WidgetRef ref) {
    final user = ref.read(userStateProvider);
    final mode = user.isBindFundPassword ? 'change' : 'set';
    ref
        .read(stRouterProvider)
        .openPage(context, '/mine/finance_password', params: {'mode': mode});
  }

  void _onLoginPassword(BuildContext context, WidgetRef ref) {
    ref.read(stRouterProvider).openPage(context, '/mine/change_login_password');
  }

  void _onCloseAccount(BuildContext context, WidgetRef ref) {
    ref.read(stRouterProvider).openPage(context, '/mine/close_account');
  }
}

class _SecurityItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? statusText;
  final String? actionText;
  final bool rowTapEnabled;
  final VoidCallback onTap;

  const _SecurityItem({
    required this.icon,
    required this.label,
    this.statusText,
    this.actionText,
    this.rowTapEnabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.mineSettingsIconPillBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon!,
                  size: 18,
                  color: context.mineSettingsTextTertiary,
                ),
              ),
              const SizedBox(width: 12),
            ],
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
            if (statusText != null && statusText!.isNotEmpty)
              Text(
                statusText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: context.mineSettingsTextSecondary,
                ),
              ),
            if (actionText != null && actionText!.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: SizedBox(
                  width: 64,
                  height: 26,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B57A),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      actionText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!rowTapEnabled) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
