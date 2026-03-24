import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/auth/screens/settings_placeholder.dart';
import 'package:tawzii/features/location/providers/location_provider.dart';
import 'package:tawzii/features/driver_loads/providers/driver_load_providers.dart';
import 'package:tawzii/features/driver_loads/screens/driver_stock_screen.dart';
import 'package:tawzii/features/orders/providers/order_provider.dart';
import 'package:tawzii/features/orders/screens/order_list_screen.dart';
import 'package:tawzii/features/packages/screens/package_list_screen.dart';
import 'package:tawzii/features/payments/screens/payment_list_screen.dart';
import 'package:tawzii/features/products/providers/product_provider.dart';
import 'package:tawzii/features/stores/screens/store_list_screen.dart';

class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  int _selectedIndex = 0;
  bool _toggling = false;

  Future<void> _toggleDuty() async {
    if (_toggling) return;
    setState(() => _toggling = true);

    final isOnDuty = ref.read(isOnDutyProvider);
    final locationService = ref.read(locationServiceProvider);

    if (!isOnDuty) {
      // Turning ON — check permission + GPS
      final granted = await locationService.checkAndRequestPermission();
      if (!granted) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationPermissionDenied)),
          );
        }
        setState(() => _toggling = false);
        return;
      }

      // Start tracking
      final user = ref.read(currentUserProvider);
      final repo = ref.read(locationRepositoryProvider);
      if (user != null && repo != null) {
        locationService.startTracking(
          onPosition: (position) async {
            try {
              await repo.insertPosition(
                driverId: user.id,
                lat: position.latitude,
                lng: position.longitude,
              );
            } catch (_) {
              // Silently skip failed inserts — no error toast every 30s
            }
          },
        );
      }
      ref.read(isOnDutyProvider.notifier).state = true;
    } else {
      // Turning OFF
      locationService.stopTracking();
      ref.read(isOnDutyProvider.notifier).state = false;
    }

    setState(() => _toggling = false);
  }

  @override
  void dispose() {
    // Stop tracking when shell is disposed
    try {
      ref.read(locationServiceProvider).stopTracking();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOnDuty = ref.watch(isOnDutyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final screens = [
      const OrderListScreen(isOwner: false),
      const DriverStockScreen(),
      const PackageListScreen(),
      const PaymentListScreen(isOwner: false),
      const StoreListScreen(),
      const SettingsPlaceholder(roleName: 'بائع'),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: screens[_selectedIndex]),
          // On-duty toggle banner
          Material(
            color: isOnDuty
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: _toggling ? null : _toggleDuty,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        isOnDuty ? Icons.location_on : Icons.location_off,
                        size: 20,
                        color: isOnDuty
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isOnDuty ? l10n.onDuty : l10n.offDuty,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isOnDuty
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_toggling)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isOnDuty
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Switch(
                          value: isOnDuty,
                          onChanged: (_) => _toggleDuty(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          // Refresh data for the tab being switched to
          ref.invalidate(orderListProvider);
          ref.invalidate(driverCurrentLoadProvider);
          ref.invalidate(productListProvider);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.orders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_outlined),
            selectedIcon: const Icon(Icons.inventory),
            label: l10n.myStock,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: l10n.packages,
          ),
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: l10n.payments,
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
