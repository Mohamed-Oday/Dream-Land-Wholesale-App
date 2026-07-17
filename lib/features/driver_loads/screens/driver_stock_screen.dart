import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/driver_loads/screens/shift_close_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';

/// Field-Kit driver stock (canvas 3c): shift-sales hero + borderless stat
/// row, loaded/sold/remaining product cards, quiet shift-close CTA.
/// The on-duty toggle lives in the driver shell, pinned above the nav bar.
class DriverStockScreen extends ConsumerWidget {
  const DriverStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final loadAsync = ref.watch(driverCurrentLoadProvider);
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverCurrentLoadProvider);
            ref.invalidate(productListProvider);
            await ref.read(driverCurrentLoadProvider.future);
          },
          child: loadAsync.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 16),
              children: [
                _buildTitleRow(context, t, l10n, pill: null),
                const SizedBox(height: 24),
                const SkeletonList(count: 6, hardened: true),
              ],
            ),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 16),
              children: [
                _buildTitleRow(context, t, l10n, pill: null),
                const SizedBox(height: 16),
                SurfaceCard(
                  child: ErrorRetryRow(
                    onRetry: () =>
                        ref.invalidate(driverCurrentLoadProvider),
                    retryLabel: l10n.retry,
                  ),
                ),
              ],
            ),
            data: (load) {
              if (load == null) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 16),
                  children: [
                    _buildTitleRow(context, t, l10n, pill: null),
                    const SizedBox(height: 48),
                    EmptyState(
                      title: l10n.noActiveLoad,
                      message:
                          'سيظهر مخزونك هنا بعد تحميل السلع من المستودع',
                    ),
                  ],
                );
              }
              return _buildLoaded(context, ref, t, l10n, load,
                  productsAsync: productsAsync);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(
    BuildContext context,
    TawziiTokens t,
    AppLocalizations l10n, {
    required Widget? pill,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.myStock,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: t.textPrimary,
          ),
        ),
        ?pill,
      ],
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    WidgetRef ref,
    TawziiTokens t,
    AppLocalizations l10n,
    Map<String, dynamic> load, {
    required AsyncValue<List<Map<String, dynamic>>> productsAsync,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final items = load['items'] as List<dynamic>? ?? [];

    // Active-since pill from opened_at.
    String openedTime = '';
    final openedAt = load['opened_at'] as String?;
    if (openedAt != null) {
      try {
        final dt = DateTime.parse(openedAt).toLocal();
        openedTime = DateFormat('HH:mm').format(dt);
      } catch (_) {}
    }

    // Package price per product (for the shift-sales hero).
    final products = productsAsync.valueOrNull;
    final Map<String, double> packagePrice = {};
    if (products != null) {
      for (final p in products) {
        final price = (p['unit_price'] as num?)?.toDouble() ?? 0;
        final upkg = p['units_per_package'] as int?;
        packagePrice[p['id'] as String] =
            upkg != null ? price * upkg : price;
      }
    }

    var totalLoaded = 0;
    var totalSold = 0;
    double shiftSales = 0;
    final rows = <({String name, int loaded, int sold, int remaining})>[];
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final product = itemMap['products'] as Map<String, dynamic>?;
      final name = (product?['name'] ?? '') as String;
      final loaded = (itemMap['quantity_loaded'] as num?)?.toInt() ?? 0;
      final sold = (itemMap['quantity_sold'] as num?)?.toInt() ?? 0;
      totalLoaded += loaded;
      totalSold += sold;
      shiftSales +=
          sold * (packagePrice[itemMap['product_id'] as String?] ?? 0);
      rows.add((
        name: name,
        loaded: loaded,
        sold: sold,
        remaining: loaded - sold,
      ));
    }
    final totalRemaining = totalLoaded - totalSold;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 16),
      children: [
        _buildTitleRow(
          context,
          t,
          l10n,
          pill: _ActiveLoadPill(openedTime: openedTime),
        ),
        const SizedBox(height: 14),

        // Shift-sales hero + borderless stat row.
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مبيعات الوردية',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              if (products == null && productsAsync.isLoading)
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: 6),
                  child: SkeletonRow(),
                )
              else if (products == null)
                SurfaceCard(
                  child: ErrorRetryRow(
                    onRetry: () => ref.invalidate(productListProvider),
                    retryLabel: l10n.retry,
                  ),
                )
              else
                Money(shiftSales, size: MoneySize.hero),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatItem(label: l10n.loaded, value: totalLoaded),
                  const SizedBox(width: 18),
                  _StatItem(label: l10n.sold, value: totalSold),
                  const SizedBox(width: 18),
                  _StatItem(label: l10n.remaining, value: totalRemaining),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Product rows: loaded/sold subtitle, loud remaining number.
        for (var i = 0; i < rows.length; i++) ...[
          _StockRow(row: rows[i], isLight: isLight, l10n: l10n),
          if (i < rows.length - 1) const SizedBox(height: 8),
        ],

        const SizedBox(height: 14),

        // Quiet shift-close CTA (amber stays scarce).
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShiftCloseScreen(loadData: load),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: t.textPrimary,
              side: BorderSide(color: t.borderStrong, width: 2),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(l10n.closeShift),
          ),
        ),
      ],
    );
  }
}

/// "تحميل نشط منذ HH:MM" status pill (success dot, 2px outline).
class _ActiveLoadPill extends StatelessWidget {
  const _ActiveLoadPill({required this.openedTime});

  final String openedTime;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(
          color: isLight ? t.borderStrong : t.border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: t.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            openedTime.isEmpty
                ? 'تحميل نشط'
                : 'تحميل نشط منذ \u2066$openedTime\u2069',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// One borderless stat: quiet label + bold tabular value.
class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 13, color: t.textSecondary),
        ),
        Text(
          '\u2066$value\u2069',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Hardened product card: name + loaded/sold, loud remaining number.
class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.row,
    required this.isLight,
    required this.l10n,
  });

  final ({String name, int loaded, int sold, int remaining}) row;
  final bool isLight;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final Color remainingColor;
    if (row.remaining <= 0) {
      remainingColor = t.danger;
    } else if (row.remaining <= 3) {
      remainingColor = t.warning;
    } else {
      remainingColor = t.textPrimary;
    }

    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(
          color: isLight ? t.borderStrong : t.border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  '${l10n.loaded} \u2066${row.loaded}\u2069 · '
                  '${l10n.sold} \u2066${row.sold}\u2069',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\u2066${row.remaining}\u2069',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: remainingColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                l10n.remaining,
                style: TextStyle(fontSize: 11, color: t.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
