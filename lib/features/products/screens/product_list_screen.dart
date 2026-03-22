import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/purchase_orders/screens/purchase_order_list_screen.dart';
import 'package:tawzii/features/suppliers/screens/supplier_list_screen.dart';
import '../providers/product_provider.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: l10n.suppliers,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SupplierListScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: l10n.purchaseOrders,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PurchaseOrderListScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProductFormScreen(),
            ),
          );
          ref.invalidate(productListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('خطأ في تحميل المنتجات', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(productListProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('لا توجد منتجات',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('اضغط + لإضافة منتج جديد',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(productListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  .copyWith(bottom: 80),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                final hasPackaging = p['has_returnable_packaging'] == true;
                final unitsPerPkg = p['units_per_package'];
                final costPrice = (p['cost_price'] as num?)?.toDouble();
                final sellPrice = (p['unit_price'] as num?)?.toDouble() ?? 0;
                final margin = costPrice != null ? sellPrice - costPrice : null;
                final marginPct = (costPrice != null && costPrice > 0)
                    ? (margin! / costPrice * 100).toStringAsFixed(0)
                    : null;
                final stockOnHand = (p['stock_on_hand'] as num?)?.toInt() ?? 0;
                final lowStockThreshold =
                    (p['low_stock_threshold'] as num?)?.toInt() ?? 0;
                final isLowStock =
                    lowStockThreshold > 0 && stockOnHand <= lowStockThreshold;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        hasPackaging ? Icons.inventory_2 : Icons.shopping_bag,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(p['name'] ?? ''),
                    subtitle: Text(
                      costPrice != null
                          ? '${l10n.sellPrice}: $sellPrice د.ج · ${l10n.costPrice}: $costPrice د.ج'
                          : '${p['unit_price']} د.ج${unitsPerPkg != null ? ' · $unitsPerPkg وحدة/عبوة' : ''}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      direction: Axis.vertical,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLowStock
                                ? AppColors.error.withValues(alpha: 0.12)
                                : AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_outlined,
                                size: 12,
                                color: isLowStock
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$stockOnHand',
                                style: TextStyle(
                                  color: isLowStock
                                      ? AppColors.error
                                      : AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (marginPct != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: margin! >= 0
                                  ? AppColors.success
                                      .withValues(alpha: 0.12)
                                  : AppColors.error
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$marginPct%',
                              style: TextStyle(
                                color: margin >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (hasPackaging)
                          Chip(
                            label: const Text('قابل للإرجاع'),
                            labelStyle: theme.textTheme.labelSmall,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductFormScreen(product: p),
                        ),
                      );
                      ref.invalidate(productListProvider);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
