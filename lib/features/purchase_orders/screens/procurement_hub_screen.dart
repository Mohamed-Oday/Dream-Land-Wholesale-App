import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/widgets/date_range_filter_bar.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/section_label.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/surface_card.dart';
import '../../../core/ui/tawzii_row.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../widgets/supplier_form_sheet.dart';
import 'create_purchase_order_screen.dart';
import 'purchase_order_detail_screen.dart';

/// Procurement hub (canvas 6a): purchase orders + suppliers as tabs in one
/// screen. Absorbs SupplierListScreen (tab) and SupplierFormScreen (sheet).
class ProcurementHubScreen extends ConsumerStatefulWidget {
  const ProcurementHubScreen({super.key});

  @override
  ConsumerState<ProcurementHubScreen> createState() =>
      _ProcurementHubScreenState();
}

class _ProcurementHubScreenState extends ConsumerState<ProcurementHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final supplierCount =
        ref.watch(supplierListProvider).valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchaseOrders),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'أوامر الشراء'),
            Tab(
              text: supplierCount == null
                  ? 'الموردون'
                  : 'الموردون · \u2066$supplierCount\u2069',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_tabController.index == 0) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreatePurchaseOrderScreen(),
              ),
            );
            ref.invalidate(purchaseOrderListProvider);
          } else {
            await showSupplierFormSheet(context);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PurchaseOrdersTab(),
          _SuppliersTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase orders tab
// ---------------------------------------------------------------------------

class _PurchaseOrdersTab extends ConsumerWidget {
  const _PurchaseOrdersTab();

  static String _bucketLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final startOfWeek =
        today.subtract(Duration(days: (today.weekday - DateTime.saturday) % 7));
    if (day == today) return 'اليوم';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس';
    if (!day.isBefore(startOfWeek)) return 'هذا الأسبوع';
    if (!day.isBefore(startOfWeek.subtract(const Duration(days: 7)))) {
      return 'الأسبوع الماضي';
    }
    return 'أقدم';
  }

  static String _subtitleDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return '\u2066${DateFormat('HH:mm').format(dt)}\u2069';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس';
    return '\u2066${DateFormat('dd/MM').format(dt)}\u2069';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final posAsync = ref.watch(purchaseOrderListProvider);

    return Column(
      children: [
        const DateRangeFilterBar(),
        Expanded(
          child: posAsync.when(
            loading: () => ListView(
              padding: const EdgeInsetsDirectional.all(18),
              children: const [SurfaceCard(child: SkeletonList(count: 6))],
            ),
            error: (e, _) => Center(
              child: ErrorRetryRow(
                onRetry: () => ref.invalidate(purchaseOrderListProvider),
              ),
            ),
            data: (orders) {
              if (orders.isEmpty) {
                return EmptyState(
                  title: l10n.noPurchaseOrders,
                  message: 'ستظهر أوامر الشراء هنا بعد أول عملية شراء',
                  ctaLabel: l10n.createPurchaseOrder,
                  onCta: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreatePurchaseOrderScreen(),
                      ),
                    );
                    ref.invalidate(purchaseOrderListProvider);
                  },
                );
              }

              // Group by date bucket, preserving newest-first order.
              final buckets = <String, List<Map<String, dynamic>>>{};
              for (final po in orders) {
                DateTime? dt;
                final createdAt = po['created_at'] as String?;
                if (createdAt != null) {
                  dt = DateTime.tryParse(createdAt)?.toLocal();
                }
                final label = dt == null ? 'أقدم' : _bucketLabel(dt);
                buckets.putIfAbsent(label, () => []).add(po);
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(purchaseOrderListProvider),
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 96),
                  children: [
                    for (final entry in buckets.entries) ...[
                      SectionLabel(entry.key),
                      SurfaceCard(
                        margin: const EdgeInsetsDirectional.only(bottom: 14),
                        child: Column(
                          children: [
                            for (var i = 0; i < entry.value.length; i++)
                              _PoRow(
                                po: entry.value[i],
                                l10n: l10n,
                                showDivider: i < entry.value.length - 1,
                                subtitleDate: _subtitleDate,
                              ),
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
    );
  }
}

class _PoRow extends ConsumerWidget {
  const _PoRow({
    required this.po,
    required this.l10n,
    required this.showDivider,
    required this.subtitleDate,
  });

  final Map<String, dynamic> po;
  final AppLocalizations l10n;
  final bool showDivider;
  final String Function(DateTime) subtitleDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplier = po['suppliers'] as Map<String, dynamic>?;
    final supplierName = supplier?['name'] as String? ?? '';
    final totalCost = (po['total_cost'] as num?)?.toDouble() ?? 0;
    final lines = po['purchase_order_lines'] as List<dynamic>? ?? [];
    final createdAt = po['created_at'] as String?;
    final dt = createdAt == null
        ? null
        : DateTime.tryParse(createdAt)?.toLocal();

    final subtitleParts = <String>[
      if (dt != null) subtitleDate(dt),
      '\u2066${lines.length}\u2069 أصناف',
      'تم الاستلام',
    ];

    return TawziiRow(
      leading: const StatusDot(StatusKind.success),
      title: supplierName,
      subtitle: subtitleParts.join(' · '),
      trailing: Money(totalCost),
      showDivider: showDivider,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PurchaseOrderDetailScreen(
              purchaseOrderId: po['id'] as String,
            ),
          ),
        );
        ref.invalidate(purchaseOrderListProvider);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Suppliers tab
// ---------------------------------------------------------------------------

class _SuppliersTab extends ConsumerWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final suppliersAsync = ref.watch(supplierListProvider);

    return suppliersAsync.when(
      loading: () => ListView(
        padding: const EdgeInsetsDirectional.all(18),
        children: const [SurfaceCard(child: SkeletonList(count: 5))],
      ),
      error: (e, _) => Center(
        child: ErrorRetryRow(
          onRetry: () => ref.invalidate(supplierListProvider),
        ),
      ),
      data: (suppliers) {
        if (suppliers.isEmpty) {
          return EmptyState(
            title: l10n.noSuppliers,
            message: 'أضف مورّديك لتسجيل المشتريات باسمهم',
            ctaLabel: l10n.addSupplier,
            onCta: () => showSupplierFormSheet(context),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(supplierListProvider),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 96),
            children: [
              SurfaceCard(
                child: Column(
                  children: [
                    for (var i = 0; i < suppliers.length; i++)
                      _SupplierRow(
                        supplier: suppliers[i],
                        showDivider: i < suppliers.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupplierRow extends StatelessWidget {
  const _SupplierRow({required this.supplier, required this.showDivider});

  final Map<String, dynamic> supplier;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final phone = supplier['phone'] as String? ?? '';
    final contact = supplier['contact_person'] as String? ?? '';
    final subtitle = [
      if (phone.isNotEmpty) '\u2066$phone\u2069',
      if (contact.isNotEmpty) contact,
    ].join(' · ');

    return TawziiRow(
      leading: const StatusDot(StatusKind.neutral),
      title: supplier['name'] as String? ?? '',
      subtitle: subtitle.isEmpty ? null : subtitle,
      showDivider: showDivider,
      onTap: () => showSupplierFormSheet(context, supplier: supplier),
    );
  }
}
