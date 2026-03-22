import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/driver/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return UserRepository(Supabase.instance.client, user.businessId);
});

/// All non-owner users (for owner view — shows drivers + admins).
final allUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll();
});

/// Drivers only (for admin view).
final driversOnlyProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  if (repo == null) return [];
  return repo.getAll(roleFilter: 'driver');
});
