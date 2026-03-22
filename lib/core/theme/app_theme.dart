import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Dream Land Shopping Material 3 theme.
///
/// Uses orange #F5A623 as seed with brand palette overrides.
/// Arabic typography with large tap targets for field use.
abstract final class AppTheme {
  static ThemeData get light {
    final seedScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    // Override with exact brand palette colors — don't let Material 3 transform them
    final colorScheme = seedScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.lightGold,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.primaryPressed,
      onSecondary: AppColors.onPrimary,
      secondaryContainer: AppColors.cream,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.mist,
      surfaceBright: AppColors.onPrimary,
      surfaceDim: AppColors.mist,
      surfaceContainer: AppColors.onPrimary,
      surfaceContainerLow: AppColors.onPrimary,
      surfaceContainerLowest: AppColors.onPrimary,
      surfaceContainerHigh: AppColors.onPrimary,
      surfaceContainerHighest: AppColors.onPrimary,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.charcoal,
      outline: AppColors.slate,
      outlineVariant: const Color(0xFFE0E0E0),
      error: AppColors.error,
      onError: AppColors.onPrimary,
      errorContainer: const Color(0xFFFCE4E4),
      tertiary: AppColors.info,
      onTertiary: AppColors.onPrimary,
      tertiaryContainer: const Color(0xFFD6E8F0),
      onTertiaryContainer: AppColors.info,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.mist,
      canvasColor: AppColors.onPrimary,
      fontFamily: 'Cairo',
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
      cardTheme: CardThemeData(
        color: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFE0E0E0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.onPrimary,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelAlignment: FloatingLabelAlignment.start,
        floatingLabelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.charcoal,
          backgroundColor: AppColors.mist,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.onPrimary,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.onPrimary),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.onPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.onPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.onPrimary,
        selectedColor: AppColors.lightGold,
        side: BorderSide(color: const Color(0xFFE0E0E0)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.onPrimary,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.lightGold,
      ),
    );
  }
}
