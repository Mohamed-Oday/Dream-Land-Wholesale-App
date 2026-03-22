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
