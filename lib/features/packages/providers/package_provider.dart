import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/package_repository.dart';

final packageRepositoryProvider = Provider<PackageRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return PackageRepository(Supabase.instance.client, user.businessId);
});

/// Driver's own package logs (filtered by driver_id).
final packageListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(packageRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repo == null || user == null) return [];
  return repo.getAll(driverId: user.id);
});

/// All package logs in the business (for owner view).
final allPackageLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(packageRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll();
});
