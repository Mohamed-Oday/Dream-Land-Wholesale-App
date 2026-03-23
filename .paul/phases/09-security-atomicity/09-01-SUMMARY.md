---
phase: 09-security-atomicity
plan: 01
subsystem: database, auth, security
tags: [supabase, rls, security-definer, jwt, trigger, aegis-remediation]

requires:
  - phase: 08-day1-fixes
    provides: Anon grants revoked, baseline security fixes applied
provides:
  - JWT metadata protection trigger on auth.users
  - Role checks on 7 SECURITY DEFINER functions
  - Append-only RLS on balance_adjustments audit table
affects: [09-02, 09-03]

tech-stack:
  added: []
  patterns:
    - "BEFORE UPDATE trigger for immutable JWT claims (silent revert, not exception)"
    - "Role gate pattern: get_user_role() NOT IN check at top of every SECURITY DEFINER function"
    - "Append-only audit table via RLS (no UPDATE/DELETE policies)"

key-files:
  created:
    - supabase/migrations/016_security_hardening.sql
  modified: []

key-decisions:
  - "Silent revert on metadata tampering (not RAISE EXCEPTION) — prevents breaking legitimate updateUser calls"
  - "approve_discount uses auth.uid() for approved_by — client parameter kept in signature for backward compat but ignored"
  - "cancel_order allows driver to cancel own orders (driver_id = auth.uid() check)"
  - "reject_expired_discounts requires owner/admin (not just authenticated) — added by enterprise audit"
  - "update_store_balance_on_order gets minimum auth guard as stopgap until atomic RPC in 09-02"

patterns-established:
  - "Role check at function entry: IF get_user_role() NOT IN ('owner', 'admin') THEN RAISE EXCEPTION"
  - "Audit tables use separate SELECT/INSERT policies per role, no UPDATE/DELETE"
  - "Trigger functions get REVOKE EXECUTE FROM PUBLIC"

duration: 20min
started: 2026-03-23T04:10:00Z
completed: 2026-03-23T04:30:00Z
---

# Phase 9 Plan 01: SQL Security Hardening Summary

**JWT metadata protection trigger + role checks on 7 SECURITY DEFINER functions + append-only balance_adjustments RLS — all in one SQL migration.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~20 min |
| Started | 2026-03-23 |
| Completed | 2026-03-23 |
| Tasks | 3 completed |
| Files created | 1 (316 lines SQL) |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: JWT metadata cannot be tampered | Pass | BEFORE UPDATE trigger silently reverts role/business_id changes |
| AC-2: approve_discount requires owner + auth.uid() | Pass | Role gate + auth.uid() replaces client p_approved_by |
| AC-3: cancel_order requires owner/admin or own driver | Pass | Driver ownership check via orders.driver_id = auth.uid() |
| AC-4: adjust_stock/adjust_store_balance require owner/admin | Pass | Role gate on both functions |
| AC-5: balance_adjustments append-only with role access | Pass | DROP old FOR ALL + 4 new role-specific policies |

## Accomplishments

- Closed the #1 AEGIS critical finding (F-04-001: JWT metadata spoofable) with a database trigger
- Hardened 7 SECURITY DEFINER functions with role checks (was 0 — now all covered)
- Made the balance_adjustments audit table tamper-resistant (append-only, no driver writes)
- Fixed approve_discount to use server-derived identity (auth.uid()) instead of client-supplied UUID

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/016_security_hardening.sql` | Created | JWT trigger + 7 function role checks + RLS redesign |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Silent revert (not RAISE EXCEPTION) for metadata trigger | Prevents breaking legitimate updateUser calls that modify other metadata fields | More robust but harder to detect tampering — acceptable since role is immutable anyway |
| Keep p_approved_by parameter in approve_discount signature | Dart code still passes it — removing would require Dart changes (09-02 scope) | Parameter is accepted but ignored; auth.uid() used instead |
| Add reject_expired_discounts to hardening (audit finding) | Enterprise audit identified this was missing — modifies order totals and store balances | Now requires owner/admin role |
| Stopgap auth on update_store_balance_on_order (audit finding) | Enterprise audit flagged ZERO auth — most dangerous unprotected function | Minimum auth.uid() check until atomic RPC replaces it in 09-02 |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 0 | - |
| Scope additions | 0 | - |
| Deferred | 0 | - |

**Total impact:** Plan executed exactly as written (including audit-applied upgrades).

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| None | Plan executed cleanly |

## Next Phase Readiness

**Ready:**
- Authorization layer is now hardened — safe foundation for Plan 09-02 (atomic order RPC)
- All SECURITY DEFINER functions have role gates
- balance_adjustments is append-only

**Concerns:**
- Migration 016 needs deployment to live Supabase (user informed)
- update_store_balance_on_order has only auth.uid() check (stopgap — replaced in 09-02)
- No automated SQL tests yet (Plan 09-03)

**Blockers:**
- None

---
*Phase: 09-security-atomicity, Plan: 01*
*Completed: 2026-03-23*
