import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import '../providers/product_provider.dart';

/// Product create/edit — folded into a bottom sheet (one surface rung up
/// over the scrim), quiet labels above the fields per canvas 4d.
///
/// Returns `true` when the product was saved.
Future<bool?> showProductFormSheet(
  BuildContext context, {
  Map<String, dynamic>? product,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProductFormSheet(product: product),
  );
}

class _ProductFormSheet extends ConsumerStatefulWidget {
  const _ProductFormSheet({this.product});

  final Map<String, dynamic>? product;

  bool get isEditing => product != null;

  @override
  ConsumerState<_ProductFormSheet> createState() =>
      _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
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
    _unitsPerPkgController = TextEditingController(
        text: p?['units_per_package']?.toString() ?? '');
    _costPriceController =
        TextEditingController(text: p?['cost_price']?.toString() ?? '');
    _stockController =
        TextEditingController(text: p?['stock_on_hand']?.toString() ?? '0');
    _lowStockThresholdController = TextEditingController(
        text: p?['low_stock_threshold']?.toString() ?? '0');
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
        final lowStockThreshold =
            int.tryParse(_lowStockThresholdController.text.trim()) ?? 0;
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

      if (mounted) {
        ref.invalidate(productListProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'خطأ في الحفظ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _label(String text, {bool required = false}) {
    final t = TawziiTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 5, top: 12),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.textSecondary,
          ),
          children: [
            if (required)
              TextSpan(text: ' *', style: TextStyle(color: t.danger)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 18,
        end: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 4,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? 'تعديل المنتج' : 'إضافة منتج',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              _label('اسم المنتج', required: true),
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              _label('سعر البيع (دج)', required: true),
              TextFormField(
                controller: _priceController,
                enabled: !_isLoading,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  final price = double.tryParse(v.trim());
                  if (price == null) return 'أدخل رقماً صحيحاً';
                  if (price <= 0) return 'السعر يجب أن يكون أكبر من صفر';
                  return null;
                },
              ),
              _label('${l10n.costPrice} (دج)'),
              TextFormField(
                controller: _costPriceController,
                enabled: !_isLoading,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'اختياري'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final cost = double.tryParse(v.trim());
                  if (cost == null) return 'أدخل رقماً صحيحاً';
                  if (cost < 0) return 'السعر يجب أن يكون صفر أو أكبر';
                  return null;
                },
              ),
              if (widget.isEditing) ...[
                _label(l10n.stockOnHand),
                TextFormField(
                  controller: _stockController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null) return 'أدخل رقماً صحيحاً';
                    if (n < 0) return 'لا يمكن أن يكون سالباً';
                    return null;
                  },
                ),
                _label(l10n.alertThreshold),
                TextFormField(
                  controller: _lowStockThresholdController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(hintText: '0 = بدون تنبيه'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null) return 'أدخل رقماً صحيحاً';
                    if (n < 0) return 'لا يمكن أن يكون سالباً';
                    return null;
                  },
                ),
              ],
              _label('عدد الوحدات في العبوة'),
              TextFormField(
                controller: _unitsPerPkgController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'اختياري'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) {
                    return 'أدخل عدداً صحيحاً أكبر من صفر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsetsDirectional.zero,
                title: const Text('تغليف قابل للإرجاع',
                    style: TextStyle(fontSize: 15)),
                subtitle: Text(
                  'هل يحتوي المنتج على عبوات يجب إرجاعها؟',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                value: _hasReturnablePackaging,
                onChanged: _isLoading
                    ? null
                    : (v) => setState(() => _hasReturnablePackaging = v),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: t.textSecondary),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: t.onAccent),
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
