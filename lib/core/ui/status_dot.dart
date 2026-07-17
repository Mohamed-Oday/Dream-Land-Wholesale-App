import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Semantic status kinds for [StatusDot] / [StatusPill].
enum StatusKind {
  /// Quiet gray (borderStrong) — default/inactive rows.
  neutral,

  /// textMuted — offline / unsynced.
  muted,

  success,
  warning,
  danger,
  info,

  /// Amber — "pending decision" only (amber is scarce).
  pending,
}

/// Resolves a [StatusKind] to its token color.
Color statusColor(StatusKind kind, TawziiTokens t) => switch (kind) {
      StatusKind.neutral => t.borderStrong,
      StatusKind.muted => t.textMuted,
      StatusKind.success => t.success,
      StatusKind.warning => t.warning,
      StatusKind.danger => t.danger,
      StatusKind.info => t.info,
      StatusKind.pending => t.accent,
    };

/// The 8px status dot — the app's status language (replaces status chips,
/// colored cards and CircleAvatars).
///
/// ```dart
/// StatusDot(StatusKind.danger)              // debt row
/// StatusDot(StatusKind.success, size: 10)   // Field-Kit hardened rows
/// ```
class StatusDot extends StatelessWidget {
  const StatusDot(this.kind, {super.key, this.size = 8});

  final StatusKind kind;

  /// 8 default; use 10 on Field-Kit (driver) hardened rows.
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor(kind, t),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Small label pill with a 6px dot — e.g. "قيد المزامنة".
///
/// Neutral outline, never a filled color block.
///
/// ```dart
/// StatusPill(label: 'قيد المزامنة', kind: StatusKind.muted)
/// StatusPill(label: 'مدفوع', kind: StatusKind.success, hardened: true)
/// ```
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.kind = StatusKind.neutral,
    this.hardened = false,
  });

  final String label;
  final StatusKind kind;

  /// Field-Kit: 2px borderStrong outline.
  final bool hardened;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: hardened ? t.borderStrong : t.border,
          width: hardened ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsetsDirectional.only(end: 6),
            decoration: BoxDecoration(
              color: statusColor(kind, t),
              shape: BoxShape.circle,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: hardened ? FontWeight.w700 : FontWeight.w600,
              height: 1.4,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
