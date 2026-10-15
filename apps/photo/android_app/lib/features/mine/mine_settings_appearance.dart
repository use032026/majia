import 'package:flutter/material.dart';

import '../../core/theme/context_adaptive_colors.dart';

export '../../core/theme/context_adaptive_colors.dart';

/// 设置栈列表页：语义别名，与全站 [AppAdaptiveColors] 一致（浅色不变，深色对齐 iOS + BrandConfig）
extension MineSettingsAppearance on BuildContext {
  bool get mineSettingsIsDark => adaptiveIsDark;

  Color get mineSettingsPageBg => adaptivePageGrey;
  Color get mineSettingsNavBarBg => adaptiveSurfacePrimary;
  Color get mineSettingsGroupBg => adaptiveCard;
  Color get mineSettingsFullPageBg => adaptiveSurfacePrimary;

  Color get mineSettingsTextPrimary => adaptiveTextPrimary;
  Color get mineSettingsTextSecondary => adaptiveTextSecondary;
  Color get mineSettingsTextTertiary => adaptiveTextTertiary;
  Color get mineSettingsSectionTitle => adaptiveTextSecondary;

  Color get mineSettingsDivider => adaptiveDivider;
  Color get mineSettingsIconPillBg => adaptiveIconPillBg;
  Color get mineSettingsSwitchOffTrack => adaptiveSwitchOffTrack;
}
