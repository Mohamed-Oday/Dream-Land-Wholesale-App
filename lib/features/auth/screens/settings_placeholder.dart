import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/printing/providers/printer_provider.dart';
import 'package:tawzii/features/printing/screens/printer_setup_screen.dart';
import '../providers/auth_provider.dart';

/// Placeholder settings screen with logout button.
///
/// Used by all role shells until full settings is implemented.
class SettingsPlaceholder extends ConsumerWidget {
  final String roleName;

  const SettingsPlaceholder({super.key, required this.roleName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);
    final isConnected = ref.watch(printerConnectedProvider);
    final printerName = ref.watch(connectedPrinterNameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User info card
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(user?.name ?? roleName),
                subtitle: Text(user?.username ?? ''),
                trailing: Chip(label: Text(roleName)),
              ),
            ),
            const SizedBox(height: 8),
            // Printer setup
            Card(
              child: ListTile(
                leading: Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.printerSetup),
                subtitle: Text(
                  isConnected
                      ? '${l10n.printerConnected}: $printerName'
                      : l10n.printerDisconnected,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrinterSetupScreen(),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Logout button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
