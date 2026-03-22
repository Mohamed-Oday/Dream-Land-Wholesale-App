import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../providers/order_provider.dart';
import 'create_order_screen.dart';
import 'receipt_preview_screen.dart';

class OrderListScreen extends ConsumerWidget {
  final bool isOwner;

  const OrderListScreen({super.key, this.isOwner = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ordersAsync =
        ref.watch(isOwner ? allOrdersProvider : orderListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orders)),
      floatingActionButton: isOwner
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateOrderScreen(),
                  ),
                );
                ref.invalidate(orderListProvider);
              },
              child: const Icon(Icons.add),
            ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('خطأ في تحميل الطلبات', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(
                    isOwner ? allOrdersProvider : orderListProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(l10n.noOrders, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    l10n.emptyOrderMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref
                .invalidate(isOwner ? allOrdersProvider : orderListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  .copyWith(bottom: 80),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OrderCard(
                  order: order,
                  isOwner: isOwner,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReceiptPreviewScreen(orderId: order['id']),
                      ),
                    );
                    ref.invalidate(
                        isOwner ? allOrdersProvider : orderListProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isOwner;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.isOwner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final store = order['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] ?? '';
    final driverData = order['users'] as Map<String, dynamic>?;
    final driverName = driverData?['name'] ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? 'created';
    final createdAt = order['created_at'] as String?;

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Store icon
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.store,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              // Order info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (isOwner && driverName.isNotEmpty) ...[
                      Text(
                        '${l10n.driver}: $driverName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Total + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${total.toStringAsFixed(2)} د.ج',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(status: status, l10n: l10n),
                  if (order['discount_status'] != null &&
                      order['discount_status'] != 'none') ...[
                    const SizedBox(height: 4),
                    _DiscountStatusChip(
                      discountStatus: order['discount_status'] as String,
                      l10n: l10n,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final AppLocalizations l10n;

  const _StatusChip({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DiscountStatusChip extends StatelessWidget {
  final String discountStatus;
  final AppLocalizations l10n;

  const _DiscountStatusChip({
    required this.discountStatus,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color fgColor;
    final String label;

    switch (discountStatus) {
      case 'pending':
        bgColor = AppColors.warning.withValues(alpha: 0.12);
        fgColor = AppColors.warning;
        label = l10n.discountPending;
      case 'approved':
        bgColor = AppColors.success.withValues(alpha: 0.12);
        fgColor = AppColors.success;
        label = l10n.discountApproved;
      case 'rejected':
        bgColor = AppColors.error.withValues(alpha: 0.12);
        fgColor = AppColors.error;
        label = l10n.discountRejected;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.percent, size: 10, color: fgColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
