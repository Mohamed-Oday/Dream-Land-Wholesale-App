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
