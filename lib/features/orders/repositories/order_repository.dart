import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class OrderRepository {
  final SupabaseClient _client;
  final String _businessId;

  OrderRepository(this._client, this._businessId);

  Future<List<Map<String, dynamic>>> getAll({
    String? driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client
        .from('orders')
        .select('*, stores(name, address), users!orders_driver_id_fkey(name)')
        .eq('business_id', _businessId);

    if (driverId != null) {
      query = query.eq('driver_id', driverId);
    }
    if (startDate != null) {
      query = query.gte('created_at', startDate.toUtc().toIso8601String());
    }
    // No endDate filter — ranges use startDate only to always include latest orders

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

  /// Create an order atomically via single RPC call.
  ///
  /// All 5 operations (order, lines, balance, packages, stock) happen in one
  /// PostgreSQL transaction. Client-generated [orderId] enables idempotent retry.
  Future<Map<String, dynamic>> create({
    required String storeId,
    required double subtotal,
    required double taxPercentage,
    required double taxAmount,
    required double discount,
    required String discountStatus,
    required double total,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    // Client-generated UUID for idempotency on network retry
    const uuid = Uuid();
    final orderId = uuid.v4();

    final result = await _client.rpc('create_order_atomic', params: {
      'p_order_id': orderId,
      'p_store_id': storeId,
      'p_business_id': _businessId,
      'p_subtotal': subtotal,
      'p_tax_percentage': taxPercentage,
      'p_tax_amount': taxAmount,
      'p_discount': discount,
      'p_discount_status': discountStatus,
      'p_total': total,
      'p_line_items': lineItems,
    });

    return Map<String, dynamic>.from(result as Map);
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

  /// Cancel a 'created' order and reverse the store balance.
  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final result = await _client.rpc('cancel_order', params: {
      'p_order_id': orderId,
      'p_business_id': _businessId,
    });

    // Restore stock (fire-and-forget — cancellation is the primary event)
    try {
      await _client.rpc('restore_stock_for_cancellation', params: {
        'p_order_id': orderId,
      });
    } catch (e) {
      debugPrint('Warning: stock restoration failed (order cancelled): $e');
    }

    return Map<String, dynamic>.from(result as Map);
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
