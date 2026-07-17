import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'status_dot.dart';

/// Shared screen-state blocks: skeleton loading, empty, error, offline.
/// Every screen ships all of these — never a spinner over money.

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

/// One shimmering skeleton list row (dot + two text bars + trailing bar),
/// surfaceAlt shimmer per the canvas.
///
/// ```dart
/// // while loading a list:
/// SurfaceCard(child: Column(children: List.filled(6, const SkeletonRow())))
/// // or use the convenience list:
/// const SkeletonList(count: 6)
/// ```
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.hardened = false});

  /// Field-Kit variant: bordered self-contained row.
  final bool hardened;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      child: Row(
        children: [
          _ShimmerBox(
            width: 8,
            height: 8,
            radius: 999,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.62,
                  child: _ShimmerBox(height: 10),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.34,
                  child: _ShimmerBox(height: 8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          _ShimmerBox(width: 52, height: 10),
        ],
      ),
    );

    if (!hardened) return row;
    final tokens = t;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.borderStrong, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: row,
    );
  }
}

/// A column of [SkeletonRow]s — drop-in loading state for any list screen.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.hardened = false});

  final int count;
  final bool hardened;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          SkeletonRow(hardened: hardened),
          if (i < count - 1) SizedBox(height: hardened ? 8 : 0),
        ],
      ],
    );
  }
}

/// Internal shimmering bar (surfaceAlt base, sliding highlight).
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({this.width, this.height = 10, this.radius = 5});

  final double? width;
  final double height;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Slide the highlight band across the bar (mirrors for RTL feel is
        // unnecessary — skeletons carry no meaning).
        final dx = (_controller.value * 3) - 1.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - dx, 0),
              end: Alignment(1 - dx, 0),
              colors: [
                t.skeletonBase,
                t.skeletonHighlight,
                t.skeletonBase,
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty
// ---------------------------------------------------------------------------

/// Empty state: labelCaps title + one sentence + ONE amber CTA.
///
/// ```dart
/// EmptyState(
///   title: 'لا توجد طلبات',
///   message: 'ستظهر الطلبات هنا بعد أول عملية بيع',
///   ctaLabel: 'طلب جديد',
///   onCta: () => context.push('/orders/new'),
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  final String title;
  final String message;

  /// The one amber CTA. Omit both to render text only.
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              height: 1.4,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: t.textMuted,
            ),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

/// Neutral error + retry (danger color is reserved for debt, not errors).
///
/// ```dart
/// ErrorRetryRow(onRetry: () => ref.invalidate(ordersProvider))
/// ```
class ErrorRetryRow extends StatelessWidget {
  const ErrorRetryRow({
    super.key,
    this.title = 'تعذّر تحميل البيانات',
    this.message = 'تحقق من الاتصال ثم أعد المحاولة',
    required this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: t.surfaceAlt,
              foregroundColor: t.textPrimary,
              minimumSize: const Size(48, 40),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline / unsynced
// ---------------------------------------------------------------------------

/// The neutral "قيد المزامنة" pill (6px muted dot). Attach next to any
/// unsynced record or amount.
class UnsyncedBadge extends StatelessWidget {
  const UnsyncedBadge({super.key, this.hardened = false});

  final bool hardened;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: 'قيد المزامنة',
      kind: StatusKind.muted,
      hardened: hardened,
    );
  }
}

/// Offline banner: neutral dot + "غير متصل — يُحفظ محلياً" + [UnsyncedBadge]
/// + last-synced time. Never alarmist, never danger-colored.
///
/// ```dart
/// OfflineBanner(lastSyncedLabel: '13:05', pendingCount: 3)
/// OfflineBanner(lastSyncedLabel: '13:05', hardened: true) // driver screens
/// ```
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.lastSyncedLabel,
    this.pendingCount,
    this.hardened = false,
  });

  /// Pre-formatted HH:MM of the last successful sync.
  final String? lastSyncedLabel;

  /// Number of operations waiting to sync (Field-Kit subtitle).
  final int? pendingCount;

  /// Field-Kit: 2px border, bolder text, warning-tinted dot.
  final bool hardened;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    final subtitleParts = <String>[
      if (lastSyncedLabel != null) 'آخر مزامنة \u2066$lastSyncedLabel\u2069',
      if (pendingCount != null) '$pendingCount عمليات معلقة',
    ];

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border:
            hardened ? Border.all(color: t.borderStrong, width: 2) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          StatusDot(
            hardened ? StatusKind.warning : StatusKind.muted,
            size: hardened ? 10 : 8,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'غير متصل — يُحفظ محلياً',
                  style: TextStyle(
                    fontSize: hardened ? 14 : 13,
                    fontWeight: hardened ? FontWeight.w700 : FontWeight.w600,
                    height: 1.5,
                    color: t.textPrimary,
                  ),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: t.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          UnsyncedBadge(hardened: hardened),
        ],
      ),
    );
  }
}
