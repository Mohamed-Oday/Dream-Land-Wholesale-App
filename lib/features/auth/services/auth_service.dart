import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Authentication service wrapping Supabase Auth.
///
/// Uses email field as "username@tawzii.local" format since
/// Supabase Auth requires email format. Email confirmation
/// must be DISABLED in Supabase project settings.
class AuthService {
  final SupabaseClient _client;

  /// Domain appended to username for Supabase Auth email field.
  static const _domain = 'tawzii.local';

  AuthService(this._client);

  /// Sign in with username and password.
  ///
  /// Maps username to email format: username@tawzii.local
  Future<AppUser> signIn(String username, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: '$username@$_domain',
      password: password,
    );

    if (response.user == null) {
      throw AuthException('Login failed');
    }

    return AppUser.fromSupabaseUser(response.user!);
  }

  /// Sign out current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current authenticated user, or null if not logged in.
  AppUser? getCurrentUser() {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AppUser.fromSupabaseUser(user);
  }

  /// Stream of auth state changes.
  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  /// Whether there is an active session.
  bool get isLoggedIn => _client.auth.currentSession != null;
}
