// test/widget/receipts/fixtures.dart
import 'package:flutter/material.dart';
import 'package:tawzii/core/l10n/app_localizations_ar.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';
import 'package:tawzii/features/receipts/widgets/receipt_paper.dart';

final l10nAr = AppLocalizationsAr();

Map<String, dynamic> _line(String name, int upp, int qty, int? pieces, num price, num total) => {
      'quantity': qty,
      'pieces_quantity': pieces,
      'unit_price': price,
      'line_total': total,
      'products': {'name': name, 'units_per_package': upp},
    };

/// The four-line sample order from the column proof: packages only,
/// mixed, pieces only, packages only. Subtotal 13 230, discount 230,
/// total 13 000, partially paid 5 000.
Map<String, dynamic> sampleOrder({String status = 'delivered'}) => {
      'id': '3f9a2c1b-7e5d-4a10-9b2f-000000000000',
      'status': status,
      'created_at': '2026-09-02T11:05:00Z',
      'subtotal': 13230,
      'tax_amount': 0,
      'discount': 230,
      'discount_status': 'approved',
      'total': 13000,
      'payment_status': 'partial',
      'paid_amount': 5000,
      'stores': {'name': 'متجر النخيل', 'address': 'شارع العربي بن مهيدي'},
      'users': {'name': 'كريم بوعلام'},
      'order_lines': [
        _line('مياه نقي 0.5 لتر', 12, 6, null, 240, 1440),
        _line('بيبسي 330 مل', 24, 4, 6, 480, 2040),
        _line('شيبس تشيبسي وسط', 20, 0, 10, 300, 150),
        _line('زيت إليو 5 لتر', 4, 3, null, 3200, 9600),
      ],
    };

Map<String, dynamic> sampleLoad() => {
      'driver_name': 'كريم بوعلام',
      'loaded_by_name': 'أحمد',
      'opened_at': '2026-09-02T07:30:00Z',
      'items': [
        {'product_name': 'مياه نقي 0.5 لتر', 'quantity_loaded': 40},
        {'product_name': 'بيبسي 330 مل', 'quantity_loaded': 24},
      ],
    };

Map<String, dynamic> sampleReturn() => {
      'driver_name': 'كريم بوعلام',
      'closed_at': '2026-09-02T18:10:00Z',
      'items': [
        {'product_name': 'مياه نقي 0.5 لتر', 'quantity_loaded': 40, 'quantity_sold': 33, 'quantity_returned': 7},
        {'product_name': 'بيبسي 330 مل', 'quantity_loaded': 24, 'quantity_sold': 24, 'quantity_returned': 0},
      ],
    };

const sampleConfig = ReceiptConfig(phone: '0770 12 34 56', footer: null);

/// Pumps [paper] at natural size on a tall test surface so the whole
/// receipt lays out (the default 800×600 surface would clip it).
Widget host(Widget paper) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Align(alignment: Alignment.topCenter, child: paper),
        ),
      ),
    );

ReceiptPaper orderPaper({Map<String, dynamic>? order, int? packageBalance = 21}) =>
    ReceiptPaper(
      docType: ReceiptDocType.order,
      l10n: l10nAr,
      config: sampleConfig,
      order: order ?? sampleOrder(),
      packageBalance: packageBalance,
    );
