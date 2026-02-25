-- Add avatar attachment type and profile visibility settings.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname = 'attachment_type' AND e.enumlabel = 'avatar'
  ) THEN
    ALTER TYPE attachment_type ADD VALUE 'avatar';
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS profile_visibility (
  user_id UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  show_gender BOOLEAN NOT NULL DEFAULT FALSE,
  show_birth_date BOOLEAN NOT NULL DEFAULT FALSE,
  show_job_title BOOLEAN NOT NULL DEFAULT FALSE,
  show_phone BOOLEAN NOT NULL DEFAULT FALSE,
  show_country BOOLEAN NOT NULL DEFAULT FALSE,
  show_county BOOLEAN NOT NULL DEFAULT FALSE,
  show_city BOOLEAN NOT NULL DEFAULT FALSE,
  show_years_experience BOOLEAN NOT NULL DEFAULT FALSE,
  show_education_level BOOLEAN NOT NULL DEFAULT FALSE,
  show_education_institution BOOLEAN NOT NULL DEFAULT FALSE,
  show_company_name BOOLEAN NOT NULL DEFAULT FALSE,
  show_company_county BOOLEAN NOT NULL DEFAULT FALSE,
  show_company_city BOOLEAN NOT NULL DEFAULT FALSE,
  show_hr_first_name BOOLEAN NOT NULL DEFAULT FALSE,
  show_hr_last_name BOOLEAN NOT NULL DEFAULT FALSE,
  show_hr_email BOOLEAN NOT NULL DEFAULT FALSE,
  show_cv BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profile_visibility_user ON profile_visibility(user_id);
