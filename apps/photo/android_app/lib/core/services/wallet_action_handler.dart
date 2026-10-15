import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/st_localizations.dart';
import '../models/user_state.dart';
import '../../shared/widgets/auth_popups.dart';
import '../../shared/widgets/trade_no_limit_sheet.dart';

/// 钱包操作权限处理
/// 对齐 iOS STWalletActionHandler 的 KYC 权限链
///
/// 功能：在 wallet/deposit/withdraw/transfer 操作前检查权限配置，
/// 展示未完成的认证步骤，引导用户完成后再放行。
class WalletActionHandler {
  final Ref _ref;

  WalletActionHandler(this._ref);

  static const Map<String, String> _fallbackText = {
    'account_security': '账户安全',
    'info_un_tip': '为保障您的资金安全，请及时完成相关认证和设置服务',
    'cancel': '取消',
    'identity': '身份认证',
    'add_bank_card': '添加银行卡',
    'bind_mobile': '绑定手机',
    'wallet_info': '电子钱包',
    'set_sum_password': '设置资金密码',
    'bind_email': '绑定邮箱',
    'to_complete': '去完成',
    'go_bind': '立即绑定',
    'already_auth': '已认证',
    'bind': '已绑定',
  };

  static const Set<String> _genericNoLimitPermissions = {
    'deposit',
    'withdraw',
    'internal_transfer',
    'claim_bonus',
    'enable_transactions',
  };

  static const Set<String> _levelChangePermissions = {
    'level_up_before_open',
    'level_down_before_open',
  };

  /// 执行钱包操作（带 KYC 权限检查）
  ///
  /// [action] 操作类型：deposit / withdraw / internal_transfer / claim_bonus
  /// [context] 用于弹窗和路由跳转的 BuildContext
  /// [onPassed] 权限检查通过后的回调（如 navigate to deposit page）
  Future<void> handleWalletAction({
    required BuildContext context,
    required String action,
    VoidCallback? onPassed,
  }) async {
    final userState = _ref.read(userStateProvider);
    final config = userState.verificationConfig;

    // iOS `getKYCPermissionModel:` uses the first matching permission and
    // breaks; duplicate backend entries must not be merged.
    STVerificationModel? activeConfig;
    for (final item in config) {
      if (item.permission == action) {
        activeConfig = item;
        break;
      }
    }

    if (activeConfig == null) {
      if (await _blockDisallowedPermission(context, action)) return;
      onPassed?.call();
      return;
    }

    if (!activeConfig.allowed) {
      await _blockDisallowedPermission(context, activeConfig.permission);
      return;
    }

    final items = _buildSecurityItems(
      userState: userState,
      configs: [activeConfig],
    );
    final needsAuth = _configuredSteps(activeConfig).any(
      (step) => _isStepRequiredAndMissing(
        userState: userState,
        permission: activeConfig!.permission,
        step: step,
      ),
    );
    if (!needsAuth) {
      // 所有认证已通过，直接放行
      onPassed?.call();
      return;
    }

    // 展示引导弹窗
    if (context.mounted) {
      await _showVerificationDialog(context, items);
    }
  }

  Future<bool> _blockDisallowedPermission(
    BuildContext context,
    String permission,
  ) async {
    if (!context.mounted) return true;
    if (_genericNoLimitPermissions.contains(permission)) {
      await showTradeNoLimitSheet(context: context, noLimit: true);
      return true;
    }
    if (_levelChangePermissions.contains(permission)) {
      await showTradeNoLimitSheet(context: context);
      return true;
    }
    return false;
  }

  List<WalletAccountSecurityItem> _buildSecurityItems({
    required UserState userState,
    required List<STVerificationModel> configs,
  }) {
    final steps = <String>[];
    for (final config in configs) {
      for (final step in _configuredSteps(config)) {
        if (!steps.contains(step)) steps.add(step);
      }
    }
    return steps
        .map((step) => _securityItemForStep(userState: userState, step: step))
        .whereType<WalletAccountSecurityItem>()
        .toList();
  }

  List<String> _configuredSteps(STVerificationModel config) {
    return config.kycVerificationConfigAry.isNotEmpty
        ? config.kycVerificationConfigAry
        : config.authMethods;
  }

  bool _isStepRequiredAndMissing({
    required UserState userState,
    required String permission,
    required String step,
  }) {
    switch (step) {
      case 'document_verify':
        return !userState.isAuthed;
      case 'bankcard_verify':
        return !userState.isBindBankCard;
      case 'bind_tel':
        return permission == 'check_vercode' ? false : !userState.isBindPhone;
      case 'ewallet_verify':
        return !userState.isBindEWallet;
      case 'set_funds_pwd':
        return !userState.isBindFundPassword;
      case 'bind_email':
        return !userState.isBindEmail;
      default:
        return false;
    }
  }

  WalletAccountSecurityItem? _securityItemForStep({
    required UserState userState,
    required String step,
  }) {
    switch (step) {
      case 'document_verify':
        return WalletAccountSecurityItem(
          step: step,
          title: _fallbackText['identity']!,
          completed: userState.isAuthed,
          completedText: _fallbackText['already_auth']!,
          actionText: _fallbackText['to_complete']!,
          assetName: 'st_mine_real_auth',
        );
      case 'bankcard_verify':
        return WalletAccountSecurityItem(
          step: step,
          title: _fallbackText['add_bank_card']!,
          completed: userState.isBindBankCard,
          completedText: _fallbackText['bind']!,
          actionText: _fallbackText['go_bind']!,
          assetName: 'st_mine_bank_card',
        );
      case 'bind_tel':
        return WalletAccountSecurityItem(
          step: step,
          title: _fallbackText['bind_mobile']!,
          completed: userState.isBindPhone,
          completedText: _fallbackText['bind']!,
          actionText: _fallbackText['go_bind']!,
          assetName: 'st_mine_phone',
        );
      case 'ewallet_verify':
        return WalletAccountSecurityItem(
          step: step,
          title: _fallbackText['wallet_info']!,
          completed: userState.isBindEWallet,
          completedText: _fallbackText['bind']!,
          actionText: _fallbackText['go_bind']!,
          assetName: 'st_mine_wallet_black',
        );
      case 'set_funds_pwd':
        return WalletAccountSecurityItem(
          step: step,
          title: _fallbackText['set_sum_password']!,
          completed: userState.isBindFundPassword,
          completedText: _fallbackText['bind']!,
          actionText: _fallbackText['to_complete']!,
          assetName: 'st_mine_pwd',
        );
      case 'bind_email':
        return WalletAccountSecurityItem(
          step: step,
          title: _fallbackText['bind_email']!,
          completed: userState.isBindEmail,
          completedText: _fallbackText['bind']!,
          actionText: _fallbackText['go_bind']!,
          assetName: 'st_mine_email',
        );
      default:
        return null;
    }
  }

  /// 展示认证引导弹窗
  Future<void> _showVerificationDialog(
    BuildContext context,
    List<WalletAccountSecurityItem> items,
  ) async {
    final localized = await _ref
        .read(stLocalizationsProvider)
        .textMap(_fallbackText);
    final sheetItems = items
        .map(
          (item) => WalletAccountSecurityItem(
            step: item.step,
            title: localized[_titleKeyForStep(item.step)] ?? item.title,
            completed: item.completed,
            completedText:
                localized[_completedKeyForStep(item.step)] ??
                item.completedText,
            actionText:
                localized[_actionKeyForStep(item.step)] ?? item.actionText,
            assetName: item.assetName,
            icon: item.icon,
          ),
        )
        .toList();
    if (!context.mounted) return;
    final step = await showWalletAccountSecuritySheet(
      context: context,
      items: sheetItems,
      title:
          localized['account_security'] ?? _fallbackText['account_security']!,
      subtitle: localized['info_un_tip'] ?? _fallbackText['info_un_tip']!,
      cancelText: localized['cancel'] ?? _fallbackText['cancel']!,
    );
    if (step != null && context.mounted) {
      _navigateToAuth(context, step);
    }
  }

  /// 跳转到认证/设置页面
  void _navigateToAuth(BuildContext context, String step) {
    switch (step) {
      case 'document_verify':
        context.push('/mine/auth');
        return;
      case 'bankcard_verify':
        context.push('/mine/bankcard');
        return;
      case 'ewallet_verify':
        context.push('/mine/ewallet');
        return;
      case 'bind_tel':
        context.push('/mine/bind_phone');
        return;
      case 'bind_email':
        context.push('/mine/bind_email');
        return;
      case 'set_funds_pwd':
        context.push('/mine/finance_password?mode=set');
        return;
    }
    context.push('/mine/auth');
  }

  String _titleKeyForStep(String step) {
    switch (step) {
      case 'document_verify':
        return 'identity';
      case 'bankcard_verify':
        return 'add_bank_card';
      case 'bind_tel':
        return 'bind_mobile';
      case 'ewallet_verify':
        return 'wallet_info';
      case 'set_funds_pwd':
        return 'set_sum_password';
      case 'bind_email':
        return 'bind_email';
      default:
        return step;
    }
  }

  String _completedKeyForStep(String step) {
    return step == 'document_verify' ? 'already_auth' : 'bind';
  }

  String _actionKeyForStep(String step) {
    return step == 'document_verify' || step == 'set_funds_pwd'
        ? 'to_complete'
        : 'go_bind';
  }
}

/// Provider
final walletActionHandlerProvider = Provider<WalletActionHandler>((ref) {
  return WalletActionHandler(ref);
});
