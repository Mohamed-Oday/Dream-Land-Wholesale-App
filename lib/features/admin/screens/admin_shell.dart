import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawzii/core/ui/tawzii_nav_bar.dart';
import 'package:tawzii/features/admin/screens/admin_dashboard_screen.dart';
import 'package:tawzii/features/auth/screens/settings_screen.dart';
import 'package:tawzii/features/driver/screens/user_management_screen.dart';
import 'package:tawzii/features/products/screens/product_list_screen.dart';
import 'package:tawzii/features/stores/screens/store_list_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;

  static const _labels = [
    'الرئيسية',
    'المتاجر',
    'المخزون',
    'المستخدمون',
    'الإعدادات',
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      const AdminDashboardScreen(),
      const StoreListScreen(),
      const ProductListScreen(),
      const UserManagementScreen(isOwner: false),
      const SettingsScreen(roleName: 'مشرف'),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: TawziiNavBar(
        labels: _labels,
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
