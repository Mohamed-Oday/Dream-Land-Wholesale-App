import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/utils/order_calculator.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver_loads/providers/driver_load_providers.dart';
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
  final Map<String, TextEditingController> _qtyControllers = {};
  bool _isLoading = false;
  bool _showDiscount = false;

  @override
  void initState() {
    super.initState();
    _loadLastStore();
  }

  @override
  void dispose() {
    _discountController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLastStore() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStoreId = prefs.getString('last_store_id');
    final lastStoreName = prefs.getString('last_store_name');
    if (lastStoreId != null && lastStoreName != null && mounted) {
      setState(() {
        _selectedStoreId = lastStoreId;
        _selectedStoreName = lastStoreName;
      });
    }
  }

  Future<void> _saveLastStore(String storeId, String storeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_store_id', storeId);
    await prefs.setString('last_store_name', storeName);
  }

  double get _subtotal => calculateSubtotal(_lineItems);
  double get _taxPercentage => 0;
  double get _taxAmount => calculateTax(_subtotal, _taxPercentage);
  double get _discountAmount => parseDiscount(_discountController.text);
  double get _total => calculateTotal(_subtotal, _taxAmount, _discountAmount);
  bool get _hasDiscount => _discountAmount > 0;
  bool get _canSubmit =>
      _selectedStoreId != null && _lineItems.isNotEmpty && !_isLoading;

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
    setState(() {
      if (clamped > 0) {
        final existingIndex =
            _lineItems.indexWhere((item) => item.productId == productId);
        if (existingIndex >= 0) {
          _lineItems[existingIndex].quantity = clamped;
        } else {
          _lineItems.add(LineItem(
            productId: productId,
            productName: product['name'] ?? '',
            unitPrice: (product['unit_price'] as num).toDouble(),
            quantity: clamped,
            unitsPerPackage: product['units_per_package'] as int?,
            hasReturnablePackaging:
                product['has_returnable_packaging'] == true,
            stockOnHand: maxStock,
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

  Future<Map<String, dynamic>?> _showStorePicker(
      BuildContext context, List<Map<String, dynamic>> stores) {
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
                ? stores
                : stores.where((s) {
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
                    child: Text(l10n.selectStore,
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
                        hintText: 'ابحث باسم المتجر...',
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
                            child: Icon(Icons.store,
                                color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(s['name'] ?? ''),
                          subtitle: (s['address'] ?? '')
                                  .toString()
                                  .isNotEmpty
                              ? Text(s['address'] as String)
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

  Future<void> _confirmAndSubmit() async {
    if (!_formKey.currentState!.validate() || !_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;

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
            _SummaryRow(label: l10n.stores, value: _selectedStoreName),
            _SummaryRow(label: l10n.items, value: '${_lineItems.length}'),
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

      final lineItemMaps = _lineItems
          .map((item) => {
                'product_id': item.productId,
                'quantity': item.quantity,
                'unit_price': item.packagePrice,
                'line_total': item.lineTotal,
              })
          .toList();

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

      orderData['stores'] = {'name': _selectedStoreName};
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
      ref.invalidate(orderListProvider);
      ref.invalidate(allOrdersProvider);
      ref.invalidate(driverCurrentLoadProvider);

      try {
        final notifService = ref.read(notificationServiceProvider);
        final userName = ref.read(currentUserProvider)?.name ?? '';
        final userBusinessId =
            ref.read(currentUserProvider)?.businessId ?? '';
        notifService.sendNotification(
          eventType: 'new_order',
          data: {'driver': userName, 'store': _selectedStoreName},
        );
        if (_hasDiscount) {
          notifService.sendNotification(
            eventType: 'discount_pending',
            data: {
              'driver': userName,
              'amount': _discountAmount.toStringAsFixed(2),
              'store': _selectedStoreName,
            },
          );
        }
        notifService.checkAndNotifyLowStock(
          productIds: _lineItems.map((i) => i.productId).toList(),
          businessId: userBusinessId,
        );
      } catch (e) {
        debugPrint('Order notification failed (non-blocking): $e');
      }

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
      debugPrint(
          'Order save PostgrestException: ${e.message} / ${e.details}');
      if (mounted) {
        final msg = e.message;
        if (msg.contains('permission denied') ||
            msg.contains('new row violates row-level security')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم تعطيل حسابك — تواصل مع المالك'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          ref
              .read(notificationServiceProvider)
              .unregisterToken(Supabase.instance.client);
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
    final productsAsync = ref.watch(productListProvider);
    final loadAsync = ref.watch(driverCurrentLoadProvider);

    final Map<String, int> loadStock = {};
    final bool hasActiveLoad;
    final loadData = loadAsync.valueOrNull;
    if (loadData != null) {
      hasActiveLoad = true;
      final items = loadData['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        final pid = m['product_id'] as String;
        final loaded = (m['quantity_loaded'] as num?)?.toInt() ?? 0;
        final sold = (m['quantity_sold'] as num?)?.toInt() ?? 0;
        loadStock[pid] = loaded - sold;
      }
    } else {
      hasActiveLoad = false;
    }

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
                    // Store selector
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
                                        await _showStorePicker(
                                            context, stores);
                                    if (selected != null) {
                                      setState(() {
                                        _selectedStoreId =
                                            selected['id'] as String;
                                        _selectedStoreName =
                                            selected['name'] ?? '';
                                      });
                                      field.didChange(
                                          selected['id'] as String);
                                      _saveLastStore(
                                        selected['id'] as String,
                                        selected['name'] ?? '',
                                      );
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
                            final warehouseStock =
                                (p['stock_on_hand'] as num?)?.toInt() ?? 0;

                            final int availableStock;
                            final bool notInLoad;
                            if (hasActiveLoad) {
                              final loadRemaining = loadStock[productId];
                              if (loadRemaining == null) {
                                availableStock = 0;
                                notInLoad = true;
                              } else {
                                availableStock = loadRemaining;
                                notInLoad = false;
                              }
                            } else {
                              availableStock = warehouseStock;
                              notInLoad = false;
                            }

                            final isDisabled =
                                availableStock <= 0 || notInLoad;
                            final currentQty = _getQuantity(productId);
                            final price =
                                (p['unit_price'] as num).toDouble();
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
                                elevation: currentQty > 0 ? 4 : 2,
                                shadowColor: theme.colorScheme.shadow
                                    .withValues(alpha: 0.15),
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: currentQty > 0
                                      ? BorderSide(
                                          color:
                                              theme.colorScheme.primary,
                                          width: 2,
                                        )
                                      : BorderSide(
                                          color: theme
                                              .colorScheme.outlineVariant
                                              .withValues(alpha: 0.6),
                                          width: 1,
                                        ),
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
                                            if (notInLoad)
                                              Text(
                                                'غير محمّل',
                                                style: TextStyle(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              )
                                            else if (availableStock <=
                                                0)
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
                                                'متبقي: $availableStock',
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
                                                        availableStock,
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
                                                    availableStock,
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
                                                      availableStock
                                                  ? () => _setQuantity(
                                                        productId,
                                                        currentQty + 1,
                                                        availableStock,
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
                                  '${item.quantity} × ${item.packagePrice.toStringAsFixed(2)}',
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
                                  '${item.lineTotal.toStringAsFixed(2)} د.ج',
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
                      _TotalRow(label: l10n.subtotal, value: _subtotal),
                      if (_taxAmount > 0)
                        _TotalRow(label: l10n.tax, value: _taxAmount),

                      // Discount section
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _isLoading
                            ? null
                            : () => setState(
                                () => _showDiscount = !_showDiscount),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.percent,
                                  size: 18,
                                  color: theme
                                      .colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text(l10n.discount,
                                  style: theme.textTheme.titleSmall),
                              const Spacer(),
                              Icon(
                                _showDiscount
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: theme
                                    .colorScheme.onSurfaceVariant,
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
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.discountAmount,
                            suffixText: l10n.currencyUnit,
                            prefixIcon: const Icon(Icons.percent),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return null;
                            }
                            final val = double.tryParse(v.trim());
                            if (val == null || val < 0) {
                              return l10n.error;
                            }
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
                                    color: theme.colorScheme
                                        .onTertiaryContainer),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.requiresOwnerApproval,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: theme.colorScheme
                                        .onTertiaryContainer,
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
                          label: l10n.total,
                          value: _total,
                          isTotal: true),
                    ],
                  ],
                ),
              ),
            ),

            // Submit button
            SafeArea(
              minimum: const EdgeInsets.all(16).copyWith(top: 0),
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
