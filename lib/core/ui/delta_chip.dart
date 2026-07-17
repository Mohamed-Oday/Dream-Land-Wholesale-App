import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'money_text.dart';

/// Signed delta chip — "+8,4%" / "-12 500" — success tint when positive,
/// danger when negative, neutral at zero. The sign leads the LTR numeral
/// group; the whole run is bidi-isolated.
///
/// ```dart
/// DeltaChip.percent(8.4)      // +8,4%  (green pill)
/// DeltaChip.percent(-3.2)     // -3,2%  (red pill)
/// DeltaChip.amount(12500)     // +12 500
/// DeltaChip.percent(2.1, invertColors: true) // e.g. debt grew: red
/// ```
class DeltaChip extends StatelessWidget {
  /// Percentage delta: one decimal, comma separator, trailing %.
  const DeltaChip.percent(
    this.value, {
    super.key,
    this.invertColors = false,
  }) : isPercent = true;

  /// Amount delta: figure-space grouped whole dinars (no unit).
  const DeltaChip.amount(
    this.value, {
    super.key,
    this.invertColors = false,
  }) : isPercent = false;

  final double value;
  final bool isPercent;

  /// When an increase is BAD (debt, returns): positive renders danger,
  /// negative renders success.
  final bool invertColors;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    final positive = value > 0;
    final negative = value < 0;
    final good = invertColors ? negative : positive;
    final bad = invertColors ? positive : negative;

    final Color fg = good
        ? t.success
        : bad
            ? t.danger
            : t.textSecondary;
    final Color bg = good
        ? t.successSoft
        : bad
            ? t.dangerSoft
            : t.surfaceAlt;

    final sign = positive ? '+' : (negative ? '-' : '');
    final abs = value.abs();
    final body = isPercent
        ? '${abs.toStringAsFixed(1).replaceFirst('.', ',')}%'
        : Money.format(abs);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '\u2066$sign$body\u2069',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
