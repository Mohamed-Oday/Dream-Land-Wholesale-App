import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/core/widgets/date_range_filter_bar.dart';
import '../providers/payment_provider.dart';
import 'payment_form_screen.dart';

class PaymentListScreen extends ConsumerWidget {
  final bool isOwner;

  const PaymentListScreen({super.key, this.isOwner = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final paymentsAsync =
        ref.watch(isOwner ? allPaymentsProvider : paymentListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.payments)),
      floatingActionButton: isOwner
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentFormScreen(),
                  ),
                );
                ref.invalidate(paymentListProvider);
              },
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          const DateRangeFilterBar(),
          Expanded(child: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('خطأ في تحميل المدفوعات',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(
                    isOwner ? allPaymentsProvider : paymentListProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(l10n.noPayments, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    l10n.emptyPaymentMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref
                .invalidate(isOwner ? allPaymentsProvider : paymentListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  .copyWith(bottom: 80),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _PaymentCard(
                  payment: payment,
                  isOwner: isOwner,
                  l10n: l10n,
                  theme: theme,
                );
              },
            ),
          );
        },
      )),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final bool isOwner;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PaymentCard({
    required this.payment,
    required this.isOwner,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final store = payment['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] ?? '';
    final driverData = payment['users'] as Map<String, dynamic>?;
    final driverName = driverData?['name'] ?? '';
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final prevBalance =
        (payment['previous_balance'] as num?)?.toDouble() ?? 0;
    final newBalance = (payment['new_balance'] as num?)?.toDouble() ?? 0;
    final createdAt = payment['created_at'] as String?;

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    return RepaintBoundary(
      child: Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Payment icon
            CircleAvatar(
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
              child: const Icon(Icons.payments, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            // Payment info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (isOwner && driverName.isNotEmpty) ...[
                    Text(
                      '${l10n.driver}: $driverName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Balance change
                  Text(
                    '${prevBalance.toStringAsFixed(2)} → ${newBalance.toStringAsFixed(2)} د.ج',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amount.toStringAsFixed(2)} د.ج',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }
}
