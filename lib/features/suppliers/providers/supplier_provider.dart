import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/supplier_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return SupplierRepository(Supabase.instance.client, user.businessId);
});

final supplierListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll();
});
