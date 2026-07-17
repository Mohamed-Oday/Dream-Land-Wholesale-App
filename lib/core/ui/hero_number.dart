import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'delta_chip.dart';
import 'money_text.dart';

/// The hero metric block — labelCaps caption + 34/600 tabular number.
/// Kills the 2x2 KPI grid: ONE hero per region, stats in a borderless row
/// beneath it (screens compose that themselves).
///
/// ```dart
/// HeroNumber(
///   label: 'إيرادات اليوم',
///   value: 342800,
///   delta: const DeltaChip.percent(8.4),
/// )
///
/// // Non-money hero (e.g. crate count):
/// HeroNumber(label: 'صناديق خارج المستودع', value: 142, isMoney: false)
///
/// // Stale (offline/old data): dims + timestamp; NEVER a spinner over money.
/// HeroNumber(label: 'إيرادات اليوم', value: 342800, stale: true, lastUpdatedLabel: '14:32')
/// ```
class HeroNumber extends StatelessWidget {
  const HeroNumber({
    super.key,
    required this.label,
    required this.value,
    this.isMoney = true,
    this.decimals = false,
    this.delta,
    this.tint = MoneyTint.neutral,
    this.stale = false,
    this.lastUpdatedLabel,
  });

  /// labelCaps caption above the number (e.g. 'إيرادات اليوم').
  final String label;

  final num value;

  /// true -> Money hero with دج unit; false -> bare tabular number.
  final bool isMoney;

  final bool decimals;

  /// Usually a [DeltaChip]; hidden while [stale].
  final Widget? delta;

  /// Semantic tint on the number (ignored while [stale]).
  final MoneyTint tint;

  /// Stale data: number dims to textSecondary, delta hides, and
  /// "آخر تحديث [lastUpdatedLabel]" shows beneath.
  final bool stale;

  /// Pre-formatted HH:MM shown when [stale] is true.
  final String? lastUpdatedLabel;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final numberColor = stale ? t.textSecondary : null;

    final Widget number = isMoney
        ? Money(
            value,
            size: MoneySize.hero,
            decimals: decimals,
            tint: tint,
            color: numberColor,
          )
        : Text(
            '\u2066${Money.format(value, decimals: decimals)}\u2069',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: -0.68,
              color: numberColor ??
                  switch (tint) {
                    MoneyTint.neutral => t.textPrimary,
                    MoneyTint.success => t.success,
                    MoneyTint.warning => t.warning,
                    MoneyTint.danger => t.danger,
                    MoneyTint.info => t.info,
                  },
              fontFeatures: const [
                FontFeature.tabularFigures(),
                FontFeature.slashedZero(),
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            height: 1.4,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: number),
            if (!stale && delta != null) ...[
              const SizedBox(width: 12),
              delta!,
            ],
          ],
        ),
        if (stale && lastUpdatedLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            'آخر تحديث \u2066$lastUpdatedLabel\u2069',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: t.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
