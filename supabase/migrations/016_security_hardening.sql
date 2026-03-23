-- AEGIS REMEDIATION: Security Hardening (Phase 9, Plan 01)
-- Fixes: F-04-001 (JWT metadata spoofable), F-02-007/F-04-007/F-04-008 (missing role checks),
--        F-05-003/F-05-005 (audit trail writable by drivers), F-04-012 (unprotected balance update)

-- ============================================================
-- PART 1: JWT Metadata Protection Trigger
-- Prevents client-side modification of role and business_id
-- in raw_user_meta_data via auth.updateUser()
-- Finding: F-04-001
-- ============================================================

CREATE OR REPLACE FUNCTION protect_user_metadata()
RETURNS TRIGGER AS $$
BEGIN
  -- On UPDATE: if role or business_id changed, revert to OLD values
  IF OLD.raw_user_meta_data IS NOT NULL THEN
    -- Preserve role from being changed
    IF (OLD.raw_user_meta_data->>'role') IS NOT NULL
       AND (NEW.raw_user_meta_data->>'role') IS DISTINCT FROM (OLD.raw_user_meta_data->>'role') THEN
      NEW.raw_user_meta_data := jsonb_set(
        NEW.raw_user_meta_data,
        '{role}',
        to_jsonb(OLD.raw_user_meta_data->>'role')
      );
    END IF;
    -- Preserve business_id from being changed
    IF (OLD.raw_user_meta_data->>'business_id') IS NOT NULL
       AND (NEW.raw_user_meta_data->>'business_id') IS DISTINCT FROM (OLD.raw_user_meta_data->>'business_id') THEN
      NEW.raw_user_meta_data := jsonb_set(
        NEW.raw_user_meta_data,
        '{business_id}',
        to_jsonb(OLD.raw_user_meta_data->>'business_id')
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger fires BEFORE UPDATE so protected fields silently revert
-- INSERT (signUp) is not affected — trigger is UPDATE only
CREATE TRIGGER protect_user_metadata_trigger
  BEFORE UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION protect_user_metadata();

-- Prevent direct invocation of trigger function
REVOKE EXECUTE ON FUNCTION protect_user_metadata() FROM PUBLIC;


-- ============================================================
-- PART 2: Role Checks on SECURITY DEFINER Functions
-- ============================================================

-- ------------------------------------------------------------
-- 2a. approve_discount: Require owner role, use auth.uid() for approved_by
-- Finding: F-02-007, F-04-008
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION approve_discount(
  p_order_id UUID,
  p_approved_by UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Role check: only owner can approve discounts
  IF get_user_role() NOT IN ('owner') THEN
    RAISE EXCEPTION 'unauthorized: only owner can approve discounts';
  END IF;

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

  -- Approve the discount — use auth.uid() instead of client-supplied p_approved_by
  UPDATE orders
  SET discount_status = 'approved',
      discount_approved_by = auth.uid()
  WHERE id = p_order_id;

  RETURN jsonb_build_object('status', 'approved', 'order_id', p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2b. reject_discount: Require owner role
-- Finding: F-05-003
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION reject_discount(
  p_order_id UUID,
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_new_total NUMERIC;
BEGIN
  -- Role check: only owner can reject discounts
  IF get_user_role() NOT IN ('owner') THEN
    RAISE EXCEPTION 'unauthorized: only owner can reject discounts';
  END IF;

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

-- ------------------------------------------------------------
-- 2c. reject_expired_discounts: Require owner/admin role
-- Finding: F-05-003 (audit-added)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION reject_expired_discounts(
  p_business_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_count INTEGER := 0;
  v_new_total NUMERIC;
BEGIN
  -- Role check: only owner/admin can trigger expired discount rejection
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can reject expired discounts';
  END IF;

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

-- ------------------------------------------------------------
-- 2d. cancel_order: Require owner/admin OR order's own driver
-- Finding: F-05-003
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- 2e. adjust_stock: Require owner/admin role
-- Finding: F-04-007
-- ------------------------------------------------------------
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

  -- Role check: only owner/admin can adjust stock
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can adjust stock';
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

-- ------------------------------------------------------------
-- 2f. adjust_store_balance: Require owner/admin role
-- Finding: F-05-003
-- ------------------------------------------------------------
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
  -- Role check: only owner/admin can adjust balances
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can adjust store balance';
  END IF;

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

-- ------------------------------------------------------------
-- 2g. update_store_balance_on_order: Add minimum auth guard (stopgap)
-- Finding: F-04-012, F-02-009 (audit-added)
-- Will be replaced by atomic order RPC in Plan 09-02
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_store_balance_on_order(
  p_store_id UUID,
  p_order_total NUMERIC
) RETURNS VOID AS $$
BEGIN
  -- Minimum auth guard (stopgap until atomic order RPC replaces this)
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: authentication required';
  END IF;

  -- Atomic UPDATE — credit_balance + p_order_total is inherently safe
  UPDATE stores
  SET credit_balance = credit_balance + p_order_total
  WHERE id = p_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- PART 3: balance_adjustments RLS — Append-Only with Role Access
-- Finding: F-04-004, F-05-005
-- ============================================================

-- Drop the overly permissive FOR ALL policy
DROP POLICY IF EXISTS "Users can manage own business adjustments" ON balance_adjustments;

-- Owner: SELECT + INSERT. No UPDATE/DELETE.
CREATE POLICY "balance_adjustments_owner_read"
  ON balance_adjustments FOR SELECT
  USING (get_user_role() = 'owner' AND business_id = get_user_business_id());

CREATE POLICY "balance_adjustments_owner_insert"
  ON balance_adjustments FOR INSERT
  WITH CHECK (get_user_role() = 'owner' AND business_id = get_user_business_id());

-- Admin: SELECT only
CREATE POLICY "balance_adjustments_admin_read"
  ON balance_adjustments FOR SELECT
  USING (get_user_role() = 'admin' AND business_id = get_user_business_id());

-- Driver: SELECT only (can see adjustments for their business)
CREATE POLICY "balance_adjustments_driver_read"
  ON balance_adjustments FOR SELECT
  USING (get_user_role() = 'driver' AND business_id = get_user_business_id());

-- No UPDATE or DELETE policies for any role = append-only audit table
