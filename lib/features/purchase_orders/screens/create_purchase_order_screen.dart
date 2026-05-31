import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../providers/purchase_order_provider.dart';
import 'purchase_order_detail_screen.dart';

class _PurchaseLineItem {
  final String productId;
  final String productName;
  final double costPerUnit;
  final int? unitsPerPackage;
  int quantity;

  _PurchaseLineItem({
    required this.productId,
    required this.productName,
    required this.costPerUnit,
    this.unitsPerPackage,
    required this.quantity,
  });

  double get packageCost => costPerUnit * (unitsPerPackage ?? 1);
  double get lineTotal => packageCost * quantity;
}

class CreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  ConsumerState<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState
    extends ConsumerState<CreatePurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSupplierId;
  String _selectedSupplierName = '';
  final List<_PurchaseLineItem> _lineItems = [];
  final _notesController = TextEditingController();
  final Map<String, TextEditingController> _qtyControllers = {};
  bool _isLoading = false;

  double get _totalCost =>
      _lineItems.fold(0, (sum, item) => sum + item.lineTotal);

  bool get _canSubmit =>
      _selectedSupplierId != null && _lineItems.isNotEmpty && !_isLoading;

  @override
  void dispose() {
    _notesController.dispose();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>?> _showSupplierPicker(
      BuildContext context, List<Map<String, dynamic>> suppliers) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(ctx);
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = searchController.text.isEmpty
                ? suppliers
                : suppliers.where((s) {
                    final name = (s['name'] as String).toLowerCase();
                    return name
                        .contains(searchController.text.toLowerCase());
                  }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l10n.selectSupplier,
                        style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      textAlign: TextAlign.start,
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم المورد...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final s = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            child: Icon(Icons.local_shipping,
                                color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(s['name'] ?? ''),
                          subtitle: (s['phone'] ?? '')
                                  .toString()
                                  .isNotEmpty
                              ? Text(s['phone'] as String)
                              : null,
                          onTap: () => Navigator.pop(ctx, s),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _getQuantity(String productId) {
    for (final item in _lineItems) {
      if (item.productId == productId) return item.quantity;
    }
    return 0;
  }

  void _setQuantity(
    String productId,
    int qty,
    int maxStock,
    Map<String, dynamic> product,
  ) {
    final clamped = qty.clamp(0, maxStock);
    final costPrice = (product['cost_price'] as num?)?.toDouble();
    final unitPrice = (product['unit_price'] as num?)?.toDouble() ?? 0;
    final price = costPrice ?? unitPrice;

    setState(() {
      if (clamped > 0) {
        final existingIndex =
            _lineItems.indexWhere((item) => item.productId == productId);
        if (existingIndex >= 0) {
          _lineItems[existingIndex].quantity = clamped;
        } else {
          _lineItems.add(_PurchaseLineItem(
            productId: productId,
            productName: product['name'] ?? '',
            costPerUnit: price,
            unitsPerPackage: (product['units_per_package'] as num?)?.toInt(),
            quantity: clamped,
          ));
        }
      } else {
        _lineItems.removeWhere((item) => item.productId == productId);
      }
      _qtyControllers[productId]?.text = '$clamped';
    });
  }

  void _removeItem(int index) {
    final productId = _lineItems[index].productId;
    setState(() {
      _lineItems.removeAt(index);
      _qtyControllers[productId]?.text = '0';
    });
  }

  Future<void> _save() async {
    if (!_canSubmit) return;
    if (_isLoading) return;

    final l10n = AppLocalizations.of(context)!;
    final currencyFormat = NumberFormat('#,##0.00', 'ar');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmPurchase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.supplier}: $_selectedSupplierName'),
            Text(
                '${l10n.items}: ${_lineItems.length} ${l10n.products.toLowerCase()}'),
            const SizedBox(height: 8),
            Text(
              '${l10n.totalCost}: ${currencyFormat.format(_totalCost)} د.ج',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(purchaseOrderRepositoryProvider)!;
      final user = ref.read(currentUserProvider)!;

      final lineItemMaps = _lineItems
          .map((item) => {
                'product_id': item.productId,
                'quantity': item.quantity,
                'unit_cost': item.packageCost,
                'line_total': item.lineTotal,
              })
          .toList();

      final result = await repo.create(
        supplierId: _selectedSupplierId!,
        createdBy: user.id,
        totalCost: _totalCost,
        lineItems: lineItemMaps,
        notes: _notesController.text.trim(),
      );

      ref.invalidate(purchaseOrderListProvider);
      ref.invalidate(productListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseCreated),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PurchaseOrderDetailScreen(
              purchaseOrderId: result['id'] as String,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final suppliers = ref.watch(supplierListProvider);
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPurchaseOrder)),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Supplier selector
                    suppliers.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => Text(l10n.error),
                      data: (list) => FormField<String>(
                        initialValue: _selectedSupplierId,
                        validator: (v) => v == null ? 'مطلوب' : null,
                        builder: (field) => InkWell(
                          onTap: _isLoading
                              ? null
                              : () async {
                                  final selected =
                                      await _showSupplierPicker(
                                          context, list);
                                  if (selected != null) {
                                    setState(() {
                                      _selectedSupplierId =
                                          selected['id'] as String;
                                      _selectedSupplierName =
                                          selected['name'] as String? ?? '';
                                    });
                                    field.didChange(
                                        selected['id'] as String);
                                  }
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.selectSupplier,
                              prefixIcon:
                                  const Icon(Icons.local_shipping),
                              suffixIcon:
                                  const Icon(Icons.arrow_drop_down),
                              errorText: field.errorText,
                            ),
                            child: Text(
                              _selectedSupplierName.isEmpty
                                  ? ''
                                  : _selectedSupplierName,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product grid
                    productsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text(l10n.error)),
                      data: (products) {
                        if (products.isEmpty) {
                          return Center(
                            child: Text(
                              l10n.noData,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            final productId = p['id'] as String;
                            final stock =
                                (p['stock_on_hand'] as num?)?.toInt() ?? 0;
                            final isDisabled = stock <= 0;
                            final currentQty = _getQuantity(productId);
                            final costPrice =
                                (p['cost_price'] as num?)?.toDouble();
                            final unitPrice =
                                (p['unit_price'] as num?)?.toDouble() ?? 0;
                            final price = costPrice ?? unitPrice;
                            final upkg =
                                p['units_per_package'] as int?;
                            final packagePrice =
                                upkg != null ? price * upkg : price;

                            final controller = _qtyControllers
                                .putIfAbsent(
                              productId,
                              () => TextEditingController(
                                  text: '$currentQty'),
                            );

                            return Opacity(
                              opacity: isDisabled ? 0.5 : 1.0,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: currentQty > 0
                                      ? BorderSide(
                                          color:
                                              theme.colorScheme.primary,
                                          width: 2,
                                        )
                                      : BorderSide.none,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['name'] ?? '',
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: theme
                                                  .textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${packagePrice.toStringAsFixed(2)} د.ج',
                                              style: theme
                                                  .textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .primary,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                            if (upkg != null)
                                              Text(
                                                '$upkg وحدة/عبوة',
                                                style: theme.textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            const Spacer(),
                                            if (stock <= 0)
                                              Text(
                                                'نفذ',
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.error,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              )
                                            else
                                              Text(
                                                'مخزون: $stock',
                                                style: TextStyle(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (!isDisabled)
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons
                                                      .remove_circle_outline,
                                                  size: 20),
                                              onPressed: currentQty > 0
                                                  ? () => _setQuantity(
                                                        productId,
                                                        currentQty - 1,
                                                        stock,
                                                        p,
                                                      )
                                                  : null,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                controller: controller,
                                                textAlign:
                                                    TextAlign.center,
                                                keyboardType:
                                                    TextInputType.number,
                                                enabled: !_isLoading,
                                                decoration:
                                                    const InputDecoration(
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          vertical: 4),
                                                  border:
                                                      OutlineInputBorder(),
                                                ),
                                                onSubmitted: (v) {
                                                  final n = int.tryParse(
                                                          v) ??
                                                      0;
                                                  _setQuantity(
                                                    productId,
                                                    n,
                                                    stock,
                                                    p,
                                                  );
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 20),
                                              onPressed: currentQty <
                                                      stock
                                                  ? () => _setQuantity(
                                                        productId,
                                                        currentQty + 1,
                                                        stock,
                                                        p,
                                                      )
                                                  : null,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Selected items summary
                    if (_lineItems.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      ...List.generate(_lineItems.length, (i) {
                        final item = _lineItems[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.productName,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.quantity} × ${currencyFormat.format(item.packageCost)}',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: theme.colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${currencyFormat.format(item.lineTotal)} د.ج',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 18,
                                    color: theme.colorScheme.error),
                                onPressed: () => _removeItem(i),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.totalCost,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600)),
                          Text(
                            '${currencyFormat.format(_totalCost)} د.ج',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              fontFeatures: [
                                const FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      enabled: !_isLoading,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.purchaseNotes,
                        prefixIcon: const Icon(Icons.notes_outlined),
                        hintText: 'اختياري',
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(16).copyWith(top: 8),
              child: FilledButton(
                onPressed: _canSubmit ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.confirmPurchase,
                        style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
