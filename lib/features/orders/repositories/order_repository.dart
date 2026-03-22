import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class OrderRepository {
  final SupabaseClient _client;
  final String _businessId;

  OrderRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll({String? driverId}) async {
    var query = _client
        .from('orders')
        .select('*, stores(name, address), users!orders_driver_id_fkey(name)')
        .eq('business_id', _businessId);

    if (driverId != null) {
      query = query.eq('driver_id', driverId);
    }

    final result = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Orders for a specific store, newest first.
  Future<List<Map<String, dynamic>>> getByStore(String storeId,
      {int limit = 10}) async {
    final result = await _client
        .from('orders')
        .select(
            '*, stores(name, address), users!orders_driver_id_fkey(name)')
        .eq('business_id', _businessId)
        .eq('store_id', storeId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final result = await _client
        .from('orders')
        .select(
            '*, stores(name, address), users!orders_driver_id_fkey(name), order_lines(*, products(name, units_per_package, unit_price))')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> create({
    required String storeId,
    required String driverId,
    required double subtotal,
    required double taxPercentage,
    required double taxAmount,
    required double discount,
    required String discountStatus,
    required double total,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    const uuid = Uuid();
    final orderId = uuid.v4();

    // Insert order
    final orderData = await _client
        .from('orders')
        .insert({
          'id': orderId,
          'business_id': _businessId,
          'store_id': storeId,
          'driver_id': driverId,
          'subtotal': subtotal,
          'tax_percentage': taxPercentage,
          'tax_amount': taxAmount,
          'discount': discount,
          'discount_status': discountStatus,
          'total': total,
          'status': 'created',
        })
        .select()
        .single();

    // Insert order lines — with cleanup on failure
    try {
      final lines = lineItems.map((item) {
        return {
          'id': uuid.v4(),
          'order_id': orderId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'line_total': item['line_total'],
        };
      }).toList();

      await _client.from('order_lines').insert(lines);
    } catch (e) {
      // Clean up orphaned order
      try {
        await _client.from('orders').delete().eq('id', orderId);
      } catch (_) {
        // Cleanup failed — original error is more important
      }
      rethrow;
    }

    return Map<String, dynamic>.from(orderData);
  }

  /// Approve a pending discount on an order.
  Future<Map<String, dynamic>> approveDiscount(
      String orderId, String approvedBy) async {
    final result = await _client.rpc('approve_discount', params: {
      'p_order_id': orderId,
      'p_approved_by': approvedBy,
      'p_business_id': _businessId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Reject a pending discount, recalculate total and adjust store balance.
  Future<Map<String, dynamic>> rejectDiscount(String orderId) async {
    final result = await _client.rpc('reject_discount', params: {
      'p_order_id': orderId,
      'p_business_id': _businessId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Auto-reject all expired pending discounts (>3 min old).
  Future<int> rejectExpiredDiscounts() async {
    final result = await _client.rpc('reject_expired_discounts', params: {
      'p_business_id': _businessId,
    });
    final data = Map<String, dynamic>.from(result as Map);
    return (data['rejected_count'] as num?)?.toInt() ?? 0;
  }

  /// Get orders with pending discount status for owner dashboard.
  Future<List<Map<String, dynamic>>> getPendingDiscounts() async {
    final result = await _client
        .from('orders')
        .select(
            '*, stores(name), users!orders_driver_id_fkey(name)')
        .eq('business_id', _businessId)
        .eq('discount_status', 'pending')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(result);
  }
}
