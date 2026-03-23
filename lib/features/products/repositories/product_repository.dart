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
    double? costPrice,
  }) async {
    final result = await _client.from('products').insert({
      'business_id': _businessId,
      'name': name,
      'unit_price': unitPrice,
      'units_per_package': unitsPerPackage,
      'has_returnable_packaging': hasReturnablePackaging,
      'cost_price': costPrice,
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

  /// Adjust stock for a product (positive = add, negative = deduct).
  Future<void> adjustStock({
    required String productId,
    required int quantity,
    required String notes,
  }) async {
    await _client.rpc('adjust_stock', params: {
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_notes': notes,
    });
  }

  /// Stock movements for a product, newest first.
  Future<List<Map<String, dynamic>>> getStockMovements(String productId) async {
    final result = await _client
        .from('stock_movements')
        .select('*, users!stock_movements_created_by_fkey(name)')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(result);
  }
}
