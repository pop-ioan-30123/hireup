-- Migration 026: persistent read state for activity and social notifications.

ALTER TABLE activity_notification
  ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

ALTER TABLE social_notification
  ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_activity_notification_user_unread
  ON activity_notification(user_id, is_read, sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_notification_recipient_unread
  ON social_notification(recipient_user_id, is_read, sent_at DESC);
