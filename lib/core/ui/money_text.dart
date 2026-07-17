import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Size presets for [Money].
enum MoneySize {
  /// 34/600, tight tracking — one per region. Unit 14/500.
  hero,

  /// 18/600 — section totals. Unit 12/500.
  h2,

  /// 15/600 — inline body amounts. Unit 12/500.
  body,

  /// 15/600 — list-row trailing amounts. Unit 11/500.
  row,
}

/// Semantic tint for the NUMBER (color goes on the number + a small dot,
/// never on whole cards). Danger is reserved for debt.
enum MoneyTint { neutral, success, warning, danger, info }

/// THE shared money widget — use it for every amount in the app.
///
/// Renders Western digits, tabular lining figures, fr_DZ style formatting
/// (U+2007 figure-space thousands separator, comma decimal, whole-dinar by
/// default) as one bidi-isolated LTR run, with the دج unit smaller in
/// textSecondary.
///
/// ```dart
/// Money(12450)                                     // 12 450 دج (row size)
/// Money(342800, size: MoneySize.hero)              // dashboard hero
/// Money(86300, tint: MoneyTint.danger, showDot: true) // debt: red number + dot
/// Money(1250.5, decimals: true)                    // 1 250,50 دج
/// Money(950, showUnit: false)                      // bare number
/// Text('الإجمالي: ${Money.format(12450)} دج')      // plain-string form
/// ```
class Money extends StatelessWidget {
  const Money(
    this.amount, {
    super.key,
    this.size = MoneySize.row,
    this.tint = MoneyTint.neutral,
    this.decimals = false,
    this.showUnit = true,
    this.showDot = false,
    this.color,
    this.numberStyle,
  });

  /// Amount in dinars.
  final num amount;

  final MoneySize size;

  /// Colors the number (and dot). Ignored when [color] is set.
  final MoneyTint tint;

  /// Show 2 decimal places (comma separator). Default is whole-dinar.
  final bool decimals;

  /// Render the small دج unit after the number.
  final bool showUnit;

  /// Prepend an 8px status dot in the tint color (debt/paid rows).
  final bool showDot;

  /// Hard override for the number color (e.g. stale hero dims to
  /// textSecondary). Wins over [tint].
  final Color? color;

  /// Optional override of the preset number TextStyle (merged on top).
  final TextStyle? numberStyle;

  /// U+2007 figure space — the thousands separator.
  static const String figureSpace = '\u2007';

  /// Formats [amount] fr_DZ style: figure-space (U+2007) thousands groups,
  /// comma decimal, whole-dinar unless [decimals]. No unit, no bidi marks.
  static String format(num amount, {bool decimals = false}) {
    final negative = amount < 0;
    final abs = amount.abs();
    String intPart;
    String decPart = '';
    if (decimals) {
      final fixed = abs.toStringAsFixed(2);
      final dot = fixed.indexOf('.');
      intPart = fixed.substring(0, dot);
      decPart = ',${fixed.substring(dot + 1)}';
    } else {
      intPart = abs.round().toString();
    }
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        grouped.write(figureSpace);
      }
      grouped.write(intPart[i]);
    }
    assert(
      !grouped.toString().contains(',') && !grouped.toString().contains('.'),
      'Money grouping must use U+2007 figure space only',
    );
    return '${negative ? '-' : ''}$grouped$decPart';
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    final Color numberColor = color ??
        switch (tint) {
          MoneyTint.neutral => t.textPrimary,
          MoneyTint.success => t.success,
          MoneyTint.warning => t.warning,
          MoneyTint.danger => t.danger,
          MoneyTint.info => t.info,
        };

    final (double numberSize, double unitSize, FontWeight weight) =
        switch (size) {
      MoneySize.hero => (34, 14, FontWeight.w600),
      MoneySize.h2 => (18, 12, FontWeight.w600),
      MoneySize.body => (15, 12, FontWeight.w600),
      MoneySize.row => (15, 11, FontWeight.w600),
    };

    final baseNumberStyle = TextStyle(
      fontSize: numberSize,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: size == MoneySize.hero ? -0.68 : 0,
      color: numberColor,
      fontFeatures: const [
        FontFeature.tabularFigures(),
        FontFeature.slashedZero(),
      ],
    ).merge(numberStyle);

    final unitStyle = TextStyle(
      fontSize: unitSize,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 0,
      color: t.textSecondary,
    );

    // One bidi-isolated LTR run: \u2066 = LRI, \u2069 = PDI.
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '\u2066${format(amount, decimals: decimals)}'),
          if (showUnit) TextSpan(text: ' دج', style: unitStyle),
          const TextSpan(text: '\u2069'),
        ],
      ),
      style: baseNumberStyle,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      overflow: TextOverflow.clip,
    );

    if (!showDot) return text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsetsDirectional.only(end: 6),
          decoration:
              BoxDecoration(color: numberColor, shape: BoxShape.circle),
        ),
        text,
      ],
    );
  }
}
