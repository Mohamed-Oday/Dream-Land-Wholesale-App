import 'package:flutter_test/flutter_test.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';

void main() {
  test('empty has no phone and no footer', () {
    expect(ReceiptConfig.empty.phone, isNull);
    expect(ReceiptConfig.empty.footer, isNull);
  });

  test('fromRows picks the two receipt keys and ignores others', () {
    final c = ReceiptConfig.fromRows([
      {'key': 'receipt.phone', 'value': '0770 12 34 56'},
      {'key': 'receipt.footer', 'value': 'شكراً لثقتكم'},
      {'key': 'something.else', 'value': 'x'},
    ]);
    expect(c.phone, '0770 12 34 56');
    expect(c.footer, 'شكراً لثقتكم');
  });

  test('blank values are treated as unset', () {
    final c = ReceiptConfig.fromRows([
      {'key': 'receipt.phone', 'value': '   '},
    ]);
    expect(c.phone, isNull);
  });

  test('values are trimmed', () {
    final c = ReceiptConfig.fromRows([
      {'key': 'receipt.footer', 'value': ' مرحباً '},
    ]);
    expect(c.footer, 'مرحباً');
  });
}
