import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seedColor = Colors.purple;

  // Typography Material3
  static final TextTheme _textTheme = TextTheme(
    displayLarge: const TextStyle(fontSize: 57, fontWeight: FontWeight.bold),
    displayMedium: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold),
    displaySmall: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
    headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
    titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge: const TextStyle(fontSize: 16),
    bodyMedium: const TextStyle(fontSize: 14),
    bodySmall: const TextStyle(fontSize: 12),
    labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
  );

  // Light theme
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: _seedColor.withValues(alpha: 0.2),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: Colors.black.withValues(alpha: 0.72)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: _seedColor.withValues(alpha: 0.2),
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(size: 28),
      unselectedIconTheme: const IconThemeData(size: 24),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 3,
      shape: CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  // Dark theme
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: _seedColor.withValues(alpha: 0.3),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: Colors.white70.withValues(alpha: 0.90)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: Colors.white70, size: 28),
      unselectedIconTheme: const IconThemeData(color: Colors.white70, size: 24),
      indicatorColor: _seedColor.withValues(alpha: 0.3),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 3,
      shape: CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
