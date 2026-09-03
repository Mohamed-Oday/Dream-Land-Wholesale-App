/// Helpers for stock held as FRACTIONAL PACKAGES.
///
/// `products.stock_on_hand` counts packages, not pieces. Selling loose pieces
/// removes a fraction of a package — 3 pieces out of a 15-piece package leaves
/// 0.8 — so stock must never be truncated with `toInt()`; that would report
/// 0.8 packages (12 sellable pieces) as "out of stock".
///
/// Everything here converts through piece space and rounds, mirroring the
/// database side (`apply_stock_piece_delta`), so display and caps agree with
/// what the server will actually deduct.
library;

/// Units in one package — never below 1, so piece math can't divide by zero.
int unitsPerPackageOrOne(int? unitsPerPackage) =>
    (unitsPerPackage == null || unitsPerPackage < 1) ? 1 : unitsPerPackage;

/// Reads `stock_on_hand` off a product map without truncating the fraction.
double stockOf(Map<String, dynamic> product) =>
    (product['stock_on_hand'] as num?)?.toDouble() ?? 0.0;

/// Total sellable pieces in [stock] packages.
int stockAsPieces(double stock, int? unitsPerPackage) =>
    (stock * unitsPerPackageOrOne(unitsPerPackage)).round();

/// Whole packages available — the cap for the package stepper.
int wholePackages(double stock) => stock <= 0 ? 0 : stock.floor();

/// Loose pieces left over once [packages] whole packages are taken out.
/// This is the cap for the pieces stepper.
int loosePiecesAfter(double stock, int packages, int? unitsPerPackage) {
  final pieces = stockAsPieces(stock, unitsPerPackage) -
      packages * unitsPerPackageOrOne(unitsPerPackage);
  return pieces < 0 ? 0 : pieces;
}

/// True when nothing sellable remains. Uses piece resolution so a residue
/// smaller than one piece does not read as "still in stock".
bool isOutOfStock(double stock, int? unitsPerPackage) =>
    stockAsPieces(stock, unitsPerPackage) <= 0;

/// Stock as a short number: 3 -> "3", 2.8 -> "2.8", 1/3 -> "0.33".
/// Whole package counts keep no decimal point.
String formatStockNumber(double stock) {
  if (stock == stock.roundToDouble()) return stock.toStringAsFixed(0);
  return stock
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Arabic stock label: "٣ عبوة + ٧ قطعة", "٣ عبوة", "٧ قطعة", or "٠".
///
/// [toArabicDigits] lets callers reuse the screen's own digit formatter;
/// without it the label falls back to Western digits.
String formatPackageStock(
  double stock,
  int? unitsPerPackage, {
  String Function(int)? toArabicDigits,
}) {
  String d(int n) => toArabicDigits?.call(n) ?? '$n';

  // Oversold stock has no meaningful package/piece split — show it plainly.
  if (stock < 0) {
    final pieces = stockAsPieces(stock, unitsPerPackage);
    return '${d(pieces)} قطعة';
  }

  final upp = unitsPerPackageOrOne(unitsPerPackage);
  final totalPieces = stockAsPieces(stock, unitsPerPackage);
  final packages = totalPieces ~/ upp;
  final pieces = totalPieces % upp;

  final parts = <String>[];
  if (packages > 0) parts.add('${d(packages)} عبوة');
  if (pieces > 0) parts.add('${d(pieces)} قطعة');
  if (parts.isEmpty) return d(0);
  return parts.join(' + ');
}
