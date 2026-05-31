-- Allow owners to create orders directly (like drivers)
-- Also relax create_order_atomic role check

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
