import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../printing/providers/printer_provider.dart';
import '../providers/order_provider.dart';

class ReceiptPreviewScreen extends ConsumerWidget {
  /// For viewing existing orders (fetched by ID).
  final String? orderId;

  /// For newly created orders (data passed directly).
  final Map<String, dynamic>? orderData;

  const ReceiptPreviewScreen({
    super.key,
    this.orderId,
    this.orderData,
  }) : assert(orderId != null || orderData != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // If we have direct data, show it immediately
    if (orderData != null) {
      return _ReceiptScaffold(order: orderData!, l10n: l10n, theme: theme);
    }

    // Otherwise fetch by ID
    final repo = ref.watch(orderRepositoryProvider);
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.receipt)),
        body: Center(child: Text(l10n.error)),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: repo.getById(orderId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.receipt)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.receipt)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(l10n.saveError, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      // Force rebuild
                      (context as Element).markNeedsBuild();
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }

        return _ReceiptScaffold(
            order: snapshot.data!, l10n: l10n, theme: theme);
      },
    );
  }
}

class _ReceiptScaffold extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _ReceiptScaffold({
    required this.order,
    required this.l10n,
    required this.theme,
  });

  @override
  ConsumerState<_ReceiptScaffold> createState() => _ReceiptScaffoldState();
}

class _ReceiptScaffoldState extends ConsumerState<_ReceiptScaffold> {
  final _receiptKey = GlobalKey();
  bool _isPrinting = false;
  bool _isCancelling = false;

  Future<void> _cancelOrder() async {
    final l10n = widget.l10n;

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
              backgroundColor: AppColors.error,
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
      await repo.cancelOrder(widget.order['id'] as String);
      if (!mounted) return;

      // Update local order state to reflect cancellation
      widget.order['status'] = 'cancelled';
      widget.order['discount_status'] = 'none';

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.orderCancelled),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      final printService = ref.read(printServiceProvider);
      final success = await printService.printFromWidget(_receiptKey);
      if (!mounted) return;
      final l10n = widget.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.printSuccess : l10n.printFailed),
          backgroundColor: success ? AppColors.success : AppColors.error,
          action: success
              ? null
              : SnackBarAction(
                  label: l10n.retry,
                  textColor: Colors.white,
                  onPressed: _print,
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.l10n.printFailed}: $e'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: widget.l10n.retry,
              textColor: Colors.white,
              onPressed: _print,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(printerConnectedProvider);
    final currentUser = ref.watch(currentUserProvider);
    final l10n = widget.l10n;
    final theme = widget.theme;

    final status = widget.order['status'] as String? ?? 'created';
    final discountStatus =
        widget.order['discount_status'] as String? ?? 'none';
    final isDiscountPending = discountStatus == 'pending';
    final canPrint = isConnected && !_isPrinting && !isDiscountPending;

    // Only owner/admin can cancel orders (drivers cannot cancel without approval)
    final canCancel = status == 'created' &&
        currentUser != null &&
        (currentUser.isOwner || currentUser.isAdmin);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.receipt)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _receiptKey,
          child: _ReceiptCard(
              order: widget.order, l10n: l10n, theme: theme),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info banner when discount is pending
              if (isDiscountPending) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.discountPendingPrintBlocked,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Cancel button (full width, above print/done)
              if (canCancel) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _isCancelling ? null : _cancelOrder,
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.cancel_outlined),
                    label: Text(_isCancelling
                        ? l10n.loading
                        : l10n.cancelOrder),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Print + Done row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canPrint ? _print : null,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.print),
                      label: Text(
                          _isPrinting ? l10n.printing : l10n.print),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(l10n.done),
                    ),
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

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _ReceiptCard({
    required this.order,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final store = order['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] ?? '';
    final storeAddress = store?['address'] ?? '';
    final status = order['status'] as String? ?? 'created';
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0;
    final taxAmount = (order['tax_amount'] as num?)?.toDouble() ?? 0;
    final discount = (order['discount'] as num?)?.toDouble() ?? 0;
    final discountStatus = order['discount_status'] as String? ?? 'none';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final createdAt = order['created_at'] as String?;
    final lines = order['order_lines'] as List<dynamic>? ?? [];

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy  HH:mm').format(dt);
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    final dimStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: [const FontFeature.tabularFigures()],
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Store name — large and prominent
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.store,
                      color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (storeAddress.isNotEmpty)
                          Text(storeAddress, style: dimStyle),
                      ],
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
            ),

            // Date
            const SizedBox(height: 10),
            Text(formattedDate, style: dimStyle),

            const SizedBox(height: 16),

            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(l10n.products,
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold)),
                  ),
                  _headerCell('سعر', flex: 2),
                  _headerCell('و/ع', flex: 1), // وحدة/عبوة
                  _headerCell('عبوات', flex: 1),
                  _headerCell('وحدات', flex: 2),
                  _headerCell(l10n.lineTotal, flex: 3),
                ],
              ),
            ),

            // Line items
            ...lines.map((line) {
              final lineMap = line as Map<String, dynamic>;
              final product = lineMap['products'] as Map<String, dynamic>?;
              final productName = product?['name'] ?? '';
              final qty = (lineMap['quantity'] as num?)?.toInt() ?? 0;
              final orderLineUnitPrice =
                  (lineMap['unit_price'] as num?)?.toDouble() ?? 0;
              final lt = (lineMap['line_total'] as num?)?.toDouble() ??
                  (orderLineUnitPrice * qty);

              // Get piece price and units_per_package from product data
              final piecePrice =
                  (product?['unit_price'] as num?)?.toDouble();
              final upkg =
                  (product?['units_per_package'] as num?)?.toInt();
              final totalPieces =
                  upkg != null ? qty * upkg : null;

              final numStyle = theme.textTheme.bodySmall?.copyWith(
                fontFeatures: [const FontFeature.tabularFigures()],
              );
              final boldNumStyle = numStyle?.copyWith(
                fontWeight: FontWeight.w600,
              );

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Product name
                    Expanded(
                      flex: 4,
                      child: Text(
                        productName,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    // Piece price
                    Expanded(
                      flex: 2,
                      child: Text(
                        piecePrice != null
                            ? piecePrice.toStringAsFixed(0)
                            : orderLineUnitPrice.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: numStyle,
                      ),
                    ),
                    // Units/package
                    Expanded(
                      flex: 1,
                      child: Text(
                        upkg?.toString() ?? '-',
                        textAlign: TextAlign.center,
                        style: numStyle,
                      ),
                    ),
                    // Qty (packages)
                    Expanded(
                      flex: 1,
                      child: Text(
                        '$qty',
                        textAlign: TextAlign.center,
                        style: boldNumStyle,
                      ),
                    ),
                    // Total pieces
                    Expanded(
                      flex: 2,
                      child: Text(
                        totalPieces?.toString() ?? '$qty',
                        textAlign: TextAlign.center,
                        style: numStyle,
                      ),
                    ),
                    // Line total
                    Expanded(
                      flex: 3,
                      child: Text(
                        lt.toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: boldNumStyle,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Totals
            _TotalLine(
              label: l10n.subtotal,
              value: subtotal,
              theme: theme,
            ),
            if (taxAmount > 0)
              _TotalLine(
                label: l10n.tax,
                value: taxAmount,
                theme: theme,
              ),
            if (discount > 0 &&
                (discountStatus == 'approved' || discountStatus == 'pending'))
              _TotalLine(
                label: l10n.discount,
                value: -discount,
                theme: theme,
                isDiscount: true,
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: theme.colorScheme.primary, width: 2),
                ),
              ),
              child: _TotalLine(
                label: l10n.total,
                value: total,
                theme: theme,
                isGrandTotal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final Color bgColor;
    final Color fgColor;
    final String label;

    switch (status) {
      case 'delivered':
        bgColor = AppColors.success.withValues(alpha: 0.12);
        fgColor = AppColors.success;
        label = l10n.statusDelivered;
      case 'cancelled':
        bgColor = AppColors.error.withValues(alpha: 0.12);
        fgColor = AppColors.error;
        label = l10n.statusCancelled;
      default:
        bgColor = AppColors.primary.withValues(alpha: 0.12);
        fgColor = AppColors.primary;
        label = l10n.statusCreated;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final double value;
  final ThemeData theme;
  final bool isGrandTotal;
  final bool isDiscount;

  const _TotalLine({
    required this.label,
    required this.value,
    required this.theme,
    this.isGrandTotal = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle? style;
    if (isGrandTotal) {
      style = theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        fontFeatures: [const FontFeature.tabularFigures()],
      );
    } else if (isDiscount) {
      style = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
        fontFeatures: [const FontFeature.tabularFigures()],
      );
    } else {
      style = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: [const FontFeature.tabularFigures()],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${value.toStringAsFixed(2)} د.ج', style: style),
        ],
      ),
    );
  }
}
