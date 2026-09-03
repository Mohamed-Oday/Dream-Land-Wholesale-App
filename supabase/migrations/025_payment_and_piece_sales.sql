-- Migration 025: Add payment status RPC and update create_order_atomic for piece sales
-- Created: 2026-07-23

-- ============================================================
-- 1) Update create_order_atomic to handle piece sales
-- ============================================================
-- The order_lines table now has sold_by_piece and pieces_quantity columns
-- When sold_by_piece=true, quantity=0 (packages), pieces_quantity stores pieces
-- line_total = unit_price * pieces_quantity / units_per_package

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
  v_user_role TEXT;
  v_sold_by_piece BOOLEAN;
  v_pieces_quantity INTEGER;
  v_units_per_package INTEGER;
BEGIN
  -- ── Auth checks ──────────────────────────────────────────
  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  v_user_role := get_user_role();
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'unauthorized: deactivated or invalid role';
  END IF;

  IF v_user_role NOT IN ('driver', 'owner') THEN
    RAISE EXCEPTION 'unauthorized: only drivers and owners can create orders';
  END IF;

  IF p_business_id != get_user_business_id() THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- ── Store-business validation ────────────────────────────
  IF NOT EXISTS (
    SELECT 1 FROM stores WHERE id = p_store_id AND business_id = p_business_id
  ) THEN
    RAISE EXCEPTION 'unauthorized: store not in business';
  END IF;

  -- ── Discount status validation ───────────────────────────
  IF p_discount_status NOT IN ('none', 'pending') THEN
    RAISE EXCEPTION 'invalid discount_status: must be none or pending';
  END IF;

  -- ── Idempotency guard ────────────────────────────────────
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
      RETURN v_existing;
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
    v_sold_by_piece := COALESCE((v_line->>'sold_by_piece')::BOOLEAN, FALSE);
    v_pieces_quantity := CASE WHEN (v_line->>'pieces_quantity') IS NOT NULL 
                              THEN (v_line->>'pieces_quantity')::INTEGER 
                              ELSE NULL END;
    v_units_per_package := (v_line->>'units_per_package')::INTEGER;

    INSERT INTO order_lines (
      id, order_id, product_id, quantity, unit_price, line_total,
      sold_by_piece, pieces_quantity
    ) VALUES (
      v_line_id,
      v_order_id,
      (v_line->>'product_id')::UUID,
      CASE WHEN v_sold_by_piece THEN 0 ELSE (v_line->>'quantity')::INTEGER END,
      (v_line->>'unit_price')::NUMERIC,
      (v_line->>'line_total')::NUMERIC,
      v_sold_by_piece,
      v_pieces_quantity
    );
  END LOOP;

  -- ── Step 3: UPDATE store credit balance ──────────────────
  UPDATE stores
  SET credit_balance = credit_balance + p_total
  WHERE id = p_store_id;

  -- ── Step 4: Package logs for returnable products ─────────
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
  LOOP
    SELECT id, has_returnable_packaging, units_per_package
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
    v_sold_by_piece := COALESCE((v_line->>'sold_by_piece')::BOOLEAN, FALSE);
    v_pieces_quantity := CASE WHEN (v_line->>'pieces_quantity') IS NOT NULL 
                              THEN (v_line->>'pieces_quantity')::INTEGER 
                              ELSE NULL END;

    -- Calculate stock deduction: pieces if sold by piece, packages * units_per_package if packages
    IF v_sold_by_piece AND v_pieces_quantity IS NOT NULL THEN
      UPDATE products
      SET stock_on_hand = stock_on_hand - v_pieces_quantity
      WHERE id = (v_line->>'product_id')::UUID;

      INSERT INTO stock_movements (
        business_id, product_id, movement_type,
        quantity, reference_id, created_by
      ) VALUES (
        p_business_id,
        (v_line->>'product_id')::UUID,
        'order_out',
        -v_pieces_quantity,
        v_order_id,
        v_driver_id
      );
    ELSE
      -- Package sales: deduct quantity * units_per_package
      UPDATE products
      SET stock_on_hand = stock_on_hand - ((v_line->>'quantity')::INTEGER * (v_line->>'units_per_package')::INTEGER)
      WHERE id = (v_line->>'product_id')::UUID;

      INSERT INTO stock_movements (
        business_id, product_id, movement_type,
        quantity, reference_id, created_by
      ) VALUES (
        p_business_id,
        (v_line->>'product_id')::UUID,
        'order_out',
        -((v_line->>'quantity')::INTEGER * (v_line->>'units_per_package')::INTEGER),
        v_order_id,
        v_driver_id
      );
    END IF;
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


-- ============================================================
-- 2) Create update_order_payment_status RPC
-- ============================================================
-- Updates order payment status, paid amount, paid_at timestamp,
-- adjusts store credit balance, creates payment record linked to order

CREATE OR REPLACE FUNCTION update_order_payment_status(
  p_order_id UUID,
  p_business_id UUID,
  p_payment_status TEXT,  -- 'unpaid', 'partial', 'paid'
  p_paid_amount NUMERIC,
  p_driver_id UUID DEFAULT NULL,
  p_store_id UUID DEFAULT NULL,
  p_method TEXT DEFAULT 'cash'
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_store RECORD;
  v_prev_balance NUMERIC;
  v_new_balance NUMERIC;
  v_payment_id UUID;
  v_driver UUID := auth.uid();
BEGIN
  -- ── Auth checks ──────────────────────────────────────────
  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF get_user_role() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: deactivated or invalid role';
  END IF;

  IF p_business_id != get_user_business_id() THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- ── Validate payment status ──────────────────────────────
  IF p_payment_status NOT IN ('unpaid', 'partial', 'paid') THEN
    RAISE EXCEPTION 'invalid payment_status: must be unpaid, partial, or paid';
  END IF;

  -- ── Get current order ────────────────────────────────────
  SELECT o.* INTO v_order
  FROM orders o
  WHERE o.id = p_order_id AND o.business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found or not in business';
  END IF;

  -- Get store credit balance
  SELECT credit_balance INTO v_prev_balance
  FROM stores
  WHERE id = v_order.store_id;

  -- ── Validate paid amount ─────────────────────────────────
  IF p_paid_amount < 0 THEN
    RAISE EXCEPTION 'paid_amount cannot be negative';
  END IF;

  IF p_paid_amount > v_order.total THEN
    RAISE EXCEPTION 'paid_amount cannot exceed order total';
  END IF;

  -- ── Validate transition ──────────────────────────────────
  IF v_order.payment_status = 'paid' AND p_payment_status != 'paid' THEN
    RAISE EXCEPTION 'cannot change payment status from paid';
  END IF;

  -- ── Determine new balance ────────────────────────────────
  v_new_balance := v_prev_balance + p_paid_amount;

  -- ── Update order ─────────────────────────────────────────
  UPDATE orders
  SET payment_status = p_payment_status,
      paid_amount = p_paid_amount,
      paid_at = CASE WHEN p_payment_status = 'paid' THEN NOW() ELSE paid_at END
  WHERE id = p_order_id;

  -- ── Update store credit balance ──────────────────────────
  UPDATE stores
  SET credit_balance = v_new_balance
  WHERE id = v_order.store_id;

  -- ── Create payment record ────────────────────────────────
  v_payment_id := gen_random_uuid();

  INSERT INTO payments (
    id, business_id, store_id, driver_id, order_id,
    amount, method, previous_balance, new_balance
  ) VALUES (
    v_payment_id, p_business_id, v_order.store_id, 
    COALESCE(p_driver_id, v_driver), p_order_id,
    p_paid_amount, p_method, v_prev_balance, v_new_balance
  );

  -- ── Return updated data ──────────────────────────────────
  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'payment_id', v_payment_id,
    'payment_status', p_payment_status,
    'paid_amount', p_paid_amount,
    'store_new_balance', v_new_balance,
    'created_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 3) Grant execute permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION create_order_atomic(UUID, UUID, UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION update_order_payment_status(UUID, UUID, TEXT, NUMERIC, UUID, UUID, TEXT) TO authenticated;