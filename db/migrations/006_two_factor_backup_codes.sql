-- Add hashed backup codes support for Two-Factor Authentication.

ALTER TABLE app_user
  ADD COLUMN IF NOT EXISTS two_factor_backup_codes_hashes TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS two_factor_backup_codes_generated_at TIMESTAMPTZ;
