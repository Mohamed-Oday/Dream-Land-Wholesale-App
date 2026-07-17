import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/theme/app_theme.dart';
import 'package:tawzii/core/ui/tawzii_nav_bar.dart';
import 'package:tawzii/core/ui/tawzii_row.dart';
import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/auth/screens/settings_screen.dart';
import 'package:tawzii/features/location/providers/location_provider.dart';
import 'package:tawzii/features/driver_loads/screens/driver_stock_screen.dart';
import 'package:tawzii/features/orders/screens/order_list_screen.dart';
import 'package:tawzii/features/packages/screens/package_list_screen.dart';
import 'package:tawzii/features/payments/screens/payment_list_screen.dart';
import 'package:tawzii/features/stores/screens/store_list_screen.dart';

class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  // Store-hub-centric flow (canvas t4): stores tab is the driver's home.
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
          setState(() => _toggling = false);
        }
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

    if (mounted) setState(() => _toggling = false);
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
    final t = TawziiTokens.of(context);

    final screens = [
      const StoreListScreen(),
      const OrderListScreen(isOwner: false),
      const DriverStockScreen(),
      const PaymentListScreen(isOwner: false),
      const _DriverMoreScreen(),
    ];

    final labels = [
      l10n.stores,
      l10n.orders,
      l10n.myStock,
      l10n.payments,
      'المزيد',
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
          ),
          // On-duty toggle banner (canvas 3c): surface, hairline top border,
          // 8px success dot, 13/600 label, success-colored switch.
          Material(
            color: t.surface,
            child: InkWell(
              onTap: _toggling ? null : _toggleDuty,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.border)),
                ),
                padding:
                    const EdgeInsetsDirectional.symmetric(horizontal: 18),
                height: 48,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnDuty ? t.success : t.borderStrong,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOnDuty
                            ? 'في الخدمة — التتبع مفعّل'
                            : 'خارج الخدمة — التتبع متوقف',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              isOnDuty ? t.textPrimary : t.textSecondary,
                        ),
                      ),
                    ),
                    if (_toggling)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.textMuted,
                        ),
                      )
                    else
                      Switch(
                        value: isOnDuty,
                        onChanged: (_) => _toggleDuty(),
                        activeThumbColor: t.surface,
                        activeTrackColor: t.success,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: TawziiNavBar(
        labels: labels,
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

/// المزيد tab — packages and settings entry points (canvas t3/t4 nav).
class _DriverMoreScreen extends StatelessWidget {
  const _DriverMoreScreen();

  @override
  Widget build(BuildContext context) {
    final t = TawziiTokens.of(context);
    final chevron = Icon(Icons.chevron_left, size: 20, color: t.textMuted);

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
        children: [
          TawziiRow(
            hardened: true,
            title: 'الصناديق',
            subtitle: 'أرصدة الصناديق والاسترجاع',
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PackageListScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TawziiRow(
            hardened: true,
            title: 'الإعدادات',
            subtitle: 'الإشعارات والطابعة والمظهر',
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(roleName: 'بائع'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
