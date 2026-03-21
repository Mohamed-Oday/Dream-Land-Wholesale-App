import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Dream Land Shopping Material 3 theme.
///
/// Uses orange #F5A623 as seed color.
/// Arabic typography with large tap targets for field use.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'NotoSansArabic',
      // Large tap targets for field use (one-handed, sunlight)
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // Typography scale
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.3),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.4),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.4),
      ),
      // Elevated button with large touch target
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }
}
