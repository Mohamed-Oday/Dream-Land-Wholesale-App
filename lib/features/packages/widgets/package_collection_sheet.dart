import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/state_blocks.dart';
import '../../../core/ui/status_dot.dart';
import '../../../core/ui/tawzii_row.dart';
import '../../products/providers/product_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../providers/package_provider.dart';

/// Package collection as a bottom sheet (canvas 6f) — absorbs the old
/// PackageCollectionScreen. Store picker (unless preselected), per-product
/// balances via get_package_balances_for_store, 56px steppers, balance-after
/// preview, over-collection warning, confirm → create_package_log per product.
Future<void> showPackageCollectionSheet(
  BuildContext context, {
  String? storeId,
  String? storeName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PackageCollectionSheet(
      initialStoreId: storeId,
      initialStoreName: storeName,
    ),
  );
}

class _ProductEntry {
  final String productId;
  final String productName;
  final int currentBalance;
  int collected = 0;

  _ProductEntry({
    required this.productId,
    required this.productName,
    required this.currentBalance,
  });
}

class _PackageCollectionSheet extends ConsumerStatefulWidget {
  const _PackageCollectionSheet({
    this.initialStoreId,
    this.initialStoreName,
  });

  final String? initialStoreId;
  final String? initialStoreName;

  @override
  ConsumerState<_PackageCollectionSheet> createState() =>
      _PackageCollectionSheetState();
}

class _PackageCollectionSheetState
    extends ConsumerState<_PackageCollectionSheet> {
  String? _selectedStoreId;
  String _selectedStoreName = '';
  bool _isLoading = false;
  bool _isLoadingBalances = false;
  final List<_ProductEntry> _entries = [];

  bool get _hasAnyCollected => _entries.any((e) => e.collected > 0);
  bool get _canSubmit =>
      _selectedStoreId != null && _hasAnyCollected && !_isLoading;

  @override
  void initState() {
    super.initState();
    if (widget.initialStoreId != null) {
      _selectedStoreId = widget.initialStoreId;
      _selectedStoreName = widget.initialStoreName ?? '';
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadBalances(widget.initialStoreId!),
      );
    }
  }

  Future<void> _pickStore(List<Map<String, dynamic>> stores) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 10),
                child: Text(
                  l10n.selectStore,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              for (final s in stores)
                TawziiRow(
                  leading: const StatusDot(StatusKind.neutral),
                  title: s['name'] as String? ?? '',
                  subtitle: (s['address'] ?? '').toString().isEmpty
                      ? null
                      : s['address'] as String,
                  hardened: true,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      final id = selected['id'] as String;
      setState(() {
        _selectedStoreId = id;
        _selectedStoreName = selected['name'] as String? ?? '';
      });
      _loadBalances(id);
    }
  }

  Future<void> _loadBalances(String storeId) async {
    setState(() => _isLoadingBalances = true);

    try {
      final repo = ref.read(packageRepositoryProvider)!;
      final products = ref.read(productListProvider).valueOrNull ?? [];

      final balances = await repo.getBalancesByStore(storeId);
      final balanceMap = <String, int>{};
      for (final b in balances) {
        balanceMap[b['product_id'] as String] =
            (b['balance'] as num).toInt();
      }

      _entries.clear();
      for (final p in products) {
        if (p['has_returnable_packaging'] == true) {
          final productId = p['id'] as String;
          _entries.add(_ProductEntry(
            productId: productId,
            productName: p['name'] as String? ?? '',
            currentBalance: balanceMap[productId] ?? 0,
          ));
        }
      }

      if (mounted) setState(() => _isLoadingBalances = false);
    } catch (e) {
      debugPrint('Error loading balances: $e');
      if (mounted) setState(() => _isLoadingBalances = false);
    }
  }

  Future<void> _confirmAndSubmit() async {
    if (!_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;
    final toCollect = _entries.where((e) => e.collected > 0).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmCollection),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmCollectionMessage),
            const SizedBox(height: 12),
            Text(
              _selectedStoreName,
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...toCollect.map(
              (e) => Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.productName)),
                    Text(
                      '\u2066${e.collected}\u2069',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(packageRepositoryProvider)!;

      for (final entry in toCollect) {
        await repo.create(
          storeId: _selectedStoreId!,
          productId: entry.productId,
          collected: entry.collected,
        );
      }

      if (!mounted) return;

      ref.invalidate(packageListProvider);
      ref.invalidate(storeListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.packagesCollected)),
      );
      Navigator.pop(context);
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Package collection error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveError}: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Package collection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.saveError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = TawziiTokens.of(context);
    final storesAsync = ref.watch(storeListProvider);

    final totalCollected =
        _entries.fold<int>(0, (sum, e) => sum + e.collected);
    final totalBalance =
        _entries.fold<int>(0, (sum, e) => sum + e.currentBalance);
    final anyOverCollect =
        _entries.any((e) => e.collected > e.currentBalance);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.collectPackages,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),

              // Store line: name + current balance, or picker prompt
              storesAsync.when(
                loading: () => const SkeletonRow(),
                error: (e, _) => ErrorRetryRow(
                  onRetry: () => ref.invalidate(storeListProvider),
                ),
                data: (stores) => InkWell(
                  onTap: _isLoading ? null : () => _pickStore(stores),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.symmetric(vertical: 4),
                    child: Text(
                      _selectedStoreId == null
                          ? '${l10n.selectStore} ↓'
                          : '$_selectedStoreName · الرصيد الحالي: \u2066$totalBalance\u2069',
                      style: TextStyle(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingBalances)
                const SkeletonList(count: 3, hardened: true)
              else if (_selectedStoreId != null && _entries.isEmpty)
                const EmptyState(
                  title: 'لا عبوات قابلة للإرجاع',
                  message: 'لا توجد منتجات بعبوات قابلة للإرجاع',
                )
              else if (_entries.isNotEmpty) ...[
                for (final entry in _entries) ...[
                  _EntryRow(
                    entry: entry,
                    isLoading: _isLoading,
                    onChanged: (v) => setState(() => entry.collected = v),
                  ),
                  const SizedBox(height: 8),
                ],
                if (anyOverCollect)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 8),
                    child: Text(
                      l10n.overCollectionWarning,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.warning,
                      ),
                    ),
                  ),
                Text(
                  'الرصيد بعد التحصيل: \u2066${totalBalance - totalCollected}\u2069',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: t.textSecondary),
                ),
                const SizedBox(height: 14),
              ],

              FilledButton(
                onPressed: _canSubmit ? _confirmAndSubmit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(
                  _isLoading ? '...' : 'تأكيد التحصيل',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isLoading,
    required this.onChanged,
  });

  final _ProductEntry entry;
  final bool isLoading;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    Widget stepButton({
      required IconData icon,
      required VoidCallback? onTap,
      bool filled = false,
    }) {
      return Material(
        color: filled ? t.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 56,
            height: 56,
            decoration: filled
                ? null
                : BoxDecoration(
                    border: Border.all(color: t.borderStrong, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
            child: Icon(
              icon,
              size: 24,
              color: filled ? t.onAccent : t.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderStrong, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.productName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'الرصيد: \u2066${entry.currentBalance}\u2069',
                  style: TextStyle(fontSize: 12, color: t.textSecondary),
                ),
              ],
            ),
          ),
          stepButton(
            icon: Icons.remove,
            onTap: entry.collected > 0
                ? () => onChanged(entry.collected - 1)
                : null,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '\u2066${entry.collected}\u2069',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          stepButton(
            icon: Icons.add,
            onTap: () => onChanged(entry.collected + 1),
            filled: true,
          ),
        ],
      ),
    );
  }
}
