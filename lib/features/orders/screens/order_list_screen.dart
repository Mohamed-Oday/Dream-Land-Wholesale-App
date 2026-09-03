import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/widgets/date_range_filter_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/surface_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/settings_screen.dart';
import '../providers/order_provider.dart';
import 'create_order_screen.dart';
import '../../receipts/screens/receipt_screen.dart';

/// Order list (canvas 6d): status-dot rows, inline owner/admin actions
/// (edit · print · cancel) on tap-expanded rows, pending-discount rows with
/// countdown drain, cancelled rows struck through, create via FAB.
/// Driver sees own orders as Field-Kit hardened rows, no inline actions.
class OrderListScreen extends ConsumerStatefulWidget {
  final bool isOwner;

  const OrderListScreen({super.key, this.isOwner = false});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  bool _pendingOnly = false;
  String? _expandedOrderId;
  String _paymentStatusFilter = 'all'; // 'all', 'unpaid', 'partial', 'paid'

  bool get isOwner => widget.isOwner;

  Widget _buildFilterChip(String label, String value) {
    final t = TawziiTokens.of(context);
    final selected = _paymentStatusFilter == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: selected,
      onSelected: (_) => setState(() => _paymentStatusFilter = value),
      selectedColor: t.accentSoft,
      checkmarkColor: t.accent,
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: selected ? t.accent : t.borderStrong,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  void _invalidate() {
    ref.invalidate(isOwner ? allOrdersProvider : orderListProvider);
  }

  Future<void> _openReceipt(String orderId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptScreen.order(orderId: orderId),
      ),
    );
    _invalidate();
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelOrder),
        content: Text(l10n.cancelOrderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(orderRepositoryProvider)!;
      await repo.cancelOrder(order['id'] as String);
      if (!mounted) return;
      _invalidate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.orderCancelled)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final canManage = currentUser != null &&
        (currentUser.isOwner || currentUser.isAdmin) &&
        isOwner;
    final ordersAsync =
        ref.watch(isOwner ? allOrdersProvider : orderListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orders),
        actions: !isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: l10n.settings,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const SettingsScreen(roleName: 'بائع'),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          _invalidate();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const DateRangeFilterBar(),
          Expanded(
            child: ordersAsync.when(
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
                child: ErrorRetryRow(onRetry: _invalidate),
              ),
              data: (orders) {
                final pendingCount = orders
                    .where((o) => o['discount_status'] == 'pending')
                    .length;
                Iterable<Map<String, dynamic>> filtered = orders;
                if (_pendingOnly) {
                  filtered = filtered
                      .where((o) => o['discount_status'] == 'pending');
                }
                if (_paymentStatusFilter != 'all') {
                  filtered = filtered.where((o) =>
                      (o['payment_status'] as String? ?? 'unpaid') ==
                      _paymentStatusFilter);
                }
                final visible = filtered.toList();

                if (orders.isEmpty) {
                  return EmptyState(
                    title: l10n.noOrders,
                    message: l10n.emptyOrderMessage,
                    ctaLabel: 'طلب جديد',
                    onCta: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateOrderScreen()),
                      );
                      _invalidate();
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _invalidate(),
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        18, 12, 18, 96),
                    children: [
                      // Payment status filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('الكل', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('غير مدفوع', 'unpaid'),
                            const SizedBox(width: 8),
                            _buildFilterChip('مدفوع جزئياً', 'partial'),
                            const SizedBox(width: 8),
                            _buildFilterChip('مدفوع', 'paid'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Pending-discount filter chip
                      if (pendingCount > 0 || _pendingOnly)
                        Padding(
                          padding:
                              const EdgeInsetsDirectional.only(bottom: 12),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => setState(
                                    () => _pendingOnly = !_pendingOnly),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsetsDirectional
                                      .symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: _pendingOnly
                                        ? t.accentSoft
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _pendingOnly
                                          ? t.accent
                                          : t.borderStrong,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  alignment: AlignmentDirectional.center,
                                  child: Text(
                                    'خصم معلق · \u2066$pendingCount\u2069',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: t.warning,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (visible.isEmpty)
                        EmptyState(
                          title: 'لا توجد طلبات',
                          message: _pendingOnly
                              ? 'لا توجد طلبات ذات خصم معلق'
                              : 'لا توجد طلبات مطابقة للتصفية',
                        )
                      else if (isOwner)
                        SurfaceCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < visible.length; i++)
                                _OrderRow(
                                  order: visible[i],
                                  isOwner: true,
                                  canManage: canManage,
                                  showDivider: i < visible.length - 1,
                                  expanded: _expandedOrderId ==
                                      visible[i]['id'],
                                  onTap: () {
                                    final id =
                                        visible[i]['id'] as String;
                                    if (canManage) {
                                      setState(() => _expandedOrderId =
                                          _expandedOrderId == id
                                              ? null
                                              : id);
                                    } else {
                                      _openReceipt(id);
                                    }
                                  },
                                  onEdit: () => _openReceipt(
                                      visible[i]['id'] as String),
                                  onPrint: () => _openReceipt(
                                      visible[i]['id'] as String),
                                  onCancel: () =>
                                      _cancelOrder(visible[i]),
                                  onExpired: _invalidate,
                                ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (final order in visible) ...[
                              _OrderRow(
                                order: order,
                                isOwner: false,
                                canManage: false,
                                hardened: true,
                                expanded: false,
                                onTap: () =>
                                    _openReceipt(order['id'] as String),
                                onExpired: _invalidate,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
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

// ---------------------------------------------------------------------------
// Order row
// ---------------------------------------------------------------------------

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.isOwner,
    required this.canManage,
    required this.expanded,
    required this.onTap,
    this.hardened = false,
    this.showDivider = false,
    this.onEdit,
    this.onPrint,
    this.onCancel,
    this.onExpired,
  });

  final Map<String, dynamic> order;
  final bool isOwner;
  final bool canManage;
  final bool expanded;
  final bool hardened;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onPrint;
  final VoidCallback? onCancel;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    final store = order['stores'] as Map<String, dynamic>?;
    final storeName = store?['name'] as String? ?? '';
    final driverData = order['users'] as Map<String, dynamic>?;
    final driverName = driverData?['name'] as String? ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? 'created';
    final discountStatus = order['discount_status'] as String? ?? 'none';
    final paymentStatus = order['payment_status'] as String? ?? 'unpaid';
    final paidAmount = (order['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final isCancelled = status == 'cancelled';
    final isPendingDiscount = discountStatus == 'pending';
    final createdAt = order['created_at'] as String?;
    final dt = createdAt == null ? null : DateTime.tryParse(createdAt)?.toLocal();
    final time = dt == null ? '' : DateFormat('HH:mm').format(dt);

    if (isPendingDiscount) {
      return _PendingDiscountRow(
        order: order,
        storeName: storeName,
        driverName: driverName,
        onTap: onTap,
        onExpired: onExpired,
        hardened: hardened,
        showDivider: showDivider,
      );
    }

    // Payment status badge color
    Color paymentBadgeColor;
    String paymentLabel;
    switch (paymentStatus) {
      case 'paid':
        paymentBadgeColor = Colors.green;
        paymentLabel = 'مدفوع';
        break;
      case 'partial':
        paymentBadgeColor = Colors.orange;
        paymentLabel = 'جزئي';
        break;
      default:
        paymentBadgeColor = Colors.red;
        paymentLabel = 'غير مدفوع';
    }

    final subtitleParts = <String>[
      if (isOwner && driverName.isNotEmpty) driverName,
      if (isCancelled) 'ملغي — عُكس الرصيد' else if (time.isNotEmpty) '\u2066$time\u2069',
      if (status == 'delivered') l10n.statusDelivered,
    ];

    final dot = isCancelled
        ? const StatusDot(StatusKind.muted)
        : StatusDot(StatusKind.success, size: hardened ? 10 : 8);

    final money = Money(
      total,
      color: isCancelled ? t.textMuted : null,
      numberStyle: isCancelled
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
    );

    final paymentBadge = Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: paymentBadgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: paymentBadgeColor),
      ),
      child: Text(
        paymentLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: paymentBadgeColor,
        ),
      ),
    );

    final mainRow = ConstrainedBox(
      constraints: BoxConstraints(minHeight: hardened ? 56 : 48),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: hardened ? 14 : 12,
          vertical: hardened ? 9 : 7,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 11),
              child: dot,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName,
                    style: TextStyle(
                      fontSize: hardened ? 16 : 15,
                      fontWeight: hardened ? FontWeight.w600 : FontWeight.w500,
                      height: 1.5,
                      color: t.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: hardened ? t.textSecondary : t.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  paymentBadge,
                  const SizedBox(width: 8),
                  money,
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Widget content = mainRow;

    // Expanded inline actions (owner/admin only)
    if (expanded && canManage) {
      content = Column(
        children: [
          mainRow,
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(31, 0, 12, 10),
            child: Row(
              children: [
                _ActionButton(label: 'تعديل', onTap: onEdit),
                const SizedBox(width: 8),
                _ActionButton(label: 'طباعة', onTap: onPrint),
                const SizedBox(width: 8),
                if (status == 'created')
                  _ActionButton(
                    label: l10n.cancelOrder,
                    onTap: onCancel,
                    danger: true,
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if (hardened) {
      return Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderStrong, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: content,
          ),
        ),
      );
    }

    final row = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      ),
    );

    if (!showDivider) return row;
    return Column(
      children: [
        row,
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Divider(height: 1, thickness: 1, color: t.border),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: danger ? null : Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: AlignmentDirectional.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: danger ? t.danger : t.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending-discount row with countdown drain (3-minute window)
// ---------------------------------------------------------------------------

class _PendingDiscountRow extends StatefulWidget {
  const _PendingDiscountRow({
    required this.order,
    required this.storeName,
    required this.driverName,
    required this.onTap,
    this.onExpired,
    this.hardened = false,
    this.showDivider = false,
  });

  final Map<String, dynamic> order;
  final String storeName;
  final String driverName;
  final VoidCallback onTap;
  final VoidCallback? onExpired;
  final bool hardened;
  final bool showDivider;

  @override
  State<_PendingDiscountRow> createState() => _PendingDiscountRowState();
}

class _PendingDiscountRowState extends State<_PendingDiscountRow> {
  static const _windowSeconds = 3 * 60;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final createdAt = widget.order['created_at'] as String?;
    if (createdAt == null) {
      _timer?.cancel();
      return;
    }
    try {
      final created = DateTime.parse(createdAt).toLocal();
      final expiresAt = created.add(const Duration(minutes: 3));
      final remaining = expiresAt.difference(DateTime.now());

      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _timer?.cancel();
        if (!_expired) {
          _expired = true;
          widget.onExpired?.call();
        }
      } else {
        _remainingSeconds = remaining.inSeconds;
      }
    } catch (_) {
      _timer?.cancel();
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

    final discount =
        (widget.order['discount'] as num?)?.toDouble() ?? 0;
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final countdown = '$mins:${secs.toString().padLeft(2, '0')}';
    final progress =
        (_remainingSeconds / _windowSeconds).clamp(0.0, 1.0);

    final content = Container(
      color: t.accentSoft,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.storeName} — خصم \u2066${Money.format(discount)}\u2069',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: t.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.driverName.isNotEmpty)
                      Text(
                        widget.driverName,
                        style: TextStyle(
                          fontSize: 12,
                          color: t.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'متبقي \u2066$countdown\u2069',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.warning,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Countdown drain — mirrors in RTL automatically via FractionallySizedBox
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 4,
              color: t.borderStrong,
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: progress,
                child: Container(color: t.accent),
              ),
            ),
          ),
        ],
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(onTap: widget.onTap, child: content),
    );

    if (widget.hardened) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: t.borderStrong, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: tappable,
      );
    }

    if (!widget.showDivider) return tappable;
    return Column(
      children: [
        tappable,
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Divider(height: 1, thickness: 1, color: t.border),
        ),
      ],
    );
  }
}
