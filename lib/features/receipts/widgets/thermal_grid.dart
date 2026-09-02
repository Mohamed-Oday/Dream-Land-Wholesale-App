// lib/features/receipts/widgets/thermal_grid.dart
import 'package:flutter/material.dart';

import 'package:tawzii/features/receipts/widgets/thermal.dart';

/// One label/amount row printed inside the grid frame under the items.
typedef GridFooterRow = ({String label, String value});

/// A grid cell: a main line of spans and an optional smaller second line.
class ThermalCell extends StatelessWidget {
  final List<InlineSpan> main;
  final List<InlineSpan>? sub;
  final TextAlign align;
  final double mainSizeDots;
  final FontWeight mainWeight;

  const ThermalCell({
    super.key,
    required this.main,
    this.sub,
    this.align = TextAlign.start,
    this.mainSizeDots = 21,
    this.mainWeight = FontWeight.w400,
  });

  ThermalCell.text(
    String text, {
    super.key,
    String? sub,
    this.align = TextAlign.start,
    this.mainSizeDots = 21,
    this.mainWeight = FontWeight.w400,
  })  : main = [TextSpan(text: text)],
        sub = sub == null ? null : [TextSpan(text: sub)];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Dots.px(6), horizontal: Dots.px(5)),
      child: Column(
        crossAxisAlignment: switch (align) {
          TextAlign.center => CrossAxisAlignment.center,
          TextAlign.end || TextAlign.left => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children: [
          RichText(
            textAlign: align,
            text: TextSpan(
              style: TextStyle(
                fontFamily: kThermalFont,
                fontSize: Dots.px(mainSizeDots),
                fontWeight: mainWeight,
                height: 1.25,
                color: ThermalInk.black,
              ),
              children: main,
            ),
          ),
          if (sub case != null)
            RichText(
              textAlign: align,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: kThermalFont,
                  fontSize: Dots.px(17),
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: ThermalInk.black,
                ),
                children: sub,
              ),
            ),
        ],
      ),
    );
  }
}

/// The boxed item table (column template A): every cell ruled.
///
/// Built as up to three stacked [Table]s that share fixed column widths so
/// their vertical rules line up: header, body, and an optional footer whose
/// label spans every column but the last. Flutter's [Table] has no colspan,
/// which is why the footer is its own table.
class ThermalGrid extends StatelessWidget {
  /// Column widths in printer dots. Must sum to 536.
  final List<double> columnDots;
  final List<String> headers;
  final List<TextAlign> aligns;
  final List<List<Widget>> rows;
  final List<GridFooterRow> footer;

  const ThermalGrid({
    super.key,
    required this.columnDots,
    required this.headers,
    required this.aligns,
    required this.rows,
    this.footer = const [],
  })  : assert(headers.length == columnDots.length),
        assert(aligns.length == columnDots.length);

  static final BorderSide _thick =
      BorderSide(color: ThermalInk.black, width: Dots.px(3));
  static final BorderSide _thin =
      BorderSide(color: ThermalInk.black, width: Dots.px(2));

  Map<int, TableColumnWidth> get _widths => {
        for (var i = 0; i < columnDots.length; i++)
          i: FixedColumnWidth(Dots.px(columnDots[i])),
      };

  @override
  Widget build(BuildContext context) {
    assert(columnDots.fold<double>(0, (a, b) => a + b) == 536,
        'grid columns must span the 536-dot content width');
    final hasFooter = footer.isNotEmpty;

    final header = Table(
      columnWidths: _widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder(
        top: _thick,
        left: _thick,
        right: _thick,
        bottom: _thick,
        verticalInside: _thin,
      ),
      children: [
        TableRow(children: [
          for (var i = 0; i < headers.length; i++)
            ThermalCell.text(headers[i],
                align: aligns[i], mainSizeDots: 19, mainWeight: FontWeight.w700),
        ]),
      ],
    );

    final body = Table(
      columnWidths: _widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder(
        left: _thick,
        right: _thick,
        bottom: hasFooter ? BorderSide.none : _thick,
        horizontalInside: _thin,
        verticalInside: _thin,
      ),
      children: [for (final r in rows) TableRow(children: r)],
    );

    final footerTable = hasFooter
        ? Table(
            columnWidths: {
              0: FixedColumnWidth(Dots.px(columnDots
                  .take(columnDots.length - 1)
                  .fold<double>(0, (a, b) => a + b))),
              1: FixedColumnWidth(Dots.px(columnDots.last)),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            border: TableBorder(
              top: _thick,
              left: _thick,
              right: _thick,
              bottom: _thick,
              horizontalInside: _thin,
              verticalInside: _thin,
            ),
            children: [
              for (final f in footer)
                TableRow(children: [
                  ThermalCell.text(f.label, mainWeight: FontWeight.w700),
                  ThermalCell.text(f.value,
                      align: aligns.last, mainWeight: FontWeight.w700),
                ]),
            ],
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, body, if (footerTable case != null) footerTable],
    );
  }
}
