import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Blocking screen shown when app version is below min_version from remote_config.
///
/// Non-dismissible: no back button, no pop, no navigation out.
class ForceUpdateScreen extends StatelessWidget {
  final String minVersion;
  final String downloadUrl;

  const ForceUpdateScreen({
    super.key,
    required this.minVersion,
    required this.downloadUrl,
  });

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) return;

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: downloadUrl));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ الرابط. افتح المتصفح والصقه.')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: downloadUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ الرابط. افتح المتصفح والصقه.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'تحديث مطلوب',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'يجب تحديث التطبيق إلى الإصدار $minVersion أو أحدث للمتابعة.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (downloadUrl.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openUrl(context),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('تحديث التطبيق'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'رابط التحميل:',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      downloadUrl,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
