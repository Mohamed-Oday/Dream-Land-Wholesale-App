import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/features/printing/providers/printer_provider.dart';

class ReturnReceiptScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> receiptData;

  const ReturnReceiptScreen({super.key, required this.receiptData});

  @override
  ConsumerState<ReturnReceiptScreen> createState() =>
      _ReturnReceiptScreenState();
}

class _ReturnReceiptScreenState extends ConsumerState<ReturnReceiptScreen> {
  final _receiptKey = GlobalKey();
  bool _isPrinting = false;

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      final printService = ref.read(printServiceProvider);
      final success = await printService.printFromWidget(_receiptKey);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.printSuccess : l10n.printFailed),
          backgroundColor: success ? AppColors.success : AppColors.error,
          action: success
              ? null
              : SnackBarAction(
                  label: l10n.retry,
                  textColor: Colors.white,
                  onPressed: _print,
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.printFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isConnected = ref.watch(printerConnectedProvider);
    final canPrint = isConnected && !_isPrinting;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shiftCloseReceipt)),
      body: SingleChildScrollView(
        child: RepaintBoundary(
          key: _receiptKey,
          child: _ReturnReceiptCard(
              receiptData: widget.receiptData, l10n: l10n, theme: theme),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canPrint ? _print : null,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print),
                  label: Text(_isPrinting ? l10n.printing : l10n.print),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    // Pop back to driver stock screen (or root)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(l10n.done),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receiptData;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _ReturnReceiptCard({
    required this.receiptData,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final driverName = receiptData['driver_name'] as String? ?? '';
    final closedAt = receiptData['closed_at'] as String?;
    final items = receiptData['items'] as List<dynamic>? ?? [];

    String formattedDate = '';
    if (closedAt != null) {
      try {
        final dt = DateTime.parse(closedAt).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy  HH:mm').format(dt);
      } catch (_) {}
    }

    int totalLoaded = 0, totalSold = 0, totalReturned = 0;
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      totalLoaded += (m['quantity_loaded'] as num?)?.toInt() ?? 0;
      totalSold += (m['quantity_sold'] as num?)?.toInt() ?? 0;
      totalReturned += (m['quantity_returned'] as num?)?.toInt() ?? 0;
    }

    final dimStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: [const FontFeature.tabularFigures()],
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: theme.colorScheme.primary, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.exit_to_app,
                      color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.shiftCloseReceipt,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(l10n.appTitle,
                            style: dimStyle?.copyWith(
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _InfoRow(
                label: l10n.driver, value: driverName, theme: theme),
            if (formattedDate.isNotEmpty)
              _InfoRow(
                  label: l10n.orderDate,
                  value: formattedDate,
                  theme: theme),

            const SizedBox(height: 16),

            // Table header
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Text(l10n.products,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text(l10n.loaded,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text(l10n.sold,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text(l10n.returned,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Items
            ...items.map((item) {
              final m = item as Map<String, dynamic>;
              final name = m['product_name'] as String? ?? '';
              final loaded = (m['quantity_loaded'] as num?)?.toInt() ?? 0;
              final sold = (m['quantity_sold'] as num?)?.toInt() ?? 0;
              final returned =
                  (m['quantity_returned'] as num?)?.toInt() ?? 0;
              final numStyle = theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: [const FontFeature.tabularFigures()],
              );

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                    Expanded(flex: 4, child: Text(name, style: numStyle)),
                    Expanded(
                        flex: 2,
                        child: Text('$loaded',
                            textAlign: TextAlign.center, style: numStyle)),
                    Expanded(
                        flex: 2,
                        child: Text('$sold',
                            textAlign: TextAlign.center, style: numStyle)),
                    Expanded(
                        flex: 2,
                        child: Text('$returned',
                            textAlign: TextAlign.center, style: numStyle)),
                  ],
                ),
              );
            }),

            // Totals
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: theme.colorScheme.primary, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Text(l10n.total,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text('$totalLoaded',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text('$totalSold',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text('$totalReturned',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoRow(
      {required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
