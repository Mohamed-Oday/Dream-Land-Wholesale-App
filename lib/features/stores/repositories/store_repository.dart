import 'package:supabase_flutter/supabase_flutter.dart';

class StoreRepository {
  final SupabaseClient _client;
  final String _businessId;

  StoreRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll() async {
    final result = await _client
        .from('stores')
        .select()
        .eq('business_id', _businessId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final result =
        await _client.from('stores').select().eq('id', id).single();
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> create({
    required String name,
    String address = '',
    String phone = '',
    String contactPerson = '',
  }) async {
    final result = await _client.from('stores').insert({
      'business_id': _businessId,
      'name': name,
      'address': address,
      'phone': phone,
      'contact_person': contactPerson,
    }).select().single();
    return Map<String, dynamic>.from(result);
  }

  /// Adjust a store's credit balance with reason logging.
  Future<Map<String, dynamic>> adjustBalance({
    required String storeId,
    required double amount,
    required String reason,
  }) async {
    final result = await _client.rpc('adjust_store_balance', params: {
      'p_store_id': storeId,
      'p_business_id': _businessId,
      'p_amount': amount,
      'p_reason': reason,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> fields) async {
    final result = await _client
        .from('stores')
        .update(fields)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(result);
  }
}
