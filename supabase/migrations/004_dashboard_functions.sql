-- Phase 3 Plan 01: Dashboard RPC functions + performance index

-- ============================================================
-- Performance index for package alerts query
-- Enables efficient DISTINCT ON (store_id, product_id) lookups
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_package_logs_store_product_created
  ON package_logs(store_id, product_id, created_at DESC);

-- ============================================================
-- get_package_alerts: Returns stores with outstanding unreturned packages
-- Aggregates latest balance per (store_id, product_id), sums per store
-- ============================================================
CREATE OR REPLACE FUNCTION get_package_alerts(p_business_id UUID)
RETURNS TABLE (store_id UUID, store_name TEXT, total_outstanding BIGINT) AS $$
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  RETURN QUERY
  SELECT
    latest.store_id,
    s.name AS store_name,
    SUM(latest.balance_after)::BIGINT AS total_outstanding
  FROM (
    SELECT DISTINCT ON (pl.store_id, pl.product_id)
      pl.store_id,
      pl.product_id,
      pl.balance_after
    FROM package_logs pl
    WHERE pl.business_id = p_business_id
    ORDER BY pl.store_id, pl.product_id, pl.created_at DESC
  ) latest
  JOIN stores s ON s.id = latest.store_id
  GROUP BY latest.store_id, s.name
  HAVING SUM(latest.balance_after) > 0
  ORDER BY total_outstanding DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions (matches existing RPC pattern)
GRANT EXECUTE ON FUNCTION get_package_alerts(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_package_alerts(UUID) TO authenticated;
