# Enterprise Plan Audit Report

**Plan:** phases/06-procurement-cost-tracking/06-01-PLAN.md
**Audited:** 2026-03-22
**Verdict:** Conditionally Acceptable (now enterprise-ready after applying fixes)

---

## 1. Executive Verdict

**Conditionally acceptable** — upgraded to enterprise-ready after applying 1 must-have and 1 strongly-recommended fix.

The plan is well-structured: clear phase decomposition (06-01/02/03), correct schema design (nullable cost_price for backwards compatibility), existing RLS pattern adherence, and safe insert pattern from lessons learned. Good scope discipline — no purchase orders or profit calculations in this plan.

Would I sign off? **Yes**, after the applied fixes.

## 2. What Is Solid

- **Migration design:** Suppliers table follows established schema patterns (business_id, UUID PK, timestamptz). RLS policies mirror existing stores pattern (owner ALL, admin ALL, driver SELECT). Backwards-compatible nullable cost_price.
- **Safe insert pattern:** Plan explicitly specifies "no .single()" on supplier create, learning from the 05-02 PGRST116 driver RLS issue.
- **Phase decomposition:** Correctly splits procurement into 3 plans: foundation (06-01), purchase orders (06-02), profit/KPIs (06-03). No overloaded plans.
- **Navigation simplicity:** Suppliers accessed from product list app bar icon — avoids adding tabs to already-full navigation bars.
- **Boundaries:** Clear exclusions (no purchase orders, no profit calc, no dashboard changes).

## 3. Enterprise Gaps Identified

### Gap 1: No CHECK constraint on cost_price
Product `unit_price` has `CHECK (unit_price > 0)`. The new `cost_price` column has no constraint, allowing negative values. A negative cost price would corrupt profit margin calculations in 06-03. The form validates `cost < 0` but database constraints are defense-in-depth against direct SQL/API access.

### Gap 2: Missing flutter gen-l10n step
Plan adds l10n strings to .arb files but doesn't mention running `flutter gen-l10n` to regenerate AppLocalizations. In 05-02, this omission caused compile errors that had to be fixed during execution.

### Gap 3: No supplier soft-delete (deferred)
Suppliers table has no `active` flag. When purchase orders reference suppliers (06-02), deleting a supplier would violate FK constraints or orphan records. The FOR ALL policies include DELETE — no guard against accidental deletion.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | No CHECK on cost_price | Task 1 Step 1 (migration SQL) | Added `CHECK (cost_price >= 0)` to ALTER TABLE statement |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Missing flutter gen-l10n | Task 1 Step 2 (l10n strings) | Added explicit `flutter gen-l10n` step after adding .arb strings |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | Supplier soft-delete (active flag) | No FK references to suppliers yet — purchase_orders table comes in 06-02. Add `active` flag when planning 06-02 if needed, or use ON DELETE RESTRICT on the FK. |

## 5. Audit & Compliance Readiness

**Audit evidence:** Suppliers table has standard columns with created_at timestamp. RLS policies ensure data isolation by business_id. Cost price has CHECK constraint preventing invalid data.

**Silent failure prevention:** Form validation + database CHECK constraint = double defense. Safe insert pattern avoids PGRST116 errors.

**Post-incident reconstruction:** All records have UUIDs and timestamps. Standard Supabase audit trail.

**Ownership:** Clean feature separation — all supplier files in `lib/features/suppliers/`. Product modifications limited to 3 existing files.

## 6. Final Release Bar

**What must be true before shipping:**
- Migration applies cleanly (suppliers table + cost_price column with CHECK)
- Supplier CRUD works for owner and admin
- cost_price saves and loads correctly on products
- flutter gen-l10n runs successfully after adding strings

**Remaining risks if shipped as-is (after fixes):**
- Low: Supplier deletion has no guard — acceptable since no FK references exist yet.

**Sign-off:** I would approve this plan for production after the applied fixes.

---

**Summary:** Applied 1 must-have + 1 strongly-recommended upgrade. Deferred 1 item.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
