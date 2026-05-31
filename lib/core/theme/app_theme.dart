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
      outlineVariant: seedScheme.outlineVariant,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      errorContainer: seedScheme.errorContainer,
      tertiary: AppColors.info,
      onTertiary: AppColors.onPrimary,
      tertiaryContainer: seedScheme.tertiaryContainer,
      onTertiaryContainer: AppColors.info,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
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
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelAlignment: FloatingLabelAlignment.start,
        floatingLabelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }
}
