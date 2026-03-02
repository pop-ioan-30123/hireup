ALTER TABLE user_experience
  ADD COLUMN IF NOT EXISTS show_on_profile BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE user_education
  ADD COLUMN IF NOT EXISTS show_on_profile BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS user_skill (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('language', 'soft', 'hard')),
    sort_order SMALLINT NOT NULL CHECK (sort_order >= 1 AND sort_order <= 30),
    name TEXT NOT NULL,
    score SMALLINT NOT NULL CHECK (score >= 1 AND score <= 10),
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, category, sort_order)
);

CREATE INDEX IF NOT EXISTS idx_user_skill_user_id ON user_skill(user_id);
