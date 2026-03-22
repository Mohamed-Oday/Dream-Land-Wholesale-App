import 'package:supabase_flutter/supabase_flutter.dart';

class LocationRepository {
  final SupabaseClient _client;
  final String _businessId;

  LocationRepository(this._client, this._businessId);

  /// Insert driver's current position into Supabase.
  Future<void> insertPosition({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    await _client.from('driver_locations').insert({
      'driver_id': driverId,
      'business_id': _businessId,
      'lat': lat,
      'lng': lng,
    });
  }

  /// Get latest position per active driver (within last hour) via RPC.
  Future<List<Map<String, dynamic>>> getLatestDriverLocations() async {
    final result = await _client.rpc('get_latest_driver_locations', params: {
      'p_business_id': _businessId,
    });

    return List<Map<String, dynamic>>.from(result as List);
  }
}
