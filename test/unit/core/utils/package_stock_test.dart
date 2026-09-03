import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/core/utils/package_stock.dart';

void main() {
  group('stock is counted in packages', () {
    test('selling one whole package from a stock of one leaves zero', () {
      // The reported bug: 1 package in stock, sell 1 package of a 15-piece
      // product. Stock must land on 0 — not -14.
      const stock = 1.0;
      const upp = 15;
      final remainingPieces = stockAsPieces(stock, upp) - 1 * upp;
      expect(remainingPieces, equals(0));
      expect(isOutOfStock(remainingPieces / upp, upp), isTrue);
    });

    test('a full package is worth unitsPerPackage pieces', () {
      expect(stockAsPieces(1.0, 15), equals(15));
      expect(stockAsPieces(3.0, 15), equals(45));
    });

    test('products without a package size count one piece per package', () {
      expect(stockAsPieces(4.0, null), equals(4));
      expect(stockAsPieces(4.0, 0), equals(4));
    });
  });

  group('fractional packages', () {
    test('selling 3 pieces of a 15-piece package leaves 0.8 packages', () {
      final remaining = (stockAsPieces(1.0, 15) - 3) / 15;
      expect(remaining, closeTo(0.8, 1e-9));
      expect(stockAsPieces(remaining, 15), equals(12));
    });

    test('0.8 packages is not out of stock', () {
      expect(isOutOfStock(0.8, 15), isFalse);
    });

    test('selling pieces one at a time lands exactly on zero', () {
      var stock = 1.0;
      for (var i = 0; i < 15; i++) {
        stock = (stockAsPieces(stock, 15) - 1) / 15;
      }
      expect(stockAsPieces(stock, 15), equals(0));
      expect(isOutOfStock(stock, 15), isTrue);
    });
  });

  group('cart caps', () {
    test('whole packages available floors the fraction', () {
      expect(wholePackages(2.8), equals(2));
      expect(wholePackages(0.8), equals(0));
      expect(wholePackages(3.0), equals(3));
    });

    test('negative stock offers nothing', () {
      expect(wholePackages(-14.0), equals(0));
      expect(isOutOfStock(-14.0, 15), isTrue);
    });

    test('piece cap is what is left after the chosen whole packages', () {
      // 2.5 packages of a 10-piece product = 25 pieces.
      expect(loosePiecesAfter(2.5, 0, 10), equals(25));
      expect(loosePiecesAfter(2.5, 2, 10), equals(5));
      expect(loosePiecesAfter(2.5, 2, 10), equals(5));
    });

    test('piece cap never goes negative when packages exceed stock', () {
      expect(loosePiecesAfter(1.0, 5, 10), equals(0));
    });
  });

  group('display', () {
    test('splits a fraction into packages and pieces', () {
      expect(formatPackageStock(2.8, 10), equals('2 عبوة + 8 قطعة'));
    });

    test('omits the empty half of the label', () {
      expect(formatPackageStock(3.0, 10), equals('3 عبوة'));
      expect(formatPackageStock(0.8, 10), equals('8 قطعة'));
    });

    test('zero stock reads as zero', () {
      expect(formatPackageStock(0.0, 10), equals('0'));
    });

    test('oversold stock is shown in pieces rather than a bogus split', () {
      expect(formatPackageStock(-14.0, 15), equals('-210 قطعة'));
    });

    test('uses the supplied digit formatter', () {
      expect(
        formatPackageStock(2.8, 10, toArabicDigits: (n) => '<$n>'),
        equals('<2> عبوة + <8> قطعة'),
      );
    });
  });
}
