import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';
import '../../auth/providers/auth_provider.dart';
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

  Future<Map<String, dynamic>?> _showStorePicker(
      BuildContext context, List<Map<String, dynamic>> stores) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.selectStore, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(),
            ...stores.map((s) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                child: Icon(Icons.store, color: Theme.of(ctx).colorScheme.onPrimaryContainer),
              ),
              title: Text(s['name'] ?? ''),
              subtitle: (s['address'] ?? '').toString().isNotEmpty ? Text(s['address'] as String) : null,
              onTap: () => Navigator.pop(ctx, s),
            )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

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

      // Send notification (fire-and-forget, best-effort)
      try {
        final notifService = ref.read(notificationServiceProvider);
        final userName = ref.read(currentUserProvider)?.name ?? '';
        notifService.sendNotification(
          eventType: 'payment_collected',
          data: {
            'driver': userName,
            'amount': amount.toStringAsFixed(2),
            'store': _selectedStoreName,
          },
        );
      } catch (e) {
        debugPrint('Payment notification failed (non-blocking): $e');
      }

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
                    // Store selector — tap to pick from bottom sheet
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
                                        await _showStorePicker(context, stores);
                                    if (selected != null) {
                                      setState(() {
                                        _selectedStoreId =
                                            selected['id'] as String;
                                        _selectedStoreName =
                                            selected['name'] ?? '';
                                        _storeBalance =
                                            (selected['credit_balance'] as num?)
                                                    ?.toDouble() ??
                                                0;
                                      });
                                      field.didChange(selected['id'] as String);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.selectStore,
                                prefixIcon: const Icon(Icons.store),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
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
