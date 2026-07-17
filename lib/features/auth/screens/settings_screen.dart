import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/constants/app_constants.dart';
import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/notifications/notification_provider.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/theme/theme_mode_provider.dart';
import 'package:tawzii/core/ui/section_label.dart';
import 'package:tawzii/core/ui/state_blocks.dart';
import 'package:tawzii/core/ui/status_dot.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/utils/version_utils.dart';
import 'package:tawzii/features/printing/providers/printer_provider.dart';
import '../providers/auth_provider.dart';

/// Remote config provider — cached, only refetches on invalidate.
final remoteConfigProvider = FutureProvider<Map<String, String>>((ref) async {
  try {
    final result =
        await Supabase.instance.client.from('remote_config').select('key, value');
    final rows = List<Map<String, dynamic>>.from(result);
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  } catch (_) {
    return {};
  }
});

/// Real settings screen (canvas 7c): notifications, printer (with inline
/// Bluetooth scan/pair), theme, sync, session/logout.
///
/// Absorbs the old NotificationPreferencesScreen and PrinterSetupScreen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.roleName});

  final String roleName;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // --- Notification preferences state -------------------------------------
  bool _notifLoading = true;
  bool _notifError = false;
  bool _newOrder = true;
  bool _paymentCollected = true;
  bool _discountPending = true;
  bool _lowStock = true;
  bool _shiftOpened = true;
  bool _shiftClosed = true;

  // --- Printer state -------------------------------------------------------
  bool _printerExpanded = false;
  List<BluetoothInfo> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;

  bool get _isDriver => ref.read(currentUserProvider)?.role == 'driver';

  @override
  void initState() {
    super.initState();
    // Drivers don't receive notifications — skip the fetch for them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isDriver) _loadPreferences();
    });
  }

  // ---------------------------------------------------------------------
  // Notification preferences (RPC-backed, optimistic toggles)
  // ---------------------------------------------------------------------

  Future<void> _loadPreferences() async {
    setState(() {
      _notifLoading = true;
      _notifError = false;
    });

    try {
      final result =
          await Supabase.instance.client.rpc('get_notification_preferences');

      final rows = List<Map<String, dynamic>>.from(result as List);
      if (rows.isNotEmpty) {
        final prefs = rows.first;
        if (mounted) {
          setState(() {
            _newOrder = prefs['new_order'] as bool? ?? true;
            _paymentCollected = prefs['payment_collected'] as bool? ?? true;
            _discountPending = prefs['discount_pending'] as bool? ?? true;
            _lowStock = prefs['low_stock'] as bool? ?? true;
            _shiftOpened = prefs['shift_opened'] as bool? ?? true;
            _shiftClosed = prefs['shift_closed'] as bool? ?? true;
            _notifLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _notifLoading = false);
      }
    } on SocketException catch (_) {
      if (mounted) {
        setState(() {
          _notifLoading = false;
          _notifError = true;
        });
      }
    } on PostgrestException catch (_) {
      if (mounted) {
        setState(() {
          _notifLoading = false;
          _notifError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notifLoading = false;
          _notifError = true;
        });
      }
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
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
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

  // ---------------------------------------------------------------------
  // Printer (Bluetooth scan / pair / disconnect)
  // ---------------------------------------------------------------------

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final allGranted =
        statuses.values.every((s) => s.isGranted || s.isLimited);

    if (!allGranted && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enableBluetooth),
          action: SnackBarAction(
            label: l10n.settings,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }

    return allGranted;
  }

  Future<void> _scanDevices() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectTo(BluetoothInfo device) async {
    setState(() => _isConnecting = true);

    try {
      final printService = ref.read(printServiceProvider);
      final success = await printService.connect(
        device.macAdress,
        name: device.name,
      );

      if (mounted) {
        ref.read(printerConnectedProvider.notifier).state = success;
        ref.read(connectedPrinterNameProvider.notifier).state =
            success ? device.name : null;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? AppLocalizations.of(context)!.printerConnected
                : AppLocalizations.of(context)!.printFailed),
          ),
        );
      }
    } catch (e) {
      debugPrint('Connect error: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    final printService = ref.read(printServiceProvider);
    await printService.disconnect();

    if (mounted) {
      ref.read(printerConnectedProvider.notifier).state = false;
      ref.read(connectedPrinterNameProvider.notifier).state = null;
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------

  Future<void> _logout() async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.unregisterToken(Supabase.instance.client);
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
  }

  void _showDownloadDialog(
      BuildContext context, String url, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.downloadUpdate),
        content: SelectableText(
          url,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);
    final isDriver = user?.role == 'driver';

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 24),
          children: [
            Text(
              'الإعدادات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if ((user?.name ?? '').isNotEmpty) user!.name,
                widget.roleName,
              ].join(' · '),
              style: TextStyle(fontSize: 13, color: t.textSecondary),
            ),
            const SizedBox(height: 16),

            // -- Notifications (owner/admin only — drivers don't receive) --
            if (!isDriver) ...[
              const SectionLabel('الإشعارات'),
              SurfaceCard(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 14, vertical: 4),
                child: _buildNotificationsBody(t, l10n),
              ),
              const SizedBox(height: 14),
            ],

            // -- Printer ---------------------------------------------------
            const SectionLabel('الطابعة'),
            _buildPrinterCard(t, l10n),
            const SizedBox(height: 14),

            // -- Theme -----------------------------------------------------
            const SectionLabel('المظهر'),
            _buildThemePicker(t),
            const SizedBox(height: 14),

            // -- App -------------------------------------------------------
            const SectionLabel('التطبيق'),
            _buildAppCard(t, l10n),
            const SizedBox(height: 16),

            // -- Logout ----------------------------------------------------
            OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: t.danger,
                minimumSize: const Size(double.infinity, 52),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsBody(TawziiTokens t, AppLocalizations l10n) {
    if (_notifLoading) {
      return const Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: 4),
        child: SkeletonList(count: 3),
      );
    }
    if (_notifError) {
      return ErrorRetryRow(onRetry: _loadPreferences);
    }

    final entries = <(String, String, bool)>[
      ('new_order', l10n.notifNewOrder, _newOrder),
      ('payment_collected', l10n.notifPayment, _paymentCollected),
      ('discount_pending', l10n.notifDiscount, _discountPending),
      ('low_stock', l10n.notifLowStock, _lowStock),
      ('shift_opened', l10n.notifShiftOpened, _shiftOpened),
      ('shift_closed', l10n.notifShiftClosed, _shiftClosed),
    ];

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Container(
            decoration: i < entries.length - 1
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: t.border, width: 1),
                    ),
                  )
                : null,
            padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entries[i].$2,
                    style: TextStyle(fontSize: 15, color: t.textPrimary),
                  ),
                ),
                Switch(
                  value: entries[i].$3,
                  activeTrackColor: t.success,
                  onChanged: (v) => _togglePreference(entries[i].$1, v),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPrinterCard(TawziiTokens t, AppLocalizations l10n) {
    final isConnected = ref.watch(printerConnectedProvider);
    final printerName = ref.watch(connectedPrinterNameProvider);

    return SurfaceCard(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status row
          InkWell(
            onTap: () => setState(() => _printerExpanded = !_printerExpanded),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 11),
              child: Row(
                children: [
                  StatusDot(
                    isConnected ? StatusKind.success : StatusKind.neutral,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected
                              ? 'متصلة — \u2066${printerName ?? ''}\u2069'
                              : l10n.printerDisconnected,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          isConnected
                              ? 'إعادة الاتصال تلقائية'
                              : 'اضغط للبحث عن طابعة',
                          style:
                              TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _printerExpanded ? 'إغلاق' : 'إعداد ‹',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ),

          // Inline setup panel (scan / pair / disconnect)
          if (_printerExpanded) ...[
            Divider(height: 1, thickness: 1, color: t.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isScanning || _isConnecting ? null : _scanDevices,
                    child: Text(
                      _isScanning ? l10n.scanning : l10n.scanPrinters,
                    ),
                  ),
                ),
                if (isConnected) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _disconnect,
                    child: Text(
                      l10n.disconnectPrinter,
                      style: TextStyle(color: t.danger),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_isScanning)
              const Padding(
                padding: EdgeInsetsDirectional.symmetric(vertical: 4),
                child: SkeletonList(count: 2),
              )
            else if (_devices.isEmpty)
              Padding(
                padding:
                    const EdgeInsetsDirectional.symmetric(vertical: 10),
                child: Text(
                  l10n.noPrintersFound,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              )
            else
              Column(
                children: [
                  for (final device in _devices)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                          vertical: 6),
                      child: Row(
                        children: [
                          StatusDot(
                            isConnected && printerName == device.name
                                ? StatusKind.success
                                : StatusKind.neutral,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: t.textPrimary,
                                  ),
                                ),
                                Text(
                                  '\u2066${device.macAdress}\u2069',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.textMuted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isConnected && printerName == device.name)
                            StatusPill(
                              label: l10n.printerConnected,
                              kind: StatusKind.success,
                            )
                          else
                            TextButton(
                              onPressed: _isConnecting
                                  ? null
                                  : () => _connectTo(device),
                              child: _isConnecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(l10n.connectPrinter),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildThemePicker(TawziiTokens t) {
    final mode = ref.watch(themeModeProvider);

    Widget option(String label, ThemeMode value) {
      final selected = mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () =>
              ref.read(themeModeProvider.notifier).setMode(value),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? t.surface : null,
              borderRadius: BorderRadius.circular(999),
              border: selected ? Border.all(color: t.border) : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? t.textPrimary : t.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          option('داكن', ThemeMode.dark),
          const SizedBox(width: 4),
          option('فاتح', ThemeMode.light),
          const SizedBox(width: 4),
          option('تلقائي', ThemeMode.system),
        ],
      ),
    );
  }

  Widget _buildAppCard(TawziiTokens t, AppLocalizations l10n) {
    final remoteConfig = ref.watch(remoteConfigProvider);

    // Update availability (preserved from old settings screen)
    String versionTrailing = '${AppConstants.appVersion} — أحدث إصدار';
    VoidCallback? onVersionTap;
    var updateAvailable = false;
    remoteConfig.whenData((config) {
      final latestVersion = config['latest_version'] ?? '';
      final downloadUrl = config['download_url'] ?? '';
      if (latestVersion.isNotEmpty &&
          isNewerVersion(latestVersion, AppConstants.appVersion)) {
        updateAvailable = true;
        versionTrailing = '${l10n.updateAvailable}: $latestVersion';
        if (downloadUrl.isNotEmpty) {
          onVersionTap =
              () => _showDownloadDialog(context, downloadUrl, l10n);
        }
      }
    });

    return SurfaceCard(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14, vertical: 4),
      child: Column(
        children: [
          // Version row
          InkWell(
            onTap: onVersionTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: t.border, width: 1),
                ),
              ),
              padding:
                  const EdgeInsetsDirectional.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.appVersion,
                      style:
                          TextStyle(fontSize: 15, color: t.textPrimary),
                    ),
                  ),
                  Text(
                    '\u2066$versionTrailing\u2069',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          updateAvailable ? t.textPrimary : t.textMuted,
                      fontWeight: updateAvailable
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sync row
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.syncStatus,
                    style: TextStyle(fontSize: 15, color: t.textPrimary),
                  ),
                ),
                const StatusDot(StatusKind.success, size: 6),
                const SizedBox(width: 6),
                Text(
                  l10n.syncAutomatic,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
