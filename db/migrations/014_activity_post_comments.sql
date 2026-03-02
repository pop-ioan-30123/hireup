CREATE TABLE IF NOT EXISTS profile_activity_comment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES profile_activity_post(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profile_activity_comment_post_created
  ON profile_activity_comment(post_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_profile_activity_comment_user_created
  ON profile_activity_comment(user_id, created_at DESC);
