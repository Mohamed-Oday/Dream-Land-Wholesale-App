# Dreamland Wholesale App — Feature Specification

**Version:** 1.0
**Date:** 2026-07-22
**Features:** 3 core features for wholesale order management

---

## Feature 1: Sell Items in Pieces (Not Just Full Packages)

### Current Behavior
- Products have `units_per_package` (nullable)
- When creating orders, `LineItem.quantity` represents **packages**
- Line total = `unit_price * quantity` (where unit_price is already package price)
- No way to sell individual pieces from a package

### Required Changes

#### 1.1 Database — Products Table
Add new column to `Products` table (`lib/core/database/tables/products_table.dart`):
```dart
BoolColumn get sellByPiece => boolean().withDefault(const Constant(false))();
```
- When `sellByPiece = true`, the product can be sold asella UI should allow entering quantity in **pieces**
- `units_per_package` still defines how many pieces per package (for inventory tracking)

#### 1.2 Database — OrderLines Table
Add columns to track piece vs package:
```dart
BoolColumn get soldByPiece => boolean().withDefault(const Constant(false))();
IntColumn get piecesQuantity => integer().nullable()(); // actual pieces sold
```
- If `soldByPiece = true`: `piecesQuantity` stores pieces, `quantity` = 0 or packages equivalent
- If `soldByPiece = false`: `quantity` stores packages, `piecesQuantity` = null

#### 1.3 Model — LineItem (`lib/features/orders/models/line_item.dart`)
Add fields:
```dart
final bool soldByPiece;
final int? piecesQuantity;
```
Update calculations:
- If `soldByPiece`: `lineTotal = unitPrice * (piecesQuantity ?? 0) / (unitsPerPackage ?? 1)`
- If not: existing logic (`unitPrice * quantity`)

#### 1.4 UI — Create Order Screen (`lib/features/orders/screens/create_order_screen.dart`)
- When adding product with `sellByPiece = true`:
  - Show numeric keypad for **pieces** (not packages)
  - Display: "كمية (قطع)" instead of "كمية (عبوات)"
  - Validate against `stockOnHand` (which is in pieces)
- When adding product with `sellByPiece = false`:
  - Existing behavior (packages)

#### 1.5 UI — Product Form Sheet (`lib/features/products/screens/product_form_sheet.dart`)
Add toggle: "البيع بالقطعة" (Sell by piece)
- When enabled: user can sell individual pieces
- Requires `units_per_package` to be set

---

## Feature 2: Persist Draft Orders When Navigating Away

### Current Behavior
- `CreateOrderScreen` state (`_lineItems`, `_selectedStoreId`, `_selectedStoreName`, `_discount`, `_storeBalance`) is in memory only
- Navigating away (to products screen to check stock, etc.) loses all progress

### Required Changes

#### 2.1 Local Storage Keys
Use `SharedPreferences` with keys:
- `draft_order_line_items` — JSON list of LineItem data
- `draft_order_store_id` — String
- `draft_order_store_name` — String
- `draft_order_discount` — double
- `draft_order_store_balance` — double
- `draft_order_timestamp` — ISO8601 string (for expiry)

#### 2.2 Auto-Save
- Save on every state change: `_setQuantity`, `_pickStore`, `_editDiscount`, `_lineItems` changes
- Debounce: 500ms

#### 2.3 Auto-Restore on Init
- In `initState`: check for draft, if exists and < 24h old → show restore dialog
- Dialog: "يوجد طلب غير مكتمل. استعادته؟" (There's an incomplete order. Restore?)
- If yes: populate all state from SharedPreferences
- If no: clear draft

#### 2.4 Clear Draft on Submit
- When order successfully submitted → clear all draft keys

#### 2.5 Clear Draft on Explicit Discard
- Add "إلغاء الطلب" (Discard Order) button in app bar / floating action
- Shows confirmation dialog, clears draft on confirm

---

## Feature 3: Mark Order as Paid Directly

### Current Behavior
- Payments recorded in separate `Payments` table (amount, method, balances)
- Orders have `status` = 'created' | 'delivered' | 'cancelled'
- No direct "paid" status on order itself
- To record payment: go to store → add payment → enters amount

### Required Changes

#### 3.1 Database — Orders Table
Add to `Orders` table (`lib/core/database/tables/orders_table.dart`):
```dart
TextColumn get paymentStatus => text().withDefault(const Constant('unpaid'))(); // 'unpaid' | 'partial' | 'paid'
RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
DateTimeColumn get paidAt => dateTime().nullable()();
```

#### 3.2 Database — Payments Table (Optional Enhancement)
Add `orderId` to link payments to orders:
```dart
TextColumn get orderId => text().nullable()();
```

#### 3.3 Repository — OrderRepository
Add methods:
```dart
Future<void> updatePaymentStatus(String orderId, String status, {double? paidAmount});
Future<List<Map<String, dynamic>>> getOrdersWithPaymentStatus({String? storeId, String? paymentStatus});
```

#### 3.4 UI — Order List Screen (`lib/features/orders/screens/order_list_screen.dart`)
- Add filter chip: "الحالة: غير مدفوع / مدفوع جزئياً / مدفوع"
- Show payment status badge on each order row:
  - 🔴 Unpaid (red)
  - 🟡 Partial (amber)
  - 🟢 Paid (green)
- Add "Mark Paid" action on order row (swipe or trailing icon)
- On "Mark Paid": show keypad for amount (default = remaining balance), confirm → update order + create payment record

#### 3.5 UI — Order Detail (if exists) or Order List Row
- Show `paidAmount / total` 
- "Mark Paid" button → opens amount entry → creates Payment record + updates Order

#### 3.6 Payment Creation Flow
When marking order as paid:
1. Calculate remaining = `order.total - order.paidAmount`
2. Show keypad with remaining as default
3. On confirm:
   - Insert into `Payments` table (amount, method='cash', storeId, driverId, orderId)
   - Update `Orders`: `paidAmount += amount`, `paymentStatus` = 'paid' if fully paid else 'partial', `paidAt` = now if fully paid
   - Update store credit balance (existing logic)

---

## Implementation Order

1. **Database Migrations** — Products (sellByPiece), OrderLines (soldByPiece, piecesQuantity), Orders (paymentStatus, paidAmount, paidAt)
2. **Feature 1** — Sell by piece (model, UI, product form)
3. **Feature 2** — Draft order persistence (SharedPreferences, auto-save/restore)
4. **Feature 3** — Payment status on orders (DB, repo, order list UI, mark-paid flow)
5. **Testing** — Unit + integration tests for all three

---

## Acceptance Criteria

### Feature 1
- [ ] Product form has "Sell by piece" toggle
- [ ] When enabled, create order shows pieces input
- [ ] Piece quantity validated against stock_on_hand
- [ ] Line total calculates correctly (piece price = unit_price / units_per_package)
- [ ] OrderLines stores soldByPiece + piecesQuantity

### Feature 2
- [ ] Navigate away from create order → come back → draft restored
- [ ] Draft expires after 24 hours
- [ ] Explicit discard clears draft
- [ ] Successful submit clears draft

### Feature 3
- [ ] Order list shows payment status badge
- [ ] Filter by payment status works
- [ ] "Mark Paid" creates payment record + updates order
- [ ] Partial payment supported (shows as 'partial')
- [ ] Store balance updated correctly