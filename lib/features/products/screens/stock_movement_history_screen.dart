import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../providers/product_provider.dart';

class StockMovementHistoryScreen extends ConsumerWidget {
  final String productId;
  final String productName;

  const StockMovementHistoryScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final movementsAsync = ref.watch(stockMovementsProvider(productId));
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stockMovements)),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(stockMovementsProvider(productId)),
        child: movementsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.error, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(stockMovementsProvider(productId)),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
          data: (movements) {
            if (movements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(l10n.noStockMovements,
                        style: theme.textTheme.titleMedium),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: movements.length,
              itemBuilder: (context, index) {
                final m = movements[index];
                final type = m['movement_type'] as String? ?? '';
                final quantity = (m['quantity'] as num?)?.toInt() ?? 0;
                final notes = m['notes'] as String? ?? '';
                final createdAt =
                    DateTime.tryParse(m['created_at'] as String? ?? '');
                final user = m['users'] as Map<String, dynamic>?;
                final userName = user?['name'] as String? ?? '';

                final typeInfo = _getTypeInfo(l10n, type);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          typeInfo.color.withValues(alpha: 0.15),
                      child: Icon(typeInfo.icon, color: typeInfo.color,
                          size: 20),
                    ),
                    title: Text(typeInfo.label,
                        style: theme.textTheme.titleSmall),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (createdAt != null)
                          Text(
                            '${dateFormat.format(createdAt.toLocal())} · $userName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (notes.isNotEmpty)
                          Text(
                            notes,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: Text(
                      quantity >= 0 ? '+$quantity' : '$quantity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: quantity >= 0
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  _TypeInfo _getTypeInfo(AppLocalizations l10n, String type) {
    switch (type) {
      case 'order_out':
        return _TypeInfo(
          label: l10n.movementOrderOut,
          icon: Icons.arrow_downward,
          color: AppColors.error,
        );
      case 'purchase_in':
        return _TypeInfo(
          label: l10n.movementPurchaseIn,
          icon: Icons.arrow_upward,
          color: AppColors.success,
        );
      case 'cancellation_restore':
        return _TypeInfo(
          label: l10n.movementCancellationRestore,
          icon: Icons.undo,
          color: Colors.blue,
        );
      case 'adjustment':
        return _TypeInfo(
          label: l10n.movementAdjustment,
          icon: Icons.tune,
          color: Colors.orange,
        );
      default:
        return _TypeInfo(
          label: type,
          icon: Icons.help_outline,
          color: Colors.grey,
        );
    }
  }
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;

  const _TypeInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}
