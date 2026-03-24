import 'package:supabase_flutter/supabase_flutter.dart';

class DriverLoadRepository {
  final SupabaseClient _client;
  final String _businessId;

  DriverLoadRepository(this._client, this._businessId);

  /// Create a new driver load atomically (deducts warehouse stock).
  Future<String> createLoad({
    required String driverId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final result = await _client.rpc('create_driver_load', params: {
      'p_business_id': _businessId,
      'p_driver_id': driverId,
      'p_items': items,
      'p_notes': notes,
    });
    return result as String;
  }

  /// Get all loads for this business (with driver name, item counts).
  Future<List<Map<String, dynamic>>> getLoads() async {
    final result = await _client.rpc('get_driver_loads', params: {
      'p_business_id': _businessId,
    });
    return List<Map<String, dynamic>>.from(result as List);
  }

  /// Get a single load with its items and product names.
  Future<Map<String, dynamic>> getLoadDetail(String loadId) async {
    // Two FKs to users (driver_id, loaded_by) — disambiguate with column hint
    final load = await _client
        .from('driver_loads')
        .select('''
          *,
          driver:users!driver_id(name),
          loader:users!loaded_by(name)
        ''')
        .eq('id', loadId)
        .single();

    final items = await _client
        .from('driver_load_items')
        .select('*, products(name, unit_price, units_per_package)')
        .eq('load_id', loadId)
        .order('created_at');

    load['items'] = List<Map<String, dynamic>>.from(items);
    return Map<String, dynamic>.from(load);
  }

  /// Close a driver load (shift close). Returns stock to warehouse.
  Future<void> closeLoad({
    required String loadId,
    required List<Map<String, dynamic>> returns,
  }) async {
    await _client.rpc('close_driver_load', params: {
      'p_load_id': loadId,
      'p_returns': returns,
    });
  }

  /// Add items to an existing active load.
  Future<void> addToLoad({
    required String loadId,
    required List<Map<String, dynamic>> items,
  }) async {
    await _client.rpc('add_to_driver_load', params: {
      'p_load_id': loadId,
      'p_items': items,
    });
  }

  /// Get the current driver's active load with items. Returns null if none.
  Future<Map<String, dynamic>?> getDriverCurrentLoad(String driverId) async {
    final loads = await _client
        .from('driver_loads')
        .select('*')
        .eq('driver_id', driverId)
        .eq('status', 'active')
        .limit(1);

    if (loads.isEmpty) return null;

    final load = Map<String, dynamic>.from(loads.first);
    final loadId = load['id'] as String;

    final items = await _client
        .from('driver_load_items')
        .select('*, products(name)')
        .eq('load_id', loadId)
        .order('created_at');

    load['items'] = List<Map<String, dynamic>>.from(items);
    return load;
  }
}
