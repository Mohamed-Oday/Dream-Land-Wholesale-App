import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/numeric_keypad.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/packages/providers/package_provider.dart';
import 'package:tawzii/features/printing/providers/printer_provider.dart';
import 'package:tawzii/features/auth/screens/settings_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';
import 'package:tawzii/features/receipts/providers/receipt_config_provider.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';
import 'package:tawzii/features/receipts/widgets/receipt_paper.dart';

export 'package:tawzii/features/receipts/widgets/receipt_paper.dart' show ReceiptDocType;

/// Local (feature-scoped) provider: fetch an order by id with retry support.
final _orderByIdProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, orderId) async {
  final repo = ref.watch(orderRepositoryProvider);
  if (repo == null) throw StateError('no session');
  return repo.getById(orderId);
});

/// 4c — THE UNIFIED RECEIPT. One screen, three document types
/// (order / load manifest / return), 80 mm thermal preview (288 px = 576 dots).
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
  bool _isMarkingPaid = false;
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

  /// Record a payment against the order. Prompts for the amount collected now
  /// (defaults to the remaining balance) and derives paid/partial status.
  Future<void> _markAsPaid(Map<String, dynamic> order) async {
    final l10n = AppLocalizations.of(context)!;
    final total = ((order['total'] as num?) ?? 0).toDouble();
    final alreadyPaid = ((order['paid_amount'] as num?) ?? 0).toDouble();
    final remaining = (total - alreadyPaid).clamp(0.0, total);

    final amount = await showKeypadSheet(
      context,
      title: 'المبلغ المدفوع',
      initialValue: remaining > 0 ? remaining : null,
      allowDecimal: true,
      hardened: true,
    );
    if (amount == null || amount <= 0 || !mounted) return;

    final newPaidTotal = (alreadyPaid + amount).clamp(0.0, total);
    final status = newPaidTotal >= total
        ? 'paid'
        : (newPaidTotal > 0 ? 'partial' : 'unpaid');

    setState(() => _isMarkingPaid = true);
    try {
      final repo = ref.read(orderRepositoryProvider)!;
      await repo.updatePaymentStatus(
        orderId: order['id'] as String,
        paymentStatus: status,
        paidAmount: newPaidTotal,
        storeId: order['store_id'] as String?,
      );
      if (!mounted) return;

      // Reflect locally / refetch.
      if (_directOrder != null) {
        _directOrder!['payment_status'] = status;
        _directOrder!['paid_amount'] = newPaidTotal;
      } else if (widget.orderId != null) {
        ref.invalidate(_orderByIdProvider(widget.orderId!));
      }
      ref.invalidate(orderListProvider);
      ref.invalidate(allOrdersProvider);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'paid'
              ? 'تم تسجيل الدفع بالكامل'
              : 'تم تسجيل دفعة جزئية'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingPaid = false);
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

    final paymentStatus = order?['payment_status'] as String? ?? 'unpaid';
    final canMarkPaid = widget.docType == ReceiptDocType.order &&
        order != null &&
        status != 'cancelled' &&
        paymentStatus != 'paid';

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
          // 80 mm thermal paper at its natural 288 px (= 576 dots at 2.0).
          // The RepaintBoundary is what gets captured; it sits inside the
          // FittedBox so a narrow phone scales the preview without touching
          // the printed bitmap.
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final paper = RepaintBoundary(
                  key: _receiptKey,
                  child: ReceiptPaper(
                    docType: widget.docType,
                    order: order,
                    loadData: widget.loadData,
                    returnData: widget.returnData,
                    packageBalance: _packageBalance,
                    config: ref.watch(receiptConfigProvider).valueOrNull ??
                        ReceiptConfig.empty,
                    l10n: l10n,
                  ),
                );
                if (constraints.maxWidth >= ReceiptPaper.width) return paper;
                return FittedBox(fit: BoxFit.fitWidth, child: paper);
              },
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
              if (canMarkPaid) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _isMarkingPaid ? null : () => _markAsPaid(order),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                    ),
                    icon: _isMarkingPaid
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.payments_outlined, size: 20),
                    label: Text(
                      paymentStatus == 'partial'
                          ? 'إكمال الدفع'
                          : 'تسجيل الدفع',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
