import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver_loads/screens/add_to_load_screen.dart';
import 'package:tawzii/features/driver_loads/screens/create_load_screen.dart';
import 'package:tawzii/features/driver_loads/screens/load_receipt_screen.dart';

class LoadListScreen extends ConsumerWidget {
  const LoadListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final loadsAsync = ref.watch(driverLoadListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverLoads)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverLoadListProvider);
          await ref.read(driverLoadListProvider.future);
        },
        child: loadsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(l10n.error, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(driverLoadListProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
          data: (loads) {
            if (loads.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noLoads,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: loads.length,
              itemBuilder: (_, index) {
                final load = loads[index];
                return _LoadCard(load: load, l10n: l10n, theme: theme);
              },
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

class _LoadCard extends StatelessWidget {
  final Map<String, dynamic> load;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _LoadCard({
    required this.load,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final driverName = load['driver_name'] as String? ?? '';
    final status = load['status'] as String? ?? 'active';
    final itemCount = (load['item_count'] as num?)?.toInt() ?? 0;
    final totalQty = (load['total_quantity'] as num?)?.toInt() ?? 0;
    final openedAt = load['opened_at'] as String?;
    final loadedByName = load['loaded_by_name'] as String? ?? '';

    String formattedDate = '';
    if (openedAt != null) {
      try {
        final dt = DateTime.parse(openedAt).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {
        formattedDate = openedAt;
      }
    }

    final isActive = status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Build receipt data from load list data
          final receiptData = {
            'id': load['id'],
            'driver_name': driverName,
            'loaded_by_name': loadedByName,
            'opened_at': openedAt,
            'items': <Map<String, dynamic>>[],
          };

          // Fetch detail then navigate
          final repo =
              ProviderScope.containerOf(context).read(driverLoadRepositoryProvider);
          if (repo == null) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _LoadDetailLoader(
                loadId: load['id'] as String,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      driverName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.success.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? l10n.activeLoad : l10n.closedLoad,
                      style: TextStyle(
                        color: isActive
                            ? AppColors.success
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$itemCount ${l10n.products} · $totalQty ${l10n.totalLoaded}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Action buttons for active loads (owner/admin only)
              if (isActive)
                Consumer(
                  builder: (ctx, ref, _) {
                    final currentUser = ref.watch(currentUserProvider);
                    if (currentUser == null ||
                        (!currentUser.isOwner && !currentUser.isAdmin)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => AddToLoadScreen(
                                        loadId: load['id'] as String),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(l10n.addToLoad,
                                  style: const TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads the full detail, then shows the receipt screen.
class _LoadDetailLoader extends ConsumerWidget {
  final String loadId;

  const _LoadDetailLoader({required this.loadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final detailAsync = ref.watch(driverLoadDetailProvider(loadId));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.loadDetails)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.loadDetails)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(l10n.error),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(driverLoadDetailProvider(loadId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: (detail) {
        final items = detail['items'] as List<dynamic>? ?? [];
        final driverUser = detail['driver'] as Map<String, dynamic>?;
        final loaderUser = detail['loader'] as Map<String, dynamic>?;

        // Build receipt data from detail
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

        return LoadReceiptScreen(loadData: receiptData);
      },
    );
  }
}
