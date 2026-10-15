import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 设备 ID 管理器
/// 对齐 iOS AppDeviceIdTool.getAppDeviceId()
/// iOS 使用 Keychain + NSUserDefaults 双层持久化
/// Flutter 使用 SharedPreferences 持久化
class DeviceIdManager {
  static String? _deviceId;
  static const String _key = 'device_uuid';

  /// 获取持久化的设备 UUID（首次生成后不变）
  /// 对齐 iOS: Keychain 存储 → NSUserDefaults 缓存 → 内存缓存
  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_key);

    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = const Uuid().v4().toUpperCase();
      await prefs.setString(_key, _deviceId!);
    }

    return _deviceId!;
  }
}
