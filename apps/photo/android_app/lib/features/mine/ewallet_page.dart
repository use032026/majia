import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/models/ewallet_item_model.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/router/route_observer.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/mine_finance_theme.dart';
import '../../shared/widgets/st_keyboard_actions.dart';
import '../../shared/widgets/st_toast.dart';
import '../auth/auth_captcha_dialog.dart';

class EWalletPage extends ConsumerStatefulWidget {
  const EWalletPage({super.key});

  @override
  ConsumerState<EWalletPage> createState() => _EWalletPageState();
}

class _EWalletText {
  const _EWalletText._();

  static const fallbackText = {
    'e_wallet': '电子钱包',
    'no_ewallet_tip1': '暂无电子钱包',
    'add_digital_wallet': '添加钱包地址',
    'warm_tips': '温馨提示',
    'sure_to_set_default_bank_card': '确定设为默认银行卡吗？',
    'cancel': '取消',
    'certain': '确定',
    'set_default_failed': '设置默认电子钱包失败',
    'set_failed': '设置失败',
    'sure_to_delete_rejected_ewallet': '确定删除审核未通过的电子钱包吗？',
    'sure_unbind_ewallet': '确定解绑电子钱包吗？',
    'operation_failed': '操作失败',
    'account_security': '账户安全',
    'two_factor_auth': '双重认证',
    'bind_mobile': '绑定手机号',
    'bind_email': '绑定邮箱',
    'already_complete': '已完成',
    'get_certified_now': '去完成',
    'no_setting': '未设置地址',
    'currency': '币种',
    'choose_currency': '选择币种',
    'net': '网络',
    'wallet_address': '钱包地址',
    'paster': '粘贴',
    'verify_code': '验证码',
    'verify_code_send_again': '重新发送',
    'get_verification_code': '获取验证码',
    'submit': '提交',
    'please_choose_currency': '请选择币种',
    'please_choose_net': '请选择网络',
    'choose_net': '选择网络',
    'enter_electronic_wallet_address': '请输入电子钱包地址',
    'enter_phone_or_email_verification_code': '请输入手机/邮箱验证码',
    'please_input_phone_tip': '请输入手机验证码',
    'please_input_email_tip': '请输入邮箱验证码',
    'local_phone_num': '预留手机号码',
    'local_email': '预留邮箱',
    'paster_no': '剪贴板无内容',
    'verification_code_sent_successfully': '验证码已发送',
    'ewallet_address_format_error': '钱包地址格式错误，请重新填写',
    'no_currency': '暂无可选币种，请稍后再试',
    'get_currency_failed': '获取币种失败',
    'no_network_options': '该币种暂无网络选项',
    'set_default': '设为默认',
    'unbind': '解绑',
    'delete': '删除',
    'under_review': '审核中',
    'default_text': '默认',
    'ewallet_fail_tip': '您的电子钱包认证未通过。',
    'reason': '原因：',
    'add_wallet_bottom_tip': '地址仅支持 10~100 位数字或字母，区分大小写；提交后需审核。',
  };
}

mixin _EWalletLocalizedState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String? _localizedLanguageCode;
  Map<String, String> _localized = _EWalletText.fallbackText;

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_EWalletText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _EWalletText.fallbackText[key] ?? key;
}

class _EWalletPageState extends ConsumerState<EWalletPage>
    with RouteAware, _EWalletLocalizedState<EWalletPage> {
  List<EWalletItemModel> _wallets = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _loadFailed = false;
  bool _routeSubscribed = false;
  bool _skipNextPopRefresh = false;
  String? _openActionWalletId;

  void _toast(String message) {
    if (mounted) STToast.show(context, message);
  }

  @override
  void initState() {
    super.initState();
    _loadEWallets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didPopNext() {
    if (_skipNextPopRefresh) {
      _skipNextPopRefresh = false;
      return;
    }
    _loadEWallets(showLoading: false);
  }

  @override
  void didPushNext() {
    _hideSwipe();
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _syncBindFlags() async {
    try {
      final service = ref.read(stServiceProvider);
      final profile = await service.getUserProfile();
      final data = profile['data'];
      if (data is Map<String, dynamic>) {
        ref.read(userStateProvider.notifier).mergeUserInfoApi(data);
      }
    } catch (e) {
      debugPrint('EWallet sync bind flags: $e');
    }
  }

  void _ensureBusinessOk(Map<String, dynamic> raw, String fallback) {
    final code = raw['code'];
    final ok = code == null || code == 0 || code == '0';
    if (!ok) {
      throw Exception(raw['message']?.toString() ?? fallback);
    }
  }

  Future<void> _loadEWallets({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || !_hasLoadedOnce;
    setState(() {
      _isLoading = shouldShowLoading;
      _openActionWalletId = null;
    });

    try {
      final service = ref.read(stServiceProvider);
      final data = await service.getEWalletList();
      if (!mounted) return;
      setState(() {
        _wallets = data.map((e) => EWalletItemModel.fromDynamic(e)).toList();
        _hasLoadedOnce = true;
        _isLoading = false;
        _loadFailed = false;
      });
      await _syncBindFlags();
    } catch (e) {
      if (!mounted) return;
      if (shouldShowLoading) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
      _toast('${_t('operation_failed')}: ${stUserVisibleErrorMessage(e)}');
    }
  }

  void _hideSwipe() {
    if (_openActionWalletId == null || !mounted) return;
    setState(() => _openActionWalletId = null);
  }

  List<_EWalletAction> _walletActions(EWalletItemModel wallet) {
    if (wallet.id.isEmpty) return const [];
    if (wallet.status == 0) return const [];
    if (wallet.status == 1) {
      return wallet.isDefault
          ? const [_EWalletAction.unbind]
          : const [_EWalletAction.unbind, _EWalletAction.setDefault];
    }
    if (wallet.status == 2) {
      return const [_EWalletAction.delete];
    }
    return const [];
  }

  void _handleWalletAction(EWalletItemModel wallet, _EWalletAction action) {
    _hideSwipe();
    switch (action) {
      case _EWalletAction.setDefault:
        _setDefaultWallet(wallet);
        break;
      case _EWalletAction.delete:
        _deleteWallet(wallet, isDelete: true);
        break;
      case _EWalletAction.unbind:
        _deleteWallet(wallet, isDelete: false);
        break;
    }
  }

  Object _walletRequestId(EWalletItemModel wallet) {
    return int.tryParse(wallet.id) ?? wallet.id;
  }

  Future<void> _setDefaultWallet(EWalletItemModel wallet) async {
    if (wallet.id.isEmpty || wallet.isDefault) return;

    _skipNextPopRefresh = true;
    final confirm = await showIosCommonAlertDialog(
      context: context,
      title: _t('warm_tips'),
      message: _t('sure_to_set_default_bank_card'),
      cancelText: _t('cancel'),
      confirmText: _t('certain'),
    );
    if (confirm != true || !mounted) return;

    try {
      final service = ref.read(stServiceProvider);
      final raw = await service.setDefaultEWallet({
        'id': _walletRequestId(wallet),
      });
      _ensureBusinessOk(raw, _t('set_default_failed'));
      if (!mounted) return;
      setState(() {
        _wallets = _wallets
            .map((item) => item.copyWith(isDefault: item.id == wallet.id))
            .toList();
      });
    } catch (e) {
      _toast('${_t('set_failed')}: ${stUserVisibleErrorMessage(e)}');
    }
  }

  Future<void> _deleteWallet(
    EWalletItemModel wallet, {
    required bool isDelete,
  }) async {
    if (wallet.id.isEmpty) return;

    _skipNextPopRefresh = true;
    final confirm = await showIosCommonAlertDialog(
      context: context,
      title: _t('warm_tips'),
      message: isDelete
          ? _t('sure_to_delete_rejected_ewallet')
          : _t('sure_unbind_ewallet'),
      cancelText: _t('cancel'),
      confirmText: _t('certain'),
    );
    if (confirm != true || !mounted) return;

    try {
      final service = ref.read(stServiceProvider);
      await service.deleteEWallet({'id': _walletRequestId(wallet)});
      if (!mounted) return;
      if (wallet.isDefault) {
        await _loadEWallets(showLoading: false);
      } else {
        setState(() {
          _wallets = _wallets.where((item) => item.id != wallet.id).toList();
        });
      }
    } catch (e) {
      _toast('${_t('operation_failed')}: ${stUserVisibleErrorMessage(e)}');
    }
  }

  Future<void> _openAddEWalletFlow() async {
    _hideSwipe();
    final user = ref.read(userStateProvider);
    if (!user.isBindEmail) {
      final target = await showModalBottomSheet<_EWalletBindTarget>(
        context: context,
        isScrollControlled: true,
        barrierColor: const Color(0x4D000000),
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _buildBindEmailSheet(sheetContext, user),
      );
      if (!mounted || target == null) return;
      switch (target) {
        case _EWalletBindTarget.phone:
          await context.push('/mine/bind_phone');
          break;
        case _EWalletBindTarget.email:
          await context.push('/mine/bind_email');
          break;
      }
      return;
    }

    await context.push('/mine/ewallet/add');
  }

  Widget _buildBindEmailSheet(BuildContext sheetContext, UserState user) {
    final bottom = MediaQuery.of(sheetContext).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: sheetContext.adaptivePageGrey,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      padding: EdgeInsets.only(bottom: bottom + 24),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/st_mine_info_perfect.png',
                  width: 108,
                  height: 108,
                ),
                const SizedBox(height: 10),
                Text(
                  _t('account_security'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: sheetContext.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _t('two_factor_auth'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: sheetContext.adaptiveTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Material(
                    color: sheetContext.adaptiveCard,
                    borderRadius: BorderRadius.circular(15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _authRequirementRow(
                          sheetContext,
                          label: _t('bind_mobile'),
                          icon: Icons.phone_iphone_rounded,
                          done: user.isBindPhone,
                          target: _EWalletBindTarget.phone,
                        ),
                        Divider(
                          height: 1,
                          indent: 54,
                          color: sheetContext.adaptiveDivider,
                        ),
                        _authRequirementRow(
                          sheetContext,
                          label: _t('bind_email'),
                          icon: Icons.email_outlined,
                          done: user.isBindEmail,
                          target: _EWalletBindTarget.email,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: _sheetCancelButton(sheetContext),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              padding: const EdgeInsets.only(top: 16, right: 16),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: Image.asset(
                'assets/images/st_mine_close_gary.png',
                width: 20,
                height: 20,
              ),
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authRequirementRow(
    BuildContext sheetContext, {
    required String label,
    required IconData icon,
    required bool done,
    required _EWalletBindTarget target,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: done ? null : () => Navigator.of(sheetContext).pop(target),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: 15),
            Icon(icon, size: 24, color: sheetContext.adaptiveTextPrimary),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: sheetContext.adaptiveTextPrimary,
                ),
              ),
            ),
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done
                    ? sheetContext.adaptiveIconPillBg
                    : const Color(0xFF477DFF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                done ? _t('already_complete') : _t('get_certified_now'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: done
                      ? sheetContext.adaptiveTextTertiary
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 15),
          ],
        ),
      ),
    );
  }

  Widget _sheetCancelButton(BuildContext sheetContext) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Material(
        color: sheetContext.adaptiveCard,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => Navigator.of(sheetContext).pop(),
          child: Center(
            child: Text(
              _t('cancel'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: sheetContext.adaptiveTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    return Scaffold(
      backgroundColor: MineFinanceTheme.pageBg(context),
      appBar: AppBar(
        title: Text(_t('e_wallet')),
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        backgroundColor: MineFinanceTheme.navBg(context),
        foregroundColor: MineFinanceTheme.textPrimary(context),
        actions: [
          IconButton(
            key: const ValueKey('ewallet_nav_add_button'),
            icon: Image.asset(
              'assets/images/st_mine_add.png',
              width: 18,
              height: 18,
            ),
            onPressed: _openAddEWalletFlow,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: STLoadAnimationView())
          : STPullRefresh(
              color: const Color(0xFF00B57A),
              onRefresh: () => _loadEWallets(showLoading: false),
              child: _wallets.isEmpty
                  ? _loadFailed
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: _emptyViewportHeight(context)),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: _emptyViewportHeight(context),
                                child: _buildEmptyView(),
                              ),
                            ],
                          )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        MineFinanceTheme.horizontalInset,
                        22,
                        MineFinanceTheme.horizontalInset,
                        28,
                      ),
                      itemCount: _wallets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final wallet = _wallets[index];
                        final actions = _walletActions(wallet);
                        final address = wallet.addressRaw.trim().isNotEmpty
                            ? wallet.addressRaw.trim()
                            : _t('no_setting');
                        return _EWalletSwipeActionRow(
                          actions: actions,
                          isOpen: _openActionWalletId == wallet.id,
                          onOpen: actions.isEmpty
                              ? null
                              : () => setState(
                                  () => _openActionWalletId = wallet.id,
                                ),
                          onClose: _hideSwipe,
                          onAction: (action) =>
                              _handleWalletAction(wallet, action),
                          actionLabels: {
                            _EWalletAction.setDefault: _t('set_default'),
                            _EWalletAction.unbind: _t('unbind'),
                            _EWalletAction.delete: _t('delete'),
                          },
                          child: MineEWalletTile(
                            currencyTitle: wallet.currencyTitle,
                            addressDisplay: address,
                            status: wallet.status,
                            isDefault: wallet.isDefault,
                            failRemark: wallet.remark,
                            reviewLabel: _t('under_review'),
                            defaultLabel: _t('default_text'),
                            failureTitle: _t('ewallet_fail_tip'),
                            reasonLabel: _t('reason'),
                            onCopy: wallet.isCertified && wallet.id.isNotEmpty
                                ? () => copyMineClipboard(context, wallet.id)
                                : null,
                            onTap: actions.isEmpty ? null : _hideSwipe,
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const imageSize = 108.0;
        final imageTop = (constraints.maxHeight - imageSize) / 2 - 60;
        return Stack(
          children: [
            Positioned(
              top: imageTop.clamp(80.0, constraints.maxHeight).toDouble(),
              left: 0,
              right: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/st_mine_bank_none.png',
                    width: imageSize,
                    height: imageSize,
                  ),
                  const SizedBox(height: 19),
                  Text(
                    _t('no_ewallet_tip1'),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _blackAddButton(onTap: _openAddEWalletFlow),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _emptyViewportHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final height =
        media.size.height -
        kToolbarHeight -
        media.padding.top -
        media.padding.bottom;
    return height.clamp(360.0, double.infinity).toDouble();
  }

  Widget _blackAddButton({required VoidCallback onTap}) {
    return SizedBox(
      width: 127,
      height: 26,
      child: Material(
        key: const ValueKey('ewallet_empty_add_button'),
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Center(
            child: Text(
              _t('add_digital_wallet'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddEWalletPage extends ConsumerStatefulWidget {
  const AddEWalletPage({super.key});

  @override
  ConsumerState<AddEWalletPage> createState() => _AddEWalletPageState();
}

class _AddEWalletPageState extends ConsumerState<AddEWalletPage>
    with _EWalletLocalizedState<AddEWalletPage> {
  final _addressCtrl = TextEditingController();
  final _verifyCodeCtrl = TextEditingController();
  final _addressFocus = FocusNode();
  final _verifyCodeFocus = FocusNode();

  List<_CryptoCurrencyItem> _currencies = [];
  bool _isLoading = true;
  bool _submitting = false;
  bool _sendingCode = false;
  int _resendSec = 0;
  int _currencyIndex = 0;
  String _network = '';
  Timer? _timer;

  _CryptoCurrencyItem? get _currentCurrency {
    if (_currencies.isEmpty) return null;
    return _currencies[_currencyIndex.clamp(0, _currencies.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _addressCtrl.dispose();
    _verifyCodeCtrl.dispose();
    _addressFocus.dispose();
    _verifyCodeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencies() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(stServiceProvider);
      final raw = await service.getCryptoCurrency();
      final currencies = _extractCryptoCurrencies(raw);
      if (!mounted) return;
      setState(() {
        _currencies = currencies;
        _currencyIndex = 0;
        _network = currencies.isNotEmpty && currencies.first.networks.isNotEmpty
            ? currencies.first.networks.first
            : '';
        _isLoading = false;
      });
      if (currencies.isEmpty) {
        STToast.show(context, _t('no_currency'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      STToast.show(
        context,
        '${_t('get_currency_failed')}: ${stUserVisibleErrorMessage(e)}',
      );
    }
  }

  Future<Map<String, dynamic>> _captchaBridgeUserInfo() async {
    final service = ref.read(stServiceProvider);
    final user = ref.read(userStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var appVersion = '';
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}

    return {
      if (user.userId.isNotEmpty) 'id': user.userId,
      'nickName': user.nickname,
      'funds_password_status': user.isBindFundPassword ? '1' : '0',
      'ab': user.isB ? 'b' : 'a',
      'language_code': service.dio.currentLanguage,
      'token': user.token,
      'device_type': 'ios',
      'dark_mode': isDark ? '1' : '0',
      'timeZone': '${DateTime.now().timeZoneOffset.inHours}',
      'appVersion': appVersion,
    };
  }

  void _startCooldown([int seconds = 59]) {
    _timer?.cancel();
    setState(() => _resendSec = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSec <= 1) {
        timer.cancel();
        setState(() => _resendSec = 0);
      } else {
        setState(() => _resendSec -= 1);
      }
    });
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _resendSec > 0) return;
    setState(() => _sendingCode = true);
    try {
      final service = ref.read(stServiceProvider);
      final h5 = ref.read(userStateProvider).h5AddressModel;
      final captchaUrl = (h5?.codeVerifyUrl.trim().isNotEmpty ?? false)
          ? h5!.codeVerifyUrl.trim()
          : 'localMini://codeverify';
      final bridgeUserInfo = await _captchaBridgeUserInfo();
      if (!mounted) return;
      final captcha = await showAuthCaptchaDialog(
        context,
        url: captchaUrl,
        baseHost: service.dio.baseUrl.replaceFirst(RegExp(r'/violet/?$'), ''),
        captchaApiKey: h5?.captchaApiKey ?? '',
        bridgeUserInfo: bridgeUserInfo,
      );
      if (captcha == null) return;

      _startCooldown();
      await service.sendWalletVerificationCode({
        'code_type': 5,
        'captcha_id': '${captcha['id'] ?? ''}',
        'captcha_key': '${captcha['captchaKey'] ?? ''}',
        'captcha_value': '${captcha['value'] ?? ''}',
      });
      if (mounted) {
        STToast.show(context, _t('verification_code_sent_successfully'));
      }
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    final currency = _currentCurrency;
    final address = _sanitizeWalletAddress(_addressCtrl.text);
    final code = _verifyCodeCtrl.text.trim();

    if (address != _addressCtrl.text) {
      _addressCtrl.value = TextEditingValue(
        text: address,
        selection: TextSelection.collapsed(offset: address.length),
      );
    }
    if (address.isEmpty) {
      STToast.show(context, _t('enter_electronic_wallet_address'));
      return;
    }
    if (!_isEWalletPaymentAddressFormatValid(address)) {
      STToast.show(context, _t('ewallet_address_format_error'));
      return;
    }
    if (code.isEmpty) {
      STToast.show(context, _t('enter_phone_or_email_verification_code'));
      return;
    }
    if (currency == null) {
      STToast.show(context, _t('no_currency'));
      return;
    }
    if (currency.networks.isNotEmpty && _network.isEmpty) {
      STToast.show(context, _t('please_choose_net'));
      return;
    }

    setState(() => _submitting = true);
    try {
      final service = ref.read(stServiceProvider);
      await service.addEWallet({
        'name': '',
        'currency': currency.name,
        'network': _network,
        'payment_address': address,
        'verify_code': code,
      });
      await _syncBindFlagsAfterSubmit(service);
      if (!mounted) return;
      context.push(
        '/mine/commit_success',
        extra: const {
          'kind': 'ewallet',
          'fallbackPath': '/mine/ewallet?type=1',
        },
      );
    } catch (e) {
      if (mounted) {
        STToast.show(context, stUserVisibleErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _syncBindFlagsAfterSubmit(STService service) async {
    try {
      final profile = await service.getUserProfile();
      final data = profile['data'];
      if (data is Map<String, dynamic>) {
        ref.read(userStateProvider.notifier).mergeUserInfoApi(data);
      }
    } catch (_) {}
  }

  Future<void> _pasteAddress() async {
    final data = await Clipboard.getData('text/plain');
    final text = _sanitizeWalletAddress(data?.text ?? '');
    if (text.isEmpty) {
      if (mounted) STToast.show(context, _t('paster_no'));
      return;
    }
    _addressCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _showCurrencyPicker() async {
    if (_currencies.isEmpty) return;
    final index = await _showPicker<int>(
      title: _t('choose_currency'),
      items: List.generate(_currencies.length, (index) {
        return _PickerItem(value: index, label: _currencies[index].name);
      }),
      selectedValue: _currencyIndex,
    );
    if (index == null || !mounted) return;
    final current = _currencies[index];
    setState(() {
      _currencyIndex = index;
      _network = current.networks.isNotEmpty ? current.networks.first : '';
    });
  }

  Future<void> _showNetworkPicker() async {
    final current = _currentCurrency;
    if (current == null || current.networks.isEmpty) return;
    final network = await _showPicker<String>(
      title: _t('choose_net'),
      items: current.networks
          .map((item) => _PickerItem(value: item, label: item))
          .toList(),
      selectedValue: _network,
    );
    if (network == null || !mounted) return;
    setState(() => _network = network);
  }

  Future<T?> _showPicker<T>({
    required String title,
    required List<_PickerItem<T>> items,
    required T selectedValue,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      barrierColor: const Color(0x4D000000),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final sheetHeight = (media.size.height * 0.5).clamp(
          300.0,
          media.size.height,
        );
        return Material(
          key: const ValueKey('ewallet_picker_sheet'),
          color: sheetContext.adaptiveSurfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: sheetContext.adaptiveDivider,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: sheetContext.adaptiveTextPrimary,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        child: SizedBox(
                          key: const ValueKey('ewallet_picker_close_button'),
                          width: 44,
                          height: 44,
                          child: Center(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 28,
                                color: sheetContext.adaptiveTextSecondary,
                              ),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      15,
                      20,
                      15,
                      media.padding.bottom + 24,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (itemContext, index) {
                      final item = items[index];
                      final selected = item.value == selectedValue;
                      return _PickerSheetItem<T>(
                        key: ValueKey('ewallet_picker_item_${item.label}'),
                        item: item,
                        selected: selected,
                        onTap: () => Navigator.pop(context, item.value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    final current = _currentCurrency;
    final networks = current?.networks ?? const <String>[];
    final user = ref.watch(userStateProvider);
    final verCodeTarget = _verCodeTargetForUser(user);
    final verCodeHint = _verCodeHint(verCodeTarget, _t);
    final verCodeContactText = _verCodeContactText(user, verCodeTarget, _t);
    if (networks.isNotEmpty && _network.isEmpty) {
      _network = networks.first;
    }

    return STKeyboardActions(
      focusNodes: [_addressFocus, _verifyCodeFocus],
      child: Scaffold(
        backgroundColor: context.adaptiveSurfacePrimary,
        appBar: AppBar(
          title: Text(_t('add_digital_wallet')),
          elevation: 0,
          backgroundColor: context.adaptiveSurfacePrimary,
          foregroundColor: context.adaptiveTextPrimary,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: context.adaptiveTextPrimary),
        ),
        body: _isLoading
            ? const Center(child: STLoadAnimationView())
            : ListView(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
                children: [
                  _SelectorField(
                    label: _t('currency'),
                    value: current?.name ?? '',
                    placeholder: _t('please_choose_currency'),
                    onTap: _currencies.isEmpty ? null : _showCurrencyPicker,
                  ),
                  const SizedBox(height: 12),
                  _SelectorField(
                    label: _t('net'),
                    value: _network,
                    placeholder: networks.isEmpty
                        ? _t('no_network_options')
                        : _t('please_choose_net'),
                    onTap: networks.isEmpty ? null : _showNetworkPicker,
                  ),
                  const SizedBox(height: 18),
                  _InputShell(
                    label: _t('wallet_address'),
                    trailing: TextButton(
                      onPressed: _pasteAddress,
                      child: Text(_t('paster')),
                    ),
                    child: TextField(
                      key: const ValueKey('ewallet_add_address_field'),
                      controller: _addressCtrl,
                      focusNode: _addressFocus,
                      inputFormatters: const [_WalletAddressFormatter()],
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: _t('enter_electronic_wallet_address'),
                        hintStyle: TextStyle(color: context.adaptiveTextHint),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InputShell(
                    label: _t('verify_code'),
                    trailing: TextButton(
                      onPressed: (_sendingCode || _resendSec > 0)
                          ? null
                          : _sendCode,
                      child: Text(
                        _resendSec > 0
                            ? '${_t('verify_code_send_again')}(${_resendSec}s)'
                            : _t('get_verification_code'),
                        style: TextStyle(
                          color: (_sendingCode || _resendSec > 0)
                              ? context.adaptiveTextHint
                              : const Color(0xFF00B57A),
                        ),
                      ),
                    ),
                    child: TextField(
                      key: const ValueKey('ewallet_add_verify_code_field'),
                      controller: _verifyCodeCtrl,
                      focusNode: _verifyCodeFocus,
                      keyboardType: verCodeTarget == _EWalletVerCodeTarget.phone
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        hintText: verCodeHint,
                        hintStyle: TextStyle(color: context.adaptiveTextHint),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      verCodeContactText,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('add_wallet_bottom_tip'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      key: const ValueKey('ewallet_add_submit_button'),
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _t('submit'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String value;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 11),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ),
        Material(
          color: context.adaptiveMutedBlock,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              height: 54,
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      value.isNotEmpty ? value : placeholder,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: value.isNotEmpty
                            ? context.adaptiveTextPrimary
                            : context.adaptiveTextHint,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: enabled
                        ? context.adaptiveTextSecondary
                        : context.adaptiveTextHint,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerSheetItem<T> extends StatelessWidget {
  const _PickerSheetItem({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _PickerItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.adaptiveCard,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 28,
                  color: Color(0xFF58C879),
                ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputShell extends StatelessWidget {
  const _InputShell({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: context.adaptiveMutedBlock,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _EWalletSwipeActionRow extends StatelessWidget {
  const _EWalletSwipeActionRow({
    required this.child,
    required this.actions,
    required this.isOpen,
    required this.onAction,
    required this.actionLabels,
    this.onOpen,
    this.onClose,
  });

  static const double _buttonWidth = 60;

  final Widget child;
  final List<_EWalletAction> actions;
  final bool isOpen;
  final ValueChanged<_EWalletAction> onAction;
  final Map<_EWalletAction, String> actionLabels;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  double get _openOffset => actions.length * _buttonWidth;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx < -3) {
          onOpen?.call();
        } else if (details.delta.dx > 3) {
          onClose?.call();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MineFinanceTheme.cardRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions
                      .map(
                        (action) => _EWalletSwipeButton(
                          action: action,
                          label: actionLabels[action],
                          width: _buttonWidth,
                          onTap: () => onAction(action),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                isOpen ? -_openOffset : 0,
                0,
                0,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _EWalletSwipeButton extends StatelessWidget {
  const _EWalletSwipeButton({
    required this.action,
    required this.label,
    required this.width,
    required this.onTap,
  });

  final _EWalletAction action;
  final String? label;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDefault = action == _EWalletAction.setDefault;
    return SizedBox(
      width: width,
      child: Material(
        color: isDefault ? const Color(0xFFF9CE59) : const Color(0xFFFF6E2E),
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label ?? action.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDefault
                    ? MineFinanceTheme.textPrimary(context)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CryptoCurrencyItem {
  final String name;
  final List<String> networks;

  const _CryptoCurrencyItem({required this.name, required this.networks});

  factory _CryptoCurrencyItem.fromDynamic(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    final networks = <String>[];
    final rawNet = data['networks'];
    if (rawNet is List) {
      for (final n in rawNet) {
        final s = n?.toString() ?? '';
        if (s.isNotEmpty) networks.add(s);
      }
    }
    return _CryptoCurrencyItem(
      name:
          data['cryptocurrency_name']?.toString() ??
          data['currency']?.toString() ??
          '',
      networks: networks,
    );
  }
}

class _PickerItem<T> {
  const _PickerItem({required this.value, required this.label});

  final T value;
  final String label;
}

class _WalletAddressFormatter extends TextInputFormatter {
  const _WalletAddressFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _sanitizeWalletAddress(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

List<_CryptoCurrencyItem> _extractCryptoCurrencies(Map<String, dynamic> raw) {
  final data = raw['data'] is Map<String, dynamic>
      ? Map<String, dynamic>.from(raw['data'] as Map)
      : raw;
  final crypto = data['crypto_currencies'];
  final list = <_CryptoCurrencyItem>[];

  if (crypto is List) {
    for (final item in crypto) {
      if (item is Map) {
        list.add(_CryptoCurrencyItem.fromDynamic(item));
      }
    }
  }
  return list;
}

String _sanitizeWalletAddress(String raw) {
  return raw.replaceAll(RegExp(r'[\r\n]+'), '').trim();
}

bool _isEWalletPaymentAddressFormatValid(String raw) {
  final text = raw.trim();
  if (text.length < 10 || text.length > 100) return false;
  return RegExp(r'^[A-Za-z0-9]+$').hasMatch(text);
}

enum _EWalletAction { setDefault, unbind, delete }

enum _EWalletBindTarget { phone, email }

enum _EWalletVerCodeTarget { phone, email }

const bool _defaultLoginShowsPhoneFirst = true;

_EWalletVerCodeTarget _verCodeTargetForUser(UserState user) {
  if (user.isBindEmail && user.isBindPhone) {
    return _defaultLoginShowsPhoneFirst
        ? _EWalletVerCodeTarget.phone
        : _EWalletVerCodeTarget.email;
  }
  if (user.isBindPhone) return _EWalletVerCodeTarget.phone;
  if (user.isBindEmail) return _EWalletVerCodeTarget.email;
  return _defaultLoginShowsPhoneFirst
      ? _EWalletVerCodeTarget.phone
      : _EWalletVerCodeTarget.email;
}

String _verCodeHint(
  _EWalletVerCodeTarget target,
  String Function(String key) t,
) {
  return target == _EWalletVerCodeTarget.phone
      ? t('please_input_phone_tip')
      : t('please_input_email_tip');
}

String _verCodeContactText(
  UserState user,
  _EWalletVerCodeTarget target,
  String Function(String key) t,
) {
  if (target == _EWalletVerCodeTarget.phone) {
    final area = user.phoneAreaCode.trim();
    final phone = user.phone.trim();
    final areaText = area.isNotEmpty ? '($area)' : '';
    return '${t('local_phone_num')}$areaText$phone';
  }
  return '${t('local_email')}${user.email.trim()}';
}
