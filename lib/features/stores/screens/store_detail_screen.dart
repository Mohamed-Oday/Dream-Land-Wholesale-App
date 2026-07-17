import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/orders/screens/create_order_screen.dart';
import 'package:tawzii/features/packages/providers/package_provider.dart';
import 'package:tawzii/features/packages/widgets/package_collection_sheet.dart';
import 'package:tawzii/features/payments/providers/payment_provider.dart';
import 'package:tawzii/features/payments/screens/payment_form_screen.dart';
import 'package:tawzii/features/receipts/screens/receipt_screen.dart';
import 'package:tawzii/features/stores/providers/store_provider.dart';
import 'package:tawzii/features/stores/screens/store_form_screen.dart';

/// Local (feature-scoped) providers so the hub can refresh after field actions.
final _storeByIdProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, storeId) async {
  final repo = ref.watch(storeRepositoryProvider);
  if (repo == null) return null;
  return repo.getById(storeId);
});

final _paymentsByStoreProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, storeId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  if (repo == null) return [];
  return repo.getByStore(storeId);
});

final _packageBalancesByStoreProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, storeId) async {
  final repo = ref.watch(packageRepositoryProvider);
  if (repo == null) return [];
  return repo.getBalancesByStore(storeId);
});

/// 4b — Store detail: THE VISIT HUB.
/// Debt hero + the two field actions in the thumb zone; order entry starts here.
class StoreDetailScreen extends ConsumerWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(_storeByIdProvider(storeId));
    ref.invalidate(_paymentsByStoreProvider(storeId));
    ref.invalidate(_packageBalancesByStoreProvider(storeId));
    ref.invalidate(ordersByStoreProvider(storeId));
    ref.invalidate(storeListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final dateFormat = DateFormat('dd/MM HH:mm');

    final storeAsync = ref.watch(_storeByIdProvider(storeId));
    final orders = ref.watch(ordersByStoreProvider(storeId));
    final payments = ref.watch(_paymentsByStoreProvider(storeId));
    final packageBalances =
        ref.watch(_packageBalancesByStoreProvider(storeId));

    final store = storeAsync.valueOrNull;
    final storeName = store?['name'] as String? ?? l10n.storeDetails;
    final currentUser = ref.watch(currentUserProvider);
    final canAdjust =
        currentUser?.isOwner == true || currentUser?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),
        actions: [
          if (store != null)
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreFormScreen(store: store),
                  ),
                );
                _refreshAll(ref);
              },
              child: Text(l10n.edit),
            ),
        ],
      ),
      body: storeAsync.when(
        loading: () => const Padding(
          padding: EdgeInsetsDirectional.all(18),
          child: SkeletonList(count: 6),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsetsDirectional.all(18),
          child: ErrorRetryRow(
            onRetry: () => ref.invalidate(_storeByIdProvider(storeId)),
          ),
        ),
        data: (store) {
          if (store == null) {
            return Padding(
              padding: const EdgeInsetsDirectional.all(18),
              child: ErrorRetryRow(
                onRetry: () => ref.invalidate(_storeByIdProvider(storeId)),
              ),
            );
          }

          final balance =
              ((store['credit_balance'] as num?) ?? 0).toDouble();
          final hasDebt = balance > 0;
          final subtitle = [
            if ((store['address'] ?? '').toString().isNotEmpty)
              store['address'],
            if ((store['phone'] ?? '').toString().isNotEmpty)
              '\u2066${store['phone']}\u2069',
            if ((store['contact_person'] ?? '').toString().isNotEmpty)
              store['contact_person'],
          ].join(' · ');

          final totalPackages = packageBalances.valueOrNull?.fold<int>(
                0,
                (sum, b) => sum + ((b['balance'] as num?)?.toInt() ?? 0),
              ) ??
              0;

          return RefreshIndicator(
            onRefresh: () async => _refreshAll(ref),
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
              children: [
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 14),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12, color: t.textSecondary),
                    ),
                  ),

                // --- Debt hero ---
                Text(
                  'الرصيد المستحق',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Money(
                  balance,
                  size: MoneySize.hero,
                  tint: hasDebt ? MoneyTint.danger : MoneyTint.neutral,
                  showDot: hasDebt,
                ),
                const SizedBox(height: 4),
                Text(
                  'عبوات لدى المتجر: \u2066$totalPackages\u2069',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                if (canAdjust)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () =>
                          _showAdjustBalanceDialog(context, ref, store),
                      child: Text(l10n.adjustBalance),
                    ),
                  ),
                const SizedBox(height: 8),

                // --- The two field actions (thumb zone) ---
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateOrderScreen()),
                          );
                          _refreshAll(ref);
                        },
                        child: const Text('طلب جديد'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side:
                              BorderSide(color: t.borderStrong, width: 2),
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PaymentFormScreen()),
                          );
                          _refreshAll(ref);
                        },
                        child: const Text('تحصيل دفعة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Returnable packages ---
                SurfaceCard(
                  hardened: true,
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      14, 11, 14, 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'عبوات قابلة للاسترجاع',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            packageBalances.when(
                              loading: () => Text('…',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: t.textMuted)),
                              error: (_, _) => Text(l10n.error,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: t.textMuted)),
                              data: (_) => Text(
                                'الإجمالي: \u2066$totalPackages\u2069 ${l10n.packageUnit}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: t.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side:
                              BorderSide(color: t.borderStrong, width: 2),
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsetsDirectional
                              .symmetric(horizontal: 14),
                        ),
                        onPressed: () async {
                          await showPackageCollectionSheet(
                            context,
                            storeId: storeId,
                            storeName: store['name'] as String?,
                          );
                          _refreshAll(ref);
                        },
                        child: const Text('تحصيل العبوات',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- Store location (GPS map never mirrors) ---
                if (store['gps_lat'] != null &&
                    store['gps_lng'] != null) ...[
                  SectionLabel(l10n.storeLocation),
                  SurfaceCard(
                    padding: EdgeInsetsDirectional.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              (store['gps_lat'] as num).toDouble(),
                              (store['gps_lng'] as num).toDouble(),
                            ),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.dreamland.tawzii',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    (store['gps_lat'] as num)
                                        .toDouble(),
                                    (store['gps_lng'] as num)
                                        .toDouble(),
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.location_pin,
                                    color: t.danger,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                            const SimpleAttributionWidget(
                              source:
                                  Text('OpenStreetMap contributors'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Recent orders ---
                SectionLabel(l10n.recentOrders),
                orders.when(
                  loading: () =>
                      const SurfaceCard(child: SkeletonList(count: 3)),
                  error: (_, _) => ErrorRetryRow(
                    onRetry: () =>
                        ref.invalidate(ordersByStoreProvider(storeId)),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return _EmptySection(message: l10n.noOrdersForStore);
                    }
                    return SurfaceCard(
                      child: Column(
                        children: list.map((order) {
                          final total =
                              ((order['total'] as num?) ?? 0).toDouble();
                          final status =
                              order['status'] as String? ?? 'created';
                          final discountStatus =
                              order['discount_status'] as String? ??
                                  'none';
                          final createdAt = DateTime.tryParse(
                              order['created_at'] as String? ?? '');

                          final statusLabel = status == 'delivered'
                              ? l10n.statusDelivered
                              : status == 'cancelled'
                                  ? l10n.statusCancelled
                                  : l10n.statusCreated;
                          final discountLabel = discountStatus == 'pending'
                              ? l10n.discountPending
                              : discountStatus == 'approved'
                                  ? l10n.discountApproved
                                  : discountStatus == 'rejected'
                                      ? l10n.discountRejected
                                      : null;

                          return TawziiRow(
                            leading: StatusDot(
                              status == 'delivered'
                                  ? StatusKind.success
                                  : status == 'cancelled'
                                      ? StatusKind.danger
                                      : StatusKind.info,
                            ),
                            title: createdAt != null
                                ? '\u2066${dateFormat.format(createdAt.toLocal())}\u2069'
                                : statusLabel,
                            subtitle: [
                              statusLabel,
                              ?discountLabel,
                            ].join(' · '),
                            trailing: Money(total),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReceiptScreen.order(
                                      orderId: order['id'] as String),
                                ),
                              );
                              _refreshAll(ref);
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // --- Recent payments ---
                SectionLabel(l10n.recentPayments),
                payments.when(
                  loading: () =>
                      const SurfaceCard(child: SkeletonList(count: 2)),
                  error: (_, _) => ErrorRetryRow(
                    onRetry: () => ref
                        .invalidate(_paymentsByStoreProvider(storeId)),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return _EmptySection(
                          message: l10n.noPaymentsForStore);
                    }
                    return SurfaceCard(
                      child: Column(
                        children: list.take(10).map((payment) {
                          final amount =
                              ((payment['amount'] as num?) ?? 0)
                                  .toDouble();
                          final driver = payment['users']
                              as Map<String, dynamic>?;
                          final driverName =
                              driver?['name'] as String? ?? '';
                          final createdAt = DateTime.tryParse(
                              payment['created_at'] as String? ?? '');

                          return TawziiRow(
                            leading:
                                const StatusDot(StatusKind.success),
                            title: driverName.isNotEmpty
                                ? driverName
                                : l10n.recentPayments,
                            subtitle: createdAt != null
                                ? '\u2066${dateFormat.format(createdAt.toLocal())}\u2069'
                                : null,
                            trailing: Money(amount,
                                tint: MoneyTint.success),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAdjustBalanceDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> store,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final t = TawziiTokens.of(ctx);
        return AlertDialog(
          title: Text(l10n.adjustBalance),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.positiveAddsCredit,
                  style:
                      TextStyle(fontSize: 12, color: t.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.adjustmentAmount,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary),
                ),
                const SizedBox(height: 5),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  decoration: InputDecoration(
                    suffixText: l10n.currencyUnit,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.error;
                    final val = double.tryParse(v.trim());
                    if (val == null || val == 0) return l10n.error;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.adjustmentReason,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary),
                ),
                const SizedBox(height: 5),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return l10n.adjustmentReasonRequired;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);

                final amount = double.parse(amountCtrl.text.trim());
                final reason = reasonCtrl.text.trim();

                try {
                  final storeRepo = ref.read(storeRepositoryProvider)!;
                  final result = await storeRepo.adjustBalance(
                    storeId: storeId,
                    amount: amount,
                    reason: reason,
                  );

                  if (context.mounted) {
                    final prev = result['previous_balance'];
                    final next = result['new_balance'];
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${l10n.adjustmentSuccess}: \u2066$prev\u2069 → \u2066$next\u2069'),
                      ),
                    );
                    _refreshAll(ref);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.error}: $e')),
                    );
                  }
                }
              },
              child: Text(l10n.confirmAdjustment),
            ),
          ],
        );
      },
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: t.textMuted),
        ),
      ),
    );
  }
}
