-- Migration 026: Add missing piece-sale + payment columns
-- Created: 2026-07-23
--
-- ROOT CAUSE
-- Migration 025 added the piece-sale/payment RPCs (create_order_atomic,
-- update_order_payment_status) and the Flutter app + Drift schema were updated,
-- but NO migration ever ran ALTER TABLE ... ADD COLUMN for the columns those RPCs
-- and the app read/write. The remote schema was therefore missing all of them.
--
-- Symptom: PostgrestException PGRST204
--   "Could not find the 'sell_by_piece' column of 'products' in the schema cache"
-- when saving a product with the البيع بالقطعة (sell-by-piece) toggle enabled.
-- The same failure was latent for: creating an order with piece lines
-- (order_lines.sold_by_piece / pieces_quantity) and for "Mark Paid"
-- (orders.payment_status / paid_amount / paid_at, payments.order_id).
--
-- All statements are idempotent (ADD COLUMN IF NOT EXISTS), safe to re-run.

-- products: capability flag — this product MAY be sold as individual pieces
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS sell_by_piece BOOLEAN NOT NULL DEFAULT FALSE;

-- order_lines: per-line record that a line WAS sold by piece, and how many pieces
ALTER TABLE order_lines
  ADD COLUMN IF NOT EXISTS sold_by_piece   BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE order_lines
  ADD COLUMN IF NOT EXISTS pieces_quantity INTEGER;          -- null for package sales

-- orders: payment tracking
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS payment_status TEXT    NOT NULL DEFAULT 'unpaid';
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS paid_amount    NUMERIC NOT NULL DEFAULT 0;
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS paid_at        TIMESTAMPTZ;       -- set when fully paid

-- payments: link each payment to the order it settles
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES orders(id);

-- Enforce the payment_status domain that the app and update_order_payment_status assume
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE orders ADD  CONSTRAINT orders_payment_status_check
  CHECK (payment_status IN ('unpaid', 'partial', 'paid'));

-- Helpful index for looking up payments by order
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);

-- order_lines.quantity was CHECK (quantity > 0). A piece-only line stores
-- quantity = 0 (the count lives in pieces_quantity), so relax the constraint to
-- allow 0 packages as long as the line has SOME quantity (packages or pieces).
-- (Verify the constraint name first if this errors:
--   SELECT conname FROM pg_constraint
--   WHERE conrelid = 'order_lines'::regclass AND contype = 'c';)
ALTER TABLE order_lines DROP CONSTRAINT IF EXISTS order_lines_quantity_check;
ALTER TABLE order_lines ADD  CONSTRAINT order_lines_quantity_check
  CHECK (quantity >= 0 AND (quantity > 0 OR COALESCE(pieces_quantity, 0) > 0));
