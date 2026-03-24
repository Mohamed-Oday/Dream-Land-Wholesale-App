-- ============================================================
-- Migration 023: Notification Preferences
-- Per-user toggles for which notification types to receive.
-- Also updates get_fcm_tokens_for_business to filter by prefs.
-- ============================================================

-- ============================================================
-- 1. Table
-- ============================================================

CREATE TABLE notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  new_order BOOLEAN NOT NULL DEFAULT true,
  payment_collected BOOLEAN NOT NULL DEFAULT true,
  discount_pending BOOLEAN NOT NULL DEFAULT true,
  low_stock BOOLEAN NOT NULL DEFAULT true,
  shift_opened BOOLEAN NOT NULL DEFAULT true,
  shift_closed BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Apply set_updated_at trigger (matches project pattern from Phase 10)
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON notification_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================
-- 2. RLS
-- ============================================================

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own preferences"
  ON notification_preferences
  FOR ALL
  USING (auth.uid() = user_id);


-- ============================================================
-- 3. RPCs
-- ============================================================

-- 3a. Get notification preferences (returns defaults if no row exists)
CREATE OR REPLACE FUNCTION get_notification_preferences()
RETURNS TABLE(
  new_order BOOLEAN,
  payment_collected BOOLEAN,
  discount_pending BOOLEAN,
  low_stock BOOLEAN,
  shift_opened BOOLEAN,
  shift_closed BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    COALESCE(np.new_order, true),
    COALESCE(np.payment_collected, true),
    COALESCE(np.discount_pending, true),
    COALESCE(np.low_stock, true),
    COALESCE(np.shift_opened, true),
    COALESCE(np.shift_closed, true)
  FROM (SELECT 1) AS dummy
  LEFT JOIN notification_preferences np ON np.user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION get_notification_preferences() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_notification_preferences() TO authenticated;


-- 3b. Upsert a single notification preference
CREATE OR REPLACE FUNCTION upsert_notification_preference(
  p_event_type TEXT,
  p_enabled BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate event type
  IF p_event_type NOT IN (
    'new_order', 'payment_collected', 'discount_pending',
    'low_stock', 'shift_opened', 'shift_closed'
  ) THEN
    RAISE EXCEPTION 'invalid event type: %', p_event_type;
  END IF;

  -- Ensure row exists for this user
  INSERT INTO notification_preferences (user_id)
  VALUES (auth.uid())
  ON CONFLICT (user_id) DO NOTHING;

  -- Update the specific column using CASE (no dynamic SQL)
  UPDATE notification_preferences
  SET
    new_order = CASE WHEN p_event_type = 'new_order' THEN p_enabled ELSE new_order END,
    payment_collected = CASE WHEN p_event_type = 'payment_collected' THEN p_enabled ELSE payment_collected END,
    discount_pending = CASE WHEN p_event_type = 'discount_pending' THEN p_enabled ELSE discount_pending END,
    low_stock = CASE WHEN p_event_type = 'low_stock' THEN p_enabled ELSE low_stock END,
    shift_opened = CASE WHEN p_event_type = 'shift_opened' THEN p_enabled ELSE shift_opened END,
    shift_closed = CASE WHEN p_event_type = 'shift_closed' THEN p_enabled ELSE shift_closed END,
    updated_at = now()
  WHERE user_id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION upsert_notification_preference(TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION upsert_notification_preference(TEXT, BOOLEAN) TO authenticated;


-- ============================================================
-- 4. Update get_fcm_tokens_for_business to filter by preferences
-- ============================================================

-- Drop old 3-param version
DROP FUNCTION IF EXISTS get_fcm_tokens_for_business(UUID, TEXT[], UUID);

-- Recreate with 4th param: p_event_type (filters by notification preferences)
CREATE OR REPLACE FUNCTION get_fcm_tokens_for_business(
  p_business_id UUID,
  p_roles TEXT[] DEFAULT ARRAY['owner', 'admin'],
  p_exclude_user UUID DEFAULT NULL,
  p_event_type TEXT DEFAULT NULL
)
RETURNS TABLE(user_id UUID, device_token TEXT)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT ft.user_id, ft.device_token
  FROM fcm_tokens ft
  JOIN auth.users au ON au.id = ft.user_id
  LEFT JOIN notification_preferences np ON np.user_id = ft.user_id
  WHERE au.raw_user_meta_data->>'business_id' = p_business_id::text
    AND au.raw_user_meta_data->>'role' = ANY(p_roles)
    AND COALESCE((au.raw_user_meta_data->>'active')::boolean, true) IS TRUE
    AND ft.user_id != COALESCE(p_exclude_user, '00000000-0000-0000-0000-000000000000'::uuid)
    AND (
      p_event_type IS NULL
      OR np.user_id IS NULL  -- No preferences row = all enabled (default)
      OR CASE p_event_type
          WHEN 'new_order' THEN np.new_order
          WHEN 'payment_collected' THEN np.payment_collected
          WHEN 'discount_pending' THEN np.discount_pending
          WHEN 'low_stock' THEN np.low_stock
          WHEN 'shift_opened' THEN np.shift_opened
          WHEN 'shift_closed' THEN np.shift_closed
          ELSE true
        END
    );
$$;

-- service_role only — no GRANT needed (postgres owner always has access)
REVOKE ALL ON FUNCTION get_fcm_tokens_for_business(UUID, TEXT[], UUID, TEXT) FROM PUBLIC;
