import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/auth/screens/settings_placeholder.dart';
import 'package:tawzii/features/orders/screens/order_list_screen.dart';
import 'package:tawzii/features/payments/screens/payment_list_screen.dart';
import 'package:tawzii/features/products/screens/product_list_screen.dart';
import 'package:tawzii/features/stores/screens/store_list_screen.dart';

class OwnerShell extends ConsumerStatefulWidget {
  const OwnerShell({super.key});

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  int _selectedIndex = 0;

  Future<void> _showCreateDriverDialog(String? businessId) async {
    if (businessId == null) return;
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var loading = false;
        String? errorMsg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('إضافة سائق'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    enabled: !loading,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameCtrl,
                    enabled: !loading,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'مطلوب';
                      if (v.trim().contains(' ')) return 'بدون مسافات';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    enabled: !loading,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'مطلوب';
                      if (v.length < 6) return '6 أحرف على الأقل';
                      return null;
                    },
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMsg!,
                        style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          loading = true;
                          errorMsg = null;
                        });
                        try {
                          final client = Supabase.instance.client;
                          final username = usernameCtrl.text.trim();
                          final name = nameCtrl.text.trim();

                          // Save current session
                          final currentSession =
                              client.auth.currentSession;

                          // Create auth user
                          final authRes = await client.auth.signUp(
                            email: '$username@tawzii.local',
                            password: passwordCtrl.text,
                            data: {
                              'role': 'driver',
                              'business_id': businessId,
                              'name': name,
                              'username': username,
                            },
                          );

                          if (authRes.user == null) {
                            throw Exception('فشل إنشاء الحساب');
                          }

                          // Restore owner session (signUp logs in the new user)
                          if (currentSession?.refreshToken != null) {
                            await client.auth.setSession(
                                currentSession!.refreshToken!);
                          }

                          // Insert into users table
                          await client.from('users').insert({
                            'id': authRes.user!.id,
                            'business_id': businessId,
                            'name': name,
                            'username': username,
                            'role': 'driver',
                            'password_hash': '',
                          });

                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setDialogState(() {
                            errorMsg = 'خطأ: $e';
                            loading = false;
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إنشاء'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء حساب السائق بنجاح')),
      );
    }

    nameCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final user = ref.watch(currentUserProvider);
    final screens = [
      _DashboardPlaceholder(
        onProductsTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductListScreen()),
        ),
        onCreateDriverTap: () => _showCreateDriverDialog(user?.businessId),
      ),
      _PlaceholderScreen(title: l10n.map, icon: Icons.map),
      const StoreListScreen(),
      const SettingsPlaceholder(roleName: 'مالك'),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l10n.map,
          ),
          NavigationDestination(
            icon: const Icon(Icons.store_outlined),
            selectedIcon: const Icon(Icons.store),
            label: l10n.stores,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}

class _DashboardPlaceholder extends StatelessWidget {
  final VoidCallback onProductsTap;
  final VoidCallback onCreateDriverTap;

  const _DashboardPlaceholder({
    required this.onProductsTap,
    required this.onCreateDriverTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments),
            tooltip: 'المدفوعات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentListScreen(isOwner: true),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'الطلبات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OrderListScreen(isOwner: true),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: 'المنتجات',
            onPressed: onProductsTap,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('لوحة التحكم', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onProductsTap,
              icon: const Icon(Icons.inventory_2),
              label: const Text('إدارة المنتجات'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onCreateDriverTap,
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة سائق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
