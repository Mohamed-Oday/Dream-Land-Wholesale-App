# Enterprise Plan Audit Report

**Plan:** .paul/phases/04-polish-hardening/04-03-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable (now acceptable after applying fixes)

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **acceptable** after applying 1 must-have and 2 strongly-recommended fixes.

The plan has strong fundamentals: FOR UPDATE locking, JWT authorization, RLS on the adjustments table, role-gated UI, and required reason field. The critical gap was accepting `adjusted_by` as a client parameter — for a financial audit trail, the server must derive the user identity from the JWT to prevent spoofing.

## 2. What Is Solid

- **FOR UPDATE locking** on store row before balance modification — prevents concurrent modification
- **Separate balance_adjustments table** instead of overloading payments — clean audit separation
- **RLS policy** on balance_adjustments using JWT business_id — proper row-level security
- **Role-gating** at UI level (owner/admin only) — defense in depth
- **Required reason field** with minLength validation — ensures audit trail quality
- **SECURITY DEFINER** on RPC — executes with elevated privileges, properly guarded by auth checks

## 3. Enterprise Gaps Identified

### Gap 1: adjusted_by From Client Input (CRITICAL)
The RPC accepted `p_adjusted_by` as a parameter, meaning the client could pass any UUID. For financial operations, the identity of who performed the adjustment must be non-spoofable. An attacker or buggy client could attribute adjustments to another user. `auth.uid()` is the only trustworthy source.

### Gap 2: RPC Allows Zero-Amount Adjustments
A zero-amount adjustment has no financial effect but would create a log entry, polluting the audit trail. The RPC should reject `p_amount = 0` explicitly.

### Gap 3: Threshold Dialog Missing Input Validation
The threshold config dialog accepts a number but doesn't validate the range. Values like 0, -1, or non-numeric input could cause the filter to behave unexpectedly (showing all stores or crashing on parse).

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | adjusted_by from client is spoofable — use auth.uid() server-side | Task 1 Part B (RPC), Part C (repo), Part D (UI call) | Removed p_adjusted_by parameter. RPC now uses auth.uid(). Repository method no longer accepts adjustedBy. UI call simplified. |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | RPC allows zero-amount adjustments | Task 1 Part B (RPC) | Added `IF p_amount = 0 THEN RAISE EXCEPTION 'amount_cannot_be_zero'` |
| 2 | Threshold dialog accepts invalid input | Task 1 Part A | Added validation: threshold >= 1 before accepting |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Threshold not persisted across app restarts | Already acknowledged in scope limits. StateProvider for MVP is pragmatic. |

## 5. Audit & Compliance Readiness

**Financial audit trail**: Now non-spoofable. `adjusted_by` is derived from `auth.uid()`, meaning the JWT's authenticated user identity is always recorded. Post-incident reconstruction can definitively identify who made each adjustment.

**Authorization**: Two layers — JWT business_id check in RPC + role check in UI. Even if UI is bypassed, the RPC requires authentication and correct business membership.

**Data integrity**: FOR UPDATE prevents concurrent balance modifications. The adjustment log captures previous_balance and new_balance, enabling full reconstruction.

## 6. Final Release Bar

**What must be true before shipping:**
- RPC uses auth.uid() for adjusted_by ✓ (applied)
- Migration 008 deployed before app update

**Sign-off:** With the 3 applied upgrades, I would sign my name to this plan.

---

**Summary:** Applied 1 must-have + 2 strongly-recommended upgrades. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
