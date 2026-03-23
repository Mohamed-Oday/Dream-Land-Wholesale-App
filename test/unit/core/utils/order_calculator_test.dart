import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/core/utils/order_calculator.dart';
import 'package:tawzii/features/orders/models/line_item.dart';

void main() {
  LineItem _makeItem({double unitPrice = 100.0, int quantity = 1}) {
    return LineItem(
      productId: 'p1',
      productName: 'test',
      unitPrice: unitPrice,
      quantity: quantity,
    );
  }

  group('calculateSubtotal', () {
    test('sums multiple items', () {
      final items = [
        _makeItem(unitPrice: 100.0, quantity: 2),
        _makeItem(unitPrice: 50.0, quantity: 3),
      ];
      expect(calculateSubtotal(items), closeTo(350.0, 0.001));
    });

    test('empty list returns 0', () {
      expect(calculateSubtotal([]), closeTo(0.0, 0.001));
    });

    test('single item returns its lineTotal', () {
      final items = [_makeItem(unitPrice: 250.0, quantity: 1)];
      expect(calculateSubtotal(items), closeTo(250.0, 0.001));
    });
  });

  group('calculateTax', () {
    test('zero percent returns 0', () {
      expect(calculateTax(1000.0, 0), closeTo(0.0, 0.001));
    });

    test('19 percent on 1000 returns 190', () {
      expect(calculateTax(1000.0, 19), closeTo(190.0, 0.001));
    });

    test('fractional percentage', () {
      expect(calculateTax(200.0, 5.5), closeTo(11.0, 0.001));
    });
  });

  group('calculateTotal', () {
    test('subtotal plus tax minus discount', () {
      expect(calculateTotal(1000.0, 190.0, 50.0), closeTo(1140.0, 0.001));
    });

    test('zero discount returns subtotal plus tax', () {
      expect(calculateTotal(500.0, 0.0, 0.0), closeTo(500.0, 0.001));
    });

    test('discount equal to subtotal returns only tax', () {
      expect(calculateTotal(500.0, 50.0, 500.0), closeTo(50.0, 0.001));
    });
  });

  group('parseDiscount', () {
    test('valid number returns parsed value', () {
      expect(parseDiscount('100.50'), closeTo(100.50, 0.001));
    });

    test('empty string returns 0', () {
      expect(parseDiscount(''), closeTo(0.0, 0.001));
    });

    test('whitespace only returns 0', () {
      expect(parseDiscount('   '), closeTo(0.0, 0.001));
    });

    test('non-numeric returns 0', () {
      expect(parseDiscount('abc'), closeTo(0.0, 0.001));
    });
  });
}
