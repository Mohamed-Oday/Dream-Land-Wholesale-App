import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/driver_loads/screens/return_receipt_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';

class ShiftCloseScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> loadData;

  const ShiftCloseScreen({super.key, required this.loadData});

  @override
  ConsumerState<ShiftCloseScreen> createState() => _ShiftCloseScreenState();
}

class _ShiftCloseScreenState extends ConsumerState<ShiftCloseScreen> {
  late List<_ReturnItem> _returnItems;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final items = widget.loadData['items'] as List<dynamic>? ?? [];
    _returnItems = items.map((item) {
      final itemMap = item as Map<String, dynamic>;
      final product = itemMap['products'] as Map<String, dynamic>?;
      final loaded = (itemMap['quantity_loaded'] as num?)?.toInt() ?? 0;
      final sold = (itemMap['quantity_sold'] as num?)?.toInt() ?? 0;
      final remaining = loaded - sold;
      return _ReturnItem(
        productId: itemMap['product_id'] as String,
        productName: product?['name'] ?? '',
        loaded: loaded,
        sold: sold,
        remaining: remaining,
        returnController: TextEditingController(text: '$remaining'),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final item in _returnItems) {
      item.returnController.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmClose() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmCloseShift),
        content: Text(l10n.closeShift),
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
      final repo = ref.read(driverLoadRepositoryProvider)!;
      final loadId = widget.loadData['id'] as String;

      final returns = _returnItems.map((item) {
        final qty = int.tryParse(item.returnController.text) ?? 0;
        return {
          'product_id': item.productId,
          'quantity_returned': qty,
        };
      }).toList();

      await repo.closeLoad(loadId: loadId, returns: returns);

      if (!mounted) return;

      ref.invalidate(driverCurrentLoadProvider);
      ref.invalidate(driverLoadListProvider);
      ref.invalidate(productListProvider);

      // Build receipt data
      final receiptData = {
        'driver_name': currentUser?.name ?? '',
        'closed_at': DateTime.now().toIso8601String(),
        'items': _returnItems.map((item) {
          final qty = int.tryParse(item.returnController.text) ?? 0;
          return {
            'product_name': item.productName,
            'quantity_loaded': item.loaded,
            'quantity_sold': item.sold,
            'quantity_returned': qty,
          };
        }).toList(),
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReturnReceiptScreen(receiptData: receiptData),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      String displayMsg;
      if (e.message.contains('invalid_load')) {
        displayMsg = l10n.error;
      } else if (e.message.contains('invalid_return')) {
        displayMsg = e.message;
      } else {
        displayMsg = '${l10n.error}: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.networkError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.closeShift)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _returnItems.length,
              itemBuilder: (_, index) {
                final item = _returnItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _InfoChip(
                                label: l10n.loaded,
                                value: '${item.loaded}',
                                theme: theme),
                            const SizedBox(width: 8),
                            _InfoChip(
                                label: l10n.sold,
                                value: '${item.sold}',
                                theme: theme),
                            const SizedBox(width: 8),
                            _InfoChip(
                                label: l10n.remaining,
                                value: '${item.remaining}',
                                theme: theme),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(l10n.returned,
                                style: theme.textTheme.bodyMedium),
                            const Spacer(),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: item.returnController,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: [
                                    const FontFeature.tabularFigures()
                                  ],
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16).copyWith(bottom: 24),
            child: FilledButton(
              onPressed: _isLoading ? null : _confirmClose,
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
                  : Text(l10n.confirmCloseShift,
                      style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoChip(
      {required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: theme.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w500)),
    );
  }
}

class _ReturnItem {
  final String productId;
  final String productName;
  final int loaded;
  final int sold;
  final int remaining;
  final TextEditingController returnController;

  _ReturnItem({
    required this.productId,
    required this.productName,
    required this.loaded,
    required this.sold,
    required this.remaining,
    required this.returnController,
  });
}
