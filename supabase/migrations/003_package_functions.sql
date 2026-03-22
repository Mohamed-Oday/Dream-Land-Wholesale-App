-- Phase 2 Plan 02: Package tracking RPC functions

-- ============================================================
-- create_package_log: Atomically records package given/collected + updates balance
-- ============================================================
CREATE OR REPLACE FUNCTION create_package_log(
  p_store_id UUID,
  p_product_id UUID,
  p_business_id UUID,
  p_given INTEGER DEFAULT 0,
  p_collected INTEGER DEFAULT 0,
  p_order_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_previous INTEGER;
  v_balance INTEGER;
  v_log_id UUID;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get current balance with row lock to prevent race conditions
  SELECT balance_after INTO v_previous
  FROM package_logs
  WHERE store_id = p_store_id AND product_id = p_product_id
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    v_previous := 0;
  END IF;

  v_balance := v_previous + p_given - p_collected;

  -- Insert package log
  INSERT INTO package_logs (business_id, store_id, driver_id, product_id, order_id, given, collected, balance_after)
  VALUES (p_business_id, p_store_id, auth.uid(), p_product_id, p_order_id, p_given, p_collected, v_balance)
  RETURNING id INTO v_log_id;

  RETURN jsonb_build_object(
    'id', v_log_id,
    'previous_balance', v_previous,
    'balance_after', v_balance
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- get_package_balances_for_store: Current balance for all products at a store
-- ============================================================
CREATE OR REPLACE FUNCTION get_package_balances_for_store(
  p_store_id UUID
) RETURNS TABLE (product_id UUID, balance INTEGER) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (pl.product_id) pl.product_id, pl.balance_after AS balance
  FROM package_logs pl
  WHERE pl.store_id = p_store_id
  ORDER BY pl.product_id, pl.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_package_log(UUID, UUID, UUID, INTEGER, INTEGER, UUID) TO anon;
GRANT EXECUTE ON FUNCTION create_package_log(UUID, UUID, UUID, INTEGER, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_package_balances_for_store(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_package_balances_for_store(UUID) TO authenticated;
