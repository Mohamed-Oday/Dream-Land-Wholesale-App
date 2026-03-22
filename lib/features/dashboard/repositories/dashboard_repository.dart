import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final SupabaseClient _client;
  final String _businessId;

  DashboardRepository(this._client, this._businessId);

  /// Today's start in Algeria local time (Africa/Algiers, UTC+1),
  /// returned as a UTC ISO8601 string for Supabase filtering.
  String _todayStartUtc() {
    final now = DateTime.now().toUtc();
    // Algeria is UTC+1 (no DST changes since 2014)
    final algiersNow = now.add(const Duration(hours: 1));
    final algiersStart = DateTime.utc(
      algiersNow.year,
      algiersNow.month,
      algiersNow.day,
    );
    // Convert back to UTC: subtract the +1 offset
    final utcStart = algiersStart.subtract(const Duration(hours: 1));
    return utcStart.toIso8601String();
  }

  /// Sum of all payment amounts collected today (Algeria local time).
  Future<double> getTodayRevenue() async {
    final todayStart = _todayStartUtc();
    final result = await _client
        .from('payments')
        .select('amount')
        .eq('business_id', _businessId)
        .gte('created_at', todayStart);

    final rows = List<Map<String, dynamic>>.from(result);
    if (rows.isEmpty) return 0.0;

    double total = 0.0;
    for (final row in rows) {
      final amount = row['amount'];
      if (amount is num) {
        total += amount.toDouble();
      }
    }
    return total;
  }

  /// Count of orders created today (Algeria local time).
  Future<int> getTodayOrderCount() async {
    final todayStart = _todayStartUtc();
    final result = await _client
        .from('orders')
        .select()
        .eq('business_id', _businessId)
        .gte('created_at', todayStart)
        .count(CountOption.exact);

    return result.count;
  }

  /// Sum of all purchase order costs today (Algeria local time).
  Future<double> getTodayPurchases() async {
    final todayStart = _todayStartUtc();
    final result = await _client
        .from('purchase_orders')
        .select('total_cost')
        .eq('business_id', _businessId)
        .gte('created_at', todayStart);

    final rows = List<Map<String, dynamic>>.from(result);
    if (rows.isEmpty) return 0.0;

    double total = 0.0;
    for (final row in rows) {
      final cost = row['total_cost'];
      if (cost is num) {
        total += cost.toDouble();
      }
    }
    return total;
  }

  /// Stores with credit_balance > 0, sorted by balance descending.
  Future<List<Map<String, dynamic>>> getTopDebtors({int limit = 5}) async {
    final result = await _client
        .from('stores')
        .select('id, name, credit_balance')
        .eq('business_id', _businessId)
        .gt('credit_balance', 0)
        .order('credit_balance', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(result);
  }

  /// Most recent orders across the business, newest first.
  Future<List<Map<String, dynamic>>> getRecentOrders({int limit = 10}) async {
    final result = await _client
        .from('orders')
        .select('*, stores(name, address), users!orders_driver_id_fkey(name)')
        .eq('business_id', _businessId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Products where stock_on_hand <= low_stock_threshold (threshold > 0).
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final result = await _client
        .from('products')
        .select('id, name, stock_on_hand, low_stock_threshold')
        .eq('business_id', _businessId)
        .eq('active', true)
        .gt('low_stock_threshold', 0);

    final rows = List<Map<String, dynamic>>.from(result);
    // PostgREST can't compare columns — filter in Dart
    return rows
        .where((p) =>
            (p['stock_on_hand'] as num? ?? 0) <=
            (p['low_stock_threshold'] as num? ?? 0))
        .toList();
  }

  /// Stores with outstanding unreturned packages via RPC.
  Future<List<Map<String, dynamic>>> getPackageAlerts() async {
    final result = await _client.rpc('get_package_alerts', params: {
      'p_business_id': _businessId,
    });

    return List<Map<String, dynamic>>.from(result as List);
  }
}
