import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver_loads/repositories/driver_load_repository.dart';

final driverLoadRepositoryProvider = Provider<DriverLoadRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return DriverLoadRepository(Supabase.instance.client, user.businessId);
});

final driverLoadListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(driverLoadRepositoryProvider);
  if (repo == null) return [];
  return repo.getLoads();
});

final driverLoadDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, loadId) async {
  final repo = ref.watch(driverLoadRepositoryProvider);
  if (repo == null) return {};
  return repo.getLoadDetail(loadId);
});

/// Current driver's active load (for driver stock screen).
final driverCurrentLoadProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(driverLoadRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  if (repo == null || user == null) return null;
  return repo.getDriverCurrentLoad(user.id);
});
