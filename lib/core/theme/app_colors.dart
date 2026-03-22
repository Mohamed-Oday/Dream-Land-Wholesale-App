import 'package:flutter/material.dart';

/// Dream Land Shopping brand color tokens.
///
/// Primary: Brand Orange #F5A623
/// Palette: Warm amber tones with forest/cherry/navy accents.
abstract final class AppColors {
  // Primary palette
  static const Color primary = Color(0xFFF5A623);       // Brand orange
  static const Color primaryPressed = Color(0xFFE8940D); // Deep amber
  static const Color onPrimary = Color(0xFFFFFFFF);      // White
  static const Color cream = Color(0xFFFFF3DC);          // Soft backgrounds
  static const Color lightGold = Color(0xFFFDDFA0);      // Highlights, tags

  // Neutrals
  static const Color ink = Color(0xFF1A1A1A);            // Headlines
  static const Color charcoal = Color(0xFF4A4A4A);       // Body text
  static const Color slate = Color(0xFF9B9B9B);          // Captions, hints
  static const Color mist = Color(0xFFF4F4F4);           // Page background

  // Accents & Semantic
  static const Color success = Color(0xFF2D6A4F);        // Forest green
  static const Color warning = Color(0xFFF9A825);        // Amber warning
  static const Color error = Color(0xFFD64045);          // Cherry
  static const Color info = Color(0xFF1B4965);           // Navy

  // Legacy aliases (for existing code references)
  static const Color textPrimary = ink;
  static const Color textSecondary = charcoal;
  static const Color textDisabled = slate;
}
