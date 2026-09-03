// lib/features/receipts/widgets/receipt_paper.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';
import 'package:tawzii/features/receipts/models/receipt_line.dart';
import 'package:tawzii/features/receipts/widgets/thermal.dart';
import 'package:tawzii/features/receipts/widgets/thermal_grid.dart';

/// The three document types the receipt paper can render.
enum ReceiptDocType { order, load, returns }

/// The thermal paper. Fixed at 288 logical px so a capture at pixelRatio 2.0
/// is exactly 576 dots — the printer's width — with no resampling.
///
/// Every colour on it is [ThermalInk.black] or [ThermalInk.paper]; see
/// `test/widget/receipts/receipt_palette_test.dart`.
class ReceiptPaper extends StatelessWidget {
  static const double width = 288;

  final ReceiptDocType docType;
  final AppLocalizations l10n;
  final ReceiptConfig config;
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? loadData;
  final Map<String, dynamic>? returnData;
  final int? packageBalance;

  const ReceiptPaper({
    super.key,
    required this.docType,
    required this.l10n,
    this.config = ReceiptConfig.empty,
    this.order,
    this.loadData,
    this.returnData,
    this.packageBalance,
  });

  static String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  static String _amt(num v) => ltr(Money.format(v));

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: width,
        color: ThermalInk.paper,
        padding: EdgeInsets.fromLTRB(
            Dots.px(20), Dots.px(26), Dots.px(20), Dots.px(30)),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: kThermalFont,
            fontSize: Dots.px(22),
            height: 1.5,
            color: ThermalInk.black,
            fontFeatures: const [
              FontFeature.tabularFigures(),
              FontFeature.liningFigures(),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (docType) {
              ReceiptDocType.order => _orderBody(),
              ReceiptDocType.load => _loadBody(),
              ReceiptDocType.returns => _returnBody(),
            },
          ),
        ),
      ),
    );
  }

  // --- shared pieces ---

  List<Widget> _masthead(String docTitle, {String? reference}) {
    return [
      Text(
        l10n.appTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: Dots.px(34), fontWeight: FontWeight.w700, height: 1.2),
      ),
      if (config.phone != null)
        Text(
          'توزيع الجملة — ${ltr(config.phone!)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: Dots.px(19)),
        ),
      const ThermalRule(),
      Text(
        docTitle,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: Dots.px(24), fontWeight: FontWeight.w600),
      ),
      if (reference != null)
        Text(
          reference,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: Dots.px(28), fontWeight: FontWeight.w700, height: 1.2),
        ),
      const ThermalRule(kind: ThermalRuleKind.hair),
    ];
  }

  List<Widget> _footer() {
    final lines = <String>[
      config.footer ?? 'شكراً لثقتكم',
      if (config.phone != null) 'للاستفسار: ${ltr(config.phone!)}',
    ];
    return [
      const ThermalRule(),
      Text(
        lines.join('\n'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: Dots.px(19), height: 1.45),
      ),
    ];
  }

  Widget _meta(String label, String value,
          {double valueSizeDots = 19, FontWeight valueWeight = FontWeight.w600}) =>
      ThermalKv(
        label: label,
        value: value,
        sizeDots: 19,
        valueSizeDots: valueSizeDots,
        valueWeight: valueWeight,
      );

  static TextSpan _unit(String letter) => TextSpan(
        text: ' $letter',
        style: TextStyle(fontSize: Dots.px(17), fontWeight: FontWeight.w500),
      );

  /// `6 ع` / `+6 ق` / `10 ق` — number at cell size, unit letter at 17 dots.
  static List<InlineSpan> _qtySpans(String s) {
    final space = s.lastIndexOf(' ');
    if (space < 0) return [TextSpan(text: s)];
    return [
      TextSpan(text: s.substring(0, space)),
      _unit(s.substring(space + 1)),
    ];
  }

  // --- order receipt ---

  static String _orderRef(Map<String, dynamic> o) {
    final id = (o['id'] ?? '').toString();
    return ltr('#${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}');
  }

  List<Widget> _orderBody() {
    final o = order!;
    final store = o['stores'] as Map<String, dynamic>?;
    final driver = o['users'] as Map<String, dynamic>?;
    final storeName = (store?['name'] ?? '').toString();
    final storeAddress = (store?['address'] ?? '').toString();
    final driverName = (driver?['name'] ?? '').toString();
    final status = o['status'] as String? ?? 'created';
    final subtotal = ((o['subtotal'] as num?) ?? 0).toDouble();
    final taxAmount = ((o['tax_amount'] as num?) ?? 0).toDouble();
    final discount = ((o['discount'] as num?) ?? 0).toDouble();
    final discountStatus = o['discount_status'] as String? ?? 'none';
    final total = ((o['total'] as num?) ?? 0).toDouble();
    final paymentStatus = o['payment_status'] as String? ?? 'unpaid';
    final paidAmount = ((o['paid_amount'] as num?) ?? 0).toDouble();
    final date = _fmtDate(o['created_at'] as String?);
    final lines = (o['order_lines'] as List<dynamic>? ?? [])
        .map((l) => ReceiptLine.fromOrderLine(l as Map<String, dynamic>))
        .toList();
    final showDiscount = discount > 0 &&
        (discountStatus == 'approved' || discountStatus == 'pending');
    final cancelled = status == 'cancelled';

    return [
      ..._masthead('فاتورة تسليم', reference: _orderRef(o)),
      if (cancelled)
        Padding(
          padding: EdgeInsets.only(bottom: Dots.px(8)),
          child: Text(
            l10n.statusCancelled,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: Dots.px(30), fontWeight: FontWeight.w700),
          ),
        ),
      if (date.isNotEmpty) _meta(l10n.orderDate, ltr(date)),
      if (storeName.isNotEmpty)
        _meta('المتجر', storeName,
            valueSizeDots: 23, valueWeight: FontWeight.w700),
      if (storeAddress.isNotEmpty)
        _meta(l10n.address, storeAddress, valueWeight: FontWeight.w500),
      if (driverName.isNotEmpty) _meta(l10n.driver, driverName),
      SizedBox(height: Dots.px(14)),
      ThermalGrid(
        columnDots: const [236, 84, 96, 120],
        headers: const ['الصنف', 'الكمية', 'السعر', 'الإجمالي'],
        aligns: const [
          TextAlign.start,
          TextAlign.center,
          TextAlign.center,
          TextAlign.end,
        ],
        rows: [
          for (final line in lines)
            [
              ThermalCell.text(line.name,
                  sub: line.perPackageLabel,
                  mainSizeDots: 23,
                  mainWeight: FontWeight.w600),
              ThermalCell(
                main: _qtySpans(line.qtyMain),
                sub: line.qtySub == null ? null : _qtySpans(line.qtySub!),
                align: TextAlign.center,
              ),
              ThermalCell.text(line.priceMain,
                  sub: line.priceSub, align: TextAlign.center),
              ThermalCell.text(line.totalText,
                  align: TextAlign.end, mainWeight: FontWeight.w700),
            ],
        ],
        footer: [
          (label: l10n.subtotal, value: _amt(subtotal)),
          if (taxAmount > 0) (label: l10n.tax, value: _amt(taxAmount)),
          if (showDiscount)
            (label: l10n.discount, value: ltr('−${Money.format(discount)}')),
        ],
      ),
      TotalBar(label: 'الإجمالي', value: '${_amt(total)} ${l10n.currencyUnit}'),
      if (!cancelled) ...[
        Stamp(
          label: 'حالة الدفع',
          value: switch (paymentStatus) {
            'paid' => 'مدفوع',
            'partial' => 'مدفوع جزئياً',
            _ => 'غير مدفوع',
          },
        ),
        if (paymentStatus == 'partial') ...[
          ThermalKv(label: 'المدفوع', value: _amt(paidAmount)),
          DueBox(
              label: 'المتبقي',
              value: _amt((total - paidAmount).clamp(0.0, total))),
        ],
      ],
      if (packageBalance != null) ...[
        const ThermalRule(kind: ThermalRuleKind.hair),
        _meta('العبوات المتبقية لدى المتجر',
            '${ltr(packageBalance!)} ${l10n.packageUnit}'),
      ],
      SizedBox(height: Dots.px(22)),
      Row(
        children: [
          const Expanded(child: SignatureLine(label: 'توقيع المستلم')),
          SizedBox(width: Dots.px(22)),
          const Expanded(child: SignatureLine(label: 'توقيع السائق')),
        ],
      ),
      ..._footer(),
    ];
  }

  // --- load manifest ---

  List<Widget> _loadBody() {
    final d = loadData!;
    final driverName = d['driver_name'] as String? ?? '';
    final loadedByName = d['loaded_by_name'] as String? ?? '';
    final date = _fmtDate(d['opened_at'] as String?);
    final items = (d['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final totalQty = items.fold<int>(
        0, (sum, i) => sum + ((i['quantity_loaded'] as num?)?.toInt() ?? 0));

    return [
      ..._masthead(l10n.loadReceipt),
      if (driverName.isNotEmpty)
        _meta(l10n.driver, driverName,
            valueSizeDots: 23, valueWeight: FontWeight.w700),
      if (loadedByName.isNotEmpty) _meta(l10n.loadedBy, loadedByName),
      if (date.isNotEmpty) _meta(l10n.orderDate, ltr(date)),
      SizedBox(height: Dots.px(14)),
      ThermalGrid(
        columnDots: const [416, 120],
        headers: ['الصنف', 'الكمية'],
        aligns: const [TextAlign.start, TextAlign.end],
        rows: [
          for (final m in items)
            [
              ThermalCell.text(m['product_name'] as String? ?? '',
                  mainSizeDots: 23, mainWeight: FontWeight.w600),
              ThermalCell.text(
                  ltr((m['quantity_loaded'] as num?)?.toInt() ?? 0),
                  align: TextAlign.end,
                  mainWeight: FontWeight.w700),
            ],
        ],
        footer: [(label: l10n.totalLoaded, value: ltr(totalQty))],
      ),
      ..._footer(),
    ];
  }

  // --- return / shift close ---

  List<Widget> _returnBody() {
    final d = returnData!;
    final driverName = d['driver_name'] as String? ?? '';
    final date = _fmtDate(d['closed_at'] as String?);
    final items = (d['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    int sum(String key) => items.fold<int>(
        0, (s, m) => s + ((m[key] as num?)?.toInt() ?? 0));
    final totalLoaded = sum('quantity_loaded');
    final totalSold = sum('quantity_sold');
    final totalReturned = sum('quantity_returned');

    List<Widget> row(String name, int a, int b, int c, {bool bold = false}) {
      final w = bold ? FontWeight.w700 : FontWeight.w400;
      return [
        ThermalCell.text(name,
            mainSizeDots: bold ? 21 : 23,
            mainWeight: bold ? FontWeight.w700 : FontWeight.w600),
        ThermalCell.text(ltr(a), align: TextAlign.center, mainWeight: w),
        ThermalCell.text(ltr(b), align: TextAlign.center, mainWeight: w),
        ThermalCell.text(ltr(c), align: TextAlign.center, mainWeight: w),
      ];
    }

    return [
      ..._masthead(l10n.shiftCloseReceipt),
      if (driverName.isNotEmpty)
        _meta(l10n.driver, driverName,
            valueSizeDots: 23, valueWeight: FontWeight.w700),
      if (date.isNotEmpty) _meta(l10n.orderDate, ltr(date)),
      SizedBox(height: Dots.px(14)),
      ThermalGrid(
        columnDots: const [236, 100, 100, 100],
        headers: ['الصنف', l10n.loaded, l10n.sold, l10n.returned],
        aligns: const [
          TextAlign.start,
          TextAlign.center,
          TextAlign.center,
          TextAlign.center,
        ],
        rows: [
          for (final m in items)
            row(
              m['product_name'] as String? ?? '',
              (m['quantity_loaded'] as num?)?.toInt() ?? 0,
              (m['quantity_sold'] as num?)?.toInt() ?? 0,
              (m['quantity_returned'] as num?)?.toInt() ?? 0,
            ),
          row(l10n.total, totalLoaded, totalSold, totalReturned, bold: true),
        ],
      ),
      ..._footer(),
    ];
  }
}
