import 'package:tawzii/features/orders/models/line_item.dart';

/// Calculate subtotal from a list of line items.
double calculateSubtotal(List<LineItem> items) =>
    items.fold(0, (sum, item) => sum + item.lineTotal);

/// Calculate tax amount from subtotal and tax percentage.
double calculateTax(double subtotal, double taxPercentage) =>
    subtotal * taxPercentage / 100;

/// Calculate order total: subtotal + tax - discount.
double calculateTotal(double subtotal, double taxAmount, double discount) =>
    subtotal + taxAmount - discount;

/// Parse a discount string into a double. Returns 0 for empty or invalid input.
double parseDiscount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return double.tryParse(trimmed) ?? 0;
}
