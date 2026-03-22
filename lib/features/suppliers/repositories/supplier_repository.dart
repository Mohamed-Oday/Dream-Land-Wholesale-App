import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierRepository {
  final SupabaseClient _client;
  final String _businessId;

  SupplierRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll() async {
    final result = await _client
        .from('suppliers')
        .select()
        .eq('business_id', _businessId)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final result =
        await _client.from('suppliers').select().eq('id', id).single();
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> create({
    required String name,
    String phone = '',
    String address = '',
    String contactPerson = '',
  }) async {
    final data = <String, dynamic>{
      'business_id': _businessId,
      'name': name,
      'phone': phone,
      'address': address,
      'contact_person': contactPerson,
    };
    final result = await _client.from('suppliers').insert(data).select();
    final rows = List<Map<String, dynamic>>.from(result);
    return rows.isNotEmpty ? rows.first : data;
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> fields) async {
    final result = await _client
        .from('suppliers')
        .update(fields)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(result);
  }
}
