ALTER TABLE user_profile
  ADD COLUMN IF NOT EXISTS profile_summary TEXT,
  ADD COLUMN IF NOT EXISTS professional_status TEXT NOT NULL DEFAULT 'open_to_work';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profile_professional_status_check'
  ) THEN
    ALTER TABLE user_profile
      ADD CONSTRAINT user_profile_professional_status_check
      CHECK (professional_status IN ('open_to_work', 'hired', 'not_available'));
  END IF;
END
$$;

ALTER TABLE profile_visibility
  ADD COLUMN IF NOT EXISTS show_specialization BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS show_profile_summary BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS show_professional_status BOOLEAN NOT NULL DEFAULT FALSE;