import 'package:flutter/material.dart';

/// Dream Land Shopping brand color tokens.
///
/// Primary: Orange #F5A623 (from logo)
/// On-primary: White #FFFFFF
/// All other colors derived via Material 3 ColorScheme.fromSeed.
abstract final class AppColors {
  // Brand colors
  static const Color primary = Color(0xFFF5A623);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic colors (used for non-themed contexts like receipts)
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // Text colors for light theme
  static const Color textPrimary = Color(0xFF1C1B1F);
  static const Color textSecondary = Color(0xFF49454F);
  static const Color textDisabled = Color(0xFF9E9E9E);
}
