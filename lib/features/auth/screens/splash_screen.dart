import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

/// The app gate (canvas 7b): ONE screen, two states.
///
/// - Loading: wordmark + thin amber progress bar while auth/init state is
///   determined.
/// - Force update ([forceUpdate] = true): a blocking, non-dismissible state
///   with the required version and a download action. This absorbs the old
///   ForceUpdateScreen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.forceUpdate = false,
    this.minVersion = '',
    this.downloadUrl = '',
  });

  /// When true the gate shows the blocking force-update state.
  final bool forceUpdate;
  final String minVersion;
  final String downloadUrl;

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
            const SnackBar(
                content: Text('تم نسخ الرابط. افتح المتصفح والصقه.')),
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
    final t = TawziiTokens.of(context);

    final body = Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: forceUpdate
                  ? _buildForceUpdate(context, t)
                  : _buildLoading(t),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'v${AppConstants.appVersion}',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 11,
                  color: t.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!forceUpdate) return body;
    // Blocking state: no back button, no pop, no navigation out.
    return PopScope(canPop: false, child: body);
  }

  Widget _buildLoading(TawziiTokens t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'دريم لاند',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'توزيع المواد الغذائية بالجملة',
            style: TextStyle(fontSize: 13, color: t.textSecondary),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 120,
              height: 3,
              child: LinearProgressIndicator(
                color: t.accent,
                backgroundColor: t.surfaceAlt,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForceUpdate(BuildContext context, TawziiTokens t) {
    final versionStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: t.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تحديث مطلوب',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: t.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'إصدارك '),
                  TextSpan(
                    text: '\u2066${AppConstants.appVersion}\u2069',
                    style: versionStyle,
                  ),
                  const TextSpan(text: ' — الحد الأدنى المطلوب '),
                  TextSpan(
                    text: '\u2066$minVersion\u2069',
                    style: versionStyle,
                  ),
                  const TextSpan(
                    text: '. حدّث للمتابعة، بياناتك غير المُزامنة محفوظة.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (downloadUrl.isNotEmpty) ...[
              FilledButton(
                onPressed: () => _openUrl(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('تحميل التحديث'),
              ),
              const SizedBox(height: 12),
              Text(
                'يُثبَّت يدوياً \u2066(APK)\u2069 — خارج المتجر',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
