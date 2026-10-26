import 'package:flutter/material.dart';

/// Paleta central de la app.
class AppColors {
  static const cream = Color(0xFFF4EFE3);
  static const gold = Color(0xFFE8C14A);
  static const ink = Color(0xFF0E0E0D);
  static const panel = Color(0xFF161816);
}

/// Fuente propia para títulos (Abril Fatface, licencia OFL, incluida en la app).
const titleFont = 'Abril';

TextStyle titleStyle({double size = 20, Color color = AppColors.cream}) =>
    TextStyle(fontFamily: titleFont, fontSize: size, color: color, letterSpacing: 0.3);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.gold,
    onPrimary: AppColors.ink,
    secondary: AppColors.cream,
    onSecondary: AppColors.ink,
    surface: AppColors.ink,
    onSurface: AppColors.cream,
    primaryContainer: const Color(0xFF3A3018),
    onPrimaryContainer: AppColors.cream,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.cream,
      titleTextStyle: titleStyle(size: 22),
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontFamily: titleFont),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontFamily: titleFont),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontFamily: titleFont),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.panel,
      titleTextStyle: titleStyle(size: 20),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.panel),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.panel),
  );
}
