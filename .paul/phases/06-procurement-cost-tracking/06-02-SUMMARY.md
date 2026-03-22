---
phase: 06-procurement-cost-tracking
plan: 02
subsystem: purchase-orders, database
tags: [purchase-orders, supplier-selection, product-lines, date-filters, migration]

requires:
  - phase: 06-01
    provides: Suppliers table + CRUD, product cost_price column
provides:
  - purchase_orders + purchase_order_lines tables with RLS
  - Purchase order creation (supplier picker, product lines with package pricing)
  - Purchase order list with date range filters
  - Purchase order detail view
  - Navigation from product list app bar (shopping_cart icon)
affects:
  - 06-03 (profit margins will use purchase order cost data)

tech-stack:
  added: []
  patterns:
    - "Package-level pricing: cost_per_unit × units_per_package = package cost (matches sales order pattern)"
    - "Child table RLS via EXISTS subquery against parent (purchase_order_lines → purchase_orders)"
    - "created_by FK to users(id) for PostgREST join (audit finding)"
    - "Editable quantity input field with +/- buttons for large quantities"

key-files:
  created:
    - supabase/migrations/012_purchase_orders.sql
    - lib/features/purchase_orders/repositories/purchase_order_repository.dart
    - lib/features/purchase_orders/providers/purchase_order_provider.dart
    - lib/features/purchase_orders/screens/create_purchase_order_screen.dart
    - lib/features/purchase_orders/screens/purchase_order_list_screen.dart
    - lib/features/purchase_orders/screens/purchase_order_detail_screen.dart
  modified:
    - lib/features/products/screens/product_list_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Package-level pricing: purchases are in packages, not individual units (user feedback)"
  - "Editable quantity field: direct input for large quantities alongside +/- buttons (user-requested)"
  - "created_by REFERENCES users(id): FK required for PostgREST join (audit finding)"
  - "Purchase orders are immutable: no edit/delete after creation (financial record integrity)"
  - "Navigation via shopping_cart icon in product list app bar (alongside truck for suppliers)"

duration: ~35min
completed: 2026-03-22
---

# Phase 6 Plan 02: Purchase Orders Summary

**Purchase order creation with supplier picker, package-level product lines, date-filtered list, and detail view — complete procurement transaction recording.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~35 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files created | 7 (1 migration + 6 Dart) |
| Files modified | 3 |
| L10n strings added | 14 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Purchase Orders Tables with RLS | Pass | Migration 012: 2 tables, 6 RLS policies, 4 indices, CHECK constraints |
| AC-2: Create Purchase Order | Pass | Supplier picker + product lines with package pricing + editable qty |
| AC-3: Purchase Order List with Date Filters | Pass | DateRangeFilterBar, supplier name, total, date, line count |
| AC-4: Purchase Order Detail View | Pass | Header (supplier, date, user), line items, total, notes |
| AC-5: Purchase Order Navigation | Pass | Shopping cart icon in product list app bar |

## Accomplishments

- purchase_orders + purchase_order_lines tables with RLS (owner/admin ALL, driver SELECT)
- Purchase order creation: supplier bottom sheet picker, product line items
- Package-level pricing: cost_per_unit × units_per_package = package cost
- Editable quantity input field with +/- buttons for large quantities
- Date range filtering on purchase order list (shared dateRangeProvider)
- Purchase order detail with supplier, date, created_by, line items, total, notes
- Navigation: shopping_cart icon in product list app bar
- 14 l10n strings added

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Scope additions | 2 | Package pricing + editable quantity (both user-requested) |
| Auto-fixed | 2 | Missing l10n strings (date, createdBy), unused parameter warning |

**Total impact:** Both user-requested changes improve real-world usability.

### Scope Additions (User-Requested)

1. **Package-level pricing** — User noted "we buy full packages, not single items". Changed pricing from `cost_price × quantity` to `(cost_price × units_per_package) × quantity`. Matches sales order `packagePrice` pattern.
2. **Editable quantity field** — User requested direct input for quantities instead of only +/- buttons. Added 48px-wide TextField between the +/- controls.

### Auto-fixed Issues

1. **Missing l10n strings** — `date` and `createdBy` strings didn't exist in ARB files. Used inline Arabic text instead.
2. **Unused parameter warning** — `quantity` default value on `_PurchaseLineItem` was unused. Changed to required parameter.

## Skill Audit

Skill audit: All required skills invoked ✓

## Next Phase Readiness

**Ready:**
- Plan 06-03 (Profit Margins + Dashboard KPIs) can proceed
- Purchase order cost data available for profit calculations
- Product cost_price + purchase order unit_cost available for margin analysis

**Concerns:**
- Non-atomic PO + lines insert (deferred from audit — matches existing order pattern)

**Blockers:**
- None

---
*Phase: 06-procurement-cost-tracking, Plan: 02*
*Completed: 2026-03-22*
