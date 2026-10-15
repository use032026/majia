import 'package:flutter/material.dart';
import '../config/brand_config.dart';

/// 应用主题系统
/// 支持亮/暗模式 + 品牌配置注入
class AppTheme {
  static ThemeData light(BrandConfig brand) {
    final colors = brand.resolveColorPalette(isDark: false);
    final primaryColor = _hexToColor(brand.resolveThemeMain(isDark: false));
    final secondaryColor = _hexToColor(brand.resolveThemeAssist(isDark: false));
    final surfaceColor = _hexToColor(colors['totalBg_1']!);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      textTheme: _buildTextTheme(colors),
      extensions: [
        AppPalette(
          brand: brand,
          isDark: false,
        ),
      ],
    );
  }

  static ThemeData dark(BrandConfig brand) {
    final colors = brand.resolveColorPalette(isDark: true);
    final primaryColor = _hexToColor(brand.resolveThemeMain(isDark: true));
    final secondaryColor = _hexToColor(brand.resolveThemeAssist(isDark: true));
    final surfaceColor = _hexToColor(colors['totalBg_1']!);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      textTheme: _buildTextTheme(colors),
      extensions: [
        AppPalette(
          brand: brand,
          isDark: true,
        ),
      ],
    );
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  static TextTheme _buildTextTheme(Map<String, String> colors) {
    return TextTheme(
      bodyLarge: TextStyle(color: _hexToColor(colors['text_1']!)),
      bodyMedium: TextStyle(color: _hexToColor(colors['text_2']!)),
      bodySmall: TextStyle(color: _hexToColor(colors['text_3']!)),
    );
  }
}

/// 品牌调色板扩展
class AppPalette extends ThemeExtension<AppPalette> {
  final BrandConfig brand;
  final bool isDark;

  const AppPalette({
    required this.brand,
    required this.isDark,
  });

  Color get riseColor => AppTheme._hexToColor(brand.riseColor);
  Color get fallColor => AppTheme._hexToColor(brand.fallColor);
  Color get equalColor => AppTheme._hexToColor(brand.equalColor);

  Map<String, Color> get textColors => isDark
      ? _resolveColorsFromMode(true)
      : _resolveColorsFromMode(false);

  Map<String, Color> _resolveColorsFromMode(bool isDarkMode) {
    final palette = brand.resolveColorPalette(isDark: isDarkMode);
    return palette.map((k, v) => MapEntry(k, AppTheme._hexToColor(v)));
  }

  @override
  AppPalette copyWith({BrandConfig? brand, bool? isDark}) {
    return AppPalette(
      brand: brand ?? this.brand,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brand: brand,
      isDark: isDark,
    );
  }
}
