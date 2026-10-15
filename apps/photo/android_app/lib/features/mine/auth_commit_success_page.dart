import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';

/// 通用「提交成功」页
/// 对齐 iOS `STAuthCommitSuccessViewController` / `STMineAuthCommitType`
enum AuthCommitKind {
  auth,
  bankCard,
  eWallet,
  draw,
  setFinancePwd,
  resetFinancePwd,

  /// 修改资金密码成功（`Language-zh-Hans.json`: update_sum_password_success）
  changeFinancePwd,
}

/// `extra['kind']`：`auth` | `bank_card` | `ewallet` | `draw` |
/// `set_finance_pwd` | `reset_finance_pwd` | `change_finance_pwd`
AuthCommitKind authCommitKindFromExtra(Object? raw) {
  final s = raw?.toString() ?? 'draw';
  switch (s) {
    case 'auth':
      return AuthCommitKind.auth;
    case 'bank_card':
      return AuthCommitKind.bankCard;
    case 'ewallet':
      return AuthCommitKind.eWallet;
    case 'set_finance_pwd':
      return AuthCommitKind.setFinancePwd;
    case 'reset_finance_pwd':
      return AuthCommitKind.resetFinancePwd;
    case 'change_finance_pwd':
      return AuthCommitKind.changeFinancePwd;
    case 'draw':
      return AuthCommitKind.draw;
    default:
      return AuthCommitKind.draw;
  }
}

/// 文案对齐 `Language-zh-Hans.json`（与 iOS bundle 一致）
class AuthCommitSuccessPage extends StatefulWidget {
  final AuthCommitKind kind;
  final String? returnPath;
  final String? fallbackPath;
  final int? popCount;

  const AuthCommitSuccessPage({
    super.key,
    required this.kind,
    this.returnPath,
    this.fallbackPath,
    this.popCount,
  });

  @override
  State<AuthCommitSuccessPage> createState() => _AuthCommitSuccessPageState();
}

class _AuthCommitSuccessPageState extends State<AuthCommitSuccessPage> {
  static const String _mineRootTabLocation = '/tabbar/mine';
  static const Map<String, String> _fallbackText = {
    'add_bank_result_tip': '您的银行卡信息已提交，预计1-2个工作日内完成审核。',
    'add_ewallet_result_tip': '您的加密货币地址已提交，预计1-2个工作日内完成审核。',
    'add_success': '添加成功',
    'back': '返回',
    'complete': '完成',
    'fund_password_success': '资金密码重置成功',
    'fund_password_used': '资金密码用于出金、划转等操作，请妥善保管。',
    'identify_submit': '认证信息已提交',
    'identity_submit_result_tip': '我们已收到您提交的材料，正在审核中，请耐心等待。',
    'set_sum_password_success': '资金密码设置成功',
    'set_sum_password_tip': '资金密码用于出金、划转等关键操作，请妥善保管。',
    'update_sum_password_success': '资金密码修改成功',
    'withdrawal_request_submitted': '您的出金申请已提交并正在审核中，请耐心等待。',
    'withdrawal_tip_title': '出金申请已提交',
  };

  String? _languageCode;
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
    STLocalizations.ofContext(context).textMap(_fallbackText).then((entries) {
      if (!mounted) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) => _localized[key] ?? _fallbackText[key] ?? key;

  String get _greenTitle {
    switch (widget.kind) {
      case AuthCommitKind.auth:
        return _t('identify_submit');
      case AuthCommitKind.bankCard:
      case AuthCommitKind.eWallet:
        return _t('add_success');
      case AuthCommitKind.draw:
        return _t('withdrawal_tip_title');
      case AuthCommitKind.resetFinancePwd:
        return _t('fund_password_success');
      case AuthCommitKind.changeFinancePwd:
        return _t('update_sum_password_success');
      case AuthCommitKind.setFinancePwd:
        return _t('set_sum_password_success');
    }
  }

  String get _blackTip {
    switch (widget.kind) {
      case AuthCommitKind.auth:
        return _t('identity_submit_result_tip');
      case AuthCommitKind.bankCard:
        return _t('add_bank_result_tip');
      case AuthCommitKind.eWallet:
        return _t('add_ewallet_result_tip');
      case AuthCommitKind.draw:
        return _t('withdrawal_request_submitted');
      case AuthCommitKind.setFinancePwd:
        return _t('set_sum_password_tip');
      case AuthCommitKind.resetFinancePwd:
      case AuthCommitKind.changeFinancePwd:
        return _t('fund_password_used');
    }
  }

  /// iOS：资金密码成功用「完成」，其余（含提现）用「返回」
  String get _primaryLabel {
    switch (widget.kind) {
      case AuthCommitKind.setFinancePwd:
      case AuthCommitKind.resetFinancePwd:
      case AuthCommitKind.changeFinancePwd:
        return _t('complete');
      default:
        return _t('back');
    }
  }

  void _onPrimary(BuildContext context) {
    _finish(context);
  }

  String? get _defaultReturnPath {
    switch (widget.kind) {
      case AuthCommitKind.auth:
        return _mineRootTabLocation;
      case AuthCommitKind.bankCard:
      case AuthCommitKind.eWallet:
      case AuthCommitKind.draw:
      case AuthCommitKind.setFinancePwd:
      case AuthCommitKind.resetFinancePwd:
      case AuthCommitKind.changeFinancePwd:
        return null;
    }
  }

  int get _defaultPopCount {
    switch (widget.kind) {
      case AuthCommitKind.eWallet:
      case AuthCommitKind.draw:
        return 2;
      case AuthCommitKind.auth:
      case AuthCommitKind.setFinancePwd:
      case AuthCommitKind.resetFinancePwd:
      case AuthCommitKind.changeFinancePwd:
      case AuthCommitKind.bankCard:
        return 1;
    }
  }

  void _finish(BuildContext context) {
    final explicitReturnPath = _normalizePath(widget.returnPath);
    final defaultReturnPath = _normalizePath(_defaultReturnPath);
    final targetPath = explicitReturnPath ?? defaultReturnPath;
    if (targetPath != null) {
      context.go(targetPath);
      return;
    }

    final router = GoRouter.of(context);
    final desiredPopCount = widget.popCount ?? _defaultPopCount;
    var didPop = false;
    if (desiredPopCount == 1 && router.canPop()) {
      router.pop(true);
      didPop = true;
    } else {
      for (var i = 0; i < desiredPopCount; i += 1) {
        if (!router.canPop()) break;
        router.pop();
        didPop = true;
      }
    }

    if (!didPop) {
      final fallback = _normalizePath(widget.fallbackPath);
      if (fallback != null) context.go(fallback);
    }
  }

  static String? _normalizePath(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const ValueKey('auth_commit_success_back'),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: Colors.black,
            onPressed: () => _finish(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Image.asset(
                'assets/images/st_mine_checked_sec.png',
                width: 54,
                height: 54,
              ),
              const SizedBox(height: 17),
              Text(
                _greenTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1BCC83),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 17),
              Text(
                _blackTip,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 123),
              Center(
                child: SizedBox(
                  width: 150,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _onPrimary(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B57A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(_primaryLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
