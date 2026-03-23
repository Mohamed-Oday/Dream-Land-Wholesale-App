-- AEGIS REMEDIATION: Day-1 Security Fixes (Phase 8)
--
-- IMPORTANT: Supabase Free Tier pauses after 7 days of inactivity.
-- Set up a keep-alive mechanism:
--   Option A: Upgrade to Supabase Pro ($25/month)
--   Option B: External cron (e.g., cron-job.org) pinging the health endpoint daily
--   Option C: pg_cron job: SELECT 1; on a daily schedule
--
-- Finding refs: DA blind spot 3.1, F-07-006

-- ============================================================
-- Fix 1: Location cleanup — wrong column name (created_at → timestamp)
-- Finding: F-02-008
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_old_driver_locations()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM driver_locations
  WHERE "timestamp" < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Fix 2: Revoke anon grants on mutation RPCs
-- Finding: F-02-003, F-05-004
-- Only mutation functions are revoked. Read-only functions
-- (get_package_balances_for_store, get_package_alerts,
-- get_latest_driver_locations) remain accessible to anon.
-- ============================================================
REVOKE EXECUTE ON FUNCTION create_package_log(UUID, UUID, UUID, INTEGER, INTEGER, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION approve_discount(UUID, UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION reject_discount(UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION reject_expired_discounts(UUID) FROM anon;
