import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver/providers/user_management_provider.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/driver_loads/screens/load_receipt_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';

class CreateLoadScreen extends ConsumerStatefulWidget {
  const CreateLoadScreen({super.key});

  @override
  ConsumerState<CreateLoadScreen> createState() => _CreateLoadScreenState();
}

class _CreateLoadScreenState extends ConsumerState<CreateLoadScreen> {
  String? _selectedDriverId;
  String _selectedDriverName = '';
  final List<_LoadItem> _items = [];
  final _notesController = TextEditingController();
  bool _isLoading = false;

  bool get _canSubmit =>
      _selectedDriverId != null && _items.isNotEmpty && !_isLoading;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showDriverPicker() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final driversAsync = ref.watch(driversOnlyProvider);
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
                  child: Text(l10n.selectDriver,
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                const Divider(),
                driversAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.error),
                  ),
                  data: (drivers) {
                    final activeDrivers = drivers
                        .where((d) => d['active'] == true)
                        .toList();
                    if (activeDrivers.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.noUsers),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: activeDrivers.map((d) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(ctx)
                                .colorScheme
                                .primaryContainer,
                            child: Icon(Icons.person,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onPrimaryContainer),
                          ),
                          title: Text(d['name'] ?? ''),
                          subtitle: Text(d['username'] ?? ''),
                          onTap: () {
                            setState(() {
                              _selectedDriverId = d['id'] as String;
                              _selectedDriverName = d['name'] ?? '';
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            );
          },
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
                              title: Text(
                                p['name'] ?? '',
                                style: isOutOfStock
                                    ? TextStyle(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant)
                                    : null,
                              ),
                              subtitle: Text(
                                  '${l10n.stockOnHand}: $stock'),
                              trailing: isOutOfStock
                                  ? Text(l10n.outOfStock,
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
    if (stock <= 0) return;

    setState(() {
      final existingIndex =
          _items.indexWhere((item) => item.productId == product['id']);
      if (existingIndex >= 0) {
        if (_items[existingIndex].quantity >= stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.stockOnHand}: $stock'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _items[existingIndex].quantity++;
      } else {
        _items.add(_LoadItem(
          productId: product['id'] as String,
          productName: product['name'] ?? '',
          quantity: 1,
          stockOnHand: stock,
        ));
      }
    });
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final item = _items[index];
      final newQty = item.quantity + delta;
      if (newQty >= 1 && newQty <= item.stockOnHand) {
        item.quantity = newQty;
      } else if (newQty > item.stockOnHand) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.stockOnHand}: ${item.stockOnHand}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _confirmAndSubmit() async {
    if (!_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmLoad),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.driver}: $_selectedDriverName'),
            const SizedBox(height: 8),
            Text('${l10n.products}: ${_items.length}'),
            Text(
                '${l10n.totalLoaded}: ${_items.fold<int>(0, (sum, i) => sum + i.quantity)}'),
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
      final repo = ref.read(driverLoadRepositoryProvider)!;
      final itemMaps = _items
          .map((i) => {
                'product_id': i.productId,
                'quantity': i.quantity,
              })
          .toList();

      final loadId = await repo.createLoad(
        driverId: _selectedDriverId!,
        items: itemMaps,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      ref.invalidate(driverLoadListProvider);
      ref.invalidate(productListProvider);

      // Build load data for receipt
      final loadData = {
        'id': loadId,
        'driver_name': _selectedDriverName,
        'loaded_by_name': currentUser?.name ?? '',
        'opened_at': DateTime.now().toIso8601String(),
        'items': _items
            .map((i) => {
                  'product_name': i.productName,
                  'quantity_loaded': i.quantity,
                })
            .toList(),
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoadReceiptScreen(loadData: loadData),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      String displayMsg;
      if (msg.contains('driver_has_active_load')) {
        displayMsg = l10n.driverHasActiveLoad;
      } else if (msg.contains('insufficient_stock')) {
        displayMsg = l10n.insufficientStock;
      } else if (msg.contains('invalid_driver')) {
        displayMsg = l10n.error;
      } else {
        displayMsg = '${l10n.saveError}: $msg';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loadDriver)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Driver picker
                  InkWell(
                    onTap: _isLoading ? null : _showDriverPicker,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.selectDriver,
                        prefixIcon: const Icon(Icons.person),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        _selectedDriverName.isEmpty
                            ? ''
                            : _selectedDriverName,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Products header + add button
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

                  // Item list
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          l10n.addProducts,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
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
                                        Text(
                                          '${l10n.stockOnHand}: ${item.stockOnHand}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(l10n.quantityToLoad,
                                      style: theme.textTheme.bodySmall),
                                  const Spacer(),
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
                                          constraints: const BoxConstraints(
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
                                          onPressed:
                                              item.quantity < item.stockOnHand
                                                  ? () =>
                                                      _updateQuantity(i, 1)
                                                  : null,
                                          constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  // Notes field
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: l10n.purchaseNotes,
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(16).copyWith(bottom: 24),
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
                      l10n.confirmLoad,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadItem {
  final String productId;
  final String productName;
  int quantity;
  final int stockOnHand;

  _LoadItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.stockOnHand,
  });
}
