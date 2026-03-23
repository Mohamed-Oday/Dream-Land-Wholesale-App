---
phase: 10-structural-improvements
plan: 01
subsystem: database, products
tags: [check-constraint, updated-at, trigger, cancellation-audit, repository-pattern]

requires:
  - phase: 09-security-atomicity/02
    provides: cancel_order RPC with role checks, atomic order RPC
provides:
  - CHECK constraint on products.stock_on_hand (>= 0)
  - updated_at auto-timestamps on orders, stores, products, users
  - Cancellation audit trail (cancelled_by, cancelled_at) on orders
  - Consolidated cancel_order with single UPDATE + CASE
  - adjustStock() repository method (replaces last inline RPC)
affects: [10-02]

tech-stack:
  added: []
  patterns:
    - "Shared trigger function set_updated_at() reused across 4 tables"
    - "CASE expression in UPDATE for conditional field changes"
    - "Backfill pattern: SET updated_at = created_at for existing rows"

key-files:
  created:
    - supabase/migrations/018_schema_hardening.sql
  modified:
    - lib/features/products/repositories/product_repository.dart
    - lib/features/products/screens/stock_adjustment_screen.dart

key-decisions:
  - "Single UPDATE with CASE for cancel_order (consolidated from 2 UPDATEs per audit recommendation)"
  - "REVOKE EXECUTE on set_updated_at() following trigger security pattern from migration 016"
  - "Backfill updated_at = created_at (not now()) to preserve meaningful initial timestamps"

patterns-established:
  - "set_updated_at() trigger function: reusable for any new table needing modification tracking"
  - "All RPC calls go through repositories, never called directly from screens"

duration: 10min
started: 2026-03-23T05:35:00Z
completed: 2026-03-23T05:45:00Z
---

# Phase 10 Plan 01: Schema Hardening + Cancellation Audit Summary

**Added CHECK constraint on stock, updated_at auto-timestamps on 4 core tables, cancellation audit trail on orders, and moved the last inline RPC to the repository layer.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~10 min |
| Started | 2026-03-23 |
| Completed | 2026-03-23 |
| Tasks | 2 completed |
| Files created | 1 (130 lines SQL) |
| Files modified | 2 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Stock cannot go negative | Pass | CHECK constraint `products_stock_non_negative` added |
| AC-2: updated_at auto-timestamps | Pass | 4 tables + shared trigger function + backfill |
| AC-3: Cancellation audit trail | Pass | cancelled_by = auth.uid(), cancelled_at = now(), single UPDATE with CASE |
| AC-4: No inline RPC calls in screens | Pass | adjustStock() moved to ProductRepository, 0 inline calls remain |

## Accomplishments

- Database now enforces non-negative stock via CHECK constraint (was previously unchecked)
- All 4 core tables (orders, stores, products, users) auto-track modification timestamps
- Order cancellations now record who cancelled and when — critical audit trail gap closed
- Consolidated cancel_order RPC from 2 separate UPDATEs into 1 with CASE expression
- All RPC calls now go through repository layer — consistent architecture

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/018_schema_hardening.sql` | Created | CHECK, updated_at triggers, cancellation columns, updated cancel_order |
| `lib/features/products/repositories/product_repository.dart` | Modified | Added adjustStock() method wrapping adjust_stock RPC |
| `lib/features/products/screens/stock_adjustment_screen.dart` | Modified | Replaced inline Supabase.instance.client.rpc() with repository call |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Single UPDATE with CASE in cancel_order | Audit recommended: more efficient, single row lock, atomic status+audit change | Cleaner SQL, no partial update risk |
| REVOKE on set_updated_at() | Follow trigger security pattern from migration 016 | Consistent security posture |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 0 | - |
| Scope additions | 0 | - |
| Deferred | 0 | - |

**Total impact:** Plan executed exactly as written.

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| None | Plan executed cleanly |

## Next Phase Readiness

**Ready:**
- Schema is now hardened — CHECK constraints, auto-timestamps, audit trail
- Repository layer is consistent — all RPCs go through repositories
- Foundation ready for Plan 10-02 (dashboard consolidation)

**Concerns:**
- Migrations 015-018 all need deployment to live Supabase
- CHECK constraint will cause atomic order RPC to fail if stock insufficient (correct behavior, but error message could be friendlier)

**Blockers:**
- None

---
*Phase: 10-structural-improvements, Plan: 01*
*Completed: 2026-03-23*
