# Dream Land Shopping (Tawzii)

<p align="center">
  <img src="app_icon.png" width="120" alt="Dream Land Shopping">
</p>

<p align="center">
  <strong>Real-time wholesale distribution management</strong><br>
  Orders, payments, packages, and driver tracking — replacing paper with digital accountability.
</p>

---

## About

A mobile-first Arabic (RTL) wholesale distribution management app for B2B food distribution businesses in Algeria. Drivers operate as mobile salespeople visiting stores on routes — taking orders, delivering products, collecting payments, tracking returnable packaging, and printing Bluetooth receipts. Everything syncs in real-time to the owner's dashboard.

**Scale:** <10 drivers, 10-20 stores, single business. Android only, distributed via APK sideload.

## Features

### Owner
- Real-time dashboard: revenue, orders, profit, cash flow
- Top debtors and outstanding credit balances
- Low stock alerts with configurable thresholds
- Discount approval queue (auto-reject after 3 min timeout)
- Live driver GPS tracking on OpenStreetMap
- Manual balance adjustments with audit trail
- User management (create/deactivate admins and drivers)

### Driver
- Fast order creation with product catalog and stock validation
- Bluetooth thermal receipt printing
- Payment collection with automatic credit balance tracking
- Returnable packaging tracking (per product, per store)
- Store creation in the field with map location picker
- Driver stock view: loaded, sold, remaining quantities
- Shift close with return receipt printing

### Admin
- Operational dashboard (revenue, orders, payments)
- Product catalog management
- Driver account management
- Load products onto drivers at start of day
- Add stock to active driver loads mid-shift

### Driver Stock Loading
- Admin/owner loads products onto drivers with atomic stock deduction
- Real-time driver stock tracking (loaded - sold - returned)
- Shift close flow with return quantity entry and receipt printing
- Orders automatically deduct from driver's loaded stock
- Load-aware product picker (only shows driver's loaded products)
- Load receipt + return receipt Bluetooth printing

### Push Notifications
- Real-time FCM push notifications to owner/admin phones
- 6 event triggers: new order, payment collected, discount request, low stock, shift opened/closed
- Notifications delivered even when app is closed (background handling)
- Per-user notification preferences (toggle which events to receive)
- Notification preferences screen in settings (owner/admin only)

### Procurement & Inventory
- Supplier management
- Purchase orders with cost tracking
- Automatic stock deduction on orders, replenishment from purchases
- Manual stock adjustments with movement history
- Profit margins (sell price vs cost price)

### Security
- Atomic order creation (5 DB operations in 1 PostgreSQL transaction)
- JWT metadata protection (role and business_id immutable via trigger)
- Role-based access control (RLS policies + RPC role checks)
- Idempotent order creation (prevents duplicates on network retry)
- Deactivation enforcement (instantly blocks all data access)
- Startup version check with blocking force-update screen
- Append-only audit tables (no UPDATE/DELETE on financial records)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) — Android |
| Backend | Supabase (PostgreSQL + Realtime + Auth + Edge Functions + RLS) |
| Notifications | Firebase Cloud Messaging (FCM v1 API) |
| Local DB | Drift (SQLite) |
| Maps | OpenStreetMap + flutter_map |
| Printing | Bluetooth thermal printer (ESC/POS) |
| State | Riverpod |

## Architecture

```
lib/
├── core/
│   ├── constants/          # App-wide constants
│   ├── l10n/               # Arabic localization
│   ├── theme/              # Material Design 3 (#F5A623 brand)
│   ├── sync/               # Sync queue manager
│   └── utils/              # Version utils, order calculator
├── features/
│   ├── auth/               # Login, init, settings, force-update
│   ├── orders/             # Order creation, list, receipt, models
│   ├── payments/           # Payment collection, history
│   ├── stores/             # Store CRUD, location picker
│   ├── products/           # Product catalog, stock adjustment
│   ├── driver/             # Driver shell, user management, GPS
│   ├── owner/              # Owner shell, dashboard
│   ├── admin/              # Admin shell
│   ├── dashboard/          # Consolidated dashboard RPC + providers
│   ├── printing/           # Bluetooth printer service
│   ├── packages/           # Returnable packaging tracking
│   ├── procurement/        # Suppliers, purchase orders
│   ├── driver_loads/       # Driver stock loading, shift close, receipts
│   └── discount/           # Discount approval flow
├── core/
│   └── notifications/      # FCM service, notification providers
├── routing/                # GoRouter with role-based routing
└── app.dart

supabase/migrations/        # 23 PostgreSQL migrations
supabase/functions/          # Edge Functions (send-notification)
docs/                       # Role-operation matrix
```

## Roles

| Role | Access |
|------|--------|
| **Owner** | Full visibility — dashboard, all orders, payments, GPS, discounts, users, stock, procurement |
| **Admin** | Operational — dashboard, products, payments, packages, driver management |
| **Driver** | Field — create orders, collect payments, log packages, GPS tracking |

See [`docs/ROLE-OPERATION-MATRIX.md`](docs/ROLE-OPERATION-MATRIX.md) for the complete access control matrix.

## Getting Started

### Prerequisites

- Flutter SDK (^3.11)
- Android SDK
- Supabase project (free tier sufficient)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Mohamed-Oday/Dream-Land-Wholesale-App.git
   cd Dream-Land-Wholesale-App
   ```

2. Create `.env` file with your Supabase credentials:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

3. Run all 23 migrations on your Supabase project (SQL Editor or `supabase db push`)

4. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

5. On first launch, the init screen creates the owner account

### Build Release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Testing

```bash
flutter test
```

40 unit tests covering:
- Financial calculations (line item pricing, subtotal, tax, discount)
- Version comparison (semver)
- User model (roles, routing, factory)

## Database

23 PostgreSQL migrations + 1 Edge Function:
- Core schema (users, stores, products, orders, payments, packages)
- Driver loads & shift management (driver_loads, driver_load_items)
- FCM token storage & notification preferences
- RPC functions (atomic orders, discount approval, stock management, dashboard, driver loads)
- Row-Level Security policies per role
- SECURITY DEFINER functions with role checks
- CHECK constraints, auto-updating timestamps, cancellation audit trail
- Edge Function: send-notification (FCM v1 API with OAuth2)

## Version History

| Version | Description |
|---------|-------------|
| **v0.3** | Driver stock loading, shift management, FCM push notifications with 6 event triggers and preferences |
| **v0.2.1** | AEGIS audit remediation — security hardening, atomic transactions, 40 tests, dashboard consolidation |
| **v0.2** | Business intelligence — admin expansion, procurement, stock & inventory |
| **v0.1** | Core loop — auth, orders, payments, packages, GPS, printing, hardening |

**Totals: 12 phases, 34 plans, 23 migrations, 1 Edge Function, 40 unit tests**

## License

Private — proprietary software for Dream Land Shopping wholesale distribution.

---

Built with [Claude Code](https://claude.com/claude-code)
