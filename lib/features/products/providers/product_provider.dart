import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ProductRepository(Supabase.instance.client, user.businessId);
});

final productListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll();
});
