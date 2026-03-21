# Enterprise Plan Audit Report

**Plan:** .paul/phases/01-core-loop/01-01-PLAN.md
**Audited:** 2026-03-21
**Verdict:** Conditionally Acceptable (now upgraded to Enterprise-Ready after applying findings)

---

## 1. Executive Verdict

**Conditionally acceptable, upgraded to enterprise-ready after applying 4 must-have and 3 strongly-recommended fixes.**

The plan's architecture is sound: three-layer foundation (Flutter scaffold, Supabase schema, Drift local DB) is the correct approach for an offline-first mobile app. The separation of concerns is clean — scaffold only, no business logic leaking into foundation. Phase boundaries are well-defined.

However, the original plan had gaps in credential management, schema constraint rigor, and schema parity verification that would have created maintenance debt and security exposure. These have been addressed.

If I were accountable for this system in production: yes, I would approve it — after the applied fixes.

## 2. What Is Solid

- **Three-task decomposition:** Flutter scaffold, Supabase schema, Drift setup — each is independent enough to reason about, small enough to verify.
- **Explicit scope boundaries:** "SCAFFOLD only — no business logic" prevents scope creep. The plan knows what it is NOT.
- **RTL-first approach:** Building RTL from day one (not retrofitting) is correct. Many apps fail here by adding RTL as an afterthought.
- **business_id on all tables from day one:** Zero-cost multi-tenancy foundation. Smart architectural decision preserved in the schema.
- **Sync queue design:** The sync_queue_table schema (operation, record_id, payload, retry_count, error_message) is production-grade. Retry limits prevent infinite loops. Error messages enable debugging.
- **Human verification checkpoint:** Requiring visual RTL verification before proceeding is appropriate — automated tests cannot catch all RTL layout issues.
- **Explicit state management decision:** Choosing Riverpod here (not deferring) prevents a decision bottleneck in Plan 01-02.

## 3. Enterprise Gaps Identified

### Gap 1: Supabase Credentials Hardcoded (CRITICAL)
The plan says "Create main.dart that initializes Supabase" but does not specify where the Supabase URL and anon key come from. Default Flutter + Supabase tutorials hardcode these in source code. For any system handling financial data (payments, balances), credentials must not be in version-controlled files.

### Gap 2: Schema Constraint Weakness
The SQL schema specifies column types and foreign keys but omits critical business-logic constraints:
- No CHECK on unit_price > 0 (allows zero or negative prices)
- No CHECK on payment amount > 0 (allows zero payments)
- No CHECK on order_lines quantity > 0
- No explicit ON DELETE behavior for foreign keys (PostgreSQL defaults to NO ACTION, which may orphan records or block deletions unpredictably)

### Gap 3: Username Uniqueness Scope
The plan says `username (text, unique)` but this is a globally unique constraint. With business_id for multi-tenancy, usernames should be unique *per business*, not globally. A global unique constraint would prevent two businesses from having a driver named "ahmed".

### Gap 4: Drift-Supabase Schema Parity
The plan creates both Supabase SQL tables and Drift Dart tables but has no verification step to ensure they match. Schema drift between local and remote databases is the #1 cause of sync failures in offline-first apps.

### Gap 5: .gitignore for Credentials
No mention of .gitignore setup. The .env file containing Supabase credentials could be accidentally committed.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Supabase credentials hardcoded risk | Task 1 action (step 5), AC-5 added, verification section | Added: load credentials from env config, create .env.example, never hardcode in source |
| 2 | Missing CHECK constraints on business fields | Task 2 action (steps 5-6), Task 2 verify | Added: CHECK constraints for unit_price, quantity, amount, given/collected |
| 3 | Username uniqueness scoped wrong | Task 2 action (step 7), users table definition | Changed: unique(username) → unique(business_id, username) |
| 4 | No .gitignore for .env | files_modified, boundaries, verification | Added: .gitignore with .env exclusion |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Missing ON DELETE behavior on FKs | Task 2 action (step 8) | Added: CASCADE for order_lines, RESTRICT for all others |
| 2 | No Drift-Supabase schema parity check | Task 3 action (step 8), AC-6 added, verification | Added: explicit parity verification step with documentation |
| 3 | files_modified missing .env.example and .gitignore | Frontmatter | Added: .env.example and .gitignore to files_modified list |

### Deferred (Can Safely Defer)

| # | Finding | Rationale for Deferral |
|---|---------|----------------------|
| 1 | No database migration versioning strategy for Drift | This is a greenfield app with version 1 schema. Migration versioning becomes important at version 2+. Can be added when the first schema change is needed. |
| 2 | No automated schema parity test | Manual parity check is sufficient for 9 tables. Automated test worthwhile when schema changes frequently (Phase 2+). |
| 3 | No Supabase project creation instructions | The plan correctly focuses on migration SQL. Supabase project creation is a one-time manual step that doesn't need to be in the plan. |

## 5. Audit & Compliance Readiness

**Audit evidence:** The plan produces reviewable SQL migration files and typed Dart table definitions. Both are inspectable artifacts. The sync queue's error_message and retry_count fields support post-incident reconstruction.

**Silent failure prevention:** The verification checklist requires flutter analyze, build success, and build_runner completion — three independent gates that catch different failure classes. The human verification checkpoint catches RTL issues that automation misses.

**Ownership and accountability:** Each task has a single owner (Claude during APPLY) with explicit verify and done criteria. No ambiguous handoffs.

**Remaining weakness:** RLS policies are defined in SQL but cannot be tested without a live Supabase project. This is acceptable for a foundation plan — RLS testing happens in Plan 01-02 (auth integration).

## 6. Final Release Bar

**What must be true before this plan ships:**
- All 6 acceptance criteria pass (including audit-added AC-5 and AC-6)
- No credentials in version-controlled files
- Schema constraints protect against invalid business data
- Drift and Supabase schemas are verified as matching

**Remaining risks if shipped as-is (after fixes):**
- RLS policies are untested until auth is implemented (Plan 01-02) — acceptable for foundation
- Sync queue is infrastructure only; actual sync correctness depends on Plan 01-02+ implementation
- Supabase free tier limits are not enforced by the schema — monitoring is a Phase 4 concern

**Sign-off:** I would sign my name to this plan as the foundation layer of a production system. The applied fixes address all critical gaps. The deferred items are genuinely deferrable.

---

**Summary:** Applied 4 must-have + 3 strongly-recommended upgrades. Deferred 3 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
