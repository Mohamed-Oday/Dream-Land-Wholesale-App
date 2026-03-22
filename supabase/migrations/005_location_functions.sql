-- Phase 3 Plan 02: Location tracking RPC functions

-- ============================================================
-- get_latest_driver_locations: Returns latest position per active driver
-- Only includes locations from the last hour and active drivers
-- ============================================================
CREATE OR REPLACE FUNCTION get_latest_driver_locations(p_business_id UUID)
RETURNS TABLE (driver_id UUID, driver_name TEXT, lat DOUBLE PRECISION, lng DOUBLE PRECISION, "timestamp" TIMESTAMPTZ) AS $$
BEGIN
  -- Authorization: verify caller's business matches parameter
  IF p_business_id != (auth.jwt() -> 'user_metadata' ->> 'business_id')::UUID THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (dl.driver_id)
    dl.driver_id,
    u.name AS driver_name,
    dl.lat,
    dl.lng,
    dl.timestamp
  FROM driver_locations dl
  JOIN users u ON u.id = dl.driver_id
  WHERE dl.business_id = p_business_id
    AND dl.timestamp > now() - interval '1 hour'
    AND u.active = true
  ORDER BY dl.driver_id, dl.timestamp DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions (matches existing RPC pattern)
GRANT EXECUTE ON FUNCTION get_latest_driver_locations(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_latest_driver_locations(UUID) TO authenticated;
