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
