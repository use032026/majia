import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/st_toast.dart';

/// 卡片工具单例
/// 对齐 iOS STConfigCardTool，提供卡片渲染所需的各类回调注入：
///   - 暗黑模式卡片颜色
///   - 涨跌颜色
///   - 边框颜色
///   - 字符串格式化
///   - 数字字体
///   - 路由跳转
///   - Toast/日志
///
/// 所有回调均有默认实现，业务层可按需替换。
class CardTool {
  // ==================== 暗黑模式卡片颜色 ====================

  /// 暗黑模式下卡片背景色回调
  Color Function(BuildContext)? cardDarkModeHandlerBlock;

  Color cardDarkColor(BuildContext context) {
    if (cardDarkModeHandlerBlock != null) {
      return cardDarkModeHandlerBlock!(context);
    }
    return const Color(0xFF1C1C1E);
  }

  // ==================== 行情 K 线切换 ====================

  /// K 线开关回调（返回是否支持 K 线切换）
  bool Function()? configCardMarketListKlineSwitchBlock;

  bool get canSwitchKline {
    return configCardMarketListKlineSwitchBlock?.call() ?? false;
  }

  // ==================== 涨跌颜色 ====================

  /// 涨跌颜色回调
  Color Function(bool isRise)? cardRiseAndFallColorHandlerBlock;

  Color riseFallColor(bool isRise) {
    if (cardRiseAndFallColorHandlerBlock != null) {
      return cardRiseAndFallColorHandlerBlock!(isRise);
    }
    // 默认：红涨绿跌
    return isRise ? const Color(0xFFE74C3C) : const Color(0xFF27AE60);
  }

  // ==================== 边框颜色 ====================

  /// 卡片边框颜色回调
  Color Function(Brightness)? cardBorderColorHandlerBlock;

  Color borderColor(Brightness brightness) {
    if (cardBorderColorHandlerBlock != null) {
      return cardBorderColorHandlerBlock!(brightness);
    }
    return brightness == Brightness.dark
        ? const Color(0xFF333333)
        : const Color(0xFFE8E8E8);
  }

  // ==================== 字符串格式化 ====================

  /// 卡片字符串格式化回调（如金额格式化）
  String Function(String key, String value)? cardStringHandlerBlock;

  String formatString(String key, String value) {
    if (cardStringHandlerBlock != null) {
      return cardStringHandlerBlock!(key, value);
    }
    return value;
  }

  // ==================== 数字字体 ====================

  /// 数字字体回调（用于金额等数字展示）
  TextStyle Function(TextStyle base)? cardNumFontHandlerBlock;

  TextStyle numFont(TextStyle base) {
    if (cardNumFontHandlerBlock != null) {
      return cardNumFontHandlerBlock!(base);
    }
    return base;
  }

  // ==================== 路由跳转 ====================

  /// 卡片点击跳转路由回调
  void Function(String? router, Map<String, dynamic>? params)?
  cardRouterHandlerBlock;

  void routeTo(String? router, [Map<String, dynamic>? params]) {
    if (cardRouterHandlerBlock != null) {
      cardRouterHandlerBlock!(router, params);
    }
  }

  // ==================== Toast ====================

  /// Toast 回调
  void Function(String message)? cardToastHandlerBlock;

  void showToast(String message) {
    if (cardToastHandlerBlock != null) {
      cardToastHandlerBlock!(message);
    } else {
      STToast.showGlobal(message);
    }
  }

  // ==================== 日志 ====================

  /// 日志回调
  void Function(String tag, String message)? cardLogHandlerBlock;

  void log(String tag, String message) {
    if (cardLogHandlerBlock != null) {
      cardLogHandlerBlock!(tag, message);
    } else {
      debugPrint('[$tag] $message');
    }
  }

  // ==================== 信息提示 ====================

  /// 信息提示回调（如登录提示、权限提示）
  void Function(String message, {VoidCallback? action})? cardInfoHandlerBlock;

  void showInfo(String message, {VoidCallback? action}) {
    if (cardInfoHandlerBlock != null) {
      cardInfoHandlerBlock!(message, action: action);
    }
  }
}

/// Provider
final cardToolProvider = Provider<CardTool>((ref) {
  return CardTool();
});
