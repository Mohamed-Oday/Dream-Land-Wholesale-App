import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/surface_card.dart';
import 'package:tawzii/core/ui/tawzii_nav_bar.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/auth/screens/settings_screen.dart';
import 'package:tawzii/features/dashboard/screens/owner_dashboard_screen.dart';
import 'package:tawzii/features/driver/screens/user_management_screen.dart';
import 'package:tawzii/features/location/screens/driver_map_screen.dart';
import 'package:tawzii/features/orders/screens/order_list_screen.dart';
import 'package:tawzii/features/products/screens/product_list_screen.dart';
import 'package:tawzii/features/stores/screens/store_list_screen.dart';

class OwnerShell extends ConsumerStatefulWidget {
  const OwnerShell({super.key});

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  int _selectedIndex = 0;

  static const _labels = [
    'الرئيسية',
    'الطلبات',
    'المتاجر',
    'المخزون',
    'المزيد',
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      const OwnerDashboardScreen(),
      const OrderListScreen(isOwner: true),
      const StoreListScreen(),
      const ProductListScreen(),
      const _OwnerMoreScreen(),
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

/// المزيد tab — users, driver map and settings entry points (canvas t2 nav).
class _OwnerMoreScreen extends StatelessWidget {
  const _OwnerMoreScreen();

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final chevron = Icon(Icons.chevron_left, size: 20, color: t.textMuted);

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
        children: [
          SurfaceCard(
            child: Column(
              children: [
                TawziiRow(
                  title: 'المستخدمون',
                  subtitle: 'الحسابات والأداء',
                  trailing: chevron,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(isOwner: true),
                    ),
                  ),
                ),
                TawziiRow(
                  title: 'خريطة البائعين',
                  subtitle: 'مواقع البائعين في الخدمة',
                  trailing: chevron,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DriverMapScreen(),
                    ),
                  ),
                ),
                TawziiRow(
                  title: 'الإعدادات',
                  subtitle: 'الإشعارات والطابعة والمظهر',
                  trailing: chevron,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(roleName: 'مالك'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
