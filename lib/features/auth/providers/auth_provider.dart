import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Provides the AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

/// Stream of Supabase auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.onAuthStateChange;
});

/// Current authenticated user, or null.
final currentUserProvider = Provider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  // Re-evaluate when auth state changes
  ref.watch(authStateProvider);
  return authService.getCurrentUser();
});

/// Whether the user is logged in.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Current user's role, or null.
final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.role;
});

/// Notifier that GoRouter can listen to for auth state changes.
class AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  AuthNotifier(AuthService authService) {
    _subscription = authService.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Checks if the database has any users (for init screen detection).
///
/// Uses RPC function (SECURITY DEFINER) to bypass RLS.
/// Without this, unauthenticated queries return empty due to RLS,
/// causing the init screen to show even when users exist.
final hasUsersProvider = FutureProvider<bool>((ref) async {
  try {
    final client = Supabase.instance.client;
    final result = await client.rpc('has_users');
    return result as bool;
  } catch (_) {
    // RPC not available (migration not run yet) — fall back to old approach
    try {
      final client = Supabase.instance.client;
      final result = await client.from('users').select('id').limit(1);
      return (result as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
});

/// Provides the AuthNotifier for GoRouter's refreshListenable.
final authNotifierProvider = Provider<AuthNotifier>((ref) {
  final authService = ref.watch(authServiceProvider);
  final notifier = AuthNotifier(authService);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});
