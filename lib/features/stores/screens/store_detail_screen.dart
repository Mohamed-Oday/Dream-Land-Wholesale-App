import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/packages/providers/package_provider.dart';
import 'package:tawzii/features/payments/providers/payment_provider.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';
import 'package:tawzii/features/stores/providers/store_provider.dart';
import 'package:tawzii/features/stores/screens/store_form_screen.dart';

class StoreDetailScreen extends ConsumerWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final dateFormat = DateFormat('dd/MM HH:mm');

    final storeRepo = ref.watch(storeRepositoryProvider);
    final orders = ref.watch(ordersByStoreProvider(storeId));
    final products = ref.watch(productListProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: storeRepo?.getById(storeId),
      builder: (context, storeSnap) {
        final store = storeSnap.data;
        final storeName = store?['name'] as String? ?? l10n.storeDetails;

        return Scaffold(
          appBar: AppBar(
            title: Text(storeName),
            actions: [
              if (store != null)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: l10n.edit,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreFormScreen(store: store),
                      ),
                    );
                    ref.invalidate(storeListProvider);
                  },
                ),
            ],
          ),
          body: storeSnap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : store == null
                  ? Center(child: Text(l10n.error))
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(ordersByStoreProvider(storeId));
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // --- Store Info Card ---
                          Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  if ((store['address'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _InfoRow(
                                      icon: Icons.location_on_outlined,
                                      label: l10n.address,
                                      value: store['address'] as String,
                                      theme: theme,
                                    ),
                                  if ((store['phone'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.phone_outlined,
                                      label: l10n.phone,
                                      value: store['phone'] as String,
                                      theme: theme,
                                    ),
                                  ],
                                  if ((store['contact_person'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.person_outline,
                                      label: l10n.contactPerson,
                                      value:
                                          store['contact_person'] as String,
                                      theme: theme,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(l10n.balance,
                                          style: theme.textTheme.titleSmall),
                                      Text(
                                        '${currencyFormat.format((store['credit_balance'] as num?)?.toDouble() ?? 0)} ${l10n.currencyUnit}',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: ((store['credit_balance']
                                                          as num?)
                                                      ?.toDouble() ??
                                                  0) >
                                              0
                                              ? colorScheme.error
                                              : AppColors.success,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // --- Recent Orders ---
                          _SectionHeader(
                            title: l10n.recentOrders,
                            icon: Icons.receipt_long,
                            iconColor: colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          orders.when(
                            data: (list) {
                              if (list.isEmpty) {
                                return _EmptySection(
                                    message: l10n.noOrdersForStore);
                              }
                              return Column(
                                children: list.map((order) {
                                  final total = (order['total'] as num?)
                                          ?.toDouble() ??
                                      0;
                                  final status =
                                      order['status'] as String? ??
                                          'created';
                                  final discountStatus =
                                      order['discount_status'] as String? ??
                                          'none';
                                  final createdAt = DateTime.tryParse(
                                      order['created_at'] as String? ?? '');

                                  return Card(
                                    elevation: 0,
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Icon(Icons.receipt_long,
                                          color: colorScheme.primary),
                                      title: Text(
                                        '${currencyFormat.format(total)} ${l10n.currencyUnit}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      subtitle: Text(
                                        createdAt != null
                                            ? dateFormat
                                                .format(createdAt.toLocal())
                                            : '',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      trailing: Wrap(
                                        spacing: 4,
                                        children: [
                                          _MiniChip(
                                            label: status == 'delivered'
                                                ? l10n.statusDelivered
                                                : status == 'cancelled'
                                                    ? l10n.statusCancelled
                                                    : l10n.statusCreated,
                                            color: status == 'delivered'
                                                ? AppColors.success
                                                : status == 'cancelled'
                                                    ? AppColors.error
                                                    : AppColors.primary,
                                          ),
                                          if (discountStatus != 'none')
                                            _MiniChip(
                                              label: discountStatus ==
                                                      'pending'
                                                  ? l10n.discountPending
                                                  : discountStatus ==
                                                          'approved'
                                                      ? l10n
                                                          .discountApproved
                                                      : l10n
                                                          .discountRejected,
                                              color: discountStatus ==
                                                      'pending'
                                                  ? AppColors.warning
                                                  : discountStatus ==
                                                          'approved'
                                                      ? AppColors.success
                                                      : AppColors.error,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.all(24),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            ),
                            error: (_, _) =>
                                _EmptySection(message: l10n.error),
                          ),

                          const SizedBox(height: 24),

                          // --- Recent Payments ---
                          _SectionHeader(
                            title: l10n.recentPayments,
                            icon: Icons.payments,
                            iconColor: AppColors.success,
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: ref
                                .watch(paymentRepositoryProvider)
                                ?.getByStore(storeId),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final payments = snap.data ?? [];
                              if (payments.isEmpty) {
                                return _EmptySection(
                                    message: l10n.noPaymentsForStore);
                              }
                              return Column(
                                children: payments.take(10).map((payment) {
                                  final amount = (payment['amount'] as num?)
                                          ?.toDouble() ??
                                      0;
                                  final driver = payment['users']
                                      as Map<String, dynamic>?;
                                  final driverName =
                                      driver?['name'] as String? ?? '';
                                  final createdAt = DateTime.tryParse(
                                      payment['created_at'] as String? ??
                                          '');

                                  return Card(
                                    elevation: 0,
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Icon(Icons.payments,
                                          color: AppColors.success),
                                      title: Text(
                                        '${currencyFormat.format(amount)} ${l10n.currencyUnit}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      subtitle: Text(
                                        [
                                          if (driverName.isNotEmpty)
                                            driverName,
                                          if (createdAt != null)
                                            dateFormat.format(
                                                createdAt.toLocal()),
                                        ].join(' · '),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // --- Package Balances ---
                          _SectionHeader(
                            title: l10n.packageBalances,
                            icon: Icons.inventory_2,
                            iconColor: colorScheme.tertiary,
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: ref
                                .watch(packageRepositoryProvider)
                                ?.getBalancesByStore(storeId),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final balances = snap.data ?? [];
                              if (balances.isEmpty) {
                                return _EmptySection(
                                    message: l10n.noPackageActivity);
                              }

                              // Join product names from product list
                              final productList =
                                  products.valueOrNull ?? [];
                              final productMap = {
                                for (final p in productList)
                                  p['id'] as String: p['name'] as String? ?? ''
                              };

                              return Card(
                                elevation: 0,
                                color: colorScheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (int i = 0;
                                        i < balances.length;
                                        i++) ...[
                                      ListTile(
                                        leading: Icon(Icons.inventory_2,
                                            color: colorScheme.tertiary),
                                        title: Text(
                                          productMap[balances[i]
                                                      ['product_id']] ??
                                              '${l10n.products} #${i + 1}',
                                          style:
                                              theme.textTheme.titleSmall,
                                        ),
                                        trailing: Text(
                                          '${balances[i]['balance'] ?? 0} ${l10n.packageUnit}',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            color: colorScheme.tertiary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (i < balances.length - 1)
                                        Divider(
                                          height: 1,
                                          indent: 56,
                                          color:
                                              colorScheme.outlineVariant,
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
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
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
