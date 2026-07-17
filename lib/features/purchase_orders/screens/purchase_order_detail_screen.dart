import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/hero_number.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/section_label.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/surface_card.dart';
import '../providers/purchase_order_provider.dart';

/// Purchase order detail (canvas 6c): supplier header, cost hero,
/// stock-updated status row, line items, notes.
class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  final String purchaseOrderId;

  const PurchaseOrderDetailScreen({
    super.key,
    required this.purchaseOrderId,
  });

  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState
    extends ConsumerState<PurchaseOrderDetailScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ref.read(purchaseOrderRepositoryProvider);
    _future = repo?.getById(widget.purchaseOrderId);
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt as String)?.toLocal();
    if (dt == null) return createdAt.toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time = DateFormat('HH:mm').format(dt);
    if (day == today) return 'اليوم \u2066$time\u2069';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس \u2066$time\u2069';
    return '\u2066${DateFormat('dd/MM/yyyy').format(dt)}\u2069 · \u2066$time\u2069';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseDetails)),
      body: _future == null
          ? Center(
              child: ErrorRetryRow(
                onRetry: () => setState(_load),
              ),
            )
          : FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    padding: const EdgeInsetsDirectional.all(18),
                    children: const [
                      SurfaceCard(child: SkeletonList(count: 5)),
                    ],
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Center(
                    child: ErrorRetryRow(
                      onRetry: () => setState(_load),
                    ),
                  );
                }

                final po = snapshot.data!;
                final supplierName = (po['suppliers']
                        as Map<String, dynamic>?)?['name'] as String? ??
                    '';
                final createdByName =
                    (po['users'] as Map<String, dynamic>?)?['name']
                            as String? ??
                        '';
                final totalCost =
                    (po['total_cost'] as num?)?.toDouble() ?? 0;
                final lines =
                    po['purchase_order_lines'] as List<dynamic>? ?? [];
                final notes = (po['notes'] ?? '').toString();
                final dateLabel = _formatDate(po['created_at']);

                return ListView(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
                  children: [
                    // Supplier header
                    Text(
                      supplierName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      createdByName.isEmpty
                          ? dateLabel
                          : '$dateLabel · بواسطة $createdByName',
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Cost hero
                    HeroNumber(label: l10n.totalCost, value: totalCost),
                    const SizedBox(height: 14),

                    // Stock-updated status row
                    SurfaceCard(
                      level: SurfaceLevel.alt,
                      radius: 12,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          13, 11, 13, 11),
                      margin: const EdgeInsetsDirectional.only(bottom: 14),
                      child: Row(
                        children: [
                          const StatusDot(StatusKind.success),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'تم الاستلام — المخزون محدّث',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: t.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            dateLabel,
                            style:
                                TextStyle(fontSize: 11, color: t.textMuted),
                          ),
                        ],
                      ),
                    ),

                    // Line items
                    SectionLabel('الأصناف · \u2066${lines.length}\u2069'),
                    if (lines.isEmpty)
                      EmptyState(
                        title: l10n.noPurchaseOrders,
                        message: 'لا توجد أصناف مسجلة في هذا الأمر',
                      )
                    else
                      SurfaceCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < lines.length; i++)
                              _LineRow(
                                line: lines[i] as Map<String, dynamic>,
                                showDivider: i < lines.length - 1,
                              ),
                          ],
                        ),
                      ),

                    // Notes
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SectionLabel(l10n.purchaseNotes),
                      SurfaceCard(
                        level: SurfaceLevel.alt,
                        padding: const EdgeInsetsDirectional.all(14),
                        child: Text(
                          notes,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.showDivider});

  final Map<String, dynamic> line;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final product = line['products'] as Map<String, dynamic>?;
    final productName = product?['name'] as String? ?? '';
    final quantity = (line['quantity'] as num?)?.toInt() ?? 0;
    final unitCost = (line['unit_cost'] as num?)?.toDouble() ?? 0;
    final lineTotal = (line['line_total'] as num?)?.toDouble() ?? 0;

    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\u2066$quantity\u2069 × \u2066${Money.format(unitCost)}\u2069',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          Money(lineTotal, showUnit: false),
        ],
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
