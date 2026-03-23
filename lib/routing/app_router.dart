import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/version_utils.dart';
import '../features/auth/models/app_user.dart';
import '../features/auth/screens/force_update_screen.dart';
import '../features/auth/screens/init_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/driver/screens/driver_shell.dart';
import '../features/owner/screens/owner_shell.dart';
import '../features/admin/screens/admin_shell.dart';

/// Manages app routing state: init check + auth + version check.
class AppRouterNotifier extends ChangeNotifier {
  bool _initialized = false;
  bool _hasUsers = false;
  bool _forceUpdate = false;
  String _minVersion = '';
  String _downloadUrl = '';
  AppUser? _currentUser;

  bool get initialized => _initialized;
  bool get hasUsers => _hasUsers;
  bool get forceUpdate => _forceUpdate;
  String get minVersion => _minVersion;
  String get downloadUrl => _downloadUrl;
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

    // Check minimum version from remote_config
    try {
      final configResult = await client
          .from('remote_config')
          .select('key, value');
      final rows = List<Map<String, dynamic>>.from(configResult);
      final config = {
        for (final r in rows) r['key'] as String: r['value'] as String
      };
      final remoteMin = config['min_version'] ?? '';
      if (remoteMin.isNotEmpty &&
          isNewerVersion(remoteMin, AppConstants.appVersion)) {
        _forceUpdate = true;
        _minVersion = remoteMin;
        _downloadUrl = config['download_url'] ?? '';
      }
    } catch (_) {
      // Network failure: proceed normally — don't block app on fetch error
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

      // Force update — block all navigation
      if (notifier.forceUpdate) {
        return path == '/force-update' ? null : '/force-update';
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
        path: '/force-update',
        builder: (context, state) => ForceUpdateScreen(
          minVersion: notifier.minVersion,
          downloadUrl: notifier.downloadUrl,
        ),
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
