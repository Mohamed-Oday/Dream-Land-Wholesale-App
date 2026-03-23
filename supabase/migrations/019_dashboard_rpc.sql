-- AEGIS REMEDIATION: Dashboard Consolidation (Phase 10, Plan 02)
-- Consolidates 5 separate dashboard queries into single RPC
-- Deploy via: supabase db push or Supabase Dashboard SQL Editor

-- ============================================================
-- get_dashboard_summary: Single RPC returning all dashboard KPIs
-- Replaces 5 individual queries with 1 round trip
-- ============================================================

CREATE OR REPLACE FUNCTION get_dashboard_summary(p_business_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_today_start TIMESTAMPTZ;
  v_revenue NUMERIC;
  v_order_count INTEGER;
  v_purchases NUMERIC;
  v_debtors JSONB;
  v_low_stock JSONB;
BEGIN
  -- Auth checks
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can view dashboard';
  END IF;

  IF p_business_id != get_user_business_id() THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- Algeria timezone: start of today in UTC
  v_today_start := ((now() AT TIME ZONE 'Africa/Algiers')::date)::timestamptz AT TIME ZONE 'Africa/Algiers';

  -- Today's revenue (sum of payments)
  SELECT COALESCE(SUM(amount), 0) INTO v_revenue
  FROM payments
  WHERE business_id = p_business_id
    AND created_at >= v_today_start;

  -- Today's order count
  SELECT COUNT(*) INTO v_order_count
  FROM orders
  WHERE business_id = p_business_id
    AND created_at >= v_today_start;

  -- Today's purchases (sum of purchase order costs)
  SELECT COALESCE(SUM(total_cost), 0) INTO v_purchases
  FROM purchase_orders
  WHERE business_id = p_business_id
    AND created_at >= v_today_start;

  -- Top debtors (stores with outstanding credit)
  SELECT COALESCE(jsonb_agg(row_to_json(d)), '[]'::jsonb) INTO v_debtors
  FROM (
    SELECT id, name, credit_balance
    FROM stores
    WHERE business_id = p_business_id
      AND credit_balance > 0
    ORDER BY credit_balance DESC
    LIMIT 5
  ) d;

  -- Low stock products (stock at or below threshold)
  SELECT COALESCE(jsonb_agg(row_to_json(ls)), '[]'::jsonb) INTO v_low_stock
  FROM (
    SELECT id, name, stock_on_hand, low_stock_threshold
    FROM products
    WHERE business_id = p_business_id
      AND active = true
      AND low_stock_threshold > 0
      AND stock_on_hand <= low_stock_threshold
  ) ls;

  -- Return consolidated JSONB
  RETURN jsonb_build_object(
    'today_revenue', v_revenue,
    'today_order_count', v_order_count,
    'today_purchases', v_purchases,
    'today_profit', v_revenue - v_purchases,
    'top_debtors', v_debtors,
    'low_stock_products', v_low_stock
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION get_dashboard_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_dashboard_summary(UUID) TO authenticated;
