import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/dashboard/providers/dashboard_provider.dart';
import 'package:tawzii/features/dashboard/widgets/kpi_card.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/orders/screens/order_list_screen.dart';
import 'package:tawzii/features/stores/screens/store_detail_screen.dart';
import 'package:tawzii/features/payments/screens/payment_list_screen.dart';
import 'package:tawzii/features/products/screens/product_list_screen.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final revenue = ref.watch(todayRevenueProvider);
    final orderCount = ref.watch(todayOrderCountProvider);
    final debtors = ref.watch(topDebtorsProvider);
    final alerts = ref.watch(packageAlertsProvider);
    final pendingDiscounts = ref.watch(pendingDiscountsProvider);

    final numberFormat = NumberFormat('#,##0', 'ar');
    final currencyFormat = NumberFormat('#,##0.00', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments),
            tooltip: l10n.payments,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentListScreen(isOwner: true),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: l10n.orders,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OrderListScreen(isOwner: true),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: l10n.products,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductListScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayRevenueProvider);
          ref.invalidate(todayOrderCountProvider);
          ref.invalidate(topDebtorsProvider);
          ref.invalidate(packageAlertsProvider);
          ref.invalidate(pendingDiscountsProvider);
          // Wait for all providers to resolve before hiding indicator
          await Future.wait([
            ref.read(todayRevenueProvider.future),
            ref.read(todayOrderCountProvider.future),
            ref.read(topDebtorsProvider.future),
            ref.read(packageAlertsProvider.future),
            ref.read(pendingDiscountsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- KPI Cards Row ---
            Row(
              children: [
                Expanded(
                  child: revenue.when(
                    data: (value) => KpiCard(
                      label: l10n.todayRevenue,
                      value: '${currencyFormat.format(value)} ${l10n.currencyUnit}',
                      icon: Icons.payments_outlined,
                    ),
                    loading: () => _buildShimmerCard(context),
                    error: (_, _) => _buildErrorCard(
                      context,
                      l10n.todayRevenue,
                      Icons.payments_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: orderCount.when(
                    data: (value) => KpiCard(
                      label: l10n.todayOrders,
                      value: numberFormat.format(value),
                      icon: Icons.receipt_long_outlined,
                    ),
                    loading: () => _buildShimmerCard(context),
                    error: (_, _) => _buildErrorCard(
                      context,
                      l10n.todayOrders,
                      Icons.receipt_long_outlined,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- Pending Discounts Section ---
            _SectionHeader(
              title: l10n.pendingDiscounts,
              icon: Icons.percent,
              iconColor: colorScheme.tertiary,
            ),
            const SizedBox(height: 8),
            pendingDiscounts.when(
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyState(
                    icon: Icons.check_circle_outline,
                    message: l10n.noPendingDiscounts,
                    color: Colors.green,
                  );
                }
                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        _PendingDiscountTile(
                          order: items[i],
                          onApprove: () => _handleApprove(context, ref, items[i]),
                          onReject: () => _handleReject(context, ref, items[i]),
                          currencyFormat: currencyFormat,
                        ),
                        if (i < items.length - 1)
                          Divider(height: 1, indent: 72, color: colorScheme.outlineVariant),
                      ],
                    ],
                  ),
                );
              },
              loading: () => _buildShimmerList(context, 2),
              error: (_, _) => _buildErrorSection(context, l10n.retry, () {
                ref.invalidate(pendingDiscountsProvider);
              }),
            ),

            const SizedBox(height: 24),

            // --- Top Debtors Section ---
            _SectionHeader(
              title: l10n.topDebtors,
              icon: Icons.warning_amber_rounded,
              iconColor: colorScheme.error,
            ),
            const SizedBox(height: 8),
            debtors.when(
              data: (stores) {
                if (stores.isEmpty) {
                  return _EmptyState(
                    icon: Icons.check_circle_outline,
                    message: l10n.noDebts,
                    color: Colors.green,
                  );
                }
                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < stores.length; i++) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                colorScheme.errorContainer,
                            radius: 20,
                            child: Icon(
                              Icons.store,
                              color: colorScheme.onErrorContainer,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            stores[i]['name'] as String? ?? '',
                            style: theme.textTheme.titleSmall,
                          ),
                          trailing: Text(
                            '${currencyFormat.format(_toDouble(stores[i]['credit_balance']))} ${l10n.currencyUnit}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoreDetailScreen(
                                storeId: stores[i]['id'] as String,
                              ),
                            ),
                          ),
                        ),
                        if (i < stores.length - 1)
                          Divider(height: 1, indent: 72, color: colorScheme.outlineVariant),
                      ],
                    ],
                  ),
                );
              },
              loading: () => _buildShimmerList(context, 3),
              error: (error, _) => _buildErrorSection(context, l10n.retry, () {
                ref.invalidate(topDebtorsProvider);
              }),
            ),

            const SizedBox(height: 24),

            // --- Package Alerts Section ---
            _SectionHeader(
              title: l10n.packageAlerts,
              icon: Icons.inventory_2_outlined,
              iconColor: colorScheme.tertiary,
            ),
            const SizedBox(height: 8),
            alerts.when(
              data: (stores) {
                if (stores.isEmpty) {
                  return _EmptyState(
                    icon: Icons.check_circle_outline,
                    message: l10n.allPackagesReturned,
                    color: Colors.green,
                  );
                }
                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < stores.length; i++) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                colorScheme.tertiaryContainer,
                            radius: 20,
                            child: Icon(
                              Icons.inventory_2,
                              color: colorScheme.onTertiaryContainer,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            stores[i]['store_name'] as String? ?? '',
                            style: theme.textTheme.titleSmall,
                          ),
                          trailing: Text(
                            '${numberFormat.format(_toInt(stores[i]['total_outstanding']))} ${l10n.packageUnit}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (i < stores.length - 1)
                          Divider(height: 1, indent: 72, color: colorScheme.outlineVariant),
                      ],
                    ],
                  ),
                );
              },
              loading: () => _buildShimmerList(context, 3),
              error: (error, _) => _buildErrorSection(context, l10n.retry, () {
                ref.invalidate(packageAlertsProvider);
              }),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _handleApprove(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.approveDiscount),
        content: Text(l10n.confirmApproveDiscount),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(orderRepositoryProvider)!;
      final user = ref.read(currentUserProvider)!;
      await repo.approveDiscount(order['id'] as String, user.id);
      ref.invalidate(pendingDiscountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discountApproved)),
        );
      }
    } catch (e) {
      ref.invalidate(pendingDiscountsProvider);
      if (context.mounted) {
        final msg = e.toString().contains('discount_already_processed')
            ? l10n.discountAlreadyProcessed
            : l10n.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rejectDiscount),
        content: Text(l10n.confirmRejectDiscount),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(orderRepositoryProvider)!;
      await repo.rejectDiscount(order['id'] as String);
      ref.invalidate(pendingDiscountsProvider);
      ref.invalidate(topDebtorsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discountRejected)),
        );
      }
    } catch (e) {
      ref.invalidate(pendingDiscountsProvider);
      if (context.mounted) {
        final msg = e.toString().contains('discount_already_processed')
            ? l10n.discountAlreadyProcessed
            : l10n.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  Widget _buildShimmerCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const SizedBox(height: 100),
    );
  }

  Widget _buildErrorCard(BuildContext context, String label, IconData icon) {
    return KpiCard(
      label: label,
      value: '--',
      icon: icon,
    );
  }

  Widget _buildShimmerList(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: List.generate(count, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 14,
                  width: 60,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorSection(
      BuildContext context, String retryLabel, VoidCallback onRetry) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                retryLabel,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PendingDiscountTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final NumberFormat currencyFormat;

  const _PendingDiscountTile({
    required this.order,
    required this.onApprove,
    required this.onReject,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final store = order['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] ?? '';
    final driver = order['users'] as Map<String, dynamic>?;
    final driverName = driver?['name'] ?? '';
    final discount = (order['discount'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse(order['created_at'] as String? ?? '');

    // Time remaining: 3 min - elapsed
    String timeText = '';
    if (createdAt != null) {
      final elapsed = DateTime.now().toUtc().difference(createdAt);
      final remaining = const Duration(minutes: 3) - elapsed;
      if (remaining.isNegative) {
        timeText = l10n.discountRejected;
      } else {
        final mins = remaining.inMinutes;
        final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        timeText = l10n.timeRemaining(mins, secs);
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.tertiaryContainer,
        radius: 20,
        child: Icon(Icons.percent, color: colorScheme.onTertiaryContainer, size: 20),
      ),
      title: Text(storeName, style: theme.textTheme.titleSmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$driverName · ${currencyFormat.format(discount)} ${l10n.currencyUnit}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (timeText.isNotEmpty)
            Text(
              timeText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.tertiary,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            color: Colors.green,
            onPressed: onApprove,
            tooltip: l10n.approveDiscount,
          ),
          IconButton(
            icon: const Icon(Icons.cancel),
            color: colorScheme.error,
            onPressed: onReject,
            tooltip: l10n.rejectDiscount,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
