import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/dashboard/providers/dashboard_provider.dart';
import 'package:tawzii/features/receipts/screens/receipt_screen.dart';
import 'package:tawzii/features/stores/screens/store_detail_screen.dart';
import 'package:tawzii/features/driver_loads/screens/load_list_screen.dart';

/// Admin dashboard — role-trimmed variant of the owner dashboard (canvas 2b):
/// no revenue/profit hero and no discount queue; status-dot row lists for
/// recent orders, debtors, and package alerts under labelCaps headers.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);

    final recentOrders = ref.watch(recentOrdersProvider);
    final debtors = ref.watch(topDebtorsProvider);
    final alerts = ref.watch(packageAlertsProvider);

    final dateLabel = DateFormat('EEEE d MMMM', 'ar').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dashboard),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: t.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: l10n.driverLoads,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoadListScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentOrdersProvider);
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(packageAlertsProvider);
          try {
            await Future.wait([
              ref.read(recentOrdersProvider.future),
              ref.read(dashboardSummaryProvider.future),
              ref.read(packageAlertsProvider.future),
            ]);
          } catch (_) {
            // Errors surface through the providers' AsyncValue states.
          }
        },
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
          children: [
            // ---- recent orders ---------------------------------------------
            SectionLabel(l10n.recentOrders),
            recentOrders.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return SurfaceCard(
                    child: EmptyState(
                      title: l10n.noOrders,
                      message: 'ستظهر الطلبات هنا فور تسجيلها من البائعين',
                    ),
                  );
                }
                return SurfaceCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < orders.length; i++)
                        _orderRow(
                          context,
                          l10n,
                          orders[i],
                          showDivider: i < orders.length - 1,
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SurfaceCard(child: SkeletonList(count: 4)),
              error: (_, _) => SurfaceCard(
                child: ErrorRetryRow(
                  onRetry: () => ref.invalidate(recentOrdersProvider),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ---- top debtors -----------------------------------------------
            SectionLabel(l10n.topDebtors),
            debtors.when(
              data: (stores) {
                if (stores.isEmpty) {
                  return SurfaceCard(
                    child: EmptyState(
                      title: l10n.noDebts,
                      message: 'كل المتاجر سدّدت مستحقاتها',
                    ),
                  );
                }
                return SurfaceCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < stores.length; i++)
                        TawziiRow(
                          leading: const StatusDot(StatusKind.danger),
                          title: stores[i]['name'] as String? ?? '',
                          trailing: Money(
                            _toDouble(stores[i]['credit_balance']),
                            tint: MoneyTint.danger,
                          ),
                          showDivider: i < stores.length - 1,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoreDetailScreen(
                                storeId: stores[i]['id'] as String,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SurfaceCard(child: SkeletonList(count: 3)),
              error: (_, _) => SurfaceCard(
                child: ErrorRetryRow(
                  onRetry: () => ref.invalidate(dashboardSummaryProvider),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ---- package alerts --------------------------------------------
            SectionLabel(
              '${l10n.packageAlerts} (>${ref.watch(packageAlertThresholdProvider)})',
              trailing: IconButton(
                icon: Icon(Icons.tune, size: 18, color: t.textSecondary),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.alertThreshold,
                onPressed: () => _showThresholdDialog(context, ref),
              ),
            ),
            alerts.when(
              data: (stores) {
                final threshold = ref.watch(packageAlertThresholdProvider);
                final filtered = stores
                    .where((s) => _toInt(s['total_outstanding']) >= threshold)
                    .toList();
                if (filtered.isEmpty) {
                  return SurfaceCard(
                    child: EmptyState(
                      title: l10n.allPackagesReturned,
                      message: 'لا توجد عبوات خارج المستودع فوق الحد',
                    ),
                  );
                }
                return SurfaceCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < filtered.length; i++)
                        TawziiRow(
                          leading: const StatusDot(StatusKind.info),
                          title: filtered[i]['store_name'] as String? ?? '',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\u2066${Money.format(_toInt(filtered[i]['total_outstanding']))}\u2069',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: t.info,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                    FontFeature.slashedZero(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.packageUnit,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          showDivider: i < filtered.length - 1,
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SurfaceCard(child: SkeletonList(count: 3)),
              error: (_, _) => SurfaceCard(
                child: ErrorRetryRow(
                  onRetry: () => ref.invalidate(packageAlertsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- recent order row -----------------------------------------------------

  Widget _orderRow(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> order, {
    required bool showDivider,
  }) {
    final t = TawziiTokens.of(context);

    final store = order['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] as String? ?? '';
    final driverData = order['users'] as Map<String, dynamic>?;
    final driverName = driverData?['name'] as String? ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? 'created';
    final createdAt = order['created_at'] as String?;

    String timeAgo = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = '\u2066${diff.inMinutes}\u2069 د';
        } else if (diff.inHours < 24) {
          timeAgo = '\u2066${diff.inHours}\u2069 س';
        } else {
          timeAgo = '\u2066${DateFormat('dd/MM HH:mm').format(dt)}\u2069';
        }
      } catch (_) {
        timeAgo = createdAt;
      }
    }

    // Status carried by the dot (canvas 2c): delivered = success,
    // created = info, cancelled = muted + muted struck amount.
    final StatusKind kind;
    String? statusSuffix;
    switch (status) {
      case 'delivered':
        kind = StatusKind.success;
      case 'cancelled':
        kind = StatusKind.muted;
        statusSuffix = l10n.statusCancelled;
      default:
        kind = StatusKind.info;
    }

    final subtitleParts = <String>[
      if (driverName.isNotEmpty) driverName,
      if (timeAgo.isNotEmpty) timeAgo,
      ?statusSuffix,
    ];

    return TawziiRow(
      leading: StatusDot(kind),
      title: storeName,
      subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
      trailing: Money(
        total,
        color: status == 'cancelled' ? t.textMuted : null,
      ),
      showDivider: showDivider,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen.order(
            orderId: order['id'] as String,
          ),
        ),
      ),
    );
  }

  void _showThresholdDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(packageAlertThresholdProvider);
    final controller = TextEditingController(text: '$current');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.alertThreshold),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.alertThreshold,
            suffixText: l10n.packageUnit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 1) {
                ref.read(packageAlertThresholdProvider.notifier).state = value;
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
