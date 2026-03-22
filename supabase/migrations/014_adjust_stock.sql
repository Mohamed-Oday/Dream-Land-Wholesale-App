-- Phase 7 Plan 02: Stock adjustment RPC function

-- ============================================================
-- adjust_stock: Manual stock correction with reason
-- ============================================================
CREATE OR REPLACE FUNCTION adjust_stock(
  p_product_id UUID,
  p_quantity INTEGER,
  p_notes TEXT
) RETURNS void AS $$
DECLARE
  v_business_id UUID;
BEGIN
  -- Auth check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- Reject zero quantity
  IF p_quantity = 0 THEN
    RAISE EXCEPTION 'zero_quantity_adjustment';
  END IF;

  -- Get product business_id and verify ownership
  SELECT business_id INTO v_business_id
  FROM products WHERE id = p_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'product_not_found';
  END IF;

  IF v_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Update product stock
  UPDATE products
  SET stock_on_hand = stock_on_hand + p_quantity
  WHERE id = p_product_id;

  -- Log movement
  INSERT INTO stock_movements (business_id, product_id, movement_type, quantity, notes, created_by)
  VALUES (v_business_id, p_product_id, 'adjustment', p_quantity, p_notes, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION adjust_stock(UUID, INTEGER, TEXT) TO authenticated;
