import 'package:tawzii/core/ui/money_text.dart';

/// Wraps [v] in U+2066 (LRI) … U+2069 (PDI) so a Latin number keeps its
/// own direction inside Arabic text. Without it the `+`/`−` of a quantity
/// or discount jumps to the wrong end of the run.
String ltr(Object v) => '⁦$v⁩';

/// Which kinds of quantity an order line carries.
enum ReceiptLineMode { packagesOnly, mixed, piecesOnly }

/// One order line, reduced to the strings the receipt grid prints.
///
/// Input is the raw `order_lines` row joined with `products`, exactly as
/// `OrderRepository.getById` returns it. `unit_price` is the **package**
/// price; a loose piece costs `unit_price ÷ units_per_package`.
class ReceiptLine {
  final String name;
  final int packages;
  final int pieces;
  final int? unitsPerPackage;
  final double packagePrice;
  final double lineTotal;

  const ReceiptLine({
    required this.name,
    required this.packages,
    required this.pieces,
    required this.unitsPerPackage,
    required this.packagePrice,
    required this.lineTotal,
  });

  factory ReceiptLine.fromOrderLine(Map<String, dynamic> line) {
    final product = line['products'] as Map<String, dynamic>?;
    final packages = (line['quantity'] as num?)?.toInt() ?? 0;
    final pieces = (line['pieces_quantity'] as num?)?.toInt() ?? 0;
    final upp = (product?['units_per_package'] as num?)?.toInt();
    final packagePrice = ((line['unit_price'] as num?) ?? 0).toDouble();
    final storedTotal = ((line['line_total'] as num?) ?? 0).toDouble();
    final piecePrice = packagePrice / _unitsOrOne(upp);
    return ReceiptLine(
      name: (product?['name'] ?? '').toString(),
      packages: packages,
      pieces: pieces,
      unitsPerPackage: upp,
      packagePrice: packagePrice,
      lineTotal: storedTotal > 0
          ? storedTotal
          : packagePrice * packages + piecePrice * pieces,
    );
  }

  static int _unitsOrOne(int? upp) => (upp == null || upp < 1) ? 1 : upp;

  double get piecePrice => packagePrice / _unitsOrOne(unitsPerPackage);

  ReceiptLineMode get mode {
    if (pieces > 0 && packages > 0) return ReceiptLineMode.mixed;
    if (pieces > 0) return ReceiptLineMode.piecesOnly;
    return ReceiptLineMode.packagesOnly;
  }

  /// `12 ق/ع` — pieces per package, or null when the product has no size.
  String? get perPackageLabel =>
      unitsPerPackage == null ? null : '${ltr(unitsPerPackage!)} ق/ع';

  String get qtyMain => switch (mode) {
        ReceiptLineMode.packagesOnly => '${ltr(packages)} ع',
        ReceiptLineMode.mixed => '${ltr(packages)} ع',
        ReceiptLineMode.piecesOnly => '${ltr(pieces)} ق',
      };

  String? get qtySub =>
      mode == ReceiptLineMode.mixed ? '+${ltr(pieces)} ق' : null;

  String get priceMain => switch (mode) {
        ReceiptLineMode.piecesOnly => ltr(Money.format(piecePrice)),
        _ => ltr(Money.format(packagePrice)),
      };

  String? get priceSub => switch (mode) {
        ReceiptLineMode.packagesOnly => null,
        ReceiptLineMode.mixed => '${ltr(Money.format(piecePrice))}/ق',
        ReceiptLineMode.piecesOnly => 'للقطعة',
      };

  String get totalText => ltr(Money.format(lineTotal));
}
