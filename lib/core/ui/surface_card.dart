import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Surface-ladder rungs for [SurfaceCard].
enum SurfaceLevel {
  /// surface color, radius 14. Hairline border in light theme only —
  /// in dark the surface value step alone provides separation.
  primary,

  /// surfaceAlt, borderless, radius 14 — secondary blocks.
  alt,

  /// surfaceAlt tint, radius 10 — selected row/item highlight.
  selected,
}

/// Surface-ladder container — the replacement for identical outlined Cards.
///
/// Structure comes from surface value steps (bg -> surface -> surfaceAlt),
/// not borders or shadows.
///
/// ```dart
/// SurfaceCard(child: Column(children: rows))                 // list container
/// SurfaceCard(level: SurfaceLevel.alt, child: ...)           // quiet block
/// SurfaceCard(level: SurfaceLevel.selected, onTap: ..., child: ...)
/// SurfaceCard(hardened: true, child: ...)                    // driver: 2px border
/// ```
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.level = SurfaceLevel.primary,
    this.padding = const EdgeInsetsDirectional.all(6),
    this.margin,
    this.radius,
    this.onTap,
    this.hardened = false,
  });

  final Widget child;
  final SurfaceLevel level;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Defaults: 14 (primary/alt), 10 (selected), 12 (hardened).
  final double? radius;

  final VoidCallback? onTap;

  /// Field-Kit hardening (driver screens): 2px borderStrong outline,
  /// radius 12.
  final bool hardened;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final double r = radius ??
        (hardened
            ? 12
            : switch (level) {
                SurfaceLevel.primary => 14,
                SurfaceLevel.alt => 14,
                SurfaceLevel.selected => 10,
              });

    final Color bg = switch (level) {
      SurfaceLevel.primary => t.surface,
      SurfaceLevel.alt => t.surfaceAlt,
      SurfaceLevel.selected => t.surfaceAlt,
    };

    final BoxBorder? border = hardened
        ? Border.all(color: t.borderStrong, width: 2)
        : (level == SurfaceLevel.primary && isLight
            ? Border.all(color: t.border)
            : null);

    final borderRadius = BorderRadius.circular(r);

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
