import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_provider.dart';
import 'notification_service.dart';

/// Singleton NotificationService instance.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Initializes notifications and manages FCM token lifecycle based on auth state.
///
/// - On signIn: initializes service + registers token
/// - On signOut: unregisters token
/// - On token refresh: upserts new token
final notificationInitProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final authAsync = ref.watch(authStateProvider);
  StreamSubscription<String>? tokenRefreshSub;

  authAsync.whenData((authState) {
    final client = Supabase.instance.client;

    switch (authState.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        // Initialize service (request permission, create channel) then register token
        service.initialize().then((_) {
          service.registerToken(client);
        });
        // Listen for FCM token refreshes
        tokenRefreshSub?.cancel();
        tokenRefreshSub = service.onTokenRefresh.listen((newToken) {
          debugPrint('NotificationProvider: FCM token refreshed, upserting');
          try {
            client.rpc('upsert_fcm_token', params: {
              'p_device_token': newToken,
              'p_platform': 'android',
            });
          } catch (e) {
            debugPrint('NotificationProvider: token refresh upsert failed: $e');
          }
        });
        break;
      case AuthChangeEvent.signedOut:
        // Token deletion handled pre-signOut in UI (while session is still active).
        // By the time signedOut fires, auth.uid() is null so RPC would fail.
        tokenRefreshSub?.cancel();
        tokenRefreshSub = null;
        break;
      default:
        break;
    }
  });

  ref.onDispose(() {
    tokenRefreshSub?.cancel();
  });
});
