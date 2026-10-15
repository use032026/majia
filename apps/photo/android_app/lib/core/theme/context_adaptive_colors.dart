import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 全站 UI 暗色适配色板（浅色与现有 Figma/iOS 一致；深色对齐 `BrandConfig.darkColors`）
extension AppAdaptiveColors on BuildContext {
  AppPalette? get _palette => Theme.of(this).extension<AppPalette>();

  Map<String, Color>? get _c => _palette?.textColors;

  bool get adaptiveIsDark => Theme.of(this).brightness == Brightness.dark;

  /// 列表灰底页（#F7F7F7 / totalBg_2）
  Color get adaptivePageGrey =>
      _c?['totalBg_2'] ??
      (adaptiveIsDark ? const Color(0xFF18191A) : const Color(0xFFF7F7F7));

  /// 顶栏 / 全屏主表面（#FFFFFF / totalBg_1）
  Color get adaptiveSurfacePrimary =>
      _c?['totalBg_1'] ??
      (adaptiveIsDark ? const Color(0xFF18191A) : const Color(0xFFFFFFFF));

  /// 卡片、分组表面（childBg_2）
  Color get adaptiveCard =>
      _c?['childBg_2'] ??
      (adaptiveIsDark ? const Color(0xFF212229) : const Color(0xFFFFFFFF));

  /// 次级块、浅灰条（childBg_1）
  Color get adaptiveMutedBlock =>
      _c?['childBg_1'] ??
      (adaptiveIsDark ? const Color(0xFF212229) : const Color(0xFFF7F7F7));

  /// 禁用/置景占位底（childBg_ph）；资金页「审核中」等浅底卡片也映射到此
  Color get adaptivePlaceholderSurface =>
      _c?['childBg_ph'] ??
      (adaptiveIsDark ? const Color(0xFF2F3340) : const Color(0xFFECECEC));

  /// 资金卡片「稍暗」底（浅 #F2F2F2；暗色贴近 childBg_ph）
  Color get adaptiveFinanceCardMuted =>
      adaptiveIsDark ? adaptivePlaceholderSurface : const Color(0xFFF2F2F2);

  Color get adaptiveTextPrimary =>
      _c?['text_1'] ??
      (adaptiveIsDark ? const Color(0xFFEDF1F8) : const Color(0xFF000000));

  Color get adaptiveTextTertiary =>
      _c?['text_2'] ??
      (adaptiveIsDark ? const Color(0xFFABAFB7) : const Color(0xFF60656D));

  Color get adaptiveTextSecondary =>
      _c?['text_3'] ??
      (adaptiveIsDark ? const Color(0xFF6E727D) : const Color(0xFF9A9DA2));

  Color get adaptiveTextHint =>
      _c?['text_4'] ??
      (adaptiveIsDark ? const Color(0xFF424553) : const Color(0xFFD9D9D9));

  Color get adaptiveDivider =>
      adaptiveIsDark ? const Color(0xFF2F3340) : const Color(0xFFECECEC);

  Color get adaptiveHairline =>
      adaptiveIsDark ? const Color(0xFF2F3340) : const Color(0xFFEAEAEA);

  Color get adaptiveIconPillBg =>
      adaptiveIsDark ? const Color(0xFF2F3340) : const Color(0xFFF5F5F5);

  Color get adaptiveSwitchOffTrack =>
      adaptiveIsDark ? const Color(0xFF3A3D46) : const Color(0xFFE9E9EA);

  /// 与 [CardTool.iosPageBackgroundGrey] 浅色一致；暗色为灰页底
  Color get adaptiveMarketListPageBg => adaptivePageGrey;
}
