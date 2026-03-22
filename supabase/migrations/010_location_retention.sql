-- Phase 4 Plan 05: DriverLocation 7-day retention cleanup

-- Cleanup function: delete driver_locations older than 7 days
-- Can be called manually or scheduled via pg_cron
CREATE OR REPLACE FUNCTION cleanup_old_driver_locations()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM driver_locations
  WHERE created_at < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION cleanup_old_driver_locations() TO authenticated;
