import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper around Supabase client for typed access.
///
/// Initialized in main.dart via Supabase.initialize().
/// This class provides convenient access to the client instance.
class SupabaseClientWrapper {
  SupabaseClientWrapper._();

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static SupabaseQueryBuilder from(String table) => client.from(table);

  static RealtimeChannel channel(String name) => client.channel(name);
}
