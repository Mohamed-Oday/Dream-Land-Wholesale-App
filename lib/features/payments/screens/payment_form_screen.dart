import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../../stores/providers/store_provider.dart';
import '../providers/payment_provider.dart';

class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStoreId;
  String _selectedStoreName = '';
  double _storeBalance = 0;
  final _amountController = TextEditingController();
  bool _isLoading = false;

  double get _enteredAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0;

  bool get _canSubmit =>
      _selectedStoreId != null &&
      _enteredAmount > 0 &&
      !_isLoading;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit() async {
    if (!_formKey.currentState!.validate() || !_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;
    final amount = _enteredAmount;
    final newBalance = _storeBalance - amount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmPayment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmPaymentMessage),
            const SizedBox(height: 16),
            _DialogRow(
                label: l10n.stores, value: _selectedStoreName),
            _DialogRow(
                label: l10n.amount,
                value: '${amount.toStringAsFixed(2)} د.ج'),
            const Divider(),
            _DialogRow(
                label: l10n.currentBalance,
                value: '${_storeBalance.toStringAsFixed(2)} د.ج'),
            _DialogRow(
              label: l10n.newBalance,
              value: '${newBalance.toStringAsFixed(2)} د.ج',
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
      final repo = ref.read(paymentRepositoryProvider)!;

      await repo.create(
        storeId: _selectedStoreId!,
        amount: amount,
      );

      if (!mounted) return;

      // Invalidate store list to refresh balances
      ref.invalidate(storeListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentCollected),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context);
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
      debugPrint('Payment save error: ${e.message} / ${e.details}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.saveError}: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Payment save error: $e');
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newPayment)),
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
                      data: (stores) => DropdownButtonFormField<String>(
                        initialValue: _selectedStoreId,
                        decoration: InputDecoration(
                          labelText: l10n.selectStore,
                          prefixIcon: const Icon(Icons.store),
                        ),
                        items: stores.map((s) {
                          return DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedStoreId = value;
                                  final store = stores
                                      .firstWhere((s) => s['id'] == value);
                                  _selectedStoreName =
                                      store['name'] ?? '';
                                  _storeBalance =
                                      (store['credit_balance'] as num?)
                                              ?.toDouble() ??
                                          0;
                                });
                              },
                        validator: (v) => v == null ? 'مطلوب' : null,
                      ),
                    ),

                    // Current balance display
                    if (_selectedStoreId != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _storeBalance > 0
                              ? AppColors.warning.withValues(alpha: 0.08)
                              : AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _storeBalance > 0
                                ? AppColors.warning.withValues(alpha: 0.3)
                                : AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _storeBalance > 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: _storeBalance > 0
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.currentBalance,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${_storeBalance.toStringAsFixed(2)} د.ج',
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [
                                        const FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Amount input
                    TextFormField(
                      controller: _amountController,
                      enabled: !_isLoading,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.enterAmount,
                        prefixIcon: const Icon(Icons.payments),
                        suffixText: 'د.ج',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        final amount = double.tryParse(v.trim());
                        if (amount == null) return 'أدخل رقماً صحيحاً';
                        if (amount <= 0) return 'المبلغ يجب أن يكون أكبر من صفر';
                        return null;
                      },
                    ),

                    // Overpayment warning
                    if (_selectedStoreId != null &&
                        _enteredAmount > 0 &&
                        _enteredAmount > _storeBalance &&
                        _storeBalance > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.overpaymentWarning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    // Payment summary
                    if (_selectedStoreId != null && _enteredAmount > 0) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: l10n.currentBalance,
                        value: '${_storeBalance.toStringAsFixed(2)} د.ج',
                        theme: theme,
                      ),
                      _SummaryRow(
                        label: l10n.amount,
                        value:
                            '- ${_enteredAmount.toStringAsFixed(2)} د.ج',
                        theme: theme,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 4),
                      _SummaryRow(
                        label: l10n.newBalance,
                        value:
                            '${(_storeBalance - _enteredAmount).toStringAsFixed(2)} د.ج',
                        theme: theme,
                        bold: true,
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
                        l10n.recordPayment,
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final bool bold;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: [const FontFeature.tabularFigures()],
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: color ?? theme.colorScheme.onSurfaceVariant,
            fontFeatures: [const FontFeature.tabularFigures()],
          );

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

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DialogRow({
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
