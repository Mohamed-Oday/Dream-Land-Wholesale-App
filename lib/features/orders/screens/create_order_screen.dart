import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/utils/order_calculator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../models/line_item.dart';
import '../providers/order_provider.dart';
import 'receipt_preview_screen.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStoreId;
  String _selectedStoreName = '';
  final List<LineItem> _lineItems = [];
  final _discountController = TextEditingController();
  bool _isLoading = false;
  bool _showDiscount = false;

  double get _subtotal => calculateSubtotal(_lineItems);

  double get _taxPercentage => 0;

  double get _taxAmount => calculateTax(_subtotal, _taxPercentage);

  double get _discountAmount => parseDiscount(_discountController.text);

  double get _total => calculateTotal(_subtotal, _taxAmount, _discountAmount);

  bool get _hasDiscount => _discountAmount > 0;

  bool get _canSubmit =>
      _selectedStoreId != null && _lineItems.isNotEmpty && !_isLoading;

  Future<Map<String, dynamic>?> _showStorePicker(
      BuildContext context, List<Map<String, dynamic>> stores) {
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
                color: Theme.of(ctx).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.selectStore,
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(),
            ...stores.map((s) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.primaryContainer,
                    child: Icon(Icons.store,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onPrimaryContainer),
                  ),
                  title: Text(s['name'] ?? ''),
                  subtitle: (s['address'] ?? '').toString().isNotEmpty
                      ? Text(s['address'] as String)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showProductPicker() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return Consumer(
              builder: (ctx, ref, _) {
                final productsAsync = ref.watch(productListProvider);
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.addProduct,
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: productsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text(l10n.error)),
                        data: (products) => ListView.builder(
                          controller: scrollController,
                          itemCount: products.length,
                          itemBuilder: (_, index) {
                            final p = products[index];
                            final stock = (p['stock_on_hand'] as num?)?.toInt() ?? 0;
                            final isOutOfStock = stock <= 0;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isOutOfStock
                                    ? Theme.of(ctx).colorScheme.errorContainer
                                    : Theme.of(ctx).colorScheme.primaryContainer,
                                child: Icon(Icons.shopping_bag,
                                    color: isOutOfStock
                                        ? Theme.of(ctx).colorScheme.onErrorContainer
                                        : Theme.of(ctx).colorScheme.onPrimaryContainer),
                              ),
                              title: Text(
                                p['name'] ?? '',
                                style: isOutOfStock
                                    ? TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)
                                    : null,
                              ),
                              subtitle: Text(() {
                                final price = (p['unit_price'] as num).toDouble();
                                final upkg = p['units_per_package'] as int?;
                                final stockLabel = 'المخزون: $stock';
                                if (upkg != null) {
                                  return '${(price * upkg).toStringAsFixed(2)} د.ج/عبوة · $stockLabel';
                                }
                                return '${price.toStringAsFixed(2)} د.ج · $stockLabel';
                              }()),
                              trailing: isOutOfStock
                                  ? Text('نفذ',
                                      style: TextStyle(
                                        color: Theme.of(ctx).colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ))
                                  : null,
                              enabled: !isOutOfStock,
                              onTap: isOutOfStock
                                  ? null
                                  : () {
                                      _addProduct(p);
                                      Navigator.pop(ctx);
                                    },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _addProduct(Map<String, dynamic> product) {
    final stock = (product['stock_on_hand'] as num?)?.toInt() ?? 0;

    // Block if out of stock
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نفذ المخزون'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      final existingIndex = _lineItems
          .indexWhere((item) => item.productId == product['id']);
      if (existingIndex >= 0) {
        // Block if already at stock limit
        if (_lineItems[existingIndex].quantity >= stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('الكمية المتاحة: $stock فقط'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _lineItems[existingIndex].quantity++;
      } else {
        _lineItems.add(LineItem(
          productId: product['id'],
          productName: product['name'] ?? '',
          unitPrice: (product['unit_price'] as num).toDouble(),
          quantity: 1,
          unitsPerPackage: product['units_per_package'] as int?,
          hasReturnablePackaging:
              product['has_returnable_packaging'] == true,
          stockOnHand: stock,
        ));
      }
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  void _removeItem(int index) {
    setState(() => _lineItems.removeAt(index));
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final item = _lineItems[index];
      final newQty = item.quantity + delta;
      if (newQty >= 1 && newQty <= item.stockOnHand) {
        item.quantity = newQty;
      } else if (newQty > item.stockOnHand) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الكمية المتاحة: ${item.stockOnHand} فقط'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _confirmAndSubmit() async {
    if (!_formKey.currentState!.validate() || !_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmOrderTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmOrderMessage),
            const SizedBox(height: 16),
            _SummaryRow(
                label: l10n.stores, value: _selectedStoreName),
            _SummaryRow(
                label: l10n.items,
                value: '${_lineItems.length}'),
            const Divider(),
            _SummaryRow(
              label: l10n.total,
              value: '${_total.toStringAsFixed(2)} د.ج',
              bold: true,
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

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(orderRepositoryProvider)!;

      final lineItemMaps = _lineItems.map((item) => {
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.packagePrice,
            'line_total': item.lineTotal,
          }).toList();

      // Single atomic RPC — order, lines, balance, packages, stock all in one transaction
      final orderData = await repo.create(
        storeId: _selectedStoreId!,
        subtotal: _subtotal,
        taxPercentage: _taxPercentage,
        taxAmount: _taxAmount,
        discount: _discountAmount,
        discountStatus: _hasDiscount ? 'pending' : 'none',
        total: _total,
        lineItems: lineItemMaps,
      );

      if (!mounted) return;

      // Add line items to order data for receipt display
      orderData['order_lines'] = _lineItems
          .map((item) => {
                'products': {
                  'name': item.productName,
                  'units_per_package': item.unitsPerPackage,
                  'unit_price': item.unitPrice,
                },
                'quantity': item.quantity,
                'unit_price': item.packagePrice,
                'line_total': item.lineTotal,
              })
          .toList();

      ref.invalidate(productListProvider);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptPreviewScreen(orderData: orderData),
        ),
      );
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.networkError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Order save PostgrestException: ${e.message} / ${e.details}');
      if (mounted) {
        // Deactivated user: RLS denies all access → show clear message + sign out
        final msg = e.message;
        if (msg.contains('permission denied') || msg.contains('new row violates row-level security')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم تعطيل حسابك — تواصل مع المالك'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          ref.read(authServiceProvider).signOut();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.saveError}: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Order save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.saveError}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final storesAsync = ref.watch(storeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newOrder)),
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
                    // Store selector — tap to pick from bottom sheet
                    storesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text(l10n.error),
                      data: (stores) => FormField<String>(
                        initialValue: _selectedStoreId,
                        validator: (v) => v == null ? 'مطلوب' : null,
                        builder: (field) {
                          return InkWell(
                            onTap: _isLoading
                                ? null
                                : () async {
                                    final selected =
                                        await _showStorePicker(context, stores);
                                    if (selected != null) {
                                      setState(() {
                                        _selectedStoreId =
                                            selected['id'] as String;
                                        _selectedStoreName =
                                            selected['name'] ?? '';
                                      });
                                      field.didChange(
                                          selected['id'] as String);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.selectStore,
                                prefixIcon: const Icon(Icons.store),
                                suffixIcon:
                                    const Icon(Icons.arrow_drop_down),
                                errorText: field.errorText,
                              ),
                              child: Text(
                                _selectedStoreName.isEmpty
                                    ? ''
                                    : _selectedStoreName,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Line items header + add button
                    Row(
                      children: [
                        Text(l10n.products,
                            style: theme.textTheme.titleSmall),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _showProductPicker,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.addProduct),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Line items
                    if (_lineItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            l10n.addProduct,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
                              children: [
                                // Product name + package info + price
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w500),
                                          ),
                                          if (item.unitsPerPackage != null)
                                            Text(
                                              '${item.unitsPerPackage} وحدة/عبوة'
                                              '${item.totalPieces != null ? ' · ${item.totalPieces} وحدة' : ''}',
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item.packagePrice.toStringAsFixed(2)} د.ج/عبوة',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        if (item.unitsPerPackage != null)
                                          Text(
                                            '${item.unitPrice.toStringAsFixed(2)} د.ج/وحدة',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Quantity controls + line total
                                Row(
                                  children: [
                                    // Quantity controls
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: theme
                                                .colorScheme.outlineVariant),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove,
                                                size: 18),
                                            onPressed: item.quantity > 1
                                                ? () =>
                                                    _updateQuantity(i, -1)
                                                : null,
                                            constraints:
                                                const BoxConstraints(
                                                    minWidth: 40,
                                                    minHeight: 40),
                                            padding: EdgeInsets.zero,
                                          ),
                                          SizedBox(
                                            width: 36,
                                            child: Text(
                                              '${item.quantity}',
                                              textAlign: TextAlign.center,
                                              style: theme
                                                  .textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontFeatures: [
                                                  const FontFeature
                                                      .tabularFigures()
                                                ],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add,
                                                size: 18),
                                            onPressed: item.quantity < item.stockOnHand
                                                ? () => _updateQuantity(i, 1)
                                                : null,
                                            constraints:
                                                const BoxConstraints(
                                                    minWidth: 40,
                                                    minHeight: 40),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    // Line total
                                    Text(
                                      '${item.lineTotal.toStringAsFixed(2)} د.ج',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: [
                                          const FontFeature
                                              .tabularFigures()
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Delete button
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          size: 20,
                                          color: theme.colorScheme.error),
                                      onPressed: () => _removeItem(i),
                                      tooltip: l10n.removeItem,
                                      constraints: const BoxConstraints(
                                          minWidth: 40, minHeight: 40),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    // Totals section
                    if (_lineItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _TotalRow(label: l10n.subtotal, value: _subtotal),
                      if (_taxAmount > 0)
                        _TotalRow(label: l10n.tax, value: _taxAmount),

                      // Discount section
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _isLoading
                            ? null
                            : () => setState(() => _showDiscount = !_showDiscount),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.percent, size: 18,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text(l10n.discount,
                                  style: theme.textTheme.titleSmall),
                              const Spacer(),
                              Icon(
                                _showDiscount
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showDiscount) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _discountController,
                          enabled: !_isLoading,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.discountAmount,
                            suffixText: l10n.currencyUnit,
                            prefixIcon: const Icon(Icons.percent),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final val = double.tryParse(v.trim());
                            if (val == null || val < 0) return l10n.error;
                            if (val > _subtotal) {
                              return l10n.discountExceedsSubtotal;
                            }
                            return null;
                          },
                        ),
                        if (_hasDiscount) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16,
                                    color: theme
                                        .colorScheme.onTertiaryContainer),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.requiresOwnerApproval,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme
                                        .colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      if (_hasDiscount)
                        _TotalRow(
                          label: l10n.discount,
                          value: -_discountAmount,
                          isDiscount: true,
                        ),

                      const SizedBox(height: 4),
                      _TotalRow(
                          label: l10n.total, value: _total, isTotal: true),
                    ],
                  ],
                ),
              ),
            ),

            // Submit button
            Padding(
              padding:
                  const EdgeInsets.all(16).copyWith(bottom: 24),
              child: FilledButton(
                onPressed: _canSubmit ? _confirmAndSubmit : null,
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
                    : Text(
                        l10n.createOrder,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;
  final bool isDiscount;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextStyle? style;
    if (isTotal) {
      style = theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        fontFeatures: [const FontFeature.tabularFigures()],
      );
    } else if (isDiscount) {
      style = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
        fontFeatures: [const FontFeature.tabularFigures()],
      );
    } else {
      style = theme.textTheme.bodyMedium?.copyWith(
        fontFeatures: [const FontFeature.tabularFigures()],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${value.toStringAsFixed(2)} د.ج', style: style),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

