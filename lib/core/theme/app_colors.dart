import 'package:flutter/material.dart';

/// Tawzii design tokens — Warm-Neutral Minimal ("Surface Ladder" 1b base,
/// "Field Kit" 1c hardening on driver screens).
///
/// LIGHT theme tokens. Never hardcode hex in widgets — read tokens from
/// `TawziiTokens.of(context)` (see app_theme.dart) so both themes work.
abstract final class AppColorsLight {
  // Surface ladder: bg -> surface -> surfaceAlt
  static const Color bg = Color(0xFFFAFAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF4F4F2);
  static const Color border = Color(0xFFE7E5E4);
  static const Color borderStrong = Color(0xFFD6D3D1);

  // Text
  static const Color textPrimary = Color(0xFF1C1917);
  static const Color textSecondary = Color(0xFF57534E);
  static const Color textMuted = Color(0xFF78716C);
  static const Color disabledFg = Color(0xFFC0BBB6);

  // Accent (amber is scarce: max 1-2 elements per screen)
  static const Color accent = Color(0xFFF5A623);
  static const Color accentHover = Color(0xFFE8940D);
  static const Color accentSoft = Color(0xFFFEF3E2);

  /// Text/icon color ON amber — always ink, NEVER white.
  static const Color onAccent = Color(0xFF1C1917);

  // Semantic (color goes on the NUMBER + a small dot, never whole cards)
  static const Color success = Color(0xFF2D6A4F);
  static const Color warning = Color(0xFF8A6D1B); // mustard != accent amber
  static const Color danger = Color(0xFFC0392B);
  static const Color info = Color(0xFF1B4965);

  // Soft containers for the semantic colors (chip/pill backgrounds)
  static const Color successSoft = Color(0x1A2D6A4F); // 10%
  static const Color warningSoft = Color(0x1A8A6D1B);
  static const Color dangerSoft = Color(0x1AC0392B);
  static const Color infoSoft = Color(0x1A1B4965);

  // Overlay
  static const Color scrim = Color(0x8C0C0A09); // rgba(12,10,9,.55)

  // Skeleton shimmer
  static const Color skeletonBase = Color(0xFFF4F4F2);
  static const Color skeletonHighlight = Color(0xFFECEAE7);
}

/// DARK theme tokens — a parallel surface ladder, one rung up per sheet.
abstract final class AppColorsDark {
  static const Color bg = Color(0xFF0C0A09);
  static const Color surface = Color(0xFF1C1917);
  static const Color surfaceAlt = Color(0xFF292524);
  static const Color border = Color(0xFF302B29);
  static const Color borderStrong = Color(0xFF44403C);

  static const Color textPrimary = Color(0xFFFAFAF9);
  static const Color textSecondary = Color(0xFFA8A29E);
  static const Color textMuted = Color(0xFF8F8880);
  static const Color disabledFg = Color(0xFF57534E);

  static const Color accent = Color(0xFFF7B84B);
  static const Color accentHover = Color(0xFFF5A623);
  static const Color accentSoft = Color(0xFF2A2016);

  /// Ink on amber in BOTH themes.
  static const Color onAccent = Color(0xFF1C1917);

  static const Color success = Color(0xFF3FB27F);
  static const Color warning = Color(0xFFC9A227);
  static const Color danger = Color(0xFFEF6D66);
  static const Color info = Color(0xFF5B8AA6);

  static const Color successSoft = Color(0x263FB27F); // 15%
  static const Color warningSoft = Color(0x26C9A227);
  static const Color dangerSoft = Color(0x26EF6D66);
  static const Color infoSoft = Color(0x265B8AA6);

  static const Color scrim = Color(0xA6000000); // rgba(0,0,0,.65)

  static const Color skeletonBase = Color(0xFF292524);
  static const Color skeletonHighlight = Color(0xFF332E2B);
}

/// Legacy aliases so pre-redesign screens keep compiling.
///
/// These map onto the LIGHT token set. New/redesigned code must NOT use
/// this class — use `TawziiTokens.of(context)` instead so dark mode works.
abstract final class AppColors {
  static const Color primary = AppColorsLight.accent;
  static const Color primaryPressed = AppColorsLight.accentHover;
  static const Color onPrimary = AppColorsLight.onAccent;
  static const Color cream = AppColorsLight.accentSoft;
  static const Color lightGold = AppColorsLight.accentSoft;

  static const Color ink = AppColorsLight.textPrimary;
  static const Color charcoal = AppColorsLight.textSecondary;
  static const Color slate = AppColorsLight.textMuted;
  static const Color mist = AppColorsLight.surfaceAlt;

  static const Color success = AppColorsLight.success;
  static const Color warning = AppColorsLight.warning;
  static const Color error = AppColorsLight.danger;
  static const Color info = AppColorsLight.info;

  static const Color textPrimary = AppColorsLight.textPrimary;
  static const Color textSecondary = AppColorsLight.textSecondary;
  static const Color textDisabled = AppColorsLight.disabledFg;
}
