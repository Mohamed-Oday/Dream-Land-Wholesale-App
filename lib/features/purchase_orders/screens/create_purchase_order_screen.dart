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
  int quantity; // number of packages

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
  bool _isLoading = false;

  double get _totalCost =>
      _lineItems.fold(0, (sum, item) => sum + item.lineTotal);

  bool get _canSubmit =>
      _selectedSupplierId != null && _lineItems.isNotEmpty && !_isLoading;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _showSupplierPicker(
      BuildContext context, List<Map<String, dynamic>> suppliers) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.selectSupplier,
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(),
            ...suppliers.map((s) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.primaryContainer,
                    child: Icon(Icons.local_shipping,
                        color:
                            Theme.of(ctx).colorScheme.onPrimaryContainer),
                  ),
                  title: Text(s['name'] ?? ''),
                  subtitle: (s['phone'] ?? '').toString().isNotEmpty
                      ? Text(s['phone'] as String)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showProductPicker(BuildContext context) {
    final products = ref.read(productListProvider).valueOrNull ?? [];
    if (products.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.addProducts,
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      final costPrice =
                          (p['cost_price'] as num?)?.toDouble();
                      final unitPrice =
                          (p['unit_price'] as num?)?.toDouble() ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(ctx)
                              .colorScheme
                              .primaryContainer,
                          child: Icon(Icons.shopping_bag,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onPrimaryContainer),
                        ),
                        title: Text(p['name'] ?? ''),
                        subtitle: Text(
                          costPrice != null
                              ? '${l10n.costPrice}: $costPrice د.ج'
                              : '${p['unit_price']} د.ج',
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _addProduct(
                            p['id'] as String,
                            p['name'] as String? ?? '',
                            costPrice ?? unitPrice,
                            (p['units_per_package'] as num?)?.toInt(),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addProduct(
      String productId, String name, double costPerUnit, int? unitsPerPkg) {
    setState(() {
      final existing = _lineItems
          .where((item) => item.productId == productId)
          .toList();
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        _lineItems.add(_PurchaseLineItem(
          productId: productId,
          productName: name,
          costPerUnit: costPerUnit,
          unitsPerPackage: unitsPerPkg,
          quantity: 1,
        ));
      }
    });
  }

  Future<void> _save() async {
    if (!_canSubmit) return;
    if (_isLoading) return;

    final l10n = AppLocalizations.of(context)!;
    final currencyFormat = NumberFormat('#,##0.00', 'ar');

    // Confirmation dialog
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPurchaseOrder)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Supplier Selector ---
            suppliers.when(
              data: (list) => FormField<String>(
                initialValue: _selectedSupplierId,
                validator: (v) => v == null ? 'مطلوب' : null,
                builder: (field) => InkWell(
                  onTap: _isLoading
                      ? null
                      : () async {
                          final selected =
                              await _showSupplierPicker(context, list);
                          if (selected != null) {
                            setState(() {
                              _selectedSupplierId =
                                  selected['id'] as String;
                              _selectedSupplierName =
                                  selected['name'] as String? ?? '';
                            });
                            field.didChange(selected['id'] as String);
                          }
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.selectSupplier,
                      prefixIcon: const Icon(Icons.local_shipping),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
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
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.error),
            ),

            const SizedBox(height: 24),

            // --- Line Items Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.products,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: _isLoading
                      ? null
                      : () => _showProductPicker(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addProducts),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Line Items List ---
            if (_lineItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    l10n.addProducts,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_lineItems.length, (i) {
                final item = _lineItems[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.productName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant),
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(
                                      () => _lineItems.removeAt(i)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Quantity controls
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 22),
                              onPressed: _isLoading || item.quantity <= 1
                                  ? null
                                  : () => setState(() => item.quantity--),
                              visualDensity: VisualDensity.compact,
                            ),
                            SizedBox(
                              width: 48,
                              child: TextField(
                                controller: TextEditingController(
                                    text: '${item.quantity}'),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: [
                                    const FontFeature.tabularFigures()
                                  ],
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !_isLoading,
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n > 0) {
                                    setState(() => item.quantity = n);
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 22),
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() => item.quantity++),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            // Package cost
                            Text('× ${currencyFormat.format(item.packageCost)} د.ج',
                                style: theme.textTheme.bodySmall),
                            const Spacer(),
                            // Line total
                            Text(
                              '${currencyFormat.format(item.lineTotal)} د.ج',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

            // --- Total ---
            if (_lineItems.isNotEmpty) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.totalCost,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    '${currencyFormat.format(_totalCost)} د.ج',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // --- Notes ---
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

            // --- Save Button ---
            FilledButton(
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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
