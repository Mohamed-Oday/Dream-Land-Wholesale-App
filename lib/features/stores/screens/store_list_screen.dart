import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/tawzii_row.dart';
import '../providers/store_provider.dart';
import 'store_detail_screen.dart';
import 'store_form_screen.dart';

/// 4a — Store list: search, debt-forward rows, the one sanctioned FAB.
class StoreListScreen extends ConsumerStatefulWidget {
  const StoreListScreen({super.key});

  @override
  ConsumerState<StoreListScreen> createState() => _StoreListScreenState();
}

enum _StoreFilter { all, debtors }

class _StoreListScreenState extends ConsumerState<StoreListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _StoreFilter _filter = _StoreFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> stores) {
    final q = _query.trim();
    return stores.where((s) {
      final balance = ((s['credit_balance'] as num?) ?? 0).toDouble();
      if (_filter == _StoreFilter.debtors && balance <= 0) return false;
      if (q.isEmpty) return true;
      final haystack = [
        s['name'] ?? '',
        s['address'] ?? '',
        s['phone'] ?? '',
        s['contact_person'] ?? '',
      ].join(' ').toString();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final storesAsync = ref.watch(storeListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المتاجر')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreFormScreen()),
          );
          ref.invalidate(storeListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search — Field-Kit hardened (drivers use this screen in the field).
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 18, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث عن متجر…',
                filled: true,
                fillColor: t.surface,
                contentPadding:
                    const EdgeInsetsDirectional.symmetric(horizontal: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.borderStrong, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.accent, width: 2),
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, size: 20, color: t.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          // Filter chips.
          storesAsync.maybeWhen(
            data: (stores) {
              final debtors = stores
                  .where((s) =>
                      ((s['credit_balance'] as num?) ?? 0).toDouble() > 0)
                  .length;
              return Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 12),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'الكل',
                      selected: _filter == _StoreFilter.all,
                      onTap: () => setState(() => _filter = _StoreFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'مدينون · $debtors',
                      selected: _filter == _StoreFilter.debtors,
                      onTap: () =>
                          setState(() => _filter = _StoreFilter.debtors),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: storesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: 18),
                child: SkeletonList(count: 7, hardened: true),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsetsDirectional.all(18),
                child: ErrorRetryRow(
                  onRetry: () => ref.invalidate(storeListProvider),
                ),
              ),
              data: (stores) {
                if (stores.isEmpty) {
                  return EmptyState(
                    title: 'لا توجد متاجر',
                    message: 'أضف أول متجر لبدء تسجيل الطلبات والمدفوعات',
                    ctaLabel: 'متجر جديد',
                    onCta: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StoreFormScreen()),
                      );
                      ref.invalidate(storeListProvider);
                    },
                  );
                }

                final filtered = _applyFilters(stores);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    title: 'لا نتائج',
                    message: 'لا يوجد متجر مطابق للبحث أو الفلتر الحالي',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(storeListProvider),
                  child: ListView.separated(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = filtered[index];
                      final balance =
                          ((s['credit_balance'] as num?) ?? 0).toDouble();
                      final hasDebt = balance > 0;
                      final subtitle = [
                        if ((s['address'] ?? '').toString().isNotEmpty)
                          s['address'],
                        if ((s['phone'] ?? '').toString().isNotEmpty)
                          s['phone'],
                      ].join(' · ');

                      return TawziiRow(
                        hardened: true,
                        leading: StatusDot(
                          hasDebt ? StatusKind.danger : StatusKind.neutral,
                          size: 10,
                        ),
                        title: (s['name'] ?? '').toString(),
                        subtitle: subtitle.isEmpty ? null : subtitle,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Money(
                              balance,
                              tint: hasDebt
                                  ? MoneyTint.danger
                                  : MoneyTint.neutral,
                            ),
                            Text(
                              hasDebt ? 'دين' : 'خالص',
                              style: TextStyle(
                                fontSize: 11,
                                color: t.textMuted,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoreDetailScreen(
                                  storeId: s['id'] as String),
                            ),
                          );
                        },
                      );
                    },
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
        alignment: AlignmentDirectional.center,
        decoration: BoxDecoration(
          color: selected ? t.surface : null,
          border: selected ? Border.all(color: t.borderStrong) : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? t.textPrimary : t.textMuted,
          ),
        ),
      ),
    );
  }
}
