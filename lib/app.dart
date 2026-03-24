import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/app_localizations.dart';
import 'core/notifications/notification_provider.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

class TawziiApp extends ConsumerWidget {
  const TawziiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Eagerly initialize notification lifecycle (registers/unregisters FCM token on auth changes)
    ref.watch(notificationInitProvider);

    return MaterialApp.router(
      title: 'دريم لاند للتسوق',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
