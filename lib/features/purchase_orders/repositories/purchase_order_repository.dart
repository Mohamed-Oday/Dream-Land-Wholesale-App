import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseOrderRepository {
  final SupabaseClient _client;
  final String _businessId;

  PurchaseOrderRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client
        .from('purchase_orders')
        .select(
            '*, suppliers(name), users!purchase_orders_created_by_fkey(name), purchase_order_lines(*, products(name))')
        .eq('business_id', _businessId);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toUtc().toIso8601String());
    }

    final result = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final result = await _client
        .from('purchase_orders')
        .select(
            '*, suppliers(name), users!purchase_orders_created_by_fkey(name), purchase_order_lines(*, products(name))')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> create({
    required String supplierId,
    required String createdBy,
    required double totalCost,
    required List<Map<String, dynamic>> lineItems,
    String notes = '',
  }) async {
    // Insert purchase order (safe pattern — no .single())
    final poResult = await _client.from('purchase_orders').insert({
      'business_id': _businessId,
      'supplier_id': supplierId,
      'created_by': createdBy,
      'total_cost': totalCost,
      'notes': notes,
    }).select();

    final poRows = List<Map<String, dynamic>>.from(poResult);
    if (poRows.isEmpty) {
      throw Exception('Failed to create purchase order');
    }

    final poId = poRows.first['id'] as String;

    // Bulk insert line items
    if (lineItems.isNotEmpty) {
      final lines = lineItems
          .map((item) => {
                'purchase_order_id': poId,
                'product_id': item['product_id'],
                'quantity': item['quantity'],
                'unit_cost': item['unit_cost'],
                'line_total': item['line_total'],
              })
          .toList();
      await _client.from('purchase_order_lines').insert(lines);
    }

    // Replenish stock (fire-and-forget — PO is the primary business event)
    try {
      await _client.rpc('replenish_stock_from_purchase', params: {
        'p_purchase_order_id': poId,
      });
    } catch (e) {
      debugPrint('Warning: stock replenishment failed (PO saved): $e');
    }

    return poRows.first;
  }
}
