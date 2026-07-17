import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'money_text.dart';

/// In-app numeric keypad — the app never opens the system keyboard for
/// amounts. 48px keys (56px hardened / Field-Kit), tabular display line
/// with live figure-space grouping, backspace (long-press = clear),
/// optional comma decimal key.
///
/// Embeddable, controlled widget:
/// ```dart
/// NumericKeypad(
///   initialValue: 1250,
///   allowDecimal: true,
///   hardened: true,               // driver payment screen
///   onChanged: (v) => setState(() => amount = v),
/// )
/// ```
/// Or the one-shot sheet (one surface rung up, over scrim):
/// ```dart
/// final v = await showKeypadSheet(context, title: 'المبلغ المستلم');
/// if (v != null) savePayment(v);
/// ```
class NumericKeypad extends StatefulWidget {
  const NumericKeypad({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.allowDecimal = false,
    this.hardened = false,
    this.showDisplay = true,
    this.maxIntegerDigits = 9,
  });

  final double? initialValue;

  /// Called on every keypress with the current parsed value (0 when empty).
  final ValueChanged<double> onChanged;

  /// Adds the comma decimal key (fr_DZ comma, max 2 decimals).
  final bool allowDecimal;

  /// Field-Kit hardening: 56px keys, 22px digits, 2px borders.
  final bool hardened;

  /// Render the grouped amount line above the keys.
  final bool showDisplay;

  final int maxIntegerDigits;

  @override
  State<NumericKeypad> createState() => _NumericKeypadState();
}

class _NumericKeypadState extends State<NumericKeypad> {
  /// Raw typed input: digits, optionally one ',' then up to 2 digits.
  late String _raw = _rawFromInitial();

  String _rawFromInitial() {
    final v = widget.initialValue;
    if (v == null || v == 0) return '';
    if (!widget.allowDecimal || v == v.roundToDouble()) {
      return v.round().toString();
    }
    return v.toStringAsFixed(2).replaceFirst('.', ',');
  }

  double get _value {
    if (_raw.isEmpty) return 0;
    return double.tryParse(_raw.replaceFirst(',', '.')) ?? 0;
  }

  /// Display string with live U+2007 grouping on the integer part.
  String get _display {
    if (_raw.isEmpty) return '0';
    final commaIndex = _raw.indexOf(',');
    final intPart = commaIndex == -1 ? _raw : _raw.substring(0, commaIndex);
    final rest = commaIndex == -1 ? '' : _raw.substring(commaIndex);
    final grouped = Money.format(int.tryParse(intPart) ?? 0);
    return '$grouped$rest';
  }

  void _emit() => widget.onChanged(_value);

  void _pressDigit(String d) {
    final commaIndex = _raw.indexOf(',');
    if (commaIndex == -1) {
      final intLen = _raw.length;
      if (intLen >= widget.maxIntegerDigits) return;
      if (_raw == '0') _raw = '';
    } else {
      if (_raw.length - commaIndex > 2) return; // max 2 decimals
    }
    setState(() => _raw += d);
    _emit();
  }

  void _pressComma() {
    if (!widget.allowDecimal || _raw.contains(',')) return;
    setState(() => _raw = _raw.isEmpty ? '0,' : '$_raw,');
    _emit();
  }

  void _backspace() {
    if (_raw.isEmpty) return;
    setState(() => _raw = _raw.substring(0, _raw.length - 1));
    _emit();
  }

  void _clear() {
    if (_raw.isEmpty) return;
    setState(() => _raw = '');
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final hardened = widget.hardened;

    final keyHeight = hardened ? 56.0 : 48.0;
    final digitSize = hardened ? 22.0 : 20.0;
    final digitWeight = hardened ? FontWeight.w700 : FontWeight.w600;
    final keyBg = hardened
        ? (isLight ? t.surface : t.surfaceAlt)
        : t.surfaceAlt;
    final keyBorder =
        hardened ? Border.all(color: t.borderStrong, width: 2) : null;

    Widget key({
      required Widget child,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) {
      return Container(
        height: keyHeight,
        decoration: BoxDecoration(
          color: keyBg,
          border: keyBorder,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
            onLongPress: onLongPress,
            child: Center(child: child),
          ),
        ),
      );
    }

    Widget digitKey(String d) => key(
          onTap: () => _pressDigit(d),
          child: Text(
            d,
            style: TextStyle(
              fontSize: digitSize,
              fontWeight: digitWeight,
              color: t.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDisplay) ...[
          Container(
            height: hardened ? 56 : 52,
            width: double.infinity,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: t.surface,
              border: hardened
                  ? Border.all(color: t.borderStrong, width: 2)
                  : (isLight ? Border.all(color: t.border) : null),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '\u2066$_display'),
                  TextSpan(
                    text: ' دج',
                    style: TextStyle(
                      fontSize: hardened ? 13 : 12,
                      fontWeight: FontWeight.w500,
                      color: t.textSecondary,
                    ),
                  ),
                  const TextSpan(text: '\u2069'),
                ],
              ),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: hardened ? 26 : 22,
                fontWeight: hardened ? FontWeight.w700 : FontWeight.w600,
                color: t.textPrimary,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                  FontFeature.slashedZero(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Keys laid out LTR like a calculator (numerals never mirror).
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final rowKeys in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ]) ...[
                Row(
                  children: [
                    for (final d in rowKeys) ...[
                      Expanded(child: digitKey(d)),
                      if (d != rowKeys.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: widget.allowDecimal
                        ? key(
                            onTap: _pressComma,
                            child: Text(
                              '،',
                              style: TextStyle(
                                fontSize: hardened ? 20 : 18,
                                fontWeight: digitWeight,
                                color: t.textSecondary,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: digitKey('0')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: key(
                      onTap: _backspace,
                      onLongPress: _clear,
                      child: Icon(
                        Icons.backspace_outlined,
                        size: hardened ? 22 : 20,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows [NumericKeypad] in a modal bottom sheet (one surface rung up over
/// the scrim) with a confirm CTA. Returns the entered amount, or null if
/// dismissed.
///
/// ```dart
/// final amount = await showKeypadSheet(
///   context,
///   title: 'المبلغ المستلم',
///   initialValue: 5000,
///   allowDecimal: true,
///   hardened: true,
/// );
/// ```
Future<double?> showKeypadSheet(
  BuildContext context, {
  String? title,
  double? initialValue,
  bool allowDecimal = false,
  bool hardened = false,
  String confirmLabel = 'تأكيد',
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = TawziiTokens.of(sheetContext);
      var current = initialValue ?? 0;
      return Padding(
        padding: EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 4,
          bottom: 16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  height: 1.4,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            NumericKeypad(
              initialValue: initialValue,
              allowDecimal: allowDecimal,
              hardened: hardened,
              onChanged: (v) => current = v,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: hardened ? 56 : 48,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(current),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      );
    },
  );
}
