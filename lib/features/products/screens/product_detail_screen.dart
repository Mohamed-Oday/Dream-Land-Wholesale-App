import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/hero_number.dart';
import 'package:tawzii/core/ui/money_text.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/utils/package_stock.dart';
import '../providers/product_provider.dart';
import 'product_form_sheet.dart';

/// 5e — تفاصيل المنتج: stock hero, movement history inline,
/// stock adjustment as a bottom sheet one surface rung up over the scrim.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Map<String, dynamic> product;

  String get _productId => product['id'] as String;

  Map<String, dynamic> _freshProduct(WidgetRef ref) {
    final list = ref.watch(productListProvider).valueOrNull;
    if (list == null) return product;
    for (final p in list) {
      if (p['id'] == _productId) return p;
    }
    return product;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TawziiTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final p = _freshProduct(ref);
    final movementsAsync = ref.watch(stockMovementsProvider(_productId));

    final costPrice = (p['cost_price'] as num?)?.toDouble();
    final sellPrice = (p['unit_price'] as num?)?.toDouble() ?? 0;
    final stock = stockOf(p);
    final threshold = (p['low_stock_threshold'] as num?)?.toDouble() ?? 0;
    final unitsPerPkg = (p['units_per_package'] as num?)?.toInt();
    final isOut = isOutOfStock(stock, unitsPerPkg);
    final isLow = !isOut && threshold > 0 && stock <= threshold;

    final subtitleStyle = TextStyle(fontSize: 12, color: t.textSecondary);
    final subtitleNumber = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: t.textSecondary,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(p['name'] as String? ?? ''),
        actions: [
          TextButton(
            onPressed: () async {
              final saved = await showProductFormSheet(context, product: p);
              if (saved == true) ref.invalidate(productListProvider);
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productListProvider);
          ref.invalidate(stockMovementsProvider(_productId));
          await ref.read(stockMovementsProvider(_productId).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 18),
          children: [
            // Cost/sell pair — quiet, under the title.
            Row(
              children: [
                if (costPrice != null) ...[
                  Text('شراء ', style: subtitleStyle),
                  Money(costPrice,
                      showUnit: false,
                      color: t.textSecondary,
                      numberStyle: subtitleNumber),
                  Text(' · ', style: subtitleStyle),
                ],
                Text('بيع ', style: subtitleStyle),
                Money(sellPrice,
                    color: t.textSecondary, numberStyle: subtitleNumber),
                if (unitsPerPkg != null)
                  Text(' · \u2066$unitsPerPkg\u2069 وحدة/عبوة',
                      style: subtitleStyle),
                if (p['has_returnable_packaging'] == true)
                  Text(' · قابل للإرجاع', style: subtitleStyle),
              ],
            ),
            const SizedBox(height: 14),
            HeroNumber(
              label: 'المخزون الحالي',
              value: stock,
              isMoney: false,
              tint: isOut
                  ? MoneyTint.danger
                  : (isLow ? MoneyTint.warning : MoneyTint.neutral),
            ),
            if (threshold > 0) ...[
              const SizedBox(height: 2),
              Text('حد التنبيه: \u2066$threshold\u2069',
                  style: TextStyle(fontSize: 12, color: t.textMuted)),
            ],
            const SizedBox(height: 14),
            const SectionLabel('سجل الحركات'),
            movementsAsync.when(
              loading: () =>
                  const SurfaceCard(child: SkeletonList(count: 4)),
              error: (e, _) => SurfaceCard(
                child: ErrorRetryRow(
                  onRetry: () =>
                      ref.invalidate(stockMovementsProvider(_productId)),
                ),
              ),
              data: (movements) {
                if (movements.isEmpty) {
                  return EmptyState(
                    title: l10n.noStockMovements,
                    message: 'ستظهر حركات المخزون هنا مع أول عملية',
                  );
                }
                return SurfaceCard(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < movements.length; i++)
                        _MovementRow(
                          movement: movements[i],
                          showDivider: i < movements.length - 1,
                          l10n: l10n,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: () => _showAdjustSheet(context, ref, p),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(l10n.adjustStock),
          ),
        ),
      ),
    );
  }

  /// Stock adjustment — bottom sheet one surface rung up over the scrim.
  Future<void> _showAdjustSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> p,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final currentStock = stockOf(p);
    final reasonController = TextEditingController();
    var delta = 0;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final t = TawziiTokens.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final result = currentStock + delta;
            final canConfirm = !isSaving &&
                delta != 0 &&
                result >= 0 &&
                reasonController.text.trim().isNotEmpty;

            Future<void> submit() async {
              setSheetState(() => isSaving = true);
              try {
                final repo = ref.read(productRepositoryProvider)!;
                await repo.adjustStock(
                  productId: _productId,
                  quantity: delta,
                  notes: reasonController.text.trim(),
                );
                ref.invalidate(productListProvider);
                ref.invalidate(stockMovementsProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(l10n.stockAdjusted)),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  setSheetState(() => isSaving = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('${l10n.error}: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsetsDirectional.only(
                start: 18,
                end: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.adjustStock,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AdjustButton(
                        icon: Icons.remove,
                        filled: false,
                        enabled: !isSaving && result > 0,
                        onTap: () => setSheetState(() => delta--),
                        onLongPress: () => setSheetState(() =>
                            delta = (delta - 5)
                                .clamp(-currentStock.floor(), 999999)),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '\u2066${delta >= 0 ? '+' : '−'}${delta.abs()}\u2069',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      _AdjustButton(
                        icon: Icons.add,
                        filled: true,
                        enabled: !isSaving,
                        onTap: () => setSheetState(() => delta++),
                        onLongPress: () =>
                            setSheetState(() => delta += 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      text: 'النتيجة: ',
                      style:
                          TextStyle(fontSize: 13, color: t.textSecondary),
                      children: [
                        TextSpan(
                          text: '\u2066$result\u2069',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                result < 0 ? t.danger : t.textPrimary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      text: l10n.adjustmentReason,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.textSecondary,
                      ),
                      children: [
                        TextSpan(
                            text: ' *',
                            style: TextStyle(color: t.danger)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: reasonController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                        hintText: 'مثال: جرد نهاية الأسبوع'),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: canConfirm ? submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: isSaving
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: t.onAccent),
                          )
                        : const Text('تأكيد التعديل'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Material(
      color: filled && enabled ? t.accent : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: filled && enabled
            ? BorderSide.none
            : BorderSide(
                color: enabled ? t.borderStrong : t.border, width: 2),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            size: 24,
            color: filled && enabled
                ? t.onAccent
                : (enabled ? t.textSecondary : t.disabledFg),
          ),
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.movement,
    required this.showDivider,
    required this.l10n,
  });

  final Map<String, dynamic> movement;
  final bool showDivider;
  final AppLocalizations l10n;

  String _typeLabel(String type) {
    switch (type) {
      case 'order_out':
        return l10n.movementOrderOut;
      case 'purchase_in':
        return l10n.movementPurchaseIn;
      case 'cancellation_restore':
        return l10n.movementCancellationRestore;
      case 'adjustment':
        return l10n.movementAdjustment;
      case 'load_out':
        return 'تحميل بائع (خروج)';
      case 'load_return':
        return 'مرتجع تحميل (دخول)';
      default:
        return type;
    }
  }

  static String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time = DateFormat('HH:mm').format(dt);
    if (day == today) return 'اليوم \u2066$time\u2069';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'أمس \u2066$time\u2069';
    }
    return '\u2066${DateFormat('dd/MM HH:mm').format(dt)}\u2069';
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final type = movement['movement_type'] as String? ?? '';
    final quantity = (movement['quantity'] as num?)?.toInt() ?? 0;
    final notes = movement['notes'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(movement['created_at'] as String? ?? '');
    final user = movement['users'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? '';

    final subtitleParts = <String>[
      if (createdAt != null) _formatWhen(createdAt.toLocal()),
      if (userName.isNotEmpty) userName,
      if (notes.isNotEmpty) notes,
    ];

    final row = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: t.surfaceAlt))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _typeLabel(type),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Text(
            '\u2066${quantity >= 0 ? '+' : '−'}${quantity.abs()}\u2069',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: quantity >= 0 ? t.success : t.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return row;
  }
}
