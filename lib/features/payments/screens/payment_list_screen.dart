import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/widgets/date_range_filter_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/hero_number.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/section_label.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/surface_card.dart';
import '../../../core/ui/tawzii_row.dart';
import '../providers/payment_provider.dart';
import 'payment_form_screen.dart';

/// Payment list (canvas 6e): collected hero, success color on the numbers
/// only, day-grouped status-dot rows. Driver keeps the collect FAB and
/// Field-Kit hardened rows; owner gets the flat surface-card list.
class PaymentListScreen extends ConsumerWidget {
  final bool isOwner;

  const PaymentListScreen({super.key, this.isOwner = false});

  static String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'اليوم';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس';
    return '\u2066${DateFormat('dd/MM/yyyy').format(dt)}\u2069';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final paymentsAsync =
        ref.watch(isOwner ? allPaymentsProvider : paymentListProvider);

    void invalidate() =>
        ref.invalidate(isOwner ? allPaymentsProvider : paymentListProvider);

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
          Expanded(
            child: paymentsAsync.when(
              loading: () => ListView(
                padding: const EdgeInsetsDirectional.all(18),
                children: [
                  if (isOwner)
                    const SurfaceCard(child: SkeletonList(count: 6))
                  else
                    const SkeletonList(count: 5, hardened: true),
                ],
              ),
              error: (e, _) => Center(
                child: ErrorRetryRow(onRetry: invalidate),
              ),
              data: (payments) {
                if (payments.isEmpty) {
                  return EmptyState(
                    title: l10n.noPayments,
                    message: l10n.emptyPaymentMessage,
                  );
                }

                final total = payments.fold<double>(
                  0,
                  (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
                );

                // Group by day, preserving newest-first order.
                final groups = <String, List<Map<String, dynamic>>>{};
                for (final p in payments) {
                  final createdAt = p['created_at'] as String?;
                  final dt = createdAt == null
                      ? null
                      : DateTime.tryParse(createdAt)?.toLocal();
                  final label = dt == null ? 'أقدم' : _dayLabel(dt);
                  groups.putIfAbsent(label, () => []).add(p);
                }

                return RefreshIndicator(
                  onRefresh: () async => invalidate(),
                  child: ListView(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 96),
                    children: [
                      // Collected hero — success stays on row numbers only
                      HeroNumber(label: 'المحصّل', value: total),
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.only(top: 4, bottom: 16),
                        child: Builder(builder: (context) {
                          final t = TawziiTokens.of(context);
                          return Text(
                            '\u2066${payments.length}\u2069 دفعات · كلها نقداً',
                            style:
                                TextStyle(fontSize: 12, color: t.textMuted),
                          );
                        }),
                      ),
                      for (final entry in groups.entries) ...[
                        SectionLabel(entry.key),
                        if (isOwner)
                          SurfaceCard(
                            margin:
                                const EdgeInsetsDirectional.only(bottom: 14),
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < entry.value.length;
                                    i++)
                                  _PaymentRow(
                                    payment: entry.value[i],
                                    isOwner: true,
                                    showDivider:
                                        i < entry.value.length - 1,
                                  ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding:
                                const EdgeInsetsDirectional.only(bottom: 6),
                            child: Column(
                              children: [
                                for (final p in entry.value) ...[
                                  _PaymentRow(
                                    payment: p,
                                    isOwner: false,
                                    hardened: true,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.isOwner,
    this.showDivider = false,
    this.hardened = false,
  });

  final Map<String, dynamic> payment;
  final bool isOwner;
  final bool showDivider;
  final bool hardened;

  @override
  Widget build(BuildContext context) {
    final store = payment['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] as String? ?? '';
    final driverData = payment['users'] as Map<String, dynamic>?;
    final driverName = driverData?['name'] as String? ?? '';
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final prevBalance =
        (payment['previous_balance'] as num?)?.toDouble() ?? 0;
    final newBalance = (payment['new_balance'] as num?)?.toDouble() ?? 0;
    final createdAt = payment['created_at'] as String?;
    final dt =
        createdAt == null ? null : DateTime.tryParse(createdAt)?.toLocal();
    final time = dt == null ? '' : DateFormat('HH:mm').format(dt);

    final subtitleParts = <String>[
      if (isOwner && driverName.isNotEmpty) driverName,
      'نقداً',
      if (time.isNotEmpty) '\u2066$time\u2069',
      '\u2066${Money.format(prevBalance)}\u2069 ← \u2066${Money.format(newBalance)}\u2069',
    ];

    return TawziiRow(
      leading: StatusDot(StatusKind.success, size: hardened ? 10 : 8),
      title: storeName,
      subtitle: subtitleParts.join(' · '),
      trailing: Money(amount, tint: MoneyTint.success),
      showDivider: showDivider,
      hardened: hardened,
    );
  }
}
