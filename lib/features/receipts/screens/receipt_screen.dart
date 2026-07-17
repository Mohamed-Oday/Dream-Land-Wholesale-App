import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/packages/providers/package_provider.dart';
import 'package:tawzii/features/printing/providers/printer_provider.dart';
import 'package:tawzii/features/auth/screens/settings_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';

/// The three document types the unified receipt screen can render.
enum ReceiptDocType { order, load, returns }

/// Local (feature-scoped) provider: fetch an order by id with retry support.
final _orderByIdProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, orderId) async {
  final repo = ref.watch(orderRepositoryProvider);
  if (repo == null) throw StateError('no session');
  return repo.getById(orderId);
});

/// 4c — THE UNIFIED RECEIPT. One screen, three document types
/// (order / load manifest / return), 58mm thermal preview.
///
/// Replaces ReceiptPreviewScreen, LoadReceiptScreen and ReturnReceiptScreen.
class ReceiptScreen extends ConsumerStatefulWidget {
  final ReceiptDocType docType;

  /// Order doc: fetched by [orderId] or passed directly as [orderData].
  final String? orderId;
  final Map<String, dynamic>? orderData;

  /// Load manifest doc.
  final Map<String, dynamic>? loadData;

  /// Return (shift close) doc.
  final Map<String, dynamic>? returnData;

  const ReceiptScreen.order({super.key, this.orderId, this.orderData})
      : docType = ReceiptDocType.order,
        loadData = null,
        returnData = null,
        assert(orderId != null || orderData != null);

  const ReceiptScreen.load(
      {super.key, required Map<String, dynamic> this.loadData})
      : docType = ReceiptDocType.load,
        orderId = null,
        orderData = null,
        returnData = null;

  const ReceiptScreen.returns(
      {super.key, required Map<String, dynamic> receiptData})
      : docType = ReceiptDocType.returns,
        returnData = receiptData,
        orderId = null,
        orderData = null,
        loadData = null;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  final _receiptKey = GlobalKey();
  bool _isPrinting = false;
  bool _isCancelling = false;
  int? _packageBalance;

  /// Direct order data (when passed in, possibly mutated after cancel).
  Map<String, dynamic>? _directOrder;

  @override
  void initState() {
    super.initState();
    _directOrder = widget.orderData;
    if (widget.docType == ReceiptDocType.order && _directOrder != null) {
      _loadPackageBalance(_directOrder!);
    }
  }

  Future<void> _loadPackageBalance(Map<String, dynamic> order) async {
    final storeId = order['store_id'] as String?;
    if (storeId == null) return;
    final repo = ref.read(packageRepositoryProvider);
    if (repo == null) return;
    try {
      final balances = await repo.getBalancesByStore(storeId);
      final currentBalance = balances.fold<int>(
        0,
        (sum, b) => sum + ((b['balance'] as num?)?.toInt() ?? 0),
      );
      // Packages given in this order = sum of all line quantities
      final lines = order['order_lines'] as List<dynamic>? ?? [];
      final packagesInOrder = lines.fold<int>(
        0,
        (sum, line) => sum + ((line['quantity'] as num?)?.toInt() ?? 0),
      );
      if (mounted) {
        setState(() => _packageBalance = currentBalance - packagesInOrder);
      }
    } catch (e) {
      debugPrint('Package balance fetch error: $e');
    }
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      final printService = ref.read(printServiceProvider);
      final success = await printService.printFromWidget(_receiptKey);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.printSuccess : l10n.printFailed),
          action: success
              ? null
              : SnackBarAction(
                  label: l10n.retry,
                  onPressed: _print,
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.printFailed}: $e'),
            action: SnackBarAction(
              label: l10n.retry,
              onPressed: _print,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelOrder),
        content: Text(l10n.cancelOrderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: TawziiTokens.of(ctx).danger,
              foregroundColor: AppColorsLight.surface,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      final repo = ref.read(orderRepositoryProvider)!;
      await repo.cancelOrder(order['id'] as String);
      if (!mounted) return;

      // Reflect cancellation locally / refetch.
      if (_directOrder != null) {
        _directOrder!['status'] = 'cancelled';
        _directOrder!['discount_status'] = 'none';
      } else if (widget.orderId != null) {
        ref.invalidate(_orderByIdProvider(widget.orderId!));
      }
      ref.invalidate(productListProvider);
      ref.invalidate(orderListProvider);
      ref.invalidate(allOrdersProvider);

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.orderCancelled)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _done() {
    switch (widget.docType) {
      case ReceiptDocType.order:
        ref.invalidate(orderListProvider);
        ref.invalidate(allOrdersProvider);
        Navigator.pop(context);
      case ReceiptDocType.load:
        Navigator.pop(context);
      case ReceiptDocType.returns:
        // Pop back to driver stock screen (or root)
        Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    switch (widget.docType) {
      case ReceiptDocType.order:
        if (_directOrder != null) {
          return _buildScaffold(context, order: _directOrder!);
        }
        final orderAsync = ref.watch(_orderByIdProvider(widget.orderId!));
        return orderAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.receipt)),
            body: const Padding(
              padding: EdgeInsetsDirectional.all(18),
              child: SkeletonList(count: 6),
            ),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: Text(l10n.receipt)),
            body: Padding(
              padding: const EdgeInsetsDirectional.all(18),
              child: ErrorRetryRow(
                onRetry: () =>
                    ref.invalidate(_orderByIdProvider(widget.orderId!)),
              ),
            ),
          ),
          data: (order) {
            if (_packageBalance == null) {
              // Fire once per resolved order (idempotent enough for a preview).
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _loadPackageBalance(order));
            }
            return _buildScaffold(context, order: order);
          },
        );
      case ReceiptDocType.load:
        return _buildScaffold(context);
      case ReceiptDocType.returns:
        return _buildScaffold(context);
    }
  }

  Widget _buildScaffold(BuildContext context, {Map<String, dynamic>? order}) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final isConnected = ref.watch(printerConnectedProvider);
    final printerName = ref.watch(connectedPrinterNameProvider);
    final currentUser = ref.watch(currentUserProvider);

    final status = order?['status'] as String? ?? 'created';
    final discountStatus = order?['discount_status'] as String? ?? 'none';
    final isDiscountPending =
        widget.docType == ReceiptDocType.order && discountStatus == 'pending';
    final canPrint = isConnected && !_isPrinting && !isDiscountPending;

    // Only owner/admin can cancel orders (drivers cannot cancel without approval)
    final canCancel = widget.docType == ReceiptDocType.order &&
        status == 'created' &&
        currentUser != null &&
        (currentUser.isOwner || currentUser.isAdmin);

    final title = switch (widget.docType) {
      ReceiptDocType.order => l10n.receipt,
      ReceiptDocType.load => l10n.loadReceipt,
      ReceiptDocType.returns => l10n.shiftCloseReceipt,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 18, 24),
        children: [
          _DocTypeIndicator(active: widget.docType),
          const SizedBox(height: 14),
          // 58mm thermal preview — always white paper, ink text (both themes).
          Center(
            child: RepaintBoundary(
              key: _receiptKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _ReceiptPaper(
                  docType: widget.docType,
                  order: order,
                  loadData: widget.loadData,
                  returnData: widget.returnData,
                  packageBalance: _packageBalance,
                  l10n: l10n,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Printer status row.
          Row(
            children: [
              StatusDot(isConnected ? StatusKind.success : StatusKind.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isConnected
                      ? 'الطابعة متصلة${printerName != null ? ' — \u2066$printerName\u2069' : ''}'
                      : 'الطابعة غير متصلة',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () {
                  final roleName = currentUser == null
                      ? 'بائع'
                      : currentUser.isOwner
                          ? 'مالك'
                          : currentUser.isAdmin
                              ? 'مشرف'
                              : 'بائع';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SettingsScreen(roleName: roleName)),
                  );
                },
                child: const Text('تغيير'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(top: BorderSide(color: t.borderStrong, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDiscountPending) ...[
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.warningSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const StatusDot(StatusKind.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.discountPendingPrintBlocked,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: t.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (canCancel) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed:
                        _isCancelling ? null : () => _cancelOrder(order!),
                    style: TextButton.styleFrom(foregroundColor: t.danger),
                    child: Text(
                        _isCancelling ? l10n.loading : l10n.cancelOrder),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: canPrint ? _print : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      child: _isPrinting
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: t.onAccent),
                            )
                          : Text(
                              l10n.print,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _done,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.borderStrong, width: 2),
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 18),
                    ),
                    child: Text(l10n.done),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Non-interactive segmented indicator of the current document type.
class _DocTypeIndicator extends StatelessWidget {
  final ReceiptDocType active;

  const _DocTypeIndicator({required this.active});

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    Widget segment(String label, ReceiptDocType type) {
      final isActive = type == active;
      return Expanded(
        child: Container(
          height: 36,
          alignment: AlignmentDirectional.center,
          decoration: BoxDecoration(
            color: isActive ? t.surface : null,
            border: isActive ? Border.all(color: t.border) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? t.textPrimary : t.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsetsDirectional.all(3),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          segment('طلب', ReceiptDocType.order),
          const SizedBox(width: 4),
          segment('تحميل', ReceiptDocType.load),
          const SizedBox(width: 4),
          segment('إرجاع', ReceiptDocType.returns),
        ],
      ),
    );
  }
}

/// The white 58mm paper. Colors are intentionally FIXED to light-paper values
/// (AppColorsLight) in both themes: this widget is captured as a bitmap and
/// sent to the thermal printer, so it must always be ink-on-white.
class _ReceiptPaper extends StatelessWidget {
  final ReceiptDocType docType;
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? loadData;
  final Map<String, dynamic>? returnData;
  final int? packageBalance;
  final AppLocalizations l10n;

  static const _ink = AppColorsLight.textPrimary;
  static const _dim = AppColorsLight.textSecondary;
  static const _faint = AppColorsLight.textMuted;
  static const _paper = AppColorsLight.surface;
  static const _dash = AppColorsLight.borderStrong;

  const _ReceiptPaper({
    required this.docType,
    required this.l10n,
    this.order,
    this.loadData,
    this.returnData,
    this.packageBalance,
  });

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  /// Bidi-isolated LTR numeral run for the paper.
  String _n(Object v) => '\u2066$v\u2069';

  String _amt(num v) => _n(Money.format(v));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 18),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 12,
          height: 1.7,
          color: _ink,
          fontFeatures: [
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
    );
  }

  // --- shared pieces ---

  Widget _header(String docTitle) {
    return Column(
      children: [
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const _DashedDivider(color: _dash),
        Text(
          docTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _kv(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _dim)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return const Padding(
      padding: EdgeInsetsDirectional.only(top: 10),
      child: Text(
        'شكراً لثقتكم',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: _faint),
      ),
    );
  }

  // --- order receipt ---

  List<Widget> _orderBody() {
    final o = order!;
    final store = o['stores'] as Map<String, dynamic>?;
    final storeName = (store?['name'] ?? '').toString();
    final storeAddress = (store?['address'] ?? '').toString();
    final status = o['status'] as String? ?? 'created';
    final subtotal = ((o['subtotal'] as num?) ?? 0).toDouble();
    final taxAmount = ((o['tax_amount'] as num?) ?? 0).toDouble();
    final discount = ((o['discount'] as num?) ?? 0).toDouble();
    final discountStatus = o['discount_status'] as String? ?? 'none';
    final total = ((o['total'] as num?) ?? 0).toDouble();
    final lines = o['order_lines'] as List<dynamic>? ?? [];
    final date = _fmtDate(o['created_at'] as String?);

    final showDiscount = discount > 0 &&
        (discountStatus == 'approved' || discountStatus == 'pending');

    return [
      _header(l10n.receipt),
      if (status == 'cancelled')
        Text(
          l10n.statusCancelled,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      const SizedBox(height: 4),
      if (date.isNotEmpty) _kv(l10n.orderDate, _n(date)),
      if (storeName.isNotEmpty)
        _kv('المتجر', storeName, bold: true),
      if (storeAddress.isNotEmpty) _kv(l10n.address, storeAddress),
      const _DashedDivider(color: _dash),
      // Line items: name line, then LTR qty × unit …… line total.
      ...lines.map((line) {
        final lineMap = line as Map<String, dynamic>;
        final product = lineMap['products'] as Map<String, dynamic>?;
        final productName = (product?['name'] ?? '').toString();
        final qty = (lineMap['quantity'] as num?)?.toInt() ?? 0;
        final unitPrice =
            ((lineMap['unit_price'] as num?) ?? 0).toDouble();
        final lineTotal = ((lineMap['line_total'] as num?) ?? 0) == 0
            ? unitPrice * qty
            : (lineMap['line_total'] as num).toDouble();
        final upkg = (product?['units_per_package'] as num?)?.toInt();

        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    upkg != null
                        ? '${_n(qty)} × ${_amt(unitPrice)} · ${_n(upkg)} و/ع = ${_n(qty * upkg)} وحدة'
                        : '${_n(qty)} × ${_amt(unitPrice)}',
                    style: const TextStyle(color: _dim),
                  ),
                  Text(
                    _amt(lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
      const _DashedDivider(color: _dash),
      _kv(l10n.subtotal, _amt(subtotal), bold: true),
      if (taxAmount > 0) _kv(l10n.tax, _amt(taxAmount), bold: true),
      if (showDiscount) _kv(l10n.discount, '−${_amt(discount)}', bold: true),
      Padding(
        padding: const EdgeInsetsDirectional.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.total,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${_amt(total)} ${l10n.currencyUnit}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      if (packageBalance != null) ...[
        const _DashedDivider(color: _dash),
        _kv('العبوات المتبقية',
            '${_n(packageBalance!)} ${l10n.packageUnit}',
            bold: true),
      ],
      _footer(),
    ];
  }

  // --- load manifest ---

  List<Widget> _loadBody() {
    final d = loadData!;
    final driverName = d['driver_name'] as String? ?? '';
    final loadedByName = d['loaded_by_name'] as String? ?? '';
    final date = _fmtDate(d['opened_at'] as String?);
    final items = d['items'] as List<dynamic>? ?? [];
    final totalQty = items.fold<int>(
        0, (sum, i) => sum + ((i['quantity_loaded'] as num?)?.toInt() ?? 0));

    return [
      _header(l10n.loadReceipt),
      const SizedBox(height: 4),
      if (driverName.isNotEmpty) _kv(l10n.driver, driverName, bold: true),
      if (loadedByName.isNotEmpty) _kv(l10n.loadedBy, loadedByName),
      if (date.isNotEmpty) _kv(l10n.orderDate, _n(date)),
      const _DashedDivider(color: _dash),
      ...items.map((item) {
        final m = item as Map<String, dynamic>;
        final name = m['product_name'] as String? ?? '';
        final qty = (m['quantity_loaded'] as num?)?.toInt() ?? 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(_n(qty),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        );
      }),
      const _DashedDivider(color: _dash),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.totalLoaded,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          Text(_n(totalQty),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    ];
  }

  // --- return / shift close ---

  List<Widget> _returnBody() {
    final d = returnData!;
    final driverName = d['driver_name'] as String? ?? '';
    final date = _fmtDate(d['closed_at'] as String?);
    final items = d['items'] as List<dynamic>? ?? [];

    int totalLoaded = 0, totalSold = 0, totalReturned = 0;
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      totalLoaded += (m['quantity_loaded'] as num?)?.toInt() ?? 0;
      totalSold += (m['quantity_sold'] as num?)?.toInt() ?? 0;
      totalReturned += (m['quantity_returned'] as num?)?.toInt() ?? 0;
    }

    Widget tableRow(String name, String a, String b, String c,
        {bool bold = false}) {
      final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        fontSize: bold ? 13 : 12,
      );
      final dimStyle = TextStyle(
        color: bold ? _ink : _dim,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontSize: 12,
      );
      return Row(
        children: [
          Expanded(flex: 4, child: Text(name, style: style)),
          Expanded(
              flex: 2,
              child: Text(a, textAlign: TextAlign.center, style: dimStyle)),
          Expanded(
              flex: 2,
              child: Text(b, textAlign: TextAlign.center, style: dimStyle)),
          Expanded(
              flex: 2,
              child: Text(c, textAlign: TextAlign.center, style: dimStyle)),
        ],
      );
    }

    return [
      _header(l10n.shiftCloseReceipt),
      const SizedBox(height: 4),
      if (driverName.isNotEmpty) _kv(l10n.driver, driverName, bold: true),
      if (date.isNotEmpty) _kv(l10n.orderDate, _n(date)),
      const _DashedDivider(color: _dash),
      tableRow(l10n.products, l10n.loaded, l10n.sold, l10n.returned,
          bold: true),
      const SizedBox(height: 2),
      ...items.map((item) {
        final m = item as Map<String, dynamic>;
        return tableRow(
          m['product_name'] as String? ?? '',
          _n((m['quantity_loaded'] as num?)?.toInt() ?? 0),
          _n((m['quantity_sold'] as num?)?.toInt() ?? 0),
          _n((m['quantity_returned'] as num?)?.toInt() ?? 0),
        );
      }),
      const _DashedDivider(color: _dash),
      tableRow(l10n.total, _n(totalLoaded), _n(totalSold), _n(totalReturned),
          bold: true),
    ];
  }
}

/// Thin dashed divider matching the thermal receipt look.
class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashPainter(color),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;

  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) =>
      oldDelegate.color != color;
}
