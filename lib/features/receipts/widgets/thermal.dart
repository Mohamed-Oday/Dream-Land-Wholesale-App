import 'package:flutter/material.dart';

/// The only two colours that may appear on thermal paper. The ESC/POS
/// converter thresholds at luminance 128, so any grey resolves
/// unpredictably; hierarchy on paper comes from weight, size and rules.
abstract final class ThermalInk {
  static const Color black = Color(0xFF000000);
  static const Color paper = Color(0xFFFFFFFF);
}

/// Dot-denominated sizing. The paper is 288 logical px captured at
/// pixelRatio 2.0, so 1 logical px = 2 printer dots.
abstract final class Dots {
  static double px(num dots) => dots / 2;
}

const String kThermalFont = 'IBMPlexSansArabic';

enum ThermalRuleKind { solid, hair }

/// Full-width horizontal rule. Solid = 3 dots, hair = 2 dots. A 1-dot rule
/// can fall between sample rows and vanish; these never do.
class ThermalRule extends StatelessWidget {
  final ThermalRuleKind kind;
  const ThermalRule({super.key, this.kind = ThermalRuleKind.solid});

  @override
  Widget build(BuildContext context) {
    final solid = kind == ThermalRuleKind.solid;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Dots.px(solid ? 14 : 11)),
      child: Container(height: Dots.px(solid ? 3 : 2), color: ThermalInk.black),
    );
  }
}

/// Label on the start side, value on the end side.
class ThermalKv extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final double sizeDots;
  final double? valueSizeDots;
  final FontWeight? valueWeight;

  const ThermalKv({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.sizeDots = 22,
    this.valueSizeDots,
    this.valueWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: Dots.px(sizeDots),
                fontWeight: FontWeight.w500,
                color: ThermalInk.black)),
        SizedBox(width: Dots.px(14)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: Dots.px(valueSizeDots ?? sizeDots),
              fontWeight: valueWeight ?? (bold ? FontWeight.w700 : FontWeight.w600),
              color: ThermalInk.black,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one inverted block a receipt may spend: white text on solid black.
class TotalBar extends StatelessWidget {
  final String label;
  final String value;
  const TotalBar({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThermalInk.black,
      margin: EdgeInsets.symmetric(vertical: Dots.px(14)),
      padding: EdgeInsets.symmetric(vertical: Dots.px(9), horizontal: Dots.px(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: Dots.px(26),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.paper)),
          Text(value,
              style: TextStyle(
                  fontSize: Dots.px(32),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.paper)),
        ],
      ),
    );
  }
}

BoxDecoration _box() => BoxDecoration(
      border: Border.all(color: ThermalInk.black, width: Dots.px(4)),
    );

/// Centred boxed status, e.g. payment state.
class Stamp extends StatelessWidget {
  final String label;
  final String value;
  const Stamp({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _box(),
      margin: EdgeInsets.symmetric(vertical: Dots.px(14)),
      padding: EdgeInsets.symmetric(vertical: Dots.px(9), horizontal: Dots.px(14)),
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: Dots.px(18),
                  fontWeight: FontWeight.w600,
                  color: ThermalInk.black)),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: Dots.px(30),
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: ThermalInk.black)),
        ],
      ),
    );
  }
}

/// Boxed label/amount row for the balance still owed.
class DueBox extends StatelessWidget {
  final String label;
  final String value;
  const DueBox({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _box(),
      margin: EdgeInsets.symmetric(vertical: Dots.px(14)),
      padding: EdgeInsets.symmetric(vertical: Dots.px(10), horizontal: Dots.px(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: Dots.px(24),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.black)),
          Text(value,
              style: TextStyle(
                  fontSize: Dots.px(32),
                  fontWeight: FontWeight.w700,
                  color: ThermalInk.black)),
        ],
      ),
    );
  }
}

/// A 3-dot line to sign on, with its caption under it.
class SignatureLine extends StatelessWidget {
  final String label;
  const SignatureLine({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: Dots.px(3), color: ThermalInk.black),
        SizedBox(height: Dots.px(6)),
        Text(label,
            style: TextStyle(fontSize: Dots.px(18), color: ThermalInk.black)),
      ],
    );
  }
}
