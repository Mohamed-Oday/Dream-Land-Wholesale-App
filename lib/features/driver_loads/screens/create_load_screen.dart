import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver/providers/user_management_provider.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/driver_loads/screens/load_receipt_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';

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
  final Map<String, TextEditingController> _qtyControllers = {};
  bool _isLoading = false;

  bool get _canSubmit =>
      _selectedDriverId != null && _items.isNotEmpty && !_isLoading;

  @override
  void dispose() {
    _notesController.dispose();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showDriverPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final drivers = await ref.read(driversOnlyProvider.future);
    final activeDrivers = drivers.where((d) => d['active'] == true).toList();

    if (!mounted) return;

    final searchController = TextEditingController();

    await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = searchController.text.isEmpty
                ? activeDrivers
                : activeDrivers.where((d) {
                    final name = (d['name'] as String).toLowerCase();
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
                    child: Text(l10n.selectDriver,
                        style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      textAlign: TextAlign.start,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم البائع...',
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
                  if (activeDrivers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.noUsers),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final d = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Icon(Icons.person,
                                  color: theme.colorScheme.onPrimaryContainer),
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
    for (final item in _items) {
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
    setState(() {
      if (clamped > 0) {
        final existingIndex =
            _items.indexWhere((item) => item.productId == productId);
        if (existingIndex >= 0) {
          _items[existingIndex].quantity = clamped;
        } else {
          _items.add(_LoadItem(
            productId: productId,
            productName: product['name'] ?? '',
            quantity: clamped,
            stockOnHand: maxStock,
          ));
        }
      } else {
        _items.removeWhere((item) => item.productId == productId);
      }
      _qtyControllers[productId]?.text = '$clamped';
    });
  }

  void _removeItem(int index) {
    final productId = _items[index].productId;
    setState(() {
      _items.removeAt(index);
      _qtyControllers[productId]?.text = '0';
    });
  }

  Future<void> _confirmAndSubmit() async {
    if (!_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);

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

      try {
        final notifService = ref.read(notificationServiceProvider);
        notifService.sendNotification(
          eventType: 'shift_opened',
          data: {'driver': _selectedDriverName},
        );
      } catch (e) {
        debugPrint('Shift opened notification failed (non-blocking): $e');
      }

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
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loadDriver)),
      body: Form(
        child: Column(
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
                    if (_items.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      ...List.generate(_items.length, (i) {
                        final item = _items[i];
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
                                  '${item.quantity} عبوة',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: theme.colorScheme
                                        .onSurfaceVariant,
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
                      const SizedBox(height: 16),
                    ],

                    // Notes
                    if (_items.isNotEmpty) ...[
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
      ),
    );
  }
}
