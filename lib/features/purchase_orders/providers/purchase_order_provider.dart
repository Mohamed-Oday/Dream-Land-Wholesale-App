import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/core/providers/date_range_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/purchase_order_repository.dart';

final purchaseOrderRepositoryProvider =
    Provider<PurchaseOrderRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return PurchaseOrderRepository(Supabase.instance.client, user.businessId);
});

final purchaseOrderListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  final dateRange = ref.watch(dateRangeProvider);
  if (repo == null) return [];
  return repo.getAll(
    startDate: dateRange?.start,
    endDate: dateRange?.end,
  );
});
