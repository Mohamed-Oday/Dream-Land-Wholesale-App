import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/hero_number.dart';
import 'package:tawzii/core/ui/numeric_keypad.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/receipts/screens/receipt_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';

/// 5c — إغلاق الوردية: one confirmable summary, returns called out
/// before the button. Tapping a row edits its returned quantity.
class ShiftCloseScreen extends ConsumerStatefulWidget {
  const ShiftCloseScreen({super.key, required this.loadData});

  final Map<String, dynamic> loadData;

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
        productName: product?['name'] as String? ?? '',
        loaded: loaded,
        sold: sold,
        remaining: remaining,
        returned: remaining,
      );
    }).toList();
  }

  int get _totalLoaded =>
      _returnItems.fold(0, (sum, i) => sum + i.loaded);
  int get _totalSold => _returnItems.fold(0, (sum, i) => sum + i.sold);
  int get _totalReturned =>
      _returnItems.fold(0, (sum, i) => sum + i.returned);

  String get _openedLabel {
    final iso = widget.loadData['opened_at'] as String?;
    final dt = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _editReturn(_ReturnItem item) async {
    if (_isLoading || item.remaining <= 0) return;
    final v = await showKeypadSheet(
      context,
      title: 'مرتجع — ${item.productName}',
      initialValue: item.returned.toDouble(),
      hardened: true,
      confirmLabel: 'تأكيد',
    );
    if (v == null || !mounted) return;
    setState(() {
      item.returned = v.round().clamp(0, item.remaining);
    });
  }

  Future<void> _confirmClose() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(driverLoadRepositoryProvider)!;
      final loadId = widget.loadData['id'] as String;

      final returns = _returnItems
          .map((item) => {
                'product_id': item.productId,
                'quantity_returned': item.returned,
              })
          .toList();

      await repo.closeLoad(loadId: loadId, returns: returns);

      if (!mounted) return;

      ref.invalidate(driverCurrentLoadProvider);
      ref.invalidate(driverLoadListProvider);
      ref.invalidate(productListProvider);

      // Send notification (fire-and-forget, best-effort)
      try {
        final notifService = ref.read(notificationServiceProvider);
        notifService.sendNotification(
          eventType: 'shift_closed',
          data: {'driver': currentUser?.name ?? ''},
        );
      } catch (e) {
        debugPrint('Shift closed notification failed (non-blocking): $e');
      }

      final receiptData = {
        'driver_name': currentUser?.name ?? '',
        'closed_at': DateTime.now().toIso8601String(),
        'items': _returnItems
            .map((item) => {
                  'product_name': item.productName,
                  'quantity_loaded': item.loaded,
                  'quantity_sold': item.sold,
                  'quantity_returned': item.returned,
                })
            .toList(),
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen.returns(receiptData: receiptData),
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
        SnackBar(content: Text(displayMsg)),
      );
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
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
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.closeShift),
            Text(
              '${currentUser?.name ?? ''} · بدأت \u2066$_openedLabel\u2069',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 18),
              children: [
                // Shift liquidation hero — units (money is settled per order).
                HeroNumber(
                  label: 'مباع خلال الوردية',
                  value: _totalSold,
                  isMoney: false,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatPair(label: 'محمّل', value: _totalLoaded),
                    const SizedBox(width: 18),
                    _StatPair(label: 'مباع', value: _totalSold),
                    const SizedBox(width: 18),
                    _StatPair(
                        label: 'مرتجع',
                        value: _totalReturned,
                        warning: _totalReturned > 0),
                  ],
                ),
                const SizedBox(height: 14),
                SectionLabel(
                  'تصفية المخزون',
                  trailing: Text(
                    'مباع / مرتجع',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border.all(color: t.borderStrong, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < _returnItems.length; i++)
                        _ReturnRow(
                          item: _returnItems[i],
                          showDivider: i < _returnItems.length - 1,
                          onTap: () => _editReturn(_returnItems[i]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Returns called out before the button.
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const StatusDot(StatusKind.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'سيُعاد \u2066$_totalReturned\u2069 وحدة إلى المخزن '
                          'ويُطبع إيصال الإغلاق',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(
                top: BorderSide(color: t.borderStrong, width: 2),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _isLoading ? null : _confirmClose,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: t.onAccent),
                      )
                    : Text(l10n.confirmCloseShift),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPair extends StatelessWidget {
  const _StatPair({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final int value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: t.textSecondary)),
        const SizedBox(width: 4),
        Text(
          '\u2066$value\u2069',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: warning ? t.warning : t.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final _ReturnItem item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
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
                    item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'محمّل \u2066${item.loaded}\u2069',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '\u2066${item.sold}\u2069',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' / ',
                    style: TextStyle(color: t.textMuted),
                  ),
                  TextSpan(
                    text: '\u2066${item.returned}\u2069',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: item.returned > 0 ? t.warning : t.textMuted,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 14,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnItem {
  _ReturnItem({
    required this.productId,
    required this.productName,
    required this.loaded,
    required this.sold,
    required this.remaining,
    required this.returned,
  });

  final String productId;
  final String productName;
  final int loaded;
  final int sold;
  final int remaining;
  int returned;
}
