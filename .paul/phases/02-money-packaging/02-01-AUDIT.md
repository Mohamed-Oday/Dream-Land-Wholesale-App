# Enterprise Plan Audit Report

**Plan:** .paul/phases/02-money-packaging/02-01-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally Acceptable (upgraded after fixes applied)

---

## 1. Executive Verdict

**Conditionally acceptable → enterprise-ready after fixes applied.**

The plan correctly identifies the RLS constraint (drivers can't UPDATE stores) and solves it with SECURITY DEFINER RPC functions — this is the right architecture. The atomic balance update approach prevents the split-brain scenario of separate INSERT + UPDATE. Two critical gaps existed: a race condition on concurrent payments and missing authorization in the RPC functions. Both have been fixed. I would approve this plan for production with the applied fixes.

## 2. What Is Solid

- **RPC function architecture:** Using SECURITY DEFINER PL/pgSQL functions to bypass driver's read-only stores RLS is the correct approach. Direct client UPDATE would require weakening RLS policies.
- **Atomic balance updates:** Single database transaction for payment INSERT + balance UPDATE ensures consistency. No split-brain between payment and balance.
- **Audit trail in payments table:** `previous_balance` and `new_balance` columns provide defensible audit evidence for every balance change. Auditors can reconstruct the full balance history from payments alone.
- **Fire-and-forget order balance hook:** Correct trade-off — order creation is the priority, balance update is secondary. An order without a balance update is visible and reconcilable; a blocked order is lost revenue.
- **Confirmation dialog before financial transactions:** Established pattern from Phase 1, consistently applied here.
- **Boundaries protect all prior work:** Explicit DO NOT CHANGE list prevents scope creep into auth, products, stores, theme.

## 3. Enterprise Gaps Identified

### Gap 1: Race condition on concurrent payments (DATA INTEGRITY — CRITICAL)
Two drivers collecting payments from the same store simultaneously: both SELECT credit_balance=14400, both INSERT payment, both UPDATE to different values. Last write wins — one payment's balance change is lost. The SELECT ... FOR UPDATE lock prevents this by serializing access to the store row.

### Gap 2: Missing authorization in RPC functions (SECURITY — CRITICAL)
SECURITY DEFINER functions execute with the function owner's privileges, bypassing all RLS. The `create_payment` function accepts `p_business_id` as a parameter but never validates it matches the caller's JWT. A crafted client request could create payments in another business's context. The authorization check prevents cross-tenant data leakage.

### Gap 3: No overpayment warning (UX SAFETY)
A driver could enter 100,000 DA when the store owes 5,000 DA. While not technically wrong (overpayment is valid), it's likely a data entry error. An orange warning (non-blocking) catches obvious mistakes without preventing legitimate overpayments.

### Gap 4: Frontmatter file list mismatch (PLAN ACCURACY)
Frontmatter listed `order_repository.dart` but Task 2 modifies `create_order_screen.dart`. The credit balance hook is in the UI layer (after repo.create() succeeds), not the repository. Corrected to match actual modification target.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Race condition on concurrent payments | Task 1 `<action>` RPC function 1 | Added `SELECT ... FOR UPDATE` row lock on stores table before reading credit_balance |
| 2 | Missing authorization in RPC function | Task 1 `<action>` RPC function 1 | Added JWT business_id validation: caller's business must match p_business_id parameter |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 3 | No overpayment warning | Task 2 `<action>` amount input; new AC-10 | Added orange warning when payment amount > store credit_balance; non-blocking |
| 4 | Frontmatter file list mismatch | Frontmatter `files_modified` | Changed `order_repository.dart` to `create_order_screen.dart` |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Balance update failure visibility on order creation | Order exists in DB, owner can reconcile manually. Adding a notification system is Phase 2 scope (real-time notifications) — not worth blocking this plan. |
| 2 | Idempotency on RPC calls | Cash payments with manual confirmation make duplicate submissions unlikely. Driver would notice immediately. Retry logic adds complexity without proportional benefit for <10 drivers. |

## 5. Audit & Compliance Readiness

**Audit evidence:** Every payment stores `previous_balance` and `new_balance`, creating a complete audit trail. The full balance history can be reconstructed from the payments table alone, independent of the stores.credit_balance field. This is defense-in-depth.

**Silent failure prevention:** RPC functions run inside a transaction — if any step fails, the entire operation rolls back. No partial state (payment without balance update or vice versa). The FOR UPDATE lock prevents concurrent corruption.

**Post-incident reconstruction:** Given any store_id, query `SELECT * FROM payments WHERE store_id = ? ORDER BY created_at` to reconstruct the complete balance history. Each row has previous → new, forming a verifiable chain.

**Ownership and accountability:** Each payment has `driver_id` (who collected), `store_id` (from where), `amount` (how much), `created_at` (when). The authorization check in the RPC function ensures payments can only be created within the caller's business context.

## 6. Final Release Bar

**What must be true before this plan ships:**
- RPC functions use FOR UPDATE lock (verified in migration SQL)
- RPC functions validate caller's business_id against JWT
- Overpayment warning is visible but non-blocking
- Payment audit trail is complete (previous_balance, new_balance on every record)

**Remaining risks if shipped as-is (with fixes applied):**
- Balance update on order creation is fire-and-forget (low risk, manually reconcilable)
- No idempotency guard on RPC calls (low risk for cash-based system with confirmation dialog)
- Credit balance could go negative on overpayment (by design, but unusual)

**Sign-off:** With the applied fixes (row locking + authorization), this plan handles the most critical financial integrity concerns. The audit trail is solid. I would sign my name to this system.

---

**Summary:** Applied 2 must-have + 2 strongly-recommended upgrades. Deferred 2 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
