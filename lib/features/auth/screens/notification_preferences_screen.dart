import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _isLoading = true;
  bool _hasError = false;

  bool _newOrder = true;
  bool _paymentCollected = true;
  bool _discountPending = true;
  bool _lowStock = true;
  bool _shiftOpened = true;
  bool _shiftClosed = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await Supabase.instance.client
          .rpc('get_notification_preferences');

      final rows = List<Map<String, dynamic>>.from(result as List);
      if (rows.isNotEmpty) {
        final prefs = rows.first;
        setState(() {
          _newOrder = prefs['new_order'] as bool? ?? true;
          _paymentCollected = prefs['payment_collected'] as bool? ?? true;
          _discountPending = prefs['discount_pending'] as bool? ?? true;
          _lowStock = prefs['low_stock'] as bool? ?? true;
          _shiftOpened = prefs['shift_opened'] as bool? ?? true;
          _shiftClosed = prefs['shift_closed'] as bool? ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } on SocketException catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } on PostgrestException catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _togglePreference(String eventType, bool value) async {
    // Optimistic update
    final previous = _getPreference(eventType);
    _setPreference(eventType, value);

    try {
      await Supabase.instance.client.rpc(
        'upsert_notification_preference',
        params: {'p_event_type': eventType, 'p_enabled': value},
      );
    } catch (e) {
      // Revert on error
      if (mounted) {
        _setPreference(eventType, previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  bool _getPreference(String eventType) {
    switch (eventType) {
      case 'new_order':
        return _newOrder;
      case 'payment_collected':
        return _paymentCollected;
      case 'discount_pending':
        return _discountPending;
      case 'low_stock':
        return _lowStock;
      case 'shift_opened':
        return _shiftOpened;
      case 'shift_closed':
        return _shiftClosed;
      default:
        return true;
    }
  }

  void _setPreference(String eventType, bool value) {
    setState(() {
      switch (eventType) {
        case 'new_order':
          _newOrder = value;
        case 'payment_collected':
          _paymentCollected = value;
        case 'discount_pending':
          _discountPending = value;
        case 'low_stock':
          _lowStock = value;
        case 'shift_opened':
          _shiftOpened = value;
        case 'shift_closed':
          _shiftClosed = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationPreferences)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(l10n.notifLoadError,
                          style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadPreferences,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    _buildSwitch(
                      icon: Icons.shopping_cart_outlined,
                      title: l10n.notifNewOrder,
                      eventType: 'new_order',
                      value: _newOrder,
                    ),
                    _buildSwitch(
                      icon: Icons.payments_outlined,
                      title: l10n.notifPayment,
                      eventType: 'payment_collected',
                      value: _paymentCollected,
                    ),
                    _buildSwitch(
                      icon: Icons.discount_outlined,
                      title: l10n.notifDiscount,
                      eventType: 'discount_pending',
                      value: _discountPending,
                    ),
                    _buildSwitch(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.notifLowStock,
                      eventType: 'low_stock',
                      value: _lowStock,
                    ),
                    _buildSwitch(
                      icon: Icons.play_circle_outline,
                      title: l10n.notifShiftOpened,
                      eventType: 'shift_opened',
                      value: _shiftOpened,
                    ),
                    _buildSwitch(
                      icon: Icons.stop_circle_outlined,
                      title: l10n.notifShiftClosed,
                      eventType: 'shift_closed',
                      value: _shiftClosed,
                    ),
                  ],
                ),
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required String eventType,
    required bool value,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      onChanged: (newValue) => _togglePreference(eventType, newValue),
    );
  }
}
