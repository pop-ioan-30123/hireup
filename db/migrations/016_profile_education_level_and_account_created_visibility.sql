ALTER TABLE user_experience
  DROP CONSTRAINT IF EXISTS user_experience_sort_order_check;

ALTER TABLE user_experience
  ADD CONSTRAINT user_experience_sort_order_check
  CHECK (sort_order >= 1 AND sort_order <= 5);

ALTER TABLE user_education
  DROP CONSTRAINT IF EXISTS user_education_sort_order_check;

ALTER TABLE user_education
  ADD CONSTRAINT user_education_sort_order_check
  CHECK (sort_order >= 1 AND sort_order <= 5);

ALTER TABLE user_education
  ADD COLUMN IF NOT EXISTS education_level TEXT NOT NULL DEFAULT '';

ALTER TABLE profile_visibility
  ADD COLUMN IF NOT EXISTS show_account_created_date BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS show_account_created_time BOOLEAN NOT NULL DEFAULT FALSE;
