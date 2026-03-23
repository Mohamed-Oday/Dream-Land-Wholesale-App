import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../providers/product_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;

  const StockAdjustmentScreen({super.key, required this.product});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState
    extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  int get _currentStock =>
      (widget.product['stock_on_hand'] as num?)?.toInt() ?? 0;

  int get _adjustmentQty =>
      int.tryParse(_quantityController.text.trim()) ?? 0;

  int get _projectedResult => _currentStock + _adjustmentQty;

  bool get _isResultNegative => _projectedResult < 0;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    final qty = _adjustmentQty;
    if (qty == 0 || _isResultNegative) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(productRepositoryProvider)!;
      await repo.adjustStock(
        productId: widget.product['id'] as String,
        quantity: qty,
        notes: _reasonController.text.trim(),
      );

      ref.invalidate(productListProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.stockAdjusted),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
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
    final productName = widget.product['name'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adjustStock)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product info card
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.inventory_2,
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(productName,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              '${l10n.stockOnHand}: $_currentStock',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quantity field
              TextFormField(
                controller: _quantityController,
                enabled: !_isLoading,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.quantity,
                  prefixIcon: const Icon(Icons.add_circle_outline),
                  helperText: 'موجب = إضافة، سالب = خصم',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'أدخل رقماً صحيحاً';
                  if (n == 0) return 'لا يمكن أن يكون صفراً';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Projected result
              if (_quantityController.text.trim().isNotEmpty &&
                  int.tryParse(_quantityController.text.trim()) != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isResultNegative
                        ? AppColors.error.withValues(alpha: 0.08)
                        : AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isResultNegative
                          ? AppColors.error.withValues(alpha: 0.3)
                          : AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isResultNegative
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 20,
                        color: _isResultNegative
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.projectedResult(_projectedResult),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _isResultNegative
                              ? AppColors.error
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_isResultNegative) ...[
                        const Spacer(),
                        Text(
                          l10n.resultCannotBeNegative,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Reason field
              TextFormField(
                controller: _reasonController,
                enabled: !_isLoading,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.adjustmentReason,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.notes),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 24),

              // Submit button
              FilledButton(
                onPressed: (_isLoading || _isResultNegative || _adjustmentQty == 0)
                    ? null
                    : _submit,
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
                    : Text(l10n.confirm,
                        style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
