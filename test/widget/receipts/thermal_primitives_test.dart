import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SizedBox(width: 288, child: child)),
      ),
    );

void main() {
  test('Dots converts printer dots to logical px at 2 dots per px', () {
    expect(Dots.px(22), 11.0);
    expect(Dots.px(3), 1.5);
  });

  testWidgets('solid rule is 1.5 logical px (3 dots) of pure black',
      (tester) async {
    await tester.pumpWidget(_wrap(const ThermalRule()));
    final box = tester.widget<Container>(find.byType(Container));
    expect(box.color, ThermalInk.black);
    expect(tester.getSize(find.byType(Container)).height, 1.5);
  });

  testWidgets('hair rule is 1.0 logical px (2 dots)', (tester) async {
    await tester.pumpWidget(_wrap(const ThermalRule(kind: ThermalRuleKind.hair)));
    expect(tester.getSize(find.byType(Container)).height, 1.0);
  });

  testWidgets('TotalBar is white on black', (tester) async {
    await tester.pumpWidget(_wrap(const TotalBar(label: 'الإجمالي', value: '13 000 د.ج')));
    final bar = tester.widget<Container>(find.byType(Container).first);
    expect(bar.color, ThermalInk.black);
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.color, ThermalInk.paper, reason: t.data);
    }
  });

  testWidgets('Stamp and DueBox draw a 2.0 px (4 dot) black border',
      (tester) async {
    await tester.pumpWidget(_wrap(const Column(children: [
      Stamp(label: 'حالة الدفع', value: 'مدفوع جزئياً'),
      DueBox(label: 'المتبقي', value: '8 000'),
    ])));
    final boxes = tester.widgetList<Container>(find.byType(Container));
    final bordered = boxes.where((c) => c.decoration is BoxDecoration).toList();
    expect(bordered.length, 2);
    for (final c in bordered) {
      final b = (c.decoration! as BoxDecoration).border! as Border;
      expect(b.top.width, 2.0);
      expect(b.top.color, ThermalInk.black);
    }
  });

  testWidgets('SignatureLine shows a rule then its label', (tester) async {
    await tester.pumpWidget(_wrap(const SignatureLine(label: 'توقيع المستلم')));
    expect(find.text('توقيع المستلم'), findsOneWidget);
    expect(tester.getSize(find.byType(Container)).height, 1.5);
  });
}
