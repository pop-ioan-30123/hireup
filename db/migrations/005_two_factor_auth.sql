-- Add persisted Two-Factor Authentication fields.

ALTER TABLE app_user
  ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS two_factor_secret_enc TEXT,
  ADD COLUMN IF NOT EXISTS two_factor_enabled_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_app_user_two_factor_enabled
  ON app_user(two_factor_enabled)
  WHERE two_factor_enabled = TRUE;
