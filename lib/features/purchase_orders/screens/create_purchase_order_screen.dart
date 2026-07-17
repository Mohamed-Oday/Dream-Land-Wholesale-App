import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/section_label.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/surface_card.dart';
import '../../../core/ui/tawzii_row.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../providers/purchase_order_provider.dart';
import 'purchase_order_detail_screen.dart';

class _PurchaseLineItem {
  final String productId;
  final String productName;
  final int? unitsPerPackage;
  double packageCost;
  int quantity;
  final TextEditingController costController;

  _PurchaseLineItem({
    required this.productId,
    required this.productName,
    required this.packageCost,
    this.unitsPerPackage,
    required this.quantity,
  }) : costController = TextEditingController(
          text: packageCost == packageCost.roundToDouble()
              ? packageCost.toInt().toString()
              : packageCost.toString(),
        );

  double get lineTotal => packageCost * quantity;
}

/// Create purchase order (canvas 6b): supplier header with change action,
/// add-product search, per-line editable cost + 48px qty steppers, notes,
/// pinned bottom bar with total cost + confirm CTA. Confirm replenishes
/// stock + updates cost price (existing repository RPC).
class CreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  ConsumerState<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState
    extends ConsumerState<CreatePurchaseOrderScreen> {
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
    for (final item in _lineItems) {
      item.costController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSupplier(List<Map<String, dynamic>> suppliers) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SearchPickerSheet(
        title: AppLocalizations.of(context)!.selectSupplier,
        hint: 'ابحث باسم المورد…',
        items: suppliers,
        rowBuilder: (s, onTap) => TawziiRow(
          leading: const StatusDot(StatusKind.neutral),
          title: s['name'] as String? ?? '',
          subtitle: (s['phone'] as String? ?? '').isEmpty
              ? null
              : '\u2066${s['phone']}\u2069',
          onTap: onTap,
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedSupplierId = selected['id'] as String;
        _selectedSupplierName = selected['name'] as String? ?? '';
      });
    }
  }

  Future<void> _pickProduct(List<Map<String, dynamic>> products) async {
    final t = TawziiTokens.of(context);
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SearchPickerSheet(
        title: 'أضف منتجاً',
        hint: 'ابحث باسم المنتج…',
        items: products,
        rowBuilder: (p, onTap) {
          final costPrice = (p['cost_price'] as num?)?.toDouble();
          final unitPrice = (p['unit_price'] as num?)?.toDouble() ?? 0;
          final upkg = (p['units_per_package'] as num?)?.toInt();
          final packageCost = (costPrice ?? unitPrice) * (upkg ?? 1);
          final already =
              _lineItems.any((item) => item.productId == p['id']);
          return TawziiRow(
            leading: StatusDot(already ? StatusKind.pending : StatusKind.neutral),
            title: p['name'] as String? ?? '',
            subtitle: upkg != null ? '\u2066$upkg\u2069 وحدة/عبوة' : null,
            trailing: Money(packageCost, color: t.textSecondary),
            selected: already,
            onTap: onTap,
          );
        },
      ),
    );
    if (selected == null || !mounted) return;

    final productId = selected['id'] as String;
    final existing =
        _lineItems.indexWhere((item) => item.productId == productId);
    setState(() {
      if (existing >= 0) {
        _lineItems[existing].quantity += 1;
      } else {
        final costPrice = (selected['cost_price'] as num?)?.toDouble();
        final unitPrice = (selected['unit_price'] as num?)?.toDouble() ?? 0;
        final upkg = (selected['units_per_package'] as num?)?.toInt();
        _lineItems.add(_PurchaseLineItem(
          productId: productId,
          productName: selected['name'] as String? ?? '',
          packageCost: (costPrice ?? unitPrice) * (upkg ?? 1),
          unitsPerPackage: upkg,
          quantity: 1,
        ));
      }
    });
  }

  void _changeQuantity(_PurchaseLineItem item, int delta) {
    setState(() {
      final next = item.quantity + delta;
      if (next <= 0) {
        _lineItems.remove(item);
        item.costController.dispose();
      } else {
        item.quantity = next;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSubmit) return;
    if (_isLoading) return;

    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmPurchase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.supplier}: $_selectedSupplierName'),
            Text('${l10n.items}: \u2066${_lineItems.length}\u2069'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.totalCost,
                    style: Theme.of(ctx).textTheme.bodyMedium),
                Money(_totalCost, size: MoneySize.h2),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'عند التأكيد: يُحدَّث المخزون وسعر التكلفة',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
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
          SnackBar(content: Text(AppLocalizations.of(context)!.purchaseCreated)),
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
          SnackBar(content: Text('خطأ: $e')),
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
    final suppliersAsync = ref.watch(supplierListProvider);
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPurchaseOrder)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
              children: [
                // Supplier row — name + change
                suppliersAsync.when(
                  loading: () => const SkeletonRow(),
                  error: (e, _) => ErrorRetryRow(
                    onRetry: () => ref.invalidate(supplierListProvider),
                  ),
                  data: (suppliers) => SurfaceCard(
                    level: SurfaceLevel.alt,
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
                    onTap: _isLoading ? null : () => _pickSupplier(suppliers),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.supplier,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: t.textSecondary,
                                ),
                              ),
                              Text(
                                _selectedSupplierName.isEmpty
                                    ? l10n.selectSupplier
                                    : _selectedSupplierName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedSupplierName.isEmpty
                                      ? t.textMuted
                                      : t.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'تغيير',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Add product field
                productsAsync.when(
                  loading: () => const SkeletonRow(),
                  error: (e, _) => ErrorRetryRow(
                    onRetry: () => ref.invalidate(productListProvider),
                  ),
                  data: (products) => InkWell(
                    onTap: _isLoading ? null : () => _pickProduct(products),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border.all(color: t.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'أضف منتجاً…',
                              style:
                                  TextStyle(fontSize: 15, color: t.textMuted),
                            ),
                          ),
                          Icon(Icons.add, size: 20, color: t.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Line items
                if (_lineItems.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 24),
                    child: EmptyState(
                      title: 'لا أصناف بعد',
                      message: 'أضف المنتجات المشتراة لتسجيلها في هذا الأمر',
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final item in _lineItems) ...[
                        _LineCard(
                          item: item,
                          isLoading: _isLoading,
                          onCostChanged: (v) => setState(() {
                            item.packageCost = v;
                          }),
                          onDecrement: () => _changeQuantity(item, -1),
                          onIncrement: () => _changeQuantity(item, 1),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),

                const SizedBox(height: 6),
                SectionLabel(l10n.purchaseNotes),
                TextField(
                  controller: _notesController,
                  enabled: !_isLoading,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'اختياري'),
                ),
                const SizedBox(height: 10),
                Text(
                  'عند التأكيد: يُحدَّث المخزون وسعر التكلفة',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),

          // Pinned bottom bar: confirm + total
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(top: BorderSide(color: t.border)),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _canSubmit ? _save : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      child: Text(
                        _isLoading ? '...' : l10n.confirmPurchase,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.totalCost,
                        style: TextStyle(
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                      ),
                      Money(_totalCost, size: MoneySize.h2),
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

// ---------------------------------------------------------------------------
// Line card: name + line total, editable cost, qty stepper
// ---------------------------------------------------------------------------

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.item,
    required this.isLoading,
    required this.onCostChanged,
    required this.onDecrement,
    required this.onIncrement,
  });

  final _PurchaseLineItem item;
  final bool isLoading;
  final ValueChanged<double> onCostChanged;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    Widget stepButton({
      required IconData icon,
      required VoidCallback? onTap,
      bool filled = false,
    }) {
      return Material(
        color: filled ? t.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 48,
            decoration: filled
                ? null
                : BoxDecoration(
                    border: Border.all(color: t.borderStrong, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
            child: Icon(
              icon,
              size: 20,
              color: filled ? t.onAccent : t.textSecondary,
            ),
          ),
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Money(item.lineTotal, showUnit: false, size: MoneySize.body),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Cost input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سعر التكلفة',
                      style: TextStyle(
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: item.costController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsetsDirectional.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onChanged: (v) {
                          final parsed =
                              double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          onCostChanged(parsed);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Quantity stepper
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الكمية',
                    style: TextStyle(fontSize: 11, color: t.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      stepButton(icon: Icons.remove, onTap: onDecrement),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '\u2066${item.quantity}\u2069',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                      stepButton(
                        icon: Icons.add,
                        onTap: onIncrement,
                        filled: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic searchable picker sheet (suppliers / products)
// ---------------------------------------------------------------------------

class _SearchPickerSheet extends StatefulWidget {
  const _SearchPickerSheet({
    required this.title,
    required this.hint,
    required this.items,
    required this.rowBuilder,
  });

  final String title;
  final String hint;
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic> item, VoidCallback onTap)
      rowBuilder;

  @override
  State<_SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<_SearchPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.items
        : widget.items
            .where((s) =>
                (s['name'] as String? ?? '').toLowerCase().contains(query))
            .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 0),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(hintText: widget.hint),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 20),
                itemCount: filtered.length,
                itemBuilder: (_, index) {
                  final item = filtered[index];
                  return widget.rowBuilder(
                    item,
                    () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
