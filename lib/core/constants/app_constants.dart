/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'دريم لاند للتسوق';
  static const String appNameEn = 'Dream Land Shopping';
  static const String appVersion = '0.2.0';

  // Sync
  static const int maxSyncRetries = 3;
  static const Duration syncInterval = Duration(seconds: 30);

  // GPS
  static const Duration locationUpdateInterval = Duration(seconds: 30);

  // Discount
  static const Duration discountTimeout = Duration(minutes: 3);

  // Package alerts
  static const int defaultPackageAlertThreshold = 10;
}
