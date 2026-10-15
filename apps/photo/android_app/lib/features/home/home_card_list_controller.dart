import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/config/config_data_manager.dart';
import '../../core/models/tab_bar_item.dart';
import '../../core/models/user_state.dart';
import '../../core/network/st_service.dart';
import '../../core/services/activity_popup_service.dart';
import '../../shared/widgets/card_factory.dart';
import 'card_list_controller.dart';

/// 首页卡片控制器。
///
/// 对齐 iOS `STHomeViewController`：继承通用配置化列表页能力，
/// 仅承载首页额外的交易解锁显隐和活动弹窗链。
class HomeCardListController extends CardListController {
  /// 对齐 iOS `STHomeViewController.hasShowPop`：单个首页生命周期内未登录交易解锁弹窗只弹一次。
  final ValueNotifier<bool> _tradeUnlockGuestPopGuard = ValueNotifier(false);

  HomeCardListController({
    required super.ref,
    super.cards,
    super.pageListId,
    super.sourceTabBarItem,
  });

  @override
  Future<void> afterViewDidLoad(
    STService service,
    ConfigDataManager configMgr,
  ) async {
    if (ref.read(userStateProvider).isB) return;
    await refreshTradeUnlockCard(service);
  }

  @override
  Future<void> afterRefreshPage(
    STService service,
    ConfigDataManager configMgr,
  ) async {
    if (ref.read(userStateProvider).isB) return;
    await refreshTradeUnlockCard(service);
  }

  @override
  void afterWillAppear({required bool wasFirstLoad}) {
    if (ref.read(userStateProvider).isB) return;
    unawaited(_checkActivityPopups());
    unawaited(refreshTradeUnlockCard(ref.read(stServiceProvider)));
  }

  /// 对齐 iOS `requestTradeUnlockTaskProgress` + `updateDatasouce`。
  Future<void> refreshTradeUnlockCard(STService service) async {
    for (final card in allCards) {
      if (!card.cardStyle.startsWith('unlock_')) continue;
      try {
        final progress = await CardFactory.loadUnlockCardData(
          card: card,
          service: service,
        );
        if (progress != null) {
          progress['activity_url'] = ref
              .read(userStateProvider)
              .h5AddressModel
              ?.tradeUnlockActivityUrl;
        }
        _applyUnlockCardVisibility(card, progress);
      } catch (e) {
        debugPrint('⚠️ Home unlock visibility: $e');
      }
      notifyDataChanged();
      break;
    }
  }

  void _applyUnlockCardVisibility(
    ConfigCardItemData card,
    Map<String, dynamic>? progress,
  ) {
    if (progress == null) {
      card.isShow = false;
      return;
    }

    final isLogin = ref.read(userStateProvider).isLogin;
    final status = activityPopupIosIntValue(progress['activity_status']);
    final isJoined = activityPopupIosBoolValue(progress['is_joined']);
    final activityStart = activityPopupIosIntValue(progress['activity_start']);
    final activityEnd = activityPopupIosIntValue(progress['activity_end']);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    var show = true;
    if (status == 0) {
      show = false;
    } else if (isLogin && !isJoined) {
      show = false;
    } else if (!isLogin && (now < activityStart || now > activityEnd)) {
      show = false;
    }

    card.isShow = show;
    if (show) {
      syncNativePayload(card, Map<String, dynamic>.from(progress));
    }
  }

  /// 对齐 iOS `requestAictivityPop` 链路。
  Future<void> _checkActivityPopups() async {
    final opener = routeOpener;
    if (opener == null || !isVisible) return;

    try {
      final popupService = ref.read(activityPopupServiceProvider);
      await popupService.loadFrequencyCache();
      await popupService.showActivityChain(
        opener,
        tradeUnlockGuestPopGuard: _tradeUnlockGuestPopGuard,
      );
    } catch (e) {
      debugPrint('📢 Home activity popup chain error: $e');
    }
  }

  @override
  void dispose() {
    _tradeUnlockGuestPopGuard.dispose();
    super.dispose();
  }
}
