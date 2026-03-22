import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _fallbackTimer;

  /// Checks if GPS services are enabled AND location permission is granted.
  /// Returns true only if both conditions are met.
  Future<bool> checkAndRequestPermission() async {
    // First check if location services (GPS) are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Then check/request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Starts periodic GPS tracking. Calls [onPosition] with each new position.
  /// Uses geolocator position stream with 30s interval and 10m distance filter.
  void startTracking({
    required void Function(Position position) onPosition,
    Duration interval = const Duration(seconds: 30),
  }) {
    stopTracking();

    // Try position stream first
    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          intervalDuration: interval,
        ),
      ).listen(
        onPosition,
        onError: (_) {
          // If stream fails, fall back to periodic polling
          _startFallbackTimer(onPosition, interval);
        },
      );
    } catch (_) {
      _startFallbackTimer(onPosition, interval);
    }
  }

  void _startFallbackTimer(
    void Function(Position position) onPosition,
    Duration interval,
  ) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(interval, (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        onPosition(position);
      } catch (_) {
        // Silently skip — network or GPS issue, will retry next interval
      }
    });
  }

  /// Stops all tracking (stream subscription and fallback timer).
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void dispose() {
    stopTracking();
  }
}
