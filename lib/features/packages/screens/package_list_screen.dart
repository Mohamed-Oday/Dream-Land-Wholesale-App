import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../providers/package_provider.dart';
import 'package_collection_screen.dart';

class PackageListScreen extends ConsumerWidget {
  const PackageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final logsAsync = ref.watch(packageListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.packages)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PackageCollectionScreen(),
            ),
          );
          ref.invalidate(packageListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('خطأ في تحميل سجلات التغليف',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(packageListProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(l10n.noPackageLogs,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    l10n.emptyPackageMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(packageListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  .copyWith(bottom: 80),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _PackageLogCard(log: log, l10n: l10n, theme: theme);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PackageLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PackageLogCard({
    required this.log,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final product = log['products'] as Map<String, dynamic>?;
    final store = log['stores'] as Map<String, dynamic>?;
    final productName = product?['name'] ?? '';
    final storeName = store?['name'] ?? '';
    final given = (log['given'] as num?)?.toInt() ?? 0;
    final collected = (log['collected'] as num?)?.toInt() ?? 0;
    final balanceAfter = (log['balance_after'] as num?)?.toInt() ?? 0;
    final orderId = log['order_id'];
    final createdAt = log['created_at'] as String?;

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    final isGiven = given > 0;
    final isCollected = collected > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              backgroundColor: isCollected
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.12),
              child: Icon(
                isCollected ? Icons.keyboard_return : Icons.outbox,
                color: isCollected ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    storeName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isGiven)
                        _Badge(
                          label: '${l10n.givenPackages}: $given',
                          color: AppColors.primary,
                        ),
                      if (isGiven && isCollected) const SizedBox(width: 6),
                      if (isCollected)
                        _Badge(
                          label: '${l10n.collectedPackages}: $collected',
                          color: AppColors.success,
                        ),
                      if (orderId != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.receipt_long,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$balanceAfter',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'عبوات',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
