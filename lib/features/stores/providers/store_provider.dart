import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/store_repository.dart';

final storeRepositoryProvider = Provider<StoreRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return StoreRepository(Supabase.instance.client, user.businessId);
});

final storeListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(storeRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll();
});
