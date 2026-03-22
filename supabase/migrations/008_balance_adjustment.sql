-- Phase 4 Plan 03: Balance adjustment table and RPC

-- ============================================================
-- balance_adjustments table: Audit log for manual balance changes
-- ============================================================
CREATE TABLE balance_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  store_id UUID NOT NULL REFERENCES stores(id),
  adjusted_by UUID NOT NULL,
  amount NUMERIC NOT NULL,
  reason TEXT NOT NULL,
  previous_balance NUMERIC NOT NULL,
  new_balance NUMERIC NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE balance_adjustments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own business adjustments"
  ON balance_adjustments FOR ALL
  USING (business_id = (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID);

-- ============================================================
-- adjust_store_balance: Adjust balance and log with audit trail
-- adjusted_by derived from auth.uid() (non-spoofable)
-- ============================================================
CREATE OR REPLACE FUNCTION adjust_store_balance(
  p_store_id UUID,
  p_business_id UUID,
  p_amount NUMERIC,
  p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
  v_store RECORD;
  v_new_balance NUMERIC;
  v_user_id UUID;
BEGIN
  -- Authorization
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Get authenticated user ID from JWT (non-spoofable)
  v_user_id := auth.uid();

  -- Reject zero adjustments
  IF p_amount = 0 THEN
    RAISE EXCEPTION 'amount_cannot_be_zero';
  END IF;

  -- Lock and read store
  SELECT id, credit_balance INTO v_store
  FROM stores
  WHERE id = p_store_id AND business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'store_not_found';
  END IF;

  v_new_balance := v_store.credit_balance + p_amount;

  -- Update store balance
  UPDATE stores SET credit_balance = v_new_balance
    WHERE id = p_store_id;

  -- Log the adjustment
  INSERT INTO balance_adjustments (business_id, store_id, adjusted_by, amount, reason, previous_balance, new_balance)
  VALUES (p_business_id, p_store_id, v_user_id, p_amount, p_reason, v_store.credit_balance, v_new_balance);

  RETURN jsonb_build_object(
    'previous_balance', v_store.credit_balance,
    'new_balance', v_new_balance,
    'amount', p_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION adjust_store_balance(UUID, UUID, NUMERIC, TEXT) TO authenticated;
