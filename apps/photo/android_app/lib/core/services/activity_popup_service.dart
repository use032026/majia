import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_state.dart';
import '../network/st_service.dart';

int activityPopupIosIntValue(dynamic raw, {int fallback = 0}) {
  if (raw is num) return raw.toInt();
  if (raw is bool) return raw ? 1 : 0;
  if (raw == null) return fallback;
  return int.tryParse('$raw') ?? double.tryParse('$raw')?.toInt() ?? fallback;
}

bool activityPopupIosBoolValue(dynamic raw, {bool fallback = false}) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw == null) return fallback;
  final normalized = '$raw'.trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  if (normalized == 'true' || normalized == 'yes') return true;
  if (normalized == 'false' || normalized == 'no') return false;
  final parsed = num.tryParse(normalized);
  if (parsed != null) return parsed != 0;
  return fallback;
}

/// 活动弹窗服务
/// 对齐 iOS STHomeViewController viewWillAppear 中的弹窗链
///
/// 弹窗链顺序（非 B 面时执行）:
///   1. 体验金检查（requestTrialBonusCheck）
///   2. 赠金检查（requestBonusCheck）
///   3. 交易解锁活动弹窗（requestTradeUnlockTaskProgress）
///
/// 每个弹窗都有独立的 UserDefaults 频次控制，对齐 iOS NSUserDefaults 键
class ActivityPopupService {
  final STService _service;
  final UserState Function() _readUserState;

  // NSUserDefaults 键（对齐 iOS 常量）
  static const String keyTrialLastTime = 'cms_trial_last_time';
  static const String keyBonusLastTime = 'cms_bonus_last_time';
  static const String keyNewbieRewardsPrefix = 'cms_last_newbie_rewards_';
  static const String keyTaskAllCompletePrefix = 'cms_last_task_all_complete_';

  ActivityPopupService({
    required STService service,
    required UserState Function() readUserState,
  }) : _service = service,
       _readUserState = readUserState;

  bool get _isBUser => _readUserState().isB;

  /// 执行完整活动弹窗链（viewWillAppear 中调用）
  /// 仅在非 B 面时执行
  ///
  /// [tradeUnlockGuestPopGuard] 对齐 iOS `STHomeViewController.hasShowPop`（VC 生命周期内只弹一次）
  Future<void> showActivityChain(
    void Function(String path, Map<String, dynamic> params) openRoute, {
    ValueNotifier<bool>? tradeUnlockGuestPopGuard,
  }) async {
    if (_isBUser) {
      debugPrint('📢 B面用户，跳过活动弹窗');
      return;
    }

    final userState = _readUserState();
    // 已登录 → 直接走赠金检查；未登录 → 先走体验金
    if (userState.isLogin) {
      await _checkBonus(
        openRoute,
        tradeUnlockGuestPopGuard: tradeUnlockGuestPopGuard,
      );
    } else {
      final tried = await _checkTrialBonus(openRoute);
      if (!tried) {
        // 体验金无活动或失败 → 走赠金
        await _checkBonus(
          openRoute,
          tradeUnlockGuestPopGuard: tradeUnlockGuestPopGuard,
        );
      }
    }
  }

  // ==================== 体验金弹窗 ====================

  /// 检查体验金
  /// 返回 true 代表已展示弹窗，false 代表跳过
  Future<bool> _checkTrialBonus(
    void Function(String path, Map<String, dynamic> params) openRoute,
  ) async {
    if (_isBUser) return false;
    try {
      final response = await _service.checkTrialActivity();
      if (_isBUser) return false;
      final hasActivity = activityPopupIosBoolValue(response['has_activity']);

      if (!hasActivity) return false;

      // 频次控制
      await _ensureFrequencyKeyLoaded(keyTrialLastTime);
      if (_isBUser) return false;
      if (!_canShowPopup(keyTrialLastTime)) return false;

      // 展示体验金弹窗（/action/trial）
      openRoute('/action/trial', response);
      _recordPopupShow(keyTrialLastTime);
      return true;
    } catch (e) {
      debugPrint('📢 Trial bonus check failed: $e');
      return false;
    }
  }

  // ==================== 赠金弹窗 ====================

  /// 检查赠金
  Future<bool> _checkBonus(
    void Function(String path, Map<String, dynamic> params) openRoute, {
    ValueNotifier<bool>? tradeUnlockGuestPopGuard,
  }) async {
    if (_isBUser) return false;
    try {
      final response = await _service.checkBonusActivity();
      if (_isBUser) return false;
      final hasActivity = activityPopupIosBoolValue(response['has_activity']);

      if (hasActivity) {
        // 频次控制
        await _ensureFrequencyKeyLoaded(keyBonusLastTime);
        if (_isBUser) return false;
        if (!_canShowPopup(keyBonusLastTime)) {
          if (_isBUser) return false;
          await _checkTradeUnlock(
            openRoute,
            tradeUnlockGuestPopGuard: tradeUnlockGuestPopGuard,
          );
          return false;
        }

        openRoute('/action/bonus', response);
        _recordPopupShow(keyBonusLastTime);
        return true;
      }

      // 无赠金 → 走交易解锁弹窗
      if (_isBUser) return false;
      await _checkTradeUnlock(
        openRoute,
        tradeUnlockGuestPopGuard: tradeUnlockGuestPopGuard,
      );
      return false;
    } catch (e) {
      debugPrint('📢 Bonus check failed: $e');
      if (_isBUser) return false;
      await _checkTradeUnlock(
        openRoute,
        tradeUnlockGuestPopGuard: tradeUnlockGuestPopGuard,
      );
      return false;
    }
  }

  // ==================== 交易解锁活动弹窗 ====================

  /// 交易解锁活动弹窗（链末端）
  /// 对齐 iOS requestTradeUnlockPop 逻辑
  Future<void> _checkTradeUnlock(
    void Function(String path, Map<String, dynamic> params) openRoute, {
    ValueNotifier<bool>? tradeUnlockGuestPopGuard,
  }) async {
    if (_isBUser) return;
    try {
      final response = await _service.getTradeUnlockTaskProgress();
      if (_isBUser) return;
      final activityStatus = activityPopupIosIntValue(
        response['activity_status'],
      );
      final tasks = response['tasks'] as List<dynamic>? ?? [];

      // activity_status == 1 且 tasks 不为空
      if (activityStatus != 1 || tasks.isEmpty) return;

      final userState = _readUserState();
      if (userState.isB) return;
      final userId = userState.userId;
      final isJoined = activityPopupIosBoolValue(response['is_joined']);
      final activityStart = activityPopupIosIntValue(
        response['activity_start'],
      );
      final activityEnd = activityPopupIosIntValue(response['activity_end']);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (!userState.isLogin) {
        // 未登录：当前时间在活动期内
        if (now <= activityStart || now >= activityEnd) return;

        if (tradeUnlockGuestPopGuard?.value == true) return;

        final key = '$keyNewbieRewardsPrefix${userId}_1';
        if (await _hasShownToday(key)) return;
        if (_isBUser) return;

        tradeUnlockGuestPopGuard?.value = true;
        openRoute('/action/tradeUnlockTaskUnCompleted', {
          'taskInfo': response,
          'isFromDeposit': 0,
        });
        _recordPopupShow(key);
      } else if (isJoined) {
        // 已登录且已报名
        if (now <= activityStart || now >= activityEnd) return;

        final allCompleted = tasks.every(
          (t) => activityPopupIosBoolValue(
            (t as Map<String, dynamic>)['is_completed'],
          ),
        );

        if (allCompleted) {
          final key = '$keyTaskAllCompletePrefix$userId';
          if (await _hasShownEver(key)) return;
          if (_isBUser) return;

          openRoute('/action/tradeUnlockTaskCompleted', {
            'total_reward_amount':
                response['total_reward_amount']?.toString() ?? '0',
          });
          _recordPopupShow(key); // 仅展示一次（无时间窗口限制）
        } else {
          // 有未完成任务
          final hasKycTask = tasks.any((t) {
            final task = t as Map<String, dynamic>;
            return task['task_type'] == 'KYC_ID_VERIFICATION' &&
                activityPopupIosBoolValue(task['is_completed']) == false;
          });

          final suffix = hasKycTask ? '2' : '3';
          final key = '$keyNewbieRewardsPrefix${userId}_$suffix';
          if (await _hasShownToday(key)) return;
          if (_isBUser) return;

          openRoute('/action/tradeUnlockTaskUnCompleted', {
            'taskInfo': response,
            'isFromDeposit': hasKycTask ? 0 : 1,
          });
          _recordPopupShow(key);
        }
      }
    } catch (e) {
      debugPrint('📢 Trade unlock pop check failed: $e');
    }
  }

  /// 入金页未发起入金即返回时的交易解锁提醒。
  ///
  /// 对齐 iOS `STWalletActionHandler.despositBlock -> requestTaskProgressData`：
  /// 仅已登录、已报名、活动有效、存在未完成任务时展示，并使用
  /// `cms_last_newbie_rewards_{uid}_3` 做当天频控。
  Future<void> showDepositReturnTradeUnlockPrompt(
    void Function(String path, Map<String, dynamic> params) openRoute,
  ) async {
    final userState = _readUserState();
    if (!userState.isLogin || userState.isB) return;

    final userId = userState.userId;
    final key = '$keyNewbieRewardsPrefix${userId}_3';
    if (await _hasShownToday(key)) return;

    try {
      final response = await _service.getTradeUnlockTaskProgress();
      final isJoined = activityPopupIosBoolValue(response['is_joined']);
      final activityStatus = activityPopupIosIntValue(
        response['activity_status'],
      );
      final activityStart = activityPopupIosIntValue(
        response['activity_start'],
      );
      final activityEnd = activityPopupIosIntValue(response['activity_end']);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (!isJoined || activityStatus != 1) return;
      if (now <= activityStart || now >= activityEnd) return;

      final tasks = response['tasks'] as List<dynamic>? ?? [];
      if (tasks.isEmpty) return;
      final allCompleted = tasks.every((task) {
        final map = task is Map ? task : const <String, dynamic>{};
        return activityPopupIosBoolValue(map['is_completed']);
      });
      if (allCompleted) return;

      _recordPopupShow(key);
      openRoute('/action/tradeUnlockTaskUnCompleted', {
        'taskInfo': response,
        'isFromDeposit': 1,
      });
    } catch (e) {
      debugPrint('📢 Deposit return trade unlock pop check failed: $e');
    }
  }

  // ==================== 频次控制（对齐 iOS NSUserDefaults 逻辑） ====================

  /// 检查是否可以展示弹窗
  /// 规则：同一天最多 3 次，两次间隔 ≥ 300 秒
  /// 跨天重置
  bool _canShowPopup(String key) {
    return _checkFrequency(key);
  }

  Future<bool> _hasShownToday(String key) async {
    await _ensureFrequencyKeyLoaded(key);
    final cache = _frequencyCache[key];
    if (cache == null) return false;
    final savedDate = cache['date'] as String? ?? '';
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    return savedDate == todayStr;
  }

  Future<bool> _hasShownEver(String key) async {
    await _ensureFrequencyKeyLoaded(key);
    return _frequencyCache.containsKey(key);
  }

  bool _checkFrequency(String key) {
    // 由于 SharedPreferences 是异步的，这里使用内存缓存
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    final cache = _frequencyCache[key];
    if (cache == null) return true;

    final savedDate = cache['date'] as String? ?? '';
    final count = cache['count'] as int? ?? 0;
    final lastTime = cache['lastTime'] as int? ?? 0;

    if (savedDate != todayStr) {
      // 跨天重置
      return true;
    }

    // 同一天：最多 3 次，间隔 ≥ 300 秒
    if (count >= 3) return false;

    final elapsed = now.millisecondsSinceEpoch ~/ 1000 - lastTime;
    if (elapsed < 300) return false;

    return true;
  }

  void _recordPopupShow(String key) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    final cache = _frequencyCache[key] ?? {};
    final count = (cache['count'] as int? ?? 0) + 1;

    _frequencyCache[key] = {
      'date': todayStr,
      'count': count,
      'lastTime': now.millisecondsSinceEpoch ~/ 1000,
    };

    // 异步写 SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final value = '${now.millisecondsSinceEpoch ~/ 1000}_$count';
      prefs.setString(key, value);
    });
  }

  /// 内存频次缓存（避免每次读 SharedPreferences）
  final Map<String, Map<String, dynamic>> _frequencyCache = {};

  /// 加载所有频次数据到内存
  Future<void> loadFrequencyCache() async {
    final prefs = await SharedPreferences.getInstance();
    _loadKey(prefs, keyTrialLastTime);
    _loadKey(prefs, keyBonusLastTime);
  }

  Future<void> _ensureFrequencyKeyLoaded(String key) async {
    if (_frequencyCache.containsKey(key)) return;
    final prefs = await SharedPreferences.getInstance();
    _loadKey(prefs, key);
  }

  void _loadKey(SharedPreferences prefs, String key) {
    final value = prefs.getString(key);
    if (value == null) return;

    final parts = value.split('_');
    if (parts.length < 2) return;

    final timestamp = int.tryParse(parts[0]) ?? 0;
    final count = int.tryParse(parts[1]) ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final todayStr = '${date.year}-${date.month}-${date.day}';

    _frequencyCache[key] = {
      'date': todayStr,
      'count': count,
      'lastTime': timestamp,
    };
  }
}

/// Provider
final activityPopupServiceProvider = Provider<ActivityPopupService>((ref) {
  final service = ref.read(stServiceProvider);
  return ActivityPopupService(
    service: service,
    readUserState: () => ref.read(userStateProvider),
  );
});
