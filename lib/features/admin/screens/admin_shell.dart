import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/admin/screens/admin_dashboard_screen.dart';
import 'package:tawzii/features/auth/screens/settings_placeholder.dart';
import 'package:tawzii/features/dashboard/providers/dashboard_provider.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final screens = [
      const AdminDashboardScreen(),
      const StoreListScreen(),
      const ProductListScreen(),
      const UserManagementScreen(isOwner: false),
      const SettingsPlaceholder(roleName: 'مشرف'),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          // Refresh data for the tab being switched to
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(allOrdersProvider);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.store_outlined),
            selectedIcon: const Icon(Icons.store),
            label: l10n.stores,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: l10n.products,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outlined),
            selectedIcon: const Icon(Icons.people),
            label: l10n.drivers,
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
