-- Migration 028: Stock is fractional PACKAGES, not pieces
-- Created: 2026-08-02
--
-- ROOT CAUSE
-- products.stock_on_hand is denominated in PACKAGES everywhere in the system:
--   * replenish_stock_from_purchase (013)  stock += purchase_order_lines.quantity
--   * adjust_stock                 (014/016) stock += p_quantity
--   * create_driver_load / returns (020/021) stock -= / += packages
--   * create_order_atomic          (013/017/021/024) stock -= order_lines.quantity
--   * the cart UI clamps the package stepper directly against stock_on_hand
--
-- Migration 025 changed ONLY the order-deduction side to piece units, and 027
-- generalised that to `packages * units_per_package + pieces`. That subtracts a
-- PIECE count from a PACKAGE-denominated column, so selling one 15-piece package
-- out of a stock of 1 produced 1 - 15 = -14.
--
-- The same unit error exists on both restore paths, which under-restore on
-- cancellation: cancel_order (021) and restore_stock_for_cancellation (027) add
-- back only order_lines.quantity, leaving a permanent shortfall for any order
-- that was deducted in pieces.
--
-- FIX
-- Keep the package denomination the whole system already uses, and make it
-- FRACTIONAL so loose pieces deduct proportionally: selling 3 pieces from a
-- 15-piece package removes 0.2 packages. All arithmetic is performed in exact
-- piece space and rounded back to whole pieces, so repeated piece sales can
-- never drift (selling 15 single pieces from 1 package lands exactly on 0).

-- ============================================================
-- 1) Widen the stock columns to fractional packages
-- ============================================================
-- products_stock_non_negative (migration 018) is deliberately left alone.
-- Where that constraint is enforced, an over-deduction raised at order time
-- instead of being stored, so such a database has no negative rows for the
-- type change to trip over and nothing for the repair in step 7 to correct.
-- Where it is absent, there is nothing to preserve. Either way this migration
-- neither adds nor removes the guard.
ALTER TABLE products        ALTER COLUMN stock_on_hand TYPE NUMERIC;
ALTER TABLE stock_movements ALTER COLUMN quantity      TYPE NUMERIC;


-- ============================================================
-- 2) Shared helper: apply a signed PIECE delta to package stock
-- ============================================================
-- Returns the resulting PACKAGE delta so callers log exactly what changed,
-- keeping the stock_movements ledger in sync with stock_on_hand to the digit.
--
-- Working in piece space and ROUND()ing back to whole pieces is what removes
-- accumulated division dust: 1/15 is not representable exactly, but
-- ROUND(stock * upp) always recovers the true integer piece count.
--
-- NOT security definer and NOT granted to clients — it is an internal helper
-- for the SECURITY DEFINER RPCs below, which already run as the owner.
CREATE OR REPLACE FUNCTION apply_stock_piece_delta(
  p_product_id UUID,
  p_pieces     NUMERIC   -- signed: negative removes stock, positive restores it
) RETURNS NUMERIC AS $$
DECLARE
  v_upp INTEGER;
  v_old NUMERIC;
  v_new NUMERIC;
BEGIN
  SELECT COALESCE(units_per_package, 1), stock_on_hand
    INTO v_upp, v_old
  FROM products
  WHERE id = p_product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'product_not_found: %', p_product_id;
  END IF;

  IF v_upp < 1 THEN
    v_upp := 1;
  END IF;

  v_new := ROUND(v_old * v_upp + p_pieces) / v_upp;

  UPDATE products SET stock_on_hand = v_new WHERE id = p_product_id;

  RETURN v_new - v_old;
END;
$$ LANGUAGE plpgsql;

REVOKE ALL ON FUNCTION apply_stock_piece_delta(UUID, NUMERIC) FROM PUBLIC;
REVOKE ALL ON FUNCTION apply_stock_piece_delta(UUID, NUMERIC) FROM anon;
REVOKE ALL ON FUNCTION apply_stock_piece_delta(UUID, NUMERIC) FROM authenticated;


-- ============================================================
-- 3) adjust_stock — accept fractional packages
-- ============================================================
-- The INTEGER overload must go, or PostgREST can resolve to either one.
DROP FUNCTION IF EXISTS adjust_stock(UUID, INTEGER, TEXT);

CREATE OR REPLACE FUNCTION adjust_stock(
  p_product_id UUID,
  p_quantity   NUMERIC,   -- signed, in packages (may be fractional)
  p_notes      TEXT
) RETURNS void AS $$
DECLARE
  v_business_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owners can adjust stock';
  END IF;

  SELECT business_id INTO v_business_id FROM products WHERE id = p_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'product_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  UPDATE products
  SET stock_on_hand = stock_on_hand + p_quantity
  WHERE id = p_product_id;

  INSERT INTO stock_movements (business_id, product_id, movement_type, quantity, notes, created_by)
  VALUES (v_business_id, p_product_id, 'adjustment', p_quantity, p_notes, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION adjust_stock(UUID, NUMERIC, TEXT) TO authenticated;


-- ============================================================
-- 4) create_order_atomic — deduct fractional packages
-- ============================================================
-- Supersedes migration 027. Only Step 5 changes: the deduction is converted
-- from piece units into package units. Everything else is carried over verbatim.
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
  v_total_pieces INTEGER;
  v_product_id UUID;
  v_pkg_delta NUMERIC;
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

  -- ── Step 5: Deduct stock, in PACKAGES ────────────────────
  -- Whole packages deduct 1:1; loose pieces deduct their fraction of a package.
  -- units_per_package is read from the product, never from the client JSON.
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items)
  LOOP
    v_product_id := (v_line->>'product_id')::UUID;
    v_packages := COALESCE((v_line->>'quantity')::INTEGER, 0);
    v_pieces := COALESCE((v_line->>'pieces_quantity')::INTEGER, 0);

    SELECT COALESCE(units_per_package, 1) INTO v_units_per_package
    FROM products
    WHERE id = v_product_id;

    IF v_units_per_package IS NULL OR v_units_per_package < 1 THEN
      v_units_per_package := 1;
    END IF;

    v_total_pieces := v_packages * v_units_per_package + v_pieces;

    IF v_total_pieces <> 0 THEN
      v_pkg_delta := apply_stock_piece_delta(v_product_id, -v_total_pieces);

      INSERT INTO stock_movements (
        business_id, product_id, movement_type,
        quantity, reference_id, created_by
      ) VALUES (
        p_business_id, v_product_id, 'order_out',
        v_pkg_delta, v_order_id, v_driver_id
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
-- 5) restore_stock_for_cancellation — restore fractional packages
-- ============================================================
CREATE OR REPLACE FUNCTION restore_stock_for_cancellation(p_order_id UUID)
RETURNS void AS $$
DECLARE
  v_business_id UUID;
  line RECORD;
  v_total_pieces INTEGER;
  v_pkg_delta NUMERIC;
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

  -- Idempotency guard: skip if already restored (cancel_order restores inline)
  IF EXISTS (
    SELECT 1 FROM stock_movements
    WHERE reference_id = p_order_id AND movement_type = 'cancellation_restore'
  ) THEN
    RETURN;
  END IF;

  FOR line IN
    SELECT ol.product_id,
           ol.quantity,
           COALESCE(ol.pieces_quantity, 0) AS pieces,
           GREATEST(COALESCE(p.units_per_package, 1), 1) AS upp
    FROM order_lines ol
    JOIN products p ON p.id = ol.product_id
    WHERE ol.order_id = p_order_id
  LOOP
    v_total_pieces := line.quantity * line.upp + line.pieces;

    IF v_total_pieces <> 0 THEN
      v_pkg_delta := apply_stock_piece_delta(line.product_id, v_total_pieces);

      INSERT INTO stock_movements (
        business_id, product_id, movement_type, quantity, reference_id, created_by
      ) VALUES (
        v_business_id, line.product_id, 'cancellation_restore', v_pkg_delta,
        p_order_id, auth.uid()
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 6) cancel_order — restore the same fractional packages that were deducted
-- ============================================================
-- Supersedes migration 021. Only the stock-restore loop changes; it previously
-- added back order_lines.quantity alone, which under-restored every piece sale.
CREATE OR REPLACE FUNCTION cancel_order(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_active_load_id UUID;
  v_line RECORD;
  v_total_pieces INTEGER;
  v_pkg_delta NUMERIC;
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
    SELECT ol.product_id,
           ol.quantity,
           COALESCE(ol.pieces_quantity, 0) AS pieces,
           GREATEST(COALESCE(p.units_per_package, 1), 1) AS upp
    FROM order_lines ol
    JOIN products p ON p.id = ol.product_id
    WHERE ol.order_id = p_order_id
  LOOP
    v_total_pieces := v_line.quantity * v_line.upp + v_line.pieces;

    IF v_total_pieces <> 0 THEN
      v_pkg_delta := apply_stock_piece_delta(v_line.product_id, v_total_pieces);

      INSERT INTO stock_movements (
        business_id, product_id, movement_type,
        quantity, reference_id, created_by
      ) VALUES (
        v_order.business_id, v_line.product_id, 'cancellation_restore',
        v_pkg_delta, p_order_id, auth.uid()
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object('status', 'cancelled', 'reversed_amount', v_order.total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 7) Repair stock that migrations 025/027 over-deducted
-- ============================================================
-- Rather than pattern-matching the buggy formula, this recomputes what each
-- order SHOULD have taken out of stock and compares it to what the ledger says
-- actually happened. Orders deducted correctly (pre-025, or upp = 1) come out
-- to a zero delta and are skipped, so this is safe on any migration history.
--
-- A cancelled order should net to zero regardless of how it was deducted, which
-- also repairs the shortfall left by cancel_order's packages-only restore.
--
-- Idempotent: each repaired (order, product) gets a marker movement.
DO $$
DECLARE
  r RECORD;
  v_delta NUMERIC;
BEGIN
  FOR r IN
    WITH expected AS (
      SELECT ol.order_id,
             ol.product_id,
             SUM(ol.quantity)::NUMERIC                       AS packages,
             SUM(COALESCE(ol.pieces_quantity, 0))::NUMERIC   AS pieces,
             GREATEST(COALESCE(MAX(p.units_per_package), 1), 1) AS upp
      FROM order_lines ol
      JOIN products p ON p.id = ol.product_id
      GROUP BY ol.order_id, ol.product_id
    ),
    applied AS (
      SELECT sm.reference_id AS order_id,
             sm.product_id,
             SUM(sm.quantity) AS net_applied
      FROM stock_movements sm
      WHERE sm.movement_type IN ('order_out', 'cancellation_restore')
        AND sm.reference_id IS NOT NULL
      GROUP BY sm.reference_id, sm.product_id
    )
    SELECT e.order_id,
           e.product_id,
           o.business_id,
           o.driver_id,
           a.net_applied,
           CASE WHEN o.status = 'cancelled'
                THEN 0
                ELSE -(e.packages + e.pieces / e.upp)
           END AS correct_net
    FROM expected e
    JOIN applied a ON a.order_id = e.order_id AND a.product_id = e.product_id
    JOIN orders  o ON o.id = e.order_id
    WHERE NOT EXISTS (
      SELECT 1 FROM stock_movements m
      WHERE m.reference_id = e.order_id
        AND m.product_id   = e.product_id
        AND m.movement_type = 'adjustment'
        AND m.notes = 'migration_028_piece_unit_repair'
    )
  LOOP
    v_delta := r.correct_net - r.net_applied;
    CONTINUE WHEN ROUND(v_delta, 6) = 0;

    UPDATE products
    SET stock_on_hand = stock_on_hand + v_delta
    WHERE id = r.product_id;

    INSERT INTO stock_movements (
      business_id, product_id, movement_type,
      quantity, reference_id, notes, created_by
    ) VALUES (
      r.business_id, r.product_id, 'adjustment',
      v_delta, r.order_id, 'migration_028_piece_unit_repair', r.driver_id
    );
  END LOOP;
END $$;
