import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/st_localizations.dart';
import '../../core/services/wallet_action_handler.dart';
import '../../shared/widgets/st_network_image.dart';
import '../../shared/widgets/st_toast.dart';

/// 活动弹窗路由页面
/// 对齐 iOS STConfigCardHandler.cardPopHandler 中的弹窗类型：
///   /action/trial                    → STBonusAlertView（体验金）
///   /action/bonus                    → STBonusAlertView（赠金）
///   /action/tradeUnlockTaskCompleted → STCompleteTaskAlertView
///   /action/tradeUnlockTaskUnCompleted → STNewBieRewardsAlertView
///
/// 使用方式：在 GoRouter 中注册，通过 context.push 打开，显示为全屏 Dialog 样式
///
/// iOS 弹窗参考（STLaunchPlaceholderView.m / STConfigCardHandler.m）：
///   - popup_image_url + activity_url → Banner + 点击跳转
///   - total_reward_amount → 完成奖励金额展示
///   - taskInfo + isFromDeposit → 任务列表 + 入金引导

void _openDepositAfterDismiss(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final rootContext = STToast.navigatorKey.currentContext ?? context;
  context.pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    container
        .read(walletActionHandlerProvider)
        .handleWalletAction(
          context: rootContext,
          action: 'deposit',
          onPassed: () {
            if (rootContext.mounted) {
              rootContext.push('/mine/deposit');
            }
          },
        );
  });
}

const Map<String, String> _activityFallbackText = {
  'activity_settlement_contact_customer_service': '如有疑问，请联系客服。',
  'activity_settlement_confirm': '确认结算',
  'activity_settlement_tips': r'活动资格将被取消，已赠送的金额＄%@将总账户中扣除，同时将会放弃未领取的$%@交易赠金',
  'activity_settlement_tips2_iOS': r'您已解锁层级L%ld，再充值%@$，解锁层级L%ld，多赠%@$',
  'activity_settlement_tips3_iOS': r'活动资格将被取消，现在结算将放弃$%@领取资格',
  'activity_settlement_tips4_iOS': r'活动资格将被取消，已赠送的金额$%@将从总账户中扣除',
  'activity_settlement_tips5': '活动资格将被取消，现在结算将结束本次活动参与资格',
  'activity_settlement_tips6_iOS': r'您已解锁层级L%ld',
  'bonus_funds_credited_notification_tip_iOS':
      r'免费体验真实交易，亏损由平台承担，交易最高可获$%@现金奖励，有效期%@天',
  'bonus_funds_credited_notification_title_iOS': r'恭喜, $%@体验金已到账',
  'cash_reward_expiring_soon_tips': '体验金将在倒计时结束后收回，\n请尽快充值激活您的现金奖励。',
  'cash_reward_expiring_soon_title_iOS': r'您的 $%@ 现金奖励即将失效',
  'cancel': '取消',
  'certain': '确认',
  'claim_now': '立即领取',
  'complete_identity_verification_tip': '完成身份认证',
  'complete_identity_verification_tip2_iOS': r'立即领取$%@',
  'completed_all_tasks_tip': '恭喜您已完成全部任务',
  'completed_all_tasks_tip2_iOS': r'待解锁额度 $%@',
  'continue_to_claim_rewards_complete_your_first_deposit_tip': '继续领取奖励',
  'continue_to_claim_rewards_complete_your_first_deposit_tip2_iOS':
      r'完成后即可领取全部奖励 $%@',
  'currently_participating_trial_experience_tips': '您正在参加体验金活动\n充值后可提取现金奖励',
  'deposit_now_to_claim': '立即入金领取',
  'gift_money_activity_settlement': '赠金活动结算',
  'go_register': '注册',
  'go_to_recharge': '去充值',
  'keep_the_reward': '保住奖励',
  'maximum_bonus_reward_tips_iOS': r'您的操作非常专业，目前已锁定最高 $%@ 现金奖励。立即充值，将奖励划入真实账户。',
  'maximum_bonus_reward_title_iOS': r'已获得最高赠金奖励 $%@',
  'new_customer_exclusive_benefit1_desc': '充值立涨50%本金，加速您的交易盈利。',
  'new_customer_exclusive_benefit1_title': '100% 入金赠金',
  'new_customer_exclusive_benefit2_desc': r'领体验金每手返现，最高可领取 $50!',
  'new_customer_exclusive_benefit2_title': r'$50交易返赠',
  'new_customer_exclusive_benefits_subtitle': '恭喜您获得以下福利',
  'new_customer_exclusive_benefits_title': '新客专享权益',
  'new_user_exclusive_rewards_await_claiming_tip': '新用户专享奖励待领取',
  'new_user_exclusive_rewards_await_claiming_tip2_iOS': r'注册即可领取$%@奖励',
  'not_available_today': '今日不再提示',
  'reward_description': '奖励详情',
  'start_trading_to_unlock': '开始交易解锁',
  'to_be_completed_later': '稍后完成',
  'to_trade': '去交易',
  'trial_funds_have_been_exhausted_tips_iOS':
      r'已解锁 $%@ 现金奖励，入金后即可获得。现在就去实战试试手吧，真实收益等你解锁。',
  'trial_funds_have_been_exhausted_title': '体验金已用完，入金转战实盘',
  'view_activity_rules': '查看活动规则',
};

Future<Map<String, String>> _loadActivityText(BuildContext context) {
  return STLocalizations.ofContext(context).textMap(_activityFallbackText);
}

String _lt(Map<String, String> labels, String key) {
  return labels[key] ?? _activityFallbackText[key] ?? key;
}

String _fmtIos(String pattern, List<Object?> values) {
  var index = 0;
  return pattern.replaceAllMapped(
    RegExp(r'%[@sd]|%ld'),
    (_) => index < values.length ? '${values[index++]}' : '',
  );
}

int? activityPopupIsFromDepositParam(Map<String, dynamic>? params) {
  final value = params?['isFromDesposit'] ?? params?['isFromDeposit'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

/// 体验金 / 赠金弹窗（对齐 iOS STBonusAlertView）
class BonusAlertPage extends StatelessWidget {
  final String? popupImageUrl;
  final String? activityUrl;
  final String title;

  const BonusAlertPage({
    super.key,
    this.popupImageUrl,
    this.activityUrl,
    this.title = '活动',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      body: Center(
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    final link = activityUrl?.trim() ?? '';
                    context.pop();
                    if (link.isEmpty) return;
                    context.push('/web?link=${Uri.encodeComponent(link)}');
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      key: const ValueKey('activity_bonus_popup_image_box'),
                      width: 320,
                      height: 377,
                      child: _BonusPopupImage(url: popupImageUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Image.asset(
                    'assets/images/st_bonus_close.png',
                    key: const ValueKey('activity_bonus_popup_close'),
                    width: 24,
                    height: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BonusPopupImage extends StatelessWidget {
  const _BonusPopupImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';
    if (imageUrl.isEmpty) {
      return Image.asset(
        'assets/images/st_bonus_pop_placeholder.png',
        fit: BoxFit.contain,
      );
    }
    return STNetworkImage(
      key: const ValueKey('activity_bonus_popup_image'),
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => Image.asset(
        'assets/images/st_bonus_pop_placeholder.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class TrialBonusStatusPopPage extends ConsumerWidget {
  const TrialBonusStatusPopPage({super.key, required this.info});

  final Map<String, dynamic> info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, String>>(
      future: _loadActivityText(context),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? _activityFallbackText;
        final state = _TrialBonusPopupState.fromInfo(info, labels: labels);
        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.85),
          body: Center(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    key: const ValueKey('activity_trial_status_shell'),
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Image.asset(
                              'assets/images/st_pop_bg.png',
                              width: 320,
                              fit: BoxFit.fitWidth,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 52, 28, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text.rich(
                                _highlightMoney(state.title),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF333333),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text.rich(
                                _highlightMoney(state.message),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF333333),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _TrialBonusButton(
                                label: state.buttonText,
                                onPressed: () {
                                  if (state.opensRules) {
                                    final url = state.activityUrl;
                                    context.pop();
                                    if (url.isNotEmpty) {
                                      context.push(
                                        '/web?link=${Uri.encodeComponent(url)}',
                                      );
                                    }
                                    return;
                                  }
                                  _openDepositAfterDismiss(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -65,
                    child: Image.asset(
                      state.assetPath,
                      key: ValueKey(
                        'activity_trial_status_${state.assetKey}_image',
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
}

class _TrialBonusButton extends StatelessWidget {
  const _TrialBonusButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/st_button_bg.png'),
            fit: BoxFit.fill,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Image.asset(
              'assets/images/st_button_right_icon.png',
              width: 18,
              height: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialBonusPopupState {
  const _TrialBonusPopupState({
    required this.assetPath,
    required this.assetKey,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.opensRules,
    required this.activityUrl,
  });

  final String assetPath;
  final String assetKey;
  final String title;
  final String message;
  final String buttonText;
  final bool opensRules;
  final String activityUrl;

  static _TrialBonusPopupState fromInfo(
    Map<String, dynamic> info, {
    Map<String, String> labels = _activityFallbackText,
  }) {
    final params = _asMap(info['params']);
    final subType = info['sub_type']?.toString() ?? '';
    final reward = _money(params['reward_amount']);
    final trial = _money(params['trial_amount']);
    final days = params['validity_days']?.toString() ?? '';
    final activityUrl = params['activity_url']?.toString() ?? '';

    switch (subType) {
      case 'max_reward':
        return _TrialBonusPopupState(
          assetPath: 'assets/images/st_trial_highest_rewards.png',
          assetKey: 'highest_rewards',
          title: _fmtIos(_lt(labels, 'maximum_bonus_reward_title_iOS'), [
            reward.replaceFirst(r'$', ''),
          ]),
          message: _fmtIos(_lt(labels, 'maximum_bonus_reward_tips_iOS'), [
            reward.replaceFirst(r'$', ''),
          ]),
          buttonText: _lt(labels, 'go_to_recharge'),
          opensRules: false,
          activityUrl: activityUrl,
        );
      case 'exhausted':
        return _TrialBonusPopupState(
          assetPath: 'assets/images/st_trial_used.png',
          assetKey: 'used',
          title: _lt(labels, 'trial_funds_have_been_exhausted_title'),
          message: _fmtIos(
            _lt(labels, 'trial_funds_have_been_exhausted_tips_iOS'),
            [reward.replaceFirst(r'$', '')],
          ),
          buttonText: _lt(labels, 'go_to_recharge'),
          opensRules: false,
          activityUrl: activityUrl,
        );
      case 'expiring':
        return _TrialBonusPopupState(
          assetPath: 'assets/images/st_trial_rewards_invalid.png',
          assetKey: 'rewards_invalid',
          title: _fmtIos(_lt(labels, 'cash_reward_expiring_soon_title_iOS'), [
            reward.replaceFirst(r'$', ''),
          ]),
          message: _lt(labels, 'cash_reward_expiring_soon_tips'),
          buttonText: _lt(labels, 'keep_the_reward'),
          opensRules: false,
          activityUrl: activityUrl,
        );
      case 'credited':
      default:
        return _TrialBonusPopupState(
          assetPath: 'assets/images/st_trial_received.png',
          assetKey: 'credited',
          title: _fmtIos(
            _lt(labels, 'bonus_funds_credited_notification_title_iOS'),
            [trial.replaceFirst(r'$', '')],
          ),
          message: _fmtIos(
            _lt(labels, 'bonus_funds_credited_notification_tip_iOS'),
            [reward.replaceFirst(r'$', ''), days],
          ),
          buttonText: _lt(labels, 'view_activity_rules'),
          opensRules: true,
          activityUrl: activityUrl,
        );
    }
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _money(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return r'$0';
  return text.startsWith(r'$') ? text : '\$$text';
}

TextSpan _highlightMoney(String text) {
  final spans = <TextSpan>[];
  final exp = RegExp(r'\$[0-9]+(?:\.[0-9]+)?');
  var cursor = 0;
  for (final match in exp.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(color: Color(0xFFFF3A12)),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(children: spans);
}

String activitySettlementMessage({
  required String giftedAmount,
  required String receiveAmount,
  Map<String, String> labels = _activityFallbackText,
}) {
  final gifted = num.tryParse(giftedAmount) ?? 0;
  final receive = num.tryParse(receiveAmount) ?? 0;
  if (gifted == 0 && receive > 0) {
    return _fmtIos(_lt(labels, 'activity_settlement_tips3_iOS'), [
      _trimMoney(receiveAmount),
    ]);
  }
  if (gifted > 0 && receive == 0) {
    return _fmtIos(_lt(labels, 'activity_settlement_tips4_iOS'), [
      _trimMoney(giftedAmount),
    ]);
  }
  if (gifted == 0 && receive == 0) {
    return _lt(labels, 'activity_settlement_tips5');
  }
  return _fmtIos(_lt(labels, 'activity_settlement_tips'), [
    _trimMoney(giftedAmount),
    _trimMoney(receiveAmount),
  ]);
}

String _trimMoney(Object? value) {
  final number = num.tryParse('${value ?? ''}');
  if (number == null) return '${value ?? ''}';
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

class ActivitySettlementPopInfo {
  const ActivitySettlementPopInfo({
    required this.currentTierLevel,
    required this.nextTierLevel,
    required this.rechargeAmount,
    required this.bonusAmount,
    required this.isTierDesignated,
  });

  final int currentTierLevel;
  final int nextTierLevel;
  final String rechargeAmount;
  final String bonusAmount;
  final bool isTierDesignated;

  static ActivitySettlementPopInfo? fromDetailAndProgress({
    required Map<String, dynamic> detail,
    required Map<String, dynamic> progress,
  }) {
    final currentLevel =
        int.tryParse('${progress['current_tier_level'] ?? 0}') ?? 0;
    final tiers = detail['tiers'] is List ? detail['tiers'] as List : const [];
    Map<String, dynamic>? nextTier;
    for (final item in tiers) {
      if (item is! Map) continue;
      final tier = Map<String, dynamic>.from(item);
      final level = int.tryParse('${tier['level'] ?? 0}') ?? 0;
      if (level > currentLevel) {
        nextTier = tier;
        break;
      }
    }
    if (nextTier == null) return null;
    final netDepositStart =
        num.tryParse('${nextTier['net_deposit_start'] ?? 0}') ?? 0;
    final currentNetDeposit =
        num.tryParse('${progress['current_net_deposit'] ?? 0}') ?? 0;
    final totalGift =
        num.tryParse('${nextTier['total_gift_amount'] ?? 0}') ?? 0;
    final totalPosted =
        num.tryParse('${nextTier['total_posted_amount'] ?? 0}') ?? 0;
    return ActivitySettlementPopInfo(
      currentTierLevel: currentLevel,
      nextTierLevel: int.tryParse('${nextTier['level'] ?? 0}') ?? 0,
      rechargeAmount: _trimMoney(netDepositStart - currentNetDeposit),
      bonusAmount: _trimMoney(totalGift + totalPosted),
      isTierDesignated:
          detail['is_tier_designated'] == true ||
          detail['is_tier_designated']?.toString() == '1',
    );
  }
}

Future<bool?> showActivitySettlementDialog({
  required BuildContext context,
  required String giftedAmount,
  required String receiveAmount,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) => ActivitySettlementDialog(
      giftedAmount: giftedAmount,
      receiveAmount: receiveAmount,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
}

Future<ActivitySettlementRetainAction?> showActivitySettlementRetainDialog({
  required BuildContext context,
  required ActivitySettlementPopInfo info,
}) {
  return showDialog<ActivitySettlementRetainAction>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) => ActivitySettlementRetainDialog(
      info: info,
      onPrimary: () => Navigator.of(
        dialogContext,
      ).pop(ActivitySettlementRetainAction.primary),
      onConfirm: () => Navigator.of(
        dialogContext,
      ).pop(ActivitySettlementRetainAction.confirm),
    ),
  );
}

enum ActivitySettlementRetainAction { primary, confirm }

class ActivitySettlementDialog extends StatelessWidget {
  const ActivitySettlementDialog({
    super.key,
    required this.giftedAmount,
    required this.receiveAmount,
    required this.onCancel,
    required this.onConfirm,
  });

  final String giftedAmount;
  final String receiveAmount;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadActivityText(context),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? _activityFallbackText;
        return Center(
          child: _ActivitySettlementShell(
            key: const ValueKey('activity_settlement_dialog_shell'),
            title: _lt(labels, 'gift_money_activity_settlement'),
            message: activitySettlementMessage(
              giftedAmount: giftedAmount,
              receiveAmount: receiveAmount,
              labels: labels,
            ),
            extraMessage: _lt(
              labels,
              'activity_settlement_contact_customer_service',
            ),
            primaryText: _lt(labels, 'cancel'),
            confirmText: _lt(labels, 'activity_settlement_confirm'),
            onPrimary: onCancel,
            onConfirm: onConfirm,
          ),
        );
      },
    );
  }
}

class ActivitySettlementRetainDialog extends StatelessWidget {
  const ActivitySettlementRetainDialog({
    super.key,
    required this.info,
    required this.onPrimary,
    required this.onConfirm,
  });

  final ActivitySettlementPopInfo info;
  final VoidCallback onPrimary;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadActivityText(context),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? _activityFallbackText;
        final message = info.isTierDesignated
            ? _fmtIos(_lt(labels, 'activity_settlement_tips2_iOS'), [
                info.currentTierLevel,
                info.rechargeAmount,
                info.nextTierLevel,
                info.bonusAmount,
              ])
            : _fmtIos(_lt(labels, 'activity_settlement_tips6_iOS'), [
                info.currentTierLevel,
              ]);
        return Center(
          child: _ActivitySettlementShell(
            key: const ValueKey('activity_settlement_retain_dialog_shell'),
            title: _lt(labels, 'gift_money_activity_settlement'),
            message: message,
            primaryText: info.isTierDesignated
                ? _lt(labels, 'go_to_recharge')
                : _lt(labels, 'to_trade'),
            confirmText: _lt(labels, 'activity_settlement_confirm'),
            onPrimary: onPrimary,
            onConfirm: onConfirm,
          ),
        );
      },
    );
  }
}

class _ActivitySettlementShell extends StatelessWidget {
  const _ActivitySettlementShell({
    super.key,
    required this.title,
    required this.message,
    required this.primaryText,
    required this.confirmText,
    required this.onPrimary,
    required this.onConfirm,
    this.extraMessage,
  });

  final String title;
  final String message;
  final String? extraMessage;
  final String primaryText;
  final String confirmText;
  final VoidCallback onPrimary;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 320,
            margin: const EdgeInsets.only(top: 50),
            padding: const EdgeInsets.fromLTRB(12, 46, 12, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                if (extraMessage != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      extraMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 23),
                Row(
                  children: [
                    Expanded(
                      child: _ActivitySettlementButton(
                        text: primaryText,
                        backgroundColor: const Color(0xFFF5F5F5),
                        textColor: const Color(0xFF666666),
                        onTap: onPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActivitySettlementButton(
                        text: confirmText,
                        backgroundColor: const Color(0xFFFF7700),
                        textColor: Colors.white,
                        onTap: onConfirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: Image.asset(
              'assets/images/st_activity_settlement.png',
              key: const ValueKey('activity_settlement_image'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySettlementButton extends StatelessWidget {
  const _ActivitySettlementButton({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(17.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

Future<bool?> showTrialBonusTopUpDialog({
  required BuildContext context,
  required TrialBonusTopUpMode mode,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (dialogContext) => TrialBonusTopUpDialog(
      mode: mode,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
}

enum TrialBonusTopUpMode { recharge, transfer }

class TrialBonusTopUpDialog extends StatelessWidget {
  const TrialBonusTopUpDialog({
    super.key,
    required this.mode,
    required this.onCancel,
    required this.onConfirm,
  });

  final TrialBonusTopUpMode mode;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  bool get _isRecharge => mode == TrialBonusTopUpMode.recharge;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadActivityText(context),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? _activityFallbackText;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: _isRecharge ? 65 : 70),
                  child: Container(
                    key: const ValueKey('activity_trial_top_up_dialog_shell'),
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Image.asset(
                              'assets/images/st_pop_bg.png',
                              width: 320,
                              fit: BoxFit.fitWidth,
                            ),
                          ),
                        ),
                        if (!_isRecharge)
                          Positioned(
                            top: 18,
                            right: 18,
                            child: GestureDetector(
                              key: const ValueKey('activity_trial_top_up_close'),
                              onTap: onCancel,
                              child: Image.asset(
                                'assets/images/st_trial_close.png',
                                width: 28,
                                height: 28,
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            _isRecharge ? 12 : 22,
                            _isRecharge ? 62 : 102,
                            _isRecharge ? 12 : 22,
                            _isRecharge ? 20 : 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isRecharge
                                    ? _lt(
                                        labels,
                                        'new_customer_exclusive_benefits_title',
                                      )
                                    : _lt(
                                        labels,
                                        'currently_participating_trial_experience_tips',
                                      ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.35,
                                  fontWeight: _isRecharge
                                      ? FontWeight.w700
                                      : FontWeight.w300,
                                  color: _isRecharge
                                      ? const Color(0xFF333333)
                                      : const Color(0xFF111111),
                                ),
                              ),
                              if (_isRecharge) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _lt(
                                    labels,
                                    'new_customer_exclusive_benefits_subtitle',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    color: Color(0xFF909399),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _TrialBenefitCard(
                                  key: const ValueKey(
                                    'activity_trial_top_up_benefit_1',
                                  ),
                                  title: _lt(
                                    labels,
                                    'new_customer_exclusive_benefit1_title',
                                  ),
                                  desc: _lt(
                                    labels,
                                    'new_customer_exclusive_benefit1_desc',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _TrialBenefitCard(
                                  key: const ValueKey(
                                    'activity_trial_top_up_benefit_2',
                                  ),
                                  title: _lt(
                                    labels,
                                    'new_customer_exclusive_benefit2_title',
                                  ),
                                  desc: _lt(
                                    labels,
                                    'new_customer_exclusive_benefit2_desc',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActivitySettlementButton(
                                        text: _lt(labels, 'cancel'),
                                        backgroundColor: const Color(
                                          0xFFF5F5F5,
                                        ),
                                        textColor: const Color(0xFF666666),
                                        onTap: onCancel,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _ActivitySettlementButton(
                                        text: _lt(labels, 'certain'),
                                        backgroundColor: const Color(
                                          0xFFFF7700,
                                        ),
                                        textColor: Colors.white,
                                        onTap: onConfirm,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 92),
                                GestureDetector(
                                  onTap: onConfirm,
                                  child: Container(
                                    key: const ValueKey(
                                      'activity_trial_top_up_transfer_cta',
                                    ),
                                    height: 48,
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(24),
                                      ),
                                      image: DecorationImage(
                                        image: AssetImage(
                                          'assets/images/st_button_bg.png',
                                        ),
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _lt(labels, 'go_to_recharge'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            height: 1.1,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Image.asset(
                                          'assets/images/st_button_right_icon.png',
                                          width: 18,
                                          height: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Image.asset(
                    _isRecharge
                        ? 'assets/images/st_trial_received.png'
                        : 'assets/images/st_trial_used.png',
                    key: ValueKey(
                      _isRecharge
                          ? 'activity_trial_top_up_recharge_image'
                          : 'activity_trial_top_up_transfer_image',
                    ),
                    width: _isRecharge ? 110 : 140,
                    height: _isRecharge ? 110 : 140,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrialBenefitCard extends StatelessWidget {
  const _TrialBenefitCard({super.key, required this.title, required this.desc});

  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF7700),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

/// 交易解锁 - 全部完成弹窗（对齐 iOS STCompleteTaskAlertView）
class TradeUnlockCompletedPage extends StatelessWidget {
  final String? totalRewardAmount;

  const TradeUnlockCompletedPage({super.key, this.totalRewardAmount});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadActivityText(context),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? _activityFallbackText;
        final amount = totalRewardAmount ?? '0';
        return Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    key: const ValueKey('trade_unlock_completed_shell'),
                    width: 320,
                    margin: const EdgeInsets.only(top: 66),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFEFE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Image.asset(
                          'assets/images/st_complete_all_task_bg.png',
                          key: const ValueKey(
                            'trade_unlock_completed_bg_image',
                          ),
                          fit: BoxFit.fitWidth,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _lt(labels, 'completed_all_tasks_tip'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF00B57A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _fmtIos(
                                  _lt(labels, 'completed_all_tasks_tip2_iOS'),
                                  [amount],
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Container(
                                key: const ValueKey(
                                  'trade_unlock_completed_amount_panel',
                                ),
                                height: 100,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF5FF),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '\$$amount',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF00B57A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Text(
                                _lt(labels, 'start_trading_to_unlock'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () => context.pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00B57A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: Text(
                                    _lt(labels, 'start_trading_to_unlock'),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: TextButton(
                                  onPressed: () => context.pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF9A9DA2),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: Text(
                                    _lt(labels, 'reward_description'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/st_complete_all_task.png',
                    key: const ValueKey('trade_unlock_completed_top_image'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _TradeUnlockTaskKind { register, auth, deposit }

class _TradeUnlockTaskViewData {
  const _TradeUnlockTaskViewData({
    required this.kind,
    required this.amount,
    required this.image,
    required this.title,
    required this.message,
    required this.primary,
    required this.secondary,
  });

  final _TradeUnlockTaskKind kind;
  final String amount;
  final String image;
  final String title;
  final String message;
  final String primary;
  final String secondary;
}

_TradeUnlockTaskViewData _tradeUnlockTaskViewData(
  Map<String, dynamic>? taskInfo,
  int? isFromDeposit,
  Map<String, String> labels,
) {
  final tasks = (taskInfo?['tasks'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  Map<String, dynamic>? current;
  if (isFromDeposit == 1) {
    current = tasks.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e?['task_type'] == 'FIRST_DEPOSIT',
      orElse: () => null,
    );
  }
  current ??= tasks.cast<Map<String, dynamic>?>().firstWhere(
    (e) => e?['is_completed'] != true,
    orElse: () => tasks.isEmpty ? null : tasks.first,
  );
  final type = '${current?['task_type'] ?? 'REGISTER'}';
  final amount =
      '${current?['unlock_amount'] ?? taskInfo?['total_reward_amount'] ?? '0'}';
  if (type == 'KYC_ID_VERIFICATION') {
    return _TradeUnlockTaskViewData(
      kind: _TradeUnlockTaskKind.auth,
      amount: amount,
      image: 'assets/images/st_newbie_rewards_auth.png',
      title: _lt(labels, 'complete_identity_verification_tip'),
      message: _fmtIos(_lt(labels, 'complete_identity_verification_tip2_iOS'), [
        amount,
      ]),
      primary: _lt(labels, 'claim_now'),
      secondary: _lt(labels, 'to_be_completed_later'),
    );
  }
  if (type == 'FIRST_DEPOSIT') {
    return _TradeUnlockTaskViewData(
      kind: _TradeUnlockTaskKind.deposit,
      amount: amount,
      image: 'assets/images/st_newbie_rewards_deposit.png',
      title: _lt(
        labels,
        'continue_to_claim_rewards_complete_your_first_deposit_tip',
      ),
      message: _fmtIos(
        _lt(
          labels,
          'continue_to_claim_rewards_complete_your_first_deposit_tip2_iOS',
        ),
        [amount],
      ),
      primary: _lt(labels, 'deposit_now_to_claim'),
      secondary: _lt(labels, 'to_be_completed_later'),
    );
  }
  final totalAmount = tasks.fold<int>(
    0,
    (sum, e) => sum + (int.tryParse('${e['unlock_amount'] ?? 0}') ?? 0),
  );
  final registerAmount = totalAmount == 0 ? amount : '$totalAmount';
  return _TradeUnlockTaskViewData(
    kind: _TradeUnlockTaskKind.register,
    amount: registerAmount,
    image: 'assets/images/st_newbie_reward.png',
    title: _lt(labels, 'new_user_exclusive_rewards_await_claiming_tip'),
    message: _fmtIos(
      _lt(labels, 'new_user_exclusive_rewards_await_claiming_tip2_iOS'),
      [registerAmount],
    ),
    primary: _lt(labels, 'go_register'),
    secondary: _lt(labels, 'not_available_today'),
  );
}

/// 交易解锁 - 未完成弹窗（对齐 iOS STNewBieRewardsAlertView + STSelItemPopView）
class TradeUnlockUnCompletedPage extends StatelessWidget {
  final Map<String, dynamic>? taskInfo;
  final int? isFromDeposit;

  const TradeUnlockUnCompletedPage({
    super.key,
    this.taskInfo,
    this.isFromDeposit,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadActivityText(context),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? _activityFallbackText;
        final viewData = _tradeUnlockTaskViewData(
          taskInfo,
          isFromDeposit,
          labels,
        );

        return Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    key: const ValueKey('trade_unlock_uncompleted_shell'),
                    width: 320,
                    margin: const EdgeInsets.only(top: 82),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.fromLTRB(15, 98, 15, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          viewData.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          viewData.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (viewData.kind ==
                                  _TradeUnlockTaskKind.deposit) {
                                _openDepositAfterDismiss(context);
                              } else {
                                context.pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B57A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: Text(viewData.primary),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton(
                            onPressed: () => context.pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF999999),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: Text(viewData.secondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(viewData.image),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
