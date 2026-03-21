import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return OrderRepository(Supabase.instance.client, user.businessId);
});

/// Driver's own orders (filtered by driver_id).
final orderListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repo == null || user == null) return [];
  return repo.getAll(driverId: user.id);
});

/// All orders in the business (for owner view).
final allOrdersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll();
});
