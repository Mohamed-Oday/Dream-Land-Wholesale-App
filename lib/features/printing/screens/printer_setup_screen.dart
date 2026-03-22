import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import '../providers/printer_provider.dart';

class PrinterSetupScreen extends ConsumerStatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  ConsumerState<PrinterSetupScreen> createState() =>
      _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends ConsumerState<PrinterSetupScreen> {
  List<BluetoothInfo> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every(
        (s) => s.isGranted || s.isLimited);

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
            backgroundColor: success ? AppColors.success : AppColors.error,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isConnected = ref.watch(printerConnectedProvider);
    final connectedName = ref.watch(connectedPrinterNameProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.printerSetup)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status card
            Card(
              color: isConnected
                  ? AppColors.success.withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: isConnected
                          ? AppColors.success
                          : theme.colorScheme.onSurfaceVariant,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected
                                ? l10n.printerConnected
                                : l10n.printerDisconnected,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (connectedName != null)
                            Text(
                              connectedName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isConnected)
                      TextButton(
                        onPressed: _disconnect,
                        child: Text(l10n.disconnectPrinter),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Scan button
            FilledButton.tonalIcon(
              onPressed: _isScanning || _isConnecting ? null : _scanDevices,
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_isScanning ? l10n.scanning : l10n.scanPrinters),
            ),

            const SizedBox(height: 16),

            // Device list
            if (_devices.isEmpty && !_isScanning)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.noPrintersFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isCurrentlyConnected =
                        isConnected && connectedName == device.name;

                    return ListTile(
                      leading: Icon(
                        isCurrentlyConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        color: isCurrentlyConnected
                            ? AppColors.success
                            : theme.colorScheme.primary,
                      ),
                      title: Text(device.name),
                      subtitle: Text(device.macAdress),
                      trailing: isCurrentlyConnected
                          ? Chip(
                              label: Text(l10n.printerConnected),
                              backgroundColor:
                                  AppColors.success.withValues(alpha: 0.12),
                            )
                          : FilledButton.tonal(
                              onPressed: _isConnecting
                                  ? null
                                  : () => _connectTo(device),
                              child: _isConnecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Text(l10n.connectPrinter),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
