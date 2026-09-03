// test/widget/receipts/receipt_palette_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/models/receipt_line.dart';
import 'package:tawzii/features/receipts/widgets/receipt_paper.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';

import 'fixtures.dart';

// Not `const`: `Color` overrides `==`, so it does not have primitive
// equality and a `const` set of `Color` is never allowed
// (const_set_element_not_primitive_equality).
final _allowed = {ThermalInk.black, ThermalInk.paper};

void _expectInk(Color? c, String where) {
  if (c == null) return;
  expect(_allowed.contains(c), isTrue,
      reason: '$where uses $c — only ThermalInk.black / paper may print');
}

void _checkSpan(InlineSpan span, String where) {
  _expectInk(span.style?.color, where);
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      _checkSpan(child, where);
    }
  }
}

void _checkBorder(BoxBorder? b, String where) {
  if (b is Border) {
    for (final s in [b.top, b.bottom, b.left, b.right]) {
      if (s != BorderSide.none) _expectInk(s.color, where);
    }
  }
}

/// Walks every widget under the paper and asserts each declared colour.
Future<void> expectOnlyInk(WidgetTester tester) async {
  final inPaper = find.descendant(
    of: find.byType(ReceiptPaper),
    matching: find.byWidgetPredicate((_) => true),
  );
  expect(find.descendant(of: find.byType(ReceiptPaper), matching: find.byType(CustomPaint)),
      findsNothing, reason: 'no CustomPaint on the paper — painters hide colours');
  var checked = 0;
  for (final w in tester.widgetList(inPaper)) {
    checked++;
    switch (w) {
      case Text():
        _expectInk(w.style?.color, 'Text "${w.data}"');
      case RichText():
        _checkSpan(w.text, 'RichText');
      case DefaultTextStyle():
        _expectInk(w.style.color, 'DefaultTextStyle');
      case Container():
        _expectInk(w.color, 'Container');
        if (w.decoration case BoxDecoration d) {
          _expectInk(d.color, 'Container.decoration');
          _checkBorder(d.border, 'Container.border');
        }
      case DecoratedBox():
        if (w.decoration case BoxDecoration d) {
          _expectInk(d.color, 'DecoratedBox');
          _checkBorder(d.border, 'DecoratedBox.border');
        }
      case Table():
        final b = w.border;
        if (b != null) {
          for (final s in [b.top, b.bottom, b.left, b.right, b.horizontalInside, b.verticalInside]) {
            if (s != BorderSide.none) _expectInk(s.color, 'Table border');
          }
        }
      case ColoredBox():
        _expectInk(w.color, 'ColoredBox');
      default:
        break;
    }
  }
  expect(checked, greaterThan(20), reason: 'the walk should visit the paper');
}

void main() {
  setUp(() {
    // Tall surface so the full receipt lays out.
  });

  testWidgets('order paper declares only black and white', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper()));
    await expectOnlyInk(tester);
  });

  testWidgets('order paper is exactly 288 logical px wide', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper()));
    expect(tester.getSize(find.byType(ReceiptPaper)).width, 288);
  });

  testWidgets('order paper shows the grid, stamp, due box and signatures',
      (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper()));
    expect(find.text('فاتورة تسليم'), findsOneWidget);
    expect(find.text('#${ltr('3F9A2C1B')}'), findsOneWidget);
    expect(find.text('مدفوع جزئياً'), findsOneWidget);
    expect(find.text('المتبقي'), findsOneWidget);
    expect(find.text('توقيع المستلم'), findsOneWidget);
    expect(find.text('توقيع السائق'), findsOneWidget);
    expect(find.textContaining('0770 12 34 56'), findsNWidgets(2)); // header + footer
    expect(find.textContaining('للقطعة', findRichText: true), findsOneWidget);
    expect(find.textContaining('+\u20666\u2069 ق', findRichText: true), findsOneWidget);
  });

  testWidgets('cancelled order shows ملغى and no payment block', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(orderPaper(order: sampleOrder(status: 'cancelled'))));
    expect(find.text(l10nAr.statusCancelled), findsOneWidget);
    expect(find.text('حالة الدفع'), findsNothing);
    expect(find.text('المتبقي'), findsNothing);
  });

  testWidgets('text scaling is disabled inside the paper', (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(host(orderPaper()));
    final mq = tester.widget<MediaQuery>(find.descendant(
        of: find.byType(ReceiptPaper), matching: find.byType(MediaQuery)).first);
    expect(mq.data.textScaler, TextScaler.noScaling);
  });

  testWidgets('load manifest declares only black and white and totals the load',
      (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(ReceiptPaper(
      docType: ReceiptDocType.load,
      l10n: l10nAr,
      config: sampleConfig,
      loadData: sampleLoad(),
    )));
    await expectOnlyInk(tester);
    expect(find.text(l10nAr.loadReceipt), findsOneWidget);
    expect(find.text('الصنف', findRichText: true), findsOneWidget);
    expect(find.text(l10nAr.totalLoaded, findRichText: true), findsOneWidget);
    expect(find.text('\u206664\u2069', findRichText: true), findsOneWidget); // 40 + 24
  });

  testWidgets('return document declares only black and white and totals columns',
      (tester) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(ReceiptPaper(
      docType: ReceiptDocType.returns,
      l10n: l10nAr,
      config: sampleConfig,
      returnData: sampleReturn(),
    )));
    await expectOnlyInk(tester);
    expect(find.text(l10nAr.shiftCloseReceipt), findsOneWidget);
    expect(find.text('الصنف', findRichText: true), findsOneWidget);
    expect(find.text(l10nAr.loaded, findRichText: true), findsOneWidget);
    expect(find.text(l10nAr.sold, findRichText: true), findsOneWidget);
    expect(find.text(l10nAr.returned, findRichText: true), findsOneWidget);
    expect(find.text('\u206657\u2069', findRichText: true), findsOneWidget); // sold 33 + 24
    expect(find.text('\u20667\u2069', findRichText: true), findsNWidgets(2)); // row + total returned
  });
}
