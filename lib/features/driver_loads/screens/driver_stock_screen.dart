import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/driver_loads/screens/shift_close_screen.dart';

class DriverStockScreen extends ConsumerWidget {
  const DriverStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final loadAsync = ref.watch(driverCurrentLoadProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myStock)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverCurrentLoadProvider);
          await ref.read(driverCurrentLoadProvider.future);
        },
        child: loadAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(l10n.error),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () =>
                            ref.invalidate(driverCurrentLoadProvider),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (load) {
            if (load == null) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noActiveLoad,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final items = load['items'] as List<dynamic>? ?? [];
            final openedAt = load['opened_at'] as String?;
            String formattedDate = '';
            if (openedAt != null) {
              try {
                final dt = DateTime.parse(openedAt).toLocal();
                formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
              } catch (_) {}
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Date header
                      if (formattedDate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            formattedDate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 4,
                                child: Text(l10n.products,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text(l10n.loaded,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text(l10n.sold,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text(l10n.remaining,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),

                      // Items
                      ...items.map((item) {
                        final itemMap = item as Map<String, dynamic>;
                        final product =
                            itemMap['products'] as Map<String, dynamic>?;
                        final name = product?['name'] ?? '';
                        final loaded =
                            (itemMap['quantity_loaded'] as num?)?.toInt() ??
                                0;
                        final sold =
                            (itemMap['quantity_sold'] as num?)?.toInt() ??
                                0;
                        final remaining = loaded - sold;

                        final numStyle =
                            theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: [
                            const FontFeature.tabularFigures()
                          ],
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 4,
                                  child: Text(name, style: numStyle)),
                              Expanded(
                                flex: 2,
                                child: Text('$loaded',
                                    textAlign: TextAlign.center,
                                    style: numStyle),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('$sold',
                                    textAlign: TextAlign.center,
                                    style: numStyle),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '$remaining',
                                  textAlign: TextAlign.center,
                                  style: numStyle?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: remaining > 0
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Close shift button
                Padding(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 24),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShiftCloseScreen(loadData: load),
                        ),
                      );
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: Text(l10n.closeShift),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
