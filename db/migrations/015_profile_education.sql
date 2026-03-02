CREATE TABLE IF NOT EXISTS user_education (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    sort_order SMALLINT NOT NULL CHECK (sort_order >= 1 AND sort_order <= 3),
    university TEXT NOT NULL,
    specialization TEXT NOT NULL,
    start_month SMALLINT NOT NULL CHECK (start_month >= 1 AND start_month <= 12),
    start_year SMALLINT NOT NULL CHECK (start_year >= 1950 AND start_year <= 2100),
    end_month SMALLINT CHECK (end_month >= 1 AND end_month <= 12),
    end_year SMALLINT CHECK (end_year >= 1950 AND end_year <= 2100),
    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, sort_order),
    CHECK (
      (is_current = TRUE AND end_month IS NULL AND end_year IS NULL) OR
      (is_current = FALSE AND end_month IS NOT NULL AND end_year IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_user_education_user_id ON user_education(user_id);
