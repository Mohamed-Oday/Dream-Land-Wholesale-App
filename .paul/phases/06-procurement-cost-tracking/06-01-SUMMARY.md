---
phase: 06-procurement-cost-tracking
plan: 01
subsystem: suppliers, products, database
tags: [suppliers, cost-price, crud, rls, migration]

requires:
  - phase: 05-01
    provides: Admin Products tab, ProductListScreen with Card wrapper
provides:
  - Suppliers table with RLS (owner ALL, admin ALL, driver SELECT)
  - Supplier CRUD screens (list + form)
  - Product cost_price column (nullable, CHECK >= 0)
  - Product form cost_price field
  - Product list dual-price display (sell + cost)
  - Supplier navigation from product list app bar
affects:
  - 06-02 (purchase orders will reference suppliers)

tech-stack:
  added: []
  patterns:
    - "Safe insert pattern on supplier create (no .single()) — consistent with store create fix"
    - "Supplier CRUD follows store CRUD pattern (repository, provider, list, form)"
    - "cost_price CHECK constraint >= 0 at database level (defense-in-depth with form validation)"

key-files:
  created:
    - supabase/migrations/011_suppliers_and_cost_price.sql
    - lib/features/suppliers/repositories/supplier_repository.dart
    - lib/features/suppliers/providers/supplier_provider.dart
    - lib/features/suppliers/screens/supplier_list_screen.dart
    - lib/features/suppliers/screens/supplier_form_screen.dart
  modified:
    - lib/features/products/repositories/product_repository.dart
    - lib/features/products/screens/product_form_screen.dart
    - lib/features/products/screens/product_list_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Suppliers accessible via truck icon in product list app bar — avoids adding tabs to already-full nav bars"
  - "cost_price is optional (nullable) — backwards compatible with existing products"
  - "CHECK (cost_price >= 0) constraint at DB level — audit finding, prevents negative costs"
  - "Safe insert pattern on supplier create — lesson from 05-02 PGRST116 fix"

duration: ~20min
completed: 2026-03-22
---

# Phase 6 Plan 01: Suppliers + Product Cost Price Summary

**Suppliers table with CRUD screens and product cost_price column — data foundation for procurement tracking and profit margin calculation.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~20 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 6 (1 migration + 5 Dart) |
| Files modified | 5 |
| L10n strings added | 8 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Suppliers Table with RLS | Pass | Migration 011 creates table + index + 3 RLS policies |
| AC-2: Supplier CRUD Screens | Pass | List with FAB, form with create/edit, Card items |
| AC-3: Product Cost Price Field | Pass | Optional field in form, dual-price display in list |
| AC-4: Supplier Navigation | Pass | Truck icon in product list app bar navigates to supplier list |

## Accomplishments

- Suppliers table with business_id scoping and RLS (owner ALL, admin ALL, driver SELECT)
- Supplier list screen with Card items, empty state, pull-to-refresh, error handling
- Supplier form screen following store form pattern (name required, phone/address/contact optional)
- Product cost_price column (nullable NUMERIC, CHECK >= 0)
- Product form has cost price field with validation (optional, >= 0)
- Product list shows "sell price · cost price" when cost exists, original format when not
- Supplier list accessible from product list app bar (truck icon)
- 8 l10n strings added (suppliers, supplier, addSupplier, editSupplier, supplierName, noSuppliers, costPrice, sellPrice)

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Scope additions | 0 | — |
| Auto-fixed | 0 | — |

**Total impact:** None — plan executed exactly as written.

## Skill Audit

Skill audit: All required skills invoked ✓

## Next Phase Readiness

**Ready:**
- Suppliers exist for purchase order supplier selection (06-02)
- Products have cost_price for profit margin calculation (06-03)
- Plan 06-02 (Purchase Orders) can proceed

**Concerns:**
- Supplier soft-delete not implemented (deferred from audit — add when 06-02 creates FK references)

**Blockers:**
- None

---
*Phase: 06-procurement-cost-tracking, Plan: 01*
*Completed: 2026-03-22*
