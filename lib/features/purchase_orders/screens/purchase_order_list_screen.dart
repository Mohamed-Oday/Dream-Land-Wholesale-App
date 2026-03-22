import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/widgets/date_range_filter_bar.dart';
import '../providers/purchase_order_provider.dart';
import 'create_purchase_order_screen.dart';
import 'purchase_order_detail_screen.dart';

class PurchaseOrderListScreen extends ConsumerWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final posAsync = ref.watch(purchaseOrderListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseOrders)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePurchaseOrderScreen(),
            ),
          );
          ref.invalidate(purchaseOrderListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const DateRangeFilterBar(),
          Expanded(
            child: posAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.error, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.invalidate(purchaseOrderListProvider),
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
                        Icon(Icons.shopping_cart_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(l10n.noPurchaseOrders,
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(purchaseOrderListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)
                        .copyWith(bottom: 80),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final po = orders[index];
                      final supplier =
                          po['suppliers'] as Map<String, dynamic>?;
                      final supplierName =
                          supplier?['name'] as String? ?? '';
                      final totalCost =
                          (po['total_cost'] as num?)?.toDouble() ?? 0;
                      final lines =
                          po['purchase_order_lines'] as List<dynamic>? ??
                              [];
                      final createdAt =
                          po['created_at'] as String?;

                      String formattedDate = '';
                      if (createdAt != null) {
                        try {
                          final dt =
                              DateTime.parse(createdAt).toLocal();
                          formattedDate = dateFormat.format(dt);
                        } catch (_) {
                          formattedDate = createdAt;
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PurchaseOrderDetailScreen(
                                purchaseOrderId:
                                    po['id'] as String,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      colorScheme.primaryContainer,
                                  child: Icon(Icons.shopping_cart,
                                      color: colorScheme
                                          .onPrimaryContainer),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supplierName,
                                        style: theme
                                            .textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$formattedDate · ${lines.length} ${l10n.items}',
                                        style: theme
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          color: colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${currencyFormat.format(totalCost)} د.ج',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      const FontFeature
                                          .tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
