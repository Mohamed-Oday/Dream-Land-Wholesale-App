# Enterprise Plan Audit Report

**Plan:** .paul/phases/10-structural-improvements/10-02-PLAN.md
**Audited:** 2026-03-23
**Verdict:** Enterprise-ready (after applied upgrades)

---

## 1. Executive Verdict

**Conditionally acceptable**, upgraded to enterprise-ready. The dashboard consolidation architecture is correct — 5 queries to 1 RPC is the right optimization for mobile networks. The critical gap was NULL handling: SQL aggregate functions return NULL on empty sets, which would crash the Dart runtime. COALESCE fixes this at the source. The role-operation matrix is a valuable compliance artifact.

## 2. What Is Solid

1. **Single-RPC consolidation** — Correct approach. 5 round trips → 1 on every dashboard load.
2. **SQL-side timezone** — `AT TIME ZONE 'Africa/Algiers'` is authoritative. Better than Dart-side UTC+1 offset which would break if Algeria ever changes timezone rules.
3. **Derived providers pattern** — Individual providers reading from a single summary provider is clean Riverpod composition. No wasted fetches.
4. **Deprecate don't delete** — Keeping existing methods ensures backward compatibility.
5. **Scope exclusions** — Not consolidating recent_orders, package_alerts, pending_discounts is correct — they have different lifecycle, join complexity, and refresh patterns.

## 3. Enterprise Gaps Identified

### Gap A: NULL aggregates crash Dart runtime (MUST-HAVE)
`SUM()` returns NULL on empty sets. `jsonb_agg()` returns NULL on empty subqueries. Without COALESCE, the JSONB response will contain `"today_revenue": null` and `"top_debtors": null`. Dart's `as double` and `as List` casts will throw TypeError at runtime. This is not a theoretical concern — it will crash on day 1 before any payments are recorded.

### Gap B: Dart type-safety on RPC response parsing (STRONGLY RECOMMENDED)
The RPC returns JSONB which Supabase deserializes to Dart's `Map<String, dynamic>`. The plan didn't specify how derived providers should safely extract values. `summary['today_revenue'] as double` will crash if Supabase returns an int (e.g., 0 instead of 0.0). Defensive casting with `as num?` → `.toDouble()` prevents this.

## 4. Upgrades Applied to Plan

### Must-Have (Release-Blocking)

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | NULL aggregates crash Dart | Task 1 action (SQL body) | Added COALESCE on SUM() for revenue/purchases, COALESCE on jsonb_agg() for arrays |

### Strongly Recommended

| # | Finding | Plan Section Modified | Change Applied |
|---|---------|----------------------|----------------|
| 1 | Dart type-safety on RPC response | Task 2 action (provider refactor) | Added defensive casting pattern: `(x as num?)?.toDouble() ?? 0.0` for doubles, `List.from(x as List? ?? [])` for arrays |

### Deferred (Can Safely Defer)

None.

## 5. Audit & Compliance Readiness

**Performance:** Single RPC eliminates 4 unnecessary round trips per dashboard load. On mobile networks with 200-500ms latency per call, this saves 0.8-2.0 seconds of perceived load time.

**Audit evidence:** The role-operation matrix creates a compliance-ready document mapping every operation to permitted roles with source references. This is a standard SOC 2 / access control documentation artifact.

**Null safety:** COALESCE at the SQL level is defense-in-depth. The Dart-side defensive casting is a second layer. Neither alone is sufficient; together they guarantee no null-related crashes regardless of data state.

## 6. Final Release Bar

**What must be true before this plan ships:**
- Dashboard RPC returns non-null values for all fields (COALESCE)
- Dart providers safely extract values without runtime type errors
- All existing dashboard metrics display correctly
- Role-operation matrix covers all 3 roles and all features

**Remaining risks if shipped as-is (after upgrades):**
- Migrations 015-019 all need deployment to live Supabase
- No automated tests for dashboard providers (acceptable — pure data pass-through)

**Sign-off:** After COALESCE and type-safety upgrades, this plan is approved.

---

**Summary:** Applied 1 must-have + 1 strongly-recommended upgrade. Deferred 0 items.
**Plan status:** Updated and ready for APPLY

---
*Audit performed by PAUL Enterprise Audit Workflow*
*Audit template version: 1.0*
