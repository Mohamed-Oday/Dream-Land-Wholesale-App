import 'package:supabase_flutter/supabase_flutter.dart';

class PackageRepository {
  final SupabaseClient _client;
  final String _businessId;

  PackageRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll({
    String? driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client
        .from('package_logs')
        .select(
            '*, products(name), stores(name), users!package_logs_driver_id_fkey(name)')
        .eq('business_id', _businessId);

    if (driverId != null) {
      query = query.eq('driver_id', driverId);
    }
    if (startDate != null) {
      query = query.gte('created_at', startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toUtc().toIso8601String());
    }

    final result = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> create({
    required String storeId,
    required String productId,
    int given = 0,
    int collected = 0,
    String? orderId,
  }) async {
    final result = await _client.rpc('create_package_log', params: {
      'p_store_id': storeId,
      'p_product_id': productId,
      'p_business_id': _businessId,
      'p_given': given,
      'p_collected': collected,
      'p_order_id': orderId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Returns current package balance for all products at a store.
  /// Result: list of {product_id: UUID, balance: int}
  Future<List<Map<String, dynamic>>> getBalancesByStore(
      String storeId) async {
    final result = await _client.rpc('get_package_balances_for_store',
        params: {'p_store_id': storeId});
    return List<Map<String, dynamic>>.from(result as List);
  }
}
