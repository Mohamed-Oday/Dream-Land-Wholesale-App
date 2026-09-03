import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver/providers/user_management_provider.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/receipts/screens/receipt_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';
import 'package:tawzii/core/utils/package_stock.dart';

/// 5b — تحميل بائع: create load AND add-to-load are the same screen.
/// Pass [loadId] (+ [driverName]) to operate on an active load.
class CreateLoadScreen extends ConsumerStatefulWidget {
  const CreateLoadScreen({super.key, this.loadId, this.driverName});

  /// When set, the screen adds items to this active load instead of
  /// creating a new one.
  final String? loadId;

  /// Driver display name for add mode.
  final String? driverName;

  bool get isAddMode => loadId != null;

  @override
  ConsumerState<CreateLoadScreen> createState() => _CreateLoadScreenState();
}

class _CreateLoadScreenState extends ConsumerState<CreateLoadScreen> {
  String? _selectedDriverId;
  String _selectedDriverName = '';
  final Map<String, int> _quantities = {};
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isAddMode) {
      _selectedDriverName = widget.driverName ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalUnits =>
      _quantities.values.fold(0, (sum, q) => sum + q);

  bool get _canSubmit =>
      (widget.isAddMode || _selectedDriverId != null) &&
      _totalUnits > 0 &&
      !_isLoading;

  Future<void> _showDriverPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final drivers = await ref.read(driversOnlyProvider.future);
    final activeDrivers = drivers.where((d) => d['active'] == true).toList();

    if (!mounted) return;

    final searchController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final t = TawziiTokens.of(ctx);
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
              padding: EdgeInsetsDirectional.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          18, 4, 18, 8),
                      child: Text(
                        l10n.selectDriver,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 18),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'ابحث باسم البائع…',
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (activeDrivers.isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.all(24),
                        child: Text(
                          l10n.noUsers,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.textMuted),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final d = filtered[index];
                            return TawziiRow(
                              title: d['name'] as String? ?? '',
                              subtitle: d['username'] as String? ?? '',
                              selected: d['id'] == _selectedDriverId,
                              onTap: () {
                                setState(() {
                                  _selectedDriverId = d['id'] as String;
                                  _selectedDriverName =
                                      d['name'] as String? ?? '';
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _setQuantity(String productId, int qty, int maxStock) {
    final clamped = qty.clamp(0, maxStock);
    setState(() {
      if (clamped > 0) {
        _quantities[productId] = clamped;
      } else {
        _quantities.remove(productId);
      }
    });
  }

  Future<void> _submit(List<Map<String, dynamic>> products) async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(driverLoadRepositoryProvider)!;
      final itemMaps = _quantities.entries
          .map((e) => {'product_id': e.key, 'quantity': e.value})
          .toList();

      if (widget.isAddMode) {
        await repo.addToLoad(loadId: widget.loadId!, items: itemMaps);

        if (!mounted) return;

        ref.invalidate(driverLoadListProvider);
        ref.invalidate(driverLoadDetailProvider(widget.loadId!));
        ref.invalidate(driverCurrentLoadProvider);
        ref.invalidate(productListProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loadCreated)),
        );
        Navigator.pop(context);
        return;
      }

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

      final nameById = {
        for (final p in products) p['id'] as String: p['name'] as String? ?? ''
      };
      final loadData = {
        'id': loadId,
        'driver_name': _selectedDriverName,
        'loaded_by_name': currentUser?.name ?? '',
        'opened_at': DateTime.now().toIso8601String(),
        'items': _quantities.entries
            .map((e) => {
                  'product_name': nameById[e.key] ?? '',
                  'quantity_loaded': e.value,
                })
            .toList(),
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen.load(loadData: loadData),
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
      } else if (msg.contains('invalid_driver') ||
          msg.contains('invalid_load')) {
        displayMsg = l10n.error;
      } else {
        displayMsg = '${l10n.saveError}: $msg';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayMsg)),
      );
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final productsAsync = ref.watch(productListProvider);
    final products = productsAsync.valueOrNull ?? const [];

    final totalValue = _quantities.entries.fold<double>(0, (sum, e) {
      final p = products.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['id'] == e.key,
            orElse: () => null,
          );
      final price = (p?['unit_price'] as num?)?.toDouble() ?? 0;
      return sum + price * e.value;
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.isAddMode ? l10n.addToLoad : l10n.loadDriver),
            Text(
              _selectedDriverName.isEmpty
                  ? 'اختر بائعاً للتحميل'
                  : '$_selectedDriverName · '
                      '${widget.isAddMode ? 'تحميل نشط' : 'تحميل جديد'}',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          ],
        ),
        actions: [
          if (!widget.isAddMode)
            TextButton(
              onPressed: _isLoading ? null : _showDriverPicker,
              child: Text(
                  _selectedDriverName.isEmpty ? l10n.selectDriver : 'تغيير'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: productsAsync.when(
              loading: () => ListView(
                padding: const EdgeInsetsDirectional.all(18),
                children: const [SkeletonList(count: 5, hardened: true)],
              ),
              error: (e, _) => ListView(
                padding: const EdgeInsetsDirectional.all(18),
                children: [
                  ErrorRetryRow(
                    onRetry: () => ref.invalidate(productListProvider),
                  ),
                ],
              ),
              data: (allProducts) {
                final query = _searchController.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? allProducts
                    : allProducts
                        .where((p) => (p['name'] as String? ?? '')
                            .toLowerCase()
                            .contains(query))
                        .toList();

                return ListView(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 18),
                  children: [
                    TextField(
                      controller: _searchController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'ابحث في المخزن…',
                        filled: true,
                        fillColor: t.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: t.borderStrong, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: t.accent, width: 2),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    if (allProducts.isEmpty)
                      EmptyState(
                        title: 'لا توجد منتجات',
                        message: 'أضف منتجات إلى المخزن أولاً',
                      )
                    else if (filtered.isEmpty)
                      const EmptyState(
                        title: 'لا نتائج',
                        message: 'جرّب كلمة بحث أخرى',
                      )
                    else
                      for (final p in filtered) ...[
                        _ProductLoadRow(
                          product: p,
                          quantity: _quantities[p['id'] as String] ?? 0,
                          enabled: !_isLoading,
                          onChanged: (qty) => _setQuantity(
                            p['id'] as String,
                            qty,
                            wholePackages(stockOf(p)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    if (!widget.isAddMode && _quantities.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.purchaseNotes,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _notesController,
                        enabled: !_isLoading,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(hintText: 'اختياري'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          // Pinned bottom bar: confirm + running value.
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(
                top: BorderSide(color: t.borderStrong, width: 2),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _canSubmit ? () => _submit(products) : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 56),
                        textStyle: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: t.onAccent),
                            )
                          : Text('${l10n.confirmLoad} (\u2066$_totalUnits\u2069)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'القيمة',
                        style: TextStyle(
                            fontSize: 11, color: t.textSecondary),
                      ),
                      Money(totalValue, size: MoneySize.h2),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Field-Kit product row: name + stock, big −/qty/+ stepper.
/// Long-press on +/− jumps by 5. Insufficient stock blocks at source.
class _ProductLoadRow extends StatelessWidget {
  const _ProductLoadRow({
    required this.product,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  final Map<String, dynamic> product;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    // Loads move whole packages only, so a leftover fraction is not loadable.
    final stock = wholePackages(stockOf(product));
    final outOfStock = stock <= 0;

    return Opacity(
      opacity: outOfStock ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 10, 11),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderStrong, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (outOfStock)
                    Text(
                      'نفذ من المخزن',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.danger,
                      ),
                    )
                  else
                    Text(
                      'بالمخزن \u2066$stock\u2069',
                      style:
                          TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                ],
              ),
            ),
            if (!outOfStock) ...[
              const SizedBox(width: 10),
              _StepButton(
                icon: Icons.remove,
                filled: false,
                enabled: enabled && quantity > 0,
                onTap: () => onChanged(quantity - 1),
                onLongPress: () => onChanged(quantity - 5),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '\u2066$quantity\u2069',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                filled: true,
                enabled: enabled && quantity < stock,
                onTap: () => onChanged(quantity + 1),
                onLongPress: () => onChanged(quantity + 5),
              ),
            ] else
              _StepButton(
                icon: Icons.add,
                filled: false,
                enabled: false,
                onTap: () {},
              ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    return Material(
      color: filled && enabled ? t.accent : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: filled && enabled
            ? BorderSide.none
            : BorderSide(
                color: enabled ? t.borderStrong : t.border, width: 2),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 22,
            color: filled && enabled
                ? t.onAccent
                : (enabled ? t.textSecondary : t.disabledFg),
          ),
        ),
      ),
    );
  }
}
