import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/features/purchase_orders/screens/procurement_hub_screen.dart';
import 'package:tawzii/core/utils/package_stock.dart';
import '../providers/product_provider.dart';
import 'product_detail_screen.dart';
import 'product_form_sheet.dart';

enum _StockFilter { all, low, out }

/// 5d — المنتجات: cost/sell pair on the row, stock is the loud number.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() =>
      _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();
  _StockFilter _filter = _StockFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static bool _isLow(Map<String, dynamic> p) {
    final stock = stockOf(p);
    final threshold = (p['low_stock_threshold'] as num?)?.toDouble() ?? 0;
    return threshold > 0 && !_isOut(p) && stock <= threshold;
  }

  static bool _isOut(Map<String, dynamic> p) =>
      isOutOfStock(stockOf(p), (p['units_per_package'] as num?)?.toInt());

  Future<void> _openCreate() async {
    final created = await showProductFormSheet(context);
    if (created == true) ref.invalidate(productListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: l10n.purchaseOrders,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProcurementHubScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productListProvider);
          await ref.read(productListProvider.future);
        },
        child: productsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(18),
            children: const [SurfaceCard(child: SkeletonList(count: 7))],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(18),
            children: [
              SurfaceCard(
                child: ErrorRetryRow(
                  onRetry: () => ref.invalidate(productListProvider),
                ),
              ),
            ],
          ),
          data: (products) {
            final lowCount = products.where(_isLow).length;
            final outCount = products.where(_isOut).length;

            final query = _searchController.text.trim().toLowerCase();
            var visible = query.isEmpty
                ? products
                : products
                    .where((p) => (p['name'] as String? ?? '')
                        .toLowerCase()
                        .contains(query))
                    .toList();
            visible = switch (_filter) {
              _StockFilter.all => visible,
              _StockFilter.low => visible.where(_isLow).toList(),
              _StockFilter.out => visible.where(_isOut).toList(),
            };

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 96),
              children: [
                TextField(
                  controller: _searchController,
                  decoration:
                      const InputDecoration(hintText: 'ابحث عن منتج…'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _FilterChip(
                      label: 'الكل · \u2066${products.length}\u2069',
                      selected: _filter == _StockFilter.all,
                      onTap: () =>
                          setState(() => _filter = _StockFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'منخفض · \u2066$lowCount\u2069',
                      selected: _filter == _StockFilter.low,
                      warning: true,
                      onTap: () =>
                          setState(() => _filter = _StockFilter.low),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'نفذ · \u2066$outCount\u2069',
                      selected: _filter == _StockFilter.out,
                      onTap: () =>
                          setState(() => _filter = _StockFilter.out),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (products.isEmpty)
                  EmptyState(
                    title: 'لا توجد منتجات',
                    message: 'أضف أول منتج لبدء إدارة المخزون',
                    ctaLabel: 'إضافة منتج',
                    onCta: _openCreate,
                  )
                else if (visible.isEmpty)
                  const EmptyState(
                    title: 'لا نتائج',
                    message: 'جرّب كلمة بحث أو تصفية أخرى',
                  )
                else
                  SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < visible.length; i++)
                          _ProductRow(
                            product: visible[i],
                            showDivider: i < visible.length - 1,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                      product: visible[i]),
                                ),
                              );
                              ref.invalidate(productListProvider);
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Low-stock chip: mustard text when unselected (warning ≠ accent).
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selected
          ? (isDark ? t.surfaceAlt : t.surface)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: selected && !isDark
            ? BorderSide(color: t.borderStrong)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
          alignment: AlignmentDirectional.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? t.textPrimary
                  : (warning ? t.warning : t.textMuted),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.showDivider,
    required this.onTap,
  });

  final Map<String, dynamic> product;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final costPrice = (product['cost_price'] as num?)?.toDouble();
    final sellPrice = (product['unit_price'] as num?)?.toDouble() ?? 0;
    final stock = stockOf(product);
    final threshold =
        (product['low_stock_threshold'] as num?)?.toDouble() ?? 0;
    final isOut = isOutOfStock(
        stock, (product['units_per_package'] as num?)?.toInt());
    final isLow = !isOut && threshold > 0 && stock <= threshold;

    final subtitleStyle = TextStyle(fontSize: 12, color: t.textMuted);
    final subtitleNumber = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: t.textMuted,
    );

    final row = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product['name'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (costPrice != null) ...[
                        Text('شراء ', style: subtitleStyle),
                        Money(costPrice,
                            showUnit: false,
                            color: t.textMuted,
                            numberStyle: subtitleNumber),
                        Text(' · ', style: subtitleStyle),
                      ],
                      Text('بيع ', style: subtitleStyle),
                      Money(sellPrice,
                          showUnit: false,
                          color: t.textMuted,
                          numberStyle: subtitleNumber),
                      if (product['has_returnable_packaging'] == true)
                        Text(' · قابل للإرجاع', style: subtitleStyle),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u2066${formatStockNumber(stock)}\u2069',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isOut
                        ? t.danger
                        : (isLow ? t.warning : t.textPrimary),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text('مخزون',
                    style: TextStyle(fontSize: 11, color: t.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );

    if (!showDivider) return row;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Divider(height: 1, thickness: 1, color: t.border),
        ),
      ],
    );
  }
}
