# Enterprise Plan Audit Report

**Plan:** .paul/phases/03-visibility-control/03-03-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally acceptable → Accepted after applying 1 must-have + 4 strongly-recommended upgrades

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to **accepted** after applying findings.

This plan modifies financial data (order totals, store credit_balance) through an approval workflow — the highest-stakes plan in the project so far. The core architecture is sound: server-side RPCs ensure atomic operations, the auto-reject design prevents field blocking, and confirmation dialogs protect against accidental actions. One critical race condition gap and several data consistency issues were identified and corrected.

## 2. What Is Solid

- **Schema readiness:** discount, discount_status, discount_approved_by fields already exist in the orders table. No schema changes needed — reduces migration risk to zero.
- **Server-side atomicity:** approve_discount, reject_discount, and reject_expired_discounts all run as PL/pgSQL functions — atomic by default. The credit_balance adjustment in reject_discount happens in the same transaction as the order update.
- **Auto-reject design:** Running reject_expired_discounts BEFORE fetching pending discounts (Task 2) is the correct sequence — prevents showing already-expired discounts to the owner.
- **AppConstants.discountTimeout already defined:** The 3-minute timeout is centralized, not hardcoded in the SQL (though the SQL uses `interval '3 minutes'` — these should match).
- **No new dependencies:** All work uses existing Flutter/Supabase patterns.
- **Scope limits are correct:** No Realtime, no push notifications, no percentage discounts, no offline handling — each is a defensible MVP exclusion.

## 3. Enterprise Gaps Identified

### Gap 1: Stale UI race condition on approve/reject (CRITICAL)
The owner views pending discounts. A discount auto-expires at 3:01 (auto-rejected on next refresh). But the owner already has the card visible and taps "Approve" on the now-rejected discount. The RPC checks `discount_status = 'pending'` and silently fails — but the UI shows a generic error or hangs. Without a specific exception for "already processed," the owner has no idea what happened.

### Gap 2: pendingDiscountsProvider defined in two places
Task 1 adds `pendingDiscountsProvider` to `order_provider.dart`. Task 2 adds it to `dashboard_provider.dart`. Two providers with the same name would cause a naming conflict, or if different names, confusion about which to use. The provider belongs in `dashboard_provider.dart` only, since it's consumed by the dashboard.

### Gap 3: Receipt shows discount line for rejected discounts
The plan shows discount deduction on receipt when `discount > 0`, regardless of status. When a discount is rejected, the total is recalculated to `subtotal + tax` (no discount). But the receipt would still show "-100 DA discount" alongside a total that doesn't include the deduction — misleading if printed and shown to a store.

### Gap 4: Migration deployment step missing
Consistent with previous audits — need to deploy migration before testing.

### Gap 5: No specific error message for already-processed discounts
When approve/reject fails because the discount was already processed, the UI needs to show a specific message ("already processed") rather than a generic error, so the owner understands what happened.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Stale UI race condition | Task 1 action (approve/reject RPCs) | Added `RAISE EXCEPTION 'discount_already_processed'` when status != 'pending' |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 2 | Duplicate provider definition | Task 1 action (order_provider.dart) | Removed pendingDiscountsProvider from Task 1; stays only in dashboard_provider.dart (Task 2) |
| 3 | Receipt misleading after rejection | Task 1 action (receipt_preview_screen.dart) | Discount line shown only when discount_status is 'approved' or 'pending', NOT 'rejected' |
| 4 | Migration deployment verification | Task 1 verify | Added deployment step |
| 5 | Stale UI error handling in dashboard | Task 2 action (approve/reject actions) | Added catch for 'discount_already_processed' with specific user-facing message + l10n string |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 6 | No server-side discount amount validation | Client-side validation sufficient for <10 trusted internal drivers. No public API. RLS prevents cross-business access. |

## 5. Audit & Compliance Readiness

**Financial data integrity:** The reject_discount RPC atomically updates order total AND store credit_balance in a single transaction. If either fails, both roll back. The auto-reject RPC follows the same pattern for batch processing. This is correct for financial operations.

**Audit trail:** discount_approved_by records WHO approved each discount. discount_status records the final state. The original discount amount is preserved on the order record even after rejection — auditors can reconstruct what was requested and what happened.

**Race condition prevention:** RPCs check `discount_status = 'pending'` before acting. If two operations race (e.g., auto-reject vs manual approve), only one succeeds. The UI handles the failure case with a specific error message.

**Data consistency:** On rejection, both the order total and store credit_balance are adjusted atomically. The receipt only shows discount deduction for approved/pending discounts, preventing misleading financial documents.

## 6. Final Release Bar

**What must be true before this plan ships:**
- RPCs raise 'discount_already_processed' when acting on non-pending discounts
- Receipt only shows discount for approved/pending status
- Migration 006 deployed before testing
- UI handles race condition gracefully with specific error messages

**Remaining risks if shipped as-is (after fixes):**
- Auto-reject only fires when owner opens dashboard (acceptable — 3 min window is soft, not hard)
- No server-side discount amount validation (acceptable for trusted internal users)
- SQL uses hardcoded `interval '3 minutes'` while Dart uses `AppConstants.discountTimeout` — if changed, must update both

**Sign-off:** With the applied upgrades, I would approve this plan for production. The financial data operations are atomic and the race condition is handled.

---

**Summary:** Applied 1 must-have + 4 strongly-recommended upgrades. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
