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

/// Single RPC returning all dashboard KPIs — replaces 5 separate queries.
final dashboardSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return {};
  return repo.getDashboardSummary();
});

/// Derived from dashboardSummaryProvider — no separate query.
final todayRevenueProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_revenue'] as num?)?.toDouble() ?? 0.0;
});

/// Derived from dashboardSummaryProvider — no separate query.
final todayOrderCountProvider = FutureProvider<int>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_order_count'] as num?)?.toInt() ?? 0;
});

/// Derived from dashboardSummaryProvider — no separate query.
final todayPurchasesProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_purchases'] as num?)?.toDouble() ?? 0.0;
});

/// Derived from dashboardSummaryProvider — no separate query.
final todayProfitProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_profit'] as num?)?.toDouble() ?? 0.0;
});

/// Derived from dashboardSummaryProvider — no separate query.
final topDebtorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return List<Map<String, dynamic>>.from(
      summary['top_debtors'] as List? ?? []);
});

/// Derived from dashboardSummaryProvider — no separate query.
final lowStockProductsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return List<Map<String, dynamic>>.from(
      summary['low_stock_products'] as List? ?? []);
});

/// Package alerts — still a separate RPC (already consolidated).
final packageAlertsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  if (repo == null) return [];
  return repo.getPackageAlerts();
});

/// Recent orders for admin dashboard (last 10) — separate query (complex joins).
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
