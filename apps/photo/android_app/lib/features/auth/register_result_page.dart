import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/customer_service_route.dart';
import '../../core/localization/st_localizations.dart';
import 'auth_login_commit.dart';
import 'auth_theme.dart';
import 'register_config.dart';

/// 注册结果页（对齐 iOS `STRegisterResultViewController`）
class RegisterResultPage extends ConsumerStatefulWidget {
  const RegisterResultPage({
    super.key,
    required this.outcome,
    this.loginMode = 1,
    this.userInfo,
    this.registeredAccount,
  });

  /// 0=third 1=mobile 2=email（对齐 `STNewRegisterLoginMode`）
  final int loginMode;
  final RegisterOutcome outcome;
  final Map<String, dynamic>? userInfo;
  final String? registeredAccount;

  @override
  ConsumerState<RegisterResultPage> createState() => _RegisterResultPageState();
}

class _RegisterResultPageState extends ConsumerState<RegisterResultPage> {
  static const Map<String, String> _fallbackText = {
    'new_register_account_open_success': '开户成功',
    'new_register_account_activated': '您的交易账户已开通\n现在可以开始入金交易了',
    'new_register_login_deposit': '登录入金',
    'new_register_account_open_submission': '开户申请提交',
    'new_register_account_open_review':
        '您的开户申请正在审核中。\n预计 1-2 个工作日内完成，结果将通过短信通知',
    'new_register_account_open_review_email':
        '您的开户申请正在审核中。\n预计 1-2 个工作日内完成，结果将通过邮箱通知',
    'contact_customer_service': '联系客服',
    'back': '返回',
    'new_register_account_open_failed': '开户失败',
    'new_register_account_open_anomaly': '您的开户资料异常，无法为您开立账户',
    'new_register_go_modify_information': '前往修改资料',
    'new_register_account_label': '账号',
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isLight = theme.brightness == Brightness.light;
    final account = widget.registeredAccount?.trim() ?? '';

    late final String navTitle;
    late final String message;
    late final String imageAsset;
    late final String topBtnTitle;
    String? bottomBtnTitle;

    switch (widget.outcome) {
      case RegisterOutcome.success:
        navTitle = _t('new_register_account_open_success');
        message = _t('new_register_account_activated');
        imageAsset = 'st_result_success';
        topBtnTitle = _t('new_register_login_deposit');
        bottomBtnTitle = null;
        break;
      case RegisterOutcome.pending:
        navTitle = _t('new_register_account_open_submission');
        message = widget.loginMode == 1
            ? _t('new_register_account_open_review')
            : _t('new_register_account_open_review_email');
        imageAsset = 'st_result_pending';
        topBtnTitle = _t('contact_customer_service');
        bottomBtnTitle = _t('back');
        break;
      case RegisterOutcome.rejected:
        navTitle = _t('new_register_account_open_failed');
        message = _t('new_register_account_open_anomaly');
        imageAsset = 'st_result_failed';
        topBtnTitle = _t('new_register_go_modify_information');
        bottomBtnTitle = _t('contact_customer_service');
        break;
      case RegisterOutcome.inProgress:
        navTitle = _t('new_register_account_open_submission');
        message = _t('new_register_account_open_review');
        imageAsset = 'st_result_pending';
        topBtnTitle = _t('contact_customer_service');
        bottomBtnTitle = _t('back');
        break;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AuthUi.pageBg(context),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : null,
        title: Text(
          navTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AuthUi.label(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuthUi.registerNextBtnHPad,
          ),
          child: Column(
            children: [
              const SizedBox(height: 48),
              AuthUi.authAsset(
                imageAsset,
                width: MediaQuery.sizeOf(context).width - 87 - 88,
                fallbackIcon: widget.outcome == RegisterOutcome.success
                    ? Icons.check_circle_outline
                    : widget.outcome == RegisterOutcome.rejected
                    ? Icons.error_outline
                    : Icons.schedule_outlined,
              ),
              const SizedBox(height: 12),
              _ResultMessageText(
                text: message,
                highlightPending:
                    widget.outcome == RegisterOutcome.pending ||
                    widget.outcome == RegisterOutcome.inProgress,
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: AuthUi.primaryBtnH,
                child: FilledButton(
                  onPressed: () => _onTop(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    topBtnTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (widget.outcome == RegisterOutcome.success &&
                  account.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AuthUi.cardBg(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_t('new_register_account_label')}：$account',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: AuthUi.label(context),
                    ),
                  ),
                ),
              ],
              if (bottomBtnTitle != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: AuthUi.primaryBtnH,
                  child: TextButton(
                    onPressed: () => _onBottom(context, ref),
                    style: TextButton.styleFrom(
                      backgroundColor: AuthUi.cardBg(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      bottomBtnTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AuthUi.label(context),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTop(BuildContext context, WidgetRef ref) async {
    switch (widget.outcome) {
      case RegisterOutcome.success:
        var didCommitLogin = false;
        if (widget.userInfo != null) {
          await commitLoginSuccess(
            ref: ref,
            context: context,
            loginResult: {'code': 0, 'data': widget.userInfo},
            retryFailedRouter: false,
          );
          didCommitLogin = true;
        }
        if (!didCommitLogin && context.mounted) context.go('/');
        break;
      case RegisterOutcome.pending:
      case RegisterOutcome.inProgress:
        _openCustomer(context, ref);
        break;
      case RegisterOutcome.rejected:
        if (context.mounted) context.pop();
        break;
    }
  }

  void _onBottom(BuildContext context, WidgetRef ref) {
    if (widget.outcome == RegisterOutcome.pending ||
        widget.outcome == RegisterOutcome.inProgress) {
      context.go('/');
      return;
    }
    if (widget.outcome == RegisterOutcome.rejected) {
      _openCustomer(context, ref);
    }
  }

  void _openCustomer(BuildContext context, WidgetRef ref) {
    CustomerServiceRoute.open(context, ref);
  }
}

/// 审核中文案高亮「1-2」（对齐 iOS `attributedWithText:`）
class _ResultMessageText extends StatelessWidget {
  const _ResultMessageText({required this.text, this.highlightPending = false});

  final String text;
  final bool highlightPending;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 15,
      height: 1.45,
      color: AuthUi.resultBody(context),
    );
    if (!highlightPending || !text.contains('1-2')) {
      return Text(text, textAlign: TextAlign.center, style: baseStyle);
    }
    final parts = text.split('1-2');
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: parts[0]),
          const TextSpan(
            text: '1-2',
            style: TextStyle(color: Colors.red),
          ),
          if (parts.length > 1) TextSpan(text: parts.sublist(1).join('1-2')),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
