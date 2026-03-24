import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/dashboard/providers/dashboard_provider.dart';
import 'package:tawzii/features/orders/screens/receipt_preview_screen.dart';
import 'package:tawzii/features/stores/screens/store_detail_screen.dart';
import 'package:tawzii/features/driver_loads/screens/load_list_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recentOrders = ref.watch(recentOrdersProvider);
    final debtors = ref.watch(topDebtorsProvider);
    final alerts = ref.watch(packageAlertsProvider);

    final numberFormat = NumberFormat('#,##0', 'ar');
    final currencyFormat = NumberFormat('#,##0.00', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping),
            tooltip: l10n.driverLoads,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoadListScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentOrdersProvider);
          ref.invalidate(topDebtorsProvider);
          ref.invalidate(packageAlertsProvider);
          await ref.read(recentOrdersProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Recent Orders Section ---
            _SectionHeader(
              title: l10n.recentOrders,
              icon: Icons.receipt_long_outlined,
              iconColor: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            recentOrders.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: l10n.noOrders,
                    color: colorScheme.onSurfaceVariant,
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
                      for (int i = 0; i < orders.length; i++) ...[
                        _OrderTile(
                          order: orders[i],
                          currencyFormat: currencyFormat,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReceiptPreviewScreen(
                                orderId: orders[i]['id'] as String,
                              ),
                            ),
                          ),
                        ),
                        if (i < orders.length - 1)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: colorScheme.outlineVariant,
                          ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => _buildShimmerList(context, 3),
              error: (_, _) => _buildErrorSection(context, l10n.retry, () {
                ref.invalidate(recentOrdersProvider);
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
                            backgroundColor: colorScheme.errorContainer,
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
                          Divider(
                            height: 1,
                            indent: 72,
                            color: colorScheme.outlineVariant,
                          ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => _buildShimmerList(context, 3),
              error: (_, _) => _buildErrorSection(context, l10n.retry, () {
                ref.invalidate(topDebtorsProvider);
              }),
            ),

            const SizedBox(height: 24),

            // --- Package Alerts Section ---
            Row(
              children: [
                Expanded(
                  child: _SectionHeader(
                    title:
                        '${l10n.packageAlerts} (>${ref.watch(packageAlertThresholdProvider)})',
                    icon: Icons.inventory_2_outlined,
                    iconColor: colorScheme.tertiary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.tune,
                      size: 20, color: colorScheme.onSurfaceVariant),
                  tooltip: l10n.alertThreshold,
                  onPressed: () => _showThresholdDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            alerts.when(
              data: (stores) {
                final threshold = ref.watch(packageAlertThresholdProvider);
                final filtered = stores
                    .where(
                        (s) => _toInt(s['total_outstanding']) >= threshold)
                    .toList();
                if (filtered.isEmpty) {
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
                      for (int i = 0; i < filtered.length; i++) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.tertiaryContainer,
                            radius: 20,
                            child: Icon(
                              Icons.inventory_2,
                              color: colorScheme.onTertiaryContainer,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            filtered[i]['store_name'] as String? ?? '',
                            style: theme.textTheme.titleSmall,
                          ),
                          trailing: Text(
                            '${numberFormat.format(_toInt(filtered[i]['total_outstanding']))} ${l10n.packageUnit}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (i < filtered.length - 1)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: colorScheme.outlineVariant,
                          ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => _buildShimmerList(context, 3),
              error: (_, _) => _buildErrorSection(context, l10n.retry, () {
                ref.invalidate(packageAlertsProvider);
              }),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showThresholdDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(packageAlertThresholdProvider);
    final controller = TextEditingController(text: '$current');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.alertThreshold),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.alertThreshold,
            suffixText: l10n.packageUnit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 1) {
                ref.read(packageAlertThresholdProvider.notifier).state = value;
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
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
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.5),
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
                    color:
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
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

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _OrderTile({
    required this.order,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final store = order['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] as String? ?? '';
    final driverData = order['users'] as Map<String, dynamic>?;
    final driverName = driverData?['name'] as String? ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? 'created';
    final createdAt = order['created_at'] as String?;

    String timeAgo = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes} د';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours} س';
        } else {
          timeAgo = DateFormat('dd/MM HH:mm').format(dt);
        }
      } catch (_) {
        timeAgo = createdAt;
      }
    }

    final l10n = AppLocalizations.of(context)!;

    // Status chip colors matching order_list_screen pattern
    final Color statusBg;
    final Color statusFg;
    final String statusLabel;
    switch (status) {
      case 'delivered':
        statusBg = AppColors.success.withValues(alpha: 0.12);
        statusFg = AppColors.success;
        statusLabel = l10n.statusDelivered;
      case 'cancelled':
        statusBg = AppColors.error.withValues(alpha: 0.12);
        statusFg = AppColors.error;
        statusLabel = l10n.statusCancelled;
      default:
        statusBg = AppColors.primary.withValues(alpha: 0.12);
        statusFg = AppColors.primary;
        statusLabel = l10n.statusCreated;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        radius: 20,
        child: Icon(
          Icons.store,
          color: colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        storeName,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '$driverName · $timeAgo',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${currencyFormat.format(total)} ${l10n.currencyUnit}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusFg,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
