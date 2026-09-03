/// Represents a line item in an order with pricing and package calculations.
///
/// A line can carry BOTH whole packages ([quantity]) and loose pieces
/// ([piecesQuantity]) at the same time — the product decides whether pieces
/// are allowed ([allowPiece]). Package price = unitPrice × unitsPerPackage;
/// a single loose piece is priced as packagePrice ÷ unitsPerPackage.
class LineItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int? unitsPerPackage;
  final bool hasReturnablePackaging;

  /// Stock available when this line was built, in PACKAGES. Fractional because
  /// loose-piece sales consume part of a package.
  final double stockOnHand;

  /// Whole packages on this line (may be 0 when only pieces are sold).
  int quantity;

  /// Product allows loose-piece sales (capability copied from the product).
  final bool allowPiece;

  /// Loose pieces on this line (0 when none).
  int piecesQuantity;

  LineItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.unitsPerPackage,
    this.hasReturnablePackaging = false,
    this.stockOnHand = 0.0,
    this.allowPiece = false,
    this.piecesQuantity = 0,
  });

  /// Units in one package — never below 1 so piece math can't divide by zero.
  int get unitsPerPackageOrOne =>
      (unitsPerPackage == null || unitsPerPackage! < 1) ? 1 : unitsPerPackage!;

  /// Price per package (or per unit when there is no package size).
  double get packagePrice => unitPrice * unitsPerPackageOrOne;

  /// Price of a single loose piece = package price ÷ units per package.
  double get piecePrice => packagePrice / unitsPerPackageOrOne;

  /// This line includes a loose-piece component.
  bool get soldByPiece => piecesQuantity > 0;

  /// Additive total: whole packages + loose pieces.
  double get lineTotal =>
      packagePrice * quantity + piecePrice * piecesQuantity;

  /// Total individual units on this line (packages × units + loose pieces).
  int get totalPieces => quantity * unitsPerPackageOrOne + piecesQuantity;
}
