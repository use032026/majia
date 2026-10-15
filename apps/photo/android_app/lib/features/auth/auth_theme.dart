import 'package:flutter/material.dart';

import '../../core/theme/context_adaptive_colors.dart';

/// 登录 / 注册视觉常量（对齐 iOS `STLoginWithAccountViewController`、`STLoginTextField`、`STLoginButton`）
abstract final class AuthUi {
  /// 新注册页水平边距（对齐 `STNewRegisterViewController` 21pt）
  static const double padH = 21;
  static const double fieldHeight = 50;

  /// 新注册输入框高度（对齐 `configNewRegisterUI` 40pt）
  static const double registerFieldHeight = 40;
  static const double fieldRadius = 9;
  static const double registerFieldRadius = 6;
  static const double titleSize = 24;
  static const double primaryBtnW = 191;
  static const double primaryBtnH = 48;
  static const double primaryBtnR = 24;
  static const Color registerOutlineBlue = Color(0xFF00B57A);

  /// iOS 登录注册正文链接色（与注册描边按钮一致）
  static const Color linkBlue = Color(0xFF00B57A);

  /// iOS 分组列表 / 注册输入框浅灰底
  static const double registerTitleTop = 39;
  static Color pageBg(BuildContext context) => context.adaptivePageGrey;
  static Color cardBg(BuildContext context) =>
      context.adaptivePlaceholderSurface;
  static Color commonPopBg(BuildContext context) =>
      context.adaptiveSurfacePrimary;
  static Color divider(BuildContext context) => context.adaptiveDivider;
  static Color label(BuildContext context) => context.adaptiveTextPrimary;
  static Color labelBlack(BuildContext context) => label(context);
  static Color labelSecondary(BuildContext context) =>
      context.adaptiveTextTertiary;
  static Color hint(BuildContext context) => context.adaptiveTextHint;
  static Color resultBody(BuildContext context) => context.adaptiveTextTertiary;

  /// 身份认证页标题距顶（对齐 `STIdInfoViewController` 29pt）
  static const double idInfoTitleTop = 29;
  static const double idInfoFirstFieldGap = 40;
  static const double registerSubtitleGap = 8;
  static const double registerTabGap = 40;
  static const double registerFieldGap = 16;
  static const double registerCountryGap = 25;
  static const double registerLabelFieldGap = 4;
  static const double registerNextBtnHPad = 18;
  static const double registerNoticeBottom = 40;

  static String assetImage(String name) => 'assets/images/$name.png';

  static Widget authAsset(
    String name, {
    double? width,
    double? height,
    IconData? fallbackIcon,
    Color? fallbackColor,
    Color? tintColor,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      assetImage(name),
      width: width,
      height: height,
      fit: fit,
      color: tintColor,
      colorBlendMode: tintColor == null ? null : BlendMode.srcIn,
      errorBuilder: (_, __, ___) => Icon(
        fallbackIcon ?? Icons.image_outlined,
        size: width ?? height ?? 24,
        color: fallbackColor ?? tintColor ?? const Color(0xFF343434),
      ),
    );
  }

  static Color _border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white24
      : const Color(0xFFE5E5E5);

  /// 登录页输入框：白底 + 圆角 9 + 描边（对齐 STLoginTextField 默认样式）
  static InputDecoration loginField({
    required BuildContext context,
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final b = _border(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      hintStyle: TextStyle(color: isDark ? hint(context) : hint(context)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      constraints: const BoxConstraints(minHeight: fieldHeight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: b),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: b),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: primary, width: 1.2),
      ),
    );
  }

  /// 注册页输入框：圆角 6、左内边距 13（对齐 STLoginTextField `configNewRegisterUI`）
  static InputDecoration registerField({
    required BuildContext context,
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsets? contentPadding,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 15, color: hint(context)),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cardBg(context),
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      constraints: const BoxConstraints.tightFor(height: registerFieldHeight),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(registerFieldRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(registerFieldRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(registerFieldRadius),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(registerFieldRadius),
        borderSide: const BorderSide(color: Color(0xFFF95959)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(registerFieldRadius),
        borderSide: const BorderSide(color: Color(0xFFF95959)),
      ),
    );
  }

  static TextStyle registerLabelStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    color: label(context),
    fontWeight: FontWeight.w400,
  );

  static TextStyle registerTitleStyle(BuildContext context) => TextStyle(
    fontSize: titleSize,
    fontWeight: FontWeight.w700,
    color: label(context),
  );

  static TextStyle registerSubtitleStyle(BuildContext context) => TextStyle(
    fontSize: 14,
    color: labelSecondary(context),
    fontWeight: FontWeight.w400,
  );
}
