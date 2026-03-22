import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentRepository {
  final SupabaseClient _client;
  final String _businessId;

  PaymentRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll({String? driverId}) async {
    var query = _client
        .from('payments')
        .select('*, stores(name), users!payments_driver_id_fkey(name)')
        .eq('business_id', _businessId);

    if (driverId != null) {
      query = query.eq('driver_id', driverId);
    }

    final result = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> getByStore(String storeId) async {
    final result = await _client
        .from('payments')
        .select('*, stores(name), users!payments_driver_id_fkey(name)')
        .eq('business_id', _businessId)
        .eq('store_id', storeId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> create({
    required String storeId,
    required double amount,
  }) async {
    final result = await _client.rpc('create_payment', params: {
      'p_store_id': storeId,
      'p_amount': amount,
      'p_business_id': _businessId,
    });
    return Map<String, dynamic>.from(result as Map);
  }
}
