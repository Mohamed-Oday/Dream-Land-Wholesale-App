import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages FCM token lifecycle and notification display.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;

  static const _channelId = 'tawzii_notifications';
  static const _channelName = 'Tawzii Alerts';
  static const _channelDesc = 'Push notifications for orders, payments, and alerts';

  /// Initialize notification service: request permission, create channel,
  /// set up foreground listener.
  Future<void> initialize() async {
    // Request permission (Android 13+ requires explicit permission)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('NotificationService: permission denied, skipping setup');
      return;
    }

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialize local notifications plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  /// Get the current FCM device token.
  Future<String?> getToken() async {
    try {
      _currentToken = await _messaging.getToken();
      return _currentToken;
    } catch (e) {
      debugPrint('NotificationService: failed to get token: $e');
      return null;
    }
  }

  /// Stream of token refreshes.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Register the current FCM token with Supabase (best-effort).
  Future<void> registerToken(SupabaseClient client) async {
    try {
      final token = await getToken();
      if (token == null) return;
      await client.rpc('upsert_fcm_token', params: {
        'p_device_token': token,
        'p_platform': 'android',
      });
      debugPrint('NotificationService: token registered');
    } catch (e) {
      debugPrint('NotificationService: token registration failed: $e');
    }
  }

  /// Unregister the current FCM token from Supabase (best-effort).
  /// Never blocks or delays logout on failure.
  Future<void> unregisterToken(SupabaseClient client) async {
    try {
      final token = _currentToken ?? await getToken();
      if (token == null) return;
      await client.rpc('delete_fcm_token', params: {
        'p_device_token': token,
      });
      debugPrint('NotificationService: token unregistered');
    } catch (e) {
      debugPrint('NotificationService: token unregister failed (non-blocking): $e');
    }
  }

  /// Send a push notification via the Edge Function. Best-effort, never throws.
  Future<void> sendNotification({
    required String eventType,
    required Map<String, String> data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: {'event_type': eventType, 'data': data},
      );
      debugPrint('NotificationService: sent $eventType notification');
    } catch (e) {
      debugPrint('NotificationService: send $eventType failed (non-blocking): $e');
    }
  }

  /// Check if products are below stock threshold and send notifications.
  /// Best-effort, never throws.
  Future<void> checkAndNotifyLowStock({
    required List<String> productIds,
    required String businessId,
  }) async {
    try {
      final result = await Supabase.instance.client
          .from('products')
          .select('name, stock_on_hand, low_stock_threshold')
          .inFilter('id', productIds)
          .eq('business_id', businessId)
          .gt('low_stock_threshold', 0);

      for (final product in List<Map<String, dynamic>>.from(result)) {
        final stock = (product['stock_on_hand'] as num?)?.toInt() ?? 0;
        final threshold =
            (product['low_stock_threshold'] as num?)?.toInt() ?? 0;
        if (stock <= threshold) {
          await sendNotification(
            eventType: 'low_stock',
            data: {
              'product': product['name'] as String? ?? '',
              'quantity': stock.toString(),
            },
          );
        }
      }
    } catch (e) {
      debugPrint(
          'NotificationService: low stock check failed (non-blocking): $e');
    }
  }

  /// Display a foreground notification using flutter_local_notifications.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }
}
