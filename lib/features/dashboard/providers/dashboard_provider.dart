import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../repositories/dashboard_repository.dart';

/// Package alert threshold — only show stores with >= this many outstanding packages.
final packageAlertThresholdProvider = StateProvider<int>((ref) => 10);

final dashboardRepositoryProvider = Provider<DashboardRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return DashboardRepository(Supabase.instance.client, user.businessId);
});

final todayRevenueProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return 0.0;
  return repo.getTodayRevenue();
});

final todayOrderCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return 0;
  return repo.getTodayOrderCount();
});

final topDebtorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return [];
  return repo.getTopDebtors();
});

final packageAlertsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return [];
  return repo.getPackageAlerts();
});

/// Products with stock below their low_stock_threshold.
final lowStockProductsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return [];
  return repo.getLowStockProducts();
});

/// Today's purchase order costs.
final todayPurchasesProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return 0.0;
  return repo.getTodayPurchases();
});

/// Today's profit = revenue - purchases.
final todayProfitProvider = FutureProvider<double>((ref) async {
  final revenue = await ref.watch(todayRevenueProvider.future);
  final purchases = await ref.watch(todayPurchasesProvider.future);
  return revenue - purchases;
});

/// Recent orders for admin dashboard (last 10).
final recentOrdersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return [];
  return repo.getRecentOrders();
});

/// Pending discounts for owner dashboard.
/// Auto-rejects expired discounts first, then fetches remaining pending.
final pendingDiscountsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  if (orderRepo == null) return [];
  // Auto-reject expired discounts (>3 min) first
  try {
    await orderRepo.rejectExpiredDiscounts();
  } catch (_) {
    // Non-critical — continue fetching pending
  }
  return orderRepo.getPendingDiscounts();
});
