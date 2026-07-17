import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme extension carrying Tawzii tokens that Material 3 roles lack.
///
/// Usage in any widget:
/// ```dart
/// final t = TawziiTokens.of(context);
/// Container(color: t.surfaceAlt, child: Text('x', style: TextStyle(color: t.textSecondary)));
/// ```
/// Never hardcode hex values in widgets — read from this extension so both
/// light and dark themes work on every screen.
@immutable
class TawziiTokens extends ThemeExtension<TawziiTokens> {
  const TawziiTokens({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.disabledFg,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.successSoft,
    required this.warningSoft,
    required this.dangerSoft,
    required this.infoSoft,
    required this.scrim,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// Surface ladder: [bg] (scaffold) -> [surface] (cards/sheets) ->
  /// [surfaceAlt] (inputs, secondary buttons, selected tint).
  final Color bg;
  final Color surface;
  final Color surfaceAlt;

  /// Hairline separator / quiet card outline.
  final Color border;

  /// Field-Kit hardened 2px borders on driver screens.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color disabledFg;

  /// Amber. Scarce: max 1-2 amber elements per screen.
  final Color accent;
  final Color accentHover;
  final Color accentSoft;

  /// Ink on amber — in BOTH themes. Never put white on amber.
  final Color onAccent;

  final Color success;
  final Color warning; // mustard, NOT accent; never fills buttons
  final Color danger; // reserved for debt / destructive
  final Color info;

  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;
  final Color infoSoft;

  final Color scrim;
  final Color skeletonBase;
  final Color skeletonHighlight;

  static const light = TawziiTokens(
    bg: AppColorsLight.bg,
    surface: AppColorsLight.surface,
    surfaceAlt: AppColorsLight.surfaceAlt,
    border: AppColorsLight.border,
    borderStrong: AppColorsLight.borderStrong,
    textPrimary: AppColorsLight.textPrimary,
    textSecondary: AppColorsLight.textSecondary,
    textMuted: AppColorsLight.textMuted,
    disabledFg: AppColorsLight.disabledFg,
    accent: AppColorsLight.accent,
    accentHover: AppColorsLight.accentHover,
    accentSoft: AppColorsLight.accentSoft,
    onAccent: AppColorsLight.onAccent,
    success: AppColorsLight.success,
    warning: AppColorsLight.warning,
    danger: AppColorsLight.danger,
    info: AppColorsLight.info,
    successSoft: AppColorsLight.successSoft,
    warningSoft: AppColorsLight.warningSoft,
    dangerSoft: AppColorsLight.dangerSoft,
    infoSoft: AppColorsLight.infoSoft,
    scrim: AppColorsLight.scrim,
    skeletonBase: AppColorsLight.skeletonBase,
    skeletonHighlight: AppColorsLight.skeletonHighlight,
  );

  static const dark = TawziiTokens(
    bg: AppColorsDark.bg,
    surface: AppColorsDark.surface,
    surfaceAlt: AppColorsDark.surfaceAlt,
    border: AppColorsDark.border,
    borderStrong: AppColorsDark.borderStrong,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    textMuted: AppColorsDark.textMuted,
    disabledFg: AppColorsDark.disabledFg,
    accent: AppColorsDark.accent,
    accentHover: AppColorsDark.accentHover,
    accentSoft: AppColorsDark.accentSoft,
    onAccent: AppColorsDark.onAccent,
    success: AppColorsDark.success,
    warning: AppColorsDark.warning,
    danger: AppColorsDark.danger,
    info: AppColorsDark.info,
    successSoft: AppColorsDark.successSoft,
    warningSoft: AppColorsDark.warningSoft,
    dangerSoft: AppColorsDark.dangerSoft,
    infoSoft: AppColorsDark.infoSoft,
    scrim: AppColorsDark.scrim,
    skeletonBase: AppColorsDark.skeletonBase,
    skeletonHighlight: AppColorsDark.skeletonHighlight,
  );

  /// Shorthand accessor: `final t = TawziiTokens.of(context);`
  static TawziiTokens of(BuildContext context) =>
      Theme.of(context).extension<TawziiTokens>() ?? light;

  @override
  TawziiTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? disabledFg,
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? successSoft,
    Color? warningSoft,
    Color? dangerSoft,
    Color? infoSoft,
    Color? scrim,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) {
    return TawziiTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      disabledFg: disabledFg ?? this.disabledFg,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      successSoft: successSoft ?? this.successSoft,
      warningSoft: warningSoft ?? this.warningSoft,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      infoSoft: infoSoft ?? this.infoSoft,
      scrim: scrim ?? this.scrim,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    );
  }

  @override
  TawziiTokens lerp(TawziiTokens? other, double t) {
    if (other is! TawziiTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return TawziiTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      disabledFg: l(disabledFg, other.disabledFg),
      accent: l(accent, other.accent),
      accentHover: l(accentHover, other.accentHover),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      info: l(info, other.info),
      successSoft: l(successSoft, other.successSoft),
      warningSoft: l(warningSoft, other.warningSoft),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      infoSoft: l(infoSoft, other.infoSoft),
      scrim: l(scrim, other.scrim),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonHighlight: l(skeletonHighlight, other.skeletonHighlight),
    );
  }
}

/// Tawzii Material 3 themes — hand-built ColorSchemes mapped from tokens
/// (no ColorScheme.fromSeed). "Surface Ladder" component language:
/// structure comes from surface value steps, near-borderless cards,
/// amber reserved for the single primary action.
abstract final class AppTheme {
  static const String fontFamily = 'IBMPlexSansArabic';

  static ThemeData get light => _build(TawziiTokens.light, Brightness.light);
  static ThemeData get dark => _build(TawziiTokens.dark, Brightness.dark);

  static ThemeData _build(TawziiTokens t, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      // Amber accent -> primary. On-accent is INK in both themes.
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.textPrimary,
      secondary: t.textSecondary,
      onSecondary: t.surface,
      secondaryContainer: t.surfaceAlt,
      onSecondaryContainer: t.textPrimary,
      tertiary: t.info,
      onTertiary: isDark ? t.bg : AppColorsLight.surface,
      tertiaryContainer: t.infoSoft,
      onTertiaryContainer: t.info,
      error: t.danger,
      onError: isDark ? t.bg : AppColorsLight.surface,
      errorContainer: t.dangerSoft,
      onErrorContainer: t.danger,
      // Surface ladder mapped onto M3 surface roles.
      surface: t.bg,
      onSurface: t.textPrimary,
      surfaceDim: t.surfaceAlt,
      surfaceBright: t.surface,
      surfaceContainerLowest: isDark ? t.bg : t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surfaceAlt,
      surfaceContainerHighest: t.surfaceAlt,
      onSurfaceVariant: t.textSecondary,
      outline: t.borderStrong,
      outlineVariant: t.border,
      shadow: const Color(0xFF000000),
      scrim: t.scrim,
      inverseSurface: t.textPrimary,
      onInverseSurface: t.bg,
      inversePrimary: t.accentHover,
      surfaceTint: Colors.transparent,
    );

    // Type scale — hero 34/600 tabular, h1 22/600, h2 18/600, body 15/400,
    // labelCaps 12/600 tracked, unitCaption 12/500. Arabic line-height ~1.7.
    final textTheme = TextTheme(
      // Hero number (34/600, tabular, tight tracking) — use for hero money.
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.68,
        color: t.textPrimary,
        fontFeatures: const [
          FontFeature.tabularFigures(),
          FontFeature.slashedZero(),
        ],
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: t.textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: t.textPrimary,
      ),
      // h1 22/600
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: t.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: t.textPrimary,
      ),
      // h2 18/600
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: t.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: t.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: t.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.7,
        color: t.textPrimary,
      ),
      // body 15/400
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.7,
        color: t.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: t.textSecondary,
      ),
      // Buttons
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: t.textPrimary,
      ),
      // labelCaps 12/600 tracked — section headers (see SectionLabel widget)
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.6,
        color: t.textSecondary,
      ),
      // unitCaption 12/500
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0,
        color: t.textSecondary,
      ),
    );

    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [t],
      fontFamily: fontFamily,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      dividerColor: t.border,
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.textSecondary),
      disabledColor: t.disabledFg,

      // Primary CTA: amber fill + INK text. Radius 10, min 48px target.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.surfaceAlt,
          disabledForegroundColor: t.disabledFg,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 22),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.surfaceAlt,
          disabledForegroundColor: t.disabledFg,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 22),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      // Secondary: quiet surfaceAlt fill (surface-ladder, near-borderless).
      // For Field-Kit hardened outlines use OutlinedButton with 2px side.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.textSecondary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
          shape: buttonShape,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          disabledForegroundColor: t.disabledFg,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
          side: BorderSide(color: t.borderStrong),
          shape: buttonShape,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // Inputs: quiet labels (no floating-label theatrics), surfaceAlt fill,
      // borderless until focus (amber 2px). Radius 10.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceAlt,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: textTheme.bodyMedium?.copyWith(color: t.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        helperStyle: textTheme.labelSmall,
        errorStyle: textTheme.labelSmall?.copyWith(color: t.danger),
        contentPadding:
            const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.danger, width: 2),
        ),
      ),

      // Cards: radius 14, NO default border — differentiation comes from the
      // surface ladder (surface on bg). Only real shadow in the app = FAB.
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
      ),

      // AppBar: flat, bg-colored, no elevation tint.
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: t.textPrimary),
      ),

      // Sheets/dialogs: one rung up the ladder (surface over bg) over scrim.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        modalBarrierColor: t.scrim,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.vertical(
            top: Radius.circular(20),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: t.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // Chips: surfaceAlt quiet fill, accentSoft when selected.
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceAlt,
        selectedColor: t.accentSoft,
        disabledColor: t.surfaceAlt,
        side: BorderSide.none,
        labelStyle: textTheme.labelSmall
            ?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
        padding:
            const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.accentSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? t.textPrimary
                : t.textSecondary,
          ),
        ),
      ),

      // The one sanctioned shadow in the app.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        contentPadding:
            const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.bg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surfaceAlt,
        circularTrackColor: t.surfaceAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.onAccent
              : t.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.accent : t.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : t.borderStrong,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.textPrimary,
        unselectedLabelColor: t.textSecondary,
        indicatorColor: t.accent,
        dividerColor: t.border,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
