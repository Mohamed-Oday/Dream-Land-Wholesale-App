import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/dashboard/widgets/kpi_card.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/payments/providers/payment_provider.dart';

class DriverPerformanceScreen extends ConsumerWidget {
  final String driverId;
  final String driverName;

  const DriverPerformanceScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final numberFormat = NumberFormat('#,##0', 'ar');

    // Fetch all-time data directly from repos (no date range filter)
    final orderRepo = ref.watch(orderRepositoryProvider);
    final paymentRepo = ref.watch(paymentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.driverPerformance} — $driverName')),
      body: FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: Future.wait([
          orderRepo?.getAll(driverId: driverId) ?? Future.value([]),
          paymentRepo?.getAll(driverId: driverId) ?? Future.value([]),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(l10n.error, style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }

          final orders = snapshot.data?[0] ?? [];
          final payments = snapshot.data?[1] ?? [];

          // Compute stats
          final orderCount = orders.length;
          double orderTotal = 0;
          for (final o in orders) {
            orderTotal += (o['total'] as num?)?.toDouble() ?? 0;
          }

          final paymentCount = payments.length;
          double paymentTotal = 0;
          for (final p in payments) {
            paymentTotal += (p['amount'] as num?)?.toDouble() ?? 0;
          }

          // Interleave orders + payments by created_at, descending
          final activities = <_ActivityItem>[];
          for (final o in orders) {
            final store = o['stores'] as Map<String, dynamic>?;
            activities.add(_ActivityItem(
              type: _ActivityType.order,
              storeName: store?['name'] ?? '',
              amount: (o['total'] as num?)?.toDouble() ?? 0,
              createdAt: o['created_at'] as String? ?? '',
            ));
          }
          for (final p in payments) {
            final store = p['stores'] as Map<String, dynamic>?;
            activities.add(_ActivityItem(
              type: _ActivityType.payment,
              storeName: store?['name'] ?? '',
              amount: (p['amount'] as num?)?.toDouble() ?? 0,
              createdAt: p['created_at'] as String? ?? '',
            ));
          }
          activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final recent = activities.take(20).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KPI cards
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      label: l10n.totalOrders,
                      value: numberFormat.format(orderCount),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      label: l10n.totalCollected,
                      value:
                          '${currencyFormat.format(paymentTotal)} ${l10n.currencyUnit}',
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      label: l10n.totalPayments,
                      value: numberFormat.format(paymentCount),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      label: l10n.total,
                      value:
                          '${currencyFormat.format(orderTotal)} ${l10n.currencyUnit}',
                      icon: Icons.shopping_cart_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent activity
              Row(
                children: [
                  Icon(Icons.timeline,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.recentActivity,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(l10n.noActivity,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                )
              else
                ...recent.map((item) {
                  String formattedDate = '';
                  try {
                    final dt =
                        DateTime.parse(item.createdAt).toLocal();
                    formattedDate =
                        DateFormat('dd/MM/yyyy HH:mm').format(dt);
                  } catch (_) {
                    formattedDate = item.createdAt;
                  }

                  final isOrder = item.type == _ActivityType.order;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isOrder
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.success.withValues(alpha: 0.12),
                        child: Icon(
                          isOrder ? Icons.receipt_long : Icons.payments,
                          size: 18,
                          color: isOrder
                              ? AppColors.primary
                              : AppColors.success,
                        ),
                      ),
                      title: Text(item.storeName,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      subtitle: Text(formattedDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      trailing: Text(
                        '${item.amount.toStringAsFixed(2)} ${l10n.currencyUnit}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isOrder
                              ? AppColors.primary
                              : AppColors.success,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

enum _ActivityType { order, payment }

class _ActivityItem {
  final _ActivityType type;
  final String storeName;
  final double amount;
  final String createdAt;

  const _ActivityItem({
    required this.type,
    required this.storeName,
    required this.amount,
    required this.createdAt,
  });
}
