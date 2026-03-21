import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/product_provider.dart';

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
    _hasReturnablePackaging = p?['has_returnable_packaging'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitsPerPkgController.dispose();
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

      if (widget.isEditing) {
        await repo.update(widget.product!['id'], {
          'name': _nameController.text.trim(),
          'unit_price': price,
          'units_per_package': unitsPerPkg,
          'has_returnable_packaging': _hasReturnablePackaging,
        });
      } else {
        await repo.create(
          name: _nameController.text.trim(),
          unitPrice: price,
          unitsPerPackage: unitsPerPkg,
          hasReturnablePackaging: _hasReturnablePackaging,
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
