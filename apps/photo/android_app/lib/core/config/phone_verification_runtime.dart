import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 对齐 iOS `FirebaseAuthManager`：`requestPhoneVeryMethod` 解析后的运行时配置。
class PhoneVerificationRuntime {
  final bool canUseSmsVerCode;
  final List<String> supportAreas;

  const PhoneVerificationRuntime({
    this.canUseSmsVerCode = false,
    this.supportAreas = const [],
  });

  /// 是否与 iOS `isCurrentCountrySupport` 类似：判断当前区号是否在谷歌验证码通道支持列表中。
  bool isDialCodeSupported(String dialCode) {
    if (!canUseSmsVerCode || supportAreas.isEmpty || dialCode.trim().isEmpty) {
      return false;
    }
    final n = dialCode.trim();
    final normalized = n.startsWith('+') ? n : '+$n';
    final bare = n.startsWith('+') ? n.substring(1) : n;
    for (final a in supportAreas) {
      final t = a.trim();
      if (t.isEmpty) continue;
      final ta = t.startsWith('+') ? t : '+$t';
      final tb = t.startsWith('+') ? t.substring(1) : t;
      if (ta == normalized || tb == bare || t == n) return true;
    }
    return false;
  }
}

int _parseInt(dynamic v) {
  if (v == null) return -1;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? -1;
}

/// 解析 `GET …/phone_verification_method` 响应（对齐 `FirebaseAuthManager.requestPhoneVeryMethodWithCompletion`）。
PhoneVerificationRuntime parsePhoneVerificationMethod(Map<String, dynamic> raw) {
  final code = raw['code'];
  if (code is num && code != 0) {
    return const PhoneVerificationRuntime(canUseSmsVerCode: false, supportAreas: []);
  }

  final list = raw['data'];
  if (list == null) {
    return const PhoneVerificationRuntime(canUseSmsVerCode: false, supportAreas: []);
  }
  if (list is! List<dynamic>) {
    return const PhoneVerificationRuntime(canUseSmsVerCode: false, supportAreas: []);
  }

  final areas = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  var googleIdx = -1;
  final googleAreaCodes = <String>[];

  for (var i = 0; i < areas.length; i++) {
    final dic = areas[i];
    final t = _parseInt(dic['istype'] ?? dic['is_type']);
    if (t == 7) {
      final areaStr = dic['area_code']?.toString();
      if (areaStr != null && areaStr.isNotEmpty) {
        googleAreaCodes.addAll(
          areaStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }
      googleIdx = _parseInt(dic['sorts']);
      break;
    }
  }

  if (googleAreaCodes.isEmpty) {
    return const PhoneVerificationRuntime(canUseSmsVerCode: true, supportAreas: []);
  }

  final higherPriority = <String>[];
  for (final dic in areas) {
    final sort = _parseInt(dic['sorts']);
    if (googleIdx >= 0 && sort >= 0 && sort < googleIdx) {
      final areaStr = dic['area_code']?.toString();
      if (areaStr != null && areaStr.isNotEmpty) {
        higherPriority.addAll(
          areaStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }
    }
  }

  final filtered =
      googleAreaCodes.where((c) => !higherPriority.contains(c)).toList(growable: false);

  return PhoneVerificationRuntime(canUseSmsVerCode: true, supportAreas: filtered);
}

class PhoneVerificationRuntimeNotifier extends StateNotifier<PhoneVerificationRuntime> {
  PhoneVerificationRuntimeNotifier() : super(const PhoneVerificationRuntime());

  void applyResponse(Map<String, dynamic> raw) {
    state = parsePhoneVerificationMethod(raw);
  }
}

final phoneVerificationRuntimeProvider =
    StateNotifierProvider<PhoneVerificationRuntimeNotifier, PhoneVerificationRuntime>((ref) {
  return PhoneVerificationRuntimeNotifier();
});
