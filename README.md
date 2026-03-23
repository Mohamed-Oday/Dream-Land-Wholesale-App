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

### Admin
- Operational dashboard (revenue, orders, payments)
- Product catalog management
- Driver account management

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
| Backend | Supabase (PostgreSQL + Realtime + Auth + RLS) |
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
│   └── discount/           # Discount approval flow
├── routing/                # GoRouter with role-based routing
└── app.dart

supabase/migrations/        # 19 PostgreSQL migrations
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

3. Run all 19 migrations on your Supabase project (SQL Editor or `supabase db push`)

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

19 PostgreSQL migrations:
- Core schema (users, stores, products, orders, payments, packages)
- RPC functions (atomic orders, discount approval, stock management, dashboard)
- Row-Level Security policies per role
- SECURITY DEFINER functions with role checks
- CHECK constraints, auto-updating timestamps, cancellation audit trail

## Version History

| Version | Description |
|---------|-------------|
| **v0.2.1** | AEGIS audit remediation — security hardening, atomic transactions, 40 tests, dashboard consolidation |
| **v0.2** | Business intelligence — admin expansion, procurement, stock & inventory |
| **v0.1** | Core loop — auth, orders, payments, packages, GPS, printing, hardening |

**Totals: 10 phases, 28 plans, 19 migrations, 40 unit tests**

## License

Private — proprietary software for Dream Land Shopping wholesale distribution.

---

Built with [Claude Code](https://claude.com/claude-code)
