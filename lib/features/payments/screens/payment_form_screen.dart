import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/numeric_keypad.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../providers/payment_provider.dart';

/// Field-Kit payment collection (canvas 3b): huge amount display, in-app
/// keypad (the OS keyboard never opens for cash), quick-amount chips, live
/// balance preview and the overpayment warning. 56px targets.
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  static const _quickAmounts = [1000.0, 2000.0, 5000.0];

  String? _selectedStoreId;
  String _selectedStoreName = '';
  double _storeBalance = 0;
  double _amount = 0;
  // Bumped whenever a chip replaces the amount so the keypad rebuilds with
  // the new initial value.
  int _keypadEpoch = 0;
  bool _isLoading = false;

  bool get _canSubmit =>
      _selectedStoreId != null && _amount > 0 && !_isLoading;

  bool get _isOverpayment =>
      _selectedStoreId != null &&
      _amount > 0 &&
      _amount > _storeBalance &&
      _storeBalance > 0;

  double get _newBalance => _storeBalance - _amount;

  // ------------------------------------------------------------------
  // Store picker
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>?> _showStorePicker(
      BuildContext context, List<Map<String, dynamic>> stores) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsetsDirectional.only(
              start: 12, end: 12, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: 4, top: 4, bottom: 8),
                child:
                    SectionLabel(l10n.selectStore, padding: EdgeInsets.zero),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: stores.length,
                  itemBuilder: (_, index) {
                    final s = stores[index];
                    final balance =
                        (s['credit_balance'] as num?)?.toDouble() ?? 0;
                    final address = (s['address'] ?? '').toString();
                    return TawziiRow(
                      leading: StatusDot(
                        balance > 0 ? StatusKind.danger : StatusKind.neutral,
                      ),
                      title: s['name'] ?? '',
                      subtitle: address.isNotEmpty ? address : null,
                      trailing: Money(
                        balance,
                        tint: balance > 0
                            ? MoneyTint.danger
                            : MoneyTint.neutral,
                      ),
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
  }

  Future<void> _pickStore(List<Map<String, dynamic>> stores) async {
    if (_isLoading) return;
    final selected = await _showStorePicker(context, stores);
    if (selected == null || !mounted) return;
    setState(() {
      _selectedStoreId = selected['id'] as String;
      _selectedStoreName = selected['name'] ?? '';
      _storeBalance = (selected['credit_balance'] as num?)?.toDouble() ?? 0;
    });
  }

  // ------------------------------------------------------------------
  // Submit (behavior preserved from the previous form)
  // ------------------------------------------------------------------

  Future<void> _confirmAndSubmit() async {
    if (!_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final amount = _amount;
    final newBalance = _newBalance;

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
            _DialogRow(label: l10n.stores, value: _selectedStoreName),
            _DialogMoneyRow(label: l10n.amount, amount: amount),
            const Divider(),
            _DialogMoneyRow(
                label: l10n.currentBalance, amount: _storeBalance),
            _DialogMoneyRow(
              label: l10n.newBalance,
              amount: newBalance,
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

      // Refresh balances + payment lists.
      ref.invalidate(storeListProvider);
      ref.invalidate(paymentListProvider);
      ref.invalidate(allPaymentsProvider);

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
          backgroundColor: t.success,
        ),
      );

      Navigator.pop(context);
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Payment save error: ${e.message} / ${e.details}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveError}: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Payment save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final storesAsync = ref.watch(storeListProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 8),
                child: storesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsetsDirectional.only(top: 8),
                    child: SkeletonList(count: 3, hardened: true),
                  ),
                  error: (e, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(t, l10n, null),
                      const SizedBox(height: 8),
                      SurfaceCard(
                        child: ErrorRetryRow(
                          onRetry: () => ref.invalidate(storeListProvider),
                        ),
                      ),
                    ],
                  ),
                  data: (stores) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(t, l10n, stores),
                      const SizedBox(height: 16),
                      _buildAmountDisplay(t),
                      const SizedBox(height: 10),
                      _buildQuickChips(t),
                      const SizedBox(height: 14),
                      NumericKeypad(
                        key: ValueKey('keypad$_keypadEpoch'),
                        initialValue: _amount > 0 ? _amount : null,
                        allowDecimal: true,
                        hardened: true,
                        showDisplay: false,
                        onChanged: (v) => setState(() => _amount = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(t, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    TawziiTokens t,
    AppLocalizations l10n,
    List<Map<String, dynamic>>? stores,
  ) {
    return Row(
      children: [
        _SquareBackButton(onTap: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: stores == null ? null : () => _pickStore(stores),
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedStoreName.isEmpty
                      ? l10n.selectStore
                      : _selectedStoreName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: t.textPrimary,
                  ),
                ),
                if (_selectedStoreId != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l10n.currentBalance}: ',
                        style:
                            TextStyle(fontSize: 12, color: t.textSecondary),
                      ),
                      Money(
                        _storeBalance,
                        tint: _storeBalance > 0
                            ? MoneyTint.danger
                            : MoneyTint.neutral,
                        numberStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'اضغط لاختيار المتجر',
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (stores != null)
          TextButton(
            onPressed: _isLoading ? null : () => _pickStore(stores),
            child: const Text('تغيير', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildAmountDisplay(TawziiTokens t) {
    return Column(
      children: [
        Text(
          'مبلغ الدفعة',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Money(
          _amount,
          size: MoneySize.hero,
          decimals: _amount != _amount.roundToDouble(),
          numberStyle: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 8),
        _buildBalancePreview(t),
      ],
    );
  }

  Widget _buildBalancePreview(TawziiTokens t) {
    if (_selectedStoreId == null || _amount <= 0) {
      // Keep the vertical rhythm stable while typing.
      return const SizedBox(height: 20);
    }
    if (_isOverpayment) {
      final over = _amount - _storeBalance;
      return Text(
        'المبلغ أكبر من الرصيد المستحق بـ '
        '\u2066${Money.format(over, decimals: over != over.roundToDouble())}'
        '\u2069 دج',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: t.warning,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'الرصيد الجديد: ',
          style: TextStyle(fontSize: 13, color: t.textSecondary),
        ),
        Money(
          _newBalance,
          decimals: _newBalance != _newBalance.roundToDouble(),
          numberStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChips(TawziiTokens t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final value in _quickAmounts) ...[
          _QuickAmountChip(
            value: value,
            selected: _amount == value,
            enabled: !_isLoading,
            onTap: () => setState(() {
              _amount = value;
              _keypadEpoch++;
            }),
          ),
          if (value != _quickAmounts.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildBottomBar(TawziiTokens t, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.borderStrong, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _confirmAndSubmit : null,
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.onAccent,
                      ),
                    )
                  : Text(
                      l10n.recordPayment,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 48px quick-amount pill — 2px border, amber outline when selected.
class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final double value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? t.accent : t.borderStrong,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Money(
            value,
            showUnit: false,
            numberStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 48px square back button (Field-Kit, 2px borderStrong).
class _SquareBackButton extends StatelessWidget {
  const _SquareBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.borderStrong, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.arrow_back, size: 20, color: t.textSecondary),
        ),
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
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

class _DialogMoneyRow extends StatelessWidget {
  const _DialogMoneyRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  final String label;
  final double amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Money(
            amount,
            decimals: true,
            numberStyle: bold
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
        ],
      ),
    );
  }
}
