# Milestones

Completed milestone log for this project.

| Milestone | Completed | Duration | Stats |
|-----------|-----------|----------|-------|
| v0.1 Initial Release | 2026-03-22 | ~1 day | 4 phases, 16 plans |
| v0.2 Business Intelligence & Procurement | 2026-03-22 | ~1 day | 3 phases, 7 plans |
| v0.2.1 AEGIS Audit Remediation | 2026-03-23 | ~1 day | 3 phases, 6 plans |
| v0.3 Driver Stock Loading & Notifications | 2026-03-24 | ~2 days | 2 phases, 4 plans |

---

## v0.3 Driver Stock Loading & Notifications

**Completed:** 2026-03-24
**Duration:** ~2 days (Phases 11-12)

### Stats

| Metric | Value |
|--------|-------|
| Phases | 2 |
| Plans | 4 |
| Files created | 16 |
| Files modified | 21 |

### Key Accomplishments

- Driver load system: admin/owner loads products onto drivers at start of day with atomic stock deduction
- Shift close flow: driver enters remaining quantities, prints return receipt, stock restored to warehouse
- Order integration: orders automatically deduct from driver's loaded stock, load-aware product picker
- Add-to-load: admin/owner can top up a driver's active load mid-shift
- Driver stock tab: real-time view of loaded/sold/remaining quantities
- FCM push notifications via Supabase Edge Function with OAuth2 token generation
- 6 notification triggers: new order, payment collected, discount pending, low stock, shift opened/closed
- Per-user notification preferences with SQL-level filtering and settings UI
- FCM token lifecycle: auto-register on login, auto-delete on logout, refresh handling
- Foreground + background notification display with flutter_local_notifications

### Key Decisions

| Decision | Rationale | Phase |
|----------|-----------|-------|
| Edge Function over pg_net for FCM | FCM v1 requires OAuth2 JWT signing, impractical in SQL | 12-01 |
| Client-triggered notifications | All events originate from user actions at current scale | 12-01 |
| Best-effort notification pattern | Notification failures must never degrade core operations | 12-01 |
| COALESCE on active metadata field | NULL active was excluding all users from delivery | 12-02 |
| --no-verify-jwt on Edge Function | Built-in JWT verification rejected valid tokens | 12-02 |
| FOR UPDATE row lock on driver_loads | Prevents double-close race condition | 11-01 |

---

## v0.2.1 AEGIS Audit Remediation

**Completed:** 2026-03-23
**Duration:** ~1 day (Phases 8-10)

### Stats

| Metric | Value |
|--------|-------|
| Phases | 3 |
| Plans | 6 |

### Key Accomplishments

- Day-1 fixes: version constant, l10n corrections, anon REVOKE on 7 RPCs, column fix
- JWT user_metadata lockdown via trigger (prevents role escalation)
- Atomic order creation RPC (consolidated 5 separate calls into 1 transaction)
- Role checks added to all SECURITY DEFINER functions
- Deactivation enforcement with blocking dialog
- Startup version check with force-update blocking
- Minimum test suite (financial calculations + SQL RPC tests)
- CHECK constraints on stock_on_hand, updated_at triggers, cancellation audit trail
- Dashboard consolidated from 8 calls to 1 RPC
- Role-operation matrix documented

---

## v0.2 Business Intelligence & Procurement

**Completed:** 2026-03-22
**Duration:** ~2.5 hours (145 min across 7 plans)

### Stats

| Metric | Value |
|--------|-------|
| Phases | 3 |
| Plans | 7 |
| Files created | 13 |
| Files modified | 20 |
| Total files | 33 |

### Key Accomplishments

- Admin dashboard-lite with 3 sections (orders, debtors, packages) + 5-tab shell expansion
- Store location picker on OpenStreetMap with GPS auto-center for field store creation
- Supplier management (CRUD) + product cost_price column for procurement tracking
- Purchase order system (create, list, detail) with package-level pricing
- Owner dashboard expanded to 4 KPI cards (revenue, orders, purchases, profit with green/red)
- Product margin percentage badges on product list (color-coded)
- Stock tracking: stock_on_hand per product with automatic deduction on orders
- Stock replenishment from purchase orders + restoration on order cancellation
- Stock enforcement on order creation (out-of-stock disabled, quantity capped)
- Low stock alerts on dashboard with configurable thresholds
- Stock adjustment screen with projected result validation
- Stock movement history per product (4 movement types with distinct icons)

### Key Decisions

| Decision | Rationale | Phase |
|----------|-----------|-------|
| Dart-side column filtering for low stock | PostgREST can't compare columns | 07-02 |
| Stock enforcement at UI level, not DB CHECK | Owner may oversell intentionally | 07-01 |
| Denormalized stock_on_hand + stock_movements audit trail | Fast reads from column, reconstructibility from movements | 07-01 |
| RPC idempotency guards on all stock functions | Prevents double-deduction on network retry | 07-01 |
| Package-level pricing on purchase orders | User-requested during 06-02 checkpoint | 06-02 |

---

## v0.1 Initial Release

**Completed:** 2026-03-22
**Duration:** ~1 day

### Stats

| Metric | Value |
|--------|-------|
| Phases | 4 |
| Plans | 16 |

### Key Accomplishments

- Flutter scaffold with Supabase + Drift + Riverpod foundation
- Auth system with role-based routing (owner/admin/driver)
- Product & store CRUD with Arabic RTL support
- Order creation with receipt preview and Bluetooth printing
- Payment collection with credit balance tracking
- Per-product returnable package tracking
- Owner dashboard with KPIs, live driver map (OpenStreetMap)
- Discount approval flow with 3-min auto-reject
- Date range filters, driver performance views
- In-app update check, offline hardening, printer recovery

---
