-- ============================================================
-- Migration 021: Driver Load Operations
-- close_driver_load, add_to_driver_load RPCs
-- Modify create_order_atomic (Step 6: track driver sales)
-- Modify cancel_order (reverse driver sales + restore stock)
-- ============================================================


-- ============================================================
-- 1. RPC: close_driver_load
-- ============================================================

CREATE OR REPLACE FUNCTION close_driver_load(
  p_load_id UUID,
  p_returns JSONB
)
RETURNS VOID AS $$
DECLARE
  v_business_id UUID;
  v_status TEXT;
  v_item RECORD;
  v_product_id UUID;
  v_returned INTEGER;
  v_loaded INTEGER;
  v_sold INTEGER;
BEGIN
  -- ── Auth check ─────────────────────────────────────────────
  IF get_user_role() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- Driver can only close own load; owner/admin can close any
  IF get_user_role() = 'driver' THEN
    IF NOT EXISTS (
      SELECT 1 FROM driver_loads WHERE id = p_load_id AND driver_id = auth.uid()
    ) THEN
      RAISE EXCEPTION 'unauthorized: not your load';
    END IF;
  ELSIF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: insufficient role';
  END IF;

  -- ── Load validation + fetch business_id ────────────────────
  SELECT business_id, status INTO v_business_id, v_status
  FROM driver_loads WHERE id = p_load_id;

  IF NOT FOUND OR v_status != 'active' THEN
    RAISE EXCEPTION 'invalid_load: load not found or already closed';
  END IF;

  -- ── Process returns ────────────────────────────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_returns)
  LOOP
    v_product_id := (v_item.value->>'product_id')::UUID;
    v_returned := (v_item.value->>'quantity_returned')::INTEGER;

    -- Validate returned quantity against loaded - sold
    SELECT quantity_loaded, quantity_sold INTO v_loaded, v_sold
    FROM driver_load_items
    WHERE load_id = p_load_id AND product_id = v_product_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid_return: product % not in load', v_product_id;
    END IF;

    IF v_returned < 0 OR v_returned > (v_loaded - v_sold) THEN
      RAISE EXCEPTION 'invalid_return: quantity_returned out of range for product %', v_product_id;
    END IF;

    -- Update load item
    UPDATE driver_load_items
    SET quantity_returned = v_returned
    WHERE load_id = p_load_id AND product_id = v_product_id;

    -- Restore warehouse stock
    UPDATE products
    SET stock_on_hand = stock_on_hand + v_returned
    WHERE id = v_product_id;

    -- Log stock movement
    INSERT INTO stock_movements (
      business_id, product_id, movement_type,
      quantity, reference_id, created_by
    ) VALUES (
      v_business_id,
      v_product_id,
      'load_return',
      v_returned,
      p_load_id,
      auth.uid()
    );
  END LOOP;

  -- ── Close the load ─────────────────────────────────────────
  UPDATE driver_loads
  SET status = 'closed', closed_at = now()
  WHERE id = p_load_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION close_driver_load(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION close_driver_load(UUID, JSONB) TO authenticated;


-- ============================================================
-- 2. RPC: add_to_driver_load
-- ============================================================

CREATE OR REPLACE FUNCTION add_to_driver_load(
  p_load_id UUID,
  p_items JSONB
)
RETURNS VOID AS $$
DECLARE
  v_business_id UUID;
  v_status TEXT;
  v_item RECORD;
  v_product_id UUID;
  v_quantity INTEGER;
  v_stock INTEGER;
  v_existing_item_id UUID;
BEGIN
  -- ── Auth check ─────────────────────────────────────────────
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can add to loads';
  END IF;

  -- ── Load validation + fetch business_id ────────────────────
  SELECT business_id, status INTO v_business_id, v_status
  FROM driver_loads WHERE id = p_load_id;

  IF NOT FOUND OR v_status != 'active' THEN
    RAISE EXCEPTION 'invalid_load: load not found or already closed';
  END IF;

  IF get_user_business_id() != v_business_id THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- ── Empty items guard ──────────────────────────────────────
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invalid_items: at least one product required';
  END IF;

  -- ── Process items ──────────────────────────────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item.value->>'product_id')::UUID;
    v_quantity := (v_item.value->>'quantity')::INTEGER;

    -- Lock product row + check stock
    SELECT stock_on_hand INTO v_stock
    FROM products
    WHERE id = v_product_id AND business_id = v_business_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid_product: product % not found', v_product_id;
    END IF;

    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'insufficient_stock: product % has % but requested %',
        v_product_id, v_stock, v_quantity;
    END IF;

    -- Upsert: update existing or insert new
    SELECT id INTO v_existing_item_id
    FROM driver_load_items
    WHERE load_id = p_load_id AND product_id = v_product_id;

    IF v_existing_item_id IS NOT NULL THEN
      UPDATE driver_load_items
      SET quantity_loaded = quantity_loaded + v_quantity
      WHERE id = v_existing_item_id;
    ELSE
      INSERT INTO driver_load_items (load_id, product_id, quantity_loaded)
      VALUES (p_load_id, v_product_id, v_quantity);
    END IF;

    -- Deduct warehouse stock
    UPDATE products
    SET stock_on_hand = stock_on_hand - v_quantity
    WHERE id = v_product_id;

    -- Log stock movement
    INSERT INTO stock_movements (
      business_id, product_id, movement_type,
      quantity, reference_id, created_by
    ) VALUES (
      v_business_id,
      v_product_id,
      'load_out',
      -v_quantity,
      p_load_id,
      auth.uid()
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION add_to_driver_load(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION add_to_driver_load(UUID, JSONB) TO authenticated;


-- ============================================================
-- 3. Modify create_order_atomic — Add Step 6: Track driver sales
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
  v_active_load_id UUID;
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

  -- ── Step 6: Track driver load sales (if driver has active load) ──
  SELECT id INTO v_active_load_id
  FROM driver_loads
  WHERE driver_id = v_driver_id AND status = 'active';

  IF v_active_load_id IS NOT NULL THEN
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
    LOOP
      UPDATE driver_load_items
      SET quantity_sold = quantity_sold + (v_line->>'quantity')::INTEGER
      WHERE load_id = v_active_load_id
        AND product_id = (v_line->>'product_id')::UUID;
      -- No error if product not in load (driver might sell warehouse-only items)
    END LOOP;
  END IF;

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

-- Signature unchanged — no need to re-REVOKE/GRANT


-- ============================================================
-- 4. Modify cancel_order — Reverse driver sales + restore stock
-- ============================================================

CREATE OR REPLACE FUNCTION cancel_order(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_active_load_id UUID;
  v_line RECORD;
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
  SELECT id, status, discount_status, total, store_id, driver_id, business_id
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

  -- Reverse store balance
  UPDATE stores SET credit_balance = credit_balance - v_order.total
    WHERE id = v_order.store_id AND business_id = p_business_id;

  -- ── Reverse driver load sales (if driver had active load) ──
  SELECT id INTO v_active_load_id
  FROM driver_loads
  WHERE driver_id = v_order.driver_id AND status = 'active';

  IF v_active_load_id IS NOT NULL THEN
    FOR v_line IN
      SELECT product_id, quantity FROM order_lines WHERE order_id = p_order_id
    LOOP
      UPDATE driver_load_items
      SET quantity_sold = GREATEST(quantity_sold - v_line.quantity, 0)
      WHERE load_id = v_active_load_id
        AND product_id = v_line.product_id;
    END LOOP;
  END IF;

  -- ── Restore warehouse stock + log movements ────────────────
  FOR v_line IN
    SELECT product_id, quantity FROM order_lines WHERE order_id = p_order_id
  LOOP
    UPDATE products SET stock_on_hand = stock_on_hand + v_line.quantity
    WHERE id = v_line.product_id;

    INSERT INTO stock_movements (
      business_id, product_id, movement_type,
      quantity, reference_id, created_by
    ) VALUES (
      v_order.business_id,
      v_line.product_id,
      'cancellation_restore',
      v_line.quantity,
      p_order_id,
      auth.uid()
    );
  END LOOP;

  RETURN jsonb_build_object('status', 'cancelled', 'reversed_amount', v_order.total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Signature unchanged — no need to re-REVOKE/GRANT
