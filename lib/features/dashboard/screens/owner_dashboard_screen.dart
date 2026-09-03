import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/hero_number.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/dashboard/providers/dashboard_provider.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/orders/screens/order_list_screen.dart';
import 'package:tawzii/features/payments/screens/payment_list_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';
import 'package:tawzii/features/products/screens/product_detail_screen.dart';
import 'package:tawzii/features/products/screens/product_list_screen.dart';
import 'package:tawzii/features/driver_loads/screens/load_list_screen.dart';
import 'package:tawzii/features/stores/screens/store_detail_screen.dart';
import 'package:tawzii/core/utils/package_stock.dart';

/// Owner dashboard — canvas 2b "Queue-first": the decision queue (pending
/// discounts with a draining RTL countdown) sits ABOVE the revenue hero,
/// followed by debtors / package / low-stock lists as status-dot rows.
class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  /// Last time the summary loaded successfully — shown on stale/offline hero.
  DateTime? _lastUpdated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);

    ref.listen(dashboardSummaryProvider, (previous, next) {
      if (next.hasValue && !next.isLoading) {
        _lastUpdated = DateTime.now();
      }
    });

    final summary = ref.watch(dashboardSummaryProvider);
    final revenue = ref.watch(todayRevenueProvider);
    final orderCount = ref.watch(todayOrderCountProvider);
    final purchases = ref.watch(todayPurchasesProvider);
    final profit = ref.watch(todayProfitProvider);
    final debtors = ref.watch(topDebtorsProvider);
    final alerts = ref.watch(packageAlertsProvider);
    final pendingDiscounts = ref.watch(pendingDiscountsProvider);
    final lowStockProducts = ref.watch(lowStockProductsProvider);

    final initialLoading = summary.isLoading && !summary.hasValue;
    final failed = summary.hasError && !summary.isLoading;
    // Stale: refresh failed but we still hold the previous numbers.
    final stale = failed && summary.hasValue;
    final offline = failed && _isNetworkError(summary.error);
    final lastUpdatedLabel = _lastUpdated == null
        ? null
        : DateFormat('HH:mm').format(_lastUpdated!);

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'إجراءات سريعة',
            onSelected: (value) {
              switch (value) {
                case 'loads':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoadListScreen()),
                  );
                case 'payments':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentListScreen(isOwner: true),
                    ),
                  );
                case 'orders':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderListScreen(isOwner: true),
                    ),
                  );
                case 'products':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductListScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'loads', child: Text(l10n.driverLoads)),
              PopupMenuItem(value: 'payments', child: Text(l10n.payments)),
              PopupMenuItem(value: 'orders', child: Text(l10n.orders)),
              PopupMenuItem(value: 'products', child: Text(l10n.products)),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
          children: [
            // ---- offline / stale banner (2d) -------------------------------
            if (stale || (failed && !summary.hasValue)) ...[
              if (offline)
                OfflineBanner(lastSyncedLabel: lastUpdatedLabel)
              else
                SurfaceCard(
                  child: ErrorRetryRow(
                    title: 'تعذّر تحميل اللوحة',
                    message: lastUpdatedLabel == null
                        ? 'تحقق من الاتصال ثم أعد المحاولة'
                        : 'تحقق من الاتصال — الأرقام المعروضة محفوظة من \u2066$lastUpdatedLabel\u2069',
                    onRetry: _retryAll,
                  ),
                ),
              const SizedBox(height: 14),
            ],

            if (initialLoading)
              ..._buildSkeleton()
            else if (failed && !summary.hasValue)
              const SizedBox.shrink()
            else ...[
              // ---- decision queue (above the hero, 2b) ---------------------
              ..._buildDecisionQueue(
                context,
                pendingDiscounts,
                paused: stale,
              ),

              // ---- revenue hero + borderless stat row ----------------------
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: 2, end: 2, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeroNumber(
                      label: l10n.todayRevenue,
                      value: revenue.valueOrNull ?? 0,
                      stale: stale,
                      lastUpdatedLabel: lastUpdatedLabel,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      stale: stale,
                      profitLabel: l10n.todayProfit,
                      profit: profit.valueOrNull ?? 0,
                      purchasesLabel: l10n.todayPurchases,
                      purchases: purchases.valueOrNull ?? 0,
                      ordersLabel: l10n.orders,
                      orderCount: orderCount.valueOrNull ?? 0,
                    ),
                  ],
                ),
              ),

              // ---- empty day (2d) ------------------------------------------
              if (!stale &&
                  orderCount.valueOrNull == 0 &&
                  (revenue.valueOrNull ?? 0) == 0 &&
                  !orderCount.isLoading) ...[
                const SizedBox(height: 14),
                SurfaceCard(
                  child: EmptyState(
                    title: 'لا توجد طلبات اليوم',
                    message: 'ستظهر أول عملية بيع هنا فور تسجيلها من البائعين',
                    ctaLabel: 'تحميل بائع',
                    onCta: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoadListScreen()),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // ---- top debtors ---------------------------------------------
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
                loading: () =>
                    const SurfaceCard(child: SkeletonList(count: 3)),
                error: (_, _) => SurfaceCard(
                  child: ErrorRetryRow(
                    onRetry: () => ref.invalidate(dashboardSummaryProvider),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ---- package alerts ------------------------------------------
              SectionLabel(
                '${l10n.packageAlerts} (>${ref.watch(packageAlertThresholdProvider)})',
                trailing: IconButton(
                  icon: Icon(Icons.tune, size: 18, color: t.textSecondary),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.alertThreshold,
                  onPressed: () => _showThresholdDialog(context),
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
                            title:
                                filtered[i]['store_name'] as String? ?? '',
                            trailing: _CountBadge(
                              count:
                                  _toInt(filtered[i]['total_outstanding']),
                              unit: l10n.packageUnit,
                              color: t.info,
                            ),
                            showDivider: i < filtered.length - 1,
                          ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const SurfaceCard(child: SkeletonList(count: 3)),
                error: (_, _) => SurfaceCard(
                  child: ErrorRetryRow(
                    onRetry: () => ref.invalidate(packageAlertsProvider),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ---- low stock -----------------------------------------------
              SectionLabel(l10n.lowStockAlerts),
              lowStockProducts.when(
                data: (products) {
                  if (products.isEmpty) {
                    return SurfaceCard(
                      child: EmptyState(
                        title: l10n.noLowStock,
                        message: 'كل المنتجات فوق حد التنبيه',
                      ),
                    );
                  }
                  return SurfaceCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < products.length; i++)
                          TawziiRow(
                            leading: const StatusDot(StatusKind.warning),
                            title: products[i]['name'] as String? ?? '',
                            trailing: _CountBadge(
                              count: stockOf(products[i]),
                              formatted:
                                  formatStockNumber(stockOf(products[i])),
                              unit: 'متبقي',
                              unitFirst: true,
                              color: t.warning,
                            ),
                            showDivider: i < products.length - 1,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    product: products[i],
                                  ),
                                ),
                              );
                              ref.invalidate(dashboardSummaryProvider);
                              ref.invalidate(productListProvider);
                            },
                          ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const SurfaceCard(child: SkeletonList(count: 2)),
                error: (_, _) => SurfaceCard(
                  child: ErrorRetryRow(
                    onRetry: () => ref.invalidate(dashboardSummaryProvider),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- decision queue -------------------------------------------------------

  List<Widget> _buildDecisionQueue(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> pendingDiscounts, {
    required bool paused,
  }) {
    final t = TawziiTokens.of(context);
    final items = pendingDiscounts.valueOrNull ?? const [];
    if (items.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsetsDirectional.only(
            start: 2, end: 2, bottom: 8, top: 4),
        child: Text(
          'يتطلب قرارك الآن · \u2066${items.length}\u2069',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            height: 1.4,
            color: t.warning,
          ),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _DiscountCard(
                order: items[i],
                paused: paused,
                onApprove: () => _handleApprove(items[i]),
                onReject: () => _handleReject(items[i]),
              ),
              if (i < items.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
    ];
  }

  // ---- skeleton (2d) --------------------------------------------------------

  List<Widget> _buildSkeleton() {
    return const [
      SurfaceCard(child: SkeletonList(count: 2)),
      SizedBox(height: 14),
      SurfaceCard(child: SkeletonList(count: 3)),
      SizedBox(height: 14),
      SurfaceCard(child: SkeletonList(count: 3)),
    ];
  }

  // ---- actions --------------------------------------------------------------

  Future<void> _refreshAll() async {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(packageAlertsProvider);
    ref.invalidate(pendingDiscountsProvider);
    try {
      await Future.wait([
        ref.read(dashboardSummaryProvider.future),
        ref.read(packageAlertsProvider.future),
        ref.read(pendingDiscountsProvider.future),
      ]);
    } catch (_) {
      // Errors surface through the providers' AsyncValue states.
    }
  }

  void _retryAll() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(packageAlertsProvider);
    ref.invalidate(pendingDiscountsProvider);
  }

  void _showThresholdDialog(BuildContext context) {
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

  Future<void> _handleApprove(Map<String, dynamic> order) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.approveDiscount),
        content: Text(l10n.confirmApproveDiscount),
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

    try {
      final repo = ref.read(orderRepositoryProvider)!;
      final user = ref.read(currentUserProvider)!;
      await repo.approveDiscount(order['id'] as String, user.id);
      ref.invalidate(pendingDiscountsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discountApproved)),
        );
      }
    } catch (e) {
      ref.invalidate(pendingDiscountsProvider);
      if (mounted) {
        final msg = e.toString().contains('discount_already_processed')
            ? l10n.discountAlreadyProcessed
            : l10n.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> order) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rejectDiscount),
        content: Text(l10n.confirmRejectDiscount),
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

    try {
      final repo = ref.read(orderRepositoryProvider)!;
      await repo.rejectDiscount(order['id'] as String);
      ref.invalidate(pendingDiscountsProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discountRejected)),
        );
      }
    } catch (e) {
      ref.invalidate(pendingDiscountsProvider);
      if (mounted) {
        final msg = e.toString().contains('discount_already_processed')
            ? l10n.discountAlreadyProcessed
            : l10n.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  // ---- helpers --------------------------------------------------------------

  static bool _isNetworkError(Object? error) {
    if (error == null) return false;
    final s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('clientexception') ||
        s.contains('connection') ||
        s.contains('timeout') ||
        s.contains('network');
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

// ---------------------------------------------------------------------------
// Secondary borderless stat row beneath the hero (profit / purchases / orders).
// ---------------------------------------------------------------------------

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.stale,
    required this.profitLabel,
    required this.profit,
    required this.purchasesLabel,
    required this.purchases,
    required this.ordersLabel,
    required this.orderCount,
  });

  final bool stale;
  final String profitLabel;
  final double profit;
  final String purchasesLabel;
  final double purchases;
  final String ordersLabel;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: t.textSecondary,
    );
    const numberOverride = TextStyle(fontSize: 13, height: 1.5);

    return Wrap(
      spacing: 18,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(profitLabel, style: labelStyle),
            const SizedBox(width: 5),
            Money(
              profit,
              size: MoneySize.body,
              showUnit: false,
              tint: stale
                  ? MoneyTint.neutral
                  : (profit >= 0 ? MoneyTint.success : MoneyTint.danger),
              color: stale ? t.textSecondary : null,
              numberStyle: numberOverride,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(purchasesLabel, style: labelStyle),
            const SizedBox(width: 5),
            Money(
              purchases,
              size: MoneySize.body,
              showUnit: false,
              color: stale ? t.textSecondary : null,
              numberStyle: numberOverride,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ordersLabel, style: labelStyle),
            const SizedBox(width: 5),
            Text(
              '\u2066${Money.format(orderCount)}\u2069',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: stale ? t.textSecondary : t.textPrimary,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                  FontFeature.slashedZero(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Trailing count badge for non-money numbers (packages / stock remaining).
// ---------------------------------------------------------------------------

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.unit,
    required this.color,
    this.unitFirst = false,
    this.formatted,
  });

  final num count;

  /// Overrides the money-style formatting of [count]. Stock is a fractional
  /// package count, and Money.format would round 0.8 up to a misleading 1.
  final String? formatted;
  final String unit;
  final Color color;

  /// true renders 'متبقي 5' style; false renders '14 عبوة' style.
  final bool unitFirst;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final number = Text(
      '\u2066${formatted ?? Money.format(count)}\u2069',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: color,
        fontFeatures: const [
          FontFeature.tabularFigures(),
          FontFeature.slashedZero(),
        ],
      ),
    );
    final label = Text(
      unit,
      style: TextStyle(fontSize: 13, height: 1.5, color: t.textSecondary),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: unitFirst
          ? [label, const SizedBox(width: 4), number]
          : [number, const SizedBox(width: 4), label],
    );
  }
}

// ---------------------------------------------------------------------------
// Pending-discount decision card — accentSoft surface, draining RTL countdown
// (red only in the final 60s; paused while offline).
// ---------------------------------------------------------------------------

class _DiscountCard extends StatefulWidget {
  const _DiscountCard({
    required this.order,
    required this.paused,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> order;

  /// Offline/stale: countdown display freezes ("قيد الانتظار — غير متصل").
  final bool paused;

  final VoidCallback onApprove;
  final VoidCallback onReject;

  static const int _windowSeconds = 180;

  @override
  State<_DiscountCard> createState() => _DiscountCardState();
}

class _DiscountCardState extends State<_DiscountCard> {
  Timer? _timer;
  int _remainingSeconds = _DiscountCard._windowSeconds;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    if (!widget.paused) _startTimer();
  }

  @override
  void didUpdateWidget(covariant _DiscountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        _timer?.cancel();
      } else {
        _updateRemaining();
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final createdAt =
        DateTime.tryParse(widget.order['created_at'] as String? ?? '');
    if (createdAt == null) return;

    final elapsed = DateTime.now().toUtc().difference(createdAt.toUtc());
    final remaining =
        const Duration(seconds: _DiscountCard._windowSeconds) - elapsed;

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      _timer?.cancel();
      _expired = true;
      _remainingSeconds = 0;
    } else {
      _remainingSeconds = remaining.inSeconds;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    final store = widget.order['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] as String? ?? '';
    final driver = widget.order['users'] as Map<String, dynamic>?;
    final driverName = driver?['name'] as String? ?? '';
    final discount = (widget.order['discount'] as num?)?.toDouble() ?? 0;
    final total = (widget.order['total'] as num?)?.toDouble() ?? 0;

    final finalMinute = !_expired && _remainingSeconds <= 60;
    final fraction = _expired
        ? 0.0
        : (_remainingSeconds / _DiscountCard._windowSeconds).clamp(0.0, 1.0);

    // Countdown label.
    final String timeText;
    final Color timeColor;
    if (widget.paused) {
      timeText = 'متوقف مؤقتاً';
      timeColor = t.textMuted;
    } else if (_expired) {
      timeText = 'انتهت المهلة';
      timeColor = t.textMuted;
    } else {
      final mins = _remainingSeconds ~/ 60;
      final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
      timeText = l10n.timeRemaining(mins, secs);
      timeColor = finalMinute ? t.danger : t.warning;
    }

    final barColor = widget.paused
        ? t.borderStrong
        : (finalMinute ? t.danger : t.accent);

    final detailStyle =
        TextStyle(fontSize: 13, height: 1.6, color: t.textSecondary);

    return Container(
      width: 296,
      padding: const EdgeInsetsDirectional.fromSTEB(15, 14, 15, 12),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.textPrimary,
                      ),
                    ),
                    if (driverName.isNotEmpty)
                      Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: t.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: timeColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${l10n.discount} ', style: detailStyle),
              Money(
                discount,
                size: MoneySize.body,
                showUnit: false,
                numberStyle: const TextStyle(fontSize: 13),
              ),
              if (total > 0) ...[
                Text(' من ', style: detailStyle),
                Money(
                  total,
                  size: MoneySize.body,
                  numberStyle: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Draining countdown bar — anchored to the start edge, so in RTL it
          // drains from the left (mirrored automatically).
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 4,
              color: t.borderStrong.withValues(alpha: 0.45),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(color: barColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _expired ? null : widget.onApprove,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding:
                        const EdgeInsetsDirectional.symmetric(horizontal: 12),
                  ),
                  child: const Text('قبول'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _expired ? null : widget.onReject,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding:
                        const EdgeInsetsDirectional.symmetric(horizontal: 12),
                  ),
                  child: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
