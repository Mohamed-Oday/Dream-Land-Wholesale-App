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
