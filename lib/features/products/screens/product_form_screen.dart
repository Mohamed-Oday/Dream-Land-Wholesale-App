import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import '../providers/product_provider.dart';
import 'stock_adjustment_screen.dart';
import 'stock_movement_history_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? product;

  const ProductFormScreen({super.key, this.product});

  bool get isEditing => product != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _unitsPerPkgController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockThresholdController;
  late bool _hasReturnablePackaging;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?['name'] ?? '');
    _priceController =
        TextEditingController(text: p?['unit_price']?.toString() ?? '');
    _unitsPerPkgController =
        TextEditingController(text: p?['units_per_package']?.toString() ?? '');
    _costPriceController =
        TextEditingController(text: p?['cost_price']?.toString() ?? '');
    _stockController =
        TextEditingController(text: p?['stock_on_hand']?.toString() ?? '0');
    _lowStockThresholdController =
        TextEditingController(text: p?['low_stock_threshold']?.toString() ?? '0');
    _hasReturnablePackaging = p?['has_returnable_packaging'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitsPerPkgController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(productRepositoryProvider)!;
      final price = double.parse(_priceController.text.trim());
      final unitsPerPkg = _unitsPerPkgController.text.trim().isNotEmpty
          ? int.parse(_unitsPerPkgController.text.trim())
          : null;
      final costPrice = _costPriceController.text.trim().isNotEmpty
          ? double.parse(_costPriceController.text.trim())
          : null;

      if (widget.isEditing) {
        final stockOnHand = int.tryParse(_stockController.text.trim()) ?? 0;
        final lowStockThreshold = int.tryParse(_lowStockThresholdController.text.trim()) ?? 0;
        await repo.update(widget.product!['id'], {
          'name': _nameController.text.trim(),
          'unit_price': price,
          'units_per_package': unitsPerPkg,
          'has_returnable_packaging': _hasReturnablePackaging,
          'cost_price': costPrice,
          'stock_on_hand': stockOnHand,
          'low_stock_threshold': lowStockThreshold,
        });
      } else {
        await repo.create(
          name: _nameController.text.trim(),
          unitPrice: price,
          unitsPerPackage: unitsPerPkg,
          hasReturnablePackaging: _hasReturnablePackaging,
          costPrice: costPrice,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في الحفظ: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل المنتج' : 'إضافة منتج'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                enabled: !_isLoading,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'سعر الوحدة (د.ج)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  final price = double.tryParse(v.trim());
                  if (price == null) return 'أدخل رقماً صحيحاً';
                  if (price <= 0) return 'السعر يجب أن يكون أكبر من صفر';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costPriceController,
                enabled: !_isLoading,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.costPrice,
                  prefixIcon: const Icon(Icons.money_off_outlined),
                  hintText: 'اختياري',
                  suffixText: 'د.ج',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final cost = double.tryParse(v.trim());
                  if (cost == null) return 'أدخل رقماً صحيحاً';
                  if (cost < 0) return 'السعر يجب أن يكون صفر أو أكبر';
                  return null;
                },
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stockController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.stockOnHand,
                    prefixIcon: const Icon(Icons.inventory_outlined),
                    suffixText: 'وحدة',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null) return 'أدخل رقماً صحيحاً';
                    if (n < 0) return 'لا يمكن أن يكون سالباً';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lowStockThresholdController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.alertThreshold,
                    prefixIcon: const Icon(Icons.warning_amber_outlined),
                    suffixText: 'وحدة',
                    hintText: '0 = بدون تنبيه',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null) return 'أدخل رقماً صحيحاً';
                    if (n < 0) return 'لا يمكن أن يكون سالباً';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitsPerPkgController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'عدد الوحدات في العبوة',
                  prefixIcon: Icon(Icons.inventory),
                  hintText: 'اختياري',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'أدخل عدداً صحيحاً أكبر من صفر';
                  return null;
                },
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StockAdjustmentScreen(
                                        product: widget.product!),
                                  ),
                                );
                                if (result == true) {
                                  ref.invalidate(productListProvider);
                                }
                              },
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text(l10n.adjustStock),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StockMovementHistoryScreen(
                                      productId:
                                          widget.product!['id'] as String,
                                      productName:
                                          widget.product!['name'] as String? ??
                                              '',
                                    ),
                                  ),
                                ),
                        icon: const Icon(Icons.history, size: 18),
                        label: Text(l10n.stockMovements),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('تغليف قابل للإرجاع'),
                subtitle: const Text('هل يحتوي المنتج على عبوات يجب إرجاعها؟'),
                value: _hasReturnablePackaging,
                onChanged:
                    _isLoading ? null : (v) => setState(() => _hasReturnablePackaging = v),
              ),
              const SizedBox(height: 8),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _save,
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
                        widget.isEditing ? 'حفظ التعديلات' : 'إضافة المنتج',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
