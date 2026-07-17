import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../suppliers/providers/supplier_provider.dart';

/// Supplier create/edit form as a bottom sheet (canvas 6a: "supplier form =
/// sheet"). Absorbs the old SupplierFormScreen behavior: name required,
/// phone/address/contact optional, create or update via SupplierRepository,
/// invalidates supplierListProvider on save.
Future<void> showSupplierFormSheet(
  BuildContext context, {
  Map<String, dynamic>? supplier,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SupplierFormSheet(supplier: supplier),
  );
}

class _SupplierFormSheet extends ConsumerStatefulWidget {
  const _SupplierFormSheet({this.supplier});

  final Map<String, dynamic>? supplier;

  bool get isEditing => supplier != null;

  @override
  ConsumerState<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends ConsumerState<_SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameController = TextEditingController(text: s?['name'] ?? '');
    _phoneController = TextEditingController(text: s?['phone'] ?? '');
    _addressController = TextEditingController(text: s?['address'] ?? '');
    _contactController =
        TextEditingController(text: s?['contact_person'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactController.dispose();
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
      final repo = ref.read(supplierRepositoryProvider)!;

      if (widget.isEditing) {
        await repo.update(widget.supplier!['id'], {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'contact_person': _contactController.text.trim(),
        });
      } else {
        await repo.create(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          contactPerson: _contactController.text.trim(),
        );
      }

      if (mounted) {
        ref.invalidate(supplierListProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'خطأ في الحفظ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _fieldLabel(BuildContext context, String text) {
    final t = TawziiTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? l10n.editSupplier : l10n.addSupplier,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _fieldLabel(context, l10n.supplierName),
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 14),
              _fieldLabel(context, 'رقم الهاتف'),
              TextFormField(
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'اختياري'),
              ),
              const SizedBox(height: 14),
              _fieldLabel(context, 'العنوان'),
              TextFormField(
                controller: _addressController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'اختياري'),
              ),
              const SizedBox(height: 14),
              _fieldLabel(context, 'جهة الاتصال'),
              TextFormField(
                controller: _contactController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(hintText: 'اختياري'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: t.textSecondary),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(
                  _isLoading
                      ? '...'
                      : widget.isEditing
                          ? 'حفظ التعديلات'
                          : l10n.addSupplier,
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
