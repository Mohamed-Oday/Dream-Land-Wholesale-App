import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/models/app_user.dart';
import '../features/auth/screens/init_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/driver/screens/driver_shell.dart';
import '../features/owner/screens/owner_shell.dart';
import '../features/admin/screens/admin_shell.dart';

/// Manages app routing state: init check + auth.
class AppRouterNotifier extends ChangeNotifier {
  bool _initialized = false;
  bool _hasUsers = false;
  AppUser? _currentUser;

  bool get initialized => _initialized;
  bool get hasUsers => _hasUsers;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  late final StreamSubscription<AuthState> _authSub;

  AppRouterNotifier() {
    _init();
  }

  Future<void> _init() async {
    final client = Supabase.instance.client;

    // Listen to auth changes
    _authSub = client.auth.onAuthStateChange.listen((event) {
      _updateUser();
      notifyListeners();
    });

    // Check if users exist (use RPC to bypass RLS)
    try {
      final result = await client.rpc('has_users');
      _hasUsers = result as bool;
    } catch (_) {
      // RPC not available — fallback to direct query
      try {
        final result = await client.from('users').select('id').limit(1);
        _hasUsers = (result as List).isNotEmpty;
      } catch (_) {
        _hasUsers = false;
      }
    }

    // Check current session
    _updateUser();
    _initialized = true;
    notifyListeners();
  }

  void _updateUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _currentUser = AppUser.fromSupabaseUser(user);
    } else {
      _currentUser = null;
    }
  }

  void markHasUsers() {
    _hasUsers = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}

/// Single instance of the router notifier.
final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  final notifier = AppRouterNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// GoRouter provider.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(appRouterNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final path = state.matchedLocation;

      // Still loading — stay on splash
      if (!notifier.initialized) {
        return path == '/splash' ? null : '/splash';
      }

      // No users → init screen
      if (!notifier.hasUsers) {
        if (notifier.isLoggedIn) {
          // Just completed init signup
          notifier.markHasUsers();
          return notifier.currentUser!.rolePath;
        }
        return path == '/init' ? null : '/init';
      }

      // Not logged in → login
      if (!notifier.isLoggedIn) {
        return path == '/login' ? null : '/login';
      }

      // Logged in, on auth pages → go to role shell
      if (path == '/login' || path == '/splash' || path == '/init') {
        return notifier.currentUser!.rolePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/init',
        builder: (context, state) => const InitScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverShell(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerShell(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminShell(),
      ),
    ],
  );
});
