-- Phase 4 Plan 04: Remote config table for in-app update check

CREATE TABLE remote_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Read-only for app users, writable only via service_role (Supabase dashboard)
ALTER TABLE remote_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read config" ON remote_config FOR SELECT USING (true);

-- Seed with initial values
INSERT INTO remote_config (key, value) VALUES
  ('latest_version', '0.1.0'),
  ('download_url', ''),
  ('min_version', '0.1.0');
