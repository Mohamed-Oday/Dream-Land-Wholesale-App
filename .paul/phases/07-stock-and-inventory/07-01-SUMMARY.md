---
phase: 07-stock-and-inventory
plan: 01
subsystem: database, products, orders, purchase_orders
tags: [stock, inventory, rpc, stock_movements, supabase]

requires:
  - phase: 06-03
    provides: Purchase orders table, product cost_price column
provides:
  - stock_on_hand + low_stock_threshold columns on products
  - stock_movements audit trail table
  - 3 RPC functions (deduct, replenish, restore) with idempotency guards
  - Product list stock badge with color coding
  - Order creation stock enforcement (can't exceed available stock)
  - Stock display in order product picker
  - Stock editing on product form
  - Auto-deduction on order creation, auto-replenishment on PO creation, auto-restore on cancel
affects: [07-02-low-stock-alerts, dashboard]

tech-stack:
  added: []
  patterns:
    - "Stock RPC pattern: idempotency guard + business_id auth check + SECURITY DEFINER"
    - "Fire-and-forget stock RPC: try/catch in repository, non-blocking on failure"
    - "Stock enforcement: validation at UI level (product picker + quantity controls), not database CHECK"

key-files:
  created:
    - supabase/migrations/013_stock_and_inventory.sql
  modified:
    - lib/features/orders/repositories/order_repository.dart
    - lib/features/purchase_orders/repositories/purchase_order_repository.dart
    - lib/features/products/screens/product_list_screen.dart
    - lib/features/products/screens/product_form_screen.dart
    - lib/features/orders/screens/create_order_screen.dart
    - lib/features/orders/screens/receipt_preview_screen.dart
    - lib/features/purchase_orders/screens/create_purchase_order_screen.dart
    - lib/core/l10n/app_ar.arb
    - lib/core/l10n/app_en.arb

key-decisions:
  - "Denormalized stock_on_hand column updated by RPCs (fast reads, movements table for audit)"
  - "Stock enforcement at UI level, not database CHECK (owner may oversell intentionally)"
  - "User requested stock enforcement during checkpoint — added stock blocking + picker display + form editing"
  - "Driver SELECT-only on stock_movements (audit finding — prevents direct stock manipulation)"
  - "RPC idempotency via reference_id + movement_type check (audit finding — prevents double-deduction)"

duration: ~25min
completed: 2026-03-22
---

# Phase 7 Plan 01: Stock Data Model + Automatic Stock Flow Summary

**Stock tracking with automatic deduction on orders, replenishment from purchases, restoration on cancellation, stock enforcement on order creation, and stock editing on product form.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~25 min |
| Completed | 2026-03-22 |
| Tasks | 3 completed (2 auto + 1 human-verify) |
| Files modified | 10 |
| L10n strings added | 3 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Product Stock Display | Pass | Stock badge with inventory icon, color-coded (green/red) |
| AC-2: Stock Deduction on Order Creation | Pass | deduct_stock_for_order RPC called in order repo |
| AC-3: Stock Replenishment on Purchase Order | Pass | replenish_stock_from_purchase RPC called in PO repo |
| AC-4: Stock Restoration on Order Cancellation | Pass | restore_stock_for_cancellation RPC called after cancel_order |
| AC-5: Stock Movement Audit Trail | Pass | stock_movements table with all 4 movement types |

## Accomplishments

- Migration 013: stock_on_hand + low_stock_threshold on products, stock_movements table, 3 idempotent RPC functions
- Product list shows stock count badge with color coding (green for OK, red for low stock)
- Orders automatically deduct stock; purchases automatically replenish; cancellations restore
- Stock enforcement on order creation: out-of-stock products disabled in picker, quantity capped at available stock
- Stock editing field on product form (edit mode only)
- All stock RPCs have business_id authorization + idempotency guards (audit findings applied)

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Scope additions | 3 | User-requested during checkpoint |
| Additional files | 3 | Screens modified for stock enforcement + editing |

**Total impact:** Essential UX additions requested by user during verification. No scope creep — direct user requirements.

### Scope Additions (User-Requested at Checkpoint)

**1. Stock enforcement on order creation**
- **Requested:** User asked for stock validation — can't order more than available
- **Implemented:** Product picker shows stock, disables out-of-stock items. Quantity + button capped at stock_on_hand.
- **Files:** `create_order_screen.dart` (product picker + _addProduct + _updateQuantity + _LineItem)

**2. Stock display in order product picker**
- **Requested:** User wanted stock visible when selecting products for orders
- **Implemented:** Each product in picker shows "المخزون: N", out-of-stock shows red avatar + "نفذ" badge
- **Files:** `create_order_screen.dart` (product picker ListTile)

**3. Stock editing on product form**
- **Requested:** User wanted ability to edit stock directly on products
- **Implemented:** stock_on_hand field on product edit form (edit mode only, not create)
- **Files:** `product_form_screen.dart` (controller + field + save logic)

### Additional Files Modified (beyond plan)

- `lib/features/orders/screens/create_order_screen.dart` — stock enforcement + picker display
- `lib/features/products/screens/product_form_screen.dart` — stock editing field
- `lib/features/orders/screens/receipt_preview_screen.dart` — productListProvider import + invalidation

## Skill Audit

Skill audit: All required skills invoked ✓
- /frontend-design loaded during APPLY phase

## Next Phase Readiness

**Ready:**
- Plan 07-02 can proceed: Low stock alerts + manual stock management
- stock_on_hand and low_stock_threshold columns exist (07-02 uses threshold for alerts)
- stock_movements table exists (07-02 builds movement history screen)
- Stock editing already available on product form (07-02 can add dedicated adjustment screen)

**Blockers:**
- None

---
*Phase: 07-stock-and-inventory, Plan: 01*
*Completed: 2026-03-22*
