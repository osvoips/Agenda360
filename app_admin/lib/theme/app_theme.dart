import 'package:flutter/material.dart';

/// Paleta inspirada no Flamengo (preto, vermelho, branco), a mesma usada em
/// docs/prototypes/screens.html e em app_cliente/lib/theme/app_theme.dart —
/// mantém consistência visual entre os dois apps.
class AppColors {
  AppColors._();

  static const Color rubro = Color(0xFFE30613);
  static const Color rubroDark = Color(0xFFFF4438);

  static const Color inkLight = Color(0xFF131217);
  static const Color inkDark = Color(0xFFF2EFEC);

  static const Color paperLight = Color(0xFFF4F1EC);
  static const Color paperDark = Color(0xFF0E0D10);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF19171B);

  static const Color lineLight = Color(0xFFE4DFD8);
  static const Color lineDark = Color(0xFF2B282D);

  static const Color success = Color(0xFF1E8E5A);
  static const Color pending = Color(0xFFB8791A);
  static const Color dangerLight = Color(0xFF9C4A48);
  static const Color dangerDark = Color(0xFFB06E6C);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.rubro,
      brightness: Brightness.light,
      primary: AppColors.rubro,
      onPrimary: Colors.white,
      surface: AppColors.surfaceLight,
      error: AppColors.dangerLight,
    );
    return _themeFrom(colorScheme, AppColors.paperLight, AppColors.inkLight, AppColors.lineLight);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.rubroDark,
      brightness: Brightness.dark,
      primary: AppColors.rubroDark,
      onPrimary: Colors.white,
      surface: AppColors.surfaceDark,
      error: AppColors.dangerDark,
    );
    return _themeFrom(colorScheme, AppColors.paperDark, AppColors.inkDark, AppColors.lineDark);
  }

  static ThemeData _themeFrom(
    ColorScheme colorScheme,
    Color scaffoldBackground,
    Color ink,
    Color line,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: Typography.material2021().black.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink.withOpacity(0.7)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      dividerTheme: DividerThemeData(color: line, space: 1),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),
    );
  }
}
