import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Tawzii list-row primitive — replaces ListTile + CircleAvatar rows.
///
/// Anatomy (RTL-aware): leading status dot/pill · title + subtitle metadata ·
/// trailing Money/text. Min target 48px (56px hardened).
///
/// Two variants:
/// - Default (Surface Ladder): quiet row meant to live inside a
///   [SurfaceCard]; separation by whitespace, or a hairline via
///   [showDivider]; selection = surfaceAlt tint via [selected].
/// - Field-Kit ([hardened]): self-contained card with 2px borderStrong
///   border, radius 12, 56px min height, bigger text — driver screens.
///
/// ```dart
/// SurfaceCard(
///   child: Column(children: [
///     TawziiRow(
///       leading: StatusDot(StatusKind.danger),
///       title: 'بقالة الإخوة عمراني',
///       subtitle: 'دين منذ 12 يوم',
///       trailing: Money(86300, tint: MoneyTint.danger),
///       onTap: () => context.push('/stores/1'),
///     ),
///     TawziiRow(title: 'مقهى الساحة', trailing: Money(5000)),
///   ]),
/// )
///
/// // Driver screen (Field Kit), rows separated by 8px gaps:
/// TawziiRow(hardened: true, title: 'سوبيرات الأمل', trailing: Money(12450))
/// ```
class TawziiRow extends StatelessWidget {
  const TawziiRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.hardened = false,
    this.showDivider = false,
  });

  final String title;
  final String? subtitle;

  /// Usually a [StatusDot]; never a CircleAvatar.
  final Widget? leading;

  /// Usually a [Money] or small text/chevron.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Surface Ladder selection: surfaceAlt tint, radius 10.
  final bool selected;

  /// Field-Kit hardening: 2px border, 56px target, 16px title.
  final bool hardened;

  /// Hairline bottom divider (non-hardened rows in flat lists).
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    final titleStyle = TextStyle(
      fontSize: hardened ? 16 : 15,
      fontWeight: hardened ? FontWeight.w600 : FontWeight.w500,
      height: 1.5,
      color: t.textPrimary,
    );
    final subtitleStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: hardened ? t.textSecondary : t.textMuted,
    );

    Widget row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: hardened ? 56 : 48),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: hardened ? 14 : 12,
          vertical: hardened ? 9 : 7,
        ),
        child: Row(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 11),
                child: leading,
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: subtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 11),
                child: trailing,
              ),
          ],
        ),
      ),
    );

    if (hardened) {
      return Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderStrong, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: row,
          ),
        ),
      );
    }

    row = Material(
      color: selected ? t.surfaceAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: row,
      ),
    );

    if (!showDivider) return row;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Divider(height: 1, thickness: 1, color: t.border),
        ),
      ],
    );
  }
}
