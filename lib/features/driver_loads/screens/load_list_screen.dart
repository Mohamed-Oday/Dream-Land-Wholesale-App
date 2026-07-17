import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/driver_loads/screens/create_load_screen.dart';
import 'package:tawzii/features/receipts/screens/receipt_screen.dart';

/// 5a — تحميلات البائعين: status-forward rows, quantities at a glance.
class LoadListScreen extends ConsumerStatefulWidget {
  const LoadListScreen({super.key});

  @override
  ConsumerState<LoadListScreen> createState() => _LoadListScreenState();
}

class _LoadListScreenState extends ConsumerState<LoadListScreen> {
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final loadsAsync = ref.watch(driverLoadListProvider);
    final currentUser = ref.watch(currentUserProvider);
    final canManage =
        currentUser != null && (currentUser.isOwner || currentUser.isAdmin);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverLoads)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverLoadListProvider);
          await ref.read(driverLoadListProvider.future);
        },
        child: loadsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(18),
            children: const [
              SurfaceCard(child: SkeletonList(count: 6)),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(18),
            children: [
              SurfaceCard(
                child: ErrorRetryRow(
                  onRetry: () => ref.invalidate(driverLoadListProvider),
                ),
              ),
            ],
          ),
          data: (loads) {
            final active =
                loads.where((l) => l['status'] == 'active').toList();
            final closed =
                loads.where((l) => l['status'] != 'active').toList();
            final visible = _showClosed ? closed : active;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 96),
              children: [
                Row(
                  children: [
                    _FilterChip(
                      label: 'نشطة · \u2066${active.length}\u2069',
                      selected: !_showClosed,
                      onTap: () => setState(() => _showClosed = false),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'مغلقة · \u2066${closed.length}\u2069',
                      selected: _showClosed,
                      onTap: () => setState(() => _showClosed = true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (loads.isEmpty)
                  EmptyState(
                    title: l10n.noLoads,
                    message: 'حمّل بائعاً لبدء وردية بيع جديدة',
                    ctaLabel: l10n.loadDriver,
                    onCta: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateLoadScreen()),
                    ),
                  )
                else if (visible.isEmpty)
                  EmptyState(
                    title: _showClosed ? 'لا تحميلات مغلقة' : 'لا تحميلات نشطة',
                    message: _showClosed
                        ? 'ستظهر التحميلات هنا بعد إغلاق الورديات'
                        : 'حمّل بائعاً لبدء وردية بيع جديدة',
                  )
                else
                  SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < visible.length; i++)
                          _LoadRow(
                            load: visible[i],
                            canManage: canManage,
                            showDivider: i < visible.length - 1,
                            tokens: t,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateLoadScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selected
          ? (isDark ? t.surfaceAlt : t.surface)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: selected && !isDark
            ? BorderSide(color: t.borderStrong)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
          alignment: AlignmentDirectional.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? t.textPrimary : t.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadRow extends StatelessWidget {
  const _LoadRow({
    required this.load,
    required this.canManage,
    required this.showDivider,
    required this.tokens,
  });

  final Map<String, dynamic> load;
  final bool canManage;
  final bool showDivider;
  final TawziiTokens tokens;

  static String _formatWhen(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final fmt = sameDay ? DateFormat('HH:mm') : DateFormat('dd/MM HH:mm');
    return fmt.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final driverName = load['driver_name'] as String? ?? '';
    final status = load['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final itemCount = (load['item_count'] as num?)?.toInt() ?? 0;
    final totalQty = (load['total_quantity'] as num?)?.toInt() ?? 0;

    final subtitle = isActive
        ? 'نشط منذ \u2066${_formatWhen(load['opened_at'] as String?)}\u2069'
            ' · \u2066$itemCount\u2069 منتج'
        : 'أُغلق \u2066${_formatWhen(load['closed_at'] as String?)}\u2069'
            ' · \u2066$itemCount\u2069 منتج';

    return TawziiRow(
      leading: StatusDot(isActive ? StatusKind.success : StatusKind.neutral),
      title: driverName,
      subtitle: subtitle,
      showDivider: showDivider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive && canManage)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateLoadScreen(
                      loadId: load['id'] as String,
                      driverName: driverName,
                    ),
                  ),
                );
              },
              child: const Text('إضافة'),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\u2066$totalQty\u2069',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color:
                      isActive ? tokens.textPrimary : tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'وحدة',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _LoadDetailLoader(loadId: load['id'] as String),
          ),
        );
      },
    );
  }
}

/// Loads the full detail, then shows the receipt screen.
class _LoadDetailLoader extends ConsumerWidget {
  const _LoadDetailLoader({required this.loadId});

  final String loadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(driverLoadDetailProvider(loadId));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.loadDetails)),
        body: ListView(
          padding: const EdgeInsetsDirectional.all(18),
          children: const [SurfaceCard(child: SkeletonList(count: 5))],
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.loadDetails)),
        body: ListView(
          padding: const EdgeInsetsDirectional.all(18),
          children: [
            SurfaceCard(
              child: ErrorRetryRow(
                onRetry: () =>
                    ref.invalidate(driverLoadDetailProvider(loadId)),
              ),
            ),
          ],
        ),
      ),
      data: (detail) {
        final items = detail['items'] as List<dynamic>? ?? [];
        final driverUser = detail['driver'] as Map<String, dynamic>?;
        final loaderUser = detail['loader'] as Map<String, dynamic>?;

        final receiptData = {
          'id': detail['id'],
          'driver_name': driverUser?['name'] ?? '',
          'loaded_by_name': loaderUser?['name'] ?? '',
          'opened_at': detail['opened_at'],
          'items': items.map((item) {
            final itemMap = item as Map<String, dynamic>;
            final product = itemMap['products'] as Map<String, dynamic>?;
            return {
              'product_name': product?['name'] ?? '',
              'quantity_loaded': itemMap['quantity_loaded'],
            };
          }).toList(),
        };

        return ReceiptScreen.load(loadData: receiptData);
      },
    );
  }
}
