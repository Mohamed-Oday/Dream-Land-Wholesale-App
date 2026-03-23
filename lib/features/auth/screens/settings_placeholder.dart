import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/constants/app_constants.dart';
import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_colors.dart';
import 'package:tawzii/core/utils/version_utils.dart';
import 'package:tawzii/features/printing/providers/printer_provider.dart';
import 'package:tawzii/features/printing/screens/printer_setup_screen.dart';
import '../providers/auth_provider.dart';

/// Remote config provider — cached, only refetches on invalidate.
final remoteConfigProvider =
    FutureProvider<Map<String, String>>((ref) async {
  try {
    final result = await Supabase.instance.client
        .from('remote_config')
        .select('key, value');
    final rows = List<Map<String, dynamic>>.from(result);
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  } catch (_) {
    return {};
  }
});

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
    final remoteConfig = ref.watch(remoteConfigProvider);

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
            // Version info
            Card(
              child: ListTile(
                leading: Icon(Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant),
                title: Text(l10n.appVersion),
                trailing: Text(
                  AppConstants.appVersion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Update check
            remoteConfig.when(
              data: (config) {
                final latestVersion = config['latest_version'] ?? '';
                final downloadUrl = config['download_url'] ?? '';
                final hasUpdate = latestVersion.isNotEmpty &&
                    isNewerVersion(latestVersion, AppConstants.appVersion);

                if (!hasUpdate) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Card(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: ListTile(
                      leading: Icon(Icons.system_update,
                          color: AppColors.primary),
                      title: Text(
                        '${l10n.updateAvailable}: $latestVersion',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: downloadUrl.isNotEmpty
                          ? null
                          : Text(l10n.latestVersion,
                              style: theme.textTheme.bodySmall),
                      trailing: downloadUrl.isNotEmpty
                          ? FilledButton.tonal(
                              onPressed: () => _showDownloadDialog(
                                  context, downloadUrl, l10n),
                              child: Text(l10n.downloadUpdate),
                            )
                          : null,
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            // Sync status
            Card(
              child: ListTile(
                leading: Icon(Icons.sync,
                    color: theme.colorScheme.onSurfaceVariant),
                title: Text(l10n.syncStatus),
                subtitle: Text(l10n.syncAutomatic),
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
}
