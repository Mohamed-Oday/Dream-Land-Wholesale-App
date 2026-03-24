-- ============================================================
-- Migration 022: FCM Token Storage for Push Notifications
-- Creates fcm_tokens table, RLS, and token management RPCs
-- ============================================================

-- ============================================================
-- 1. Table
-- ============================================================

CREATE TABLE fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, device_token)
);


-- ============================================================
-- 2. RLS
-- ============================================================

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own tokens"
  ON fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id);


-- ============================================================
-- 3. RPCs
-- ============================================================

-- 3a. Upsert FCM token (called on login / token refresh)
CREATE OR REPLACE FUNCTION upsert_fcm_token(
  p_device_token TEXT,
  p_platform TEXT DEFAULT 'android'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO fcm_tokens (user_id, device_token, platform)
  VALUES (auth.uid(), p_device_token, p_platform)
  ON CONFLICT (user_id, device_token)
  DO UPDATE SET updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION upsert_fcm_token(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION upsert_fcm_token(TEXT, TEXT) TO authenticated;


-- 3b. Delete FCM token (called on logout)
CREATE OR REPLACE FUNCTION delete_fcm_token(
  p_device_token TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM fcm_tokens
  WHERE user_id = auth.uid()
    AND device_token = p_device_token;
END;
$$;

REVOKE ALL ON FUNCTION delete_fcm_token(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_fcm_token(TEXT) TO authenticated;


-- 3c. Get FCM tokens for a business (service_role only — used by Edge Function)
CREATE OR REPLACE FUNCTION get_fcm_tokens_for_business(
  p_business_id UUID,
  p_roles TEXT[] DEFAULT ARRAY['owner', 'admin'],
  p_exclude_user UUID DEFAULT NULL
)
RETURNS TABLE(user_id UUID, device_token TEXT)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT ft.user_id, ft.device_token
  FROM fcm_tokens ft
  JOIN auth.users au ON au.id = ft.user_id
  WHERE au.raw_user_meta_data->>'business_id' = p_business_id::text
    AND au.raw_user_meta_data->>'role' = ANY(p_roles)
    AND (au.raw_user_meta_data->>'active')::boolean IS TRUE
    AND ft.user_id != COALESCE(p_exclude_user, '00000000-0000-0000-0000-000000000000'::uuid);
$$;

-- service_role only — no GRANT needed (postgres owner always has access)
REVOKE ALL ON FUNCTION get_fcm_tokens_for_business(UUID, TEXT[], UUID) FROM PUBLIC;
