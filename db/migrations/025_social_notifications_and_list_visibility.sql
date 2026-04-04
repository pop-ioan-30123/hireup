-- Migration 025: social notifications and list visibility privacy.

ALTER TABLE user_privacy_settings
  ADD COLUMN IF NOT EXISTS show_follower_list BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS show_contact_list BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE user_privacy_settings
SET show_follower_list = COALESCE(show_follower_list, show_follower_count, TRUE),
    show_contact_list = COALESCE(show_contact_list, show_contact_count, TRUE);

CREATE TABLE IF NOT EXISTS social_notification (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  actor_user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL
    CHECK (notification_type IN ('follow', 'unfollow', 'contact')),
  image_key TEXT NOT NULL DEFAULT 'follow',
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (recipient_user_id <> actor_user_id)
);

CREATE INDEX IF NOT EXISTS idx_social_notification_recipient
  ON social_notification(recipient_user_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_notification_actor
  ON social_notification(actor_user_id, sent_at DESC);