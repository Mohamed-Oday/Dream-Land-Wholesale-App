-- Migration 029: stock never goes below zero; cancellations restore what was
-- actually deducted
-- Created: 2026-09-03
--
-- WHY
-- Products that exist in the warehouse but were never counted into the app
-- show stock 0. The owner wants such products to be sellable anyway: the app
-- no longer blocks the sale, and the database clamps the deduction at 0 so
-- stock_on_hand is never negative (a "+n / -n but not below zero" ledger).
--
-- Because a clamped deduction removes fewer packages than the order line
-- says, a later cancellation must add back what the ledger says was removed
-- (the 'order_out' movement), not the line quantity — otherwise an order of
-- 5 on a stock of 0 would cancel into a stock of 5.
--
-- Supersedes the same three functions from migration 028. Signatures,
-- grants and authorization checks are unchanged.

-- ============================================================
-- 1) apply_stock_piece_delta — clamp at zero, return the real delta
-- ============================================================
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

  -- Never below zero: selling from an uncounted product leaves it at 0.
  v_new := GREATEST(ROUND(v_old * v_upp + p_pieces) / v_upp, 0);

  UPDATE products SET stock_on_hand = v_new WHERE id = p_product_id;

  -- The caller logs this as the movement quantity, so the ledger records
  -- what really changed (possibly less than requested).
  RETURN v_new - v_old;
END;
$$ LANGUAGE plpgsql;

REVOKE ALL ON FUNCTION apply_stock_piece_delta(UUID, NUMERIC) FROM PUBLIC;
REVOKE ALL ON FUNCTION apply_stock_piece_delta(UUID, NUMERIC) FROM anon;
REVOKE ALL ON FUNCTION apply_stock_piece_delta(UUID, NUMERIC) FROM authenticated;


-- ============================================================
-- 2) Helper: pieces actually deducted for one (order, product)
-- ============================================================
-- Reads the 'order_out' movements (packages, negative) and converts them to
-- pieces. Falls back to the order line when no movement was logged (orders
-- created before the ledger existed).
CREATE OR REPLACE FUNCTION pieces_deducted_for_order_line(
  p_order_id   UUID,
  p_product_id UUID
) RETURNS INTEGER AS $$
DECLARE
  v_upp INTEGER;
  v_pkg NUMERIC;
  v_line RECORD;
BEGIN
  SELECT GREATEST(COALESCE(units_per_package, 1), 1) INTO v_upp
  FROM products WHERE id = p_product_id;

  SELECT -SUM(quantity) INTO v_pkg
  FROM stock_movements
  WHERE reference_id = p_order_id
    AND product_id = p_product_id
    AND movement_type = 'order_out';

  IF v_pkg IS NOT NULL THEN
    RETURN ROUND(v_pkg * v_upp);
  END IF;

  SELECT quantity, COALESCE(pieces_quantity, 0) AS pieces INTO v_line
  FROM order_lines
  WHERE order_id = p_order_id AND product_id = p_product_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  RETURN v_line.quantity * v_upp + v_line.pieces;
END;
$$ LANGUAGE plpgsql;

REVOKE ALL ON FUNCTION pieces_deducted_for_order_line(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION pieces_deducted_for_order_line(UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION pieces_deducted_for_order_line(UUID, UUID) FROM authenticated;


-- ============================================================
-- 3) restore_stock_for_cancellation — restore the ledger amount
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
    SELECT DISTINCT ol.product_id
    FROM order_lines ol
    WHERE ol.order_id = p_order_id
  LOOP
    v_total_pieces := pieces_deducted_for_order_line(p_order_id, line.product_id);

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
-- 4) cancel_order — same, inline
-- ============================================================
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

  -- ── Restore warehouse stock (what the ledger removed) + log movements ──
  FOR v_line IN
    SELECT DISTINCT ol.product_id
    FROM order_lines ol
    WHERE ol.order_id = p_order_id
  LOOP
    v_total_pieces := pieces_deducted_for_order_line(p_order_id, v_line.product_id);

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
