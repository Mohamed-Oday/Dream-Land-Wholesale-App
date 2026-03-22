import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/location/repositories/location_repository.dart';
import 'package:tawzii/features/location/services/location_service.dart';

final locationRepositoryProvider = Provider<LocationRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return LocationRepository(Supabase.instance.client, user.businessId);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Driver on-duty state. Defaults to false on app launch.
final isOnDutyProvider = StateProvider<bool>((ref) => false);

/// Latest driver locations for owner map (via RPC).
final driverLocationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(locationRepositoryProvider);
  if (repo == null) return [];
  return repo.getLatestDriverLocations();
});
