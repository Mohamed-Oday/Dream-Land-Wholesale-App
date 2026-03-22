import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return PaymentRepository(Supabase.instance.client, user.businessId);
});

/// Driver's own payments (filtered by driver_id).
final paymentListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repo == null || user == null) return [];
  return repo.getAll(driverId: user.id);
});

/// All payments in the business (for owner view).
final allPaymentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll();
});
