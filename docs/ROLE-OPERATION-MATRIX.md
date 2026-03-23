# Role-Operation Matrix — Tawzii

**Roles:** Owner, Admin, Driver
**Enforcement:** RLS policies (row-level security) + RPC role checks (SECURITY DEFINER functions)
**Last updated:** 2026-03-23 (v0.2.1)

---

## Orders

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT all business orders | Yes | Yes | Own only | RLS: orders_{role}_* |
| CREATE order (atomic RPC) | - | - | Yes | RPC: create_order_atomic (role='driver') |
| CANCEL order | Yes | Yes | Own only | RPC: cancel_order (role check) |
| View order lines | Yes | Yes | Own orders | RLS: order_lines_{role}_* |

## Payments

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT all business payments | Yes | Yes | Own only | RLS: payments_{role}_* |
| INSERT payment | - | - | Yes | RLS: payments_driver_insert |

## Stores

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT all business stores | Yes | Yes | Yes | RLS: stores_{role}_* |
| INSERT store | - | - | Yes | RLS: stores_driver_insert |
| UPDATE store | Yes | - | - | (via adjust_store_balance RPC) |

## Products

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT active products | Yes | Yes | Yes | RLS: products_{role}_* |
| INSERT product | Yes | Yes | - | RLS: products_owner/admin |
| UPDATE product | Yes | Yes | - | RLS: products_owner/admin |
| Deactivate product | Yes | Yes | - | ProductRepository.deactivate() |

## Stock

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| VIEW stock movements | Yes | Yes | Own business | RLS: stock_movements_{role}_* |
| ADJUST stock (manual) | Yes | Yes | - | RPC: adjust_stock (owner/admin) |
| DEDUCT stock (order) | - | - | Auto | RPC: create_order_atomic (inline) |
| RESTORE stock (cancel) | Yes | Yes | Own order | RPC: restore_stock_for_cancellation |
| REPLENISH stock (purchase) | Yes | Yes | - | RPC: replenish_stock_from_purchase |

## Users

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT all business users | Yes | - | - | RLS: users_owner_all |
| SELECT drivers only | - | Yes | - | RLS: users_admin_* |
| SELECT own profile | - | - | Yes | RLS: users_driver_self |
| CREATE user (driver/admin) | - | Yes | - | RLS: users_admin_insert + UserRepository |
| ACTIVATE/DEACTIVATE | Yes | Yes (drivers) | - | UserRepository + get_user_role() enforcement |

## Discounts

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| REQUEST discount | - | - | Yes (at order creation) | create_order_atomic: discount_status='pending' |
| APPROVE discount | Yes | - | - | RPC: approve_discount (owner only) |
| REJECT discount | Yes | - | - | RPC: reject_discount (owner only) |
| AUTO-REJECT expired | Yes | Yes | - | RPC: reject_expired_discounts (owner/admin) |

## Packages

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT package logs | Yes | Yes | Own business | RLS: package_logs_{role}_* |
| CREATE package log | - | - | Yes | RPC: create_package_log |
| VIEW package balances | Yes | Yes | Yes | RPC: get_package_balances_for_store |
| VIEW package alerts | Yes | Yes | - | RPC: get_package_alerts |

## Balance Adjustments (Audit Table)

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT adjustments | Yes | Yes | Yes (own business) | RLS: balance_adjustments_{role}_read |
| INSERT adjustment | Yes | - | - | RLS: balance_adjustments_owner_insert + RPC |
| UPDATE/DELETE | - | - | - | No policy = append-only |

## Dashboard

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| VIEW dashboard summary | Yes | Yes | - | RPC: get_dashboard_summary (owner/admin) |
| VIEW recent orders | Yes | Yes | - | DashboardRepository.getRecentOrders() |
| VIEW pending discounts | Yes | - | - | OrderRepository.getPendingDiscounts() |

## Location Tracking

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| SELECT driver locations | Yes | Yes | Own only | RLS: driver_locations_{role}_* |
| INSERT location | - | - | Yes | RLS: driver_locations_driver_insert |

## Authentication

| Operation | Owner | Admin | Driver | Source |
|-----------|:-----:|:-----:|:------:|--------|
| Sign in | Yes | Yes | Yes | Supabase Auth |
| Sign out | Yes | Yes | Yes | Supabase Auth |
| JWT metadata protection | N/A | N/A | N/A | Trigger: protect_user_metadata (migration 016) |
| Deactivation enforcement | N/A | N/A | N/A | get_user_role() returns NULL (migration 017) |

---

## Security Functions (SECURITY DEFINER)

All SECURITY DEFINER functions have explicit role checks (migration 016-019):

| Function | Permitted Roles | Migration |
|----------|----------------|-----------|
| create_order_atomic | driver | 017 |
| cancel_order | owner, admin, driver (own) | 016 + 018 |
| approve_discount | owner | 016 |
| reject_discount | owner | 016 |
| reject_expired_discounts | owner, admin | 016 |
| adjust_stock | owner, admin | 016 |
| adjust_store_balance | owner, admin | 016 |
| update_store_balance_on_order | authenticated (stopgap) | 016 |
| deduct_stock_for_order | authenticated | 013 |
| restore_stock_for_cancellation | authenticated | 013 |
| replenish_stock_from_purchase | authenticated | 013 |
| get_dashboard_summary | owner, admin | 019 |
| get_package_alerts | authenticated | 003 |

---
*Generated: 2026-03-23 — v0.2.1 AEGIS Audit Remediation*
