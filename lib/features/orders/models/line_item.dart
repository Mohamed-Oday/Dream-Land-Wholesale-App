/// Represents a line item in an order with pricing and package calculations.
class LineItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int? unitsPerPackage;
  final bool hasReturnablePackaging;
  final int stockOnHand;
  int quantity;

  LineItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.unitsPerPackage,
    this.hasReturnablePackaging = false,
    this.stockOnHand = 0,
  });

  /// Price per package (or per unit if no package).
  double get packagePrice => unitPrice * (unitsPerPackage ?? 1);

  double get lineTotal => packagePrice * quantity;

  /// Total individual pieces (quantity × unitsPerPackage).
  int? get totalPieces =>
      unitsPerPackage != null ? quantity * unitsPerPackage! : null;
}
