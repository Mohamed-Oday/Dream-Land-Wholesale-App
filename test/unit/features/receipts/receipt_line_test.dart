import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/models/receipt_line.dart';

Map<String, dynamic> _line({
  String name = 'بيبسي 330 مل',
  int quantity = 0,
  int? pieces,
  int? unitsPerPackage = 24,
  num unitPrice = 480,
  num? lineTotal,
}) {
  return {
    'quantity': quantity,
    'pieces_quantity': pieces,
    'unit_price': unitPrice,
    'line_total': lineTotal,
    'products': {
      'name': name,
      'units_per_package': unitsPerPackage,
    },
  };
}

void main() {
  const iso = '⁦';
  const pdi = '⁩';
  const fs = ' '; // figure space used by Money.format

  test('ltr wraps the value in isolate marks', () {
    expect(ltr(1440), '${iso}1440$pdi');
  });

  group('mode', () {
    test('packages only', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 6, pieces: null));
      expect(l.mode, ReceiptLineMode.packagesOnly);
    });
    test('mixed', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6));
      expect(l.mode, ReceiptLineMode.mixed);
    });
    test('pieces only', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 0, pieces: 10));
      expect(l.mode, ReceiptLineMode.piecesOnly);
    });
    test('zero of both still counts as packages only so the row prints', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 0, pieces: 0));
      expect(l.mode, ReceiptLineMode.packagesOnly);
      expect(l.qtyMain, '${iso}0$pdi ع');
    });
  });

  group('prices', () {
    test('piece price is package price over units per package', () {
      final l = ReceiptLine.fromOrderLine(_line(unitPrice: 480, unitsPerPackage: 24));
      expect(l.piecePrice, 20);
    });
    test('missing units per package makes piece price equal package price', () {
      final l = ReceiptLine.fromOrderLine(_line(unitsPerPackage: null));
      expect(l.piecePrice, 480);
      expect(l.perPackageLabel, isNull);
    });
    test('line_total is used when present', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6, lineTotal: 2040));
      expect(l.lineTotal, 2040);
    });
    test('line_total is derived when missing or zero', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6, lineTotal: 0));
      expect(l.lineTotal, 4 * 480 + 6 * 20);
    });
  });

  group('cell text', () {
    test('packages only', () {
      final l = ReceiptLine.fromOrderLine(
          _line(name: 'مياه نقي 0.5 لتر', quantity: 6, unitsPerPackage: 12, unitPrice: 240));
      expect(l.perPackageLabel, '${iso}12$pdi ق/ع');
      expect(l.qtyMain, '${iso}6$pdi ع');
      expect(l.qtySub, isNull);
      expect(l.priceMain, '${iso}240$pdi');
      expect(l.priceSub, isNull);
      expect(l.totalText, '${iso}1${fs}440$pdi');
    });
    test('mixed', () {
      final l = ReceiptLine.fromOrderLine(_line(quantity: 4, pieces: 6));
      expect(l.qtyMain, '${iso}4$pdi ع');
      expect(l.qtySub, '+${iso}6$pdi ق');
      expect(l.priceMain, '${iso}480$pdi');
      expect(l.priceSub, '${iso}20$pdi/ق');
      expect(l.totalText, '${iso}2${fs}040$pdi');
    });
    test('pieces only', () {
      final l = ReceiptLine.fromOrderLine(
          _line(quantity: 0, pieces: 10, unitsPerPackage: 20, unitPrice: 300));
      expect(l.qtyMain, '${iso}10$pdi ق');
      expect(l.qtySub, isNull);
      expect(l.priceMain, '${iso}15$pdi');
      expect(l.priceSub, 'للقطعة');
      expect(l.totalText, '${iso}150$pdi');
    });
    test('piece price rounds to whole dinars in text', () {
      // 500 / 3 = 166.67 → "167"
      final l = ReceiptLine.fromOrderLine(
          _line(quantity: 0, pieces: 1, unitsPerPackage: 3, unitPrice: 500));
      expect(l.priceMain, '${iso}167$pdi');
    });
  });
}
