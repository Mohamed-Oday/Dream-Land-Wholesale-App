-- ============================================================
-- CLEANUP: Remove test data from failed manual setup
-- ============================================================

-- Delete test users from public.users
DELETE FROM users;

-- Delete test auth users (run in SQL Editor)
DELETE FROM auth.users WHERE email LIKE '%@tawzii.local';

-- ============================================================
-- ALLOW FIRST-USER SIGNUP
-- ============================================================

-- Allow unauthenticated INSERT into users ONLY when table is empty.
-- This enables the initialization screen to create the first owner.
-- After the first user exists, this policy blocks further unauthenticated inserts.
CREATE POLICY users_first_owner_signup ON users
  FOR INSERT
  WITH CHECK (
    role = 'owner'
    AND NOT EXISTS (SELECT 1 FROM users LIMIT 1)
  );

-- Allow anyone to check if users table is empty (for init screen detection)
-- This SELECT returns no data if users exist (safe), only checks existence
CREATE POLICY users_check_empty ON users
  FOR SELECT
  USING (
    -- Allow select only when no users exist (init check)
    -- OR when user is authenticated (normal RLS applies via other policies)
    NOT EXISTS (SELECT 1 FROM users LIMIT 1)
    OR auth.uid() IS NOT NULL
  );
