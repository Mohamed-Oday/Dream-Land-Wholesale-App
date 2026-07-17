import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// labelCaps section header — 12/600 tracked, textSecondary, NO icon.
///
/// This replaces every icon+title section bar in the app.
///
/// ```dart
/// SectionLabel('أكبر المدينين')
/// SectionLabel('طلبات اليوم', trailing: TextButton(...)) // optional end action
/// ```
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.only(bottom: 8),
  });

  final String text;

  /// Optional small end-aligned action (e.g. "عرض الكل" TextButton).
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final label = Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.6,
        color: t.textSecondary,
      ),
    );
    return Padding(
      padding: padding,
      child: trailing == null
          ? label
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [label, trailing!],
            ),
    );
  }
}
