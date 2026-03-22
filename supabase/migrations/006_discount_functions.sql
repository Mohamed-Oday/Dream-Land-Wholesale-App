-- Phase 3 Plan 03: Discount approval RPC functions

-- ============================================================
-- approve_discount: Approve a pending discount on an order
-- ============================================================
CREATE OR REPLACE FUNCTION approve_discount(
  p_order_id UUID,
  p_approved_by UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Verify order exists and is pending
  SELECT id, discount_status INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.discount_status != 'pending' THEN
    RAISE EXCEPTION 'discount_already_processed';
  END IF;

  -- Approve the discount
  UPDATE orders
  SET discount_status = 'approved',
      discount_approved_by = p_approved_by
  WHERE id = p_order_id;

  RETURN jsonb_build_object('status', 'approved', 'order_id', p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- reject_discount: Reject a pending discount, recalculate total, adjust store balance
-- ============================================================
CREATE OR REPLACE FUNCTION reject_discount(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_new_total NUMERIC;
BEGIN
  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get order details with lock
  SELECT id, discount, discount_status, subtotal, tax_amount, store_id
  INTO v_order
  FROM orders
  WHERE id = p_order_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.discount_status != 'pending' THEN
    RAISE EXCEPTION 'discount_already_processed';
  END IF;

  -- Recalculate total without discount
  v_new_total := v_order.subtotal + v_order.tax_amount;

  -- Update order: reject discount, fix total
  UPDATE orders
  SET discount_status = 'rejected',
      total = v_new_total
  WHERE id = p_order_id;

  -- Add discount amount back to store credit_balance (reverse the deduction)
  UPDATE stores
  SET credit_balance = credit_balance + v_order.discount
  WHERE id = v_order.store_id;

  RETURN jsonb_build_object(
    'status', 'rejected',
    'order_id', p_order_id,
    'new_total', v_new_total,
    'discount_reversed', v_order.discount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- reject_expired_discounts: Auto-reject all pending discounts older than 3 minutes
-- ============================================================
CREATE OR REPLACE FUNCTION reject_expired_discounts(
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_count INTEGER := 0;
  v_new_total NUMERIC;
BEGIN
  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Process each expired pending discount
  FOR v_order IN
    SELECT id, discount, subtotal, tax_amount, store_id
    FROM orders
    WHERE business_id = p_business_id
      AND discount_status = 'pending'
      AND created_at < now() - interval '3 minutes'
    FOR UPDATE
  LOOP
    v_new_total := v_order.subtotal + v_order.tax_amount;

    UPDATE orders
    SET discount_status = 'rejected',
        total = v_new_total
    WHERE id = v_order.id;

    UPDATE stores
    SET credit_balance = credit_balance + v_order.discount
    WHERE id = v_order.store_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('rejected_count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION approve_discount(UUID, UUID, UUID) TO anon;
GRANT EXECUTE ON FUNCTION approve_discount(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_discount(UUID, UUID) TO anon;
GRANT EXECUTE ON FUNCTION reject_discount(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_expired_discounts(UUID) TO anon;
GRANT EXECUTE ON FUNCTION reject_expired_discounts(UUID) TO authenticated;
