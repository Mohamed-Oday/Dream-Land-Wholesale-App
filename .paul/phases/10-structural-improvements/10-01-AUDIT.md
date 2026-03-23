# Enterprise Plan Audit Report

**Plan:** .paul/phases/10-structural-improvements/10-01-PLAN.md
**Audited:** 2026-03-23
**Verdict:** Enterprise-ready (minor upgrades applied)

---

## 1. Executive Verdict

**Enterprise-ready.** This is a well-scoped schema improvement plan with low blast radius. CHECK constraints, auto-timestamps, and audit trail columns are standard database hygiene. The cancel_order RPC update preserves all existing security logic while adding audit fields. The inline RPC cleanup is a minor code quality improvement.

No architectural gaps found. The two findings were both execution-level optimizations.

## 2. What Is Solid

1. **CHECK constraint approach** — Database-level enforcement is the correct place for the stock_on_hand >= 0 invariant. It catches edge cases that Dart-side validation cannot (race conditions, direct SQL access).

2. **Shared trigger function** — `set_updated_at()` as a reusable function with per-table triggers is the standard PostgreSQL pattern. Clean and maintainable.

3. **Backfill strategy** — Setting `updated_at = created_at` for existing rows is correct. It provides a meaningful initial value rather than NULL or current timestamp.

4. **auth.uid() for cancelled_by** — Server-derived identity, consistent with the pattern from 09-02's atomic order RPC. No client-side spoofing possible.

5. **Boundaries** — Explicitly protects existing migrations, order flow, and test suite. Correctly defers large items to future plans/milestones.

## 3. Enterprise Gaps Identified

### Gap A: Missing REVOKE on trigger function (STRONGLY RECOMMENDED)
Migration 016 established the pattern: `REVOKE EXECUTE ON FUNCTION protect_user_metadata() FROM PUBLIC`. The new `set_updated_at()` trigger function should follow the same security pattern. While trigger functions are invoked by triggers (not directly by users), consistency in security posture is important for audit compliance.

### Gap B: Two separate UPDATE statements on same row in cancel_order (STRONGLY RECOMMENDED)
The current cancel_order RPC updates the orders row twice: once for `status = 'cancelled'` and conditionally for `discount_status = 'none'`. Adding cancelled_by/cancelled_at creates a third field to update. These should be consolidated into a single UPDATE using CASE for the conditional discount_status change. More efficient (single row lock), clearer intent, and audit columns are set atomically with the status change.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

None.

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Missing REVOKE on set_updated_at() | Task 1 action (PART 2) | Added `REVOKE EXECUTE ON FUNCTION set_updated_at() FROM PUBLIC` |
| 2 | Two UPDATE statements should be one | Task 1 action (PART 4) | Consolidated into single UPDATE with CASE expression for discount_status |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | CHECK constraint error not Arabic-friendly | Existing PostgrestException handling catches it; UI already prevents over-ordering via stock limits |
| 2 | ProductRepository existence ambiguity | Executor will check and create/extend during APPLY |

## 5. Audit & Compliance Readiness

**Audit evidence:** updated_at columns on all core tables create a modification audit trail. cancelled_by/cancelled_at on orders records the actor and timestamp for the most sensitive state transition. Combined with the existing created_at columns, every significant record now has creation and modification tracking.

**Silent failure prevention:** The CHECK constraint on stock_on_hand prevents silent inventory corruption. Before this, stock could go negative without any system-level detection.

**Post-incident reconstruction:** If a disputed cancellation occurs, investigators can query `cancelled_by` to identify the actor and `cancelled_at` for the exact timestamp. The `updated_at` trigger provides general modification tracking.

## 6. Final Release Bar

**What must be true before this plan ships:**
- CHECK constraint prevents negative stock_on_hand
- All 4 core tables have auto-updating updated_at
- cancel_order populates cancelled_by and cancelled_at atomically
- No screen-level inline RPC calls remain

**Remaining risks if shipped as-is (after upgrades):**
- Migrations 015-018 all need deployment to live Supabase
- No automated SQL tests (acceptable — Dart unit tests cover financial logic)

**Sign-off:** Clean plan, approved without reservation.

---

**Summary:** Applied 0 must-have + 2 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
