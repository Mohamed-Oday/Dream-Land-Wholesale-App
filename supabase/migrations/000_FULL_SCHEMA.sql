-- Dream Land Shopping (Tawzii) — Initial Schema
-- All tables include business_id for future multi-tenancy

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  name TEXT NOT NULL,
  username TEXT NOT NULL,
  password_hash TEXT NOT NULL DEFAULT '',  -- Unused: passwords managed by Supabase Auth
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'driver')),
  created_by UUID REFERENCES users(id) ON DELETE RESTRICT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, username)
);

CREATE TABLE IF NOT EXISTS stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  name TEXT NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  contact_person TEXT NOT NULL DEFAULT '',
  gps_lat DOUBLE PRECISION,
  gps_lng DOUBLE PRECISION,
  credit_balance NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  name TEXT NOT NULL,
  unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
  units_per_package INTEGER,
  category_id UUID,
  has_returnable_packaging BOOLEAN NOT NULL DEFAULT false,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  tax_percentage NUMERIC NOT NULL DEFAULT 0,
  tax_amount NUMERIC NOT NULL DEFAULT 0,
  discount NUMERIC NOT NULL DEFAULT 0,
  discount_status TEXT NOT NULL DEFAULT 'none' CHECK (discount_status IN ('none', 'pending', 'approved', 'rejected')),
  discount_approved_by UUID REFERENCES users(id) ON DELETE RESTRICT,
  total NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
  packages_count INTEGER,
  line_total NUMERIC NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  method TEXT NOT NULL DEFAULT 'cash',
  previous_balance NUMERIC NOT NULL,
  new_balance NUMERIC NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS package_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  order_id UUID REFERENCES orders(id) ON DELETE RESTRICT,
  given INTEGER NOT NULL DEFAULT 0 CHECK (given >= 0),
  collected INTEGER NOT NULL DEFAULT 0 CHECK (collected >= 0),
  balance_after INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS driver_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  business_id UUID NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, key)
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_users_business_id ON users(business_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_stores_business_id ON stores(business_id);
CREATE INDEX idx_products_business_id ON products(business_id);
CREATE INDEX idx_orders_business_id ON orders(business_id);
CREATE INDEX idx_orders_store_id ON orders(store_id);
CREATE INDEX idx_orders_driver_id ON orders(driver_id);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_order_lines_order_id ON order_lines(order_id);
CREATE INDEX idx_payments_business_id ON payments(business_id);
CREATE INDEX idx_payments_store_id ON payments(store_id);
CREATE INDEX idx_payments_driver_id ON payments(driver_id);
CREATE INDEX idx_payments_created_at ON payments(created_at);
CREATE INDEX idx_package_logs_business_id ON package_logs(business_id);
CREATE INDEX idx_package_logs_store_id ON package_logs(store_id);
CREATE INDEX idx_package_logs_product_id ON package_logs(product_id);
CREATE INDEX idx_driver_locations_driver_id ON driver_locations(driver_id);
CREATE INDEX idx_driver_locations_timestamp ON driver_locations(timestamp);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_app_config_updated_at
  BEFORE UPDATE ON app_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's role (from user_metadata in JWT)
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
BEGIN
  RETURN (auth.jwt() -> 'user_metadata' ->> 'role');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's business_id (from user_metadata in JWT)
CREATE OR REPLACE FUNCTION get_user_business_id()
RETURNS UUID AS $$
BEGIN
  RETURN ((auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---- USERS ----

-- Owner: full access within business
CREATE POLICY users_owner_all ON users
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

-- Admin: read all users in business, manage drivers
CREATE POLICY users_admin_select ON users
  FOR SELECT
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

CREATE POLICY users_admin_insert ON users
  FOR INSERT
  WITH CHECK (get_user_role() = 'admin' AND business_id = get_user_business_id() AND role = 'driver');

CREATE POLICY users_admin_update ON users
  FOR UPDATE
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id() AND role = 'driver');

-- Driver: read own record only
CREATE POLICY users_driver_select ON users
  FOR SELECT
  USING (get_user_role() = 'driver' AND id = auth.uid());

-- ---- STORES ----

CREATE POLICY stores_owner_all ON stores
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY stores_admin_all ON stores
  FOR ALL
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

CREATE POLICY stores_driver_select ON stores
  FOR SELECT
  USING (get_user_role() = 'driver' AND business_id = get_user_business_id());

CREATE POLICY stores_driver_insert ON stores
  FOR INSERT
  WITH CHECK (get_user_role() = 'driver' AND business_id = get_user_business_id());

-- ---- PRODUCTS ----

CREATE POLICY products_owner_all ON products
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY products_admin_all ON products
  FOR ALL
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

CREATE POLICY products_driver_select ON products
  FOR SELECT
  USING (get_user_role() = 'driver' AND business_id = get_user_business_id());

-- ---- ORDERS ----

CREATE POLICY orders_owner_all ON orders
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY orders_admin_select ON orders
  FOR SELECT
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

CREATE POLICY orders_driver_select ON orders
  FOR SELECT
  USING (get_user_role() = 'driver' AND driver_id = auth.uid());

CREATE POLICY orders_driver_insert ON orders
  FOR INSERT
  WITH CHECK (get_user_role() = 'driver' AND driver_id = auth.uid() AND business_id = get_user_business_id());

CREATE POLICY orders_driver_update ON orders
  FOR UPDATE
  USING (get_user_role() = 'driver' AND driver_id = auth.uid());

-- ---- ORDER LINES ----

CREATE POLICY order_lines_owner_all ON order_lines
  FOR ALL
  USING (EXISTS (SELECT 1 FROM orders WHERE orders.id = order_lines.order_id AND orders.business_id = get_user_business_id() AND get_user_role() = 'owner'));

CREATE POLICY order_lines_admin_select ON order_lines
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders WHERE orders.id = order_lines.order_id AND orders.business_id = get_user_business_id() AND get_user_role() = 'admin'));

CREATE POLICY order_lines_driver_select ON order_lines
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM orders WHERE orders.id = order_lines.order_id AND orders.driver_id = auth.uid() AND get_user_role() = 'driver'));

CREATE POLICY order_lines_driver_insert ON order_lines
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM orders WHERE orders.id = order_lines.order_id AND orders.driver_id = auth.uid() AND get_user_role() = 'driver'));

-- ---- PAYMENTS ----

CREATE POLICY payments_owner_all ON payments
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY payments_admin_select ON payments
  FOR SELECT
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

CREATE POLICY payments_driver_select ON payments
  FOR SELECT
  USING (get_user_role() = 'driver' AND driver_id = auth.uid());

CREATE POLICY payments_driver_insert ON payments
  FOR INSERT
  WITH CHECK (get_user_role() = 'driver' AND driver_id = auth.uid() AND business_id = get_user_business_id());

-- ---- PACKAGE LOGS ----

CREATE POLICY package_logs_owner_all ON package_logs
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY package_logs_admin_select ON package_logs
  FOR SELECT
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

CREATE POLICY package_logs_driver_select ON package_logs
  FOR SELECT
  USING (get_user_role() = 'driver' AND driver_id = auth.uid());

CREATE POLICY package_logs_driver_insert ON package_logs
  FOR INSERT
  WITH CHECK (get_user_role() = 'driver' AND driver_id = auth.uid() AND business_id = get_user_business_id());

-- ---- DRIVER LOCATIONS ----

CREATE POLICY driver_locations_owner_select ON driver_locations
  FOR SELECT
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY driver_locations_driver_insert ON driver_locations
  FOR INSERT
  WITH CHECK (get_user_role() = 'driver' AND driver_id = auth.uid() AND business_id = get_user_business_id());

CREATE POLICY driver_locations_driver_select ON driver_locations
  FOR SELECT
  USING (get_user_role() = 'driver' AND driver_id = auth.uid());

-- ---- APP CONFIG ----

CREATE POLICY app_config_owner_all ON app_config
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY app_config_read_all ON app_config
  FOR SELECT
  USING (business_id = get_user_business_id());
-- Phase 2: RPC functions
-- SECURITY DEFINER bypasses RLS where needed

-- ============================================================
-- has_users: Check if any users exist (bypasses RLS for init screen)
-- ============================================================
CREATE OR REPLACE FUNCTION has_users() RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM users LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Payment RPC functions for atomic balance updates

-- ============================================================
-- create_payment: Atomically records payment + updates store balance
-- ============================================================
CREATE OR REPLACE FUNCTION create_payment(
  p_store_id UUID,
  p_amount NUMERIC,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_previous NUMERIC;
  v_new NUMERIC;
  v_payment_id UUID;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Lock store row to prevent race conditions on concurrent payments
  SELECT credit_balance INTO v_previous
  FROM stores
  WHERE id = p_store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'store not found: %', p_store_id;
  END IF;

  v_new := v_previous - p_amount;

  -- Insert payment record
  INSERT INTO payments (business_id, store_id, driver_id, amount, method, previous_balance, new_balance)
  VALUES (p_business_id, p_store_id, auth.uid(), p_amount, 'cash', v_previous, v_new)
  RETURNING id INTO v_payment_id;

  -- Update store balance
  UPDATE stores SET credit_balance = v_new WHERE id = p_store_id;

  RETURN jsonb_build_object(
    'id', v_payment_id,
    'previous_balance', v_previous,
    'new_balance', v_new
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- update_store_balance_on_order: Increases store debt after order
-- ============================================================
CREATE OR REPLACE FUNCTION update_store_balance_on_order(
  p_store_id UUID,
  p_order_total NUMERIC
) RETURNS VOID AS $$
BEGIN
  -- Atomic UPDATE — credit_balance + p_order_total is inherently safe
  UPDATE stores
  SET credit_balance = credit_balance + p_order_total
  WHERE id = p_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Phase 2 Plan 02: Package tracking RPC functions

-- ============================================================
-- create_package_log: Atomically records package given/collected + updates balance
-- ============================================================
CREATE OR REPLACE FUNCTION create_package_log(
  p_store_id UUID,
  p_product_id UUID,
  p_business_id UUID,
  p_given INTEGER DEFAULT 0,
  p_collected INTEGER DEFAULT 0,
  p_order_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_previous INTEGER;
  v_balance INTEGER;
  v_log_id UUID;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get current balance with row lock to prevent race conditions
  SELECT balance_after INTO v_previous
  FROM package_logs
  WHERE store_id = p_store_id AND product_id = p_product_id
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    v_previous := 0;
  END IF;

  v_balance := v_previous + p_given - p_collected;

  -- Insert package log
  INSERT INTO package_logs (business_id, store_id, driver_id, product_id, order_id, given, collected, balance_after)
  VALUES (p_business_id, p_store_id, auth.uid(), p_product_id, p_order_id, p_given, p_collected, v_balance)
  RETURNING id INTO v_log_id;

  RETURN jsonb_build_object(
    'id', v_log_id,
    'previous_balance', v_previous,
    'balance_after', v_balance
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- get_package_balances_for_store: Current balance for all products at a store
-- ============================================================
CREATE OR REPLACE FUNCTION get_package_balances_for_store(
  p_store_id UUID
) RETURNS TABLE (product_id UUID, balance INTEGER) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (pl.product_id) pl.product_id, pl.balance_after AS balance
  FROM package_logs pl
  WHERE pl.store_id = p_store_id
  ORDER BY pl.product_id, pl.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_package_log(UUID, UUID, UUID, INTEGER, INTEGER, UUID) TO anon;
GRANT EXECUTE ON FUNCTION create_package_log(UUID, UUID, UUID, INTEGER, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_package_balances_for_store(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_package_balances_for_store(UUID) TO authenticated;
-- Phase 3 Plan 01: Dashboard RPC functions + performance index

-- ============================================================
-- Performance index for package alerts query
-- Enables efficient DISTINCT ON (store_id, product_id) lookups
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_package_logs_store_product_created
  ON package_logs(store_id, product_id, created_at DESC);

-- ============================================================
-- get_package_alerts: Returns stores with outstanding unreturned packages
-- Aggregates latest balance per (store_id, product_id), sums per store
-- ============================================================
CREATE OR REPLACE FUNCTION get_package_alerts(p_business_id UUID)
RETURNS TABLE (store_id UUID, store_name TEXT, total_outstanding BIGINT) AS $$
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  RETURN QUERY
  SELECT
    latest.store_id,
    s.name AS store_name,
    SUM(latest.balance_after)::BIGINT AS total_outstanding
  FROM (
    SELECT DISTINCT ON (pl.store_id, pl.product_id)
      pl.store_id,
      pl.product_id,
      pl.balance_after
    FROM package_logs pl
    WHERE pl.business_id = p_business_id
    ORDER BY pl.store_id, pl.product_id, pl.created_at DESC
  ) latest
  JOIN stores s ON s.id = latest.store_id
  GROUP BY latest.store_id, s.name
  HAVING SUM(latest.balance_after) > 0
  ORDER BY total_outstanding DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions (matches existing RPC pattern)
GRANT EXECUTE ON FUNCTION get_package_alerts(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_package_alerts(UUID) TO authenticated;
-- Phase 3 Plan 02: Location tracking RPC functions

-- ============================================================
-- get_latest_driver_locations: Returns latest position per active driver
-- Only includes locations from the last hour and active drivers
-- ============================================================
CREATE OR REPLACE FUNCTION get_latest_driver_locations(p_business_id UUID)
RETURNS TABLE (driver_id UUID, driver_name TEXT, lat DOUBLE PRECISION, lng DOUBLE PRECISION, "timestamp" TIMESTAMPTZ) AS $$
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (dl.driver_id)
    dl.driver_id,
    u.name AS driver_name,
    dl.lat,
    dl.lng,
    dl.timestamp
  FROM driver_locations dl
  JOIN users u ON u.id = dl.driver_id
  WHERE dl.business_id = p_business_id
    AND dl.timestamp > now() - interval '1 hour'
    AND u.active = true
  ORDER BY dl.driver_id, dl.timestamp DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions (matches existing RPC pattern)
GRANT EXECUTE ON FUNCTION get_latest_driver_locations(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_latest_driver_locations(UUID) TO authenticated;
-- Phase 3 Plan 03: Discount approval RPC functions

-- ============================================================
-- approve_discount: Approve a pending discount on an order
-- ============================================================
CREATE OR REPLACE FUNCTION approve_discount(
  p_order_id UUID,
  p_approved_by UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Verify order exists and is pending
  SELECT id, discount_status INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.discount_status != 'pending' THEN
    RAISE EXCEPTION 'discount_already_processed';
  END IF;

  -- Approve the discount
  UPDATE orders
  SET discount_status = 'approved',
      discount_approved_by = p_approved_by
  WHERE id = p_order_id;

  RETURN jsonb_build_object('status', 'approved', 'order_id', p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- reject_discount: Reject a pending discount, recalculate total, adjust store balance
-- ============================================================
CREATE OR REPLACE FUNCTION reject_discount(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_new_total NUMERIC;
BEGIN
  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get order details with lock
  SELECT id, discount, discount_status, subtotal, tax_amount, store_id
  INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.discount_status != 'pending' THEN
    RAISE EXCEPTION 'discount_already_processed';
  END IF;

  -- Recalculate total without discount
  v_new_total := v_order.subtotal + v_order.tax_amount;

  -- Update order: reject discount, fix total
  UPDATE orders
  SET discount_status = 'rejected',
      total = v_new_total
  WHERE id = p_order_id;

  -- Add discount amount back to store credit_balance (reverse the deduction)
  UPDATE stores
  SET credit_balance = credit_balance + v_order.discount
  WHERE id = v_order.store_id;

  RETURN jsonb_build_object(
    'status', 'rejected',
    'order_id', p_order_id,
    'new_total', v_new_total,
    'discount_reversed', v_order.discount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- reject_expired_discounts: Auto-reject all pending discounts older than 3 minutes
-- ============================================================
CREATE OR REPLACE FUNCTION reject_expired_discounts(
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_count INTEGER := 0;
  v_new_total NUMERIC;
BEGIN
  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Process each expired pending discount
  FOR v_order IN
    SELECT id, discount, subtotal, tax_amount, store_id
    FROM orders
    WHERE business_id = p_business_id
      AND discount_status = 'pending'
      AND created_at < now() - interval '3 minutes'
    FOR UPDATE
  LOOP
    v_new_total := v_order.subtotal + v_order.tax_amount;

    UPDATE orders
    SET discount_status = 'rejected',
        total = v_new_total
    WHERE id = v_order.id;

    UPDATE stores
    SET credit_balance = credit_balance + v_order.discount
    WHERE id = v_order.store_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('rejected_count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION approve_discount(UUID, UUID, UUID) TO anon;
GRANT EXECUTE ON FUNCTION approve_discount(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_discount(UUID, UUID) TO anon;
GRANT EXECUTE ON FUNCTION reject_discount(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_expired_discounts(UUID) TO anon;
GRANT EXECUTE ON FUNCTION reject_expired_discounts(UUID) TO authenticated;
-- Phase 4 Plan 01: Order cancellation RPC function

-- ============================================================
-- cancel_order: Cancel a 'created' order and reverse store balance
-- ============================================================
CREATE OR REPLACE FUNCTION cancel_order(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Fetch and lock the order
  SELECT id, status, discount_status, total, store_id
  INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.status != 'created' THEN
    RAISE EXCEPTION 'only_created_orders_can_be_cancelled';
  END IF;

  -- Update order status
  UPDATE orders SET status = 'cancelled'
    WHERE id = p_order_id;

  -- If discount was pending, neutralize it to prevent auto-reject from double-processing
  IF v_order.discount_status = 'pending' THEN
    UPDATE orders SET discount_status = 'none'
      WHERE id = p_order_id;
  END IF;

  -- Reverse store balance (subtract order total from credit_balance)
  UPDATE stores SET credit_balance = credit_balance - v_order.total
    WHERE id = v_order.store_id AND business_id = p_business_id;

  RETURN jsonb_build_object('status', 'cancelled', 'reversed_amount', v_order.total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION cancel_order(UUID, UUID) TO authenticated;
-- Phase 4 Plan 03: Balance adjustment table and RPC

-- ============================================================
-- balance_adjustments table: Audit log for manual balance changes
-- ============================================================
CREATE TABLE balance_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  store_id UUID NOT NULL REFERENCES stores(id),
  adjusted_by UUID NOT NULL,
  amount NUMERIC NOT NULL,
  reason TEXT NOT NULL,
  previous_balance NUMERIC NOT NULL,
  new_balance NUMERIC NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE balance_adjustments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own business adjustments"
  ON balance_adjustments FOR ALL
  USING (business_id = (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID);

-- ============================================================
-- adjust_store_balance: Adjust balance and log with audit trail
-- adjusted_by derived from auth.uid() (non-spoofable)
-- ============================================================
CREATE OR REPLACE FUNCTION adjust_store_balance(
  p_store_id UUID,
  p_business_id UUID,
  p_amount NUMERIC,
  p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
  v_store RECORD;
  v_new_balance NUMERIC;
  v_user_id UUID;
BEGIN
  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get authenticated user ID from JWT (non-spoofable)
  v_user_id := auth.uid();

  -- Reject zero adjustments
  IF p_amount = 0 THEN
    RAISE EXCEPTION 'amount_cannot_be_zero';
  END IF;

  -- Lock and read store
  SELECT id, credit_balance INTO v_store
  FROM stores
  WHERE id = p_store_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'store_not_found';
  END IF;

  v_new_balance := v_store.credit_balance + p_amount;

  -- Update store balance
  UPDATE stores SET credit_balance = v_new_balance
    WHERE id = p_store_id;

  -- Log the adjustment
  INSERT INTO balance_adjustments (business_id, store_id, adjusted_by, amount, reason, previous_balance, new_balance)
  VALUES (p_business_id, p_store_id, v_user_id, p_amount, p_reason, v_store.credit_balance, v_new_balance);

  RETURN jsonb_build_object(
    'previous_balance', v_store.credit_balance,
    'new_balance', v_new_balance,
    'amount', p_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION adjust_store_balance(UUID, UUID, NUMERIC, TEXT) TO authenticated;
-- Phase 4 Plan 04: Remote config table for in-app update check

CREATE TABLE remote_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Read-only for app users, writable only via service_role (Supabase dashboard)
ALTER TABLE remote_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read config" ON remote_config FOR SELECT USING (true);

-- Seed with initial values
INSERT INTO remote_config (key, value) VALUES
  ('latest_version', '0.1.0'),
  ('download_url', ''),
  ('min_version', '0.1.0');
-- Phase 4 Plan 05: DriverLocation 7-day retention cleanup

-- Cleanup function: delete driver_locations older than 7 days
-- Can be called manually or scheduled via pg_cron
CREATE OR REPLACE FUNCTION cleanup_old_driver_locations()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM driver_locations
  WHERE created_at < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION cleanup_old_driver_locations() TO authenticated;
-- Phase 6 Plan 01: Suppliers table + cost_price on products

-- Suppliers table
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  contact_person TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_suppliers_business_id ON suppliers(business_id);

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY suppliers_owner_all ON suppliers
  FOR ALL
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY suppliers_admin_all ON suppliers
  FOR ALL
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

CREATE POLICY suppliers_driver_select ON suppliers
  FOR SELECT
  USING (get_user_role() = 'driver' AND business_id = get_user_business_id());

-- Add cost_price to products (nullable — existing products don't have cost)
ALTER TABLE products ADD COLUMN IF NOT EXISTS cost_price NUMERIC CHECK (cost_price >= 0);
-- Phase 6 Plan 02: Purchase orders tables

CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  created_by UUID NOT NULL REFERENCES users(id),
  total_cost NUMERIC NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_purchase_orders_business_id ON purchase_orders(business_id);
CREATE INDEX idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
CREATE INDEX idx_purchase_orders_created_at ON purchase_orders(created_at);

ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY purchase_orders_owner_all ON purchase_orders
  FOR ALL USING (get_user_role() = 'owner' AND business_id = get_user_business_id());
CREATE POLICY purchase_orders_admin_all ON purchase_orders
  FOR ALL USING (get_user_role() = 'admin' AND business_id = get_user_business_id());
CREATE POLICY purchase_orders_driver_select ON purchase_orders
  FOR SELECT USING (get_user_role() = 'driver' AND business_id = get_user_business_id());

CREATE TABLE IF NOT EXISTS purchase_order_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_cost NUMERIC NOT NULL CHECK (unit_cost >= 0),
  line_total NUMERIC NOT NULL DEFAULT 0
);

CREATE INDEX idx_po_lines_purchase_order_id ON purchase_order_lines(purchase_order_id);

ALTER TABLE purchase_order_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY po_lines_owner_all ON purchase_order_lines
  FOR ALL USING (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_lines.purchase_order_id
      AND po.business_id = get_user_business_id()
      AND get_user_role() = 'owner'
  ));
CREATE POLICY po_lines_admin_all ON purchase_order_lines
  FOR ALL USING (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_lines.purchase_order_id
      AND po.business_id = get_user_business_id()
      AND get_user_role() = 'admin'
  ));
CREATE POLICY po_lines_driver_select ON purchase_order_lines
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM purchase_orders po
    WHERE po.id = purchase_order_lines.purchase_order_id
      AND po.business_id = get_user_business_id()
      AND get_user_role() = 'driver'
  ));
-- Phase 7 Plan 01: Stock & Inventory data model + RPC functions

-- ============================================================
-- 1. Add stock columns to products
-- ============================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_on_hand INTEGER NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS low_stock_threshold INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 2. Create stock_movements table
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  product_id UUID NOT NULL REFERENCES products(id),
  movement_type TEXT NOT NULL CHECK (movement_type IN ('order_out', 'purchase_in', 'cancellation_restore', 'adjustment')),
  quantity INTEGER NOT NULL,
  reference_id UUID,
  notes TEXT DEFAULT '',
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_movements_product_created ON stock_movements(product_id, created_at DESC);
CREATE INDEX idx_stock_movements_business_id ON stock_movements(business_id);
CREATE INDEX idx_stock_movements_reference ON stock_movements(reference_id, movement_type);

-- ============================================================
-- 3. RLS policies on stock_movements
-- ============================================================
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

-- Owner: full SELECT + INSERT within business_id
CREATE POLICY stock_movements_owner_all ON stock_movements
  FOR ALL USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

-- Admin: SELECT + INSERT within business_id
CREATE POLICY stock_movements_admin_select ON stock_movements
  FOR SELECT USING (get_user_role() = 'admin' AND business_id = get_user_business_id());
CREATE POLICY stock_movements_admin_insert ON stock_movements
  FOR INSERT WITH CHECK (get_user_role() = 'admin' AND business_id = get_user_business_id());

-- Driver: SELECT only within business_id (stock mutations via SECURITY DEFINER RPCs only)
CREATE POLICY stock_movements_driver_select ON stock_movements
  FOR SELECT USING (get_user_role() = 'driver' AND business_id = get_user_business_id());

-- ============================================================
-- 4. RPC: deduct_stock_for_order
-- ============================================================
CREATE OR REPLACE FUNCTION deduct_stock_for_order(p_order_id UUID)
RETURNS void AS $$
DECLARE
  v_business_id UUID;
  line RECORD;
BEGIN
  -- Auth check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- Get order business_id and verify ownership
  SELECT business_id INTO v_business_id
  FROM orders WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Idempotency guard: skip if already processed
  IF EXISTS (
    SELECT 1 FROM stock_movements
    WHERE reference_id = p_order_id AND movement_type = 'order_out'
  ) THEN
    RETURN;
  END IF;

  -- Deduct stock for each order line
  FOR line IN
    SELECT ol.product_id, ol.quantity, o.driver_id
    FROM order_lines ol
    JOIN orders o ON o.id = ol.order_id
    WHERE ol.order_id = p_order_id
  LOOP
    -- Update product stock
    UPDATE products
    SET stock_on_hand = stock_on_hand - line.quantity
    WHERE id = line.product_id;

    -- Log movement
    INSERT INTO stock_movements (business_id, product_id, movement_type, quantity, reference_id, created_by)
    VALUES (v_business_id, line.product_id, 'order_out', -line.quantity, p_order_id, line.driver_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION deduct_stock_for_order(UUID) TO authenticated;

-- ============================================================
-- 5. RPC: replenish_stock_from_purchase
-- ============================================================
CREATE OR REPLACE FUNCTION replenish_stock_from_purchase(p_purchase_order_id UUID)
RETURNS void AS $$
DECLARE
  v_business_id UUID;
  v_created_by UUID;
  line RECORD;
BEGIN
  -- Auth check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- Get PO business_id and verify ownership
  SELECT business_id, created_by INTO v_business_id, v_created_by
  FROM purchase_orders WHERE id = p_purchase_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase_order_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Idempotency guard: skip if already processed
  IF EXISTS (
    SELECT 1 FROM stock_movements
    WHERE reference_id = p_purchase_order_id AND movement_type = 'purchase_in'
  ) THEN
    RETURN;
  END IF;

  -- Replenish stock for each PO line
  FOR line IN
    SELECT product_id, quantity
    FROM purchase_order_lines
    WHERE purchase_order_id = p_purchase_order_id
  LOOP
    -- Update product stock
    UPDATE products
    SET stock_on_hand = stock_on_hand + line.quantity
    WHERE id = line.product_id;

    -- Log movement
    INSERT INTO stock_movements (business_id, product_id, movement_type, quantity, reference_id, created_by)
    VALUES (v_business_id, line.product_id, 'purchase_in', line.quantity, p_purchase_order_id, v_created_by);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION replenish_stock_from_purchase(UUID) TO authenticated;

-- ============================================================
-- 6. RPC: restore_stock_for_cancellation
-- ============================================================
CREATE OR REPLACE FUNCTION restore_stock_for_cancellation(p_order_id UUID)
RETURNS void AS $$
DECLARE
  v_business_id UUID;
  line RECORD;
BEGIN
  -- Auth check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- Get order business_id and verify ownership
  SELECT business_id INTO v_business_id
  FROM orders WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Idempotency guard: skip if already processed
  IF EXISTS (
    SELECT 1 FROM stock_movements
    WHERE reference_id = p_order_id AND movement_type = 'cancellation_restore'
  ) THEN
    RETURN;
  END IF;

  -- Restore stock for each order line
  FOR line IN
    SELECT ol.product_id, ol.quantity
    FROM order_lines ol
    WHERE ol.order_id = p_order_id
  LOOP
    -- Update product stock
    UPDATE products
    SET stock_on_hand = stock_on_hand + line.quantity
    WHERE id = line.product_id;

    -- Log movement
    INSERT INTO stock_movements (business_id, product_id, movement_type, quantity, reference_id, created_by)
    VALUES (v_business_id, line.product_id, 'cancellation_restore', line.quantity, p_order_id, auth.uid());
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION restore_stock_for_cancellation(UUID) TO authenticated;
-- Phase 7 Plan 02: Stock adjustment RPC function

-- ============================================================
-- adjust_stock: Manual stock correction with reason
-- ============================================================
CREATE OR REPLACE FUNCTION adjust_stock(
  p_product_id UUID,
  p_quantity INTEGER,
  p_notes TEXT
) RETURNS void AS $$
DECLARE
  v_business_id UUID;
BEGIN
  -- Auth check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- Reject zero quantity
  IF p_quantity = 0 THEN
    RAISE EXCEPTION 'zero_quantity_adjustment';
  END IF;

  -- Get product business_id and verify ownership
  SELECT business_id INTO v_business_id
  FROM products WHERE id = p_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'product_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Update product stock
  UPDATE products
  SET stock_on_hand = stock_on_hand + p_quantity
  WHERE id = p_product_id;

  -- Log movement
  INSERT INTO stock_movements (business_id, product_id, movement_type, quantity, notes, created_by)
  VALUES (v_business_id, p_product_id, 'adjustment', p_quantity, p_notes, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION adjust_stock(UUID, INTEGER, TEXT) TO authenticated;
-- AEGIS REMEDIATION: Day-1 Security Fixes (Phase 8)
--
-- IMPORTANT: Supabase Free Tier pauses after 7 days of inactivity.
-- Set up a keep-alive mechanism:
--   Option A: Upgrade to Supabase Pro ($25/month)
--   Option B: External cron (e.g., cron-job.org) pinging the health endpoint daily
--   Option C: pg_cron job: SELECT 1; on a daily schedule
--
-- Finding refs: DA blind spot 3.1, F-07-006

-- ============================================================
-- Fix 1: Location cleanup — wrong column name (created_at → timestamp)
-- Finding: F-02-008
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_old_driver_locations()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM driver_locations
  WHERE "timestamp" < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Fix 2: Revoke anon grants on mutation RPCs
-- Finding: F-02-003, F-05-004
-- Only mutation functions are revoked. Read-only functions
-- (get_package_balances_for_store, get_package_alerts,
-- get_latest_driver_locations) remain accessible to anon.
-- ============================================================
REVOKE EXECUTE ON FUNCTION create_package_log(UUID, UUID, UUID, INTEGER, INTEGER, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION approve_discount(UUID, UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION reject_discount(UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION reject_expired_discounts(UUID) FROM anon;
-- AEGIS REMEDIATION: Security Hardening (Phase 9, Plan 01)
-- Fixes: F-04-001 (JWT metadata spoofable), F-02-007/F-04-007/F-04-008 (missing role checks),
--        F-05-003/F-05-005 (audit trail writable by drivers), F-04-012 (unprotected balance update)

-- ============================================================
-- PART 1: JWT Metadata Protection Trigger
-- Prevents client-side modification of role and business_id
-- in raw_user_meta_data via auth.updateUser()
-- Finding: F-04-001
-- ============================================================

CREATE OR REPLACE FUNCTION protect_user_metadata()
RETURNS TRIGGER AS $$
BEGIN
  -- On UPDATE: if role or business_id changed, revert to OLD values
  IF OLD.raw_user_meta_data IS NOT NULL THEN
    -- Preserve role from being changed
    IF (OLD.raw_user_meta_data->>'role') IS NOT NULL
       AND (NEW.raw_user_meta_data->>'role') IS DISTINCT FROM (OLD.raw_user_meta_data->>'role') THEN
      NEW.raw_user_meta_data := jsonb_set(
        NEW.raw_user_meta_data,
        '{role}',
        to_jsonb(OLD.raw_user_meta_data->>'role')
      );
    END IF;
    -- Preserve business_id from being changed
    IF (OLD.raw_user_meta_data->>'business_id') IS NOT NULL
       AND (NEW.raw_user_meta_data->>'business_id') IS DISTINCT FROM (OLD.raw_user_meta_data->>'business_id') THEN
      NEW.raw_user_meta_data := jsonb_set(
        NEW.raw_user_meta_data,
        '{business_id}',
        to_jsonb(OLD.raw_user_meta_data->>'business_id')
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger fires BEFORE UPDATE so protected fields silently revert
-- INSERT (signUp) is not affected — trigger is UPDATE only
CREATE TRIGGER protect_user_metadata_trigger
  BEFORE UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION protect_user_metadata();

-- Prevent direct invocation of trigger function
REVOKE EXECUTE ON FUNCTION protect_user_metadata() FROM PUBLIC;


-- ============================================================
-- PART 2: Role Checks on SECURITY DEFINER Functions
-- ============================================================

-- ------------------------------------------------------------
-- 2a. approve_discount: Require owner role, use auth.uid() for approved_by
-- Finding: F-02-007, F-04-008
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION approve_discount(
  p_order_id UUID,
  p_approved_by UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Role check: only owner can approve discounts
  IF get_user_role() NOT IN ('owner') THEN
    RAISE EXCEPTION 'unauthorized: only owner can approve discounts';
  END IF;

  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Verify order exists and is pending
  SELECT id, discount_status INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.discount_status != 'pending' THEN
    RAISE EXCEPTION 'discount_already_processed';
  END IF;

  -- Approve the discount — use auth.uid() instead of client-supplied p_approved_by
  UPDATE orders
  SET discount_status = 'approved',
      discount_approved_by = auth.uid()
  WHERE id = p_order_id;

  RETURN jsonb_build_object('status', 'approved', 'order_id', p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2b. reject_discount: Require owner role
-- Finding: F-05-003
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION reject_discount(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_new_total NUMERIC;
BEGIN
  -- Role check: only owner can reject discounts
  IF get_user_role() NOT IN ('owner') THEN
    RAISE EXCEPTION 'unauthorized: only owner can reject discounts';
  END IF;

  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get order details with lock
  SELECT id, discount, discount_status, subtotal, tax_amount, store_id
  INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.discount_status != 'pending' THEN
    RAISE EXCEPTION 'discount_already_processed';
  END IF;

  -- Recalculate total without discount
  v_new_total := v_order.subtotal + v_order.tax_amount;

  -- Update order: reject discount, fix total
  UPDATE orders
  SET discount_status = 'rejected',
      total = v_new_total
  WHERE id = p_order_id;

  -- Add discount amount back to store credit_balance (reverse the deduction)
  UPDATE stores
  SET credit_balance = credit_balance + v_order.discount
  WHERE id = v_order.store_id;

  RETURN jsonb_build_object(
    'status', 'rejected',
    'order_id', p_order_id,
    'new_total', v_new_total,
    'discount_reversed', v_order.discount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2c. reject_expired_discounts: Require owner/admin role
-- Finding: F-05-003 (audit-added)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION reject_expired_discounts(
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_count INTEGER := 0;
  v_new_total NUMERIC;
BEGIN
  -- Role check: only owner/admin can trigger expired discount rejection
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can reject expired discounts';
  END IF;

  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Process each expired pending discount
  FOR v_order IN
    SELECT id, discount, subtotal, tax_amount, store_id
    FROM orders
    WHERE business_id = p_business_id
      AND discount_status = 'pending'
      AND created_at < now() - interval '3 minutes'
    FOR UPDATE
  LOOP
    v_new_total := v_order.subtotal + v_order.tax_amount;

    UPDATE orders
    SET discount_status = 'rejected',
        total = v_new_total
    WHERE id = v_order.id;

    UPDATE stores
    SET credit_balance = credit_balance + v_order.discount
    WHERE id = v_order.store_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('rejected_count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2d. cancel_order: Require owner/admin OR order's own driver
-- Finding: F-05-003
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION cancel_order(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Role check: owner/admin can cancel any order, driver can cancel own
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    IF get_user_role() = 'driver' THEN
      IF NOT EXISTS (SELECT 1 FROM orders WHERE id = p_order_id AND driver_id = auth.uid()) THEN
        RAISE EXCEPTION 'unauthorized: drivers can only cancel their own orders';
      END IF;
    ELSE
      RAISE EXCEPTION 'unauthorized: insufficient role';
    END IF;
  END IF;

  -- Fetch and lock the order
  SELECT id, status, discount_status, total, store_id
  INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.status != 'created' THEN
    RAISE EXCEPTION 'only_created_orders_can_be_cancelled';
  END IF;

  -- Update order status
  UPDATE orders SET status = 'cancelled'
    WHERE id = p_order_id;

  -- If discount was pending, neutralize it to prevent auto-reject from double-processing
  IF v_order.discount_status = 'pending' THEN
    UPDATE orders SET discount_status = 'none'
      WHERE id = p_order_id;
  END IF;

  -- Reverse store balance (subtract order total from credit_balance)
  UPDATE stores SET credit_balance = credit_balance - v_order.total
    WHERE id = v_order.store_id AND business_id = p_business_id;

  RETURN jsonb_build_object('status', 'cancelled', 'reversed_amount', v_order.total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2e. adjust_stock: Require owner/admin role
-- Finding: F-04-007
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION adjust_stock(
  p_product_id UUID,
  p_quantity INTEGER,
  p_notes TEXT
) RETURNS void AS $$
DECLARE
  v_business_id UUID;
BEGIN
  -- Auth check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- Role check: only owner/admin can adjust stock
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can adjust stock';
  END IF;

  -- Reject zero quantity
  IF p_quantity = 0 THEN
    RAISE EXCEPTION 'zero_quantity_adjustment';
  END IF;

  -- Get product business_id and verify ownership
  SELECT business_id INTO v_business_id
  FROM products WHERE id = p_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'product_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Update product stock
  UPDATE products
  SET stock_on_hand = stock_on_hand + p_quantity
  WHERE id = p_product_id;

  -- Log movement
  INSERT INTO stock_movements (business_id, product_id, movement_type, quantity, notes, created_by)
  VALUES (v_business_id, p_product_id, 'adjustment', p_quantity, p_notes, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2f. adjust_store_balance: Require owner/admin role
-- Finding: F-05-003
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION adjust_store_balance(
  p_store_id UUID,
  p_business_id UUID,
  p_amount NUMERIC,
  p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
  v_store RECORD;
  v_new_balance NUMERIC;
  v_user_id UUID;
BEGIN
  -- Role check: only owner/admin can adjust balances
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can adjust store balance';
  END IF;

  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get authenticated user ID from JWT (non-spoofable)
  v_user_id := auth.uid();

  -- Reject zero adjustments
  IF p_amount = 0 THEN
    RAISE EXCEPTION 'amount_cannot_be_zero';
  END IF;

  -- Lock and read store
  SELECT id, credit_balance INTO v_store
  FROM stores
  WHERE id = p_store_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'store_not_found';
  END IF;

  v_new_balance := v_store.credit_balance + p_amount;

  -- Update store balance
  UPDATE stores SET credit_balance = v_new_balance
    WHERE id = p_store_id;

  -- Log the adjustment
  INSERT INTO balance_adjustments (business_id, store_id, adjusted_by, amount, reason, previous_balance, new_balance)
  VALUES (p_business_id, p_store_id, v_user_id, p_amount, p_reason, v_store.credit_balance, v_new_balance);

  RETURN jsonb_build_object(
    'previous_balance', v_store.credit_balance,
    'new_balance', v_new_balance,
    'amount', p_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2g. update_store_balance_on_order: Add minimum auth guard (stopgap)
-- Finding: F-04-012, F-02-009 (audit-added)
-- Will be replaced by atomic order RPC in Plan 09-02
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_store_balance_on_order(
  p_store_id UUID,
  p_order_total NUMERIC
) RETURNS VOID AS $$
BEGIN
  -- Minimum auth guard (stopgap until atomic order RPC replaces this)
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: authentication required';
  END IF;

  -- Atomic UPDATE — credit_balance + p_order_total is inherently safe
  UPDATE stores
  SET credit_balance = credit_balance + p_order_total
  WHERE id = p_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- PART 3: balance_adjustments RLS — Append-Only with Role Access
-- Finding: F-04-004, F-05-005
-- ============================================================

-- Drop the overly permissive FOR ALL policy
DROP POLICY IF EXISTS "Users can manage own business adjustments" ON balance_adjustments;

-- Owner: SELECT + INSERT. No UPDATE/DELETE.
CREATE POLICY "balance_adjustments_owner_read"
  ON balance_adjustments FOR SELECT
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY "balance_adjustments_owner_insert"
  ON balance_adjustments FOR INSERT
  WITH CHECK (get_user_role() = 'owner' AND business_id = get_user_business_id());

-- Admin: SELECT only
CREATE POLICY "balance_adjustments_admin_read"
  ON balance_adjustments FOR SELECT
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

-- Driver: SELECT only (can see adjustments for their business)
CREATE POLICY "balance_adjustments_driver_read"
  ON balance_adjustments FOR SELECT
  USING (get_user_role() = 'driver' AND business_id = get_user_business_id());

-- No UPDATE or DELETE policies for any role = append-only audit table
-- AEGIS REMEDIATION: Atomic Order Creation + Deactivation Enforcement (Phase 9, Plan 02)
-- Fixes: F-02-009 (non-atomic order creation), F-04-006 (deactivation not enforced),
--        F-07-001 (startup version check — Dart side)
-- Deploy via: supabase db push or Supabase Dashboard SQL Editor

-- ============================================================
-- PART 1: Atomic Order Creation RPC
-- Consolidates 5 separate DB operations into one transaction:
--   1. INSERT order
--   2. INSERT order_lines
--   3. UPDATE store credit_balance
--   4. CREATE package_logs for returnable products
--   5. DEDUCT stock + log stock_movements
-- ============================================================

CREATE OR REPLACE FUNCTION create_order_atomic(
  p_order_id UUID DEFAULT NULL,
  p_store_id UUID DEFAULT NULL,
  p_business_id UUID DEFAULT NULL,
  p_subtotal NUMERIC DEFAULT 0,
  p_tax_percentage NUMERIC DEFAULT 0,
  p_tax_amount NUMERIC DEFAULT 0,
  p_discount NUMERIC DEFAULT 0,
  p_discount_status TEXT DEFAULT 'none',
  p_total NUMERIC DEFAULT 0,
  p_line_items JSONB DEFAULT '[]'::JSONB
) RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_driver_id UUID := auth.uid();
  v_line JSONB;
  v_line_id UUID;
  v_product RECORD;
  v_prev_pkg_balance INTEGER;
  v_new_pkg_balance INTEGER;
  v_existing JSONB;
  v_created_at TIMESTAMPTZ;
BEGIN
  -- ── Auth checks ──────────────────────────────────────────
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF get_user_role() != 'driver' THEN
    RAISE EXCEPTION 'unauthorized: only drivers can create orders';
  END IF;

  IF p_business_id != get_user_business_id() THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- ── Store-business validation (audit-added) ──────────────
  IF NOT EXISTS (
    SELECT 1 FROM stores WHERE id = p_store_id AND business_id = p_business_id
  ) THEN
    RAISE EXCEPTION 'unauthorized: store not in business';
  END IF;

  -- ── Discount status validation (audit-added) ─────────────
  IF p_discount_status NOT IN ('none', 'pending') THEN
    RAISE EXCEPTION 'invalid discount_status: must be none or pending';
  END IF;

  -- ── Idempotency guard (audit-added) ──────────────────────
  IF p_order_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'id', o.id,
      'store_id', o.store_id,
      'driver_id', o.driver_id,
      'business_id', o.business_id,
      'subtotal', o.subtotal,
      'tax_percentage', o.tax_percentage,
      'tax_amount', o.tax_amount,
      'discount', o.discount,
      'discount_status', o.discount_status,
      'total', o.total,
      'status', o.status,
      'created_at', o.created_at
    ) INTO v_existing
    FROM orders o WHERE o.id = p_order_id;

    IF v_existing IS NOT NULL THEN
      RETURN v_existing;  -- Idempotent: return existing order
    END IF;

    v_order_id := p_order_id;
  ELSE
    v_order_id := gen_random_uuid();
  END IF;

  -- ── Step 1: INSERT order ─────────────────────────────────
  INSERT INTO orders (
    id, business_id, store_id, driver_id,
    subtotal, tax_percentage, tax_amount,
    discount, discount_status, total, status
  ) VALUES (
    v_order_id, p_business_id, p_store_id, v_driver_id,
    p_subtotal, p_tax_percentage, p_tax_amount,
    p_discount, p_discount_status, p_total, 'created'
  )
  RETURNING created_at INTO v_created_at;

  -- ── Step 2: INSERT order_lines from JSONB ────────────────
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
  LOOP
    v_line_id := gen_random_uuid();

    INSERT INTO order_lines (id, order_id, product_id, quantity, unit_price, line_total)
    VALUES (
      v_line_id,
      v_order_id,
      (v_line->>'product_id')::UUID,
      (v_line->>'quantity')::INTEGER,
      (v_line->>'unit_price')::NUMERIC,
      (v_line->>'line_total')::NUMERIC
    );
  END LOOP;

  -- ── Step 3: UPDATE store credit balance ──────────────────
  UPDATE stores
  SET credit_balance = credit_balance + p_total
  WHERE id = p_store_id;

  -- ── Step 4: Package logs for returnable products ─────────
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
  LOOP
    SELECT id, has_returnable_packaging
    INTO v_product
    FROM products
    WHERE id = (v_line->>'product_id')::UUID;

    IF v_product.has_returnable_packaging THEN
      -- Get current package balance with row lock (prevents race conditions)
      SELECT balance_after INTO v_prev_pkg_balance
      FROM package_logs
      WHERE store_id = p_store_id AND product_id = v_product.id
      ORDER BY created_at DESC
      LIMIT 1
      FOR UPDATE;

      IF NOT FOUND THEN
        v_prev_pkg_balance := 0;
      END IF;

      v_new_pkg_balance := v_prev_pkg_balance + (v_line->>'quantity')::INTEGER;

      INSERT INTO package_logs (
        business_id, store_id, driver_id, product_id,
        order_id, given, collected, balance_after
      ) VALUES (
        p_business_id, p_store_id, v_driver_id, v_product.id,
        v_order_id, (v_line->>'quantity')::INTEGER, 0, v_new_pkg_balance
      );
    END IF;
  END LOOP;

  -- ── Step 5: Deduct stock + log movements ─────────────────
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
  LOOP
    UPDATE products
    SET stock_on_hand = stock_on_hand - (v_line->>'quantity')::INTEGER
    WHERE id = (v_line->>'product_id')::UUID;

    INSERT INTO stock_movements (
      business_id, product_id, movement_type,
      quantity, reference_id, created_by
    ) VALUES (
      p_business_id,
      (v_line->>'product_id')::UUID,
      'order_out',
      -(v_line->>'quantity')::INTEGER,
      v_order_id,
      v_driver_id
    );
  END LOOP;

  -- ── Return order data ────────────────────────────────────
  RETURN jsonb_build_object(
    'id', v_order_id,
    'store_id', p_store_id,
    'driver_id', v_driver_id,
    'business_id', p_business_id,
    'subtotal', p_subtotal,
    'tax_percentage', p_tax_percentage,
    'tax_amount', p_tax_amount,
    'discount', p_discount,
    'discount_status', p_discount_status,
    'total', p_total,
    'status', 'created',
    'created_at', v_created_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION create_order_atomic(UUID, UUID, UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_order_atomic(UUID, UUID, UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, JSONB) TO authenticated;


-- ============================================================
-- PART 2: Deactivation Enforcement on get_user_role()
-- When a user's active = false in users table, get_user_role()
-- returns NULL, which blocks ALL RLS policies system-wide.
-- ============================================================

CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
DECLARE
  v_active BOOLEAN;
BEGIN
  -- Check if user is active in users table
  SELECT active INTO v_active FROM users WHERE id = auth.uid();

  -- If explicitly deactivated, block all access
  IF v_active = false THEN
    RETURN NULL;
  END IF;

  -- NULL (no row found — init edge case) or TRUE: return JWT role as before
  RETURN (auth.jwt() -> 'user_metadata' ->> 'role');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- AEGIS REMEDIATION: Schema Hardening (Phase 10, Plan 01)
-- Fixes: stock negativity, missing updated_at, cancellation audit trail
-- Deploy via: supabase db push or Supabase Dashboard SQL Editor

-- ============================================================
-- PART 1: CHECK constraint on stock_on_hand
-- Prevents inventory from going negative via race conditions
-- ============================================================

ALTER TABLE products
  ADD CONSTRAINT products_stock_non_negative CHECK (stock_on_hand >= 0);


-- ============================================================
-- PART 2: updated_at columns + auto-update trigger
-- Adds modification tracking to 4 core tables
-- ============================================================

-- Shared trigger function (reusable across tables)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Prevent direct invocation of trigger function
REVOKE EXECUTE ON FUNCTION set_updated_at() FROM PUBLIC;

-- Add updated_at columns
ALTER TABLE orders ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE stores ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE products ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();

-- Backfill: set updated_at = created_at for existing rows
UPDATE orders SET updated_at = created_at WHERE updated_at IS NULL;
UPDATE stores SET updated_at = created_at WHERE updated_at IS NULL;
UPDATE products SET updated_at = created_at WHERE updated_at IS NULL;
UPDATE users SET updated_at = created_at WHERE updated_at IS NULL;

-- Create auto-update triggers
CREATE TRIGGER set_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_stores_updated_at
  BEFORE UPDATE ON stores
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================
-- PART 3: Cancellation audit columns on orders
-- Records who cancelled and when
-- ============================================================

ALTER TABLE orders ADD COLUMN cancelled_by UUID REFERENCES users(id);
ALTER TABLE orders ADD COLUMN cancelled_at TIMESTAMPTZ;


-- ============================================================
-- PART 4: Update cancel_order RPC — populate audit columns
-- Consolidated into single UPDATE with CASE for discount_status
-- ============================================================

CREATE OR REPLACE FUNCTION cancel_order(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Role check: owner/admin can cancel any order, driver can cancel own
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    IF get_user_role() = 'driver' THEN
      IF NOT EXISTS (SELECT 1 FROM orders WHERE id = p_order_id AND driver_id = auth.uid()) THEN
        RAISE EXCEPTION 'unauthorized: drivers can only cancel their own orders';
      END IF;
    ELSE
      RAISE EXCEPTION 'unauthorized: insufficient role';
    END IF;
  END IF;

  -- Fetch and lock the order
  SELECT id, status, discount_status, total, store_id
  INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.status != 'created' THEN
    RAISE EXCEPTION 'only_created_orders_can_be_cancelled';
  END IF;

  -- Single UPDATE: status + audit columns + conditional discount neutralization
  UPDATE orders
  SET status = 'cancelled',
      cancelled_by = auth.uid(),
      cancelled_at = now(),
      discount_status = CASE
        WHEN discount_status = 'pending' THEN 'none'
        ELSE discount_status
      END
  WHERE id = p_order_id;

  -- Reverse store balance (subtract order total from credit_balance)
  UPDATE stores SET credit_balance = credit_balance - v_order.total
    WHERE id = v_order.store_id AND business_id = p_business_id;

  RETURN jsonb_build_object('status', 'cancelled', 'reversed_amount', v_order.total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- AEGIS REMEDIATION: Dashboard Consolidation (Phase 10, Plan 02)
-- Consolidates 5 separate dashboard queries into single RPC
-- Deploy via: supabase db push or Supabase Dashboard SQL Editor

-- ============================================================
-- get_dashboard_summary: Single RPC returning all dashboard KPIs
-- Replaces 5 individual queries with 1 round trip
-- ============================================================

CREATE OR REPLACE FUNCTION get_dashboard_summary(p_business_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_today_start TIMESTAMPTZ;
  v_revenue NUMERIC;
  v_order_count INTEGER;
  v_purchases NUMERIC;
  v_debtors JSONB;
  v_low_stock JSONB;
BEGIN
  -- Auth checks
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can view dashboard';
  END IF;

  IF p_business_id != get_user_business_id() THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Algeria timezone: start of today in UTC
  v_today_start := ((now() AT TIME ZONE 'Africa/Algiers')::date)::timestamptz AT TIME ZONE 'Africa/Algiers';

  -- Today's revenue (sum of payments)
  SELECT COALESCE(SUM(amount), 0) INTO v_revenue
  FROM payments
  WHERE business_id = p_business_id
    AND created_at >= v_today_start;

  -- Today's order count
  SELECT COUNT(*) INTO v_order_count
  FROM orders
  WHERE business_id = p_business_id
    AND created_at >= v_today_start;

  -- Today's purchases (sum of purchase order costs)
  SELECT COALESCE(SUM(total_cost), 0) INTO v_purchases
  FROM purchase_orders
  WHERE business_id = p_business_id
    AND created_at >= v_today_start;

  -- Top debtors (stores with outstanding credit)
  SELECT COALESCE(jsonb_agg(row_to_json(d)), '[]'::jsonb) INTO v_debtors
  FROM (
    SELECT id, name, credit_balance
    FROM stores
    WHERE business_id = p_business_id
      AND credit_balance > 0
    ORDER BY credit_balance DESC
    LIMIT 5
  ) d;

  -- Low stock products (stock at or below threshold)
  SELECT COALESCE(jsonb_agg(row_to_json(ls)), '[]'::jsonb) INTO v_low_stock
  FROM (
    SELECT id, name, stock_on_hand, low_stock_threshold
    FROM products
    WHERE business_id = p_business_id
      AND active = true
      AND low_stock_threshold > 0
      AND stock_on_hand <= low_stock_threshold
  ) ls;

  -- Return consolidated JSONB
  RETURN jsonb_build_object(
    'today_revenue', v_revenue,
    'today_order_count', v_order_count,
    'today_purchases', v_purchases,
    'today_profit', v_revenue - v_purchases,
    'top_debtors', v_debtors,
    'low_stock_products', v_low_stock
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION get_dashboard_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_dashboard_summary(UUID) TO authenticated;
