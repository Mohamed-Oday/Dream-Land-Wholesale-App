import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final SupabaseClient _client;
  final String _businessId;

  UserRepository(this._client, this._businessId);

  /// Get all non-owner users. Optionally filter by role.
  Future<List<Map<String, dynamic>>> getAll({String? roleFilter}) async {
    var query = _client
        .from('users')
        .select('id, name, username, role, active, created_at')
        .eq('business_id', _businessId)
        .neq('role', 'owner');

    if (roleFilter != null) {
      query = query.eq('role', roleFilter);
    }

    final result = await query.order('role').order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> deactivate(String userId) async {
    await _client
        .from('users')
        .update({'active': false}).eq('id', userId);
  }

  Future<void> activate(String userId) async {
    await _client
        .from('users')
        .update({'active': true}).eq('id', userId);
  }

  /// Create a new user (driver or admin).
  /// Saves and restores caller session since signUp changes active session.
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    // Save current session
    final currentSession = _client.auth.currentSession;

    // Create auth user
    final authRes = await _client.auth.signUp(
      email: '$username@tawzii.local',
      password: password,
      data: {
        'role': role,
        'business_id': _businessId,
        'name': name,
        'username': username,
      },
    );

    if (authRes.user == null) {
      throw Exception('Failed to create auth account');
    }

    // Restore caller session — critical, must not fail silently
    if (currentSession?.refreshToken != null) {
      try {
        await _client.auth.setSession(currentSession!.refreshToken!);
      } catch (e) {
        throw Exception('Session restore failed after user creation: $e');
      }
    }

    // Insert into users table
    try {
      await _client.from('users').insert({
        'id': authRes.user!.id,
        'business_id': _businessId,
        'name': name,
        'username': username,
        'role': role,
        'password_hash': '',
      });
    } catch (e) {
      throw Exception(
          'Auth account created but user record failed: $e');
    }

    return {
      'id': authRes.user!.id,
      'name': name,
      'username': username,
      'role': role,
      'active': true,
    };
  }
}
