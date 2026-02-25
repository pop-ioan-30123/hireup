-- Compatibility migration for environments that were on 006 before consolidation.
-- Keeps schema consistent after moving 007/008 fields into 002/004.

ALTER TABLE app_user
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS birth_date DATE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_app_user_gender'
  ) THEN
    ALTER TABLE app_user
      ADD CONSTRAINT chk_app_user_gender
      CHECK (gender IS NULL OR gender IN ('male', 'female'));
  END IF;
END $$;

ALTER TABLE profile_visibility
  ADD COLUMN IF NOT EXISTS show_gender BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS show_birth_date BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS show_job_title BOOLEAN NOT NULL DEFAULT FALSE;
