import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/date_range_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return OrderRepository(Supabase.instance.client, user.businessId);
});

/// Driver's own orders (filtered by driver_id + date range).
final orderListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final dateRange = ref.watch(dateRangeProvider);
  if (repo == null || user == null) return [];
  return repo.getAll(
    driverId: user.id,
    startDate: dateRange?.start,
    endDate: dateRange?.end,
  );
});

/// All orders in the business (for owner view + date range).
final allOrdersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final dateRange = ref.watch(dateRangeProvider);
  if (repo == null) return [];
  return repo.getAll(
    startDate: dateRange?.start,
    endDate: dateRange?.end,
  );
});

/// Orders for a specific store (for store detail screen).
final ordersByStoreProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, storeId) async {
  final repo = ref.watch(orderRepositoryProvider);
  if (repo == null) return [];
  return repo.getByStore(storeId);
});
