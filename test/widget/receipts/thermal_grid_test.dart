// test/widget/receipts/thermal_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';
import 'package:tawzii/features/receipts/widgets/thermal_grid.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: SizedBox(width: 268, child: child)),
        ),
      ),
    );

ThermalGrid _grid({List<GridFooterRow> footer = const []}) => ThermalGrid(
      columnDots: const [236, 84, 96, 120],
      headers: const ['الصنف', 'الكمية', 'السعر', 'الإجمالي'],
      aligns: const [TextAlign.start, TextAlign.center, TextAlign.center, TextAlign.end],
      rows: [
        [
          ThermalCell.text('مياه نقي 0.5 لتر', sub: '12 ق/ع', mainSizeDots: 23, mainWeight: FontWeight.w600),
          ThermalCell.text('6 ع', align: TextAlign.center),
          ThermalCell.text('240', align: TextAlign.center),
          ThermalCell.text('1 440', align: TextAlign.end, mainWeight: FontWeight.w700),
        ],
      ],
      footer: footer,
    );

void main() {
  testWidgets('columns are fixed at the dot widths (÷2) and sum to 268',
      (tester) async {
    await tester.pumpWidget(_wrap(_grid()));
    final tables = tester.widgetList<Table>(find.byType(Table)).toList();
    expect(tables.length, 2); // header + body, no footer
    final widths = tables.first.columnWidths!;
    expect((widths[0]! as FixedColumnWidth).value, 118);
    expect((widths[1]! as FixedColumnWidth).value, 42);
    expect((widths[2]! as FixedColumnWidth).value, 48);
    expect((widths[3]! as FixedColumnWidth).value, 60);
    expect(tester.getSize(find.byType(Table).first).width, 268);
  });

  testWidgets('outer frame is 1.5 px and inner rules are 1.0 px black',
      (tester) async {
    await tester.pumpWidget(_wrap(_grid()));
    final tables = tester.widgetList<Table>(find.byType(Table)).toList();
    final header = tables[0].border!;
    expect(header.top.width, 1.5);
    expect(header.bottom.width, 1.5); // header bottom is a 3-dot rule
    expect(header.left.width, 1.5);
    expect(header.right.width, 1.5);
    expect(header.verticalInside.width, 1.0);
    final body = tables[1].border!;
    expect(body.top, BorderSide.none); // shares the header's bottom rule
    expect(body.bottom.width, 1.5);
    expect(body.horizontalInside.width, 1.0);
    expect(body.verticalInside.width, 1.0);
    for (final s in [header.top, body.bottom, body.verticalInside]) {
      expect(s.color, ThermalInk.black);
    }
  });

  testWidgets('footer rows span the first three columns and sit in the frame',
      (tester) async {
    await tester.pumpWidget(_wrap(_grid(footer: const [
      (label: 'المجموع الفرعي', value: '13 230'),
      (label: 'الخصم', value: '−230'),
    ])));
    final tables = tester.widgetList<Table>(find.byType(Table)).toList();
    expect(tables.length, 3);
    final foot = tables[2];
    expect((foot.columnWidths![0]! as FixedColumnWidth).value, 118 + 42 + 48);
    expect((foot.columnWidths![1]! as FixedColumnWidth).value, 60);
    expect(foot.border!.top.width, 1.5);
    expect(foot.border!.horizontalInside.width, 1.0);
    expect(foot.children.length, 2);
    expect(find.text('المجموع الفرعي'), findsOneWidget);
    expect(find.text('−230'), findsOneWidget);
    // Body no longer closes the frame; the footer does.
    expect(tables[1].border!.bottom, BorderSide.none);
  });

  testWidgets('every text in the grid is pure black', (tester) async {
    await tester.pumpWidget(_wrap(_grid(footer: const [(label: 'x', value: 'y')])));
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.color, ThermalInk.black, reason: t.data);
    }
    for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
      expect(r.text.style?.color, ThermalInk.black);
    }
  });
}
