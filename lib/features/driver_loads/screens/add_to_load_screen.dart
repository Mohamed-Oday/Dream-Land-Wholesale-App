import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';

class AddToLoadScreen extends ConsumerStatefulWidget {
  final String loadId;

  const AddToLoadScreen({super.key, required this.loadId});

  @override
  ConsumerState<AddToLoadScreen> createState() => _AddToLoadScreenState();
}

class _AddToLoadScreenState extends ConsumerState<AddToLoadScreen> {
  final List<_AddItem> _items = [];
  bool _isLoading = false;

  bool get _canSubmit => _items.isNotEmpty && !_isLoading;

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
                      child: productsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => Center(child: Text(l10n.error)),
                        data: (products) => ListView.builder(
                          controller: scrollController,
                          itemCount: products.length,
                          itemBuilder: (_, index) {
                            final p = products[index];
                            final stock =
                                (p['stock_on_hand'] as num?)?.toInt() ?? 0;
                            final isOutOfStock = stock <= 0;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isOutOfStock
                                    ? Theme.of(ctx).colorScheme.errorContainer
                                    : Theme.of(ctx)
                                        .colorScheme
                                        .primaryContainer,
                                child: Icon(Icons.shopping_bag,
                                    color: isOutOfStock
                                        ? Theme.of(ctx)
                                            .colorScheme
                                            .onErrorContainer
                                        : Theme.of(ctx)
                                            .colorScheme
                                            .onPrimaryContainer),
                              ),
                              title: Text(p['name'] ?? ''),
                              subtitle: Text(
                                  '${l10n.stockOnHand}: $stock'),
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

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  void _addProduct(Map<String, dynamic> product) {
    final stock = (product['stock_on_hand'] as num?)?.toInt() ?? 0;
    if (stock <= 0) return;

    setState(() {
      final existingIndex =
          _items.indexWhere((item) => item.productId == product['id']);
      if (existingIndex >= 0) {
        if (_items[existingIndex].quantity >= stock) return;
        _items[existingIndex].quantity++;
      } else {
        _items.add(_AddItem(
          productId: product['id'] as String,
          productName: product['name'] ?? '',
          quantity: 1,
          stockOnHand: stock,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final item = _items[index];
      final newQty = item.quantity + delta;
      if (newQty >= 1 && newQty <= item.stockOnHand) {
        item.quantity = newQty;
      }
    });
  }

  Future<void> _confirmAdd() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(driverLoadRepositoryProvider)!;
      final itemMaps = _items
          .map((i) => {'product_id': i.productId, 'quantity': i.quantity})
          .toList();

      await repo.addToLoad(loadId: widget.loadId, items: itemMaps);

      if (!mounted) return;

      ref.invalidate(driverLoadListProvider);
      ref.invalidate(driverLoadDetailProvider(widget.loadId));
      ref.invalidate(driverCurrentLoadProvider);
      ref.invalidate(productListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loadCreated),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      String displayMsg;
      if (e.message.contains('insufficient_stock')) {
        displayMsg = l10n.insufficientStock;
      } else if (e.message.contains('invalid_load')) {
        displayMsg = l10n.error;
      } else {
        displayMsg = '${l10n.error}: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addToLoad)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(l10n.products,
                          style: theme.textTheme.titleSmall),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _showProductPicker,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.addProducts),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(l10n.addProducts,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant)),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w500)),
                                    Text(
                                        '${l10n.stockOnHand}: ${item.stockOnHand}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: theme
                                          .colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove,
                                          size: 18),
                                      onPressed: item.quantity > 1
                                          ? () => _updateQuantity(i, -1)
                                          : null,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                      padding: EdgeInsets.zero,
                                    ),
                                    SizedBox(
                                      width: 32,
                                      child: Text('${item.quantity}',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontFeatures: [
                                                const FontFeature
                                                    .tabularFigures()
                                              ])),
                                    ),
                                    IconButton(
                                      icon:
                                          const Icon(Icons.add, size: 18),
                                      onPressed: item.quantity <
                                              item.stockOnHand
                                          ? () => _updateQuantity(i, 1)
                                          : null,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 20,
                                    color: theme.colorScheme.error),
                                onPressed: () => _removeItem(i),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16).copyWith(bottom: 24),
            child: FilledButton(
              onPressed: _canSubmit ? _confirmAdd : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l10n.confirmLoad,
                      style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddItem {
  final String productId;
  final String productName;
  int quantity;
  final int stockOnHand;

  _AddItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.stockOnHand,
  });
}
