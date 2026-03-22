-- Phase 2: RPC functions
-- SECURITY DEFINER bypasses RLS where needed

-- ============================================================
-- has_users: Check if any users exist (bypasses RLS for init screen)
-- ============================================================
CREATE OR REPLACE FUNCTION has_users() RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM users LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Payment RPC functions for atomic balance updates

-- ============================================================
-- create_payment: Atomically records payment + updates store balance
-- ============================================================
CREATE OR REPLACE FUNCTION create_payment(
  p_store_id UUID,
  p_amount NUMERIC,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_previous NUMERIC;
  v_new NUMERIC;
  v_payment_id UUID;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Lock store row to prevent race conditions on concurrent payments
  SELECT credit_balance INTO v_previous
  FROM stores
  WHERE id = p_store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'store not found: %', p_store_id;
  END IF;

  v_new := v_previous - p_amount;

  -- Insert payment record
  INSERT INTO payments (business_id, store_id, driver_id, amount, method, previous_balance, new_balance)
  VALUES (p_business_id, p_store_id, auth.uid(), p_amount, 'cash', v_previous, v_new)
  RETURNING id INTO v_payment_id;

  -- Update store balance
  UPDATE stores SET credit_balance = v_new WHERE id = p_store_id;

  RETURN jsonb_build_object(
    'id', v_payment_id,
    'previous_balance', v_previous,
    'new_balance', v_new
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- update_store_balance_on_order: Increases store debt after order
-- ============================================================
CREATE OR REPLACE FUNCTION update_store_balance_on_order(
  p_store_id UUID,
  p_order_total NUMERIC
) RETURNS VOID AS $$
BEGIN
  -- Atomic UPDATE — credit_balance + p_order_total is inherently safe
  UPDATE stores
  SET credit_balance = credit_balance + p_order_total
  WHERE id = p_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
