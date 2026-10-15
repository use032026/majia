import 'package:shared_preferences/shared_preferences.dart';

/// 对齐 iOS `STRouterManagerFailedRouter`：从我的页发起登录前写入「登录后要去的」完整 location，
/// 登录成功后在 [consume] 并交给 `GoRouter.go`。
abstract final class MinePendingRoute {
  static const String _prefsKey = 'mine_pending_go_location';

  static Future<void> arm(String location) async {
    final loc = location.trim();
    if (loc.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, loc);
  }

  /// 主动登录（无后续页）时清空，避免误跳转到上一次挂起路由。
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// 读取并清除挂起路由（单次消费）。
  static Future<String?> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKey);
    await prefs.remove(_prefsKey);
    if (v == null || v.isEmpty) return null;
    return v;
  }
}
