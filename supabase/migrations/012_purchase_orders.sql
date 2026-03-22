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
