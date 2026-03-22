-- Phase 4 Plan 01: Order cancellation RPC function

-- ============================================================
-- cancel_order: Cancel a 'created' order and reverse store balance
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

  -- Update order status
  UPDATE orders SET status = 'cancelled'
    WHERE id = p_order_id;

  -- If discount was pending, neutralize it to prevent auto-reject from double-processing
  IF v_order.discount_status = 'pending' THEN
    UPDATE orders SET discount_status = 'none'
      WHERE id = p_order_id;
  END IF;

  -- Reverse store balance (subtract order total from credit_balance)
  UPDATE stores SET credit_balance = credit_balance - v_order.total
    WHERE id = v_order.store_id AND business_id = p_business_id;

  RETURN jsonb_build_object('status', 'cancelled', 'reversed_amount', v_order.total);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION cancel_order(UUID, UUID) TO authenticated;
