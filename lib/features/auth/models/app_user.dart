import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents an authenticated user in the app.
///
/// Constructed from Supabase Auth user + user_metadata.
/// No password field — passwords are Supabase Auth only.
class AppUser {
  final String id;
  final String businessId;
  final String username;
  final String role;
  final String name;
  final bool active;

  const AppUser({
    required this.id,
    required this.businessId,
    required this.username,
    required this.role,
    required this.name,
    this.active = true,
  });

  /// Create AppUser from Supabase Auth user.
  ///
  /// Expects user_metadata to contain:
  /// - role: "owner" | "admin" | "driver"
  /// - business_id: UUID string
  /// - name: display name
  /// - username: login username
  factory AppUser.fromSupabaseUser(User user) {
    final metadata = user.userMetadata ?? {};
    return AppUser(
      id: user.id,
      businessId: metadata['business_id'] as String? ?? '',
      username: metadata['username'] as String? ?? '',
      role: metadata['role'] as String? ?? 'driver',
      name: metadata['name'] as String? ?? '',
      active: metadata['active'] as bool? ?? true,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';

  /// Route path for this user's role shell.
  String get rolePath => '/$role';
}
