import 'package:flutter/foundation.dart';

/// 轻量级事件总线
/// 对齐 iOS NSNotificationCenter 的核心使用场景
///
/// 代替全局通知，提供类型安全的应用内事件分发
/// 使用方式:
///   EventBus().emit('wallet_updated');
///   EventBus().on('wallet_updated', callback);
///   EventBus().off('wallet_updated', callback);
class EventBus {
  EventBus._internal();

  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;

  final Map<String, List<VoidCallback>> _listeners = {};
  final Map<String, List<void Function(Object? data)>> _payloadListeners = {};

  /// 注册事件监听
  void on(String event, VoidCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  /// 移除事件监听
  void off(String event, VoidCallback callback) {
    _listeners[event]?.remove(callback);
  }

  /// 触发事件
  void emit(String event) {
    final callbacks = _listeners[event];
    if (callbacks != null) {
      for (final cb in callbacks) {
        try {
          cb();
        } catch (e) {
          debugPrint('⚠️ EventBus error [$event]: $e');
        }
      }
    }
  }

  /// 注册带 payload 的事件监听。
  ///
  /// 用于对齐 iOS `NSNotificationCenter` 携带已更新模型的场景。
  void onData(String event, void Function(Object? data) callback) {
    _payloadListeners.putIfAbsent(event, () => []).add(callback);
  }

  /// 移除带 payload 的事件监听。
  void offData(String event, void Function(Object? data) callback) {
    _payloadListeners[event]?.remove(callback);
  }

  /// 触发带 payload 的事件。
  void emitData(String event, Object? data) {
    final callbacks = _payloadListeners[event];
    if (callbacks != null) {
      for (final cb in List<void Function(Object? data)>.from(callbacks)) {
        try {
          cb(data);
        } catch (e) {
          debugPrint('⚠️ EventBus payload error [$event]: $e');
        }
      }
    }
    emit(event);
  }

  /// 移除所有监听（对齐 iOS: dealloc 时 removeObserver）
  void clear() {
    _listeners.clear();
    _payloadListeners.clear();
  }

  // ==================== 预定义事件常量 ====================

  /// 登录成功 → 刷新钱包/等级/认证数据
  static const String loginSuccess = 'login_success';

  /// 退出登录 → 清理相关状态
  static const String logout = 'logout';

  /// 钱包数据更新
  static const String walletUpdated = 'wallet_updated';

  /// 交易持仓/挂单列表更新（沿用 iOS `STTradePositionListRefreshNotification` 命名）
  static const String tradePositionListRefresh = 'trade_position_list_refresh';

  /// 交易操作视图刷新（对齐 iOS `STTradeActionViewRefreshNotification`）
  static const String tradeActionViewRefresh = 'trade_action_view_refresh';

  /// 交易账户切换成功（对齐 iOS `STChangeAccountSuccessNotification`）
  static const String accountChanged = 'account_changed';

  /// 涨跌颜色切换成功（对齐 iOS `STRiseColorDidChangedNotification`）
  static const String riseColorChanged = 'rise_color_changed';

  /// 语言/时区等配置变更
  static const String configChanged = 'config_changed';
}
