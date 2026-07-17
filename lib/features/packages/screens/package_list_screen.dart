import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/widgets/date_range_filter_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/hero_number.dart';
import '../../../core/ui/section_label.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/surface_card.dart';
import '../providers/package_provider.dart';
import '../widgets/package_collection_sheet.dart';

/// Packages (canvas 6f): outstanding-crates hero, per-store outstanding rows,
/// recent movement log. Collection is a bottom sheet, not a screen — tap a
/// store row (preselected) or the FAB.
class PackageListScreen extends ConsumerWidget {
  const PackageListScreen({super.key});

  static String _formatDate(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return createdAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time = DateFormat('HH:mm').format(dt);
    if (day == today) return '\u2066$time\u2069';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس \u2066$time\u2069';
    return '\u2066${DateFormat('dd/MM').format(dt)}\u2069';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final logsAsync = ref.watch(packageListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.packages)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showPackageCollectionSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const DateRangeFilterBar(),
          Expanded(
            child: logsAsync.when(
              loading: () => ListView(
                padding: const EdgeInsetsDirectional.all(18),
                children: const [SkeletonList(count: 5, hardened: true)],
              ),
              error: (e, _) => Center(
                child: ErrorRetryRow(
                  onRetry: () => ref.invalidate(packageListProvider),
                ),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return EmptyState(
                    title: l10n.noPackageLogs,
                    message: l10n.emptyPackageMessage,
                    ctaLabel: l10n.collectPackages,
                    onCta: () => showPackageCollectionSheet(context),
                  );
                }

                // Aggregate latest balance per (store, product): logs are
                // newest-first, so the first hit per pair is the latest.
                final latestByPair = <String, Map<String, dynamic>>{};
                for (final log in logs) {
                  final storeId = log['store_id']?.toString() ?? '';
                  final productId = log['product_id']?.toString() ?? '';
                  latestByPair.putIfAbsent('$storeId|$productId', () => log);
                }

                final byStore = <String, _StoreOutstanding>{};
                for (final log in latestByPair.values) {
                  final storeId = log['store_id']?.toString() ?? '';
                  final store = log['stores'] as Map<String, dynamic>?;
                  final product = log['products'] as Map<String, dynamic>?;
                  final balance =
                      (log['balance_after'] as num?)?.toInt() ?? 0;
                  final agg = byStore.putIfAbsent(
                    storeId,
                    () => _StoreOutstanding(
                      storeId: storeId,
                      storeName: store?['name'] as String? ?? '',
                    ),
                  );
                  agg.total += balance;
                  if (balance > 0) {
                    agg.parts.add(
                        '${product?['name'] as String? ?? ''} \u2066$balance\u2069');
                  }
                }

                final stores = byStore.values.toList()
                  ..sort((a, b) => b.total.compareTo(a.total));
                final outstanding =
                    stores.fold<int>(0, (sum, s) => sum + s.total);
                final storesWithOutstanding =
                    stores.where((s) => s.total > 0).length;

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(packageListProvider),
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        18, 12, 18, 96),
                    children: [
                      // Outstanding hero (count, not money)
                      HeroNumber(
                        label: 'عبوات خارجة',
                        value: outstanding,
                        isMoney: false,
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            top: 4, bottom: 16),
                        child: Text(
                          'لدى \u2066$storesWithOutstanding\u2069 متجراً · صناديق وقارورات',
                          style:
                              TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ),

                      // Per-store outstanding rows (tap → collection sheet)
                      Column(
                        children: [
                          for (final s in stores) ...[
                            _StoreRow(store: s),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Recent movement log
                      SectionLabel('آخر الحركات'),
                      SurfaceCard(
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < logs.length && i < 20;
                                i++)
                              _LogRow(
                                log: logs[i],
                                l10n: l10n,
                                showDivider:
                                    i < logs.length - 1 && i < 19,
                                dateLabel: _formatDate(
                                    logs[i]['created_at'] as String?),
                              ),
                          ],
                        ),
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

class _StoreOutstanding {
  _StoreOutstanding({required this.storeId, required this.storeName});

  final String storeId;
  final String storeName;
  int total = 0;
  final List<String> parts = [];
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store});

  final _StoreOutstanding store;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final hasOutstanding = store.total > 0;

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
          onTap: () => showPackageCollectionSheet(
            context,
            storeId: store.storeId,
            storeName: store.storeName,
          ),
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 11),
                    child: StatusDot(
                      hasOutstanding
                          ? StatusKind.warning
                          : StatusKind.neutral,
                      size: 10,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.storeName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                            color: t.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (store.parts.isNotEmpty)
                          Text(
                            store.parts.join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: t.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 11),
                    child: Text(
                      '\u2066${store.total}\u2069',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: hasOutstanding ? t.warning : t.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.log,
    required this.l10n,
    required this.showDivider,
    required this.dateLabel,
  });

  final Map<String, dynamic> log;
  final AppLocalizations l10n;
  final bool showDivider;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final product = log['products'] as Map<String, dynamic>?;
    final store = log['stores'] as Map<String, dynamic>?;
    final given = (log['given'] as num?)?.toInt() ?? 0;
    final collected = (log['collected'] as num?)?.toInt() ?? 0;
    final balanceAfter = (log['balance_after'] as num?)?.toInt() ?? 0;

    final subtitleParts = <String>[
      product?['name'] as String? ?? '',
      if (given > 0) '${l10n.givenPackages} \u2066$given\u2069',
      if (collected > 0) '${l10n.collectedPackages} \u2066$collected\u2069',
      if (dateLabel.isNotEmpty) dateLabel,
    ];

    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 11),
            child: StatusDot(
              collected > 0 ? StatusKind.success : StatusKind.neutral,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store?['name'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: t.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitleParts.join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: t.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u2066$balanceAfter\u2069',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'عبوات',
                  style: TextStyle(fontSize: 11, color: t.textMuted),
                ),
              ],
            ),
          ),
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
