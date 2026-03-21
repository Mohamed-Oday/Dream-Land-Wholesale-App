import 'package:supabase_flutter/supabase_flutter.dart';

class ProductRepository {
  final SupabaseClient _client;
  final String _businessId;

  ProductRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll() async {
    final result = await _client
        .from('products')
        .select()
        .eq('business_id', _businessId)
        .eq('active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final result =
        await _client.from('products').select().eq('id', id).single();
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required double unitPrice,
    int? unitsPerPackage,
    bool hasReturnablePackaging = false,
  }) async {
    final result = await _client.from('products').insert({
      'business_id': _businessId,
      'name': name,
      'unit_price': unitPrice,
      'units_per_package': unitsPerPackage,
      'has_returnable_packaging': hasReturnablePackaging,
    }).select().single();
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> fields) async {
    final result = await _client
        .from('products')
        .update(fields)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(result);
  }

  Future<void> deactivate(String id) async {
    await _client.from('products').update({'active': false}).eq('id', id);
  }
}
