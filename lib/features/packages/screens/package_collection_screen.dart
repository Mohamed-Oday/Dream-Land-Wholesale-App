import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../../products/providers/product_provider.dart';
import '../../stores/providers/store_provider.dart';
import '../providers/package_provider.dart';

class PackageCollectionScreen extends ConsumerStatefulWidget {
  const PackageCollectionScreen({super.key});

  @override
  ConsumerState<PackageCollectionScreen> createState() =>
      _PackageCollectionScreenState();
}

class _PackageCollectionScreenState
    extends ConsumerState<PackageCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStoreId;
  String _selectedStoreName = '';
  bool _isLoading = false;
  bool _isLoadingBalances = false;

  // Returnable products with their current balance + collected input
  final List<_ProductEntry> _entries = [];

  bool get _hasAnyCollected =>
      _entries.any((e) => (int.tryParse(e.controller.text) ?? 0) > 0);

  bool get _canSubmit =>
      _selectedStoreId != null && _hasAnyCollected && !_isLoading;

  Future<Map<String, dynamic>?> _showStorePicker(
      BuildContext context, List<Map<String, dynamic>> stores) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.selectStore, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(),
            ...stores.map((s) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                child: Icon(Icons.store, color: Theme.of(ctx).colorScheme.onPrimaryContainer),
              ),
              title: Text(s['name'] ?? ''),
              subtitle: (s['address'] ?? '').toString().isNotEmpty ? Text(s['address'] as String) : null,
              onTap: () => Navigator.pop(ctx, s),
            )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBalances(String storeId) async {
    setState(() => _isLoadingBalances = true);

    try {
      final repo = ref.read(packageRepositoryProvider)!;
      final products = ref.read(productListProvider).valueOrNull ?? [];

      // Get balances for this store
      final balances = await repo.getBalancesByStore(storeId);
      final balanceMap = <String, int>{};
      for (final b in balances) {
        balanceMap[b['product_id'] as String] = (b['balance'] as num).toInt();
      }

      // Clear old entries
      for (final e in _entries) {
        e.controller.dispose();
      }
      _entries.clear();

      // Build entries for returnable products only
      for (final p in products) {
        if (p['has_returnable_packaging'] == true) {
          final productId = p['id'] as String;
          _entries.add(_ProductEntry(
            productId: productId,
            productName: p['name'] ?? '',
            currentBalance: balanceMap[productId] ?? 0,
            controller: TextEditingController(),
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
    if (!_formKey.currentState!.validate() || !_canSubmit) return;

    final l10n = AppLocalizations.of(context)!;

    // Build summary of items to collect
    final toCollect = _entries
        .where((e) => (int.tryParse(e.controller.text) ?? 0) > 0)
        .toList();

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
            Text(_selectedStoreName,
                style: Theme.of(ctx)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            ...toCollect.map((e) {
              final qty = int.parse(e.controller.text);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.productName)),
                    Text('$qty',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
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
        final qty = int.parse(entry.controller.text);
        await repo.create(
          storeId: _selectedStoreId!,
          productId: entry.productId,
          collected: qty,
        );
      }

      if (!mounted) return;

      ref.invalidate(packageListProvider);
      ref.invalidate(storeListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.packagesCollected),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context);
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.networkError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Package collection error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.saveError}: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Package collection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.saveError}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final storesAsync = ref.watch(storeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.collectPackages)),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Store selector — tap to pick from bottom sheet
                    storesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text(l10n.error),
                      data: (stores) => FormField<String>(
                        initialValue: _selectedStoreId,
                        validator: (v) => v == null ? 'مطلوب' : null,
                        builder: (field) {
                          return InkWell(
                            onTap: _isLoading
                                ? null
                                : () async {
                                    final selected =
                                        await _showStorePicker(context, stores);
                                    if (selected != null) {
                                      final id = selected['id'] as String;
                                      setState(() {
                                        _selectedStoreId = id;
                                        _selectedStoreName =
                                            selected['name'] ?? '';
                                      });
                                      field.didChange(id);
                                      _loadBalances(id);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.selectStore,
                                prefixIcon: const Icon(Icons.store),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                errorText: field.errorText,
                              ),
                              child: Text(
                                _selectedStoreName.isEmpty
                                    ? ''
                                    : _selectedStoreName,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Products with balances
                    if (_isLoadingBalances)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_selectedStoreId != null && _entries.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'لا توجد منتجات بعبوات قابلة للإرجاع',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else if (_entries.isNotEmpty) ...[
                      Text(l10n.currentPackageBalance,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ..._entries.map((entry) {
                        final collected =
                            int.tryParse(entry.controller.text) ?? 0;
                        final isOverCollecting =
                            collected > 0 && collected > entry.currentBalance;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.productName,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: entry.currentBalance > 0
                                            ? AppColors.primary
                                                .withValues(alpha: 0.12)
                                            : theme.colorScheme
                                                .surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${entry.currentBalance} عبوات',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: entry.currentBalance > 0
                                              ? AppColors.primary
                                              : theme.colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: entry.controller,
                                  enabled: !_isLoading,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l10n.enterCollected,
                                    prefixIcon:
                                        const Icon(Icons.keyboard_return),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null; // Empty is OK (skip)
                                    }
                                    final n = int.tryParse(v.trim());
                                    if (n == null || n < 0) {
                                      return 'أدخل رقماً صحيحاً';
                                    }
                                    return null;
                                  },
                                ),
                                if (isOverCollecting) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.overCollectionWarning,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.all(16).copyWith(bottom: 24),
              child: FilledButton(
                onPressed: _canSubmit ? _confirmAndSubmit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        l10n.collectPackages,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductEntry {
  final String productId;
  final String productName;
  final int currentBalance;
  final TextEditingController controller;

  _ProductEntry({
    required this.productId,
    required this.productName,
    required this.currentBalance,
    required this.controller,
  });
}
