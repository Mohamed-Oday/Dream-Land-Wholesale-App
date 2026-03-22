import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import '../providers/purchase_order_provider.dart';

class PurchaseOrderDetailScreen extends ConsumerWidget {
  final String purchaseOrderId;

  const PurchaseOrderDetailScreen({
    super.key,
    required this.purchaseOrderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final repo = ref.watch(purchaseOrderRepositoryProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: repo?.getById(purchaseOrderId),
      builder: (context, snapshot) {
        final po = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.purchaseDetails)),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : po == null
                  ? Center(child: Text(l10n.error))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // --- Header Card ---
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _InfoRow(
                                  icon: Icons.local_shipping,
                                  label: l10n.supplier,
                                  value: (po['suppliers']
                                              as Map<String, dynamic>?)?[
                                          'name'] as String? ??
                                      '',
                                  theme: theme,
                                ),
                                const SizedBox(height: 8),
                                _InfoRow(
                                  icon: Icons.calendar_today,
                                  label: 'التاريخ',
                                  value: _formatDate(
                                      po['created_at'], dateFormat),
                                  theme: theme,
                                ),
                                const SizedBox(height: 8),
                                _InfoRow(
                                  icon: Icons.person,
                                  label: 'بواسطة',
                                  value: (po['users']
                                              as Map<String, dynamic>?)?[
                                          'name'] as String? ??
                                      '',
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // --- Line Items ---
                        Row(
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 20, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              l10n.products,
                              style:
                                  theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        _buildLineItems(po, theme, colorScheme,
                            currencyFormat, l10n),

                        const SizedBox(height: 16),

                        // --- Total ---
                        Card(
                          elevation: 0,
                          color: colorScheme.primaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.totalCost,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  '${currencyFormat.format((po['total_cost'] as num?)?.toDouble() ?? 0)} د.ج',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        colorScheme.onPrimaryContainer,
                                    fontFeatures: [
                                      const FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- Notes ---
                        if ((po['notes'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.notes,
                                      size: 18,
                                      color:
                                          colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      po['notes'] as String,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildLineItems(
    Map<String, dynamic> po,
    ThemeData theme,
    ColorScheme colorScheme,
    NumberFormat currencyFormat,
    AppLocalizations l10n,
  ) {
    final lines = po['purchase_order_lines'] as List<dynamic>? ?? [];
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            l10n.noPurchaseOrders,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < lines.length; i++) ...[
            _buildLineItem(
                lines[i] as Map<String, dynamic>,
                theme,
                colorScheme,
                currencyFormat,
                l10n),
            if (i < lines.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineItem(
    Map<String, dynamic> line,
    ThemeData theme,
    ColorScheme colorScheme,
    NumberFormat currencyFormat,
    AppLocalizations l10n,
  ) {
    final product = line['products'] as Map<String, dynamic>?;
    final productName = product?['name'] as String? ?? '';
    final quantity = (line['quantity'] as num?)?.toInt() ?? 0;
    final unitCost = (line['unit_cost'] as num?)?.toDouble() ?? 0;
    final lineTotal = (line['line_total'] as num?)?.toDouble() ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        radius: 20,
        child: Icon(Icons.shopping_bag,
            color: colorScheme.onPrimaryContainer, size: 20),
      ),
      title: Text(productName, style: theme.textTheme.titleSmall),
      subtitle: Text(
        '$quantity × ${currencyFormat.format(unitCost)} د.ج',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        '${currencyFormat.format(lineTotal)} د.ج',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  String _formatDate(dynamic createdAt, DateFormat format) {
    if (createdAt == null) return '';
    try {
      return format.format(DateTime.parse(createdAt as String).toLocal());
    } catch (_) {
      return createdAt.toString();
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
