-- Migration 027: Additive package+piece orders, corrected payment RPC, symmetric restore
-- Created: 2026-07-23
--
-- Supersedes create_order_atomic / update_order_payment_status from migration 025
-- and restore_stock_for_cancellation from migration 013. Fixes audit findings:
--   #1  create_order_atomic read units_per_package from the JSON line (which the
--       client never sent) -> quantity*NULL = NULL -> NOT NULL stock violation.
--       Now reads units_per_package from products and deducts ADDITIVELY:
--       stock = packages * units_per_package + loose pieces.
--   #3  update_order_payment_status ADDED the paid amount to stores.credit_balance
--       (store debt), doubling it. Now SUBTRACTS the incremental delta.
--   #7  It re-applied the full absolute amount on every call. Now applies only the
--       delta vs the previously recorded paid_amount and is idempotent on retry.
--   #8  It trusted a client-supplied p_driver_id unchecked (SECURITY DEFINER bypass
--       of the payments RLS). Now p_driver_id is validated against the business.
--   #4  restore_stock_for_cancellation restored order_lines.quantity only (0 for
--       piece sales). Now restores additively to mirror the deduction.
--
-- Depends on the columns added in migration 026.

-- ============================================================
-- 1) create_order_atomic — additive packages + pieces
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
  v_user_role TEXT;
  v_packages INTEGER;
  v_pieces INTEGER;
  v_sold_by_piece BOOLEAN;
  v_units_per_package INTEGER;
  v_total_units INTEGER;
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
      'id', o.id, 'store_id', o.store_id, 'driver_id', o.driver_id,
      'business_id', o.business_id, 'subtotal', o.subtotal,
      'tax_percentage', o.tax_percentage, 'tax_amount', o.tax_amount,
      'discount', o.discount, 'discount_status', o.discount_status,
      'total', o.total, 'status', o.status, 'created_at', o.created_at
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
    v_packages := COALESCE((v_line->>'quantity')::INTEGER, 0);
    v_pieces := COALESCE((v_line->>'pieces_quantity')::INTEGER, 0);
    v_sold_by_piece := COALESCE((v_line->>'sold_by_piece')::BOOLEAN, v_pieces > 0);

    INSERT INTO order_lines (
      id, order_id, product_id, quantity, unit_price, line_total,
      sold_by_piece, pieces_quantity
    ) VALUES (
      v_line_id, v_order_id,
      (v_line->>'product_id')::UUID,
      v_packages,
      (v_line->>'unit_price')::NUMERIC,
      (v_line->>'line_total')::NUMERIC,
      v_sold_by_piece,
      NULLIF(v_pieces, 0)
    );
  END LOOP;

  -- ── Step 3: UPDATE store credit balance (adds the order as debt) ──
  UPDATE stores
  SET credit_balance = credit_balance + p_total
  WHERE id = p_store_id;

  -- ── Step 4: Package logs for returnable products (whole packages only) ──
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
  LOOP
    v_packages := COALESCE((v_line->>'quantity')::INTEGER, 0);

    SELECT id, has_returnable_packaging
    INTO v_product
    FROM products
    WHERE id = (v_line->>'product_id')::UUID;

    IF v_product.has_returnable_packaging AND v_packages > 0 THEN
      SELECT balance_after INTO v_prev_pkg_balance
      FROM package_logs
      WHERE store_id = p_store_id AND product_id = v_product.id
      ORDER BY created_at DESC
      LIMIT 1
      FOR UPDATE;

      IF NOT FOUND THEN
        v_prev_pkg_balance := 0;
      END IF;

      v_new_pkg_balance := v_prev_pkg_balance + v_packages;

      INSERT INTO package_logs (
        business_id, store_id, driver_id, product_id,
        order_id, given, collected, balance_after
      ) VALUES (
        p_business_id, p_store_id, v_driver_id, v_product.id,
        v_order_id, v_packages, 0, v_new_pkg_balance
      );
    END IF;
  END LOOP;

  -- ── Step 5: Deduct stock = packages * units_per_package + loose pieces ──
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
  LOOP
    v_packages := COALESCE((v_line->>'quantity')::INTEGER, 0);
    v_pieces := COALESCE((v_line->>'pieces_quantity')::INTEGER, 0);

    -- units_per_package is read from the product, never from the client JSON.
    SELECT COALESCE(units_per_package, 1) INTO v_units_per_package
    FROM products
    WHERE id = (v_line->>'product_id')::UUID;
    v_units_per_package := COALESCE(v_units_per_package, 1);

    v_total_units := v_packages * v_units_per_package + v_pieces;

    IF v_total_units <> 0 THEN
      UPDATE products
      SET stock_on_hand = stock_on_hand - v_total_units
      WHERE id = (v_line->>'product_id')::UUID;

      INSERT INTO stock_movements (
        business_id, product_id, movement_type,
        quantity, reference_id, created_by
      ) VALUES (
        p_business_id,
        (v_line->>'product_id')::UUID,
        'order_out',
        -v_total_units,
        v_order_id,
        v_driver_id
      );
    END IF;
  END LOOP;

  -- ── Return order data ────────────────────────────────────
  RETURN jsonb_build_object(
    'id', v_order_id, 'store_id', p_store_id, 'driver_id', v_driver_id,
    'business_id', p_business_id, 'subtotal', p_subtotal,
    'tax_percentage', p_tax_percentage, 'tax_amount', p_tax_amount,
    'discount', p_discount, 'discount_status', p_discount_status,
    'total', p_total, 'status', 'created', 'created_at', v_created_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 2) update_order_payment_status — correct sign, delta, driver check
-- ============================================================
-- p_paid_amount is the CUMULATIVE amount paid on the order to date.
CREATE OR REPLACE FUNCTION update_order_payment_status(
  p_order_id UUID,
  p_business_id UUID,
  p_payment_status TEXT,          -- 'unpaid', 'partial', 'paid'
  p_paid_amount NUMERIC,
  p_driver_id UUID DEFAULT NULL,
  p_store_id UUID DEFAULT NULL,
  p_method TEXT DEFAULT 'cash'
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_prev_balance NUMERIC;
  v_new_balance NUMERIC;
  v_delta NUMERIC;
  v_payment_id UUID;
  v_driver UUID := auth.uid();
  v_effective_driver UUID;
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

  IF p_payment_status NOT IN ('unpaid', 'partial', 'paid') THEN
    RAISE EXCEPTION 'invalid payment_status: must be unpaid, partial, or paid';
  END IF;

  -- Optional driver attribution must belong to this business (no spoofing).
  IF p_driver_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM users WHERE id = p_driver_id AND business_id = p_business_id
  ) THEN
    RAISE EXCEPTION 'invalid driver_id: not in business';
  END IF;
  v_effective_driver := COALESCE(p_driver_id, v_driver);

  -- ── Load + lock order ────────────────────────────────────
  SELECT o.* INTO v_order
  FROM orders o
  WHERE o.id = p_order_id AND o.business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found or not in business';
  END IF;

  IF p_paid_amount < 0 THEN
    RAISE EXCEPTION 'paid_amount cannot be negative';
  END IF;

  IF p_paid_amount > v_order.total THEN
    RAISE EXCEPTION 'paid_amount cannot exceed order total';
  END IF;

  -- Incremental payment since the last recorded cumulative amount.
  v_delta := p_paid_amount - COALESCE(v_order.paid_amount, 0);

  -- Idempotent no-op (e.g. a retry re-sending the same amount + status).
  IF v_delta = 0 AND v_order.payment_status = p_payment_status THEN
    RETURN jsonb_build_object(
      'order_id', p_order_id,
      'payment_status', v_order.payment_status,
      'paid_amount', v_order.paid_amount,
      'unchanged', true
    );
  END IF;

  SELECT credit_balance INTO v_prev_balance
  FROM stores
  WHERE id = v_order.store_id
  FOR UPDATE;

  -- credit_balance is store DEBT; recording a payment REDUCES it by the delta.
  v_new_balance := v_prev_balance - v_delta;

  UPDATE orders
  SET payment_status = p_payment_status,
      paid_amount = p_paid_amount,
      paid_at = CASE WHEN p_payment_status = 'paid' THEN NOW() ELSE paid_at END
  WHERE id = p_order_id;

  UPDATE stores
  SET credit_balance = v_new_balance
  WHERE id = v_order.store_id;

  -- Only log a payment row for a positive incremental payment
  -- (payments.amount has a CHECK (amount > 0)).
  v_payment_id := NULL;
  IF v_delta > 0 THEN
    v_payment_id := gen_random_uuid();
    INSERT INTO payments (
      id, business_id, store_id, driver_id, order_id,
      amount, method, previous_balance, new_balance
    ) VALUES (
      v_payment_id, p_business_id, v_order.store_id,
      v_effective_driver, p_order_id,
      v_delta, p_method, v_prev_balance, v_new_balance
    );
  END IF;

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'payment_id', v_payment_id,
    'payment_status', p_payment_status,
    'paid_amount', p_paid_amount,
    'delta', v_delta,
    'store_new_balance', v_new_balance,
    'created_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 3) restore_stock_for_cancellation — additive restore
-- ============================================================
CREATE OR REPLACE FUNCTION restore_stock_for_cancellation(p_order_id UUID)
RETURNS void AS $$
DECLARE
  v_business_id UUID;
  line RECORD;
  v_units INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  SELECT business_id INTO v_business_id
  FROM orders WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Idempotency guard: skip if already restored
  IF EXISTS (
    SELECT 1 FROM stock_movements
    WHERE reference_id = p_order_id AND movement_type = 'cancellation_restore'
  ) THEN
    RETURN;
  END IF;

  -- Restore the same unit count that was deducted at creation:
  -- packages * units_per_package + loose pieces.
  FOR line IN
    SELECT ol.product_id,
           ol.quantity,
           COALESCE(ol.pieces_quantity, 0) AS pieces,
           COALESCE(p.units_per_package, 1) AS upp
    FROM order_lines ol
    JOIN products p ON p.id = ol.product_id
    WHERE ol.order_id = p_order_id
  LOOP
    v_units := line.quantity * line.upp + line.pieces;

    IF v_units <> 0 THEN
      UPDATE products
      SET stock_on_hand = stock_on_hand + v_units
      WHERE id = line.product_id;

      INSERT INTO stock_movements (
        business_id, product_id, movement_type, quantity, reference_id, created_by
      ) VALUES (
        v_business_id, line.product_id, 'cancellation_restore', v_units,
        p_order_id, auth.uid()
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 4) Grants
-- ============================================================
GRANT EXECUTE ON FUNCTION create_order_atomic(UUID, UUID, UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, NUMERIC, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION update_order_payment_status(UUID, UUID, TEXT, NUMERIC, UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_stock_for_cancellation(UUID) TO authenticated;
