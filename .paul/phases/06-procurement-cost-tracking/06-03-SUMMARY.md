---
phase: 06-procurement-cost-tracking
plan: 03
subsystem: dashboard, products
tags: [kpi-cards, profit-margin, purchases-total, dashboard]

requires:
  - phase: 06-01
    provides: Product cost_price column
  - phase: 06-02
    provides: purchase_orders table with total_cost
provides:
  - Owner dashboard: Today's Purchases + Today's Profit KPI cards
  - KpiCard: optional valueColor parameter (green/red profit)
  - Product list: color-coded margin percentage badge
affects: []

tech-stack:
  added: []
  patterns:
    - "Derived provider: todayProfitProvider watches revenue + purchases providers"
    - "KpiCard valueColor: optional Color param, backwards-compatible (null defaults to onSurface)"
    - "Margin badge: pre-computed outside widget tree, color-coded via AppColors.success/error"

key-files:
  created: []
  modified:
    - lib/features/dashboard/widgets/kpi_card.dart
    - lib/features/dashboard/repositories/dashboard_repository.dart
    - lib/features/dashboard/providers/dashboard_provider.dart
    - lib/features/dashboard/screens/owner_dashboard_screen.dart
    - lib/features/products/screens/product_list_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Profit = revenue - purchases (simple, no tax/overhead)"
  - "KpiCard gets optional valueColor param (audit finding — backwards-compatible)"
  - "Margin calc outside widget tree to avoid Dart collection spread limitation (audit finding)"
  - "Admin dashboard unchanged — stays lite with lists only"

duration: ~15min
completed: 2026-03-22
---

# Phase 6 Plan 03: Profit Margins + Dashboard KPIs Summary

**Owner dashboard expanded to 4 KPI cards (revenue, orders, purchases, profit) with green/red profit coloring, plus color-coded margin percentage badges on product list.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~15 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files modified | 7 |
| L10n strings added | 2 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Today's Purchases KPI Card | Pass | Sums purchase_orders.total_cost for today |
| AC-2: Today's Profit KPI Card | Pass | Revenue - purchases, green/red via valueColor |
| AC-3: Product List Margin Indicator | Pass | Color-coded % badge, green positive, red negative |

## Accomplishments

- Owner dashboard: 4 KPI cards in 2 rows (revenue + orders, purchases + profit)
- Profit KPI: green when positive, red when negative (via new KpiCard valueColor)
- Product list: margin % badge (e.g., "25%") next to returnable chip
- DashboardRepository.getTodayPurchases() following getTodayRevenue() pattern
- todayProfitProvider derived from revenue - purchases (reactive)
- KpiCard: optional valueColor parameter (backwards-compatible)

## Deviations from Plan

None — plan executed as written after audit fixes.

## Skill Audit

Skill audit: All required skills invoked ✓

## Next Phase Readiness

**PHASE 6 COMPLETE — All 3 plans delivered:**
- 06-01: Suppliers + Product Cost Price
- 06-02: Purchase Orders
- 06-03: Profit Margins + Dashboard KPIs

**Ready:**
- Phase 7: Stock & Inventory can proceed
- All procurement infrastructure in place

**Blockers:**
- None

---
*Phase: 06-procurement-cost-tracking, Plan: 03*
*Completed: 2026-03-22*
