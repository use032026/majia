import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jufu/shared/widgets/st_pull_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jufu/shared/widgets/st_load_animation_view.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/network/st_error_messages.dart';
import '../../core/network/st_service.dart';
import '../../core/models/auth_status_model.dart';
import '../../core/models/bank_card_model.dart';
import '../../core/router/route_observer.dart';
import '../../core/models/user_state.dart';
import '../../core/theme/context_adaptive_colors.dart';
import '../../shared/widgets/ios_common_alert_dialog.dart';
import '../../shared/widgets/mine_finance_theme.dart';
import '../../shared/widgets/st_localized_prompt.dart';
import '../../shared/widgets/st_toast.dart';

/// 银行卡管理页面 — UI 对齐 iOS STBankCardListViewController（浅灰底、分组留白、圆角卡片、角标）
class BankCardPage extends ConsumerStatefulWidget {
  const BankCardPage({super.key});

  @override
  ConsumerState<BankCardPage> createState() => _BankCardPageState();
}

class _BankCardText {
  const _BankCardText._();

  static final Map<String, String> fallbackText = {
    'bank_card': stLocalizedTextFromZhHans('银行卡'),
    'no_bank_card_tip1': stLocalizedTextFromZhHans('暂无银行卡'),
    'add_bank_card': stLocalizedTextFromZhHans('添加银行卡'),
    'set_to_default_success': stLocalizedTextFromZhHans('已设为默认'),
    'warm_tips': stLocalizedTextFromZhHans('温馨提示'),
    'sure_to_set_default_bank_card': stLocalizedTextFromZhHans('确认设为默认？'),
    'cancel': stLocalizedTextFromZhHans('取消'),
    'certain': stLocalizedTextFromZhHans('确定'),
    'set_default_failed': stLocalizedTextFromZhHans('设为默认失败'),
    'set_failed': stLocalizedTextFromZhHans(''),
    'sure_to_unbind_bank_card': stLocalizedTextFromZhHans('确认解绑该银行卡？'),
    'sure_to_delete_rejected_bank_card': stLocalizedTextFromZhHans('确认删除该银行卡？'),
    'operation_failed': stLocalizedTextFromZhHans(''),
    'load_failed': stLocalizedTextFromZhHans('加载失败'),
    'bind_bank_need_identifity': stLocalizedTextFromZhHans('需要身份验证'),
    'bind_bank_please_identifity': stLocalizedTextFromZhHans(
      '请先完成身份验证，然后再使用此服务',
    ),
    'identity': stLocalizedTextFromZhHans('身份认证'),
    'get_certified_now': stLocalizedTextFromZhHans('立即认证'),
    'set_default': stLocalizedTextFromZhHans('设为默认'),
    'unbind': stLocalizedTextFromZhHans('解绑'),
    'delete': stLocalizedTextFromZhHans('删除'),
    'under_review': stLocalizedTextFromZhHans('审核中'),
    'default_text': stLocalizedTextFromZhHans('默认'),
    'bank_card_fail_tip': stLocalizedTextFromZhHans('您的银行卡认证未通过。'),
    'reason': stLocalizedTextFromZhHans('原因：'),
    'branch_name': stLocalizedTextFromZhHans('支行名称'),
  };
}

class _BankCardPageState extends ConsumerState<BankCardPage> with RouteAware {
  List<BankCardModel> _cards = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _loadFailed = false;
  bool _routeSubscribed = false;
  bool _skipNextPopRefresh = false;
  String? _openActionCardId;
  String? _localizedLanguageCode;
  Map<String, String> _localized = _BankCardText.fallbackText;

  void _ensureLocalizedText() {
    final localizations = ref.read(stLocalizationsProvider);
    final languageCode = localizations.languageCode;
    if (_localizedLanguageCode == languageCode) return;
    _localizedLanguageCode = languageCode;
    localizations.textMap(_BankCardText.fallbackText).then((entries) {
      if (!mounted || _localizedLanguageCode != languageCode) return;
      setState(() => _localized = entries);
    });
  }

  String _t(String key) =>
      _localized[key] ?? _BankCardText.fallbackText[key] ?? key;

  void _toast(String message) {
    if (mounted) STToast.show(context, stSanitizeUserVisibleText(message));
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
      debugPrint('BankCard sync bind flags: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBankCards();
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
    _loadBankCards(showLoading: false);
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

  Future<void> _loadBankCards({bool showLoading = true}) async {
    final shouldShowLoading = showLoading || !_hasLoadedOnce;
    setState(() {
      _isLoading = shouldShowLoading;
      _openActionCardId = null;
    });

    try {
      final service = ref.read(stServiceProvider);
      final data = await service.getBankCards();
      if (mounted) {
        setState(() {
          _cards = data
              .whereType<Map<String, dynamic>>()
              .map(BankCardModel.fromJson)
              .toList();
          _hasLoadedOnce = true;
          _isLoading = false;
          _loadFailed = false;
        });
        await _syncBindFlags();
      }
    } catch (e) {
      if (mounted) {
        if (shouldShowLoading) {
          setState(() {
            _isLoading = false;
            _loadFailed = true;
          });
        }
        showStLocalizedToastByKey(
          context,
          'requestfail',
          fallback: stDefaultLoadErrorText,
        );
      }
    }
  }

  void _hideSwipe() {
    if (_openActionCardId == null || !mounted) return;
    setState(() => _openActionCardId = null);
  }

  List<_BankCardAction> _cardActions(BankCardModel card) {
    if (card.id.isEmpty) return const [];
    if (card.isPendingReview) {
      return const [];
    }

    if (card.isCertified) {
      return card.isDefault
          ? const [_BankCardAction.unbind]
          : const [_BankCardAction.unbind, _BankCardAction.setDefault];
    }

    if (card.isRejected) {
      return const [_BankCardAction.delete];
    }

    return const [];
  }

  void _handleCardAction(BankCardModel card, _BankCardAction action) {
    _hideSwipe();
    switch (action) {
      case _BankCardAction.setDefault:
        _setDefaultCard(card);
        break;
      case _BankCardAction.delete:
        _deleteCard(card, isDelete: true);
        break;
      case _BankCardAction.unbind:
        _deleteCard(card, isDelete: false);
        break;
    }
  }

  void _ensureBusinessOk(Map<String, dynamic> raw, String fallback) {
    final code = raw['code'];
    final ok = code == null || code == 0 || code == '0';
    if (!ok) {
      throw Exception(raw['message']?.toString() ?? fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocalizedText();
    return Scaffold(
      backgroundColor: MineFinanceTheme.pageBg(context),
      appBar: AppBar(
        title: Text(_t('bank_card')),
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        backgroundColor: MineFinanceTheme.navBg(context),
        foregroundColor: MineFinanceTheme.textPrimary(context),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/st_mine_add.png',
              width: 18,
              height: 18,
            ),
            onPressed: _openAddBankCardFlow,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: STLoadAnimationView())
          : STPullRefresh(
              color: const Color(0xFF00B57A),
              onRefresh: () => _loadBankCards(showLoading: false),
              child: _cards.isEmpty
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
                      itemCount: _cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final card = _cards[index];
                        final actions = _cardActions(card);
                        return _BankCardSwipeActionRow(
                          actions: actions,
                          isOpen: _openActionCardId == card.id,
                          onOpen: actions.isEmpty
                              ? null
                              : () =>
                                    setState(() => _openActionCardId = card.id),
                          onClose: _hideSwipe,
                          onAction: (action) => _handleCardAction(card, action),
                          actionLabels: {
                            _BankCardAction.setDefault: _t('set_default'),
                            _BankCardAction.unbind: _t('unbind'),
                            _BankCardAction.delete: _t('delete'),
                          },
                          child: MineBankCardTile(
                            bankName: card.displayBankName,
                            holderName: card.cardHolder,
                            branchName: card.branch,
                            cardNumberDisplay: card.maskedCardNumber,
                            currency: card.currency,
                            status: card.status,
                            isDefault: card.isDefault,
                            failRemark: card.remark,
                            branchLabel: _t('branch_name'),
                            reviewLabel: _t('under_review'),
                            defaultLabel: _t('default_text'),
                            failureTitle: _t('bank_card_fail_tip'),
                            reasonLabel: _t('reason'),
                            onCopy: card.isCertified
                                ? () => copyMineClipboard(
                                    context,
                                    card.cardNumber.replaceAll(' ', ''),
                                  )
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
                    _t('no_bank_card_tip1'),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _blackAddButton(onTap: _openAddBankCardFlow),
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
      width: 110,
      height: 26,
      child: Material(
        key: const ValueKey('bank_card_empty_add_button'),
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Center(
            child: Text(
              _t('add_bank_card'),
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

  Object _cardRequestId(BankCardModel card) {
    return int.tryParse(card.id) ?? card.id;
  }

  Future<void> _setDefaultCard(BankCardModel card) async {
    if (card.id.isEmpty) return;
    if (card.isDefault) {
      _toast(_t('set_to_default_success'));
      return;
    }

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
      final raw = await service.setDefaultBankCard({'id': _cardRequestId(card)});
      _ensureBusinessOk(raw, _t('set_default_failed'));
      if (!mounted) return;
      setState(() {
        _cards = _cards
            .map((item) => item.copyWith(isDefault: item.id == card.id))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        _toast('${_t('set_failed')}: ${stUserVisibleErrorMessage(e)}');
      }
    }
  }

  Future<void> _deleteCard(BankCardModel card, {required bool isDelete}) async {
    if (card.id.isEmpty) return;

    _skipNextPopRefresh = true;
    final confirm = await showIosCommonAlertDialog(
      context: context,
      title: _t('warm_tips'),
      message: isDelete
          ? _t('sure_to_delete_rejected_bank_card')
          : _t('sure_to_unbind_bank_card'),
      cancelText: _t('cancel'),
      confirmText: _t('certain'),
    );

    if (confirm == true) {
      try {
        final service = ref.read(stServiceProvider);
        await service.deleteBankCard({'id': _cardRequestId(card)});
        if (!mounted) return;
        if (card.isDefault) {
          await _loadBankCards(showLoading: false);
        } else {
          setState(() {
            _cards = _cards.where((item) => item.id != card.id).toList();
          });
        }
      } catch (e) {
        if (mounted) {
          _toast('${_t('operation_failed')}: ${stUserVisibleErrorMessage(e)}');
        }
      }
    }
  }

  Future<void> _openAddBankCardFlow() async {
    _hideSwipe();
    final isAuthed =
        ref.read(userStateProvider).isAuthed ||
        await _refreshAuthStatusBeforeAdd();
    if (!mounted) return;
    if (!isAuthed) {
      final goAuth = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        barrierColor: const Color(0x4D000000),
        backgroundColor: Colors.transparent,
        builder: _buildBindBankAuthSheet,
      );
      if (!mounted) return;
      if (goAuth == true) await context.push('/mine/auth');
      return;
    }

    _skipNextPopRefresh = true;
    final submitted = await context.push<bool>(
      '/mine/bankcard/add',
      extra: {'existingCards': _cards},
    );
    if (submitted == true && mounted) {
      await _loadBankCards(showLoading: false);
    }
  }

  Future<bool> _refreshAuthStatusBeforeAdd() async {
    try {
      final service = ref.read(stServiceProvider);
      final raw = await service.getAuthStatus();
      final payload = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final status = _authStatusFromPayload(payload);
      if (status == null) return ref.read(userStateProvider).isAuthed;
      ref.read(userStateProvider.notifier).updateAuthStatus(status);
      return status.isApproved;
    } catch (e) {
      debugPrint('BankCard refresh auth status: $e');
      return ref.read(userStateProvider).isAuthed;
    }
  }

  AuthStatusModel? _authStatusFromPayload(Map<String, dynamic> payload) {
    final rawIdentity = payload['identity_status'] ?? payload['identityStatus'];
    final identityStatus = rawIdentity is num
        ? rawIdentity.toInt()
        : int.tryParse(rawIdentity?.toString() ?? '');
    if (identityStatus != null) {
      return AuthStatusModel(
        status: switch (identityStatus) {
          1 => 'pending',
          2 => 'approved',
          3 => 'rejected',
          _ => 'none',
        },
      );
    }

    final rawStatus = payload['status'];
    final status = rawStatus?.toString();
    if (status == null || status.isEmpty) return null;
    return AuthStatusModel.fromJson(payload);
  }

  Widget _buildBindBankAuthSheet(BuildContext sheetContext) {
    final bottom = MediaQuery.of(sheetContext).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: sheetContext.adaptivePageGrey,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      padding: EdgeInsets.only(bottom: bottom + 24),
      child: Stack(
        children: [
          const SizedBox(height: 10),
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
                  _t('bind_bank_need_identifity'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: sheetContext.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _t('bind_bank_please_identifity'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: sheetContext.adaptiveTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: _authRequirementRow(sheetContext),
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
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authRequirementRow(BuildContext sheetContext) {
    return Material(
      color: sheetContext.adaptiveCard,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.of(sheetContext).pop(true),
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 15),
              Image.asset(
                'assets/images/st_mine_real_auth.png',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  _t('identity'),
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
                  color: const Color(0xFF477DFF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _t('get_certified_now'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 15),
            ],
          ),
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
          onTap: () => Navigator.of(sheetContext).pop(false),
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
}

class _BankCardSwipeActionRow extends StatelessWidget {
  const _BankCardSwipeActionRow({
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
  final List<_BankCardAction> actions;
  final bool isOpen;
  final ValueChanged<_BankCardAction> onAction;
  final Map<_BankCardAction, String> actionLabels;
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
            if (isOpen)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions
                        .map(
                          (action) => _BankCardSwipeButton(
                            action: action,
                            label: actionLabels[action]!,
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
              child: SizedBox(width: double.infinity, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCardSwipeButton extends StatelessWidget {
  const _BankCardSwipeButton({
    required this.action,
    required this.label,
    required this.width,
    required this.onTap,
  });

  final _BankCardAction action;
  final String label;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDefault = action == _BankCardAction.setDefault;
    return SizedBox(
      width: width,
      child: Material(
        color: isDefault ? const Color(0xFFF9CE59) : const Color(0xFFFF6E2E),
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
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

enum _BankCardAction { setDefault, unbind, delete }
