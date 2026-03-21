-- ============================================================
-- OWNER ACCOUNT SETUP
-- ============================================================
--
-- PREREQUISITES (Supabase Dashboard):
-- 1. Go to Settings → Auth → Email
--    → DISABLE "Enable email confirmations"
--    (username@tawzii.local format cannot receive emails)
--
-- 2. Go to Authentication → Users → Add User
--    → Email: owner@tawzii.local
--    → Password: (choose a strong password)
--    → Auto Confirm User: YES
--
-- 3. After creating the auth user, copy the UUID from the users list
--
-- 4. Set user_metadata via SQL Editor (replace UUIDs):
--
UPDATE auth.users
SET raw_user_meta_data = jsonb_build_object(
  'role', 'owner',
  'business_id', 'YOUR_BUSINESS_UUID_HERE',
  'name', 'المالك',
  'username', 'owner'
)
WHERE email = 'owner@tawzii.local';
--
-- 5. Create matching public.users row:

-- Generate a business UUID first (run this separately):
-- SELECT gen_random_uuid(); -- Copy result as your business_id

-- Then insert the owner user (replace placeholders):
INSERT INTO users (id, business_id, name, username, role)
VALUES (
  'AUTH_USER_UUID_HERE',        -- from step 3
  'BUSINESS_UUID_HERE',         -- from step above
  'المالك',                     -- Owner name in Arabic
  'owner',                      -- Login username
  'owner'                       -- Role
);

-- ============================================================
-- VERIFICATION
-- ============================================================
-- After setup, verify:
SELECT * FROM users WHERE role = 'owner';
-- Should return 1 row with the owner account.
--
-- Test login in the app with:
-- Username: owner
-- Password: (the password from step 2)
