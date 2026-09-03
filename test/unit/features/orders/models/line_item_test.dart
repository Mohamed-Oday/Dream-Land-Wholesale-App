import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/orders/models/line_item.dart';

void main() {
  LineItem _makeItem({
    double unitPrice = 50.0,
    int? unitsPerPackage,
    int quantity = 1,
    int piecesQuantity = 0,
    bool allowPiece = false,
  }) {
    return LineItem(
      productId: 'p1',
      productName: 'خبز',
      unitPrice: unitPrice,
      quantity: quantity,
      unitsPerPackage: unitsPerPackage,
      piecesQuantity: piecesQuantity,
      allowPiece: allowPiece,
    );
  }

  group('packagePrice', () {
    test('with unitsPerPackage multiplies unit price by package size', () {
      final item = _makeItem(unitPrice: 50.0, unitsPerPackage: 10);
      expect(item.packagePrice, closeTo(500.0, 0.001));
    });

    test('without unitsPerPackage returns unit price directly', () {
      final item = _makeItem(unitPrice: 50.0);
      expect(item.packagePrice, closeTo(50.0, 0.001));
    });
  });

  group('lineTotal', () {
    test('equals packagePrice times quantity', () {
      final item = _makeItem(unitPrice: 50.0, unitsPerPackage: 10, quantity: 3);
      expect(item.lineTotal, closeTo(1500.0, 0.001));
    });

    test('with single quantity equals packagePrice', () {
      final item = _makeItem(unitPrice: 100.0, quantity: 1);
      expect(item.lineTotal, closeTo(100.0, 0.001));
    });

    test('updates when quantity changes', () {
      final item = _makeItem(unitPrice: 50.0, unitsPerPackage: 10, quantity: 1);
      expect(item.lineTotal, closeTo(500.0, 0.001));
      item.quantity = 5;
      expect(item.lineTotal, closeTo(2500.0, 0.001));
    });
  });

  group('totalPieces', () {
    test('with unitsPerPackage returns quantity times package size', () {
      final item = _makeItem(unitsPerPackage: 10, quantity: 3);
      expect(item.totalPieces, equals(30));
    });

    test('without unitsPerPackage counts each package as one unit', () {
      final item = _makeItem(quantity: 3);
      expect(item.totalPieces, equals(3));
    });

    test('adds loose pieces to package units', () {
      final item =
          _makeItem(unitsPerPackage: 10, quantity: 2, piecesQuantity: 3);
      expect(item.totalPieces, equals(23));
    });
  });

  group('piece sales', () {
    test('piece price is package price divided by units per package', () {
      final item = _makeItem(unitPrice: 50.0, unitsPerPackage: 10);
      expect(item.piecePrice, closeTo(50.0, 0.001));
    });

    test('lineTotal is additive: packages plus loose pieces', () {
      final item = _makeItem(
        unitPrice: 50.0,
        unitsPerPackage: 10,
        quantity: 2,
        piecesQuantity: 3,
        allowPiece: true,
      );
      // packagePrice 500 × 2 packages + piecePrice 50 × 3 pieces = 1150
      expect(item.lineTotal, closeTo(1150.0, 0.001));
    });

    test('piece-only line (zero packages) totals piece price times pieces', () {
      final item = _makeItem(
        unitPrice: 50.0,
        unitsPerPackage: 10,
        quantity: 0,
        piecesQuantity: 4,
        allowPiece: true,
      );
      expect(item.lineTotal, closeTo(200.0, 0.001));
      expect(item.soldByPiece, isTrue);
    });
  });

  group('edge cases', () {
    test('zero quantity produces zero lineTotal', () {
      final item = _makeItem(unitPrice: 100.0, quantity: 0);
      expect(item.lineTotal, closeTo(0.0, 0.001));
    });
  });
}
